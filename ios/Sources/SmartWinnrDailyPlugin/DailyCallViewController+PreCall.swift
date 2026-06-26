//
//  DailyCallViewController+PreCall.swift
//  SmartwinnrCapacitorDaily
//
//  Native pre-call screen: lets the user pick the audio route and camera,
//  see a live camera preview, and confirm the microphone is actually
//  capturing (live level meter) BEFORE joining the call. Reuses the single
//  `callClient` for preview, so there is no second-instance device contention.
//

import UIKit
import Daily
import AVFoundation

// MARK: - Audio route helpers

extension AudioDeviceType {
    /// User-facing label for the route picker.
    var displayName: String {
        switch self {
        case .bluetooth:    return "Bluetooth"
        case .speakerphone: return "Speaker"
        case .wired:        return "Wired"
        case .earpiece:     return "Phone"
        @unknown default:   return rawValue.capitalized
        }
    }
}

// MARK: - Pre-call overlay management

extension DailyCallViewController {

    /// Builds and shows the pre-call overlay, enables preview inputs, and starts
    /// the local audio-level observer so the mic meter is live.
    func presentPreCallOverlay() {
        preCallActive = true

        let preCall = PreCallView(
            isAudioModeOnly: isAudioModeOnly,
            userName: userName,
            coachingTitle: coachingTitle
        )
        preCall.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(preCall)
        NSLayoutConstraint.activate([
            preCall.topAnchor.constraint(equalTo: view.topAnchor),
            preCall.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            preCall.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preCall.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        preCallView = preCall

        // Wire user actions back to the live preview client.
        preCall.onSelectRoute = { [weak self] route in
            guard let self = self else { return }
            // Store the choice; it's applied to the Daily SDK at join time
            // (applyPreferredAudioRoute). Pre-join the SDK isn't connected, so
            // we also re-point the AVAudioEngine session at the new route so the
            // meter reflects the selected input.
            self.selectedAudioDevice = route
            self.applyPreCallRouteOverride(route)
        }
        preCall.onFlipCamera = { [weak self] in
            self?.flipPreCallCamera()
        }
        preCall.onJoin = { [weak self] in
            self?.handlePreCallJoin()
        }
        preCall.onCancel = { [weak self] in
            self?.handlePreCallCancel()
        }

        // Enable ONLY the camera for preview WITHOUT joining — this produces the
        // local camera track. The microphone is intentionally NOT enabled on the
        // Daily client here: pre-join, Daily does not capture mic audio and its
        // localAudioLevel observer never fires, so the meter would stay empty.
        // We meter the mic ourselves via AVAudioEngine (see startPreCallMicMonitor),
        // and Daily enables the mic at join time (enableMicrophoneInput).
        if !isAudioModeOnly {
            callClient.setInputsEnabled([.camera: true]) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.callClient.updateInputs(.set(
                        camera: .set(settings: .set(facingMode: .set(self.selectedCameraFacingMode)))
                    ), completion: nil)
                    DispatchQueue.main.async { [weak self] in
                        self?.updatePreCallPreviewTrack()
                    }
                case .failure(let error):
                    print("[AudioDebug] precall setInputsEnabled FAILED: \(error.localizedDescription)")
                }
            }
        }

        // Drive the mic level meter directly from the microphone (works pre-join).
        startPreCallMicMonitor()

        // Populate the route picker from whatever the SDK already knows; the
        // `availableDevicesUpdated` delegate will refine it as devices settle.
        updatePreCallRoutes(from: callClient.availableDevices)
    }

    /// Tears down preview state shared by Join and Cancel.
    private func teardownPreCall() {
        preCallActive = false
        stopPreCallMicMonitor()
        preCallView?.removeFromSuperview()
        preCallView = nil
    }

    /// User confirmed — capture selections (already applied live) and join.
    private func handlePreCallJoin() {
        teardownPreCall()
        proceedToJoin()
    }

    /// User backed out of the call from the pre-call screen.
    private func handlePreCallCancel() {
        teardownPreCall()
        leave()
    }

