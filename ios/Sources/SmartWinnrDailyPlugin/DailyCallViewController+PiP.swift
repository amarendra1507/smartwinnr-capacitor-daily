//
//  DailyCallViewController+PiP.swift
//  SmartwinnrCapacitorDaily
//
//  PiP shows profile images (AI avatar large + user avatar small inset)
//  instead of live video streams. Audio continues in background.
//

import UIKit
import Daily
import AVFoundation
import AVKit

extension DailyCallViewController {

    @available(iOS 15.0, *)
    func checkPipSupport() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    // MARK: - Source-view layout helper

    /// Forces the PiP source view (and its ancestors) to finish their
    /// pending layout before calling `startPictureInPicture`. iOS silently
    /// defers PiP start if the source view has zero/stale bounds.
    func ensurePipSourceViewLaidOut() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        newRemoteVideoView.setNeedsLayout()
        newRemoteVideoView.layoutIfNeeded()
        newMainStackView.setNeedsLayout()
        newMainStackView.layoutIfNeeded()
    }

    // MARK: - Ensure Source View is Visible

    private func ensureRemoteVideoVisible() {
        newContentContainerView.alpha = 1.0
        newRemoteVideoView.isHidden = false
        newRemoteVideoView.alpha = 1.0
        newRemoteVideoContainer.isHidden = false
        newRemoteVideoContainer.alpha = 1.0
        remoteTileWrapper.isHidden = false
        remoteTileWrapper.alpha = 1.0
        newMainStackView.isHidden = false
        newMainStackView.alpha = 1.0
        newRemoteVideoView.setNeedsLayout()
        newRemoteVideoView.layoutIfNeeded()
    }

    // MARK: - PiP Content: Profile Images Layout
    // Shows AI profile (large, centered) + user profile (small inset, bottom-right)
    // with names and a subtle "In Call" indicator.

    // MARK: - PiP Content: Live Video Layout (for document-share mode)
    // Renders the actual AI video full-bleed with the local user as a small
    // inset in the bottom-right — like a native video-call PiP. Secondary
    // VideoView instances are used so the main UI's video views are left
    // untouched.

    /// Audio-only mode renders the static profile-avatar PiP; all other
    /// modes (video call with or without document share, video call with
    /// screen share) render the live-video PiP with name + state overlays.
    @available(iOS 15.0, *)
    private func buildPipContent(in pipVC: AVPictureInPictureVideoCallViewController) {
        if isAudioModeOnly {
            buildPipProfileContent(in: pipVC)
        } else {
            buildPipLiveVideoContent(in: pipVC)
        }
    }

    @available(iOS 15.0, *)
    private func buildPipLiveVideoContent(in pipVC: AVPictureInPictureVideoCallViewController) {
        pipVC.view.subviews.forEach { $0.removeFromSuperview() }
        pipVC.view.backgroundColor = .black

        let remoteView = VideoView()
        remoteView.translatesAutoresizingMaskIntoConstraints = false
        remoteView.backgroundColor = .black
        remoteView.track = newRemoteVideoView.track
        pipVC.view.addSubview(remoteView)
        self.pipRemoteVideoView = remoteView

        let localContainer = UIView()
        localContainer.translatesAutoresizingMaskIntoConstraints = false
        localContainer.layer.cornerRadius = 8
        localContainer.layer.borderWidth = 1.5
        localContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        localContainer.clipsToBounds = true
        localContainer.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        pipVC.view.addSubview(localContainer)

        let localView = VideoView()
        localView.translatesAutoresizingMaskIntoConstraints = false
        localView.backgroundColor = .black
        localView.track = newLocalVideoView.track
        localContainer.addSubview(localView)
        self.pipLocalVideoView = localView

        NSLayoutConstraint.activate([
            remoteView.topAnchor.constraint(equalTo: pipVC.view.topAnchor),
            remoteView.leadingAnchor.constraint(equalTo: pipVC.view.leadingAnchor),
            remoteView.trailingAnchor.constraint(equalTo: pipVC.view.trailingAnchor),
            remoteView.bottomAnchor.constraint(equalTo: pipVC.view.bottomAnchor),

            localContainer.trailingAnchor.constraint(equalTo: pipVC.view.trailingAnchor, constant: -6),
            localContainer.bottomAnchor.constraint(equalTo: pipVC.view.bottomAnchor, constant: -6),
            localContainer.widthAnchor.constraint(equalToConstant: 60),
            localContainer.heightAnchor.constraint(equalToConstant: 80),

            localView.topAnchor.constraint(equalTo: localContainer.topAnchor),
            localView.leadingAnchor.constraint(equalTo: localContainer.leadingAnchor),
            localView.trailingAnchor.constraint(equalTo: localContainer.trailingAnchor),
            localView.bottomAnchor.constraint(equalTo: localContainer.bottomAnchor),
        ])

        // --- Overlays: AI name + state, User name + speaking dot ---
        buildPipStatusOverlays(in: pipVC.view, aiHost: remoteView, userHost: localContainer)
        // Seed the current state (falls back to listening if nothing set).
        refreshPipAiStateFromParticipants()
        refreshPipUserSpeakingFromParticipants()
    }

    // MARK: - PiP status overlays (name + state animation)

    @available(iOS 15.0, *)
    private func buildPipStatusOverlays(in hostView: UIView, aiHost: UIView, userHost: UIView) {
        // AI name pill (top-center of the PiP)
        let aiName = UILabel()
        aiName.translatesAutoresizingMaskIntoConstraints = false
        aiName.text = coachName.isEmpty ? "AI Coach" : coachName
        aiName.textColor = .white
        aiName.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        aiName.textAlignment = .center
        aiName.backgroundColor = UIColor(white: 0, alpha: 0.55)
        aiName.layer.cornerRadius = 10
        aiName.layer.masksToBounds = true
        aiName.setContentHuggingPriority(.required, for: .horizontal)
        hostView.addSubview(aiName)
        self.pipAiNameLabel = aiName

        // AI state pill — icon-only, pinned to the bottom-LEFT of the PiP
        // window. The animated icon alone conveys state; no label text.
        let stateContainer = UIView()
        stateContainer.translatesAutoresizingMaskIntoConstraints = false
        stateContainer.backgroundColor = UIColor(white: 0, alpha: 0.55)
        stateContainer.layer.cornerRadius = 10
        stateContainer.layer.masksToBounds = true
        hostView.addSubview(stateContainer)
        self.pipAiStateContainer = stateContainer

        let stateIcon = UIView()
        stateIcon.translatesAutoresizingMaskIntoConstraints = false
        stateIcon.backgroundColor = .clear
        stateContainer.addSubview(stateIcon)
        self.pipAiStateIcon = stateIcon

        // Keep an off-screen label so the existing render code that writes
        // into it continues to work without conditionals. It's not added as
        // a subview, so it never appears on screen.
        self.pipAiStateLabel = UILabel()

        NSLayoutConstraint.activate([
            aiName.topAnchor.constraint(equalTo: hostView.topAnchor, constant: 6),
            aiName.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            aiName.heightAnchor.constraint(equalToConstant: 20),
            aiName.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.leadingAnchor, constant: 8),
            aiName.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -8),

            stateContainer.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: 6),
            stateContainer.bottomAnchor.constraint(equalTo: hostView.bottomAnchor, constant: -6),
            stateContainer.heightAnchor.constraint(equalToConstant: 22),
            stateContainer.widthAnchor.constraint(equalToConstant: 28),

            stateIcon.centerXAnchor.constraint(equalTo: stateContainer.centerXAnchor),
            stateIcon.centerYAnchor.constraint(equalTo: stateContainer.centerYAnchor),
            stateIcon.widthAnchor.constraint(equalToConstant: 16),
            stateIcon.heightAnchor.constraint(equalToConstant: 12),
        ])

        // Pad label text with spaces so the pill has breathing room.
        aiName.text = "  \(aiName.text ?? "")  "

        // User name + speaking dot, positioned above the local inset tile.
        let userName = UILabel()
        userName.translatesAutoresizingMaskIntoConstraints = false
        userName.text = "  \(self.userName.isEmpty ? "You" : self.userName)  "
        userName.textColor = .white
        userName.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        userName.textAlignment = .center
        userName.backgroundColor = UIColor(white: 0, alpha: 0.55)
        userName.layer.cornerRadius = 8
        userName.layer.masksToBounds = true
        hostView.addSubview(userName)
        self.pipUserNameLabel = userName

        let userDot = UIView()
        userDot.translatesAutoresizingMaskIntoConstraints = false
        userDot.backgroundColor = UIColor.systemGreen
        userDot.layer.cornerRadius = 4
        userDot.isHidden = true
        hostView.addSubview(userDot)
        self.pipUserSpeakingDot = userDot

        NSLayoutConstraint.activate([
            userName.bottomAnchor.constraint(equalTo: userHost.topAnchor, constant: -4),
            userName.trailingAnchor.constraint(equalTo: userHost.trailingAnchor),
            userName.heightAnchor.constraint(equalToConstant: 16),

            userDot.centerYAnchor.constraint(equalTo: userName.centerYAnchor),
            userDot.trailingAnchor.constraint(equalTo: userName.leadingAnchor, constant: -4),
            userDot.widthAnchor.constraint(equalToConstant: 8),
            userDot.heightAnchor.constraint(equalToConstant: 8),
        ])

        renderPipAiStateVisuals(state: currentPipAiState)
    }

    /// Apply state name + icon animation into the existing state container.
    func renderPipAiStateVisuals(state: PipAiState) {
        guard let icon = pipAiStateIcon, let label = pipAiStateLabel else { return }
        icon.subviews.forEach { $0.removeFromSuperview() }
        icon.layer.removeAllAnimations()

        switch state {
        case .listening:
            label.text = "Listening"
            // Simple static mic-ish dot.
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = UIColor.white.withAlphaComponent(0.8)
            dot.layer.cornerRadius = 3
            icon.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: icon.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6),
            ])

        case .thinking:
            label.text = "Thinking"
            // Three pulsing dots (cascading opacity).
            let colors = [UIColor.systemPurple, UIColor.systemBlue, UIColor.systemTeal]
            for i in 0..<3 {
                let d = UIView()
                d.translatesAutoresizingMaskIntoConstraints = false
                d.backgroundColor = colors[i].withAlphaComponent(0.95)
                d.layer.cornerRadius = 2
                icon.addSubview(d)
                NSLayoutConstraint.activate([
                    d.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
                    d.leadingAnchor.constraint(equalTo: icon.leadingAnchor, constant: CGFloat(i * 5)),
                    d.widthAnchor.constraint(equalToConstant: 4),
                    d.heightAnchor.constraint(equalToConstant: 4),
                ])
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.fromValue = 0.3
                anim.toValue = 1.0
                anim.duration = 0.6
                anim.autoreverses = true
                anim.repeatCount = .infinity
                anim.beginTime = CACurrentMediaTime() + Double(i) * 0.18
                d.layer.add(anim, forKey: "pulse")
            }

        case .speaking:
            label.text = "Speaking"
            // Three bouncing bars (audio-equalizer).
            for i in 0..<3 {
                let bar = UIView()
                bar.translatesAutoresizingMaskIntoConstraints = false
                bar.backgroundColor = UIColor.systemGreen
                bar.layer.cornerRadius = 1
                icon.addSubview(bar)
                NSLayoutConstraint.activate([
                    bar.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
                    bar.leadingAnchor.constraint(equalTo: icon.leadingAnchor, constant: CGFloat(i * 5)),
                    bar.widthAnchor.constraint(equalToConstant: 3),
                    bar.heightAnchor.constraint(equalToConstant: 10),
                ])
                let anim = CABasicAnimation(keyPath: "transform.scale.y")
                anim.fromValue = 0.4
                anim.toValue = 1.2
                anim.duration = 0.35
                anim.autoreverses = true
                anim.repeatCount = .infinity
                anim.beginTime = CACurrentMediaTime() + Double(i) * 0.12
                bar.layer.add(anim, forKey: "eq")
            }
        }
    }

    /// Public setter called from the speaking/thinking state machine.
    /// Idempotent — only re-renders the visuals when the state changes.
    func updatePipAiState(_ state: PipAiState) {
        guard state != currentPipAiState else { return }
        currentPipAiState = state
        DispatchQueue.main.async { [weak self] in
            self?.renderPipAiStateVisuals(state: state)
        }
    }

    func updatePipUserSpeaking(_ isSpeaking: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.pipUserSpeakingDot?.isHidden = !isSpeaking
        }
    }

    /// Read the current participant state map and update PiP accordingly.
    /// Called on PiP (re)build so state is correct even mid-conversation.
    func refreshPipAiStateFromParticipants() {
        if isAnyAiSpeaking() {
            updatePipAiState(.speaking)
        } else if participantStates.values.contains(where: { !$0.id.contains("local") && $0.isThinking }) {
            updatePipAiState(.thinking)
        } else {
            updatePipAiState(.listening)
        }
    }

    func refreshPipUserSpeakingFromParticipants() {
        updatePipUserSpeaking(isAnyUserSpeaking())
    }

    @available(iOS 15.0, *)
    private func buildPipProfileContent(in pipVC: AVPictureInPictureVideoCallViewController) {
        pipVC.view.subviews.forEach { $0.removeFromSuperview() }

        // Dark gradient background
        let bgView = UIView()
        bgView.translatesAutoresizingMaskIntoConstraints = false
        pipVC.view.addSubview(bgView)

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 1.0).cgColor,
            UIColor(red: 0.14, green: 0.18, blue: 0.28, alpha: 1.0).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        bgView.layer.insertSublayer(gradient, at: 0)

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: pipVC.view.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: pipVC.view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: pipVC.view.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: pipVC.view.bottomAnchor),
        ])

        // Resize gradient on layout
        bgView.accessibilityIdentifier = "pip_bg"

        // --- AI Avatar (large, centered) ---
        let aiSize: CGFloat = 72
        let aiAvatar = UIImageView()
        aiAvatar.contentMode = .scaleAspectFill
        aiAvatar.clipsToBounds = true
        aiAvatar.layer.cornerRadius = aiSize / 2
        aiAvatar.layer.borderWidth = 2.5
        aiAvatar.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        aiAvatar.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(aiAvatar)

        // Load AI image
        if let urlStr = coachProfileImageURL, let url = URL(string: urlStr) {
            loadProfileImage(from: url) { [weak aiAvatar] img in
                DispatchQueue.main.async { aiAvatar?.image = img }
            }
        } else if let img = coachProfileImage {
            aiAvatar.image = img
        } else {
            aiAvatar.image = generateDefaultProfileImage(for: coachName)
        }

        // AI name label
        let aiName = UILabel()
        aiName.text = coachName
        aiName.textColor = .white
        aiName.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        aiName.textAlignment = .center
        aiName.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(aiName)

        // Pulsing ring around AI avatar (indicates active call)
        let pulseRing = UIView()
        pulseRing.layer.cornerRadius = (aiSize + 12) / 2
        pulseRing.layer.borderWidth = 1.5
        pulseRing.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.4).cgColor
        pulseRing.backgroundColor = .clear
        pulseRing.translatesAutoresizingMaskIntoConstraints = false
        bgView.insertSubview(pulseRing, belowSubview: aiAvatar)

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.95
        pulse.toValue = 1.08
        pulse.duration = 2.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseRing.layer.add(pulse, forKey: "pip_pulse")

        NSLayoutConstraint.activate([
            aiAvatar.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            aiAvatar.centerYAnchor.constraint(equalTo: bgView.centerYAnchor, constant: -12),
            aiAvatar.widthAnchor.constraint(equalToConstant: aiSize),
            aiAvatar.heightAnchor.constraint(equalToConstant: aiSize),

            pulseRing.centerXAnchor.constraint(equalTo: aiAvatar.centerXAnchor),
            pulseRing.centerYAnchor.constraint(equalTo: aiAvatar.centerYAnchor),
            pulseRing.widthAnchor.constraint(equalToConstant: aiSize + 12),
            pulseRing.heightAnchor.constraint(equalToConstant: aiSize + 12),

            aiName.topAnchor.constraint(equalTo: aiAvatar.bottomAnchor, constant: 6),
            aiName.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            aiName.leadingAnchor.constraint(greaterThanOrEqualTo: bgView.leadingAnchor, constant: 8),
            aiName.trailingAnchor.constraint(lessThanOrEqualTo: bgView.trailingAnchor, constant: -8),
        ])

        // --- User Avatar (small inset, bottom-right) ---
        let userSize: CGFloat = 36
        let pad: CGFloat = 8

        let userContainer = UIView()
        userContainer.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        userContainer.layer.cornerRadius = 8
        userContainer.layer.borderWidth = 1
        userContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        userContainer.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(userContainer)

        let userAvatar = UIImageView()
        userAvatar.contentMode = .scaleAspectFill
        userAvatar.clipsToBounds = true
        userAvatar.layer.cornerRadius = userSize / 2
        userAvatar.layer.borderWidth = 1.5
        userAvatar.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        userAvatar.translatesAutoresizingMaskIntoConstraints = false
        userContainer.addSubview(userAvatar)

        // Load user image
        if let urlStr = userProfileImageURL, let url = URL(string: urlStr) {
            loadProfileImage(from: url) { [weak userAvatar] img in
                DispatchQueue.main.async { userAvatar?.image = img }
            }
        } else if let img = userProfileImage {
            userAvatar.image = img
        } else {
            userAvatar.image = generateDefaultProfileImage(for: userName)
        }

        let userName = UILabel()
        userName.text = self.userName
        userName.textColor = UIColor.white.withAlphaComponent(0.8)
        userName.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        userName.translatesAutoresizingMaskIntoConstraints = false
        userContainer.addSubview(userName)

        NSLayoutConstraint.activate([
            userContainer.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -pad),
            userContainer.bottomAnchor.constraint(equalTo: bgView.bottomAnchor, constant: -pad),

            userAvatar.leadingAnchor.constraint(equalTo: userContainer.leadingAnchor, constant: 5),
            userAvatar.centerYAnchor.constraint(equalTo: userContainer.centerYAnchor),
            userAvatar.widthAnchor.constraint(equalToConstant: userSize),
            userAvatar.heightAnchor.constraint(equalToConstant: userSize),

            userName.leadingAnchor.constraint(equalTo: userAvatar.trailingAnchor, constant: 5),
            userName.trailingAnchor.constraint(equalTo: userContainer.trailingAnchor, constant: -6),
            userName.centerYAnchor.constraint(equalTo: userContainer.centerYAnchor),

            userContainer.topAnchor.constraint(equalTo: userAvatar.topAnchor, constant: -4),
            userContainer.bottomAnchor.constraint(equalTo: userAvatar.bottomAnchor, constant: 4),
        ])

        // --- "In Call" indicator (top-left) ---
        let callBadge = UIView()
        callBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
        callBadge.layer.cornerRadius = 8
        callBadge.layer.borderWidth = 1
        callBadge.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        callBadge.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(callBadge)

        let callDot = UIView()
        callDot.backgroundColor = UIColor.systemGreen
        callDot.layer.cornerRadius = 3
        callDot.translatesAutoresizingMaskIntoConstraints = false
        callBadge.addSubview(callDot)

        let callLabel = UILabel()
        callLabel.text = "In Call"
        callLabel.textColor = UIColor.systemGreen
        callLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        callLabel.translatesAutoresizingMaskIntoConstraints = false
        callBadge.addSubview(callLabel)

        // Blink the dot
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1.0
        blink.toValue = 0.3
        blink.duration = 1.0
        blink.autoreverses = true
        blink.repeatCount = .infinity
        callDot.layer.add(blink, forKey: "blink")

        NSLayoutConstraint.activate([
            callBadge.topAnchor.constraint(equalTo: bgView.topAnchor, constant: 6),
            callBadge.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 6),

            callDot.leadingAnchor.constraint(equalTo: callBadge.leadingAnchor, constant: 6),
            callDot.centerYAnchor.constraint(equalTo: callBadge.centerYAnchor),
            callDot.widthAnchor.constraint(equalToConstant: 6),
            callDot.heightAnchor.constraint(equalToConstant: 6),

            callLabel.leadingAnchor.constraint(equalTo: callDot.trailingAnchor, constant: 4),
            callLabel.trailingAnchor.constraint(equalTo: callBadge.trailingAnchor, constant: -6),
            callLabel.topAnchor.constraint(equalTo: callBadge.topAnchor, constant: 3),
            callLabel.bottomAnchor.constraint(equalTo: callBadge.bottomAnchor, constant: -3),
        ])

        // Resize gradient layer when layout changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            gradient.frame = bgView.bounds
        }
    }

    // MARK: - Setup

    /// Idempotent install of a didBecomeActive observer that re-arms PiP
    /// when the user returns to the app. Fixes the case where the user
    /// closes the floating PiP and the window never restarts.
    func installPipReentryObserverIfNeeded() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActiveForPiP),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc func handleAppDidBecomeActiveForPiP() {
        print("[PiP] app didBecomeActive — screenSharing=\(isScreenSharingActive) docShare=\(documentShareActivated)")
        guard isScreenSharingActive, documentShareActivated else { return }
        if #available(iOS 15.0, *) {
            if let ctrl = pipControllerStorage as? AVPictureInPictureController,
               ctrl.isPictureInPictureActive {
                print("[PiP] already active on re-entry — no-op")
                return
            }
            // Controller may have been torn down by iOS when PiP was dismissed;
            // rebuild if needed.
            if pipControllerStorage == nil {
                print("[PiP] re-entry: rebuilding controller")
                setupPictureInPicture()
            } else {
                print("[PiP] re-entry: reusing existing controller")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.attemptPipStart()
            }
        }
    }

    @available(iOS 15.0, *)
    func setupPictureInPicture() {
        print("[PiP] setupPictureInPicture called")
        installPipReentryObserverIfNeeded()
        guard checkPipSupport() else {
            print("[PiP] setup ABORTED: PiP not supported on this device")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            print("[PiP] AudioSession OK — category=playAndRecord mode=voiceChat active=\(session.isOtherAudioPlaying == false)")
        } catch {
            print("[PiP] AudioSession ERROR: \(error.localizedDescription)")
        }

        ensureRemoteVideoVisible()

        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 320, height: 240)
        pipVideoCallViewControllerStorage = pipVC

        buildPipContent(in: pipVC)

        // Source view still needed for PiP system (animation origin)
        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: newRemoteVideoView,
            contentViewController: pipVC
        )

        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = false
        pipControllerStorage = controller

        print("[PiP] controller created — sourceBounds=\(newRemoteVideoView.bounds) sourceHidden=\(newRemoteVideoView.isHidden) sourceAlpha=\(newRemoteVideoView.alpha) sourceSuperviewHidden=\(newMainStackView.isHidden) documentShareActivated=\(documentShareActivated)")

        pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
            [weak self] ctrl, _ in
            print("[PiP] KVO: isPictureInPicturePossible=\(ctrl.isPictureInPicturePossible) isActive=\(ctrl.isPictureInPictureActive) isScreenSharing=\(self?.isScreenSharingActive ?? false)")
            if ctrl.isPictureInPicturePossible, let self = self, self.isScreenSharingActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !ctrl.isPictureInPictureActive {
                        print("[PiP] KVO-triggered start attempt")
                        ctrl.startPictureInPicture()
                    }
                }
            }
        }
    }

    @available(iOS 15.0, *)
    func updatePipProfileOverlay() {
        guard let pipVC = pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController else { return }
        buildPipContent(in: pipVC)
    }

    // MARK: - Start / Stop / Retry

    @available(iOS 15.0, *)
    func startPictureInPicture() {
        print("[PiP] startPictureInPicture() called — controllerExists=\(pipControllerStorage != nil) documentShareActivated=\(documentShareActivated)")
        ensureRemoteVideoVisible()

        if pipControllerStorage == nil {
            setupPictureInPicture()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.attemptPipStart()
            }
            return
        }

        // Refresh content
        if let pipVC = pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController {
            buildPipContent(in: pipVC)
        }
        attemptPipStart()
    }

    @available(iOS 15.0, *)
    func attemptPipStart() {
        guard let controller = pipControllerStorage as? AVPictureInPictureController else {
            print("[PiP] attemptPipStart ABORTED: no controller")
            return
        }
        if controller.isPictureInPictureActive {
            print("[PiP] attemptPipStart: already active — done")
            pipStartRetryCount = 0
            return
        }
        ensurePipSourceViewLaidOut()
        let sceneState: String = {
            if let scene = view.window?.windowScene {
                switch scene.activationState {
                case .foregroundActive: return "foregroundActive"
                case .foregroundInactive: return "foregroundInactive"
                case .background: return "background"
                case .unattached: return "unattached"
                @unknown default: return "unknown"
                }
            }
            return "noScene"
        }()
        print("[PiP] attemptPipStart — possible=\(controller.isPictureInPicturePossible) active=\(controller.isPictureInPictureActive) retry=\(pipStartRetryCount) sourceBounds=\(newRemoteVideoView.bounds) sourceHidden=\(newRemoteVideoView.isHidden) stackHidden=\(newMainStackView.isHidden) sceneState=\(sceneState) isScreenSharing=\(isScreenSharingActive)")
        // iOS silently no-ops startPictureInPicture() while the scene is
        // `foregroundInactive` (which happens for several seconds after a
        // broadcast starts). Wait for `foregroundActive` — faster + cleaner
        // than hammering `startPictureInPicture` during the inactive window.
        guard sceneState == "foregroundActive" else {
            pipStartRetryCount += 1
            guard pipStartRetryCount < pipMaxRetries else {
                print("[PiP] retry EXHAUSTED waiting for foregroundActive")
                pipStartRetryCount = 0
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.attemptPipStart()
            }
            return
        }
        if controller.isPictureInPicturePossible {
            pipStartRetryCount = 0
            print("[PiP] → calling controller.startPictureInPicture()")
            controller.startPictureInPicture()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self,
                      let ctrl = self.pipControllerStorage as? AVPictureInPictureController else { return }
                print("[PiP] post-start verify — isActive=\(ctrl.isPictureInPictureActive)")
                if !ctrl.isPictureInPictureActive {
                    self.attemptPipStart()
                }
            }
        } else {
            pipStartRetryCount += 1
            guard pipStartRetryCount < pipMaxRetries else {
                print("[PiP] retry EXHAUSTED after \(pipStartRetryCount) attempts")
                pipStartRetryCount = 0
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.attemptPipStart()
            }
        }
    }

    @available(iOS 15.0, *)
    func stopPictureInPicture() {
        guard let controller = pipControllerStorage as? AVPictureInPictureController else { return }
        if controller.isPictureInPictureActive { controller.stopPictureInPicture() }
        stopVideoRenderingMonitor()
    }

    // MARK: - Rendering Monitor

    func startVideoRenderingMonitor() {
        stopVideoRenderingMonitor()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {}

        videoRenderingMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.newRemoteVideoView.isHidden = false
                self.newRemoteVideoView.alpha = 1.0
                self.newContentContainerView.alpha = 1.0

                // Resize gradient in PiP content if needed
                if #available(iOS 15.0, *) {
                    if let pipVC = self.pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController,
                       let bgView = pipVC.view.subviews.first(where: { $0.accessibilityIdentifier == "pip_bg" }),
                       let gradientLayer = bgView.layer.sublayers?.first as? CAGradientLayer {
                        gradientLayer.frame = bgView.bounds
                    }
                }
            }
        }
    }

    func stopVideoRenderingMonitor() {
        videoRenderingMonitorTimer?.invalidate()
        videoRenderingMonitorTimer = nil
    }

    // MARK: - Helpers

    func loadProfileImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data, let image = UIImage(data: data) else { completion(nil); return }
            completion(image)
        }.resume()
    }

    func generateDefaultProfileImage(for name: String) -> UIImage? {
        let initials = name.components(separatedBy: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        let size = CGSize(width: 80, height: 80)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 32, weight: .bold), .foregroundColor: UIColor.white]
            let ts = initials.size(withAttributes: attrs)
            initials.draw(in: CGRect(x: (size.width-ts.width)/2, y: (size.height-ts.height)/2, width: ts.width, height: ts.height), withAttributes: attrs)
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

