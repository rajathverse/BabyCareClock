import ActivityKit
import Foundation

/// Live Activity showing a countdown to the next item on the Lock Screen and Dynamic Island.
struct CareActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var itemID: UUID
        var itemName: String
        var symbol: String
        var kind: CareKind
        var due: Date
        /// When the current interval started, so the ring can show progress.
        var intervalStart: Date
    }

    var babyName: String
}
