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
    
//    App Black RGB 9, 30, 66, 1
//    App Background Grey 244, 245, 247, 0.08
    
    let callClient: CallClient = .init()
    // The local participant video view.
    private let localVideoView: VideoView = .init()
    
    private var participantIds: [String] = []
    private var remoteParticipantId : String = "";

   // A dictionary of remote participant video views.
   private var videoViews: [ParticipantID: VideoView] = [:]

    private let token: MeetingToken
    private let roomURLString: String
    private let userName: String
    private let coachingTitle: String
    private let coachName: String
    private let maxTime: TimeInterval
    private var currentTime: TimeInterval = 1
//    private var primaryColorRGB: String
    var timer:Timer?
    
//    primaryColorRGB: String
    
    init(urlString: String, token: String, userName: String, coachingTitle: String, maxTime: Int, coachName: String ) {
        self.roomURLString = urlString
        self.token = MeetingToken(stringValue: token)
        self.userName = userName
        self.coachingTitle = coachingTitle;
        self.maxTime = TimeInterval(maxTime);
        self.coachName = coachName;
//        self.primaryColorRGB = primaryColorRGB;
//        self.currentTime = TimeInterval(1);
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
    }
    
    func getCallStatus() -> CallState {
        return self.callClient.callState
    }
    
    func startTimer() {
//        print("Timer Started")
        let message = "\(self.coachName) will be joining us shortly."
        self.showAlert(message: message)
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    @objc func updateTime() {
        // Update current time
        currentTime += 1
//        print(currentTime)
        
        // Check if current time exceeds max time
        if currentTime > maxTime {
            timer?.invalidate()
            timer = nil
            // Optionally handle the case when the timer exceeds max time
        } else {
//            print(formatTime(currentTime))
//            "\(timeFormatted(totalTime)) / \(timeFormatted(maxTime))"
            timerLabel.text = "\(formatTime(currentTime)) / \(formatTime(maxTime))"
        }
    }
        
    func formatTime(_ time: TimeInterval) -> String {
        _ = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d",  minutes, seconds)
    }
    
    var onDismiss: (() -> Void)?

    // UI elements
    var leaveRoomButton: UIButton!
    var microphoneInputButton: UIButton!
    var cameraInputButton: UIButton!
    var participantsStack: UIStackView!
    var currentTimeLabel: UILabel!
//    var currentTime: TimeInterval!;
//    var maxTime: TimeInterval!
    var timerLabel: UILabel!
    var overlayView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        self.modalPresentationStyle = .fullScreen
        self.isModalInPresentation = true;
        // Setup CallClient delegate
        self.callClient.delegate = self
        
        
        // Create buttons
        createButtons()
        
        // Create stack view
        createStackView()
        
        updateControls()
        
        // Setup constraints
        setupConstraints()
        startTimer();
        
        // Create and configure the overlay view
        overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.layer.cornerRadius = 10
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(overlayView)

        // Create and configure the label
        let messageLabel = UILabel()
        messageLabel.text = "\(self.coachName) will be joining us shortly."
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

        
        guard let roomURL = URL(string: roomURLString) else {
//            print("Invalid room URL")
            return
        }
        
        self.callClient.join(url: roomURL, token: token) { result in
            switch result {
            case .success(_):
                // Handle successful join
//                print("Joined call with ID: ")
                self.callClient.set(username: self.userName) { result in
                    switch result {
                    case .success(_):
                        // Handle successful join
                        print("Joined call with ID: ")
//                        print(callJoinData)
                        
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
        leaveRoomButton.setTitle("END ROLE PLAY", for: .normal)
        leaveRoomButton.setTitleColor(.white, for: .normal)
        leaveRoomButton.translatesAutoresizingMaskIntoConstraints = false
        leaveRoomButton.backgroundColor = .systemRed
        leaveRoomButton.tintColor = .white
        leaveRoomButton.layer.cornerRadius = 25
        leaveRoomButton.addTarget(self, action: #selector(didTapLeaveRoom), for: .touchUpInside)
        
        microphoneInputButton = UIButton(type: .system)
        microphoneInputButton.translatesAutoresizingMaskIntoConstraints = false
        microphoneInputButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        microphoneInputButton.tintColor = .white
        microphoneInputButton.layer.cornerRadius = 10
        let micImage = UIImage(systemName: "mic.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium))
        microphoneInputButton.setImage(micImage, for: .normal)
        microphoneInputButton.addTarget(self, action: #selector(didTapToggleMicrophone), for: .touchUpInside)
        
        cameraInputButton = UIButton(type: .system)
        cameraInputButton.translatesAutoresizingMaskIntoConstraints = false
        cameraInputButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cameraInputButton.tintColor = .white
        cameraInputButton.layer.cornerRadius = 10
        let videoImage = UIImage(systemName: "video.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium))
        cameraInputButton.setImage(videoImage, for: .normal)
        cameraInputButton.addTarget(self, action: #selector(didTapToggleCamera), for: .touchUpInside)
                
        // Set up title label
        let titleLabel = UILabel()
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
                
        let bottomView = UIView()
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.backgroundColor = .systemBackground
        bottomView.layer.cornerRadius = 10
        view.addSubview(bottomView)
        
        timerLabel = UILabel()
        timerLabel.text = ""
        timerLabel.textAlignment = .center
        timerLabel.backgroundColor = .systemBackground
        timerLabel.textColor = UIColor.orange
        timerLabel.font = UIFont.boldSystemFont(ofSize: 24)
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.layer.cornerRadius = 10
        timerLabel.layer.masksToBounds = true
//        view.addSubview(timerLabel)
        
        let topView = UIView()
        topView.translatesAutoresizingMaskIntoConstraints = false
        topView.backgroundColor = UIColor(red: hRed, green: hGreen, blue: hBlue, alpha: hAlpha)
        topView.layer.cornerRadius = 10
        view.addSubview(topView)
        topView.addSubview(titleLabel)
        
        // Set up constraints for the top view
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topView.heightAnchor.constraint(equalToConstant: 50) // Adjust height as needed
        ])
        
        // Set up constraints for the titleLabel
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: topView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: topView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: topView.bottomAnchor)
        ])
        
        let timerView = UIView()
        timerView.translatesAutoresizingMaskIntoConstraints = false
        timerView.backgroundColor = UIColor(red: hRed, green: hGreen, blue: hBlue, alpha: hAlpha)
        timerView.layer.cornerRadius = 10
        view.addSubview(timerView)
        timerView.addSubview(timerLabel)
        
        // Set up constraints for the top view
        NSLayoutConstraint.activate([
            timerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 65),
            timerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            timerView.heightAnchor.constraint(equalToConstant: 50) // Adjust height as needed
        ])
        
        // Set up constraints for the titleLabel
        NSLayoutConstraint.activate([
            timerLabel.topAnchor.constraint(equalTo: timerView.topAnchor),
            timerLabel.leadingAnchor.constraint(equalTo: timerView.leadingAnchor),
            timerLabel.trailingAnchor.constraint(equalTo: timerView.trailingAnchor),
            timerLabel.bottomAnchor.constraint(equalTo: timerView.bottomAnchor)
        ])
        
        bottomView.addSubview(leaveRoomButton)
        self.localVideoView.addSubview(cameraInputButton)
        self.localVideoView.addSubview(microphoneInputButton)
        // bottomView.addSubview(cameraInputButton)
        // bottomView.addSubview(microphoneInputButton)
       
        // Constraints for bottomView and buttons will be added in setupConstraints()
    }
    
    func createStackView() {
        participantsStack = UIStackView()
        participantsStack.translatesAutoresizingMaskIntoConstraints = false
        participantsStack.axis = .vertical
        participantsStack.distribution = .fillEqually
        participantsStack.backgroundColor = .white
        participantsStack.layer.cornerRadius = 10
        participantsStack.spacing = 10
        view.addSubview(participantsStack)
    }
    
    func setupConstraints() {
        // Safe area
        let safeArea = view.safeAreaLayoutGuide
        
        // Bottom view
        let bottomView = leaveRoomButton.superview!
        let topView = leaveRoomButton.superview!
        let margin: CGFloat = 8.0 // Adjust the margin as needed
        
        NSLayoutConstraint.activate([
            // Top View
            topView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.15),
            topView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            topView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            
            // Bottom view
            bottomView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: 50),
            bottomView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            
            leaveRoomButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            leaveRoomButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            leaveRoomButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            leaveRoomButton.heightAnchor.constraint(equalToConstant: 50),
            
            microphoneInputButton.leadingAnchor.constraint(equalTo: self.localVideoView.leadingAnchor, constant: margin), // Place at the left
            microphoneInputButton.bottomAnchor.constraint(equalTo: self.localVideoView.bottomAnchor, constant: -margin), // Place at the bottom
            microphoneInputButton.widthAnchor.constraint(equalToConstant: 30), // Adjust the width as needed
            microphoneInputButton.heightAnchor.constraint(equalToConstant: 30), // Adjust the height as needed
            
            cameraInputButton.leadingAnchor.constraint(equalTo: microphoneInputButton.trailingAnchor, constant: margin), // Place next to the microphone button
            cameraInputButton.bottomAnchor.constraint(equalTo: self.localVideoView.bottomAnchor, constant: -margin), // Place at the bottom
            cameraInputButton.widthAnchor.constraint(equalToConstant: 30), // Adjust the width as needed
            cameraInputButton.heightAnchor.constraint(equalToConstant: 30), // Adjust the height as needed
            
            // Participants Stack
            participantsStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 120),
            participantsStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 23),
            participantsStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            participantsStack.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: 50)
            
        ])
        
    }
    
    @objc func didTapLeaveRoom()  {
        self.callClient.stopRecording() { result in
            switch result {
            case .success(_):
                // Handle successful recording stop
                let participants = self.callClient.participants;
                let localParticipant = participants.local;
//                print(localParticipant.id)
                self.removeParticipantView(participantId: localParticipant.id)
                self.callClient.leave() { result in
                    // Returns .left
                    _ = self.callClient.callState
                    self.timer?.invalidate()
                    self.timer = nil

                    self.leave();
                }
            case .failure(let error):
                // Handle join failure
                print("Failed to stop recording: \(error.localizedDescription)")
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
            videoView.layer.cornerRadius = 10 // Adjust the corner radius as needed
            videoView.layer.masksToBounds = true // Ensure the corners are clipped
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
    
    // Method to remove the overlay view
    func removeOverlayView() {
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayView.alpha = 0
        }) { _ in
            self.overlayView.removeFromSuperview()
        }
    }
}

