//
//  DailyCallViewController+CallDelegate.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
//

import UIKit
import Daily
import AVKit

// MARK: - CallClientDelegate

extension DailyCallViewController: CallClientDelegate {

    func callClientDidDetectStartOfSystemBroadcast(_ callClient: CallClient) {
        isScreenSharingActive = true
        updateScreenShareButton()
        dismissBroadcastPicker()

        callClient.updateInputs(
            .set(screenVideo: .set(isEnabled: .set(true))),
            completion: nil
        )

        if #available(iOS 15.0, *) {
            DispatchQueue.main.async {
                if self.isUIInitialized {
                    self.newRemoteVideoView.isHidden = false
                    self.newRemoteVideoContainer.isHidden = false
                    self.newRemoteVideoView.alpha = 1.0
                    self.newRemoteVideoContainer.alpha = 1.0
                    self.view.bringSubviewToFront(self.newRemoteVideoContainer)
                }

                for (_, videoView) in self.videoViews {
                    videoView.isHidden = false
                    videoView.alpha = 1.0
                    if let superview = videoView.superview {
                        superview.bringSubviewToFront(videoView)
                    }
                }

                self.pipPossibleObservation?.invalidate()
                self.pipControllerStorage = nil
                self.setupPictureInPicture()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.startPictureInPicture()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if let controller = self.pipControllerStorage as? AVPictureInPictureController {
                            if !controller.isPictureInPictureActive && controller.isPictureInPicturePossible {
                                self.attemptPipStart()
                            }
                        }
                    }
                }
            }
        }
    }

    public func callClientDidDetectEndOfSystemBroadcast(_ callClient: CallClient) {
        isScreenSharingActive = false
        updateScreenShareButton()

        callClient.updateInputs(
            .set(screenVideo: .set(isEnabled: .set(false))),
            completion: nil
        )

        if #available(iOS 15.0, *) {
            DispatchQueue.main.async {
                self.stopPictureInPicture()
            }
        }
    }

    func callClient(_ callClient: CallClient, inputsUpdated inputs: InputSettings) {
        DispatchQueue.main.async { [weak self] in
            self?.updateControls()
        }
    }

    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
        print("Participant \(participant.id) joined the call")

        // Don't start recording twice
        guard !self.recordingStarted else {
            DispatchQueue.main.async { [weak self] in
                self?.removeOverlayView()
            }
            return
        }

        self.callClient.startRecording() { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let recordingInfo):
                self.recordingStartTime = Date().timeIntervalSince1970
                self.currentRecordingId = "\(recordingInfo)"
                self.recordingStarted = true
                if let recordingId = self.currentRecordingId,
                   let startTime = self.recordingStartTime {
                    self.onRecordingStarted?(recordingId, startTime)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.removeOverlayView()
                }
                self.joined()
            case .failure(let error):
                print("Failed startRecording: \(error.localizedDescription)")
                self.onRecordingError?(error.localizedDescription)
                // Still proceed — the call works, recording just won't be available
                DispatchQueue.main.async { [weak self] in
                    self?.removeOverlayView()
                }
                self.joined()
            }
        }

        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = screenTrack ?? cameraTrack

        let videoView = VideoView()
        videoView.track = videoTrack
        self.videoViews[participant.id] = videoView

        if let track = videoTrack {
            self.attachVideoTrack(track, for: participant.id, isLocal: false)
        }

        let participantState = DailyParticipant(
            id: participant.id.description,
            name: participant.info.username ?? "Remote User"
        )
        self.participantStates[participant.id] = participantState

        if !self.allParticipantJoined {
            self.allParticipantJoined = true
            self.initializeTurnSystem()
            self.setEventHandlingActive(true)

            if #available(iOS 15.0, *) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }
                    self.pipPossibleObservation?.invalidate()
                    self.pipControllerStorage = nil
                    self.setupPictureInPicture()
                }
            }
        }
    }

    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = cameraTrack ?? screenTrack

        if participant.info.isLocal {
            if let track = videoTrack {
                self.attachVideoTrack(track, for: participant.id, isLocal: true)
            }

            // Preserve existing speaking/thinking state — only create if not already tracked
            if self.participantStates[participant.id] == nil {
                self.participantStates[participant.id] = DailyParticipant(
                    id: participant.id.description,
                    name: self.userName
                )
                print("[AudioDebug] participantUpdated: registered LOCAL participant \(participant.id)")
            }

            if self.isTestMode {
                DispatchQueue.main.async { [weak self] in
                    self?.removeOverlayView()
                }
            }
        } else {
            let videoView = self.videoViews[participant.id] ?? VideoView()
            videoView.track = videoTrack
            self.videoViews[participant.id] = videoView

            if let track = videoTrack {
                self.attachVideoTrack(track, for: participant.id, isLocal: false)
            }

            if #available(iOS 15.0, *) {
                if let pipController = self.pipControllerStorage as? AVPictureInPictureController,
                   pipController.isPictureInPictureActive {
                    DispatchQueue.main.async { [weak self] in
                        self?.updatePipProfileOverlay()
                    }
                }
            }

            // Preserve existing speaking/thinking state — only create if not already tracked
            if self.participantStates[participant.id] == nil {
                self.participantStates[participant.id] = DailyParticipant(
                    id: participant.id.description,
                    name: participant.info.username ?? "Remote User"
                )
                print("[AudioDebug] participantUpdated: registered REMOTE participant \(participant.id)")
            }

            if let alert = self.disconnectionAlert {
                alert.dismiss(animated: true)
                self.disconnectionAlert = nil
            }

            if self.isTestMode {
                DispatchQueue.main.async { [weak self] in
                    self?.removeOverlayView()
                }
            }
        }
    }

    func callClient(_ callClient: CallClient, callStateUpdated callState: CallState) {
        handleCallStateChange(callState)
    }

    func callClient(_ callClient: CallClient, networkQualityChanged quality: String) {
        print("[NetworkDebug] networkQualityChanged delegate fired — quality: '\(quality)'")
        handleNetworkQualityChange(quality)
    }

    func callClient(_ callClient: CallClient, networkStatsUpdated stats: NetworkStats) {
        print("[NetworkDebug] networkStatsUpdated delegate fired — threshold: \(stats.threshold), quality: \(stats.quality), previousThreshold: \(String(describing: stats.previousThreshold))")
        let latest = stats.stats.latest
        print("[NetworkDebug]   latest stats — sendBps: \(latest.sendBitsPerSecond ?? -1), recvBps: \(latest.receiveBitsPerSecond ?? -1), totalSendLoss: \(latest.totalSendPacketLoss ?? -1), totalRecvLoss: \(latest.totalRecvPacketLoss ?? -1)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.settingsVC?.updateNetworkStats(stats)
            self.handleNetworkStatsUpdate(stats)
        }
    }

    func callClient(_ callClient: CallClient, activeSpeakerChanged activeSpeaker: Participant?) {
        // Disabled: relying only on server messages for animation control
    }

    func callClient(
        _ callClient: CallClient,
        participantCountsUpdated participantCounts: ParticipantCounts
    ) {
        if participantCounts.present < 2 && self.recordingStarted == true {
            self.onParticipantCountChanged?(participantCounts.present)
        }
    }

    func callClient(
        _ callClient: CallClient,
        participantLeft participant: Participant,
        withReason reason: ParticipantLeftReason
    ) {
        if participant.info.isLocal {
            // Local participant left - no action needed
        } else {
            let participantName = participant.info.username ?? "AI"
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Participant Disconnected",
                    message: "\(participantName) has left due to network issues. Please wait while they rejoin.",
                    preferredStyle: .alert
                )
                self.present(alert, animated: true)
                self.disconnectionAlert = alert
            }

            let remoteIds = self.videoViews.keys.filter { $0 != self.callClient.participants.local.id }
            for id in remoteIds {
                if let existingView = self.videoViews.removeValue(forKey: id) {
                    existingView.removeFromSuperview()
                }
            }

            self.participantStates.removeValue(forKey: participant.id)
            self.stopThinkingAnimation(for: participant.id)
        }
    }

    // MARK: - App Message Handling

    func callClient(
        _ callClient: CallClient,
        appMessageAsJson jsonData: Data,
        from participantID: ParticipantID
    ) {
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            processServerEventFromJSON(jsonString)
        }
    }
}
