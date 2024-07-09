import Foundation
import Daily

@objc public class SmartWinnrDaily: NSObject {

    var callClient: CallClient?
    @MainActor
    func joinCall(url: URL, completion: @escaping (Result<CallJoinData, CallClientError>) -> Void) {
            self.callClient = CallClient()
            self.callClient?.delegate = self
            self.callClient?.join(url: url) { result in
                switch result {
                case .success(let callJoinData):
                    completion(.success(callJoinData))
                case .failure(let callJoinError):
                   completion(.failure(callJoinError))
                }
            }
        }
    
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}

extension SmartWinnrDaily: CallClientDelegate {
    func callClient(_ client: CallClient, didUpdateState state: CallState) {
        // Handle call state updates
        print("Call state updated: \(state)")
    }

    func callClient(_ client: CallClient, didEncounterError error: Error) {
        // Handle errors
        print("Call encountered an error: \(error.localizedDescription)")
    }

    func callClient(_ client: CallClient, didJoinCallWithId callId: String) {
        // Handle successful call join
        print("Joined call with ID: \(callId)")
    }

    func callClient(_ client: CallClient, didLeaveCallWithId callId: String) {
        // Handle call leave
        print("Left call with ID: \(callId)")
    }
}
