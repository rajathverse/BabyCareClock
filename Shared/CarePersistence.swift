import Foundation

enum AppGroup {
    static let identifier = "group.com.rajathverse.childcareclock"

    /// The shared container the app and widget both read. Falls back to the app's own
    /// Application Support folder when App Groups are unavailable (e.g. a free signing team).
    static var directory: URL {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ChildCareClock", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }
}

enum CarePersistence {
    private static let fileName = "care-state.json"

    private static var url: URL { AppGroup.directory.appendingPathComponent(fileName) }

    static func load() -> CareState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decode(data)
        } catch {
            // Keep the unreadable file aside instead of overwriting it on the next save.
            let backup = AppGroup.directory.appendingPathComponent(fileName + ".unreadable")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            print("Unable to read \(fileName): \(error)")
            return nil
        }
    }

    static func save(_ state: CareState) {
        do {
            try encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("Unable to save \(fileName): \(error.localizedDescription)")
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    static func encode(_ state: CareState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    static func decode(_ data: Data) throws -> CareState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CareState.self, from: data)
    }
}
