import Foundation

enum CareStatus: Equatable {
    case upcoming
    case dueSoon
    case overdue
}

/// An item paired with the time it is next due.
struct ScheduledItem: Identifiable, Equatable {
    let item: CareItem
    let due: Date

    var id: UUID { item.id }
}

struct CareTimelineEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case done
        case skipped
        case overdue
        case planned
    }

    let id: String
    let date: Date
    let kind: Kind
    let item: CareItem
    let note: String
    /// Set for logged entries so they can be edited or deleted.
    let eventID: UUID?
}

/// An as-needed item with when it was last given and when another dose is allowed.
struct AsNeededItem: Identifiable, Equatable {
    let item: CareItem
    let lastGiven: Date?
    /// Nil when it can be given now.
    let okAfter: Date?

    var id: UUID { item.id }
}

enum CareValidationError: LocalizedError, Equatable {
    case missingName
    case duplicateName(String)
    case intervalOutOfRange
    case missingTimes

    var errorDescription: String? {
        switch self {
        case .missingName:
            return String(appLocalized: "Please enter a name.")
        case .duplicateName(let name):
            return String(appLocalized: "\"\(name)\" is already in your care plan. Edit the existing one instead.")
        case .intervalOutOfRange:
            return String(appLocalized: "Choose a time between 30 minutes and 7 days.")
        case .missingTimes:
            return String(appLocalized: "Add at least one time of day.")
        }
    }
}

/// Scheduling rules. Due times are derived from the log rather than stored, so editing or deleting
/// an entry always recalculates the schedule correctly.
enum CareEngine {
    static let minimumIntervalMinutes = 30
    static let maximumIntervalMinutes = 7 * 24 * 60
    static let maximumTimesPerDay = 8
    /// How many future slots a single item may add to today's timeline.
    static let maxPlannedSlotsPerItem = 12

    static func latestEvent(for itemID: UUID, in state: CareState) -> CareEvent? {
        state.events.filter { $0.itemID == itemID }.max { $0.date < $1.date }
    }

    // MARK: Due times

    /// When a scheduled item is next due. For as-needed items this is when another dose is allowed.
    static func nextDue(for item: CareItem, in state: CareState, calendar: Calendar = .current) -> Date {
        let latest = latestEvent(for: item.id, in: state)
        let base: Date
        switch item.schedule {
        case .interval:
            base = latest.map { $0.date.addingTimeInterval(item.interval) } ?? item.firstDue
        case .times(let times):
            if let latest {
                // A dose logged a little early or late covers the slot it was meant for.
                base = firstSlot(after: latest.date.addingTimeInterval(grace(for: times)), times: times, inclusive: false, calendar: calendar)
            } else {
                base = firstSlot(after: item.firstDue, times: times, inclusive: true, calendar: calendar)
            }
        case .asNeeded:
            return latest.map { $0.date.addingTimeInterval(item.interval) } ?? .distantPast
        }
        if let snoozed = item.snoozedUntil, snoozed > base { return snoozed }
        return base
    }

    /// The slot after `due`, assuming that one is done on time.
    static func followingSlot(after due: Date, for item: CareItem, calendar: Calendar = .current) -> Date {
        switch item.schedule {
        case .interval, .asNeeded:
            return due.addingTimeInterval(item.interval)
        case .times(let times):
            return firstSlot(after: due.addingTimeInterval(grace(for: times)), times: times, inclusive: false, calendar: calendar)
        }
    }

    /// Start of the current cycle, used for countdown rings.
    static func cycleStart(for item: CareItem, due: Date, calendar: Calendar = .current) -> Date {
        switch item.schedule {
        case .interval, .asNeeded:
            return due.addingTimeInterval(-item.interval)
        case .times(let times):
            let previous = slots(times: times, from: due.addingTimeInterval(-2 * 86_400), to: due, calendar: calendar).last { $0 < due }
            return previous ?? due.addingTimeInterval(-86_400)
        }
    }

    /// Fraction of the cycle still to go, from 1 (just done) to 0 (due now).
    static func remainingFraction(for item: CareItem, due: Date, now: Date, calendar: Calendar = .current) -> Double {
        let length = due.timeIntervalSince(cycleStart(for: item, due: due, calendar: calendar))
        guard length > 0 else { return 0 }
        return min(1, max(0, due.timeIntervalSince(now) / length))
    }

