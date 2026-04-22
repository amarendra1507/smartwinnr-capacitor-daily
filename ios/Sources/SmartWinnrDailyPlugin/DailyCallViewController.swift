//
//  DailyCallViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Created by SmartWinnr on 02/07/24.
//

import Foundation
import UIKit
import Daily
import ReplayKit
import AVFoundation
import AVKit

class DailyCallViewController: UIViewController {

    // MARK: - UI Components

    lazy var headerView = UIView()
    lazy var headerTitleLabel = UILabel()
    lazy var headerBackButton = UIButton()
    lazy var newContentContainerView = UIView()
    lazy var newCoachingTitleLabel = UILabel()
    lazy var newTimerLabel = UILabel()
    lazy var newMainStackView = UIStackView()
    lazy var newLocalVideoContainer = UIView()
    lazy var newRemoteVideoContainer = UIView()
    lazy var newLocalVideoView = VideoView()
    lazy var newRemoteVideoView = VideoView()

    // Secondary VideoView instances rendered INSIDE the native
    // AVPictureInPictureVideoCallViewController's content view when the
    // doc-share flow is active. They share the same tracks as the primary
    // views so the PiP window shows live AI + user video.
    var pipRemoteVideoView: VideoView?
    var pipLocalVideoView: VideoView?
    // Status overlays rendered above the PiP video tiles so the viewer can
    // see the AI's thinking/listening/speaking state + the user's speaking
    // state + both names while in PiP.
    var pipAiNameLabel: UILabel?
    var pipAiStateContainer: UIView?
    var pipAiStateIcon: UIView?
    var pipAiStateLabel: UILabel?
    var pipUserNameLabel: UILabel?
    var pipUserSpeakingDot: UIView?

    enum PipAiState { case listening, thinking, speaking }
    var currentPipAiState: PipAiState = .listening
    lazy var newLocalParticipantLabel = UILabel()
    lazy var newRemoteParticipantLabel = UILabel()
    lazy var newCameraButton = UIButton()
    lazy var newMicButton = UIButton()
    lazy var newEndRolePlayButton = UIButton()
    lazy var newScreenShareButton = UIButton()

    // Tile wrappers (video + indicator row as one unit, matching web <video-tile>)
    lazy var localTileWrapper = UIView()
    lazy var remoteTileWrapper = UIView()

    // Tile indicator rows (below each video, matching web .tile-indicator-row)
    lazy var localIndicatorRow = UIView()
    lazy var remoteIndicatorRow = UIView()

    // Controls row (End Role Play + Screen Share + Settings, matching web .controls)
    lazy var controlsRow = UIStackView()
    lazy var newSettingsButton = UIButton()

    // Aspect ratio constraints (updated on orientation change)
    var localVideoAspectConstraint: NSLayoutConstraint?
    var remoteVideoAspectConstraint: NSLayoutConstraint?

    // Audio-only mode avatar placeholders (shown instead of video)
    lazy var localAvatarView = UIView()
    lazy var remoteAvatarView = UIView()

    // MARK: - Device Detection

    private var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    // MARK: - Speaking and Animation State

    var participantStates: [ParticipantID: DailyParticipant] = [:]

    // MARK: - Turn-based Conversation Tracking

    var currentTurn: Int = 0
    var isUserTurn: Bool = true
    var conversationTurns: [TurnRecord] = []
    var aiFirst: Bool = false

    // MARK: - Server Event Properties

    weak var serverEventDelegate: ServerEventDelegate?
    var eventQueue: DispatchQueue = DispatchQueue(label: "ServerEventQueue", qos: .userInitiated)
    var isEventHandlingActive: Bool = true

    // MARK: - UI State

    var isUIInitialized = false

    // MARK: - Call Client and State

    let callClient: CallClient = .init()
    var allParticipantJoined: Bool = false
    var videoViews: [ParticipantID: VideoView] = [:]

    let token: MeetingToken
    private let roomURLString: String
    let userName: String
    let coachingTitle: String
    let coachName: String
    let isTestMode: Bool
    let enableScreenShare: Bool
    let isAudioModeOnly: Bool
    let maxTime: TimeInterval
    var currentTime: TimeInterval = 1
    var timer: Timer?
    var userProfileImageURL: String?
    var userProfileImage: UIImage?
    var coachProfileImageURL: String?
    var coachProfileImage: UIImage?

