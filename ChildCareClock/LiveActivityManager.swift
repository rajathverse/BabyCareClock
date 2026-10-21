import ActivityKit
import Foundation

/// Earlier builds showed a Lock Screen / Dynamic Island countdown. It has been replaced by the
/// due-time notification, so this only ends any countdown still running from an older build.
@MainActor
enum LiveActivityManager {
    static func endAll() {
        for activity in Activity<CareActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