    static func status(due: Date, now: Date, warningMinutes: Int) -> CareStatus {
        let remaining = due.timeIntervalSince(now)
        if remaining <= 0 { return .overdue }
        if remaining <= TimeInterval(warningMinutes * 60) { return .dueSoon }
        return .upcoming
    }

    /// A course has finished once nothing more is due before its end (or, for as-needed items, once it has ended).
    static func isFinished(_ item: CareItem, in state: CareState, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let end = item.endDate else { return false }
        if item.schedule.isAsNeeded { return now >= end }
        return nextDue(for: item, in: state, calendar: calendar) >= end
    }

    /// Scheduled (not as-needed, not finished) items ordered by when they are next due, most urgent first.
    static func schedule(for state: CareState, now: Date = Date(), calendar: Calendar = .current) -> [ScheduledItem] {
        state.items
            .filter { !$0.schedule.isAsNeeded && !isFinished($0, in: state, now: now, calendar: calendar) }
            .map { ScheduledItem(item: $0, due: nextDue(for: $0, in: state, calendar: calendar)) }
            .sorted { $0.due == $1.due ? $0.item.name < $1.item.name : $0.due < $1.due }
    }

    static func asNeeded(for state: CareState, now: Date = Date()) -> [AsNeededItem] {
        state.items
            .filter { $0.schedule.isAsNeeded && !isFinished($0, in: state, now: now) }
            .sorted { $0.name < $1.name }
            .map { item in
                let last = latestEvent(for: item.id, in: state)?.date
                let allowed = last.map { $0.addingTimeInterval(item.interval) }
                return AsNeededItem(item: item, lastGiven: last, okAfter: allowed.flatMap { $0 > now ? $0 : nil })
            }
    }

    static func finished(for state: CareState, now: Date = Date(), calendar: Calendar = .current) -> [CareItem] {
        state.items.filter { isFinished($0, in: state, now: now, calendar: calendar) }.sorted { $0.name < $1.name }
    }

    // MARK: Clock times

    /// Allowance for logging a fixed-time dose early or late: an hour, or less when slots are close together.
    static func grace(for times: [Int]) -> TimeInterval {
        let sorted = Array(Set(times)).sorted()
        guard sorted.count > 1 else { return 3600 }
        var gaps = zip(sorted.dropFirst(), sorted).map { $0 - $1 }
        gaps.append(1440 - sorted.last! + sorted.first!)
        return min(3600, TimeInterval(gaps.min()! * 60) / 2)
    }

