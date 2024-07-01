import Foundation

@objc public class SmartWinnrDaily: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