    // MARK: - Document Share (PDF) — opt-in via `isDocumentShareEnabled`

    var isDocumentShareEnabled: Bool = false
    var documentUrlString: String?
    var documentTitle: String?
    var documentShareActivated: Bool = false

    // All sharable resources (from `sharable_resources`) and which one is
    // currently being rendered. Index 0 is used by default.
    struct SharableResourceItem {
        let id: String
        let url: String
        let displayName: String?
    }
    var sharableResourceItems: [SharableResourceItem] = []
    var currentResourceIndex: Int = 0

    // Document share UI (lazily created only when the mode is activated)
    var pdfContainerView: UIView?
    var pdfDocumentView: DocumentSharePdfView?
    var floatingTilesOverlayView: UIView?
    var combinedPipContainerView: UIView?
    var resourceSelectorButton: UIButton?
    var thumbnailToggleButton: UIButton?
    var thumbnailStripView: UIView?
    var thumbnailDrawerLeadingConstraint: NSLayoutConstraint?
    var pdfContentLeadingConstraint: NSLayoutConstraint?
    var isThumbnailStripVisible: Bool = false
    let thumbnailDrawerWidth: CGFloat = 130
    var pageIndicatorLabel: UILabel?
    var pageIndicatorHideTimer: Timer?

    // Constraints that get swapped when entering document-share mode.
    // `standardTileConstraints` are the default two-tile layout captured at
    // build time; `documentShareTileConstraints` are the PiP-floating ones.
    var standardTileConstraints: [NSLayoutConstraint] = []
    var documentShareTileConstraints: [NSLayoutConstraint] = []

    // Document share event callbacks (bridged to `notifyListeners` by the plugin)
    var onPdfPageChanged: ((Int, Int) -> Void)?
    var onPdfTrackingUpdate: (([String: Any]) -> Void)?
    var onPdfLoadError: ((String) -> Void)?
    var onPagePresentationTracking: (([[String: Any]]) -> Void)?

    // Page-presentation tracking (documentId / pageNumber / startTime /
    // endTime / timeSpentMs per entry). The app expects the full cumulative
    // list on every emit.
    var pagePresentationEntries: [[String: Any]] = []
    var activePagePresentationEntry: [String: Any]?

    // MARK: - Overlay

    var overlayView: UIView?
    var overlayGradientLayer: CAGradientLayer?

    // MARK: - Network Toast

    var networkToastView: UIView?
    var networkToastDismissTimer: Timer?
    var lastNetworkQuality: String = "good"


    // MARK: - Callbacks

    var onCallStateChange: ((CallState) -> Void)?
    var onNetworkQualityChange: ((String) -> Void)?
    var onParticipantJoined: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    var onJoined: (() -> Void)?
    var onLeft: (() -> Void)?
    var onRecordingStarted: ((String, TimeInterval) -> Void)?
    var onRecordingStopped: ((String, TimeInterval) -> Void)?
    var onRecordingError: ((String) -> Void)?
    var onParticipantCountChanged: ((Int) -> Void)?

    // MARK: - Recording State

    var recordingStartTime: TimeInterval?
    var currentRecordingId: String?
    var recordingStarted: Bool = false
    var disconnectionAlert: UIAlertController?

    // MARK: - Screen Share

    var systemBroadcastPickerView: UIView?
    var isScreenSharingActive: Bool = false

    // MARK: - Picture-in-Picture Properties

    var pipControllerStorage: Any?
    var pipVideoCallViewControllerStorage: Any?
    var pipPossibleObservation: NSKeyValueObservation?
    var videoRenderingMonitorTimer: Timer?
    var pipStartRetryCount: Int = 0
    let pipMaxRetries: Int = 10

    // MARK: - Appearance

    let appTextColor = UIColor(red: 9.0/255.0, green: 30.0/255.0, blue: 66.0/255.0, alpha: 1.0)

    // MARK: - Initialization

