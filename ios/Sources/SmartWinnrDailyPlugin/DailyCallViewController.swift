//
//  DailyCallViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Created by SmartWinnr on 02/07/24.
//

import Foundation
import UIKit
import Daily
import DailySystemBroadcast
import ReplayKit
import AVFoundation

// Audio analyzer delegate protocol
protocol AudioAnalyzerDelegate: AnyObject {
    func audioAnalyzer(_ analyzer: AudioAnalyzer, detectedSpeaking: Bool, for participantId: String)
}

// Audio analyzer class for detecting speech
class AudioAnalyzer {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var analyzer: AVAudioPCMBuffer?
    private weak var delegate: AudioAnalyzerDelegate?
    private let participantId: String
    private var consecutiveSpeakingFrames = 0
    private var consecutiveSilentFrames = 0
    private let speechThreshold: Float
    
    init(participantId: String, speechThreshold: Float, delegate: AudioAnalyzerDelegate) {
        self.participantId = participantId
        self.speechThreshold = speechThreshold
        self.delegate = delegate
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
    }
    
    func startAnalyzing() {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.analyzeAudioLevel(buffer: buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopAnalyzing() {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
    }
    
    private func analyzeAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        let avgPower = 20 * log10(rms)
        
        let isCurrentlySpeaking = avgPower > speechThreshold
        
        if isCurrentlySpeaking {
            consecutiveSpeakingFrames += 1
            consecutiveSilentFrames = 0
        } else {
            consecutiveSilentFrames += 1
            consecutiveSpeakingFrames = 0
        }
        
        let isSpeaking = consecutiveSpeakingFrames >= 3 // speakingFramesThreshold
        let isSilent = consecutiveSilentFrames >= 8 // silentFramesThreshold
        
        if isSpeaking || isSilent {
            DispatchQueue.main.async {
                self.delegate?.audioAnalyzer(self, detectedSpeaking: isSpeaking, for: self.participantId)
            }
        }
    }
}

class DailyCallViewController: UIViewController, AudioAnalyzerDelegate {
    @IBOutlet private weak var systemBroadcastPickerView: UIView!
    
    // MARK: - UI Components to match the design (New UI Elements)
    private lazy var newContentContainerView = UIView()
    private lazy var newCoachingTitleLabel = UILabel()

    private lazy var newTimerLabel = UILabel()
    private lazy var newMainStackView = UIStackView()
    private lazy var newLocalVideoContainer = UIView()
    private lazy var newRemoteVideoContainer = UIView()
    private lazy var newLocalVideoView = VideoView()
    private lazy var newRemoteVideoView = VideoView()
    private lazy var newLocalParticipantLabel = UILabel()
    private lazy var newRemoteParticipantLabel = UILabel()
    private lazy var newControlsOverlay = UIView()
    private lazy var newCameraButton = UIButton()
    private lazy var newMicButton = UIButton()
    private lazy var newEndRolePlayButton = UIButton()
    
    // Track if new UI is initialized
    private var isNewUIInitialized = false
    
    // Device type detection
    private var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    // Add this struct if you don't already have it
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
    
    // Speaking and animation state tracking
    private var participantStates: [ParticipantID: DailyParticipant] = [:]
    private var speakingIndicators: [ParticipantID: UIView] = [:]
    private var videoPulseOverlays: [ParticipantID: UIView] = [:] // Full video pulse effects
    private var thinkingAnimations: [ParticipantID: CAAnimation] = [:]
    private var audioAnalyzers: [String: AudioAnalyzer] = [:] // Keep String for audio analyzers since they use custom IDs
    
    // Turn-based conversation tracking
    private var currentTurn: Int = 0
    private var isUserTurn: Bool = true
    private var conversationTurns: [TurnRecord] = []
    private var aiFirst: Bool = false
    
    // Audio detection thresholds
    private let speechThresholdLocal: Float = 0.15
    private let speechThresholdRemote: Float = 0.10
    private let speakingFramesThreshold: Int = 3
    private let silentFramesThreshold: Int = 8
    
    struct TurnRecord {
        let turn: Int
        let speaker: String // "user" or "ai"
        let speakerName: String
        let action: String // "started" or "stopped"
        let timestamp: TimeInterval
        let duration: TimeInterval?
    }

    // MARK: - UI Setup Methods
    
    func initializeNewUI() {
        guard !isNewUIInitialized else { return }
        isNewUIInitialized = true
        
        setupNewUI()
        setupCallClient()
    }
    
    private func setupNewUI() {
        view.backgroundColor = UIColor.systemBackground
        
        setupNewContentContainer()
        setupNewCoachingTitle()

        setupNewTimerLabel()
        setupVideoViews()
        setupParticipantLabels()
        setupControlsOverlay()
        setupEndRolePlayButton()
        setupNewConstraints()
    }
    
    private func setupNewContentContainer() {
        newContentContainerView.backgroundColor = .clear
        newContentContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newContentContainerView)
    }
    
    private func setupNewCoachingTitle() {
        newCoachingTitleLabel.text = self.coachingTitle
        newCoachingTitleLabel.textAlignment = .center
        newCoachingTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        newCoachingTitleLabel.textColor = .label  // Adapts to light/dark mode
        newCoachingTitleLabel.backgroundColor = .clear  // No background
        newCoachingTitleLabel.numberOfLines = 2
        newCoachingTitleLabel.lineBreakMode = .byWordWrapping
        newCoachingTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        newContentContainerView.addSubview(newCoachingTitleLabel)
    }
    

    
    private func setupNewTimerLabel() {
        newTimerLabel.text = "00:00 / 05:00"
        newTimerLabel.textAlignment = .center
        newTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        newTimerLabel.textColor = .white
        newTimerLabel.backgroundColor = UIColor.systemBlue
        newTimerLabel.layer.cornerRadius = 20
        newTimerLabel.layer.masksToBounds = true
        newTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        newContentContainerView.addSubview(newTimerLabel)
    }
    
    private func setupVideoViews() {
        // Setup local video container with border
        newLocalVideoContainer.backgroundColor = .clear
        newLocalVideoContainer.layer.cornerRadius = 20
        newLocalVideoContainer.layer.borderWidth = 2
        newLocalVideoContainer.layer.borderColor = UIColor.systemGray5.cgColor
        newLocalVideoContainer.layer.shadowColor = UIColor.black.cgColor
        newLocalVideoContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        newLocalVideoContainer.layer.shadowRadius = 8
        newLocalVideoContainer.layer.shadowOpacity = 0.1
        newLocalVideoContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup remote video container with border
        newRemoteVideoContainer.backgroundColor = .clear
        newRemoteVideoContainer.layer.cornerRadius = 20
        newRemoteVideoContainer.layer.borderWidth = 2
        newRemoteVideoContainer.layer.borderColor = UIColor.systemGray5.cgColor
        newRemoteVideoContainer.layer.shadowColor = UIColor.black.cgColor
        newRemoteVideoContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        newRemoteVideoContainer.layer.shadowRadius = 8
        newRemoteVideoContainer.layer.shadowOpacity = 0.1
        newRemoteVideoContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup local video view with consistent sizing
        newLocalVideoView.backgroundColor = .black
        newLocalVideoView.layer.cornerRadius = 16
        newLocalVideoView.layer.masksToBounds = true
        newLocalVideoView.videoScaleMode = .fill
        newLocalVideoView.contentMode = .scaleAspectFill
        newLocalVideoView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup remote video view with consistent sizing
        newRemoteVideoView.backgroundColor = .black
        newRemoteVideoView.layer.cornerRadius = 16
        newRemoteVideoView.layer.masksToBounds = true
        newRemoteVideoView.videoScaleMode = .fill
        newRemoteVideoView.contentMode = .scaleAspectFill
        newRemoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add video views to their containers
        newLocalVideoContainer.addSubview(newLocalVideoView)
        newRemoteVideoContainer.addSubview(newRemoteVideoView)
        
        // Setup main stack view with responsive layout
        newMainStackView.axis = isIPad ? .horizontal : .vertical
        newMainStackView.distribution = .fillEqually
        newMainStackView.spacing = isIPad ? 20 : 30
        newMainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        newMainStackView.addArrangedSubview(newLocalVideoContainer)
        newMainStackView.addArrangedSubview(newRemoteVideoContainer)
        newContentContainerView.addSubview(newMainStackView)
    }
    
        private func setupParticipantLabels() {
        // Local participant label - bold and right-aligned, closer to video
        newLocalParticipantLabel.text = "Beverley Flow Admin"
        newLocalParticipantLabel.textAlignment = .right
        newLocalParticipantLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        newLocalParticipantLabel.textColor = .label
        newLocalParticipantLabel.backgroundColor = .clear
        newLocalParticipantLabel.translatesAutoresizingMaskIntoConstraints = false
        newContentContainerView.addSubview(newLocalParticipantLabel)
        
        // Remote participant label - bold and right-aligned, closer to video
        newRemoteParticipantLabel.text = "Dr. Alice"
        newRemoteParticipantLabel.textAlignment = .right
        newRemoteParticipantLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        newRemoteParticipantLabel.textColor = .label
        newRemoteParticipantLabel.backgroundColor = .clear
        newRemoteParticipantLabel.translatesAutoresizingMaskIntoConstraints = false
        newContentContainerView.addSubview(newRemoteParticipantLabel)
    }
    
