import Foundation

enum CareKind: String, Codable, CaseIterable, Identifiable {
    case medicine
    case care

    var id: String { rawValue }
    var title: String { self == .medicine ? String(appLocalized: "Medicine") : String(appLocalized: "Care") }
    var sectionTitle: String { self == .medicine ? String(appLocalized: "Medicines & supplements") : String(appLocalized: "Care activities") }
    var defaultSymbol: String { self == .medicine ? "pills.fill" : "heart.fill" }
}

/// How an item repeats.
enum CareSchedule: Equatable {
    /// Every `intervalMinutes`, counted from the last time it was done.
    case interval
    /// Every day at fixed clock times, stored as minutes after midnight.
    case times([Int])
    /// Only when needed (e.g. fever medicine). No reminders; `intervalMinutes` is the minimum gap between doses.
    case asNeeded

    var isAsNeeded: Bool { self == .asNeeded }
}

struct CareItem: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: CareKind
    var name: String
    var symbol: String
    var intervalMinutes: Int
    var schedule: CareSchedule
    var dosage: String
    var notes: String
    var remindersOn: Bool
    /// When the item is due if nothing has been logged for it yet.
    var firstDue: Date
    /// A snooze pushes the due time out until this date, unless a later log replaces it.
    var snoozedUntil: Date?
    /// End of a course (e.g. antibiotics for 5 days). Nothing is due at or after this moment.
    var endDate: Date?
    var createdAt: Date

    init(id: UUID = UUID(), kind: CareKind, name: String, symbol: String, intervalMinutes: Int, schedule: CareSchedule = .interval, dosage: String = "", notes: String = "", remindersOn: Bool = true, firstDue: Date, snoozedUntil: Date? = nil, endDate: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.name = name
        self.symbol = symbol
        self.intervalMinutes = intervalMinutes
        self.schedule = schedule
        self.dosage = dosage
        self.notes = notes
        self.remindersOn = remindersOn
        self.firstDue = firstDue
        self.snoozedUntil = snoozedUntil
        self.endDate = endDate
        self.createdAt = createdAt
    }

    var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }

    /// As-needed items never send reminders.
    var sendsReminders: Bool { remindersOn && !schedule.isAsNeeded }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, symbol, intervalMinutes, scheduleKind, times, dosage, notes, remindersOn, firstDue, snoozedUntil, endDate, createdAt
    }

    // Optional fields fall back to defaults so files written by older builds still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decodeIfPresent(CareKind.self, forKey: .kind) ?? .care
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? kind.defaultSymbol
        intervalMinutes = try c.decode(Int.self, forKey: .intervalMinutes)
        switch try c.decodeIfPresent(String.self, forKey: .scheduleKind) {
        case "times": schedule = .times(try c.decodeIfPresent([Int].self, forKey: .times) ?? [])
        case "asNeeded": schedule = .asNeeded
        default: schedule = .interval
        }
        dosage = try c.decodeIfPresent(String.self, forKey: .dosage) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        remindersOn = try c.decodeIfPresent(Bool.self, forKey: .remindersOn) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        firstDue = try c.decodeIfPresent(Date.self, forKey: .firstDue) ?? createdAt
        snoozedUntil = try c.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(name, forKey: .name)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(intervalMinutes, forKey: .intervalMinutes)
        switch schedule {
        case .interval:
            try c.encode("interval", forKey: .scheduleKind)
        case .times(let times):
            try c.encode("times", forKey: .scheduleKind)
            try c.encode(times, forKey: .times)
        case .asNeeded:
            try c.encode("asNeeded", forKey: .scheduleKind)
        }
        try c.encode(dosage, forKey: .dosage)
        try c.encode(notes, forKey: .notes)
        try c.encode(remindersOn, forKey: .remindersOn)
        try c.encode(firstDue, forKey: .firstDue)
        try c.encodeIfPresent(snoozedUntil, forKey: .snoozedUntil)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

enum CareEventKind: String, Codable {
    case done
    case skipped
}

