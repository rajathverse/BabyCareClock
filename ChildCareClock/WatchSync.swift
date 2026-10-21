import Foundation
import WatchConnectivity

/// Keeps the Apple Watch app up to date and applies Done / Snooze taps made on the Watch.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends a trimmed copy of the state (recent log only) as the Watch's latest context.
    func send(_ state: CareState) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = try? CarePersistence.encode(WatchPayload.trimmed(state)) else { return }
        try? session.updateApplicationContext([WatchPayload.stateKey: data])
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.send(CareViewModel.shared.state) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    private func handle(_ message: [String: Any]) {
        guard let action = WatchPayload.Action(message: message) else { return }
        DispatchQueue.main.async {
            switch action.kind {
            case .done: CareViewModel.shared.complete(action.itemID, at: action.date)
            case .snooze: CareViewModel.shared.snooze(action.itemID)
            }
        }
    }
}
