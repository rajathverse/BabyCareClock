import Foundation

/// The language chosen inside the app. It applies to every screen, reminders, the widget and the Watch,
/// independent of the iPhone's own language.
enum AppLanguage {
    struct Option: Identifiable, Hashable {
        let code: String
        /// The language's name in its own script, e.g. "हिन्दी".
        let name: String
        var id: String { code }
    }

    static let options: [Option] = [
        Option(code: "en", name: "English"),
        Option(code: "hi", name: "हिन्दी"),
        Option(code: "kn", name: "ಕನ್ನಡ"),
        Option(code: "ta", name: "தமிழ்"),
        Option(code: "te", name: "తెలుగు"),
        Option(code: "ml", name: "മലയാളം"),
        Option(code: "mr", name: "मराठी"),
        Option(code: "gu", name: "ગુજરાતી"),
        Option(code: "bn", name: "বাংলা"),
        Option(code: "pa", name: "ਪੰਜਾਬੀ"),
        Option(code: "or", name: "ଓଡ଼ିଆ"),
    ]

    /// Saved in the App Group so the widget follows it; the Watch keeps its own copy sent from the iPhone.
    static let storageKey = "appLanguage"
    static var storage: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    /// The chosen language, or the iPhone's language when it is one we support, else English.
    static var code: String {
        get {
            if let saved = storage.string(forKey: storageKey), options.contains(where: { $0.code == saved }) { return saved }
            return systemDefault
        }
        set {
            storage.set(newValue, forKey: storageKey)
            cachedBundle = nil
        }
    }

    static var systemDefault: String {
        for preferred in Locale.preferredLanguages {
            let language = Locale(identifier: preferred).language.languageCode?.identifier ?? ""
            if options.contains(where: { $0.code == language }) { return language }
        }
        return "en"
    }

    static var name: String { options.first { $0.code == code }?.name ?? "English" }

    /// Locale for dates and times. Digits stay 0–9 so they match the rest of the app.
    static var locale: Locale { Locale(identifier: "\(code)_IN@numbers=latn") }

    private static var cachedBundle: (code: String, bundle: Bundle)?

    /// The translations for the chosen language.
    static var bundle: Bundle {
        let code = code
        if let cachedBundle, cachedBundle.code == code { return cachedBundle.bundle }
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        cachedBundle = (code, bundle)
        return bundle
    }
}

extension String {
    /// Like `String(localized:)`, but in the language chosen inside the app.
    init(appLocalized value: String.LocalizationValue, comment: StaticString? = nil) {
        self.init(localized: value, bundle: AppLanguage.bundle, locale: AppLanguage.locale, comment: comment)
    }
}

extension Date {
    /// "9:00 AM" in the app's language.
    var shortTime: String { formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLanguage.locale)) }
}