struct CareEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var itemID: UUID
    var date: Date
    var kind: CareEventKind
    var note: String

    init(id: UUID = UUID(), itemID: UUID, date: Date, kind: CareEventKind = .done, note: String = "") {
        self.id = id
        self.itemID = itemID
        self.date = date
        self.kind = kind
        self.note = note
    }

    private enum CodingKeys: String, CodingKey { case id, itemID, date, kind, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        itemID = try c.decode(UUID.self, forKey: .itemID)
        date = try c.decode(Date.self, forKey: .date)
        kind = try c.decodeIfPresent(CareEventKind.self, forKey: .kind) ?? .done
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct BabyProfile: Codable, Equatable {
    /// Quick choices for who is using the app; anything else can be typed. Saved in English and shown translated.
    static let roleChoices = ["Mom", "Dad", "Grandma", "Grandpa", "Nanny"]

    /// A quick-choice role in the app's language; anything typed in is shown as it is.
    static func displayRole(_ role: String) -> String {
        switch role {
        case "Mom": return String(appLocalized: "Mom")
        case "Dad": return String(appLocalized: "Dad")
        case "Grandma": return String(appLocalized: "Grandma")
        case "Grandpa": return String(appLocalized: "Grandpa")
        case "Nanny": return String(appLocalized: "Nanny")
        default: return role
        }
    }

    var name: String
    var birthDate: Date?
    /// Who is using the app, e.g. "Mom" or "Dad". Empty when not chosen.
    var caregiverRole: String

    init(name: String, birthDate: Date? = nil, caregiverRole: String = "") {
        self.name = name
        self.birthDate = birthDate
        self.caregiverRole = caregiverRole
    }

    private enum CodingKeys: String, CodingKey { case name, birthDate, caregiverRole }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        caregiverRole = try c.decodeIfPresent(String.self, forKey: .caregiverRole) ?? ""
    }

    /// "Vedika's Mom", or nil when no role was chosen.
    var caregiverTitle: String? {
        let role = caregiverRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !role.isEmpty else { return nil }
        let baby = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baby.isEmpty else { return Self.displayRole(role) }
        // Each role has its own phrase so languages can match the possessive to it (Hindi की / के).
        let title: String
        switch role {
        case "Mom": title = String(appLocalized: "\(baby)'s Mom")
        case "Dad": title = String(appLocalized: "\(baby)'s Dad")
        case "Grandma": title = String(appLocalized: "\(baby)'s Grandma")
        case "Grandpa": title = String(appLocalized: "\(baby)'s Grandpa")
        case "Nanny": title = String(appLocalized: "\(baby)'s Nanny")
        default: title = String(appLocalized: "\(baby)'s \(role)", comment: "Caregiver title with a role the parent typed, e.g. Vedika's Aunt")
        }
        // English: "Dhruvs' Mom", not "Dhruvs's Mom".
        return baby.hasSuffix("s") ? title.replacingOccurrences(of: "\(baby)'s ", with: "\(baby)' ") : title
    }
}

struct CareState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var baby: BabyProfile?
    var items: [CareItem]
    var events: [CareEvent]
    var vaccines: [VaccineDose]

    init(baby: BabyProfile? = nil, items: [CareItem] = [], events: [CareEvent] = [], vaccines: [VaccineDose] = []) {
        schemaVersion = Self.currentSchemaVersion
        self.baby = baby
        self.items = items
        self.events = events
        self.vaccines = vaccines
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, baby, items, events, vaccines }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        baby = try c.decodeIfPresent(BabyProfile.self, forKey: .baby)
        items = try c.decodeIfPresent([CareItem].self, forKey: .items) ?? []
        events = try c.decodeIfPresent([CareEvent].self, forKey: .events) ?? []
        vaccines = try c.decodeIfPresent([VaccineDose].self, forKey: .vaccines) ?? []
    }

    var isSetUp: Bool { baby != nil }

    func item(_ id: UUID) -> CareItem? {
        items.first { $0.id == id }
    }
}

/// A ready-made item offered during onboarding and in the add sheet.
struct CareTemplate: Identifiable, Hashable {
    /// English name, stable across languages.
    let key: String
    let kind: CareKind
    /// Name in the app's language, used for new items.
    let name: String
    let symbol: String
    let intervalMinutes: Int
    /// Clock times (minutes after midnight) for things done at a set time each day; empty means it repeats by interval.
    let times: [Int]
    let dosageHint: String

    var id: String { key }
    var schedule: CareSchedule { times.isEmpty ? .interval : .times(times) }

