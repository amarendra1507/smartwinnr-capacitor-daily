import UIKit
import AVFoundation
import AVKit
import WebKit

/// Renders a VIDEO sharable resource inside the DocumentShare layout — the
/// video-resource parallel to `DocumentSharePdfView`.
///
/// Primary path: a native `AVPlayerViewController` streaming the HLS url. It is
/// preferred because (a) it is reliably captured by the ReplayKit session
/// recording (a WKWebView player can be excluded from screen capture by the
/// app's secure-layer setup), (b) it gives the full, familiar transport bar
/// (large play/pause, scrubber, elapsed/remaining time, volume, full screen),
/// and (c) it exposes precise play/pause/time state we forward to JS. If no HLS
/// url is supplied it falls back to a `WKWebView` loading the Bunny embed url
/// (limited: no playback-state tracking).
///
/// Because AVPlayerViewController is a view controller, the owner must call
/// `attach(to:)` after `load()` so it participates in the VC hierarchy (and
/// `finalizePlayback()` on teardown, which also detaches it).
///
/// Playback state is reported via `onStateChanged` (`isPlaying`,
/// `currentTimeMs`, `durationMs`, `ended`); load failures via `onLoadError`.
final class DocumentShareVideoView: UIView {

    // MARK: - Public callbacks

    var onStateChanged: (([String: Any]) -> Void)?
    var onLoadError: ((String) -> Void)?

    // MARK: - Inputs

    private let embedURL: URL?
    private let hlsURL: URL?
    private let posterURL: URL?

    // MARK: - AVPlayer

    private var player: AVPlayer?
    /// Exposed so the owning view controller can add it as a child (see attach(to:)).
    private(set) var playerViewController: AVPlayerViewController?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?

    // MARK: - WebView fallback

    private var webView: WKWebView?

    // MARK: - UI

    private let errorLabel = UILabel()
    // Shown over the first frame before playback begins (and again on end) so it
    // is immediately obvious the resource is a VIDEO — AVPlayerViewController
    // otherwise hides its controls until the user taps, making it look static.
    private let startOverlay = UIView()
    private let bigPlayButton = UIButton(type: .system)

    // MARK: - State

    private var isPlaying = false
    private var durationMs = 0
    private var startedOnce = false
    private var lastEmittedSecond = -1
    private var didFinalize = false

    // MARK: - Init

    init(embedURL: URL?, hlsURL: URL?, posterURL: URL?) {
        self.embedURL = embedURL
        self.hlsURL = hlsURL
        self.posterURL = posterURL
        super.init(frame: .zero)
        backgroundColor = .black
        setupUI()
        registerLifecycleObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        teardown()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI setup

    private func setupUI() {
        // Start overlay: a subtle scrim + a large play button, tappable anywhere.
        startOverlay.translatesAutoresizingMaskIntoConstraints = false
        startOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        startOverlay.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleStartTapped))
        startOverlay.addGestureRecognizer(tap)
        addSubview(startOverlay)

