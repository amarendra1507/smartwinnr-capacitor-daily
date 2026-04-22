import Foundation
import Capacitor
import Daily

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(SmartWinnrDailyPlugin)
public class SmartWinnrDailyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SmartWinnrDailyPlugin"
    public let jsName = "SmartWinnrDaily"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "joinCall", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endCall", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = SmartWinnrDaily()
    private var customViewController: DailyCallViewController?

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }

    @objc func endCall(_ call: CAPPluginCall) {
        print("endCall triggered")
        self.customViewController?.leave()
        call.resolve([
            "value": "left"
        ])
    }


    @objc func joinCall(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"), let _ = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }
        
        guard let tokenString = call.getString("token") else {
            call.reject("Token is required")
            return
        }

        guard let userNameString = call.getString("userName") else {
            call.reject("Username is required")
            return
        }

        guard let coachingTitle = call.getString("coachingTitle") else {
            call.reject("Coaching title is required")
            return
        }
        
        guard let maxTime = call.getInt("maximumTime")  else {
            call.reject("maximumTime title is required")
            return
        }
        
        guard let coachName = call.getString("coachName")  else {
            call.reject("coachName title is required")
            return
        }
        
        guard let testMode = call.getBool("testMode")  else {
            call.reject("testMode is required")
            return
        }

        let enableScreenShare = call.getBool("enableScreenShare") ?? false
        let audioModeOnly = call.getBool("audio_mode_only") ?? false
        let userProfileImageURL = call.getString("userProfileImageURL")
        let coachProfileImageURL = call.getString("coachProfileImageURL")
        // Caller-provided shape:
        //   is_sharable_resources_available: Bool
        //   sharable_resources: [{ id, url, display_name? }]
        // We activate document-share mode when the flag is true AND the first
        // sharable resource has a usable URL. The first resource drives the
        // initial PDF viewer; a selector lets the user switch if count > 1.
        let isSharableResourcesAvailable = call.getBool("is_sharable_resources_available") ?? false
        let sharableResourcesRaw = call.getArray("sharable_resources", JSObject.self) ?? []
        let sharableItems: [DailyCallViewController.SharableResourceItem] = sharableResourcesRaw.compactMap { entry in
            guard let url = entry["url"] as? String, !url.isEmpty else { return nil }
            let id = (entry["id"] as? String) ?? url
            return DailyCallViewController.SharableResourceItem(
                id: id,
                url: url,
                displayName: entry["display_name"] as? String
            )
        }
        let firstResource = sharableItems.first
        let documentUrl = firstResource?.url
        let documentTitle = firstResource?.displayName
        let isDocumentShareEnabled = isSharableResourcesAvailable && firstResource != nil

        print("=== SmartWinnrDailyPlugin joinCall ===")
        print("  url: \(urlString)")
        print("  token: \(tokenString.prefix(20))...")
        print("  userName: \(userNameString)")
        print("  coachName: \(coachName)")
        print("  coachingTitle: \(coachingTitle)")
        print("  maximumTime: \(maxTime)")
        print("  testMode: \(testMode)")
        print("  enableScreenShare: \(enableScreenShare)")
        print("  audio_mode_only: \(audioModeOnly)")
        print("  userProfileImageURL: \(userProfileImageURL ?? "nil")")
        print("  coachProfileImageURL: \(coachProfileImageURL ?? "nil")")
        print("======================================")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create and initialize the view controller
            let viewController = DailyCallViewController(
                urlString: urlString,
                token: tokenString,
                userName: userNameString,
                coachingTitle: coachingTitle,
                maxTime: maxTime,
                coachName: coachName,
                testMode: testMode,
                enableScreenShare: enableScreenShare,
                audioModeOnly: audioModeOnly,
                userProfileImageURL: userProfileImageURL,
                coachProfileImageURL: coachProfileImageURL
            )
            
            // Store the reference
            self.customViewController = viewController

            // Configure document share (opt-in; existing setup untouched when false)
            viewController.isDocumentShareEnabled = isDocumentShareEnabled
            viewController.sharableResourceItems = sharableItems
            viewController.currentResourceIndex = 0
            viewController.documentUrlString = documentUrl
            viewController.documentTitle = documentTitle

            viewController.onPdfPageChanged = { [weak self] pageNumber, totalPages in
                self?.notifyListeners("pdfPageChanged", data: [
                    "pageNumber": pageNumber,
                    "totalPages": totalPages
                ])
            }

            viewController.onPdfTrackingUpdate = { [weak self] data in
                self?.notifyListeners("pdfTrackingUpdate", data: data)
            }

            viewController.onPdfLoadError = { [weak self] error in
                self?.notifyListeners("pdfLoadError", data: [
                    "error": error,
                    "url": documentUrl ?? ""
                ])
            }

            viewController.onPagePresentationTracking = { [weak self] entries in
                self?.notifyListeners("pagePresentationTracking", data: [
                    "entries": entries
                ])
            }

            // Set up all callbacks
            viewController.onCallStateChange = { [weak self] state in
                self?.notifyListeners("callStateChanged", data: [
                    "state": state.rawValue
                ])
            }
            
            viewController.onNetworkQualityChange = { [weak self] quality in
                self?.notifyListeners("networkQualityChanged", data: [
                    "quality": quality
                ])
            }
            
            viewController.onParticipantJoined = { [weak self] participant in
                self?.notifyListeners("participantJoined", data: [
                    "participant": participant
                ])
                print("Participant Joined")
            }

            viewController.onRecordingStarted = { [weak self] recordingId, startTime in
                self?.notifyListeners("recordingStarted", data: [
                    "recordingId": recordingId,
                    "startTime": startTime
                ])
                print("Recording Started")
            }

            viewController.onRecordingStopped = { [weak self] recordingId, stopTime in
                self?.notifyListeners("recordingStopped", data: [
                    "recordingId": recordingId,
                    "stopTime": stopTime
                ])
                print("Recording Stopped")
            }

            viewController.onRecordingError = { [weak self] error in
                self?.notifyListeners("recordingError", data: [
                    "error": error
                ])
                print("Error Occured")
            }
            
            viewController.onDismiss = { [weak self] in
                guard let self = self,
                let vc = self.customViewController else { return }
            
                // Get call state directly without optional binding
                let callState = vc.getCallStatus()
                print("Call state", callState, callState.rawValue)
                var status = "terminated"
                
                if callState.rawValue == "left" {
                    status = "left"
                }

                self.notifyListeners("callEnded", data: [
                    "status": status
                ])

            }

            viewController.onParticipantCountChanged = { [weak self] participantCount in
                self?.notifyListeners("participantCountChanged", data: [
                    "participantCount": participantCount
                ])
            }
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootViewController = windowScene.windows.first?.rootViewController {
                viewController.modalPresentationStyle = .fullScreen // Set full screen presentation
                rootViewController.present(viewController, animated: true, completion: nil)
                call.resolve([
                    "value": "Plugin started successfully."
                ])
            } else {
                call.reject("Failed to present CustomViewController")
            }
        }
                        
                
    }
}
