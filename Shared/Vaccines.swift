import Foundation

/// One vaccine dose, e.g. "Rotavirus 1" at the 6-week visit.
struct VaccineDose: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// The visit it belongs to, e.g. "6 weeks". Doses with the same visit and due date are shown together.
    var visit: String
    var dueDate: Date
    var givenDate: Date?
    var note: String
    /// Age at which the dose is due, so due dates can be recalculated if the birth date changes.
    var ageMonths: Int?
    var ageWeeks: Int?
    /// Set once the parent changes the due date by hand; it is then left alone.
    var dueDateEdited: Bool

    init(id: UUID = UUID(), name: String, visit: String, dueDate: Date, givenDate: Date? = nil, note: String = "", ageMonths: Int? = nil, ageWeeks: Int? = nil, dueDateEdited: Bool = false) {
        self.id = id
        self.name = name
        self.visit = visit
        self.dueDate = dueDate
        self.givenDate = givenDate
        self.note = note
        self.ageMonths = ageMonths
        self.ageWeeks = ageWeeks
        self.dueDateEdited = dueDateEdited
    }

    private enum CodingKeys: String, CodingKey { case id, name, visit, dueDate, givenDate, note, ageMonths, ageWeeks, dueDateEdited }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        visit = try c.decodeIfPresent(String.self, forKey: .visit) ?? ""
        dueDate = try c.decode(Date.self, forKey: .dueDate)
        givenDate = try c.decodeIfPresent(Date.self, forKey: .givenDate)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        ageMonths = try c.decodeIfPresent(Int.self, forKey: .ageMonths)
        ageWeeks = try c.decodeIfPresent(Int.self, forKey: .ageWeeks)
        dueDateEdited = try c.decodeIfPresent(Bool.self, forKey: .dueDateEdited) ?? false
    }
}

/// A clinic visit: the doses due together.
struct VaccineVisit: Identifiable, Equatable {
    enum Status: Equatable {
        case given
        case overdue
        case dueSoon
        case upcoming
    }

    let title: String
    let dueDate: Date
    let doses: [VaccineDose]

    var id: String { "\(title)-\(Int(dueDate.timeIntervalSince1970))" }
    /// The visit name in the app's language.
    var displayTitle: String { VaccineSchedule.displayVisitTitle(title) }
    var remaining: [VaccineDose] { doses.filter { $0.givenDate == nil } }
    var isComplete: Bool { remaining.isEmpty }
}

/// A national schedule to start from. Every date can be edited afterwards.
struct VaccineSchedule: Identifiable {
    struct Visit {
        let title: String
        let months: Int
        let weeks: Int
        let vaccines: [String]
    }

    let id: String
    let name: String
    let source: String
    let visits: [Visit]

    /// Based on the Indian Academy of Pediatrics (IAP) recommended schedule, birth to 6 years.
    /// Parents are always told to confirm it with their pediatrician.
    static let india = VaccineSchedule(
        id: "in-iap",
        name: "India (IAP)",
        source: "Based on the Indian Academy of Pediatrics (IAP) immunisation schedule.",
        visits: [
            Visit(title: "At birth", months: 0, weeks: 0, vaccines: ["BCG", "OPV 0", "Hepatitis B 1"]),
            Visit(title: "6 weeks", months: 0, weeks: 6, vaccines: ["DTwP/DTaP 1", "IPV 1", "Hib 1", "Hepatitis B 2", "Rotavirus 1", "PCV 1"]),
            Visit(title: "10 weeks", months: 0, weeks: 10, vaccines: ["DTwP/DTaP 2", "IPV 2", "Hib 2", "Hepatitis B 3", "Rotavirus 2", "PCV 2"]),
            Visit(title: "14 weeks", months: 0, weeks: 14, vaccines: ["DTwP/DTaP 3", "IPV 3", "Hib 3", "Hepatitis B 4", "Rotavirus 3", "PCV 3"]),
            Visit(title: "6 months", months: 6, weeks: 0, vaccines: ["Influenza 1"]),
            Visit(title: "7 months", months: 7, weeks: 0, vaccines: ["Influenza 2"]),
            Visit(title: "9 months", months: 9, weeks: 0, vaccines: ["MMR 1", "Typhoid conjugate (TCV)"]),
            Visit(title: "12 months", months: 12, weeks: 0, vaccines: ["Hepatitis A 1"]),
            Visit(title: "15 months", months: 15, weeks: 0, vaccines: ["MMR 2", "Varicella 1", "PCV booster"]),
            Visit(title: "16–18 months", months: 16, weeks: 0, vaccines: ["DTwP/DTaP booster 1", "Hib booster", "IPV booster"]),
            Visit(title: "18–19 months", months: 18, weeks: 0, vaccines: ["Hepatitis A 2", "Varicella 2"]),
            Visit(title: "4–6 years", months: 48, weeks: 0, vaccines: ["DTwP/DTaP booster 2", "Polio booster", "MMR 3"]),
        ]
    )

    static let all = [india]

    /// Visit names are saved in English; this shows them in the app's language.
    static func displayVisitTitle(_ title: String) -> String {
        switch title {
        case "At birth": return String(appLocalized: "At birth")
        case "6 weeks": return String(appLocalized: "6 weeks")
        case "10 weeks": return String(appLocalized: "10 weeks")
        case "14 weeks": return String(appLocalized: "14 weeks")
        case "6 months": return String(appLocalized: "6 months")
        case "7 months": return String(appLocalized: "7 months")
        case "9 months": return String(appLocalized: "9 months")
        case "12 months": return String(appLocalized: "12 months")
        case "15 months": return String(appLocalized: "15 months")
        case "16–18 months": return String(appLocalized: "16–18 months")
        case "18–19 months": return String(appLocalized: "18–19 months")
        case "4–6 years": return String(appLocalized: "4–6 years")
        case "Added by you": return String(appLocalized: "Added by you")
        default: return title
        }
    }
}