    init(urlString: String, token: String, userName: String, coachingTitle: String, maxTime: Int, coachName: String, testMode: Bool, enableScreenShare: Bool, audioModeOnly: Bool = false, userProfileImageURL: String? = nil, coachProfileImageURL: String? = nil) {
        self.roomURLString = urlString
        self.token = MeetingToken(stringValue: token)
        self.userName = userName
        self.coachingTitle = coachingTitle
        self.maxTime = TimeInterval(maxTime)
        self.coachName = coachName
        self.isTestMode = testMode
        self.enableScreenShare = enableScreenShare
        self.isAudioModeOnly = audioModeOnly
        self.userProfileImageURL = userProfileImageURL
        self.coachProfileImageURL = coachProfileImageURL
        super.init(nibName: nil, bundle: nil)

        print("=== DailyCallViewController Init ===")
        print("  roomURL: \(urlString)")
        print("  token: \(token.prefix(20))...")
        print("  userName: \(userName)")
        print("  coachName: \(coachName)")
        print("  coachingTitle: \(coachingTitle)")
        print("  maxTime: \(maxTime)s")
        print("  testMode: \(testMode)")
        print("  enableScreenShare: \(enableScreenShare)")
        print("  audioModeOnly: \(audioModeOnly)")
        print("  userProfileImageURL: \(userProfileImageURL ?? "nil")")
        print("  coachProfileImageURL: \(coachProfileImageURL ?? "nil")")
        print("====================================")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        DispatchQueue.main.async { [weak timer] in
            timer?.invalidate()
        }

        networkToastDismissTimer?.invalidate()
        networkToastDismissTimer = nil

        videoRenderingMonitorTimer?.invalidate()
        videoRenderingMonitorTimer = nil

        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil

        if #available(iOS 15.0, *) {
            if let controller = pipControllerStorage as? AVPictureInPictureController,
               controller.isPictureInPictureActive {
                controller.stopPictureInPicture()
            }
        }

        pipControllerStorage = nil
        pipVideoCallViewControllerStorage = nil

