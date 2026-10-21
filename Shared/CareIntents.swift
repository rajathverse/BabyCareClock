import AppIntents
import Foundation

/// A care plan item as Siri and Shortcuts see it.
struct CareItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Care item"
    static var defaultQuery = CareItemQuery()

    var id: UUID
    var name: String
    var symbol: String

    init(item: CareItem) {
        id = item.id
        name = item.name
        symbol = item.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct CareItemQuery: EntityStringQuery {
    private var items: [CareItem] {
        let state = CarePersistence.load() ?? CareState()
        return state.items.filter { !CareEngine.isFinished($0, in: state) }
    }

    func entities(for identifiers: [UUID]) async throws -> [CareItemEntity] {
        items.filter { identifiers.contains($0.id) }.map(CareItemEntity.init)
    }

    func entities(matching string: String) async throws -> [CareItemEntity] {
        items.filter { $0.name.localizedCaseInsensitiveContains(string) }.map(CareItemEntity.init)
    }

    func suggestedEntities() async throws -> [CareItemEntity] {
        items.sorted { $0.name < $1.name }.map(CareItemEntity.init)
    }
}

/// "Log a feed": marks an item as done now. Also used by the widget's Done button.
struct LogCareItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Log care item"
    static var description = IntentDescription("Marks a feed, diaper change, medicine or anything in your care plan as done right now.")

    @Parameter(title: "Item")
    var item: CareItemEntity

    init() {}

    init(item: CareItemEntity) {
        self.item = item
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let state = CareActions.perform({ $0.complete(item.id, at: Date()) }),
              let saved = state.item(item.id) else {
            return .result(dialog: "I couldn't find \(item.name) in your care plan.")
        }
        if saved.schedule.isAsNeeded {
            let allowed = Date().addingTimeInterval(saved.interval)
            return .result(dialog: "Logged \(saved.name). The next dose is OK after \(allowed.formatted(date: .omitted, time: .shortened)).")
        }
        let due = CareEngine.nextDue(for: saved, in: state)
        return .result(dialog: "Logged \(saved.name). Next one is due at \(due.formatted(date: .omitted, time: .shortened)).")
    }
}

/// "What's next?": reads out the next item and the one after.
struct NextUpIntent: AppIntent {
    static var title: LocalizedStringResource = "What's next"
    static var description = IntentDescription("Tells you what's due next for your baby.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = CarePersistence.load() ?? CareState()
        let now = Date()
        let schedule = CareEngine.schedule(for: state, now: now)
        guard let next = schedule.first else {
            return .result(dialog: "Nothing is scheduled right now.")
        }
        var sentence = next.due <= now
            ? "\(next.item.name) is due now."
            : "\(next.item.name) is next, \(CareFormat.relative(due: next.due, now: now)), at \(next.due.formatted(date: .omitted, time: .shortened))."
        if schedule.count > 1 {
            let after = schedule[1]
            sentence += " Then \(after.item.name) at \(after.due.formatted(date: .omitted, time: .shortened))."
        }
        return .result(dialog: IntentDialog(stringLiteral: sentence))
    }
}