    /// Flip front/back camera in the live preview.
    private func flipPreCallCamera() {
        guard !isAudioModeOnly else { return }
        selectedCameraFacingMode = (selectedCameraFacingMode == .user) ? .environment : .user
        callClient.updateInputs(.set(
            camera: .set(settings: .set(facingMode: .set(selectedCameraFacingMode)))
        ), completion: nil)
    }

    /// Refresh the audio-route options from the SDK's available devices.
    func updatePreCallRoutes(from devices: Devices) {
        // The SDK lists concrete audio Devices; map them to the high-level
        // route types iOS actually selects between (bluetooth/speaker/wired/
        // earpiece), de-duplicated and in a stable order.
        var routes: [AudioDeviceType] = []
        for device in devices.audio {
            if let type = AudioDeviceType(deviceID: device.deviceID), !routes.contains(type) {
                routes.append(type)
            }
        }
        if routes.isEmpty {
            // Fall back to the route the SDK currently reports as active.
            routes = [callClient.audioDevice]
        }
        let active = selectedAudioDevice ?? callClient.audioDevice
        preCallView?.setRoutes(routes, selected: active)
    }

    /// Bind the local camera preview track into the pre-call view.
    func updatePreCallPreviewTrack() {
        guard preCallActive, !isAudioModeOnly else { return }
        let track = callClient.participants.local.media?.camera.track
        preCallView?.setPreviewTrack(track)
    }

    // MARK: - Pre-call microphone metering

    /// Starts a direct microphone tap (AVAudioEngine) to drive the pre-call level
    /// meter. Needed because Daily's localAudioLevel observer only emits once the
    /// call is connected — before join() it never fires. Gated on mic permission.
    func startPreCallMicMonitor() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            beginPreCallAudioEngine()
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, self.preCallActive else { return }
                    if granted {
                        self.beginPreCallAudioEngine()
                    } else {
                        self.preCallView?.showMicPermissionDenied()
                    }
                }
            }
        case .denied:
            preCallView?.showMicPermissionDenied()
        @unknown default:
            beginPreCallAudioEngine()
        }
    }

    private func beginPreCallAudioEngine() {
        guard preCallActive, preCallAudioEngine == nil else { return }
        // Configure the session AND point its input/output at the selected route
        // so the level meter tests the same device the call will use.
        configurePreCallAudioSession()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // Guard against a 0-channel/0-rate format (can happen if the input route
        // isn't ready yet) — installing a tap with that format would crash.
        guard format.channelCount > 0 else {
            print("[AudioDebug] precall mic monitor: input format not ready")
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            var sumSquares: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(frameCount))
            // Audio level is logarithmic — a linear RMS map keeps the meter pinned
            // near the bottom. Convert to dBFS and map a speech-relevant window
            // (-50 dB silence floor … -10 dB loud) across the full meter range.
            let db = 20 * log10(max(rms, 1e-7))
            let minDb: Float = -50
            let maxDb: Float = -10
            let level = max(0, min(1, (db - minDb) / (maxDb - minDb)))
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.preCallActive else { return }
                self.preCallView?.setMicLevel(level)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            preCallAudioEngine = engine
            print("[AudioDebug] precall mic monitor started")
        } catch {
            print("[AudioDebug] precall mic monitor start FAILED: \(error.localizedDescription)")
            input.removeTap(onBus: 0)
        }
    }

    /// Stops the microphone tap and releases the audio session so the Daily SDK
    /// can take it over cleanly when the call joins.
    func stopPreCallMicMonitor() {
        if let engine = preCallAudioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            preCallAudioEngine = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            print("[AudioDebug] precall mic monitor stopped")
        }
    }

    /// Re-points the pre-call AVAudioSession at the chosen route and restarts the
    /// mic tap, so the level meter actually tests the SAME input device the call
    /// will use (the selection is `selectedAudioDevice`, already set by the caller).
    /// The Daily SDK's own routing is applied at join time via applyPreferredAudioRoute.
    func applyPreCallRouteOverride(_ route: AudioDeviceType) {
        guard preCallActive else { return }
        // Tear down the running tap (without deactivating the session) and rebuild
        // it against the new input — the input format can change between routes,
        // so reusing the old tap could read the wrong device or mismatch format.
        if let engine = preCallAudioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            preCallAudioEngine = nil
        }
        beginPreCallAudioEngine()
    }

    /// Sets the pre-call session category and points its input + output at the
    /// currently `selectedAudioDevice` so the meter tests the chosen device.
    private func configurePreCallAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)

            // Output port: speaker for speakerphone, otherwise the natural route.
            try session.overrideOutputAudioPort(selectedAudioDevice == .speakerphone ? .speaker : .none)

            // Input device: match the selected route so the test is faithful.
            if let route = selectedAudioDevice,
               let input = preferredInputPort(for: route, in: session) {
                try session.setPreferredInput(input)
            } else {
                try session.setPreferredInput(nil) // let iOS pick the default
            }
        } catch {
            print("[AudioDebug] precall audio session config failed: \(error.localizedDescription)")
        }
    }

    /// Maps a Daily audio route to the matching available AVAudioSession input
    /// port, so the pre-call meter captures from the device the user selected.
    private func preferredInputPort(for route: AudioDeviceType,
                                    in session: AVAudioSession) -> AVAudioSessionPortDescription? {
        let inputs = session.availableInputs ?? []
        switch route {
        case .bluetooth:
            return inputs.first { [.bluetoothHFP, .bluetoothLE].contains($0.portType) }
        case .wired:
            return inputs.first { [.headsetMic, .usbAudio, .lineIn].contains($0.portType) }
        case .speakerphone, .earpiece:
            return inputs.first { $0.portType == .builtInMic }
        @unknown default:
            return nil
        }
    }
}

