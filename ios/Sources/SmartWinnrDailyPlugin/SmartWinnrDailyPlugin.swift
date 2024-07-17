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
        CAPPluginMethod(name: "joinCall", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = SmartWinnrDaily()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }

    @objc func joinCall(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else {
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
        
        
        
//        guard let primaryColorRGB = call.getString("primaryColorRGB") else {
//            call.reject("primaryColorRGB title is required")
//            return
//        }

//        guard let maxTime = call.getString("maxTime") else {
//            call.reject("Max time is required")
//            return
//        }
//
//        guard let currentTime = call.getString("currentTime") else {
//            call.reject("Current time is required")
//            return
//        }
        
        
        
        DispatchQueue.main.async {
//            primaryColorRGB: primaryColorRGB
            var customViewController = DailyCallViewController(urlString: urlString, token: tokenString, userName: userNameString, coachingTitle: coachingTitle, maxTime: maxTime, coachName: coachName )
           
            
            customViewController.onDismiss = {
                print("call successfull")
                let callState = customViewController.getCallStatus()
                var status = "terminated"
                if callState.rawValue == "left" {
                    status = "left"
                }
                print(callState)
                call.resolve([
                    "value": status
                ])
            }
            
            
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                rootViewController.present(customViewController, animated: true, completion: nil)
//                print("call successfull")
//                call.resolve()
            } else {
                call.reject("Failed to present CustomViewController")
            }
            
        }
                        
//                        let storyboard = UIStoryboard(name: "DailyCall", bundle: nil)
//                        guard let customViewController = storyboard.instantiateViewController(withIdentifier: "DailyCallViewController") as? DailyCallViewController else {
//                            call.reject("Failed to instantiate CustomViewController from storyboard")
//                            return
//                        }
//                        
//                        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
//                            rootViewController.present(customViewController, animated: true, completion: nil)
//                            call.resolve()
//                        } else {
//                            call.reject("Failed to present CustomViewController")
//                        }
                    
                    
//                    await implementation.joinCall(url: url) { result in
//                        switch result {
//                        case .success(let message):
//                            call.resolve([
//                                "message": message
//                            ])
//                        case .failure(let error):
//                            call.reject("Failed to join call: \(error.localizedDescription)")
//                        }
//                    }
                
    }
}