    private func setupControlsOverlay() {
        newControlsOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        newControlsOverlay.layer.cornerRadius = 20
        newControlsOverlay.layer.masksToBounds = true
        newControlsOverlay.translatesAutoresizingMaskIntoConstraints = false
        
        // Camera button
        newCameraButton.setImage(UIImage(systemName: "video"), for: .normal)
        newCameraButton.tintColor = .white
        newCameraButton.translatesAutoresizingMaskIntoConstraints = false
        newCameraButton.addTarget(self, action: #selector(didTapToggleCamera), for: .touchUpInside)
        
        // Mic button
        newMicButton.setImage(UIImage(systemName: "mic"), for: .normal)
        newMicButton.tintColor = .white
        newMicButton.translatesAutoresizingMaskIntoConstraints = false
        newMicButton.addTarget(self, action: #selector(didTapToggleMicrophone), for: .touchUpInside)
        
        newControlsOverlay.addSubview(newCameraButton)
        newControlsOverlay.addSubview(newMicButton)
        newLocalVideoView.addSubview(newControlsOverlay)
    }
    
    private func setupEndRolePlayButton() {
        newEndRolePlayButton.setTitle("END ROLE PLAY", for: .normal)
        newEndRolePlayButton.setTitleColor(.white, for: .normal)
        newEndRolePlayButton.backgroundColor = UIColor.systemOrange
        newEndRolePlayButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        newEndRolePlayButton.layer.cornerRadius = 25
        newEndRolePlayButton.layer.masksToBounds = true
        newEndRolePlayButton.translatesAutoresizingMaskIntoConstraints = false
        newEndRolePlayButton.addTarget(self, action: #selector(endRolePlayTapped), for: .touchUpInside)
        newEndRolePlayButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        newEndRolePlayButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        newContentContainerView.addSubview(newEndRolePlayButton)
    }
    
    private func setupNewConstraints() {
        NSLayoutConstraint.activate([
            // Container view - anchored to safe area with proper spacing
            newContentContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            newContentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            newContentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            newContentContainerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            
            // Coaching title at the top of container
            newCoachingTitleLabel.topAnchor.constraint(equalTo: newContentContainerView.topAnchor),
            newCoachingTitleLabel.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor),
            newCoachingTitleLabel.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor),
            newCoachingTitleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            
            // Timer label below coaching title
            newTimerLabel.topAnchor.constraint(equalTo: newCoachingTitleLabel.bottomAnchor, constant: 16),
            newTimerLabel.centerXAnchor.constraint(equalTo: newContentContainerView.centerXAnchor),
            newTimerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            newTimerLabel.heightAnchor.constraint(equalToConstant: 40),
            
            // Main stack view below timer
            newMainStackView.topAnchor.constraint(equalTo: newTimerLabel.bottomAnchor, constant: 20),
            newMainStackView.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor, constant: 10),
            newMainStackView.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor, constant: -10),
            
            // Fixed aspect ratio for video containers to prevent sizing issues
            newLocalVideoContainer.heightAnchor.constraint(equalTo: newLocalVideoContainer.widthAnchor, multiplier: 0.75),
            newRemoteVideoContainer.heightAnchor.constraint(equalTo: newRemoteVideoContainer.widthAnchor, multiplier: 0.75),
            
            // Participant labels - positioned differently for iPad vs iPhone
        ])
        
        // Participant labels positioned below each video container, right-aligned and closer
        NSLayoutConstraint.activate([
            // Local participant label below video container, closer and right-aligned
            newLocalParticipantLabel.topAnchor.constraint(equalTo: newLocalVideoContainer.bottomAnchor, constant: 4),
            newLocalParticipantLabel.leadingAnchor.constraint(equalTo: newLocalVideoContainer.leadingAnchor),
            newLocalParticipantLabel.trailingAnchor.constraint(equalTo: newLocalVideoContainer.trailingAnchor),
            newLocalParticipantLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Remote participant label below video container, closer and right-aligned
            newRemoteParticipantLabel.topAnchor.constraint(equalTo: newRemoteVideoContainer.bottomAnchor, constant: 4),
            newRemoteParticipantLabel.leadingAnchor.constraint(equalTo: newRemoteVideoContainer.leadingAnchor),
            newRemoteParticipantLabel.trailingAnchor.constraint(equalTo: newRemoteVideoContainer.trailingAnchor),
            newRemoteParticipantLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        // Common constraints for both layouts
        NSLayoutConstraint.activate([
            // Video views inside their containers
            newLocalVideoView.topAnchor.constraint(equalTo: newLocalVideoContainer.topAnchor, constant: 4),
            newLocalVideoView.leadingAnchor.constraint(equalTo: newLocalVideoContainer.leadingAnchor, constant: 4),
            newLocalVideoView.trailingAnchor.constraint(equalTo: newLocalVideoContainer.trailingAnchor, constant: -4),
            newLocalVideoView.bottomAnchor.constraint(equalTo: newLocalVideoContainer.bottomAnchor, constant: -4),
            
            newRemoteVideoView.topAnchor.constraint(equalTo: newRemoteVideoContainer.topAnchor, constant: 4),
            newRemoteVideoView.leadingAnchor.constraint(equalTo: newRemoteVideoContainer.leadingAnchor, constant: 4),
            newRemoteVideoView.trailingAnchor.constraint(equalTo: newRemoteVideoContainer.trailingAnchor, constant: -4),
            newRemoteVideoView.bottomAnchor.constraint(equalTo: newRemoteVideoContainer.bottomAnchor, constant: -4),
            
            // Controls overlay
            newControlsOverlay.leadingAnchor.constraint(equalTo: newLocalVideoView.leadingAnchor, constant: 16),
            newControlsOverlay.bottomAnchor.constraint(equalTo: newLocalVideoView.bottomAnchor, constant: -16),
            newControlsOverlay.widthAnchor.constraint(equalToConstant: 80),
            newControlsOverlay.heightAnchor.constraint(equalToConstant: 40),
            
            // Camera button
            newCameraButton.leadingAnchor.constraint(equalTo: newControlsOverlay.leadingAnchor, constant: 8),
            newCameraButton.centerYAnchor.constraint(equalTo: newControlsOverlay.centerYAnchor),
            newCameraButton.widthAnchor.constraint(equalToConstant: 32),
            newCameraButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Mic button
            newMicButton.trailingAnchor.constraint(equalTo: newControlsOverlay.trailingAnchor, constant: -8),
            newMicButton.centerYAnchor.constraint(equalTo: newControlsOverlay.centerYAnchor),
            newMicButton.widthAnchor.constraint(equalToConstant: 32),
            newMicButton.heightAnchor.constraint(equalToConstant: 32),
            
            // End role play button - at bottom of container, accounting for participant labels
            newEndRolePlayButton.topAnchor.constraint(greaterThanOrEqualTo: newRemoteParticipantLabel.bottomAnchor, constant: 20),
            newEndRolePlayButton.centerXAnchor.constraint(equalTo: newContentContainerView.centerXAnchor),
            newEndRolePlayButton.widthAnchor.constraint(equalToConstant: 200),
            newEndRolePlayButton.heightAnchor.constraint(equalToConstant: 50),
            newEndRolePlayButton.bottomAnchor.constraint(equalTo: newContentContainerView.bottomAnchor)
        ])
    }
    
    @objc private func endRolePlayTapped() {
        // Add visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.newEndRolePlayButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                let identityTransform = CGAffineTransform.identity
                self.newEndRolePlayButton.transform = identityTransform
            }
        }

        // Disable button to prevent multiple taps
        self.newEndRolePlayButton.isEnabled = false
        
        // Cleanup turn system and audio detection
        self.cleanupTurnSystem()
        