    static func slots(times: [Int], from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let sorted = Array(Set(times)).sorted()
        guard !sorted.isEmpty else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day <= end {
            for minutes in sorted {
                if let slot = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day), slot >= start, slot <= end {
                    result.append(slot)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    static func firstSlot(after date: Date, times: [Int], inclusive: Bool, calendar: Calendar) -> Date {
        let candidates = slots(times: times, from: date, to: date.addingTimeInterval(3 * 86_400), calendar: calendar)
        return candidates.first { inclusive ? $0 >= date : $0 > date } ?? date.addingTimeInterval(86_400)
    }

    // MARK: Validation

    static func validate(_ item: CareItem, excluding id: UUID?, in state: CareState) throws {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CareValidationError.missingName }
        switch item.schedule {
        case .interval, .asNeeded:
            guard (minimumIntervalMinutes...maximumIntervalMinutes).contains(item.intervalMinutes) else {
                throw CareValidationError.intervalOutOfRange
            }
        case .times(let times):
            guard !times.isEmpty, times.allSatisfy({ (0..<1440).contains($0) }) else { throw CareValidationError.missingTimes }
        }
        if state.items.contains(where: { $0.id != id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw CareValidationError.duplicateName(trimmed)
        }
    }

    // MARK: Timeline

    /// Logged entries for the day, plus (for today) what is overdue and still planned.
    static func timeline(for day: Date, in state: CareState, now: Date, calendar: Calendar = .current) -> [CareTimelineEntry] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        var entries: [CareTimelineEntry] = []

        for event in state.events where event.date >= start && event.date < end {
            guard let item = state.item(event.itemID) else { continue }
            entries.append(CareTimelineEntry(
                id: event.id.uuidString,
                date: event.date,
                kind: event.kind == .done ? .done : .skipped,
                item: item,
                note: event.note,
                eventID: event.id
            ))
        }

        if calendar.isDate(day, inSameDayAs: now) {
            for scheduled in schedule(for: state, now: now, calendar: calendar) {
                let item = scheduled.item
                if scheduled.due <= now {
                    entries.append(CareTimelineEntry(id: "overdue-\(item.id)", date: scheduled.due, kind: .overdue, item: item, note: "", eventID: nil))
                    continue
                }
                var slot = scheduled.due
                var count = 0
                while slot < end && count < maxPlannedSlotsPerItem && slot < (item.endDate ?? .distantFuture) {
                    entries.append(CareTimelineEntry(id: "planned-\(item.id)-\(Int(slot.timeIntervalSince1970))", date: slot, kind: .planned, item: item, note: "", eventID: nil))
                    slot = followingSlot(after: slot, for: item, calendar: calendar)
                    count += 1
                }
            }
        }

        return entries.sorted { $0.date == $1.date ? $0.item.name < $1.item.name : $0.date < $1.date }
    }

    /// "6 weeks old", "4 months old", "1 year 2 months old".
    static func ageDescription(birthDate: Date, now: Date, calendar: Calendar = .current) -> String {
        let birth = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: now)
        guard birth <= today else { return String(appLocalized: "Arriving soon") }
        let days = calendar.dateComponents([.day], from: birth, to: today).day ?? 0
        if days == 0 { return String(appLocalized: "Born today") }
        let age: String
        if days < 14 {
            age = CareFormat.days(days)
        } else if days < 91 {
            age = CareFormat.weeks(days / 7)
        } else {
            let parts = calendar.dateComponents([.year, .month], from: birth, to: today)
            let years = parts.year ?? 0
            let months = parts.month ?? 0
            if years == 0 {
                age = CareFormat.months(months)
            } else if months == 0 {
                age = CareFormat.years(years)
            } else {
                age = "\(CareFormat.years(years)) \(CareFormat.months(months))"
            }
        }
        return String(appLocalized: "\(age) old", comment: "Baby's age, e.g. 6 weeks old")
    }
}

// MARK: - Changes

extension CareState {
    mutating func addItem(_ item: CareItem) throws {
        try CareEngine.validate(item, excluding: nil, in: self)
        items.append(normalized(item))
    }

    mutating func updateItem(_ item: CareItem) throws {
        try CareEngine.validate(item, excluding: item.id, in: self)
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = normalized(item)
    }

    private func normalized(_ item: CareItem) -> CareItem {
        var item = item
        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .times(let times) = item.schedule { item.schedule = .times(Array(Set(times)).sorted()) }
        return item
    }

    /// Removes the item and everything logged for it.
    mutating func deleteItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        events.removeAll { $0.itemID == id }
    }

    /// Logs the item as done. A time in the future is treated as now.
    @discardableResult
    mutating func complete(_ itemID: UUID, at date: Date, note: String = "", now: Date = Date()) -> CareEvent? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        let when = min(date, now)
        // A skip recorded for a slot after this dose no longer applies.
        events.removeAll { $0.itemID == itemID && $0.kind == .skipped && $0.date > when }
        let event = CareEvent(itemID: itemID, date: when, kind: .done, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        events.append(event)
        items[index].snoozedUntil = nil
        return event
    }

    /// Skips the current dose and keeps the rhythm: the next due time is the first slot after now.
    @discardableResult
    mutating func skip(_ itemID: UUID, now: Date = Date(), calendar: Calendar = .current) -> CareEvent? {
        guard let index = items.firstIndex(where: { $0.id == itemID }), !items[index].schedule.isAsNeeded else { return nil }
        var item = items[index]
        item.snoozedUntil = nil
        items[index] = item
        var slot = CareEngine.nextDue(for: item, in: self, calendar: calendar)
        while CareEngine.followingSlot(after: slot, for: item, calendar: calendar) <= now {
            slot = CareEngine.followingSlot(after: slot, for: item, calendar: calendar)
        }
        let event = CareEvent(itemID: itemID, date: slot, kind: .skipped)
        events.append(event)
        return event
    }

