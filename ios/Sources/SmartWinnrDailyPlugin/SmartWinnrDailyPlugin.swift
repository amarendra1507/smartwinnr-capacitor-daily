import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(SmartWinnrDailyPlugin)
public class SmartWinnrDailyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SmartWinnrDailyPlugin"
    public let jsName = "SmartWinnrDaily"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = SmartWinnrDaily()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }
}