// MARK: - PreCallView

/// Self-contained pre-call UI. Owns its controls and reports user intent via
/// closures; rendering of the live camera track is delegated to a `VideoView`
/// it hosts but the controller supplies the track for.
final class PreCallView: UIView {

    var onJoin: (() -> Void)?
    var onCancel: (() -> Void)?
    var onFlipCamera: (() -> Void)?
    var onSelectRoute: ((AudioDeviceType) -> Void)?

    private let isAudioModeOnly: Bool
    private let brandColor = UIColor(red: 0, green: 0, blue: 201.0/255.0, alpha: 1.0)
    private let textColor = UIColor(red: 9.0/255.0, green: 30.0/255.0, blue: 66.0/255.0, alpha: 1.0)

    private let card = UIView()
    private let previewContainer = UIView()
    private let previewVideoView = VideoView()
    private let avatarLabel = UILabel()
    private let flipButton = UIButton(type: .system)

    // Segmented LED-style audio level meter.
    private let micSegmentsStack = UIStackView()
    private var micSegments: [UIView] = []
    private let micSegmentCount = 24
    private let micInactiveColor = UIColor.systemGray5
    private let micHintLabel = UILabel()

    private let routeControl = UISegmentedControl(items: [])
    private var routes: [AudioDeviceType] = []