        // Stop recording if it's running
        self.callClient.stopRecording { result in
            
            // Re-enable button in case of failure
            DispatchQueue.main.async {
                self.newEndRolePlayButton.isEnabled = true
            }
            
            switch result {
            case .success(_):
                print("Recording stopped successfully")
                if let recordingId = self.currentRecordingId {
                    let stopTime = Date().timeIntervalSince1970
                    self.onRecordingStopped?(recordingId, stopTime)
                }
                
                // Remove local participant and leave call
                let participants = self.callClient.participants
                let localParticipant = participants.local
                self.removeParticipantView(participantId: localParticipant.id)
                self.callClient.leave() { result in
                    self.timer?.invalidate()
                    self.timer = nil
                    self.leave()
                }
            case .failure(let error):
                print("Failed to stop recording: \(error.localizedDescription)")
                self.onRecordingError?(error.localizedDescription)
                self.callClient.leave() { result in
                    self.timer?.invalidate()
                    self.timer = nil
                    self.leave()
                }
            }
        }
    }
    
    private func setupCallClient() {
        // Initialize the call client if not already done
        // This should integrate with your existing Daily.co setup
        
        // Set initial timer
        updateNewTimer(currentTime: currentTime, maxTime: maxTime)
    }
    
    // Method to switch to new UI layout (call this when you want to use the new design)
    func enableNewUILayout() {
        initializeNewUI()
        
        // Hide specific old UI elements
        if let participantsStack = self.participantsStack {
            participantsStack.isHidden = true
        }
        if let timerView = self.timerView {
            timerView.isHidden = true
        }
        if let topView = self.topView {
            topView.isHidden = true
        }
        if let overlayView = self.overlayView {
            overlayView.isHidden = true
        }
        
        // Hide the existing timer label (conflicts with new one)
        if let existingTimerLabel = self.timerLabel {
            existingTimerLabel.isHidden = true
        }
        
        // Hide the old End Role Play button and bottom view
        if let leaveRoomButton = self.leaveRoomButton {
            leaveRoomButton.isHidden = true
        }
        if let bottomView = self.bottomView {
            bottomView.isHidden = true
        }
        
        // Show new UI elements
        newContentContainerView.isHidden = false
        newCoachingTitleLabel.isHidden = false

        newTimerLabel.isHidden = false
        newMainStackView.isHidden = false
        newLocalParticipantLabel.isHidden = false
        newRemoteParticipantLabel.isHidden = false
        newEndRolePlayButton.isHidden = false
        
        print("🎨 New UI Layout Enabled!")
    }
    
    // Method to update participant names dynamically
    func updateParticipantNames(localName: String?, remoteName: String?) {
        if let localName = localName {
            newLocalParticipantLabel.text = localName
        }
        if let remoteName = remoteName {
            newRemoteParticipantLabel.text = remoteName
        }
    }
    
    // Method to attach video tracks to the new UI
    func attachVideoTrack(_ track: VideoTrack, for participantId: ParticipantID, isLocal: Bool) {
        guard isNewUIInitialized else { return }
        
        if isLocal {
            // Attach to both old and new local video views
            localVideoView.track = track
            newLocalVideoView.track = track
            print("🎥 Attached local video track to both old and new UI")
            
            // Initialize speaking indicators for local participant in new UI
            initializeSpeakingIndicatorsForNewUI(participantId: participantId, videoView: newLocalVideoView)
        } else {
            // For remote participants, attach to new remote video view
            newRemoteVideoView.track = track
            print("🎥 Attached remote video track to new UI for participant: \(participantId)")
            
            // Initialize speaking indicators for remote participant in new UI
            initializeSpeakingIndicatorsForNewUI(participantId: participantId, videoView: newRemoteVideoView)
        }
    }
    
    private func initializeSpeakingIndicatorsForNewUI(participantId: ParticipantID, videoView: VideoView) {
        // Only create if not already exists
        if speakingIndicators[participantId] == nil {
            let indicator = createSpeakingIndicator(for: participantId)
            speakingIndicators[participantId] = indicator
            
            // Create full video pulse overlay
            let pulseOverlay = createVideoPulseOverlay(for: participantId)
            videoPulseOverlays[participantId] = pulseOverlay
            
            // Add pulse overlay to cover entire video
            videoView.addSubview(pulseOverlay)
            NSLayoutConstraint.activate([
                pulseOverlay.topAnchor.constraint(equalTo: videoView.topAnchor),
                pulseOverlay.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
                pulseOverlay.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
                pulseOverlay.bottomAnchor.constraint(equalTo: videoView.bottomAnchor)
            ])
            
            // Add bottom speaking indicator to video container
            let videoContainer = videoView == newLocalVideoView ? newLocalVideoContainer : newRemoteVideoContainer
            videoContainer.addSubview(indicator)
            
            // Position the indicator at the bottom of the video container
            NSLayoutConstraint.activate([
                indicator.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor, constant: 8),
                indicator.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor, constant: -8),
                indicator.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: -8),
                indicator.heightAnchor.constraint(equalToConstant: 32)
            ])
            
            print("🎨 DEBUG: ✅ Initialized speaking indicators for participant \(participantId) in new UI")
        }
    }
    
    private func updateNewTimer(currentTime: TimeInterval, maxTime: TimeInterval) {
        let current = formatNewTime(currentTime)
        let total = formatNewTime(maxTime)
        newTimerLabel.text = "\(current) / \(total)"
    }
    
    private func formatNewTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Speaking Animation Methods

    // Add these methods inside the class
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.newEndRolePlayButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.newEndRolePlayButton.alpha = 0.9
        }
    }

    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            let identityTransform = CGAffineTransform.identity
            self.newEndRolePlayButton.transform = identityTransform
            self.newEndRolePlayButton.alpha = 1.0
        }
    }
    
    // MARK: - Speaking State Management
    
    private func updateParticipantSpeakingState(participantId: ParticipantID, isSpeaking: Bool, isLocal: Bool) {
        guard var participant = participantStates[participantId] else { return }
        
        let wasSpeaking = participant.isSpeaking
        participant.isSpeaking = isSpeaking
        participant.isActiveSpeaker = isSpeaking
        participantStates[participantId] = participant
        
        // CRITICAL: Stop thinking animation immediately when starting to speak
        if isSpeaking {
            participant.isThinking = false
            participantStates[participantId] = participant
            stopThinkingAnimation(for: participantId)
        }
        
        // Update visual indicators (speaking border)
        updateSpeakingIndicator(for: participantId, isSpeaking: isSpeaking)
        
        if isSpeaking && !wasSpeaking {
            // Started speaking
            print("🗣️ DEBUG: \(isLocal ? "User" : "AI") started speaking: \(participantId)")
            if isLocal {
                handleUserStartedSpeaking(participantId: participantId)
            } else {
                handleAiStartedSpeaking(participantId: participantId)
            }
        } else if !isSpeaking && wasSpeaking {
            // Stopped speaking - add small delay to ensure they're completely done
            print("🤫 DEBUG: \(isLocal ? "User" : "AI") stopped speaking: \(participantId)")
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
    
    private func setAiThinkingState(isThinking: Bool) {
        // Don't show thinking animation if user is currently speaking OR if AI is speaking
        if isThinking && (isAnyUserSpeaking() || isAnyAiSpeaking()) {
            print("🧠 DEBUG: Skipping thinking animation - someone is currently speaking")
            return
        }
        
        for (participantId, var participant) in participantStates {
            if !participant.id.contains("local") { // Remote participant (AI)
                // Only update thinking state if AI is not currently speaking
                if !participant.isSpeaking {
                    participant.isThinking = isThinking
                    participantStates[participantId] = participant
                    
                    if isThinking {
                        print("🧠 DEBUG: Starting AI thinking animation for \(participantId)")
                        startThinkingAnimation(for: participantId)
                    } else {
                        print("🧠 DEBUG: Stopping AI thinking animation for \(participantId)")
                        stopThinkingAnimation(for: participantId)
                    }
                } else {
                    print("🧠 DEBUG: AI is speaking, skipping thinking animation for \(participantId)")
                }
            }
        }
    }
    
    private func isAnyAiSpeaking() -> Bool {
        return participantStates.values.contains { participant in
            !participant.id.contains("local") && participant.isSpeaking
        }
    }
    
    private func isAnyUserSpeaking() -> Bool {
        return participantStates.values.contains { participant in
            participant.id.contains("local") && participant.isSpeaking
        }
    }
    
    // MARK: - Visual Indicators
    
    private func createSpeakingIndicator(for participantId: ParticipantID) -> UIView {
        // This is now just a placeholder since we'll highlight the container border instead
        let indicator = UIView()
        indicator.backgroundColor = UIColor.clear
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        
        print("🎨 DEBUG: Created speaking indicator placeholder for \(participantId)")
        return indicator
    }
    
    private func createVideoPulseOverlay(for participantId: ParticipantID) -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.clear
        overlay.layer.borderColor = UIColor.systemGreen.cgColor
        overlay.layer.borderWidth = 4.0
        overlay.layer.cornerRadius = 12
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true
        overlay.isUserInteractionEnabled = false // Don't block video interaction
        
        print("🎨 DEBUG: Created video pulse overlay for \(participantId)")
        return overlay
    }
    
    private func updateSpeakingIndicator(for participantId: ParticipantID, isSpeaking: Bool) {
        print("🎨 DEBUG: updateSpeakingIndicator called for \(participantId), isSpeaking: \(isSpeaking)")
        
        // For new UI, highlight the video container border
        if isNewUIInitialized {
            let isLocalParticipant = participantId == callClient.participants.local.id
            let videoContainer = isLocalParticipant ? newLocalVideoContainer : newRemoteVideoContainer
            
            if isSpeaking {
                // Highlight container border with green glow
                videoContainer.layer.borderColor = UIColor.systemGreen.cgColor
                videoContainer.layer.borderWidth = 4.0
                videoContainer.layer.shadowColor = UIColor.systemGreen.cgColor
                videoContainer.layer.shadowRadius = 12.0
                videoContainer.layer.shadowOpacity = 0.8
                videoContainer.layer.shadowOffset = CGSize.zero
                
                // Add pulsing animation
                let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                pulseAnimation.duration = 1.0
                pulseAnimation.fromValue = 0.4
                pulseAnimation.toValue = 0.8
                pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                videoContainer.layer.add(pulseAnimation, forKey: "speaking_pulse")
                
                print("🎨 DEBUG: ✅ HIGHLIGHTED container for speaking participant \(participantId)")
            } else {
                // Remove highlight
                videoContainer.layer.borderColor = UIColor.systemGray4.cgColor
                videoContainer.layer.borderWidth = 2.0
                videoContainer.layer.shadowOpacity = 0.1
                videoContainer.layer.removeAnimation(forKey: "speaking_pulse")
                
                print("🎨 DEBUG: ❌ REMOVED highlight from container for participant \(participantId)")
            }
            return
        }
        
        // Fallback to old UI system
        let isLocalParticipant = participantId == callClient.participants.local.id
        let videoView = isLocalParticipant ? localVideoView : videoViews[participantId]
        
        guard let videoView = videoView else {
            print("❌ 🎨 DEBUG: No video view found for participant \(participantId)")
            return
        }
        
        // Simple old UI fallback - just highlight video border
        if isSpeaking {
            videoView.layer.borderColor = UIColor.systemGreen.cgColor
            videoView.layer.borderWidth = 3.0
        } else {
            videoView.layer.borderColor = UIColor.clear.cgColor
            videoView.layer.borderWidth = 0.0
        }
    }
    
    private func getVideoViewForParticipant(_ participantId: ParticipantID) -> VideoView? {
        // If new UI is active, use new video views
        if isNewUIInitialized {
            // Check if this is the local participant
            if participantId == callClient.participants.local.id {
                return newLocalVideoView
            }
            
            // For remote participants, use the new remote video view
            return newRemoteVideoView
        }
        
        // Fallback to old UI system
        if participantId == callClient.participants.local.id {
            return localVideoView
        }
        
        // Check videoViews dictionary for remote participants
        return videoViews[participantId]
    }
    
    private func startThinkingAnimation(for participantId: ParticipantID) {
        print("🧠 DEBUG: startThinkingAnimation called for \(participantId)")
        
        // Get the correct video view for the current UI mode
        guard let videoView = getVideoViewForParticipant(participantId) else {
            print("🧠 DEBUG: No video view found for thinking animation for participant \(participantId)")
            return 
        }
        
        // Create thinking overlay
        let thinkingOverlay = UIView()
        thinkingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        thinkingOverlay.layer.cornerRadius = 12
        thinkingOverlay.translatesAutoresizingMaskIntoConstraints = false
        thinkingOverlay.tag = 999 // Tag to identify thinking overlay
        
        // Add thinking dots
        let dotsContainer = UIStackView()
        dotsContainer.axis = .horizontal
        dotsContainer.spacing = 8
        dotsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        for i in 0..<3 {
            let dot = UIView()
            dot.backgroundColor = UIColor.white
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
            dotsContainer.addArrangedSubview(dot)
            
            // Animate each dot with a delay
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.duration = 1.2
            animation.fromValue = 0.3
            animation.toValue = 1.0
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(i) * 0.4
            dot.layer.add(animation, forKey: "thinking_dots")
        }
        
        thinkingOverlay.addSubview(dotsContainer)
        videoView.addSubview(thinkingOverlay)
        
        NSLayoutConstraint.activate([
            thinkingOverlay.topAnchor.constraint(equalTo: videoView.topAnchor),
            thinkingOverlay.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            thinkingOverlay.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            thinkingOverlay.bottomAnchor.constraint(equalTo: videoView.bottomAnchor),
            
            dotsContainer.centerXAnchor.constraint(equalTo: thinkingOverlay.centerXAnchor),
            dotsContainer.centerYAnchor.constraint(equalTo: thinkingOverlay.centerYAnchor)
        ])
        
        // Store the overlay for later removal
        thinkingOverlay.accessibilityIdentifier = "thinking_\(participantId)"
    }
    
    private func stopThinkingAnimation(for participantId: ParticipantID) {
        // Get the correct video view for the current UI mode
        guard let videoView = getVideoViewForParticipant(participantId) else { return }
        
        // Remove thinking overlay
        for subview in videoView.subviews {
            if subview.accessibilityIdentifier == "thinking_\(participantId)" {
                UIView.animate(withDuration: 0.3, animations: {
                    subview.alpha = 0
                }) { _ in
                    subview.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - Turn-based Conversation Management
    
    private func handleUserStartedSpeaking(participantId: ParticipantID) {
        guard isUserTurn else { return }
        
        var participant = participantStates[participantId] ?? DailyParticipant(id: participantId.description, name: userName)
        participant.lastSpokenAt = Date().timeIntervalSince1970
        participant.turnNumber = currentTurn
        participantStates[participantId] = participant
        
        // Record the turn
        recordTurn(speaker: "user", action: "started", speakerName: userName)
    }
    
    private func handleUserStoppedSpeaking(participantId: ParticipantID) {
        guard isUserTurn else { return }
        
        if let participant = participantStates[participantId] {
            let speakingDuration = Date().timeIntervalSince1970 - participant.lastSpokenAt
            
            // Record the turn completion
            recordTurn(speaker: "user", action: "stopped", speakerName: userName, duration: speakingDuration)
            
            // Switch to AI turn - thinking animation will start
            switchToAiTurn()
        }
    }
    
    private func handleAiStartedSpeaking(participantId: ParticipantID) {
        guard !isUserTurn else { return }
        
        var participant = participantStates[participantId] ?? DailyParticipant(id: participantId.description, name: coachName)
        participant.lastSpokenAt = Date().timeIntervalSince1970
        participant.turnNumber = currentTurn
        participantStates[participantId] = participant
        
        // Stop thinking animation when AI starts speaking
        setAiThinkingState(isThinking: false)
        
        // Record the turn
        recordTurn(speaker: "ai", action: "started", speakerName: coachName)
    }
    
    private func handleAiStoppedSpeaking(participantId: ParticipantID) {
        guard !isUserTurn else { return }
        
        if let participant = participantStates[participantId] {
            let speakingDuration = Date().timeIntervalSince1970 - participant.lastSpokenAt
            
            // Record the turn completion
            recordTurn(speaker: "ai", action: "stopped", speakerName: coachName, duration: speakingDuration)
            
            // Switch back to user turn
            switchToUserTurn()
        }
    }
    
    private func switchToAiTurn() {
        isUserTurn = false
        currentTurn += 1
        
        // Check if user is still speaking before showing thinking animation
        let isUserCurrentlySpeaking = isAnyUserSpeaking()
        
        if !isUserCurrentlySpeaking {
            // Show AI thinking animation only if user is not speaking
            setAiThinkingState(isThinking: true)
        }
    }
    
    private func switchToUserTurn() {
        isUserTurn = true
        currentTurn += 1
        
        print("User turn started - turn \(currentTurn)")
    }
    
    private func recordTurn(speaker: String, action: String, speakerName: String, duration: TimeInterval? = nil) {
        let turnRecord = TurnRecord(
            turn: currentTurn,
            speaker: speaker,
            speakerName: speakerName,
            action: action,
            timestamp: Date().timeIntervalSince1970,
            duration: duration
        )
        
        conversationTurns.append(turnRecord)
        print("Turn recorded: \(turnRecord)")
    }
    
    private func initializeTurnSystem() {
        currentTurn = 1
        isUserTurn = !aiFirst // If AI should start first, set user turn to false
        conversationTurns = []
        
        // Initialize turn numbers for existing participants
        for (participantId, var participant) in participantStates {
            participant.turnNumber = 0
            participant.lastSpokenAt = 0
            participantStates[participantId] = participant
        }
        
        // If AI should start first, trigger AI thinking
        if aiFirst {
            switchToAiTurn()
        }
        
        print("Turn-based conversation system initialized - AI first: \(aiFirst)")
    }
    
    private func cleanupTurnSystem() {
        // Clear all thinking states
        setAiThinkingState(isThinking: false)
        
        // Reset turn system
        currentTurn = 0
        isUserTurn = true
        conversationTurns = []
        
        // Stop all audio analyzers
        for (_, analyzer) in audioAnalyzers {
            analyzer.stopAnalyzing()
        }
        audioAnalyzers.removeAll()
        
        // Stop audio monitoring
        stopParticipantAudioMonitoring()
    }
    
    // MARK: - AudioAnalyzerDelegate
    
    func audioAnalyzer(_ analyzer: AudioAnalyzer, detectedSpeaking: Bool, for participantId: String) {
        let isLocal = participantId.contains("local")
        
        // Find the matching ParticipantID from our videoViews dictionary
        if let matchingParticipantId = videoViews.keys.first(where: { $0.description == participantId }) {
            updateParticipantSpeakingState(participantId: matchingParticipantId, isSpeaking: detectedSpeaking, isLocal: isLocal)
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Audio Monitoring Methods
    
    private var audioMonitoringTimer: Timer?
    private var lastAudioStates: [ParticipantID: Bool] = [:]
    private var audioLevelThreshold: Float = 0.1 // Minimum audio level to consider "speaking"
    private var remoteAudioLevelThreshold: Float = 0.05 // Lower threshold for remote participants (AI)
    private var lastAudioLevels: [ParticipantID: Float] = [:]
    private var speakingDetectionCounts: [ParticipantID: Int] = [:] // Consecutive detections for stability
    
    private func startParticipantAudioMonitoring() {
        // Start a timer to check participant audio states periodically (using real audio detection)
        audioMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkParticipantAudioLevels()
        }
    }
    
    private func checkParticipantAudioLevels() {
        guard callClient.callState == .joined else { return }
        
        let participants = callClient.participants
        
        // Check local participant
        let localParticipant = participants.local
        checkParticipantAudio(participant: localParticipant, isLocal: true)
        
        // Check remote participants
        for (_, participant) in participants.remote {
            checkParticipantAudio(participant: participant, isLocal: false)
        }
    }
    
    private func checkParticipantAudio(participant: Participant, isLocal: Bool) {
        var isSpeaking = false
        var audioLevel: Float = 0.0
        
        // Method 1: Try to get actual audio level from the track
        if let audioInfo = participant.media?.microphone,
           let audioTrack = audioInfo.track {
            
            // Get audio level from the track if available
            // Note: Daily.co may provide audio level information through the track
            audioLevel = getAudioLevelFromTrack(audioTrack)
            
            let hasTrack = audioTrack != nil
            let isPlayable = audioInfo.state == .playable
            let currentActiveSpeaker = callClient.activeSpeaker
            let isActiveSpeaker = currentActiveSpeaker?.id == participant.id
            
            // Method 2: Combine audio level with other indicators for more accurate detection
            if isLocal {
                let isMicrophoneEnabled = callClient.inputs.microphone.isEnabled
                // For local: use audio level above threshold + microphone enabled + active speaker
                let audioLevelSpeaking = audioLevel > audioLevelThreshold
                isSpeaking = audioLevelSpeaking && isMicrophoneEnabled && isActiveSpeaker && hasTrack && isPlayable
                
                print("🎤 DEBUG: LOCAL \(participant.id.description) - audioLevel: \(String(format: "%.3f", audioLevel)), threshold: \(audioLevelThreshold), levelSpeaking: \(audioLevelSpeaking), micEnabled: \(isMicrophoneEnabled), activeSpeaker: \(isActiveSpeaker), isSpeaking: \(isSpeaking)")
            } else {
                // For remote: use lower threshold + active speaker for better AI detection
                let audioLevelSpeaking = audioLevel > remoteAudioLevelThreshold
                isSpeaking = audioLevelSpeaking && isActiveSpeaker && hasTrack && isPlayable
                
                print("🎤 DEBUG: REMOTE \(participant.id.description) - audioLevel: \(String(format: "%.3f", audioLevel)), threshold: \(remoteAudioLevelThreshold), levelSpeaking: \(audioLevelSpeaking), activeSpeaker: \(isActiveSpeaker), isSpeaking: \(isSpeaking)")
            }
        } else {
            // Fallback to original method if no audio track available
            let currentActiveSpeaker = callClient.activeSpeaker
            let isActiveSpeaker = currentActiveSpeaker?.id == participant.id
            
            if isLocal {
                let isMicrophoneEnabled = callClient.inputs.microphone.isEnabled
                isSpeaking = isActiveSpeaker && isMicrophoneEnabled
                print("🎤 DEBUG: LOCAL \(participant.id.description) - FALLBACK: activeSpeaker: \(isActiveSpeaker), micEnabled: \(isMicrophoneEnabled), isSpeaking: \(isSpeaking)")
            } else {
                isSpeaking = isActiveSpeaker
                print("🎤 DEBUG: REMOTE \(participant.id.description) - FALLBACK: activeSpeaker: \(isActiveSpeaker), isSpeaking: \(isSpeaking)")
            }
        }
        
        // Store audio level for debugging
        lastAudioLevels[participant.id] = audioLevel
        
        // Add stability checking to avoid flickering
        let currentCount = speakingDetectionCounts[participant.id] ?? 0
        let wasSpokingBefore = lastAudioStates[participant.id] ?? false
        
        if isSpeaking {
            speakingDetectionCounts[participant.id] = currentCount + 1
            // Different stability requirements for local vs remote
            let stabilityThreshold = isLocal ? 1 : 0  // Remote (AI) can trigger immediately
            
            if currentCount >= stabilityThreshold || wasSpokingBefore {
                if !wasSpokingBefore {
                    lastAudioStates[participant.id] = true
                    print("🔊 DEBUG: Speaking state CHANGED for \(participant.id) (\(isLocal ? "LOCAL" : "REMOTE")): SPEAKING (audioLevel: \(String(format: "%.3f", audioLevel)))")
                    updateParticipantSpeakingState(participantId: participant.id, isSpeaking: true, isLocal: isLocal)
                } else if !isLocal {
                    // Refresh remote animations to keep them visible
                    updateSpeakingIndicator(for: participant.id, isSpeaking: true)
                }
            }
        } else {
            speakingDetectionCounts[participant.id] = 0
            if wasSpokingBefore {
                lastAudioStates[participant.id] = false
                print("🔊 DEBUG: Speaking state CHANGED for \(participant.id) (\(isLocal ? "LOCAL" : "REMOTE")): SILENT (audioLevel: \(String(format: "%.3f", audioLevel)))")
                updateParticipantSpeakingState(participantId: participant.id, isSpeaking: false, isLocal: isLocal)
            }
        }
    }
    
    // Helper function to extract audio level from Daily track
    private func getAudioLevelFromTrack(_ audioTrack: Any) -> Float {
        // This is a placeholder for audio level extraction
        // Daily.co SDK may provide audio level information through different methods
        // For now, we'll return a simulated level based on activeSpeaker
        // In production, you would access the actual audio level from the track
        
        // Check if this track belongs to the current active speaker
        let currentActiveSpeaker = callClient.activeSpeaker
        if let activeSpeaker = currentActiveSpeaker {
            // Find the participant that owns this track
            let allParticipants = Array(callClient.participants.remote.values) + [callClient.participants.local]
            for participant in allParticipants {
                if let micInfo = participant.media?.microphone,
                   let participantTrack = micInfo.track,
                   String(describing: participantTrack) == String(describing: audioTrack) {
                    
                    if participant.id == activeSpeaker.id {
                        // Simulate audio level for active speaker (0.2 - 0.8 range)
                        return Float.random(in: 0.2...0.8)
                    }
                }
            }
        }
        
        // Return low level for non-active speakers
        return Float.random(in: 0.0...0.05)
    }
    
    private func stopParticipantAudioMonitoring() {
        audioMonitoringTimer?.invalidate()
        audioMonitoringTimer = nil
        lastAudioStates.removeAll()
    }
    
    private func simulateRemoteParticipantSpeaking(participantId: ParticipantID, isSpeaking: Bool) {
        // This method can be called when we detect remote participant speaking through other means
        // such as Daily's participant events or when we know the AI is supposed to be speaking
        updateParticipantSpeakingState(participantId: participantId, isSpeaking: isSpeaking, isLocal: false)
    }
    

    
//    App Black RGB 9, 30, 66, 1
//    App Background Grey 244, 245, 247, 0.08
    
    let callClient: CallClient = .init()
    // The local participant video view.
    private let localVideoView: VideoView = .init()
    private var allParticipantJoined : Bool = false;
    
    private var participantIds: [String] = []
    private var remoteParticipantId : String = "";
    private var bottomView: UIView!

    // A dictionary of remote participant video views.
    private var videoViews: [ParticipantID: VideoView] = [:]

    private let token: MeetingToken
    private let roomURLString: String
    private let userName: String
    private let coachingTitle: String
    private let coachName: String
    private let isTestMode: Bool
    private let maxTime: TimeInterval
    private var currentTime: TimeInterval = 1
    var timer:Timer?
    
    // UI elements
    var leaveRoomButton: UIButton!
    var microphoneInputButton: UIButton!
    var cameraInputButton: UIButton!
    var participantsStack: UIStackView!
    var currentTimeLabel: UILabel!
    var titleLabel: UILabel!
    var timerLabel: UILabel!
    var timerView: UIView!
    var topView: UIView!
    var overlayView: UIView!
    var endButtonContainer: UIView!
    
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
    private var recordingStartTime: TimeInterval?
    private var currentRecordingId: String?
    // var onDismiss: (() -> Void)?
    private var recordingStarted: Bool = false;
    private var disconnectionAlert: UIAlertController?
   
    init(urlString: String, token: String, userName: String, coachingTitle: String, maxTime: Int, coachName: String, testMode: Bool ) {
        self.roomURLString = urlString
        self.token = MeetingToken(stringValue: token)
        self.userName = userName
        self.coachingTitle = coachingTitle;
        self.maxTime = TimeInterval(maxTime);
        self.coachName = coachName;
        self.isTestMode = testMode;
        super.init(nibName: nil, bundle: nil)
    }
    
    let hRed: CGFloat = 244.0 / 255.0   // Red component (0 to 1)
    let hGreen: CGFloat = 245.0 / 255.0 // Green component (0 to 1)
    let hBlue: CGFloat = 247.0 / 255.0   // Blue component (0 to 1)
    let hAlpha: CGFloat = 1.0           // Alpha component (0 to 1)
    
    
    let cRed: CGFloat = 9.0 / 255.0   // Red component (0 to 1)
    let cGreen: CGFloat = 30.0 / 255.0 // Green component (0 to 1)
    let cBlue: CGFloat = 66.0 / 255.0   // Blue component (0 to 1)
    let cAlpha: CGFloat = 1.0          // Alpha component (0 to 1)
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func leave() {
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                self.onDismiss?()
            }
        }
        
        self.left();
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
    
    // In your existing call state handling method (where you handle call state changes)
    private func handleCallStateChange(_ state: CallState) {
        onCallStateChange?(state)
    }
    
    // In your network quality monitoring method
    private func handleNetworkQualityChange(_ quality: String) {
        onNetworkQualityChange?(quality)
    }
    
    // In your participant joined handler
    private func handleParticipantJoined(_ participant: Participant) {
        print("Participant \(participant) joined. handleParticipantJoined")
        let participantString = "\(participant)"
        onParticipantJoined?(participantString)
    }
    
    // In your dismiss/close method
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        onDismiss?()
        super.dismiss(animated: flag, completion: completion)
    }

   // Update the return type to be non-optional
    func getCallStatus() -> CallState {
        return self.callClient.callState
    }
    
    func startTimer() {
        // let message = "\(self.coachName) will be joining us shortly."
        // self.showAlert(message: message)
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    @objc func updateTime() {
        currentTime += 1

        // Calculate remaining time
        let remainingTime = maxTime - currentTime

        // Check if exactly 1 minute remains
        if remainingTime == 60 {
            DispatchQueue.main.async {
                self.showTimeWarningAlert()
            }
        }

        // Check if current time exceeds max time
        if currentTime > maxTime {
            timer?.invalidate()
            timer = nil
            // Optionally handle the case when the timer exceeds max time
        } else {
            timerLabel.text = "\(formatTime(currentTime)) / \(formatTime(maxTime))"
            
            // Also update new UI timer if active
            if isNewUIInitialized {
                updateNewTimer(currentTime: currentTime, maxTime: maxTime)
            }
        }
    }
        
    func formatTime(_ time: TimeInterval) -> String {
        _ = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d",  minutes, seconds)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        self.modalPresentationStyle = .fullScreen
        self.isModalInPresentation = true;
        // Setup CallClient delegate
        self.callClient.delegate = self

            // Safely handle the broadcast picker view
        if let broadcastPickerView = self.systemBroadcastPickerView as? RPSystemBroadcastPickerView {
            broadcastPickerView.preferredExtension = "group.com.smartwinnr.daily.broadcast"
            broadcastPickerView.showsMicrophoneButton = false
        } else {
            // Create a new broadcast picker view if the outlet is not connected
            let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            pickerView.preferredExtension = "group.com.smartwinnr.daily.broadcast"
            pickerView.showsMicrophoneButton = false
            self.systemBroadcastPickerView = pickerView
        }
        
        // Create buttons
        createButtons()
        
        // Create stack view
        createStackView()
        
        updateControls()
        
        // Setup constraints
        setupConstraints()
        startTimer();
        
        // Initialize and enable the new UI design
        enableNewUILayout()
        
        // Create and configure the overlay view
        overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.layer.cornerRadius = 10
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(overlayView)

        // Create and configure the label
        let messageLabel = UILabel()
        messageLabel.text = self.isTestMode ? "Meeting will be starting shortly." : "\(self.coachName) will be joining us shortly please wait."
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 20)
        messageLabel.textColor = .white
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        overlayView.addSubview(messageLabel)

        // Set constraints for the overlay view
        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            overlayView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.8),
            overlayView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.2)
        ])

        // Set constraints for the message label
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -10),
            messageLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -10)
        ])
        
        if (self.isTestMode) {
            // Add tap gesture recognizer to overlay view
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyTextToClipboard))
            overlayView.addGestureRecognizer(tapGesture)
        }

        
        guard let roomURL = URL(string: roomURLString) else {
            return
        }
        
        self.callClient.join(url: roomURL, token: token, settings: ClientSettingsUpdate() ) { result in
            switch result {
            case .success(_):
                print("Joined call")
                self.callClient.set(username: self.userName) { result in
                    switch result {
                    case .success(_):
                        // Handle successful join
                        self.callClient.updateInputs(.set(
                            camera: .set(
                                settings: .set(facingMode: .set(.user)
                                )
                            )
                        ), completion: nil)


                        if (self.isTestMode) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                self.allParticipantJoined = true;
                                
                                self.callClient.startRecording() { result in
                                    switch result {
                                    case .success(_):
                                        DispatchQueue.main.async {
                                            self.removeOverlayView()
                                        }
                                    case .failure(let error):
                                        // Handle join failure
                                        print("Failed startRecording: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                        
                    case .failure(let error):
                        // Handle join failure
                        print("Failed to join call: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                // Handle join failure
                print("Failed to join call: \(error.localizedDescription)")
            }
        }
        
        // Add the local participant's video view to the stack view.
        self.participantsStack.addArrangedSubview(self.localVideoView)
        
    }

    @objc func copyTextToClipboard() {
        let message = "\(self.roomURLString)?t=\(self.token)";
        UIPasteboard.general.string = message

        // Show a brief confirmation to the user
        let alert = UIAlertController(title: "Copied!", message: "Meeting link has been copied to clipboard.", preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
        
        // Dismiss the alert after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.removeOverlayView()
            }
        }
    }
    
    
    private func updateControls() {
        // Set the image for the camera button.
        cameraInputButton.setImage(
            UIImage(systemName: callClient.inputs.camera.isEnabled ? "video.fill": "video.slash.fill"),
            for: .normal
        )

        // Set the image for the mic button.
        microphoneInputButton.setImage(
            UIImage(systemName: callClient.inputs.microphone.isEnabled ? "mic.fill": "mic.slash.fill"),
            for: .normal
        )
        
        // Also update new UI buttons if active
        if isNewUIInitialized {
            updateNewUIControls()
        }
    }
    
    private func updateNewUIControls() {
        // Update new camera button
        newCameraButton.setImage(
            UIImage(systemName: callClient.inputs.camera.isEnabled ? "video.fill": "video.slash.fill"),
            for: .normal
        )
        
        // Update new mic button
        newMicButton.setImage(
            UIImage(systemName: callClient.inputs.microphone.isEnabled ? "mic.fill": "mic.slash.fill"),
            for: .normal
        )
    }
    
    func createButtons() {

        // Replace the existing broadcast picker creation with:
//        if let picker = DailyBroadcastHelper.shared.setupBroadcastPickerView() {
//            broadcastPickerView = picker
//            broadcastPickerView.translatesAutoresizingMaskIntoConstraints = false
//            self.localVideoView.addSubview(broadcastPickerView)
//        }

        // Create bottom container view
        bottomView = UIView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.backgroundColor = .clear // Changed from white with alpha
        // Remove corner radius and shadow properties
        view.addSubview(bottomView)

         // Create gradient layer for the button
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1.0).cgColor,  // Bright red at top
            UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1.0).cgColor   // Darker red at bottom
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.cornerRadius = 25

        // Create the button and add directly to bottomView
        leaveRoomButton = UIButton(type: .custom) // Change to .custom instead of .system
        leaveRoomButton.setTitle("End Role Play", for: .normal)
        leaveRoomButton.setTitleColor(.white, for: .normal)
        leaveRoomButton.backgroundColor = .systemRed
        leaveRoomButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        leaveRoomButton.translatesAutoresizingMaskIntoConstraints = false
        leaveRoomButton.isUserInteractionEnabled = true // Explicitly enable user interaction
        bottomView.addSubview(leaveRoomButton)

        
        // Add icon to button
        let buttonConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let phoneImage = UIImage(systemName: "phone.down.fill", withConfiguration: buttonConfig)
        leaveRoomButton.setImage(phoneImage, for: .normal)
        leaveRoomButton.tintColor = .white
        leaveRoomButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        leaveRoomButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        
        // Add shadow and other visual effects
        leaveRoomButton.layer.cornerRadius = 25
        leaveRoomButton.layer.shadowColor = UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 0.5).cgColor
        leaveRoomButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        leaveRoomButton.layer.shadowRadius = 8
        leaveRoomButton.layer.shadowOpacity = 0.5
        
        // Add gradient background
        leaveRoomButton.layer.insertSublayer(gradientLayer, at: 0)
        
        // Add multiple targets to ensure touch handling
        leaveRoomButton.addTarget(self, action: #selector(didTapLeaveRoom), for: .touchUpInside)
        leaveRoomButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        leaveRoomButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

       
        let controlButtonConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        microphoneInputButton = UIButton(type: .system)
        microphoneInputButton.translatesAutoresizingMaskIntoConstraints = false
        microphoneInputButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        microphoneInputButton.layer.cornerRadius = 20
        microphoneInputButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: controlButtonConfig), for: .normal)
        microphoneInputButton.layer.shadowColor = UIColor.black.cgColor
        microphoneInputButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        microphoneInputButton.layer.shadowRadius = 4
        microphoneInputButton.layer.shadowOpacity = 0.2
        microphoneInputButton.addTarget(self, action: #selector(didTapToggleMicrophone), for: .touchUpInside)
        
        cameraInputButton = UIButton(type: .system)
        cameraInputButton.translatesAutoresizingMaskIntoConstraints = false
        cameraInputButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cameraInputButton.layer.cornerRadius = 20
        cameraInputButton.setImage(UIImage(systemName: "video.fill", withConfiguration: controlButtonConfig), for: .normal)
        cameraInputButton.layer.shadowColor = UIColor.black.cgColor
        cameraInputButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraInputButton.layer.shadowRadius = 4
        cameraInputButton.layer.shadowOpacity = 0.2
        cameraInputButton.addTarget(self, action: #selector(didTapToggleCamera), for: .touchUpInside)
                
        // Set up title label
        titleLabel = UILabel()
        titleLabel.text = self.coachingTitle
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor(red: hRed, green: hGreen, blue: hBlue, alpha: hAlpha)
        titleLabel.textColor = UIColor(red: cRed, green: cGreen, blue: cBlue, alpha: cAlpha)
        titleLabel.layer.cornerRadius = 10
        titleLabel.layer.masksToBounds = true
        titleLabel.numberOfLines = 0 // Enable multiple lines
        titleLabel.lineBreakMode = .byWordWrapping // Enable word wrapping
                
    
        topView = UIView()
        topView.translatesAutoresizingMaskIntoConstraints = false
        topView.backgroundColor = UIColor(red: hRed, green: hGreen, blue: hBlue, alpha: hAlpha)
        topView.layer.cornerRadius = 10
        view.addSubview(topView)
        topView.addSubview(titleLabel)
                
        // Timer setup
        timerView = UIView()
        timerView.translatesAutoresizingMaskIntoConstraints = false
        timerView.backgroundColor = .clear
        timerView.layer.cornerRadius = 10
        view.addSubview(timerView)

        timerLabel = UILabel()
        timerLabel.text = ""
        timerLabel.textAlignment = .center
        timerLabel.backgroundColor = .clear // Changed from .systemBackground
        timerLabel.textColor = UIColor.orange
        timerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerView.addSubview(timerLabel)
        
        self.localVideoView.addSubview(cameraInputButton)
        self.localVideoView.addSubview(microphoneInputButton)
        // Constraints for bottomView and buttons will be added in setupConstraints()
    }
    
    func createStackView() {
        participantsStack = UIStackView()
        participantsStack.translatesAutoresizingMaskIntoConstraints = false
        participantsStack.axis = .vertical
        participantsStack.distribution = .fillEqually
        participantsStack.spacing = 16
        participantsStack.backgroundColor = .clear
        participantsStack.layer.cornerRadius = 12
        participantsStack.clipsToBounds = true
        view.addSubview(participantsStack)
        
        // Add gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBackground.withAlphaComponent(0.95).cgColor,
            UIColor.systemBackground.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func setupConstraints() {
        // Safe area
        let safeArea = view.safeAreaLayoutGuide
        let margin: CGFloat = 16.0

        // Bottom view
        // let bottomView = leaveRoomButton.superview!
        // let topView = leaveRoomButton.superview!

        NSLayoutConstraint.activate([

            topView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topView.heightAnchor.constraint(equalToConstant: 50), // Adjust height as needed
            
            titleLabel.topAnchor.constraint(equalTo: topView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: topView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: topView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: topView.bottomAnchor),
            
            // Updated Timer View constraints
            timerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 65),
            timerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            timerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            timerView.heightAnchor.constraint(equalToConstant: 50),

            // Updated Timer Label constraints
            timerLabel.centerYAnchor.constraint(equalTo: timerView.centerYAnchor),
            timerLabel.leadingAnchor.constraint(equalTo: timerView.leadingAnchor),
            timerLabel.trailingAnchor.constraint(equalTo: timerView.trailingAnchor),
            
            // Participants Stack - Main video container
            participantsStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 120),
            participantsStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: margin),
            participantsStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -margin),
            participantsStack.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: -margin),
            
            // Control buttons - Float over video
            microphoneInputButton.leadingAnchor.constraint(equalTo: localVideoView.leadingAnchor, constant: margin),
            microphoneInputButton.bottomAnchor.constraint(equalTo: localVideoView.bottomAnchor, constant: -margin),
            microphoneInputButton.widthAnchor.constraint(equalToConstant: 40),
            microphoneInputButton.heightAnchor.constraint(equalToConstant: 40),
            
            cameraInputButton.leadingAnchor.constraint(equalTo: microphoneInputButton.trailingAnchor, constant: margin/2),
            cameraInputButton.bottomAnchor.constraint(equalTo: localVideoView.bottomAnchor, constant: -margin),
            cameraInputButton.widthAnchor.constraint(equalToConstant: 40),
            cameraInputButton.heightAnchor.constraint(equalToConstant: 40),

            // Bottom View constraints - update to be closer to the bottom
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 80), // Adjust height as needed

            // Update leave room button constraints to attach directly to bottomView
            leaveRoomButton.centerXAnchor.constraint(equalTo: bottomView.centerXAnchor),
            leaveRoomButton.topAnchor.constraint(equalTo: bottomView.topAnchor, constant: 16),
            leaveRoomButton.widthAnchor.constraint(equalTo: bottomView.widthAnchor, multiplier: 0.6),
            leaveRoomButton.heightAnchor.constraint(equalToConstant: 50),
            
        ])
        
    }
    
    @objc func didTapLeaveRoom() {
        // Add visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.leaveRoomButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                let identityTransform = CGAffineTransform.identity
                self.leaveRoomButton.transform = identityTransform
            }
        }

        // Disable button to prevent multiple taps
        self.leaveRoomButton.isEnabled = false
        
        // Cleanup turn system and audio detection
        self.cleanupTurnSystem()
        self.stopParticipantAudioMonitoring()
        
        self.callClient.stopRecording() { [weak self] result in
            guard let self = self else { return }
            
            // Re-enable button in case of failure
            DispatchQueue.main.async {
                self.leaveRoomButton.isEnabled = true
            }
            
            switch result {
            case .success(_):
                if let recordingId = self.currentRecordingId {
                    let stopTime = Date().timeIntervalSince1970
                    self.onRecordingStopped?(recordingId, stopTime)
                }
                
                let participants = self.callClient.participants
                let localParticipant = participants.local
                self.removeParticipantView(participantId: localParticipant.id)
                self.callClient.leave() { result in
                    self.timer?.invalidate()
                    self.timer = nil
                    self.leave()
                }
            case .failure(let error):
                print("Failed to stop recording: \(error.localizedDescription)")
                self.onRecordingError?(error.localizedDescription)
                self.callClient.leave() { result in
                    self.timer?.invalidate()
                    self.timer = nil
                    self.leave()
                }
            }
        }
    }
    
    @objc func didTapToggleMicrophone() {
        let microphoneIsEnabled = self.callClient.inputs.microphone.isEnabled;
        self.callClient.setInputsEnabled([.microphone : !microphoneIsEnabled]) { result in
            switch result {
            case .success(_):
                // Handle successful recording stop
                self.updateControls()
                
            case .failure(let error):
                // Handle join failure
                print("didTapToggleMicrophone: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func didTapToggleCamera() {
        let cameraIsEnabled = self.callClient.inputs.camera.isEnabled;
        self.callClient.setInputsEnabled([.camera : !cameraIsEnabled]) { result in
            switch result {
            case .success(_):
                // Handle successful recording stop
                self.updateControls()
                
            case .failure(let error):
                // Handle join failure
                print("didTapToggleCamera: \(error.localizedDescription)")
            }
        }
    }
    
    func updateParticipantView(participantId: ParticipantID, videoTrack: VideoTrack) {
        if let videoView = videoViews[participantId] {
            videoView.track = videoTrack
        } else {
            let videoView = VideoView()
            videoView.translatesAutoresizingMaskIntoConstraints = false
            videoView.track = videoTrack
            videoView.layer.cornerRadius = 12
            videoView.clipsToBounds = true
            
            // Also update new UI if active
            if isNewUIInitialized {
                attachVideoTrack(videoTrack, for: participantId, isLocal: false)
            }
            
            videoView.layer.borderWidth = 2
            videoView.layer.borderColor = UIColor.systemGray5.cgColor
            videoView.layer.shadowColor = UIColor.black.cgColor
            videoView.layer.shadowOffset = CGSize(width: 0, height: 2)
            videoView.layer.shadowRadius = 4
            videoView.layer.shadowOpacity = 0.2
            videoViews[participantId] = videoView
            participantsStack.addArrangedSubview(videoView)
        }
    }
    
    func removeParticipantView(participantId: ParticipantID) {
        if let videoView = videoViews[participantId] {
            participantsStack.removeArrangedSubview(videoView)
            videoView.removeFromSuperview()
            videoViews.removeValue(forKey: participantId)
        }
    }

    func createOverlayView() {
        // Create and configure the overlay view with white background
        overlayView = UIView()
        overlayView.backgroundColor = .white // Pure white background
        overlayView.layer.cornerRadius = 16
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle shadow
        overlayView.layer.shadowColor = UIColor.black.cgColor
        overlayView.layer.shadowOffset = CGSize(width: 0, height: 4)
        overlayView.layer.shadowRadius = 8
        overlayView.layer.shadowOpacity = 0.1
        
        self.view.addSubview(overlayView)

        // Create and configure the label with black text
        let messageLabel = UILabel()
        messageLabel.text = self.isTestMode ? 
        "Meeting will be starting shortly." : 
        (self.allParticipantJoined ? 
            "Click here to copy this meeting link and share with your coach." : 
            "\(self.coachName) will be joining us shortly please wait.")
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = .black // Changed to black text
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        overlayView.addSubview(messageLabel)

        // Set constraints for the overlay view with improved positioning
        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            overlayView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.85),
            overlayView.heightAnchor.constraint(lessThanOrEqualTo: self.view.heightAnchor, multiplier: 0.25)
        ])

        // Set constraints for the message label with better padding
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -24),
            messageLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 24),
            messageLabel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -24)
        ])

        if (self.isTestMode) {
            // self.overlayView.isHidden = true
            // Add tap gesture recognizer to overlay view
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyTextToClipboard))
            overlayView.addGestureRecognizer(tapGesture)
        }
        
        // Optional: Add subtle animation when showing
        overlayView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.overlayView.alpha = 1
        }
    }

    // Update the removeOverlayView method for smooth dismissal
    func removeOverlayView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayView.alpha = 0
            self.overlayView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            self.overlayView.removeFromSuperview()
            if (self.isTestMode == true && !self.allParticipantJoined) {
                DispatchQueue.main.async {
                    self.createOverlayView()
                }
            }
        }
    }

    // Update showAlert method to match the style
    func showAlert(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.view.window != nil else { return }
            
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.view.tintColor = UIColor(red: self.cRed, green: self.cGreen, blue: self.cBlue, alpha: self.cAlpha)
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

    // Add this new method
    private func showTimeWarningAlert() {
        let alert = UIAlertController(
            title: "Time Warning",
            message: "Your session will end in 1 minute.",
            preferredStyle: .alert
        )
        
        // Customize alert appearance
        alert.view.tintColor = UIColor(red: cRed, green: cGreen, blue: cBlue, alpha: cAlpha)
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
        
        // Present the alert
        self.present(alert, animated: true)
        
        // Automatically dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            alert.dismiss(animated: true)
        }
    }

            
}

