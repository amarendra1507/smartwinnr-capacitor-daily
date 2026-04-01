//
//  DailyCallViewController+ServerEvents.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
//

import Foundation
import UIKit
import Daily

// MARK: - Server Event Handling

extension DailyCallViewController {

    func processServerEventFromJSON(_ jsonString: String) {
        print("[AudioDebug] processServerEventFromJSON received: \(jsonString.prefix(200))")
        eventQueue.async { [weak self] in
            guard let self = self, self.isEventHandlingActive else {
                print("[AudioDebug]   ⚠️ Event handling NOT active or self is nil")
                return
            }

            do {
                let jsonData = Data(jsonString.utf8)

                if let messageDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let messageType = messageDict["type"] as? String {

                    DispatchQueue.main.async {
                        self.handleSpecificMessageType(messageType, payload: messageDict["payload"] as? [String: Any])
                    }
                    return
                }

                let serverEvent = try JSONDecoder().decode(ServerEvent.self, from: jsonData)

                DispatchQueue.main.async {
                    self.handleServerEvent(serverEvent)
                }
            } catch {
                print("Failed to parse JSON message: \(error)")
            }
        }
    }

    func handleSpecificMessageType(_ messageType: String, payload: [String: Any]?) {
        print("[AudioDebug] handleSpecificMessageType: \(messageType), isAudioModeOnly: \(isAudioModeOnly)")
        switch messageType {
        // Support both UPPER_SNAKE_CASE (legacy) and lower-kebab-case (current server format)
        case "USER_STARTED_SPEAKING", "user-started-speaking":
            handleUserStartedSpeakingMessage()
        case "USER_STOPPED_SPEAKING", "user-stopped-speaking":
            handleUserStoppedSpeakingMessage()
        case "BOT_STARTED_SPEAKING", "bot-started-speaking":
            handleBotStartedSpeakingMessage()
        case "BOT_STOPPED_SPEAKING", "bot-stopped-speaking":
            handleBotStoppedSpeakingMessage()
        default:
            break
        }
    }

    func handleUserStartedSpeakingMessage() {
        let localParticipantId = callClient.participants.local.id

        forceStopBotSpeakingAnimations()
        setAiThinkingState(isThinking: false)
        updateParticipantSpeakingState(participantId: localParticipantId, isSpeaking: true, isLocal: true)

        if !isUserTurn {
            switchToUserTurn()
        }
    }

    func handleUserStoppedSpeakingMessage() {
        let localParticipantId = callClient.participants.local.id

        updateParticipantSpeakingState(participantId: localParticipantId, isSpeaking: false, isLocal: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.isAnyUserSpeaking() && !self.isAnyAiSpeaking() {
                self.setAiThinkingState(isThinking: true)
            }
        }
    }

    func handleBotStartedSpeakingMessage() {
        print("[AudioDebug] handleBotStartedSpeakingMessage - participantStates count: \(participantStates.count)")
        setAiThinkingState(isThinking: false)

        var foundAi = false
        for (participantId, participant) in participantStates {
            let isLocal = participantId == callClient.participants.local.id
            print("[AudioDebug]   participant '\(participant.id)' isLocal: \(isLocal), id.contains('local'): \(participant.id.contains("local"))")
            if !participant.id.contains("local") && !isLocal {
                print("[AudioDebug]   → Found AI participant, setting speaking=true")
                updateParticipantSpeakingState(participantId: participantId, isSpeaking: true, isLocal: false)
                foundAi = true
                break
            }
        }
        if !foundAi {
            print("[AudioDebug]   ⚠️ No AI participant found in participantStates!")
        }

        if isUserTurn {
            switchToAiTurn()
        }
    }

