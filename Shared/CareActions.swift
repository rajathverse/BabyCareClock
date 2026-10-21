import Foundation
import WidgetKit

/// Changes made outside the app's screens (the widget, Siri, the Watch) go through here so the
/// saved file, reminders, widgets and the running app all stay in step.
enum CareActions {
    @discardableResult
    static func perform(_ change: (inout CareState) -> Void) -> CareState? {
        guard var state = CarePersistence.load() else { return nil }
        change(&state)
        CarePersistence.save(state)
        NotificationScheduler.reschedule(state: state)
        WidgetCenter.shared.reloadAllTimelines()
        CareSync.postChange()
        return state
    }
}

/// A cross-process "the saved file changed" signal, so the app reloads after a widget or Siri action.
enum CareSync {
    static let name = "com.rajathverse.childcareclock.changed" as CFString
    private static var handler: (() -> Void)?

    static func postChange() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name), nil, nil, true)
    }

    static func observe(_ onChange: @escaping () -> Void) {
        handler = onChange
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in DispatchQueue.main.async { CareSync.handler?() } },
            name,
            nil,
            .deliverImmediately
        )
    }
}