extension DailyCallViewController: CallClientDelegate {

     func callClientDidDetectStartOfSystemBroadcast(
        _ callClient: CallClient
    ) {
        print("System broadcast started")
        

        callClient.updateInputs(
            .set(screenVideo: .set(isEnabled: .set(true))),
            completion: nil
        )
    }

    public func callClientDidDetectEndOfSystemBroadcast(
        _ callClient: CallClient
    ) {
        print("System broadcast ended")

        callClient.updateInputs(
            .set(screenVideo: .set(isEnabled: .set(false))),
            completion: nil
        )
    }
    
    func callClient(_ callClient: CallClient, inputsUpdated inputs: InputSettings) {
        updateControls()
    }
            
    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
        print("Participant \(participant.id) joined the call. participantJoined")
        // Create a new view for this participant's video track.
        let videoView = VideoView()
        videoView.videoScaleMode = .fit
        videoView.backgroundColor = .black  // Optional: adds black background for letterboxing

        videoView.layer.cornerRadius = 10
        videoView.layer.masksToBounds = true
        
        let nameLabel = UILabel()
        nameLabel.text = participant.info.username ?? self.userName
        nameLabel.textAlignment = .center
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.layer.cornerRadius = 10
        nameLabel.layer.masksToBounds = true
        videoView.addSubview(nameLabel)
        
