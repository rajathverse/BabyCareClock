import Foundation

/// What the iPhone and Watch send each other.
enum WatchPayload {
    static let stateKey = "state"

    /// The Watch only needs each item's latest log and the last day of history.
    static func trimmed(_ state: CareState, now: Date = Date()) -> CareState {
        var trimmed = state
        let cutoff = now.addingTimeInterval(-86_400)
        let latest = Set(state.items.compactMap { CareEngine.latestEvent(for: $0.id, in: state)?.id })
        trimmed.events = state.events.filter { $0.date >= cutoff || latest.contains($0.id) }
        trimmed.vaccines = []
        return trimmed
    }

    struct Action {
        enum Kind: String {
            case done
            case snooze
        }

        let kind: Kind
        let itemID: UUID
        let date: Date

        init(kind: Kind, itemID: UUID, date: Date = Date()) {
            self.kind = kind
            self.itemID = itemID
            self.date = date
        }

        init?(message: [String: Any]) {
            guard let raw = message["action"] as? String, let kind = Kind(rawValue: raw),
                  let idString = message["itemID"] as? String, let id = UUID(uuidString: idString) else { return nil }
            self.kind = kind
            itemID = id
            date = (message["date"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        }

        var message: [String: Any] {
            ["action": kind.rawValue, "itemID": itemID.uuidString, "date": date.timeIntervalSince1970]
        }
    }
}