    func handleBotStoppedSpeakingMessage() {
        print("[AudioDebug] handleBotStoppedSpeakingMessage")
        for (participantId, participant) in participantStates {
            if !participant.id.contains("local") && participantId != callClient.participants.local.id {
                updateParticipantSpeakingState(participantId: participantId, isSpeaking: false, isLocal: false)
                break
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.isAnyAiSpeaking() {
                self.switchToUserTurn()
            }
        }
    }

    func handleServerEvent(_ event: ServerEvent) {
        serverEventDelegate?.didReceiveServerEvent(event)

        switch event.type {
        case .animation:
            handleAnimationEvent(from: event)
        case .conversation:
            handleConversationEvent(from: event)
        case .participant:
            handleParticipantEvent(from: event)
        case .error:
            handleErrorEvent(from: event)
        case .custom:
            handleCustomEvent(from: event)
        }
    }

    private func handleAnimationEvent(from serverEvent: ServerEvent) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: serverEvent.data)
            let animationEvent = try JSONDecoder().decode(AnimationEvent.self, from: jsonData)
            didReceiveAnimationEvent(animationEvent)
        } catch {
            print("Failed to parse animation event: \(error)")
        }
    }

    private func handleConversationEvent(from serverEvent: ServerEvent) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: serverEvent.data)
            let conversationEvent = try JSONDecoder().decode(ConversationEvent.self, from: jsonData)
            didReceiveConversationEvent(conversationEvent)
        } catch {
            print("Failed to parse conversation event: \(error)")
        }
    }

    private func handleParticipantEvent(from serverEvent: ServerEvent) {
        guard let participantId = serverEvent.participantId else { return }

        let isSpeaking = serverEvent.data["is_speaking"] as? Bool ?? false
        let isThinking = serverEvent.data["is_thinking"] as? Bool ?? false
        let isLocal = serverEvent.data["is_local"] as? Bool ?? false

        if let matchingParticipantId = participantStates.keys.first(where: { $0.description == participantId }) {
            updateParticipantSpeakingState(participantId: matchingParticipantId, isSpeaking: isSpeaking, isLocal: isLocal)

            if isThinking && !isLocal {
                setAiThinkingState(isThinking: true)
            } else if !isThinking && !isLocal {
                setAiThinkingState(isThinking: false)
            }
        }
    }

    private func handleErrorEvent(from serverEvent: ServerEvent) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: serverEvent.data)
            let errorEvent = try JSONDecoder().decode(ErrorEvent.self, from: jsonData)
            didReceiveErrorEvent(errorEvent)
        } catch {
            print("Failed to parse error event: \(error)")
        }
    }

    private func handleCustomEvent(from serverEvent: ServerEvent) {
        // Custom event handling can be extended as needed
    }

    func setEventHandlingActive(_ isActive: Bool) {
        isEventHandlingActive = isActive
    }

    // MARK: - ServerEventDelegate Implementation

    func didReceiveServerEvent(_ event: ServerEvent) {
        // Called for external delegates - internal handling is done in handleServerEvent
    }

    func didReceiveAnimationEvent(_ event: AnimationEvent) {
        guard let participantId = findParticipantId(from: event.participantId) else { return }

        switch event.animationType {
        case .startSpeaking:
            let isLocal = event.participantId.contains("local") || event.participantId == callClient.participants.local.id.description
            updateParticipantSpeakingState(participantId: participantId, isSpeaking: true, isLocal: isLocal)
        case .stopSpeaking:
            let isLocal = event.participantId.contains("local") || event.participantId == callClient.participants.local.id.description
            updateParticipantSpeakingState(participantId: participantId, isSpeaking: false, isLocal: isLocal)
        case .startThinking:
            if !event.participantId.contains("local") {
                setAiThinkingState(isThinking: true)
            }
        case .stopThinking:
            if !event.participantId.contains("local") {
                setAiThinkingState(isThinking: false)
            }
        case .pulse:
            triggerPulseAnimation(for: participantId, duration: event.duration ?? 1.0, intensity: event.intensity ?? 1.0)
        case .highlight:
            triggerHighlightAnimation(for: participantId, duration: event.duration ?? 2.0)
        case .fadeIn, .fadeOut:
            triggerFadeAnimation(for: participantId, fadeIn: event.animationType == .fadeIn, duration: event.duration ?? 0.5)
        case .custom:
            handleCustomAnimation(for: participantId, metadata: event.metadata)
        }

        serverEventDelegate?.didReceiveAnimationEvent(event)
    }

    func didReceiveConversationEvent(_ event: ConversationEvent) {
        guard let _ = findParticipantId(from: event.participantId) else { return }

        switch event.action {
        case .turnStart:
            if event.participantId.contains("local") {
                switchToUserTurn()
            } else {
                switchToAiTurn()
            }
        case .turnEnd:
            break
        case .messageReceived, .messageSent:
            break
        case .aiResponse:
            setAiThinkingState(isThinking: false)
        }

        serverEventDelegate?.didReceiveConversationEvent(event)
    }

    func didReceiveErrorEvent(_ event: ErrorEvent) {
        switch event.severity {
        case .low, .medium:
            break
        case .high:
            showAlert(message: "Error: \(event.message)")
        case .critical:
            showAlert(message: "Critical Error: \(event.message)")
        }

        serverEventDelegate?.didReceiveErrorEvent(event)
    }
}
