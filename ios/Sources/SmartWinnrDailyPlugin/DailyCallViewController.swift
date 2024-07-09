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

class DailyCallViewController: UIViewController {
    
    let callClient: CallClient = .init()
    
    // The local participant video view.
    private let localVideoView: VideoView = .init()

   // A dictionary of remote participant video views.
   private var videoViews: [ParticipantID: VideoView] = [:]

    private let token: MeetingToken
    private let roomURLString: String
    
    init(urlString: String, token: String) {
        self.roomURLString = urlString
        self.token = MeetingToken(stringValue: token)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    
    
    // UI elements
    var leaveRoomButton: UIButton!
    var microphoneInputButton: UIButton!
    var cameraInputButton: UIButton!
    var participantsStack: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Setup CallClient delegate
        self.callClient.delegate = self
        
        // Create buttons
        createButtons()
        
        // Create stack view
        createStackView()
        
        updateControls()
        
        // Setup constraints
        setupConstraints()
        
        // let roomURLString: String = "https://smartwinnr.daily.co/chatroom";
        
        guard let roomURL = URL(string: roomURLString) else {
            print("Invalid room URL")
            return
        }
        
        self.callClient.join(url: roomURL, token: token) { result in
            switch result {
            case .success(let callJoinData):
                // Handle successful join
                print("Joined call with ID: ")
                print(callJoinData)
            case .failure(let error):
                // Handle join failure
                print("Failed to join call: \(error.localizedDescription)")
            }
        }
        
        // Add the local participant's video view to the stack view.
        self.participantsStack.addArrangedSubview(self.localVideoView)
        // Join the call
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
    }
    