extension DailyCallViewController: CallClientDelegate {
    
    func callClient(_ callClient: CallClient, inputsUpdated inputs: InputSettings) {
        updateControls()
    }
            
    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
//        print("Participant \(participant.id) joined the call. participantJoined")

        // Create a new view for this participant's video track.
        let videoView = VideoView()
        
        videoView.layer.cornerRadius = 10 // Adjust the corner radius as needed
        videoView.layer.masksToBounds = true // Ensure the corners are clipped
        
        let nameLabel = UILabel()
        nameLabel.text = participant.info.username ?? self.userName
        nameLabel.textAlignment = .center
//        nameLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        
        self.callClient.startRecording() { result in
            switch result {
            case .success(_):
                // Handle successful join
//                print("Recording Started")
                DispatchQueue.main.async {
                    self.removeOverlayView()
                }
//                self.startTimer()
            case .failure(let error):
                // Handle join failure
                print("Failed startRecording: \(error.localizedDescription)")
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
    }
    
    // Handle a participant updating (e.g., their tracks changing)
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {

//        print("Participant \(participant.id) updated. participantUpdated")

        // Determine whether the video track is for a screen or camera.
        let cameraTrack = participant.media?.camera.track
        let screenTrack = participant.media?.screenVideo.track
        let videoTrack = cameraTrack ?? screenTrack

        if participant.info.isLocal {
            // Update the track for the local participant's video view.
            self.localVideoView.track = videoTrack
            self.localVideoView.layer.cornerRadius = 10
            self.localVideoView.layer.masksToBounds = true
            let nameLabel = UILabel()
            nameLabel.text = self.userName
            nameLabel.textAlignment = .center
//            nameLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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

            
        } else {
            // Update the track for a remote participant's video view.
            self.videoViews[participant.id]?.track = videoTrack
        }
    }
    
}