    private let joinButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    init(isAudioModeOnly: Bool, userName: String, coachingTitle: String) {
        self.isAudioModeOnly = isAudioModeOnly
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
        buildUI(userName: userName, coachingTitle: coachingTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public updates

    func setPreviewTrack(_ track: VideoTrack?) {
        previewVideoView.track = track
        let hasVideo = track != nil
        previewVideoView.isHidden = !hasVideo
        avatarLabel.isHidden = hasVideo
    }

    func setMicLevel(_ level: Float) {
        // `level` is 0...1. Light up segments proportionally with a green→amber→red
        // gradient, classic audio-meter style.
        let clamped = max(0, min(1, level))
        let activeCount = Int((clamped * Float(micSegmentCount)).rounded())
        for (index, segment) in micSegments.enumerated() {
            segment.backgroundColor = index < activeCount
                ? micColor(forSegment: index)
                : micInactiveColor
        }
        if activeCount > 1 {
            micHintLabel.text = "Microphone is working"
            micHintLabel.textColor = UIColor.systemGreen
        }
    }

    /// Per-segment color: mostly green, easing to amber and red near the top —
    /// reads as a "louder = warmer" level meter.
    private func micColor(forSegment index: Int) -> UIColor {
        let fraction = Float(index) / Float(max(micSegmentCount - 1, 1))
        switch fraction {
        case ..<0.6:  return UIColor.systemGreen
        case ..<0.85: return UIColor.systemYellow
        default:      return UIColor.systemOrange
        }
    }

    /// Shows a clear "mic blocked" state when record permission is denied.
    func showMicPermissionDenied() {
        micHintLabel.text = "Microphone access is off — enable it in Settings"
        micHintLabel.textColor = UIColor.systemRed
        micSegments.forEach { $0.backgroundColor = micInactiveColor }
    }

    func setRoutes(_ routes: [AudioDeviceType], selected: AudioDeviceType) {
        self.routes = routes
        routeControl.removeAllSegments()
        for (index, route) in routes.enumerated() {
            routeControl.insertSegment(withTitle: route.displayName, at: index, animated: false)
        }
        if let selectedIndex = routes.firstIndex(of: selected) {
            routeControl.selectedSegmentIndex = selectedIndex
        } else if !routes.isEmpty {
            routeControl.selectedSegmentIndex = 0
        }
        routeControl.isHidden = routes.count < 2
    }

    // MARK: Actions

    @objc private func joinTapped() { onJoin?() }
    @objc private func cancelTapped() { onCancel?() }
    @objc private func flipTapped() { onFlipCamera?() }

    @objc private func routeChanged() {
        let index = routeControl.selectedSegmentIndex
        guard index >= 0, index < routes.count else { return }
        onSelectRoute?(routes[index])
    }

    // MARK: Layout

    private func buildUI(userName: String, coachingTitle: String) {
        let title = UILabel()
        title.text = "Ready to join?"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textColor
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = coachingTitle
        subtitle.font = .systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = UIColor.systemGray
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 2

        // --- Camera preview ---
        previewContainer.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        previewContainer.layer.cornerRadius = 20
        previewContainer.clipsToBounds = true
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        previewVideoView.videoScaleMode = .fill
        previewVideoView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewVideoView)

        // Audio-only (or no-video) placeholder: a circular avatar initial.
        avatarLabel.text = String(userName.prefix(1)).uppercased()
        avatarLabel.font = .systemFont(ofSize: 48, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = brandColor
        avatarLabel.layer.cornerRadius = 50
        avatarLabel.clipsToBounds = true
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(avatarLabel)

        flipButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        flipButton.tintColor = .white
        flipButton.backgroundColor = UIColor(white: 0, alpha: 0.4)
        flipButton.layer.cornerRadius = 18
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        flipButton.isHidden = isAudioModeOnly
        previewContainer.addSubview(flipButton)

        NSLayoutConstraint.activate([
            previewVideoView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewVideoView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            previewVideoView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewVideoView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),

            avatarLabel.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            avatarLabel.widthAnchor.constraint(equalToConstant: 100),
            avatarLabel.heightAnchor.constraint(equalToConstant: 100),

            flipButton.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 12),
            flipButton.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            flipButton.widthAnchor.constraint(equalToConstant: 36),
            flipButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        // In audio-only mode there is never a camera track — show the avatar.
        if isAudioModeOnly {
            previewVideoView.isHidden = true
            avatarLabel.isHidden = false
        } else {
            previewVideoView.isHidden = true // until the track arrives
            avatarLabel.isHidden = false
        }

        // --- Mic meter (segmented LED-style level indicator) ---
        let micIcon = UIImageView(image: UIImage(systemName: "mic.fill"))
        micIcon.tintColor = brandColor
        micIcon.contentMode = .scaleAspectFit
        micIcon.translatesAutoresizingMaskIntoConstraints = false

        micSegmentsStack.axis = .horizontal
        micSegmentsStack.distribution = .fillEqually
        micSegmentsStack.alignment = .fill
        micSegmentsStack.spacing = 3
        micSegmentsStack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<micSegmentCount {
            let segment = UIView()
            segment.backgroundColor = micInactiveColor
            segment.layer.cornerRadius = 2
            micSegmentsStack.addArrangedSubview(segment)
            micSegments.append(segment)
        }

        // Group the icon + meter in a soft rounded "well" so it reads as a
        // dedicated control rather than a loose bar.
        let micWell = UIView()
        micWell.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
        micWell.layer.cornerRadius = 14
        micWell.layer.borderWidth = 1
        micWell.layer.borderColor = UIColor.systemGray5.cgColor
        micWell.translatesAutoresizingMaskIntoConstraints = false
        micWell.addSubview(micIcon)
        micWell.addSubview(micSegmentsStack)

        NSLayoutConstraint.activate([
            micIcon.leadingAnchor.constraint(equalTo: micWell.leadingAnchor, constant: 14),
            micIcon.centerYAnchor.constraint(equalTo: micWell.centerYAnchor),
            micIcon.widthAnchor.constraint(equalToConstant: 20),
            micIcon.heightAnchor.constraint(equalToConstant: 20),

            micSegmentsStack.leadingAnchor.constraint(equalTo: micIcon.trailingAnchor, constant: 12),
            micSegmentsStack.trailingAnchor.constraint(equalTo: micWell.trailingAnchor, constant: -14),
            micSegmentsStack.centerYAnchor.constraint(equalTo: micWell.centerYAnchor),
            micSegmentsStack.heightAnchor.constraint(equalToConstant: 22),

            micWell.heightAnchor.constraint(equalToConstant: 52),
        ])

        let micRow = micWell

        micHintLabel.text = "Speak to test your microphone"
        micHintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        micHintLabel.textColor = UIColor.systemGray
        micHintLabel.textAlignment = .center

        // --- Audio route ---
        let routeLabel = UILabel()
        routeLabel.text = "Audio output"
        routeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        routeLabel.textColor = UIColor.systemGray

        routeLabel.textAlignment = .center
        routeControl.addTarget(self, action: #selector(routeChanged), for: .valueChanged)
        routeControl.selectedSegmentTintColor = brandColor
        routeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        routeControl.isHidden = true // shown once >= 2 routes exist

        // --- Buttons ---
        joinButton.setTitle("Join Call", for: .normal)
        joinButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.backgroundColor = brandColor
        joinButton.layer.cornerRadius = 12
        joinButton.translatesAutoresizingMaskIntoConstraints = false
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        cancelButton.setTitleColor(UIColor.systemGray, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        // --- Assemble ---
        let stack = UIStackView(arrangedSubviews: [
            title, subtitle, previewContainer, micRow, micHintLabel,
            routeLabel, routeControl, joinButton, cancelButton,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(22, after: subtitle)
        stack.setCustomSpacing(10, after: previewContainer)
        stack.setCustomSpacing(6, after: micRow)
        stack.setCustomSpacing(22, after: micHintLabel)
        stack.setCustomSpacing(8, after: routeLabel)
        stack.setCustomSpacing(24, after: routeControl)
        stack.setCustomSpacing(6, after: joinButton)

        // Centered, width-capped card so the layout stays a tidy modal on iPad
        // instead of stretching the preview tile across the full screen width.
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        addSubview(card)

        // Width cap: prefer 420pt, but never overflow the safe area on a phone.
        let preferredWidth = card.widthAnchor.constraint(equalToConstant: 420)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            preferredWidth,
            card.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            card.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            card.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

            // Preview keeps a consistent 4:3 tile inside the capped card width.
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 0.72),
            joinButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
}
