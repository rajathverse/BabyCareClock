import Foundation
import WatchConnectivity
import WatchKit

/// The Watch's copy of the care plan, kept in sync with the iPhone. Done and Snooze are applied
/// here straight away and sent to the iPhone, which stays the source of truth.
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()

    @Published private(set) var state: CareState

    private static let storageKey = "careState"

    private override init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey), let saved = try? CarePersistence.decode(data) {
            state = saved
        } else {
            state = CareState()
        }
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func complete(_ itemID: UUID) {
        var updated = state
        updated.complete(itemID, at: Date())
        apply(updated)
        WKInterfaceDevice.current().play(.success)
        send(WatchPayload.Action(kind: .done, itemID: itemID))
    }

    func snooze(_ itemID: UUID) {
        var updated = state
        updated.snooze(itemID, minutes: 15)
        apply(updated)
        WKInterfaceDevice.current().play(.click)
        send(WatchPayload.Action(kind: .snooze, itemID: itemID))
    }

    private func apply(_ newState: CareState) {
        state = newState
        if let data = try? CarePersistence.encode(newState) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Sends now if the iPhone is reachable, otherwise queues it for delivery later.
    private func send(_ action: WatchPayload.Action) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(action.message, replyHandler: nil) { _ in
                session.transferUserInfo(action.message)
            }
        } else {
            session.transferUserInfo(action.message)
        }
    }

    private func receive(_ context: [String: Any]) {
        guard let data = context[WatchPayload.stateKey] as? Data, let received = try? CarePersistence.decode(data) else { return }
        DispatchQueue.main.async { self.apply(received) }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
}