        bigPlayButton.translatesAutoresizingMaskIntoConstraints = false
        bigPlayButton.tintColor = .white
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 76, weight: .semibold)
        bigPlayButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: symbolConfig), for: .normal)
        bigPlayButton.addTarget(self, action: #selector(handleStartTapped), for: .touchUpInside)
        bigPlayButton.layer.shadowColor = UIColor.black.cgColor
        bigPlayButton.layer.shadowOpacity = 0.4
        bigPlayButton.layer.shadowRadius = 8
        bigPlayButton.layer.shadowOffset = .zero
        startOverlay.addSubview(bigPlayButton)

        // Error label sits on top of everything.
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textColor = .white
        errorLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        addSubview(errorLabel)

        NSLayoutConstraint.activate([
            startOverlay.topAnchor.constraint(equalTo: topAnchor),
            startOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            startOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            startOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            bigPlayButton.centerXAnchor.constraint(equalTo: startOverlay.centerXAnchor),
            bigPlayButton.centerYAnchor.constraint(equalTo: startOverlay.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    @objc private func handleStartTapped() {
        guard let player = player else { return }
        // Restart from the beginning if we're at the end (replay).
        if let duration = player.currentItem?.duration, duration.isNumeric {
            let atEnd = CMTimeGetSeconds(player.currentTime()) >= CMTimeGetSeconds(duration) - 0.3
            if atEnd { player.seek(to: .zero) }
        }
        player.play()
        hideStartOverlay()
    }

    private func showStartOverlay() {
        startOverlay.isHidden = false
        // Above the player view, below any error message.
        if let overlaySuper = startOverlay.superview {
            overlaySuper.bringSubviewToFront(startOverlay)
            overlaySuper.bringSubviewToFront(errorLabel)
        }
    }

    private func hideStartOverlay() {
        startOverlay.isHidden = true
    }

    // MARK: - Loading

    func load() {
        if let hls = hlsURL {
            setupAVPlayer(url: hls)
        } else if let embed = embedURL {
            setupWebView(url: embed)
        } else {
            showError("No playable video url")
        }
    }

    // MARK: - AVPlayer path (native full controls)

    private func setupAVPlayer(url: URL) {
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = avPlayer

        // AVPlayerViewController provides the standard transport UI (big play/
        // pause, scrubber, time, volume, full-screen) and its own loading spinner.
        let pvc = AVPlayerViewController()
        pvc.player = avPlayer
        pvc.showsPlaybackControls = true
        pvc.videoGravity = .resizeAspect
        // Don't fight the call's own PiP / now-playing integration.
        pvc.allowsPictureInPicturePlayback = false
        if #available(iOS 10.0, *) { pvc.updatesNowPlayingInfoCenter = false }
        pvc.view.backgroundColor = .black
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        // Player at the bottom; the start overlay + error label stay above it.
        insertSubview(pvc.view, at: 0)
        NSLayoutConstraint.activate([
            pvc.view.topAnchor.constraint(equalTo: topAnchor),
            pvc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            pvc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            pvc.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.playerViewController = pvc

        // Make it obvious this is a video from the moment it's selected.
        showStartOverlay()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch observedItem.status {
                case .readyToPlay:
                    self.errorLabel.isHidden = true
                    let seconds = CMTimeGetSeconds(observedItem.duration)
                    if seconds.isFinite && seconds > 0 { self.durationMs = Int(seconds * 1000) }
                    self.emitState(ended: false)
                case .failed:
                    let message = observedItem.error?.localizedDescription ?? "Video failed to load"
                    self.showError(message)
                default:
                    break
                }
            }
        }

        rateObservation = avPlayer.observe(\.rate, options: [.new]) { [weak self] observedPlayer, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let playing = observedPlayer.rate > 0
                if playing != self.isPlaying {
                    self.isPlaying = playing
                    if playing {
                        self.startedOnce = true
                        // Playback started — hand off to the native controls.
                        self.hideStartOverlay()
                    }
                    self.emitState(ended: false)
                }
            }
        }

        // Periodic progress (~once per second).
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let second = Int(CMTimeGetSeconds(time))
            guard second != self.lastEmittedSecond else { return }
            self.lastEmittedSecond = second
            if self.isPlaying { self.emitState(ended: false) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isPlaying = false
            // Bring the play button back as a clear replay affordance.
            self.showStartOverlay()
            self.emitState(ended: true)
        }
    }

    /// Adds the AVPlayerViewController as a child of the owning VC so it gets
    /// proper appearance/rotation forwarding. Call after `load()`.
    func attach(to parent: UIViewController) {
        guard let pvc = playerViewController, pvc.parent == nil else { return }
        parent.addChild(pvc)
        pvc.didMove(toParent: parent)
    }

    private func currentTimeMs() -> Int {
        guard let player = player else { return 0 }
        let seconds = CMTimeGetSeconds(player.currentTime())
        return seconds.isFinite ? Int(seconds * 1000) : 0
    }

    private func emitState(ended: Bool) {
        onStateChanged?([
            "isPlaying": isPlaying,
            "currentTimeMs": currentTimeMs(),
            "durationMs": durationMs,
            "ended": ended
        ])
    }

    // MARK: - WebView fallback

    private func setupWebView(url: URL) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let web = WKWebView(frame: bounds, configuration: config)
        web.translatesAutoresizingMaskIntoConstraints = false
        web.backgroundColor = .black
        web.isOpaque = false
        web.scrollView.isScrollEnabled = false
        // The Bunny embed renders its own player UI, so no native start overlay.
        insertSubview(web, at: 0)
        self.webView = web

        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: topAnchor),
            web.leadingAnchor.constraint(equalTo: leadingAnchor),
            web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        web.load(URLRequest(url: url))
        // No reliable cross-origin playback-state signal from an embed iframe;
        // report that the resource is now presented.
        emitState(ended: false)
    }

    // MARK: - Lifecycle

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAppDidEnterBackground() {
        // Pause native playback when backgrounded. The WebView player manages
        // its own state.
        if player?.rate ?? 0 > 0 { player?.pause() }
    }

    /// Called on document switch / call end. Pauses playback and tears down.
    /// (Named `finalizePlayback` rather than `finalize` to avoid clashing with
    /// NSObject's legacy `finalize()`, which would require an `override`.)
    func finalizePlayback() {
        if didFinalize { return }
        didFinalize = true
        if player?.rate ?? 0 > 0 {
            player?.pause()
            isPlaying = false
            emitState(ended: false)
        }
        teardown()
    }

    private func teardown() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        if let end = endObserver { NotificationCenter.default.removeObserver(end); endObserver = nil }
        statusObservation?.invalidate(); statusObservation = nil
        rateObservation?.invalidate(); rateObservation = nil
        player?.pause()
        if let pvc = playerViewController {
            pvc.willMove(toParent: nil)
            pvc.view.removeFromSuperview()
            pvc.removeFromParent()
            pvc.player = nil
        }
        playerViewController = nil
        player = nil
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
    }

    // MARK: - Error

    private func showError(_ message: String) {
        hideStartOverlay()
        errorLabel.text = message
        errorLabel.isHidden = false
        onLoadError?(message)
    }
}
