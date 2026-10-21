import Foundation
import UserNotifications

/// Local notifications: one at each item's due time, repeat reminders
/// for medicines not yet marked done, plus an optional early heads-up. Everything is rescheduled after each change, which stays far below the
/// system's 64 pending-notification limit.
enum NotificationScheduler {
    static let categoryID = "CARE_DUE"
    static let doneAction = "CARE_DONE"
    static let snoozeAction = "CARE_SNOOZE"
    static let itemKey = "itemID"
    static let snoozeMinutes = 15
    /// Medicines not marked done get this many repeat reminders, this many minutes apart.
    static let nudgeCount = 2
    static let nudgeMinutes = 10

    static func registerCategories() {
        let done = UNNotificationAction(identifier: doneAction, title: "Done", options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Snooze \(snoozeMinutes) min", options: [], icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
        let category = UNNotificationCategory(identifier: categoryID, actions: [done, snooze], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(state: CareState, now: Date = Date()) {
        reschedule(state: state, earlyMinutes: AppPreferences.defaults.integer(forKey: AppPreferences.earlyReminderMinutes), now: now)
    }

    static func reschedule(state: CareState, earlyMinutes: Int, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let babyName = state.baby?.name ?? ""
        scheduleVaccines(state: state, now: now)

        for scheduled in CareEngine.schedule(for: state, now: now) where scheduled.item.sendsReminders {
            let item = scheduled.item
            if scheduled.due > now {
                center.add(request(
                    id: dueID(item.id),
                    item: item,
                    title: "\(item.name) is due now",
                    body: dueBody(item, babyName: babyName),
                    at: scheduled.due
                ))
            }
            if item.kind == .medicine, AppPreferences.defaults.bool(forKey: AppPreferences.medicineNudgesEnabled) {
                for number in 1...nudgeCount {
                    let nudge = scheduled.due.addingTimeInterval(TimeInterval(number * nudgeMinutes * 60))
                    guard nudge > now else { continue }
                    center.add(request(
                        id: nudgeID(item.id, number),
                        item: item,
                        title: "\(item.name) is still due",
                        body: "It was due at \(scheduled.due.formatted(date: .omitted, time: .shortened)). Tap Done once it's given.",
                        at: nudge
                    ))
                }
            }
            if earlyMinutes > 0 {
                let early = scheduled.due.addingTimeInterval(TimeInterval(-earlyMinutes * 60))
                if early > now {
                    center.add(request(
                        id: earlyID(item.id),
                        item: item,
                        title: "\(item.name) in \(earlyMinutes) min",
                        body: "Coming up at \(scheduled.due.formatted(date: .omitted, time: .shortened)).",
                        at: early
                    ))
                }
            }
        }
    }

    /// Reminders for the next two vaccination visits: three days before and on the morning of the visit.
    private static func scheduleVaccines(state: CareState, now: Date) {
        guard AppPreferences.defaults.bool(forKey: AppPreferences.vaccineRemindersEnabled) else { return }
        let calendar = Calendar.current
        let babyName = state.baby?.name ?? "Your baby"
        let upcoming = VaccineEngine.visits(for: state.vaccines).filter { !$0.isComplete }.prefix(2)
        for visit in upcoming {
            let count = CareEngine.plural(visit.remaining.count, "vaccine")
            let day = visit.dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
            let reminders: [(String, Int, String)] = [
                ("vaccine-early-\(visit.id)", -3, "\(babyName)'s \(visit.title) vaccines are due on \(day). Time to book the visit."),
                ("vaccine-day-\(visit.id)", 0, "\(babyName)'s \(visit.title) vaccines are due today (\(count))."),
            ]
            for (id, offset, body) in reminders {
                guard let day = calendar.date(byAdding: .day, value: offset, to: visit.dueDate),
                      let when = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), when > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Vaccination reminder"
                content.body = body
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            }
        }
    }

    /// Clears banners already shown for an item once it has been handled.
    static func clearDelivered(for itemID: UUID) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [dueID(itemID), earlyID(itemID)] + (1...nudgeCount).map { nudgeID(itemID, $0) })
    }

    static func clearAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private static func dueBody(_ item: CareItem, babyName: String) -> String {
        var parts: [String] = []
        parts.append(babyName.isEmpty ? "Time for \(item.name.lowercased())." : "Time for \(babyName)'s \(item.name.lowercased()).")
        if !item.dosage.isEmpty { parts.append(item.dosage) }
        return parts.joined(separator: " · ")
    }

    private static func request(id: String, item: CareItem, title: String, body: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.threadIdentifier = item.id.uuidString
        content.userInfo = [itemKey: item.id.uuidString]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func dueID(_ id: UUID) -> String { "due-\(id.uuidString)" }
    private static func earlyID(_ id: UUID) -> String { "early-\(id.uuidString)" }
    private static func nudgeID(_ id: UUID, _ number: Int) -> String { "nudge-\(number)-\(id.uuidString)" }
}