    /// Pushes the due time out by `minutes`, counted from now if it is already due.
    mutating func snooze(_ itemID: UUID, minutes: Int, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), !items[index].schedule.isAsNeeded else { return }
        let due = CareEngine.nextDue(for: items[index], in: self)
        items[index].snoozedUntil = max(due, now).addingTimeInterval(TimeInterval(minutes * 60))
    }

    mutating func deleteEvent(_ id: UUID) {
        events.removeAll { $0.id == id }
    }

    mutating func updateEvent(_ id: UUID, date: Date, note: String, now: Date = Date()) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].date = events[index].kind == .done ? min(date, now) : date
        events[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Formatting

enum CareFormat {
    /// "Every 3 hours", "Every 30 min", "Every 1h 30m", "Once a day", "Every 2 days".
    static func interval(_ minutes: Int) -> String {
        if minutes == 1440 { return String(appLocalized: "Once a day") }
        if minutes % 1440 == 0 { return String(appLocalized: "Every \(minutes / 1440) days") }
        if minutes < 60 { return String(appLocalized: "Every \(minutes) min") }
        if minutes % 60 == 0 { return minutes == 60 ? String(appLocalized: "Every hour") : String(appLocalized: "Every \(minutes / 60) hours") }
        return String(appLocalized: "Every \(minutes / 60)h \(minutes % 60)m")
    }

    /// "9:00 AM" for minutes after midnight, in the user's locale.
    static func timeOfDay(_ minutes: Int, calendar: Calendar = .current) -> String {
        let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return date.shortTime
    }

    /// One line describing how an item repeats, e.g. "Every 3 hours", "Daily at 9:00 AM", "As needed · 6h apart".
    static func schedule(_ item: CareItem) -> String {
        var text: String
        switch item.schedule {
        case .interval:
            text = interval(item.intervalMinutes)
        case .times(let times):
            let sorted = times.sorted()
            text = sorted.count <= 2
                ? String(appLocalized: "Daily at \(sorted.map { timeOfDay($0) }.joined(separator: " & "))")
                : String(appLocalized: "\(sorted.count)× a day")
        case .asNeeded:
            text = String(appLocalized: "As needed · \(duration(item.interval)) apart")
        }
        if let end = item.endDate {
            let lastDay = end.addingTimeInterval(-1)
            text += " · " + String(appLocalized: "until \(lastDay.formatted(.dateTime.locale(AppLanguage.locale).day().month(.abbreviated)))")
        }
        return text
    }

    /// Short duration for countdowns: "1h 10m", "42 min", "2d 3h", "<1 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((abs(seconds) / 60).rounded(.up))
        if abs(seconds) < 60 { return String(appLocalized: "<1 min") }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? String(appLocalized: "\(days)d \(hours)h") : String(appLocalized: "\(days)d") }
        if hours > 0 { return minutes > 0 ? String(appLocalized: "\(hours)h \(minutes)m") : String(appLocalized: "\(hours)h") }
        return String(appLocalized: "\(minutes) min")
    }

    /// "in 1h 10m", "now", "12 min late".
    static func relative(due: Date, now: Date) -> String {
        let remaining = due.timeIntervalSince(now)
        if abs(remaining) < 60 { return String(appLocalized: "due now") }
        return remaining > 0 ? String(appLocalized: "in \(duration(remaining))") : String(appLocalized: "\(duration(remaining)) late")
    }

    // Counts with the right singular or plural, e.g. "1 day", "3 days".
    static func days(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 day") : String(appLocalized: "\(count) days") }
    static func weeks(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 week") : String(appLocalized: "\(count) weeks") }
    static func months(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 month") : String(appLocalized: "\(count) months") }
    static func years(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 year") : String(appLocalized: "\(count) years") }
    static func vaccines(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 vaccine") : String(appLocalized: "\(count) vaccines") }
    static func items(_ count: Int) -> String { count == 1 ? String(appLocalized: "1 item") : String(appLocalized: "\(count) items") }
}
