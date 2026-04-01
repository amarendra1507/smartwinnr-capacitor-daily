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

    @available(iOS 15.0, *)
    func setupPictureInPicture() {
        guard checkPipSupport() else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("PiP: Audio session error: \(error.localizedDescription)")
        }

        ensureRemoteVideoVisible()

        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 320, height: 240)
        pipVideoCallViewControllerStorage = pipVC

        // Build profile image layout
        buildPipProfileContent(in: pipVC)

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

        pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
            [weak self] ctrl, _ in
            if ctrl.isPictureInPicturePossible, let self = self, self.isScreenSharingActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !ctrl.isPictureInPictureActive { ctrl.startPictureInPicture() }
                }
            }
        }
    }

    @available(iOS 15.0, *)
    func updatePipProfileOverlay() {
        guard let pipVC = pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController else { return }
        buildPipProfileContent(in: pipVC)
    }

    // MARK: - Start / Stop / Retry

    @available(iOS 15.0, *)
    func startPictureInPicture() {
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
            buildPipProfileContent(in: pipVC)
        }
        attemptPipStart()
    }

    @available(iOS 15.0, *)
    func attemptPipStart() {
        guard let controller = pipControllerStorage as? AVPictureInPictureController else { return }
        if controller.isPictureInPictureActive { pipStartRetryCount = 0; return }
        if controller.isPictureInPicturePossible {
            pipStartRetryCount = 0
            controller.startPictureInPicture()
        } else {
            pipStartRetryCount += 1
            guard pipStartRetryCount < pipMaxRetries else { pipStartRetryCount = 0; return }
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
        ensureRemoteVideoVisible()
        if let pipVC = pipVideoCallViewControllerStorage as? AVPictureInPictureVideoCallViewController {
            buildPipProfileContent(in: pipVC)
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        startVideoRenderingMonitor()
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP: Failed - \(error.localizedDescription)")
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {}

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        stopVideoRenderingMonitor()
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}
