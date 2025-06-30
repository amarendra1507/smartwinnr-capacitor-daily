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


class DailyCallViewController: UIViewController {
    @IBOutlet private weak var systemBroadcastPickerView: UIView!

    // Add this struct if you don't already have it
    struct DailyParticipant {
        let id: String
        let name: String
    }

    // Add these methods inside the class
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.leaveRoomButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.leaveRoomButton.alpha = 0.9
        }
    }

    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.leaveRoomButton.transform = .identity
            self.leaveRoomButton.alpha = 1.0
        }
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
                self.leaveRoomButton.transform = .identity
            }
        }

        // Disable button to prevent multiple taps
        self.leaveRoomButton.isEnabled = false
        
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
        }
    }
    
}