        participantStates.removeAll()
        videoViews.removeAll()
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 201.0/255.0, alpha: 1.0) // Brand color behind status bar
        self.modalPresentationStyle = .fullScreen
        self.isModalInPresentation = true
        self.callClient.delegate = self

        initializeUI()

        // Hide the call UI until both participants join
        newContentContainerView.alpha = 0

        if #available(iOS 15.0, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.setupPictureInPicture()
            }
        }

        setupWaitingOverlay()

        guard let roomURL = URL(string: roomURLString) else { return }

        // In audio-only mode, disable camera BEFORE joining so no video is ever published
        if isAudioModeOnly {
            self.callClient.updateInputs(
                .set(camera: .set(isEnabled: .set(false))),
                completion: nil
            )
        }

        self.callClient.join(url: roomURL, token: token, settings: ClientSettingsUpdate()) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(_):
                self.callClient.set(username: self.userName) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(_):
                        if self.isAudioModeOnly {
                            // Ensure camera stays disabled after join
                            self.callClient.updateInputs(
                                .set(camera: .set(isEnabled: .set(false))),
                                completion: nil
                            )
                        } else {
                            self.callClient.updateInputs(.set(
                                camera: .set(settings: .set(facingMode: .set(.user)))
                            ), completion: nil)
                        }

                        if self.isTestMode {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                                guard let self = self else { return }
                                self.allParticipantJoined = true
                                self.callClient.startRecording() { [weak self] result in
                                    guard let self = self else { return }
                                    switch result {
                                    case .success(_):
                                        DispatchQueue.main.async { [weak self] in
                                            self?.removeOverlayView()
                                        }
                                    case .failure(let error):
                                        print("Failed startRecording: \(error.localizedDescription)")
                                        // Still remove overlay so session can proceed
                                        DispatchQueue.main.async { [weak self] in
                                            self?.removeOverlayView()
                                        }
                                    }
                                }
                            }
                        }
                    case .failure(let error):
                        print("Failed to set username: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                print("Failed to join call: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Waiting Overlay

    func setupWaitingOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(overlay)
        overlayView = overlay

        // Light background matching the page
        let pageBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        let textColor = UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0)
        let brandColor = UIColor(red: 0, green: 0, blue: 201.0/255.0, alpha: 1.0)

        overlay.backgroundColor = pageBg
        overlay.accessibilityIdentifier = "waiting_overlay"
        overlayGradientLayer = nil // no gradient needed

        // Floating particles (subtle dots in brand color)
        for i in 0..<12 {
            let dot = UIView()
            let size = CGFloat.random(in: 4...8)
            dot.backgroundColor = brandColor.withAlphaComponent(CGFloat.random(in: 0.04...0.10))
            dot.layer.cornerRadius = size / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: size),
                dot.heightAnchor.constraint(equalToConstant: size),
                dot.centerXAnchor.constraint(equalTo: overlay.leadingAnchor, constant: CGFloat.random(in: 40...340)),
                dot.centerYAnchor.constraint(equalTo: overlay.topAnchor, constant: CGFloat.random(in: 100...700)),
            ])
            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = dot.layer.position.y - 10
            float.toValue = dot.layer.position.y + 10
            float.duration = Double.random(in: 3...6)
            float.autoreverses = true
            float.repeatCount = .infinity
            float.beginTime = CACurrentMediaTime() + Double(i) * 0.3
            dot.layer.add(float, forKey: "float_\(i)")
        }

        // --- Centered content ---
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(contentStack)

        // Avatar with animated rings
        let avatarSize: CGFloat = 88
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarContainer.widthAnchor.constraint(equalToConstant: avatarSize + 40),
            avatarContainer.heightAnchor.constraint(equalToConstant: avatarSize + 40),
        ])

        // Outer pulse rings in brand color
        var ringViews: [UIView] = []
        for i in 0..<3 {
            let ring = UIView()
            let ringSize = avatarSize + CGFloat(i + 1) * 14
            ring.layer.cornerRadius = ringSize / 2
            ring.layer.borderWidth = 1.5
            ring.layer.borderColor = brandColor.withAlphaComponent(0.20 - Double(i) * 0.05).cgColor
            ring.backgroundColor = .clear
            ring.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(ring)
            ringViews.append(ring)
            NSLayoutConstraint.activate([
                ring.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
                ring.widthAnchor.constraint(equalToConstant: ringSize),
                ring.heightAnchor.constraint(equalToConstant: ringSize),
            ])
        }

        // Avatar circle with brand gradient
        let avatar = UIView()
        avatar.layer.cornerRadius = avatarSize / 2
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatar)

        let avatarGradient = CAGradientLayer()
        avatarGradient.colors = [
            brandColor.cgColor,
            UIColor(red: 0, green: 0, blue: 140.0/255.0, alpha: 1.0).cgColor,
        ]
        avatarGradient.startPoint = CGPoint(x: 0, y: 0)
        avatarGradient.endPoint = CGPoint(x: 1, y: 1)
        avatarGradient.cornerRadius = avatarSize / 2
        avatarGradient.frame = CGRect(x: 0, y: 0, width: avatarSize, height: avatarSize)
        avatar.layer.addSublayer(avatarGradient)

        let aiIcon = UIImageView(image: UIImage(systemName: "waveform.circle.fill"))
        aiIcon.tintColor = .white
        aiIcon.contentMode = .scaleAspectFit
        aiIcon.translatesAutoresizingMaskIntoConstraints = false
        avatar.addSubview(aiIcon)

        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: avatarSize),
            avatar.heightAnchor.constraint(equalToConstant: avatarSize),
            aiIcon.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            aiIcon.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            aiIcon.widthAnchor.constraint(equalToConstant: 40),
            aiIcon.heightAnchor.constraint(equalToConstant: 40),
        ])

        contentStack.addArrangedSubview(avatarContainer)
        contentStack.setCustomSpacing(28, after: avatarContainer)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = coachingTitle
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = textColor
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(16, after: titleLabel)

        // Connecting status with animated waveform
        let statusRow = UIStackView()
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        let waveStack = UIStackView()
        waveStack.axis = .horizontal
        waveStack.spacing = 3
        waveStack.alignment = .center
        waveStack.translatesAutoresizingMaskIntoConstraints = false

        let barHeights: [CGFloat] = [6, 12, 8, 14]
        var waveBars: [UIView] = []

        for i in 0..<4 {
            let bar = UIView()
            bar.backgroundColor = brandColor.withAlphaComponent(0.6)
            bar.layer.cornerRadius = 1.5
            bar.translatesAutoresizingMaskIntoConstraints = false
            waveStack.addArrangedSubview(bar)
            waveBars.append(bar)

            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 3),
                bar.heightAnchor.constraint(equalToConstant: barHeights[i]),
            ])
        }

        statusRow.addArrangedSubview(waveStack)

        let statusLabel = UILabel()
        statusLabel.text = isTestMode ? "Setting up your session" : "Connecting to \(coachName)"
        statusLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = textColor.withAlphaComponent(0.55)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusRow.addArrangedSubview(statusLabel)

        contentStack.addArrangedSubview(statusRow)
        contentStack.setCustomSpacing(24, after: statusRow)

        // Cycling tips
        let tipLabel = UILabel()
        tipLabel.textAlignment = .center
        tipLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        tipLabel.textColor = textColor.withAlphaComponent(0.35)
        tipLabel.numberOfLines = 2
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(tipLabel)

        let tips = [
            "Speak clearly for the best experience",
            "You can mute/unmute during the session",
            "The session will be recorded for review",
            "Stay focused on the objectives",
        ]
        var tipIndex = 0
        tipLabel.text = tips[0]
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak tipLabel, weak self] timer in
            guard let tipLabel = tipLabel, self?.overlayView != nil else { timer.invalidate(); return }
            tipIndex = (tipIndex + 1) % tips.count
            UIView.transition(with: tipLabel, duration: 0.5, options: .transitionCrossDissolve) {
                tipLabel.text = tips[tipIndex]
            }
        }

        // Constraints
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -32),

            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            tipLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
        ])

        if isTestMode {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyTextToClipboard))
            overlay.addGestureRecognizer(tapGesture)
        }

        // Entrance animation — add CA animations in completion so they aren't
        // stripped while contentStack.alpha == 0
        contentStack.alpha = 0
        contentStack.transform = CGAffineTransform(translationX: 0, y: 40)
        UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, animations: {
            contentStack.alpha = 1
            contentStack.transform = .identity
        }) { _ in
            // Ring pulse animations
            for (i, ring) in ringViews.enumerated() {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 0.95
                pulse.toValue = 1.08
                pulse.duration = 2.0 + Double(i) * 0.4
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ring.layer.add(pulse, forKey: "ring_pulse")
            }

            // Avatar breathing animation
            let breathe = CABasicAnimation(keyPath: "transform.scale")
            breathe.fromValue = 1.0
            breathe.toValue = 1.06
            breathe.duration = 2.5
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            avatar.layer.add(breathe, forKey: "breathe")

            // Waveform bar animations using CAKeyframeAnimation
            let barScales: [(min: CGFloat, max: CGFloat)] = [
                (0.33, 1.0), (0.33, 1.0), (0.375, 1.0), (0.36, 1.0)
            ]
            for (i, bar) in waveBars.enumerated() {
                let anim = CAKeyframeAnimation(keyPath: "transform.scale.y")
                anim.values = [barScales[i].max, barScales[i].min, barScales[i].max]
                anim.keyTimes = [0, 0.5, 1.0]
                anim.duration = 0.7
                anim.repeatCount = .infinity
                anim.beginTime = CACurrentMediaTime() + Double(i) * 0.15
                anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.layer.add(anim, forKey: "wave_\(i)")
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        overlayGradientLayer?.frame = view.bounds

        // Keep avatar images circular after Auto Layout resizes them (tag 9001)
        if isAudioModeOnly {
            for avatarView in [localAvatarView, remoteAvatarView] {
                if let imageView = avatarView.viewWithTag(9001) {
                    imageView.layer.cornerRadius = imageView.bounds.height / 2
                }
            }
        }
    }

    func removeOverlayView() {
        guard let overlay = self.overlayView else { return }

        // Step 1: Scale down and fade the content
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.3, animations: {
            for subview in overlay.subviews {
                subview.alpha = 0
                subview.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }
        }) { [weak self] _ in
            guard let self = self else { return }

            // Step 2: Fade out gradient + reveal call UI with spring
            self.newContentContainerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, animations: {
                overlay.alpha = 0
                self.newContentContainerView.alpha = 1
                self.newContentContainerView.transform = .identity
            }) { _ in
                overlay.removeFromSuperview()
                self.overlayView = nil
                self.overlayGradientLayer = nil

                // Start timer only after overlay is fully dismissed
                if self.timer == nil {
                    self.currentTime = 1
                    self.startTimer()
                }
            }
        }
    }

    // MARK: - Call Lifecycle

    func leave() {
        guard self.view.window != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard self.presentingViewController != nil else {
                self.left()
                return
            }

            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.onDismiss?()
                self.left()
            }
        }
    }

    func joined() {
        DispatchQueue.main.async {
            self.onJoined?()
        }
    }

    func left() {
        DispatchQueue.main.async {
            self.onLeft?()
        }
    }

    var previousCallState: CallState = .initialized

    func handleCallStateChange(_ state: CallState) {
        print("[NetworkDebug] handleCallStateChange — state: \(state), previous: \(previousCallState)")
        onCallStateChange?(state)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let prev = self.previousCallState
            self.previousCallState = state

            // Show toast when connection is lost
            if prev == .joined && state != .joined {
                self.showNetworkToast(
                    icon: "wifi.exclamationmark",
                    title: "Connection Lost",
                    message: "Your network connection has been interrupted.",
                    color: UIColor.systemRed,
                    persistent: true
                )
                self.lastNetworkQuality = "very-low"
                self.settingsVC?.updateNetworkQuality("very-low")
            }

            // Show toast when connection is restored
            if prev != .joined && state == .joined {
                self.dismissNetworkToast(animated: true)
                self.showNetworkToast(
                    icon: "wifi",
                    title: "Connection Restored",
                    message: "Your network connection has been restored.",
                    color: UIColor.systemGreen,
                    persistent: false
                )
                self.lastNetworkQuality = "good"
                self.settingsVC?.updateNetworkQuality("good")
            }
        }
    }

    func handleNetworkQualityChange(_ quality: String) {
        print("[NetworkDebug] handleNetworkQualityChange — quality: '\(quality)', prev: '\(lastNetworkQuality)'")
        onNetworkQualityChange?(quality)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let prev = self.lastNetworkQuality
            self.lastNetworkQuality = quality

            // Update settings modal
            self.settingsVC?.updateNetworkQuality(quality)

            // Show toast on state transitions
            guard quality != prev else {
                print("[NetworkDebug]   same as prev, skipping toast")
                return
            }
            print("[NetworkDebug]   state transition: '\(prev)' → '\(quality)', showing toast")

            switch quality {
            case "very-low":
                self.showNetworkToast(
                    icon: "wifi.exclamationmark",
                    title: "Very Poor Connection",
                    message: "Your network is unstable. Audio and video may be affected.",
                    color: UIColor.systemRed,
                    persistent: true
                )
            case "low":
                self.showNetworkToast(
                    icon: "wifi.slash",
                    title: "Poor Connection",
                    message: "Network quality is low. You may experience delays.",
                    color: UIColor.systemOrange,
                    persistent: false
                )
            default:
                if prev == "low" || prev == "very-low" {
                    self.showNetworkToast(
                        icon: "wifi",
                        title: "Connection Restored",
                        message: "Your network has improved.",
                        color: UIColor.systemGreen,
                        persistent: false
                    )
                }
            }
        }
    }

    /// Called when Daily SDK fires networkStatsUpdated — uses quality integer (0-100)
    /// since the SDK's Threshold enum stays at .good even when quality drops to 37/100
    func handleNetworkStatsUpdate(_ stats: NetworkStats) {
        settingsVC?.updateNetworkStats(stats)

        let qualityScore = stats.quality // 0-100 integer

        // Determine state from quality score (SDK threshold is unreliable)
        let quality: String
        if qualityScore >= 70 {
            quality = "good"
        } else if qualityScore >= 50 {
            quality = "low"
        } else {
            quality = "very-low"
        }

        print("[NetworkDebug] handleNetworkStatsUpdate — qualityScore: \(qualityScore), mapped: '\(quality)', lastNetworkQuality: '\(lastNetworkQuality)'")

        // Only act on state transitions
        if quality != lastNetworkQuality {
            let prev = lastNetworkQuality
            lastNetworkQuality = quality
            print("[NetworkDebug]   state transition: '\(prev)' → '\(quality)'")

            switch quality {
            case "very-low":
                showNetworkToast(
                    icon: "wifi.exclamationmark",
                    title: "Very Poor Connection",
                    message: "Your network is unstable. Audio may be affected.",
                    color: UIColor.systemRed,
                    persistent: true
                )
            case "low":
                showNetworkToast(
                    icon: "wifi.slash",
                    title: "Poor Connection",
                    message: "Network quality is low. You may experience delays.",
                    color: UIColor.systemOrange,
                    persistent: false
                )
            default:
                if prev == "low" || prev == "very-low" {
                    showNetworkToast(
                        icon: "wifi",
                        title: "Connection Restored",
                        message: "Your network has improved.",
                        color: UIColor.systemGreen,
                        persistent: false
                    )
                }
            }
        }
    }

    // MARK: - Network Toast

    private func showNetworkToast(icon: String, title: String, message: String, color: UIColor, persistent: Bool) {
        // Remove existing toast
        dismissNetworkToast(animated: false)

        let toast = UIView()
        toast.backgroundColor = UIColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 0.95)
        toast.layer.cornerRadius = 14
        toast.layer.borderWidth = 1
        toast.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        toast.layer.shadowColor = UIColor.black.cgColor
        toast.layer.shadowOffset = CGSize(width: 0, height: 4)
        toast.layer.shadowRadius = 12
        toast.layer.shadowOpacity = 0.3
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        networkToastView = toast

        // Icon container
        let iconBg = UIView()
        iconBg.backgroundColor = color.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 16
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // Text stack
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let msgLabel = UILabel()
        msgLabel.text = message
        msgLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        msgLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        msgLabel.numberOfLines = 2
        msgLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, msgLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(textStack)

        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.5)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(networkToastCloseTapped), for: .touchUpInside)
        toast.addSubview(closeBtn)

        // Color accent bar on left
        let accentBar = UIView()
        accentBar.backgroundColor = color
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(accentBar)

        NSLayoutConstraint.activate([
            // Toast position: top of safe area, centered
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 380),

            // Accent bar
            accentBar.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 12),
            accentBar.topAnchor.constraint(equalTo: toast.topAnchor, constant: 10),
            accentBar.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -10),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            // Icon
            iconBg.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            iconBg.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 32),
            iconBg.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            // Text
            textStack.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),

            // Close button
            closeBtn.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24),

            // Toast height
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])

        // Slide in from top
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: -60)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            toast.alpha = 1
            toast.transform = .identity
        }

        // Auto-dismiss (unless persistent for very-low)
        networkToastDismissTimer?.invalidate()
        if !persistent {
            networkToastDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.dismissNetworkToast(animated: true)
            }
        }
    }

    private func dismissNetworkToast(animated: Bool) {
        networkToastDismissTimer?.invalidate()
        networkToastDismissTimer = nil

        guard let toast = networkToastView else { return }

        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: -40)
            }) { _ in
                toast.removeFromSuperview()
            }
        } else {
            toast.removeFromSuperview()
        }
        networkToastView = nil
    }

    @objc private func networkToastCloseTapped() {
        dismissNetworkToast(animated: true)
    }

    func getCallStatus() -> CallState {
        return self.callClient.callState
    }

    // MARK: - Timer

    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }

    @objc func updateTime() {
        currentTime += 1

        let remainingTime = maxTime - currentTime

        if remainingTime == 60 {
            DispatchQueue.main.async {
                self.showTimeWarningAlert()
            }
        }

        if currentTime > maxTime {
            timer?.invalidate()
            timer = nil
        } else {
            updateNewTimer(currentTime: currentTime, maxTime: maxTime)
        }
    }

    // MARK: - Microphone & Camera

    @objc func didTapToggleMicrophone() {
        let microphoneIsEnabled = self.callClient.inputs.microphone.isEnabled
        self.callClient.setInputsEnabled([.microphone: !microphoneIsEnabled]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self?.updateControls()
                case .failure(let error):
                    print("didTapToggleMicrophone: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func didTapToggleCamera() {
        guard !isAudioModeOnly else { return } // camera disabled in audio-only mode
        let cameraIsEnabled = self.callClient.inputs.camera.isEnabled
        self.callClient.setInputsEnabled([.camera: !cameraIsEnabled]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self?.updateControls()
                case .failure(let error):
                    print("didTapToggleCamera: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Settings

    var settingsVC: CallSettingsViewController?

    @objc func settingsTapped() {
        let vc = CallSettingsViewController(
            callClient: callClient,
            networkQuality: lastNetworkQuality,
            isAudioModeOnly: isAudioModeOnly
        )
        settingsVC = vc
        present(vc, animated: true)
    }

    // MARK: - End Role Play

    @objc func endRolePlayTapped() {
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.newEndRolePlayButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { [weak self] _ in
            UIView.animate(withDuration: 0.1) {
                self?.newEndRolePlayButton.transform = .identity
            }
        }

        self.newEndRolePlayButton.isEnabled = false
        self.cleanupTurnSystem()
        self.finalizeDocumentShareTracking()

        self.callClient.stopRecording { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async { [weak self] in
                self?.newEndRolePlayButton.isEnabled = true
            }

            switch result {
            case .success(_):
                if let recordingId = self.currentRecordingId {
                    let stopTime = Date().timeIntervalSince1970
                    self.onRecordingStopped?(recordingId, stopTime)
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let participants = self.callClient.participants
                    let localParticipant = participants.local
                    self.removeParticipantView(participantId: localParticipant.id)

                    self.callClient.leave { [weak self] result in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.timer?.invalidate()
                            self.timer = nil
                            self.leave()
                        }
                    }
                }
            case .failure(let error):
                print("Failed to stop recording: \(error.localizedDescription)")
                self.onRecordingError?(error.localizedDescription)
                self.callClient.leave { [weak self] result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.timer?.invalidate()
                        self.timer = nil
                        self.leave()
                    }
                }
            }
        }
    }

    // MARK: - Participant Views

    func updateParticipantView(participantId: ParticipantID, videoTrack: VideoTrack) {
        if let videoView = videoViews[participantId] {
            videoView.track = videoTrack
        } else {
            let videoView = VideoView()
            videoView.translatesAutoresizingMaskIntoConstraints = false
            videoView.track = videoTrack
            videoView.layer.cornerRadius = 12
            videoView.clipsToBounds = true
            videoViews[participantId] = videoView
        }
        attachVideoTrack(videoTrack, for: participantId, isLocal: false)
    }

    func removeParticipantView(participantId: ParticipantID) {
        if let videoView = videoViews[participantId] {
            videoView.removeFromSuperview()
            videoViews.removeValue(forKey: participantId)
        }
    }

    // MARK: - Clipboard

    @objc func copyTextToClipboard() {
        let message = "\(self.roomURLString)?t=\(self.token)"
        UIPasteboard.general.string = message

        let alert = UIAlertController(title: "Copied!", message: "Meeting link has been copied to clipboard.", preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.removeOverlayView()
            }
        }
    }

    // MARK: - Alerts

    func showAlert(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.view.window != nil else { return }

            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.view.tintColor = self.appTextColor
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

            if let alertView = alert.view {
                alertView.layer.cornerRadius = 16
                alertView.backgroundColor = UIColor.white
                alertView.layer.shadowColor = UIColor.black.cgColor
                alertView.layer.shadowOffset = CGSize(width: 0, height: 4)
                alertView.layer.shadowRadius = 8
                alertView.layer.shadowOpacity = 0.1
            }

            self.present(alert, animated: true, completion: nil)
        }
    }

    private func showTimeWarningAlert() {
        let alert = UIAlertController(
            title: "Time Warning",
            message: "Your session will end in 1 minute.",
            preferredStyle: .alert
        )

        alert.view.tintColor = appTextColor
        if let alertView = alert.view {
            alertView.layer.cornerRadius = 16
            alertView.backgroundColor = .white
            alertView.layer.shadowColor = UIColor.black.cgColor
            alertView.layer.shadowOffset = CGSize(width: 0, height: 4)
            alertView.layer.shadowRadius = 8
            alertView.layer.shadowOpacity = 0.1
        }

        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)

        self.present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            alert.dismiss(animated: true)
        }
    }
}