    func createButtons() {
        leaveRoomButton = UIButton(type: .system)
        leaveRoomButton.translatesAutoresizingMaskIntoConstraints = false
        leaveRoomButton.backgroundColor = .systemRed
        leaveRoomButton.tintColor = .white
        leaveRoomButton.layer.cornerRadius = 30
        let xmarkImage = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium))
        leaveRoomButton.setImage(xmarkImage, for: .normal)
        leaveRoomButton.addTarget(self, action: #selector(didTapLeaveRoom), for: .touchUpInside)
        
        microphoneInputButton = UIButton(type: .system)
        microphoneInputButton.translatesAutoresizingMaskIntoConstraints = false
        microphoneInputButton.backgroundColor = .systemGray2
        microphoneInputButton.tintColor = .white
        microphoneInputButton.layer.cornerRadius = 30
        let micImage = UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        microphoneInputButton.setImage(micImage, for: .normal)
       microphoneInputButton.addTarget(self, action: #selector(didTapToggleMicrophone), for: .touchUpInside)
        
        cameraInputButton = UIButton(type: .system)
        cameraInputButton.translatesAutoresizingMaskIntoConstraints = false
        cameraInputButton.backgroundColor = .systemGray2
        cameraInputButton.tintColor = .white
        cameraInputButton.layer.cornerRadius = 30
        let videoImage = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        cameraInputButton.setImage(videoImage, for: .normal)
       cameraInputButton.addTarget(self, action: #selector(didTapToggleCamera), for: .touchUpInside)
        
        let bottomView = UIView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.backgroundColor = .systemGray5
        bottomView.layer.cornerRadius = 15
        view.addSubview(bottomView)
        
        bottomView.addSubview(leaveRoomButton)
        bottomView.addSubview(microphoneInputButton)
        bottomView.addSubview(cameraInputButton)
        
        // Constraints for bottomView and buttons will be added in setupConstraints()
    }
    
    func createStackView() {
        participantsStack = UIStackView()
        participantsStack.translatesAutoresizingMaskIntoConstraints = false
        participantsStack.axis = .vertical
        participantsStack.distribution = .fillEqually
        participantsStack.backgroundColor = .black
        participantsStack.layer.cornerRadius = 10
        view.addSubview(participantsStack)
    }
    
    func setupConstraints() {
        // Safe area
        let safeArea = view.safeAreaLayoutGuide
        
        // Bottom view
        let bottomView = leaveRoomButton.superview!
        
        NSLayoutConstraint.activate([
            // Bottom view
            bottomView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.15),
            bottomView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            
            // Leave Room Button
            leaveRoomButton.widthAnchor.constraint(equalTo: bottomView.widthAnchor, multiplier: 0.144928),
            leaveRoomButton.heightAnchor.constraint(equalTo: bottomView.heightAnchor, multiplier: 0.461538, constant: -2),
            leaveRoomButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -40),
            leaveRoomButton.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor, constant: -50),
            
            // Microphone Button
            microphoneInputButton.widthAnchor.constraint(equalTo: bottomView.widthAnchor, multiplier: 0.144928),
            microphoneInputButton.heightAnchor.constraint(equalTo: bottomView.heightAnchor, multiplier: 0.461538, constant: -2),
            microphoneInputButton.centerXAnchor.constraint(equalTo: bottomView.centerXAnchor),
            microphoneInputButton.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor, constant: -50),
            
            // Camera Button
            cameraInputButton.widthAnchor.constraint(equalTo: bottomView.widthAnchor, multiplier: 0.144928),
            cameraInputButton.heightAnchor.constraint(equalTo: bottomView.heightAnchor, multiplier: 0.461538, constant: -2),
            cameraInputButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 45),
            cameraInputButton.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor, constant: -50),
            
            // Participants Stack
            participantsStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
            participantsStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 23),
            participantsStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            participantsStack.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: -30)
        ])
    }
    
    @objc func didTapLeaveRoom() async {
        Task {
            do {
                try await callClient.leave()
            } catch {
                // Handle the error, for example by showing an alert to the user
                showAlert(message: "Failed to leave the room: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func didTapToggleMicrophone() {
        
        
        
//      self.callClient.inputs.microphone.isEnabled.toggle()
        updateControls()
    }
    
    @objc func didTapToggleCamera() {
//        callClient.inputs.camera.isEnabled.toggle()
        updateControls()
    }
    
    func updateParticipantView(participantId: ParticipantID, videoTrack: VideoTrack) {
        if let videoView = videoViews[participantId] {
            videoView.track = videoTrack
        } else {
            let videoView = VideoView()
            videoView.translatesAutoresizingMaskIntoConstraints = false
            videoView.track = videoTrack
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

    func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension DailyCallViewController: CallClientDelegate {
    
    func callClient(_ callClient: CallClient, inputsUpdated inputs: InputSettings) {

            print("Inputs Updated")

            // Handle UI updates
            updateControls()
        }
        
    private func callClient(_ client: CallClient, participantDidJoin participant: Participant) {
        print("Participant joined: \(participant)")
//        participant.media?.customVideo
        print("Participant \(participant.id) joined the call.")

        // Create a new view for this participant's video track.
        let videoView = VideoView()

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
    }
    
    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
        print("Participant \(participant.id) joined the call.")

        // Create a new view for this participant's video track.
        let videoView = VideoView()

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
    }
    
    // Handle a participant updating (e.g., their tracks changing)
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {

        print("Participant \(participant.id) updated.")

        // Determine whether the video track is for a screen or camera.
        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = cameraTrack ?? screenTrack

        if participant.info.isLocal {
            // Update the track for the local participant's video view.
            self.localVideoView.track = videoTrack
        } else {
            // Update the track for a remote participant's video view.
            self.videoViews[participant.id]?.track = videoTrack
        }
    }
    
    // Handle a participant leaving
    func callClient(_ callClient: CallClient, participantLeft participant: Participant, withReason reason: ParticipantLeftReason) {

        print("Participant \(participant.id) left the room.")

        // Remove remote participant's video view from the dictionary and stack view.
        if let videoView = self.videoViews.removeValue(forKey: participant.id) {
           self.participantsStack.removeArrangedSubview(videoView)
        }
    }
    
    func callClient(_ client: CallClient, participantDidLeave participant: Participant) {
        print("Participant left: \(participant)")
        removeParticipantView(participantId: participant.id)
    }
    
    func callClient(_ client: CallClient, participant: Participant, didUpdateVideoTrack videoTrack: VideoTrack) {
        print("Participant updated video track: \(participant)")
        updateParticipantView(participantId: participant.id, videoTrack: videoTrack)
    }
    
    func callClient(_ client: CallClient, participant: Participant, didUpdateAudioTrack audioTrack: AudioTrack) {
        print("Participant updated audio track: \(participant)")
        // Handle audio track updates if needed
    }
}

