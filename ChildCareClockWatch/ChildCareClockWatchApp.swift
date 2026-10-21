import SwiftUI

@main
struct ChildCareClockWatchApp: App {
    @StateObject private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}