enum VaccineEngine {
    /// Visits within this many days count as "due soon".
    static let dueSoonDays = 7

    static func dueDate(birthDate: Date, months: Int, weeks: Int, calendar: Calendar = .current) -> Date {
        let birth = calendar.startOfDay(for: birthDate)
        let afterMonths = calendar.date(byAdding: .month, value: months, to: birth) ?? birth
        return calendar.date(byAdding: .day, value: weeks * 7, to: afterMonths) ?? afterMonths
    }

    static func doses(from schedule: VaccineSchedule, birthDate: Date, calendar: Calendar = .current) -> [VaccineDose] {
        schedule.visits.flatMap { visit in
            visit.vaccines.map { name in
                VaccineDose(
                    name: name,
                    visit: visit.title,
                    dueDate: dueDate(birthDate: birthDate, months: visit.months, weeks: visit.weeks, calendar: calendar),
                    ageMonths: visit.months,
                    ageWeeks: visit.weeks
                )
            }
        }
    }

    /// Doses grouped into visits, in date order.
    static func visits(for doses: [VaccineDose], calendar: Calendar = .current) -> [VaccineVisit] {
        let grouped = Dictionary(grouping: doses) { dose in "\(dose.visit)|\(calendar.startOfDay(for: dose.dueDate).timeIntervalSince1970)" }
        return grouped.values
            .map { doses in
                let sorted = doses.sorted { $0.name < $1.name }
                return VaccineVisit(title: sorted[0].visit, dueDate: calendar.startOfDay(for: sorted[0].dueDate), doses: sorted)
            }
            .sorted { $0.dueDate == $1.dueDate ? $0.title < $1.title : $0.dueDate < $1.dueDate }
    }

    static func status(of visit: VaccineVisit, now: Date, calendar: Calendar = .current) -> VaccineVisit.Status {
        if visit.isComplete { return .given }
        let today = calendar.startOfDay(for: now)
        if visit.dueDate < today { return .overdue }
        let days = calendar.dateComponents([.day], from: today, to: visit.dueDate).day ?? 0
        return days <= dueSoonDays ? .dueSoon : .upcoming
    }

    /// The first visit that still has doses to give.
    static func nextVisit(in state: CareState, calendar: Calendar = .current) -> VaccineVisit? {
        visits(for: state.vaccines, calendar: calendar).first { !$0.isComplete }
    }

    /// "Today", "Tomorrow", "In 3 days", "2 days overdue".
    static func dueText(for visit: VaccineVisit, now: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: visit.dueDate).day ?? 0
        switch days {
        case 0: return String(appLocalized: "Due today")
        case 1: return String(appLocalized: "Due tomorrow")
        case 2...: return String(appLocalized: "In \(CareFormat.days(days))")
        case -1: return String(appLocalized: "1 day overdue")
        default: return String(appLocalized: "\(CareFormat.days(-days)) overdue")
        }
    }
}

// MARK: - Changes

extension CareState {
    /// Replaces the vaccine list with a national schedule calculated from the birth date.
    /// Doses given in the past are marked as given so the list starts at the next visit.
    mutating func startVaccineSchedule(_ schedule: VaccineSchedule, birthDate: Date, markPastAsGiven: Bool, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        vaccines = VaccineEngine.doses(from: schedule, birthDate: birthDate, calendar: calendar).map { dose in
            var dose = dose
            if markPastAsGiven, dose.dueDate < today { dose.givenDate = dose.dueDate }
            return dose
        }
    }

    /// Recalculates due dates after the birth date changes, except doses already given or edited by hand.
    mutating func recalculateVaccineDates(birthDate: Date, calendar: Calendar = .current) {
        for index in vaccines.indices where vaccines[index].givenDate == nil && !vaccines[index].dueDateEdited {
            guard let months = vaccines[index].ageMonths, let weeks = vaccines[index].ageWeeks else { continue }
            vaccines[index].dueDate = VaccineEngine.dueDate(birthDate: birthDate, months: months, weeks: weeks, calendar: calendar)
        }
    }

    mutating func setVaccineGiven(_ id: UUID, on date: Date?) {
        guard let index = vaccines.firstIndex(where: { $0.id == id }) else { return }
        vaccines[index].givenDate = date
    }

    mutating func setVisitGiven(_ visit: VaccineVisit, on date: Date) {
        for dose in visit.remaining { setVaccineGiven(dose.id, on: date) }
    }

    mutating func updateVaccine(_ dose: VaccineDose) {
        guard let index = vaccines.firstIndex(where: { $0.id == dose.id }) else { return }
        var dose = dose
        dose.name = dose.name.trimmingCharacters(in: .whitespacesAndNewlines)
        dose.note = dose.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !Calendar.current.isDate(dose.dueDate, inSameDayAs: vaccines[index].dueDate) { dose.dueDateEdited = true }
        vaccines[index] = dose
    }

    mutating func addVaccine(name: String, dueDate: Date) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        vaccines.append(VaccineDose(name: trimmed, visit: "Added by you", dueDate: dueDate, dueDateEdited: true))
    }

    mutating func deleteVaccine(_ id: UUID) {
        vaccines.removeAll { $0.id == id }
    }
}