@available(iOS 15.0, *)
extension DailyCallViewController: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] delegate: willStart")
        ensureRemoteVideoVisible()
        if let pipVC = pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController {
            buildPipContent(in: pipVC)
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] delegate: didStart ✅ inline PiP active")
        startVideoRenderingMonitor()
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        let ns = error as NSError
        print("[PiP] delegate: failedToStart ❌ domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) userInfo=\(ns.userInfo)")
        // Retry a couple of times — silent fails happen when the source
        // view hasn't laid out yet or the audio session hasn't activated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            guard let ctrl = self.pipControllerStorage as? AVPictureInPictureController else { return }
            if !ctrl.isPictureInPictureActive {
                self.ensurePipSourceViewLaidOut()
                self.attemptPipStart()
            }
        }
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] delegate: willStop")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] delegate: didStop")
        stopVideoRenderingMonitor()
        // Release the secondary live-video views so track updates stop
        // being mirrored into a detached PiP hierarchy.
        pipRemoteVideoView?.track = nil
        pipLocalVideoView?.track = nil
        pipRemoteVideoView = nil
        pipLocalVideoView = nil

        // Auto-re-arm: if screen-share is still running and the app is
        // foreground-active, rebuild and restart PiP so the floating window
        // stays visible across open/close cycles. Applies to both
        // document-share mode and plain video-mode screen share.
        guard isScreenSharingActive else {
            print("[PiP] didStop: not re-arming — screenShare=\(isScreenSharingActive)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self = self else { return }
            let sceneIsActive: Bool = {
                guard let scene = self.view.window?.windowScene else { return false }
                return scene.activationState == .foregroundActive
            }()
            guard sceneIsActive else {
                print("[PiP] didStop re-arm: scene not foregroundActive — letting iOS auto-resume on next background")
                return
            }
            if let ctrl = self.pipControllerStorage as? AVPictureInPictureController,
               ctrl.isPictureInPictureActive {
                print("[PiP] didStop re-arm: already active — skip")
                return
            }
            print("[PiP] didStop re-arm: rebuilding controller and starting")
            self.pipPossibleObservation?.invalidate()
            self.pipControllerStorage = nil
            self.pipVideoCallViewControllerStorage = nil
            if #available(iOS 15.0, *) {
                self.setupPictureInPicture()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    self?.attemptPipStart()
                }
            }
        }
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}
