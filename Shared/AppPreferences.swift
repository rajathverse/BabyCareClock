import SwiftUI

enum AppPreferences {
    /// Settings live in the App Group so the widget and Siri see the same reminder options.
    static let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    static let appearance = "appearance"
    static let soundMode = "soundMode"
    /// Minutes before the due time for an extra heads-up notification; 0 means off.
    static let earlyReminderMinutes = "earlyReminderMinutes"
    /// Items due within this many minutes are shown as "due soon".
    static let warningMinutes = "warningMinutes"
    static let vaccineRemindersEnabled = "vaccineRemindersEnabled"
    /// Repeat a medicine's reminder if it hasn't been marked done.
    static let medicineNudgesEnabled = "medicineNudgesEnabled"

    static let defaultWarningMinutes = 15
    static let defaultEarlyReminderMinutes = 5

    static func register() {
        defaults.register(defaults: [
            soundMode: SoundMode.daytime.rawValue,
            earlyReminderMinutes: defaultEarlyReminderMinutes,
            warningMinutes: defaultWarningMinutes,
            vaccineRemindersEnabled: true,
            medicineNudgesEnabled: true,
        ])
    }
}

/// When the in-app Done / Snooze chimes play. Vibration always plays.
enum SoundMode: String, CaseIterable, Identifiable {
    case daytime
    case always
    case off

    /// "Daytime only" is quiet from 9 PM until 7 AM.
    static let nightStartHour = 21
    static let nightEndHour = 7

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daytime: return "Daytime only"
        case .always: return "Always"
        case .off: return "Off"
        }
    }

    func allowsSound(at date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .always: return true
        case .off: return false
        case .daytime:
            let hour = calendar.component(.hour, from: date)
            return hour >= Self.nightEndHour && hour < Self.nightStartHour
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