        // Set up constraints for nameLabel with margin
        let margin: CGFloat = 8.0 // Adjust the margin as needed
        NSLayoutConstraint.activate([
            nameLabel.trailingAnchor.constraint(equalTo: videoView.trailingAnchor, constant: -margin), // Place at the right
            nameLabel.bottomAnchor.constraint(equalTo: videoView.bottomAnchor, constant: -margin), // Place at the bottom
            nameLabel.widthAnchor.constraint(lessThanOrEqualTo: videoView.widthAnchor, multiplier: 0.5), // Adjust the width as needed
            nameLabel.heightAnchor.constraint(equalToConstant: 30) // Adjust the height as needed
        ])
        
        self.callClient.startRecording() { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let recordingInfo):
                // Handle successful recording start
                print("Recording Started")
                self.recordingStartTime = Date().timeIntervalSince1970
                self.currentRecordingId = "\(recordingInfo)"
                self.recordingStarted = true;
                
                // Trigger recording started callback
                if let recordingId = self.currentRecordingId,
                    let startTime = self.recordingStartTime {
                    self.onRecordingStarted?(recordingId, startTime)
                }
                
                DispatchQueue.main.async {
                    self.removeOverlayView()
                }
                self.joined()
            case .failure(let error):
                print("Failed startRecording: \(error.localizedDescription)")
                // Trigger the new error callback
                self.onRecordingError?(error.localizedDescription)
            }
        }

        // Determine whether the video input is from the camera or screen.
        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = screenTrack ?? cameraTrack

        // Set the track for this participant's video view.
        videoView.track = videoTrack

        // Add this participant's video view to the dictionary.
        self.videoViews[participant.id] = videoView

        // Add this participant's video view to the stack view.
        self.participantsStack.addArrangedSubview(videoView)
        
        // Initialize participant state for speaking detection
        let participantState = DailyParticipant(
            id: participant.id.description,
            name: participant.info.username ?? "Remote User"
        )
        self.participantStates[participant.id] = participantState
        print("👤 DEBUG: Initialized participant state for \(participant.id) - name: \(participantState.name)")
        print("👤 DEBUG: Total participants tracked: \(self.participantStates.count)")
        print("👤 DEBUG: Video views count: \(self.videoViews.count)")
        
        // Initialize turn-based conversation system after all participants join
        if !self.allParticipantJoined {
            self.allParticipantJoined = true
            self.initializeTurnSystem()
            
            // Start audio level monitoring using Daily's participant audio info
            self.startParticipantAudioMonitoring()
            
            // Test AI animation after a delay to ensure everything is setup
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🧪 DEBUG: Testing AI animations for remote participants")
                for (remoteId, _) in self.participantStates {
                    if remoteId != participant.id {
                        print("🧪 DEBUG: Testing animation for remote participant \(remoteId)")
                        self.updateSpeakingIndicator(for: remoteId, isSpeaking: true)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.updateSpeakingIndicator(for: remoteId, isSpeaking: false)
                        }
                    }
                }
            }

        }
    }
    
    // Handle a participant updating (e.g., their tracks changing)
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        print("Participant \(participant.id) updated. participantUpdated")
        // Convert the participant object to a string representation
        
        // Pass the string representation to the handleParticipantJoined method
        handleParticipantJoined(participant)
        
        // Determine whether the video track is for a screen or camera.
        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = cameraTrack ?? screenTrack

        if participant.info.isLocal {
            // Update the track for the local participant's video view.
            self.localVideoView.videoScaleMode = .fit
            self.localVideoView.backgroundColor = .black
            self.localVideoView.track = videoTrack
            self.localVideoView.layer.cornerRadius = 10
            self.localVideoView.layer.masksToBounds = true
            
            // Also update new UI if active
            if self.isNewUIInitialized && videoTrack != nil {
                self.attachVideoTrack(videoTrack!, for: participant.id, isLocal: true)
            }
            let nameLabel = UILabel()
            nameLabel.text = self.userName
            nameLabel.textAlignment = .center
            nameLabel.textColor = .white
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            nameLabel.layer.cornerRadius = 10
            nameLabel.layer.masksToBounds = true
            
            self.localVideoView.addSubview(nameLabel)
                        
            // Set up constraints for nameLabel with margin
            let margin: CGFloat = 8.0 // Adjust the margin as needed
            
            // Name Label Constraints
            NSLayoutConstraint.activate([
                nameLabel.trailingAnchor.constraint(equalTo: self.localVideoView.trailingAnchor, constant: -margin), // Place at the right
                nameLabel.bottomAnchor.constraint(equalTo: self.localVideoView.bottomAnchor, constant: -margin), // Place at the bottom
                nameLabel.widthAnchor.constraint(lessThanOrEqualTo: self.localVideoView.widthAnchor, multiplier: 0.5), // Adjust the width as needed
                nameLabel.heightAnchor.constraint(equalToConstant: 30) // Adjust the height as needed
            ])
            
            // Initialize local participant state for speaking detection
            let localParticipantState = DailyParticipant(
                id: participant.id.description,
                name: self.userName
            )
            self.participantStates[participant.id] = localParticipantState

            if (self.isTestMode) {
                DispatchQueue.main.async {
                    self.removeOverlayView()
                }
            }
            
        } else {
            // Remove existing video views for remote participants only
            for (id, existingView) in self.videoViews {
                if !participant.info.isLocal {
                    existingView.removeFromSuperview()
                    self.videoViews.removeValue(forKey: id)
                }
            }
            
            // Create and configure new video view
            let videoView = VideoView()
            videoView.translatesAutoresizingMaskIntoConstraints = false
            videoView.videoScaleMode = .fit
            videoView.backgroundColor = .black
            videoView.track = videoTrack
            videoView.layer.cornerRadius = 10
            videoView.layer.masksToBounds = true
            
            // Also update new UI if active
            if self.isNewUIInitialized && videoTrack != nil {
                self.attachVideoTrack(videoTrack!, for: participant.id, isLocal: false)
            }
            
            // Add name label for remote participant
            let nameLabel = UILabel()
            nameLabel.text = participant.info.username ?? "Remote User"
            nameLabel.textAlignment = .center
            nameLabel.textColor = .white
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            nameLabel.layer.cornerRadius = 10
            nameLabel.layer.masksToBounds = true
            
            videoView.addSubview(nameLabel)
            
            // Set up constraints for nameLabel with margin
            let margin: CGFloat = 8.0
            NSLayoutConstraint.activate([
                nameLabel.trailingAnchor.constraint(equalTo: videoView.trailingAnchor, constant: -margin),
                nameLabel.bottomAnchor.constraint(equalTo: videoView.bottomAnchor, constant: -margin),
                nameLabel.widthAnchor.constraint(lessThanOrEqualTo: videoView.widthAnchor, multiplier: 0.5),
                nameLabel.heightAnchor.constraint(equalToConstant: 30)
            ])
            
            // Add to dictionary and stack view with new participant ID
            self.videoViews[participant.id] = videoView
            self.participantsStack.addArrangedSubview(videoView)
            
            // Initialize remote participant state for speaking detection
            let remoteParticipantState = DailyParticipant(
                id: participant.id.description,
                name: participant.info.username ?? "Remote User"
            )
            self.participantStates[participant.id] = remoteParticipantState

            // Dismiss any existing disconnection alert
            if let alert = self.disconnectionAlert {
                alert.dismiss(animated: true)
                self.disconnectionAlert = nil
            }
            
            if (self.isTestMode) {
                DispatchQueue.main.async {
                    self.removeOverlayView()
                }
            }
        }
    }

    // When call state changes
    func callClient(_ callClient: CallClient, callStateUpdated callState: CallState) {
        handleCallStateChange(callState)
    }

    // When network quality changes
    func callClient(_ callClient: CallClient, networkQualityChanged quality: String) {
        handleNetworkQualityChange(quality)
    }
    
    // When active speaker changes - this provides real-time speaking detection
    func callClient(_ callClient: CallClient, activeSpeakerChanged activeSpeaker: Participant?) {
        print("🔊 DEBUG: Active speaker changed to: \(activeSpeaker?.id.description ?? "none")")
        
        // Update all participants' speaking state based on active speaker
        for (participantId, _) in participantStates {
            let isSpeaking = activeSpeaker?.id == participantId
            let isLocal = participantId == callClient.participants.local.id
            
            print("🔊 DEBUG: Updating participant \(participantId.description) (\(isLocal ? "local" : "remote")) speaking state to: \(isSpeaking)")
            updateParticipantSpeakingState(participantId: participantId, isSpeaking: isSpeaking, isLocal: isLocal)
        }
    }

    func callClient(
        _ callClient: CallClient,
        participantCountsUpdated participantCounts: ParticipantCounts
    ) {
        if (participantCounts.present < 2 && self.recordingStarted == true) {
            self.onParticipantCountChanged?(participantCounts.present)
        }
    }

    func callClient(
        _ callClient: CallClient,
        participantLeft participant: Participant,
        withReason reason: ParticipantLeftReason
    ) {
        print("Participant \(participant.id) left the call. participantLeft with reason: \(reason)")
        if (participant.info.isLocal) {
            
        } else {
            // Remove existing video views for remote participants only
            let participantName = participant.info.username ?? "AI"
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Participant Disconnected",
                    message: "\(participantName) has left due to network issues. Please wait while they rejoin.",
                    preferredStyle: .alert
                )
                self.present(alert, animated: true)
                
                // Store alert reference to dismiss it later when participant rejoins
                self.disconnectionAlert = alert
            }
            for (id, existingView) in self.videoViews {
                if !participant.info.isLocal {
                    existingView.removeFromSuperview()
                    self.videoViews.removeValue(forKey: id)
                }
            }
            
            // Clean up participant state and speaking indicators
            self.participantStates.removeValue(forKey: participant.id)
            if let indicator = self.speakingIndicators[participant.id] {
                indicator.removeFromSuperview()
                self.speakingIndicators.removeValue(forKey: participant.id)
            }
            self.stopThinkingAnimation(for: participant.id)
        }
    }
    
}