    init(kind: CareKind, key: String, name: String, symbol: String, intervalMinutes: Int, times: [Int] = [], dosageHint: String) {
        self.key = key
        self.kind = kind
        self.name = name
        self.symbol = symbol
        self.intervalMinutes = intervalMinutes
        self.times = times
        self.dosageHint = dosageHint
    }

    /// A new care plan item from this template, starting now.
    func makeItem(now: Date = Date()) -> CareItem {
        CareItem(
            kind: kind,
            name: name,
            symbol: symbol,
            intervalMinutes: intervalMinutes,
            schedule: schedule,
            firstDue: times.isEmpty ? now.addingTimeInterval(TimeInterval(intervalMinutes * 60)) : now
        )
    }

    /// Built each time so names follow the language chosen in the app.
    static var all: [CareTemplate] { [
        CareTemplate(kind: .care, key: "Feed", name: String(appLocalized: "Feed"), symbol: "drop.fill", intervalMinutes: 180, dosageHint: ""),
        CareTemplate(kind: .care, key: "Diaper change", name: String(appLocalized: "Diaper change"), symbol: "sparkles", intervalMinutes: 180, dosageHint: ""),
        CareTemplate(kind: .care, key: "Nap", name: String(appLocalized: "Nap"), symbol: "moon.zzz.fill", intervalMinutes: 240, dosageHint: ""),
        CareTemplate(kind: .care, key: "Tummy time", name: String(appLocalized: "Tummy time"), symbol: "figure.and.child.holdinghands", intervalMinutes: 240, dosageHint: ""),
        CareTemplate(kind: .care, key: "Kangaroo care", name: String(appLocalized: "Kangaroo care"), symbol: "heart.fill", intervalMinutes: 480, dosageHint: ""),
        CareTemplate(kind: .care, key: "Bath", name: String(appLocalized: "Bath"), symbol: "bathtub.fill", intervalMinutes: 1440, times: [600], dosageHint: ""),
        CareTemplate(kind: .care, key: "Play time", name: String(appLocalized: "Play time"), symbol: "teddybear.fill", intervalMinutes: 480, dosageHint: ""),
        CareTemplate(kind: .care, key: "Walk outside", name: String(appLocalized: "Walk outside"), symbol: "stroller.fill", intervalMinutes: 1440, times: [480], dosageHint: ""),
        CareTemplate(kind: .medicine, key: "Vitamin D3", name: String(appLocalized: "Vitamin D3"), symbol: "sun.max.fill", intervalMinutes: 1440, times: [540], dosageHint: String(appLocalized: "e.g. 1 drop")),
        CareTemplate(kind: .medicine, key: "Iron drops", name: String(appLocalized: "Iron drops"), symbol: "eyedropper.halffull", intervalMinutes: 1440, times: [540], dosageHint: String(appLocalized: "e.g. 0.5 ml")),
        CareTemplate(kind: .medicine, key: "Calcium syrup", name: String(appLocalized: "Calcium syrup"), symbol: "cross.vial.fill", intervalMinutes: 1440, times: [540], dosageHint: String(appLocalized: "e.g. 2.5 ml")),
        CareTemplate(kind: .medicine, key: "Multivitamin", name: String(appLocalized: "Multivitamin"), symbol: "pills.fill", intervalMinutes: 1440, times: [540], dosageHint: String(appLocalized: "e.g. 0.5 ml")),
        CareTemplate(kind: .medicine, key: "Probiotic", name: String(appLocalized: "Probiotic"), symbol: "leaf.fill", intervalMinutes: 1440, times: [540], dosageHint: String(appLocalized: "e.g. 5 drops")),
    ] }

    static func templates(for kind: CareKind) -> [CareTemplate] {
        all.filter { $0.kind == kind }
    }
}

/// Symbols offered when choosing an icon for a custom item.
enum CareSymbols {
    static let choices: [String] = [
        "drop.fill", "waterbottle.fill", "sparkles", "moon.zzz.fill",
        "figure.and.child.holdinghands", "heart.fill", "bathtub.fill", "teddybear.fill",
        "stroller.fill", "sun.max.fill", "eyedropper.halffull", "cross.vial.fill",
        "pills.fill", "pill.fill", "leaf.fill", "syringe.fill",
        "thermometer.medium", "bandage.fill", "hands.and.sparkles.fill", "music.note",
        "book.fill", "fork.knife", "cup.and.saucer.fill", "star.fill",
    ]
}
