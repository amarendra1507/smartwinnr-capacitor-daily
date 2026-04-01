//
//  DailyCallViewController+Speaking.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
//

import UIKit
import Daily

// MARK: - Data Models

struct DailyParticipant {
    let id: String
    let name: String
    var isSpeaking: Bool
    var isThinking: Bool
    var isActiveSpeaker: Bool
    var lastSpokenAt: TimeInterval
    var turnNumber: Int

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.isSpeaking = false
        self.isThinking = false
        self.isActiveSpeaker = false
        self.lastSpokenAt = 0
        self.turnNumber = 0
    }
}

struct TurnRecord {
    let turn: Int
    let speaker: String
    let speakerName: String
    let action: String
    let timestamp: TimeInterval
    let duration: TimeInterval?
}

// MARK: - Speaking State Management

extension DailyCallViewController {

    func updateParticipantSpeakingState(participantId: ParticipantID, isSpeaking: Bool, isLocal: Bool) {
        guard var participant = participantStates[participantId] else { return }

        let wasSpeaking = participant.isSpeaking
        participant.isSpeaking = isSpeaking
        participant.isActiveSpeaker = isSpeaking
        participantStates[participantId] = participant

        if isSpeaking {
            participant.isThinking = false
            participantStates[participantId] = participant
            stopThinkingAnimation(for: participantId)
        }

        updateSpeakingIndicator(for: participantId, isSpeaking: isSpeaking)

        if isSpeaking && !wasSpeaking {
            if isLocal {
                if isAnyAiSpeaking() {
                    forceStopBotSpeakingAnimations()
                }
                handleUserStartedSpeaking(participantId: participantId)
            } else {
                handleAiStartedSpeaking(participantId: participantId)
            }
        } else if !isSpeaking && wasSpeaking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let currentParticipant = self.participantStates[participantId], !currentParticipant.isSpeaking {
                    if isLocal {
                        self.handleUserStoppedSpeaking(participantId: participantId)
                    } else {
                        self.handleAiStoppedSpeaking(participantId: participantId)
                    }
                }
            }
        }
    }

    func setAiThinkingState(isThinking: Bool) {
        if isThinking && (isAnyUserSpeaking() || isAnyAiSpeaking()) {
            return
        }

        for (participantId, var participant) in participantStates {
            let isLocalParticipant = participantId == callClient.participants.local.id
            let isAiParticipant = !participant.id.contains("local") && !isLocalParticipant

            if isAiParticipant {
                if !participant.isSpeaking {
                    participant.isThinking = isThinking
                    participantStates[participantId] = participant

                    if isThinking {
                        startThinkingAnimation(for: participantId)
                    } else {
                        stopThinkingAnimation(for: participantId)
                    }
                }
            }
        }
    }

    func isAnyAiSpeaking() -> Bool {
        return participantStates.values.contains { participant in
            !participant.id.contains("local") && participant.isSpeaking
        }
    }

    func isAnyUserSpeaking() -> Bool {
        return participantStates.values.contains { participant in
            participant.id.contains("local") && participant.isSpeaking
        }
    }

    func forceStopBotSpeakingAnimations() {
        for (participantId, var participant) in participantStates {
            let isLocalParticipant = participantId == callClient.participants.local.id
            let isAiParticipant = !participant.id.contains("local") && !isLocalParticipant

            if isAiParticipant && participant.isSpeaking {
                participant.isSpeaking = false
                participant.isActiveSpeaker = false
                participantStates[participantId] = participant
                updateSpeakingIndicator(for: participantId, isSpeaking: false)
                stopThinkingAnimation(for: participantId)
            }
        }
    }

    // MARK: - Visual Indicators

    func updateSpeakingIndicator(for participantId: ParticipantID, isSpeaking: Bool) {
        let isLocalParticipant = participantId == callClient.participants.local.id
        let videoContainer = isLocalParticipant ? newLocalVideoContainer : newRemoteVideoContainer
        let indicatorRow = isLocalParticipant ? localIndicatorRow : remoteIndicatorRow

        // In audio-only mode, animate on the avatar view (it covers the container)
        // In video mode, animate on the video container itself
        let targetView: UIView
        if isAudioModeOnly {
            let avatar = isLocalParticipant ? localAvatarView : remoteAvatarView
            avatar.layer.masksToBounds = false // allow shadow to render outside bounds
            targetView = avatar
        } else {
            targetView = videoContainer
        }

        if isSpeaking {
            targetView.layer.borderColor = UIColor.systemBlue.cgColor
            targetView.layer.borderWidth = 3.0
            targetView.layer.shadowColor = UIColor.systemBlue.cgColor
            targetView.layer.shadowRadius = 15.0
            targetView.layer.shadowOpacity = 0.6
            targetView.layer.shadowOffset = CGSize.zero

            let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            pulseAnimation.duration = 2.0
            pulseAnimation.fromValue = 0.6
            pulseAnimation.toValue = 0.8
            pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = .infinity
            targetView.layer.add(pulseAnimation, forKey: "speaking_pulse")

            addSpeakingPill(to: indicatorRow, participantId: participantId)
        } else {
            if isAudioModeOnly {
                // Restore avatar default — no border, clip content
                targetView.layer.borderColor = UIColor.clear.cgColor
                targetView.layer.borderWidth = 0
                targetView.layer.shadowOpacity = 0
                targetView.layer.masksToBounds = true
            } else {
                // Restore video container default card style
                targetView.layer.borderColor = UIColor.systemGray4.cgColor
                targetView.layer.borderWidth = 1
                targetView.layer.shadowColor = UIColor.black.cgColor
                targetView.layer.shadowRadius = 8
                targetView.layer.shadowOpacity = 0.12
                targetView.layer.shadowOffset = CGSize(width: 0, height: 2)
            }
            targetView.layer.removeAnimation(forKey: "speaking_pulse")

            removeSpeakingPill(from: indicatorRow, participantId: participantId)
        }
    }

    // Match web: .speaking-indicator pill with mic icon + eq bars
    private func addSpeakingPill(to indicatorRow: UIView, participantId: ParticipantID) {
        let tag = "speaking_pill_\(participantId)"
        // Don't add duplicate
        if indicatorRow.subviews.contains(where: { $0.accessibilityIdentifier == tag }) { return }

        let pill = UIView()
        pill.accessibilityIdentifier = tag
        pill.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 0.1) // rgba(16,185,129,0.1)
        pill.layer.cornerRadius = 14
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 0.2).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        // Mic icon
        let micIcon = UIImageView(image: UIImage(systemName: "mic.fill"))
        micIcon.tintColor = UIColor(red: 0.02, green: 0.59, blue: 0.41, alpha: 1.0) // #059669
        micIcon.contentMode = .scaleAspectFit
        micIcon.translatesAutoresizingMaskIntoConstraints = false

        // Eq bars — animate height constraints (CAAnimation + Auto Layout don't mix)
        let barsStack = UIStackView()
        barsStack.axis = .horizontal
        barsStack.spacing = 2
        barsStack.alignment = .bottom
        barsStack.translatesAutoresizingMaskIntoConstraints = false

        let maxH: [CGFloat] = [5, 10, 7, 12]
        let minH: [CGFloat] = [2, 3, 2, 4]
        var barHeightConstraints: [NSLayoutConstraint] = []

        for i in 0..<4 {
            let bar = UIView()
            bar.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
            bar.layer.cornerRadius = 1.5
            bar.translatesAutoresizingMaskIntoConstraints = false
            barsStack.addArrangedSubview(bar)
            let hc = bar.heightAnchor.constraint(equalToConstant: maxH[i])
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 3),
                hc,
            ])
            barHeightConstraints.append(hc)
        }

        // Looping height animation
        func animateEqBars() {
            for (i, hc) in barHeightConstraints.enumerated() {
                UIView.animate(withDuration: 0.25, delay: Double(i) * 0.08, options: [.curveEaseInOut]) {
                    hc.constant = minH[i]
                    barsStack.layoutIfNeeded()
                } completion: { _ in
                    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
                        hc.constant = maxH[i]
                        barsStack.layoutIfNeeded()
                    }
                }
            }
        }

        // Tag the timer so we can stop it when pill is removed
        let eqTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak barsStack] timer in
            guard barsStack?.window != nil else { timer.invalidate(); return }
            animateEqBars()
        }
        // Store timer reference on the pill for cleanup
        objc_setAssociatedObject(pill, UnsafeRawPointer(bitPattern: 1)!, eqTimer, .OBJC_ASSOCIATION_RETAIN)

        // Initial kick
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animateEqBars() }

        pill.addSubview(micIcon)
        pill.addSubview(barsStack)

        indicatorRow.addSubview(pill)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: indicatorRow.leadingAnchor),
            pill.centerYAnchor.constraint(equalTo: indicatorRow.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 28),
            micIcon.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            micIcon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            micIcon.widthAnchor.constraint(equalToConstant: 14),
            micIcon.heightAnchor.constraint(equalToConstant: 14),
            barsStack.leadingAnchor.constraint(equalTo: micIcon.trailingAnchor, constant: 5),
            barsStack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            barsStack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
        ])

        pill.alpha = 0
        pill.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3) {
            pill.alpha = 1
            pill.transform = .identity
        }
    }

    private func removeSpeakingPill(from indicatorRow: UIView, participantId: ParticipantID) {
        let tag = "speaking_pill_\(participantId)"
        for subview in indicatorRow.subviews where subview.accessibilityIdentifier == tag {
            // Stop the eq animation timer
            if let timer = objc_getAssociatedObject(subview, UnsafeRawPointer(bitPattern: 1)!) as? Timer {
                timer.invalidate()
            }
            UIView.animate(withDuration: 0.2, animations: {
                subview.alpha = 0
                subview.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                subview.removeFromSuperview()
            }
        }
    }

    func getVideoViewForParticipant(_ participantId: ParticipantID) -> VideoView? {
        if participantId == callClient.participants.local.id {
            return newLocalVideoView
        }
        return newRemoteVideoView
    }

    // MARK: - Thinking Animations
    // Match web: .thinking-indicator with .thinking-orb (3 purple dots)

    func startThinkingAnimation(for participantId: ParticipantID) {
        let isLocal = participantId == callClient.participants.local.id
        if isLocal { return }

        let tag = "thinking_\(participantId)"
        // Don't add duplicate
        if remoteIndicatorRow.subviews.contains(where: { $0.accessibilityIdentifier == tag }) { return }

        // Match web: .thinking-indicator pill with purple orb dots
        let pill = UIView()
        pill.accessibilityIdentifier = tag
        pill.backgroundColor = UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 0.1) // rgba(139,92,246,0.1)
        pill.layer.cornerRadius = 14
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 0.2).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        // 3 orb dots
        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 4
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false

        let purple = UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1.0) // #8b5cf6
        for i in 0..<3 {
            let dot = UIView()
            dot.backgroundColor = purple
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            dotsStack.addArrangedSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6),
            ])
            // Match web: orbPulse animation
            let anim = CAKeyframeAnimation(keyPath: "transform.scale")
            anim.values = [0.6, 1.15, 0.6]
            anim.keyTimes = [0, 0.5, 1.0]
            anim.duration = 1.4
            anim.repeatCount = .infinity
            anim.beginTime = CACurrentMediaTime() + Double(i) * 0.2
            dot.layer.add(anim, forKey: "orb_\(i)")

            let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
            opacityAnim.values = [0.35, 1.0, 0.35]
            opacityAnim.keyTimes = [0, 0.5, 1.0]
            opacityAnim.duration = 1.4
            opacityAnim.repeatCount = .infinity
            opacityAnim.beginTime = CACurrentMediaTime() + Double(i) * 0.2
            dot.layer.add(opacityAnim, forKey: "orb_opacity_\(i)")
        }

        pill.addSubview(dotsStack)
        remoteIndicatorRow.addSubview(pill)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: remoteIndicatorRow.leadingAnchor),
            pill.centerYAnchor.constraint(equalTo: remoteIndicatorRow.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 28),
            dotsStack.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            dotsStack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            dotsStack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            dotsStack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
        ])

        pill.alpha = 0
        pill.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3) {
            pill.alpha = 1
            pill.transform = .identity
        }
    }

    func stopThinkingAnimation(for participantId: ParticipantID) {
        let tag = "thinking_\(participantId)"
        for subview in remoteIndicatorRow.subviews where subview.accessibilityIdentifier == tag {
            subview.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.2, animations: {
                subview.alpha = 0
                subview.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }) { _ in
                subview.removeFromSuperview()
            }
        }
    }

    // MARK: - Turn-based Conversation Management

    func handleUserStartedSpeaking(participantId: ParticipantID) {
        guard isUserTurn else { return }

        forceStopBotSpeakingAnimations()

        var participant = participantStates[participantId] ?? DailyParticipant(id: participantId.description, name: userName)
        participant.lastSpokenAt = Date().timeIntervalSince1970
        participant.turnNumber = currentTurn
        participantStates[participantId] = participant

        recordTurn(speaker: "user", action: "started", speakerName: userName)
    }

    func handleUserStoppedSpeaking(participantId: ParticipantID) {
        guard isUserTurn else { return }

        if let participant = participantStates[participantId] {
            let speakingDuration = Date().timeIntervalSince1970 - participant.lastSpokenAt
            recordTurn(speaker: "user", action: "stopped", speakerName: userName, duration: speakingDuration)
            switchToAiTurn()
        }
    }

    func handleAiStartedSpeaking(participantId: ParticipantID) {
        guard !isUserTurn else { return }

        var participant = participantStates[participantId] ?? DailyParticipant(id: participantId.description, name: coachName)
        participant.lastSpokenAt = Date().timeIntervalSince1970
        participant.turnNumber = currentTurn
        participantStates[participantId] = participant

        setAiThinkingState(isThinking: false)
        recordTurn(speaker: "ai", action: "started", speakerName: coachName)
    }

    func handleAiStoppedSpeaking(participantId: ParticipantID) {
        guard !isUserTurn else { return }

        if let participant = participantStates[participantId] {
            let speakingDuration = Date().timeIntervalSince1970 - participant.lastSpokenAt
            recordTurn(speaker: "ai", action: "stopped", speakerName: coachName, duration: speakingDuration)
            switchToUserTurn()
        }
    }

    func switchToAiTurn() {
        isUserTurn = false
        currentTurn += 1

        if !isAnyUserSpeaking() {
            setAiThinkingState(isThinking: true)
        }
    }

    func switchToUserTurn() {
        isUserTurn = true
        currentTurn += 1

        if isAnyAiSpeaking() {
            forceStopBotSpeakingAnimations()
        }
    }

    func recordTurn(speaker: String, action: String, speakerName: String, duration: TimeInterval? = nil) {
        let turnRecord = TurnRecord(
            turn: currentTurn,
            speaker: speaker,
            speakerName: speakerName,
            action: action,
            timestamp: Date().timeIntervalSince1970,
            duration: duration
        )
        conversationTurns.append(turnRecord)
    }

    func initializeTurnSystem() {
        currentTurn = 1
        isUserTurn = !aiFirst
        conversationTurns = []

        for (participantId, var participant) in participantStates {
            participant.turnNumber = 0
            participant.lastSpokenAt = 0
            participantStates[participantId] = participant
        }

        if aiFirst {
            switchToAiTurn()
        }
    }

    func cleanupTurnSystem() {
        setAiThinkingState(isThinking: false)

        currentTurn = 0
        isUserTurn = true
        conversationTurns = []

        if #available(iOS 15.0, *) {
            stopPictureInPicture()
        }
    }

    // MARK: - Animation Helper Methods

    func findParticipantId(from stringId: String) -> ParticipantID? {
        if let exactMatch = participantStates.keys.first(where: { $0.description == stringId }) {
            return exactMatch
        }

        if stringId.contains("local") {
            return callClient.participants.local.id
        }

        return participantStates.keys.first { !$0.description.contains("local") }
    }

    func triggerPulseAnimation(for participantId: ParticipantID, duration: TimeInterval, intensity: Float) {
        guard let videoView = getVideoViewForParticipant(participantId) else { return }

        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = duration
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.0 + (intensity * 0.1)
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 1

        videoView.layer.add(pulseAnimation, forKey: "server_pulse_animation")
    }

    func triggerHighlightAnimation(for participantId: ParticipantID, duration: TimeInterval) {
        let videoContainer = participantId == callClient.participants.local.id ? newLocalVideoContainer : newRemoteVideoContainer

        let originalBorderColor = videoContainer.layer.borderColor
        let originalBorderWidth = videoContainer.layer.borderWidth

        videoContainer.layer.borderColor = UIColor.systemYellow.cgColor
        videoContainer.layer.borderWidth = 6.0

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            videoContainer.layer.borderColor = originalBorderColor
            videoContainer.layer.borderWidth = originalBorderWidth
        }
    }

    func triggerFadeAnimation(for participantId: ParticipantID, fadeIn: Bool, duration: TimeInterval) {
        guard let videoView = getVideoViewForParticipant(participantId) else { return }

        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.duration = duration
        fadeAnimation.fromValue = fadeIn ? 0.0 : 1.0
        fadeAnimation.toValue = fadeIn ? 1.0 : 0.3
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        videoView.layer.add(fadeAnimation, forKey: "server_fade_animation")
    }

    func handleCustomAnimation(for participantId: ParticipantID, metadata: [String: String]?) {
        guard let metadata = metadata else { return }

        if let animationType = metadata["type"] {
            switch animationType {
            case "bounce":
                triggerBounceAnimation(for: participantId)
            case "shake":
                triggerShakeAnimation(for: participantId)
            case "glow":
                triggerGlowAnimation(for: participantId)
            default:
                break
            }
        }
    }

    func triggerBounceAnimation(for participantId: ParticipantID) {
        guard let videoView = getVideoViewForParticipant(participantId) else { return }

        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        bounceAnimation.values = [1.0, 1.2, 0.9, 1.1, 1.0]
        bounceAnimation.keyTimes = [0.0, 0.3, 0.5, 0.8, 1.0]
        bounceAnimation.duration = 0.8
        bounceAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        videoView.layer.add(bounceAnimation, forKey: "bounce_animation")
    }

    func triggerShakeAnimation(for participantId: ParticipantID) {
        guard let videoView = getVideoViewForParticipant(participantId) else { return }

        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shakeAnimation.values = [0, -10, 10, -5, 5, 0]
        shakeAnimation.keyTimes = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        shakeAnimation.duration = 0.5
        shakeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)

        videoView.layer.add(shakeAnimation, forKey: "shake_animation")
    }

    func triggerGlowAnimation(for participantId: ParticipantID) {
        let videoContainer = participantId == callClient.participants.local.id ? newLocalVideoContainer : newRemoteVideoContainer

        let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        glowAnimation.duration = 1.0
        glowAnimation.fromValue = 0.0
        glowAnimation.toValue = 1.0
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = 2

        videoContainer.layer.shadowColor = UIColor.cyan.cgColor
        videoContainer.layer.shadowRadius = 20
        videoContainer.layer.add(glowAnimation, forKey: "glow_animation")
    }

    // MARK: - Public Test Methods

    func testAnimationEvent(participantId: String, animationType: AnimationEvent.AnimationType, duration: TimeInterval? = nil, intensity: Float? = nil) {
        let animationEvent = AnimationEvent(
            participantId: participantId,
            animationType: animationType,
            duration: duration,
            intensity: intensity,
            metadata: nil
        )
        didReceiveAnimationEvent(animationEvent)
    }

    func testEnhancedThinkingAnimation() {
        for (participantId, participant) in participantStates {
            if !participant.id.contains("local") && participantId != callClient.participants.local.id {
                startThinkingAnimation(for: participantId)

                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.stopThinkingAnimation(for: participantId)
                }
                break
            }
        }
    }

    func forceCleanupAnimations() {
        for (participantId, _) in participantStates {
            stopThinkingAnimation(for: participantId)
        }

        forceStopBotSpeakingAnimations()

        for (participantId, var participant) in participantStates {
            participant.isSpeaking = false
            participant.isThinking = false
            participant.isActiveSpeaker = false
            participantStates[participantId] = participant
        }
    }
}
