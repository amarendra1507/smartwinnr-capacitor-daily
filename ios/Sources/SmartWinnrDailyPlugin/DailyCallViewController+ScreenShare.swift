//
//  DailyCallViewController+ScreenShare.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
//

import UIKit
import Daily
import ReplayKit
import AVKit

// MARK: - Screen Share

extension DailyCallViewController {

    @objc func screenShareTapped() {
        guard newScreenShareButton.isEnabled else { return }

        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.newScreenShareButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { [weak self] _ in
            UIView.animate(withDuration: 0.1) {
                self?.newScreenShareButton.transform = .identity
            }
        }

        if isScreenSharingActive {
            stopScreenSharing()
        } else {
            showScreenShareModal()
        }
    }

    func updateScreenShareButton() {
        DispatchQueue.main.async {
            if self.isScreenSharingActive {
                self.newScreenShareButton.setTitle("STOP SCREEN SHARE", for: .normal)
                self.newScreenShareButton.backgroundColor = UIColor.systemRed
            } else {
                self.newScreenShareButton.setTitle("SCREEN SHARE", for: .normal)
                self.newScreenShareButton.backgroundColor = UIColor.systemBlue
            }
        }
    }

    func stopScreenSharing() {
        newScreenShareButton.isEnabled = false

        callClient.updateInputs(
            .set(screenVideo: .set(isEnabled: .set(false))),
            completion: { [weak self] result in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.newScreenShareButton.isEnabled = true

                    switch result {
                    case .success(_):
                        self.isScreenSharingActive = false
                        self.updateScreenShareButton()

                        if #available(iOS 15.0, *) {
                            self.stopPictureInPicture()
                        }

                    case .failure(let error):
                        print("Failed to stop screen share: \(error.localizedDescription)")
                        self.showAlert(message: "Failed to stop screen share: \(error.localizedDescription)")
                    }
                }
            }
        )
    }

    func showScreenShareModal() {
        let modalViewController = ScreenShareModalViewController()
        modalViewController.delegate = self
        modalViewController.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = modalViewController.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
        }

        present(modalViewController, animated: true, completion: nil)
    }

}

// MARK: - ScreenShareModalDelegate

extension DailyCallViewController: ScreenShareModalDelegate {

    func screenShareModalDidSelectStart() {
        showBroadcastSystemPicker()
    }

    func screenShareModalDidCancel() {
        // No action needed
    }

    // MARK: - Broadcast System Picker

    func showBroadcastSystemPicker() {
        let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        broadcastPicker.preferredExtension = "com.quizprompt.app.ScreenBroadcast"
        broadcastPicker.showsMicrophoneButton = false

        broadcastPicker.alpha = 0.01
        view.addSubview(broadcastPicker)

        self.systemBroadcastPickerView = broadcastPicker

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.triggerBroadcastPickerButton(in: broadcastPicker)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                broadcastPicker.removeFromSuperview()
            }
        }
    }

    func dismissBroadcastPicker() {
        if let picker = systemBroadcastPickerView {
            DispatchQueue.main.async {
                picker.removeFromSuperview()
                self.systemBroadcastPickerView = nil
            }
        }
    }

    func triggerBroadcastPickerButton(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            } else {
                triggerBroadcastPickerButton(in: subview)
            }
        }
    }
}
