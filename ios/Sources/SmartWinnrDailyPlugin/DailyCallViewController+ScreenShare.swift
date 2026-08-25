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
        // Centered light popup over a dimmed backdrop (the VC draws its own dim +
        // card), matching the document-share prompt — not the old page sheet.
        modalViewController.modalPresentationStyle = .overFullScreen
        modalViewController.modalTransitionStyle = .crossDissolve

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
        // Avoid stacking multiple hidden pickers across retries.
        if let existing = systemBroadcastPickerView {
            existing.removeFromSuperview()
            systemBroadcastPickerView = nil
        }

        let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        broadcastPicker.preferredExtension = "com.quizprompt.app.ScreenBroadcast"
        broadcastPicker.showsMicrophoneButton = false

        broadcastPicker.alpha = 0.01
        view.addSubview(broadcastPicker)
        self.systemBroadcastPickerView = broadcastPicker

        // The picker's internal UIButton isn't guaranteed to exist immediately on
        // first use, so force a layout pass and RETRY the tap until it's ready.
        // Previously we tapped once after 0.1s and removed the picker after 0.5s,
        // so the very first attempt usually did nothing (button not built yet) —
        // hence "works only on the second try". We also no longer remove the
        // picker on a timer: it's removed when the broadcast actually starts
        // (`dismissBroadcastPicker`) or by the retry watchdog.
        view.layoutIfNeeded()
        tapBroadcastPickerButton(broadcastPicker, attempt: 0)
    }

    /// Repeatedly attempts to tap the broadcast picker's internal button until it
    /// exists (or we hit the attempt cap / the broadcast starts / the picker is
    /// torn down). Fixes the "first tap does nothing" race on first use.
    private func tapBroadcastPickerButton(_ picker: RPSystemBroadcastPickerView, attempt: Int) {
        guard picker.superview != nil, !isScreenSharingActive else { return }
        if triggerBroadcastPickerButton(in: picker) { return } // found & tapped
        guard attempt < 8 else { return } // ~1.2s of retries max
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.tapBroadcastPickerButton(picker, attempt: attempt + 1)
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

    /// Recursively finds and taps the picker's internal button.
    /// Returns true once a button was found and tapped.
    @discardableResult
    func triggerBroadcastPickerButton(in view: UIView) -> Bool {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return true
            } else if triggerBroadcastPickerButton(in: subview) {
                return true
            }
        }
        return false
    }
}
