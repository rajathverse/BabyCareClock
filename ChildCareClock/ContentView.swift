// xcode: set sdk=iOS

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CareViewModel.shared
    @AppStorage(AppPreferences.appearance, store: AppPreferences.defaults) private var appearance = AppAppearance.system
    @AppStorage(AppPreferences.soundMode, store: AppPreferences.defaults) private var soundMode = SoundMode.daytime
    @AppStorage(AppLanguage.storageKey, store: AppPreferences.defaults) private var languageCode = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = Tab.today

    enum Tab: Hashable {
        case today, history, plan
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.state.isSetUp {
                tabs
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if let toast = vm.toast {
                ToastView(toast: toast, onUndo: vm.undo, onDismiss: vm.dismissToast)
                    .id(toast.id)
                    .padding(.horizontal, 16)
                    .padding(.bottom, vm.state.isSetUp ? 78 : 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .animation(.smooth, value: vm.state.isSetUp)
        // Rebuilt when the language changes so every screen picks up the new words.
        .id(languageCode)
        .environment(\.locale, AppLanguage.locale)
        .environmentObject(vm)
        .tint(AppPalette.primary)
        .fontDesign(.rounded)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            SoundManager.shared.mode = soundMode
            vm.refreshOutsideApp()
        }
        .onChange(of: languageCode) { _, _ in
            NotificationScheduler.registerCategories()
            vm.refreshOutsideApp()
        }
        .onChange(of: soundMode) { _, mode in
            SoundManager.shared.mode = mode
            SoundManager.shared.selection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                vm.reloadFromDisk()
                vm.refreshOutsideApp()
            } else {
                vm.saveNow()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView(openPlan: { selectedTab = .plan })
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                .tag(Tab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)
            CarePlanView()
                .tabItem { Label("Care Plan", systemImage: "list.bullet.clipboard") }
                .tag(Tab.plan)
        }
    }
}

#Preview {
    ContentView()
}
