import AppIntents

/// Siri phrases. Each must mention the app's name.
struct CareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogCareItemIntent(),
            phrases: [
                "Log \(\.$item) in \(.applicationName)",
                "Mark \(\.$item) done in \(.applicationName)",
                "Log in \(.applicationName)",
            ],
            shortTitle: "Log an item",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: NextUpIntent(),
            phrases: [
                "What's next in \(.applicationName)",
                "What's due in \(.applicationName)",
            ],
            shortTitle: "What's next",
            systemImageName: "clock.fill"
        )
    }
}
