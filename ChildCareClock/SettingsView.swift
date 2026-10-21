import PhotosUI
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage(AppPreferences.appearance, store: AppPreferences.defaults) private var appearance = AppAppearance.system
    @AppStorage(AppPreferences.soundMode, store: AppPreferences.defaults) private var soundMode = SoundMode.daytime
    @AppStorage(AppPreferences.earlyReminderMinutes, store: AppPreferences.defaults) private var earlyReminderMinutes = AppPreferences.defaultEarlyReminderMinutes
    @AppStorage(AppPreferences.warningMinutes, store: AppPreferences.defaults) private var warningMinutes = AppPreferences.defaultWarningMinutes
    @AppStorage(AppPreferences.medicineNudgesEnabled, store: AppPreferences.defaults) private var medicineNudgesEnabled = true
    @AppStorage(AppPreferences.vaccineRemindersEnabled, store: AppPreferences.defaults) private var vaccineRemindersEnabled = true

    @State private var name = ""
    @State private var role = ""
    @State private var hasBirthDate = false
    @State private var birthDate = Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var notificationStatus = UNAuthorizationStatus.notDetermined
    @State private var confirmingReset = false
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            Form {
                babySection
                remindersSection

                Section {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Sounds", selection: $soundMode) {
                        ForEach(SoundMode.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text(soundFooter)
                }

                Section {
                    ShareLink(item: exportFile(), preview: SharePreview("Baby Care Clock backup")) {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { confirmingReset = true } label: {
                        Label("Delete all data", systemImage: "trash")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Everything is stored only on this iPhone. Nothing is uploaded or shared unless you choose to.")
                }

                Section("About") {
                    Button { showingPrivacy = true } label: {
                        Label("Privacy & medical disclaimer", systemImage: "hand.raised.fill")
                    }
                    LabeledContent("Version", value: appVersion)
                }
            }
            .softFormBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveBaby()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadBaby)
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        vm.setPhoto(image)
                    }
                }
            }
            .onChange(of: earlyReminderMinutes) { _, _ in vm.refreshOutsideApp() }
            .onChange(of: vaccineRemindersEnabled) { _, _ in vm.refreshOutsideApp() }
            .onChange(of: medicineNudgesEnabled) { _, _ in vm.refreshOutsideApp() }
            .confirmationDialog("Delete all data?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    dismiss()
                    vm.resetAll()
                }
            } message: {
                Text("This removes the baby profile, photo, care plan and all history from this iPhone, including the copy kept for reinstalling. It can't be undone.")
            }
            .sheet(isPresented: $showingPrivacy) { PrivacyView() }
        }
    }

    private var babySection: some View {
        let photo = vm.photo
        let initialName = name
        return Section("Baby") {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    BabyAvatar(photo: photo, name: initialName, size: 64)
                }
                .accessibilityLabel("Change photo")
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Name", text: $name)
                        .font(.headline)
                        .textInputAutocapitalization(.words)
                        .onSubmit(saveBaby)
                    if vm.photo != nil {
                        Button("Remove photo", role: .destructive) { vm.setPhoto(nil) }
                            .font(.footnote)
                            .buttonStyle(.borderless)
                    }
                }
            }
            CaregiverRolePicker(role: $role, babyName: name)
                .padding(.vertical, 4)
            Toggle("Birth date", isOn: $hasBirthDate)
            if hasBirthDate {
                DatePicker("Born", selection: $birthDate, in: ...Date(), displayedComponents: .date)
            }
        }
    }

    private var remindersSection: some View {
        Section {
            if notificationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } label: {
                    Label("Notifications are off. Turn on in Settings", systemImage: "bell.slash.fill")
                        .foregroundStyle(AppPalette.overdueText)
                }
            } else if notificationStatus == .notDetermined {
                Button {
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        await refreshNotificationStatus()
                        vm.refreshOutsideApp()
                    }
                } label: {
                    Label("Allow reminders", systemImage: "bell.badge.fill")
                }
            }
            Picker("Early heads-up", selection: $earlyReminderMinutes) {
                Text("Off").tag(0)
                Text("5 min before").tag(5)
                Text("15 min before").tag(15)
                Text("30 min before").tag(30)
            }
            Picker("Show \"due soon\"", selection: $warningMinutes) {
                Text("5 min before").tag(5)
                Text("10 min before").tag(10)
                Text("15 min before").tag(15)
                Text("30 min before").tag(30)
            }
            Toggle("Repeat medicine reminders", isOn: $medicineNudgesEnabled)
            Toggle("Vaccination reminders", isOn: $vaccineRemindersEnabled)
        } header: {
            Text("Reminders")
        } footer: {
            Text(medicineNudgesEnabled
                 ? "You'll always get a notification with sound and vibration when something is due. If a medicine isn't marked done, it reminds you again \(NotificationScheduler.nudgeMinutes) and \(NotificationScheduler.nudgeMinutes * 2) minutes later."
                 : "You'll always get a notification with sound and vibration when something is due.")
        }
    }

    private var soundFooter: String {
        switch soundMode {
        case .daytime: return "A soft chime when you tap Done or Snooze, quiet from 9 PM to 7 AM so you only feel a vibration at night. Reminder notifications are not affected."
        case .always: return "A soft chime when you tap Done or Snooze, at any hour. Reminder notifications are not affected."
        case .off: return "Only a vibration when you tap Done or Snooze. Reminder notifications are not affected."
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func loadBaby() {
        name = vm.baby?.name ?? ""
        role = vm.baby?.caregiverRole ?? ""
        hasBirthDate = vm.baby?.birthDate != nil
        birthDate = vm.baby?.birthDate ?? Date()
    }

    private func saveBaby() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = BabyProfile(
            name: trimmed.isEmpty ? (vm.baby?.name ?? "Baby") : trimmed,
            birthDate: hasBirthDate ? birthDate : nil,
            caregiverRole: role.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if profile != vm.baby { vm.updateBaby(profile) }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NotificationScheduler.authorizationStatus()
    }

    private func exportFile() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BabyCareClock-backup.json")
        if let data = try? CarePersistence.encode(vm.state) {
            try? data.write(to: url, options: .atomic)
        }
        return url
    }
}

private struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    block("Your privacy", "Baby Care Clock has no account, no ads and no tracking. Your baby's name, photo, care plan and history are stored only on this iPhone. A copy is kept in the iPhone's secure Keychain so your data comes back if you delete and reinstall the app. Nothing is sent to us or anyone else. Data only leaves your phone when you choose to share or export it.")
                    block("Notifications", "Reminders are scheduled on your iPhone using Apple's local notifications. They work offline.")
                    block("Not medical advice", "Baby Care Clock is a reminder and logging tool. It does not give medical advice and is not a medical device. Always follow the dosing instructions from your pediatrician, pharmacist or the medicine's label, and contact a doctor if you are worried about your baby's health.")
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.text)
            Text(text)
                .font(.body)
                .foregroundStyle(AppPalette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}
