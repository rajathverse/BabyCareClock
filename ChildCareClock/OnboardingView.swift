import PhotosUI
import SwiftUI

/// First launch: welcome → baby → what to track → reminders.
struct OnboardingView: View {
    @EnvironmentObject private var vm: CareViewModel

    private enum Step: Int, CaseIterable {
        case welcome, baby, plan, reminders
    }

    @State private var step = Step.welcome
    @State private var name = ""
    @State private var role = ""
    @State private var hasBirthDate = true
    @State private var birthDate = Date()
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    /// Chosen ready-made items by template key (English name), with the timing for each.
    @State private var chosen: [String: PlanTiming] = Dictionary(uniqueKeysWithValues: ["Feed", "Diaper change", "Vitamin D3"].compactMap { key in
        CareTemplate.all.first { $0.key == key }.map { (key, PlanTiming($0)) }
    })
    /// Items the parent added themselves, and any of those they said were already done.
    @State private var customItems: [CareItem] = []
    @State private var customDoneAt: [UUID: Date] = [:]
    @State private var editingTiming: CareTemplate?
    @State private var addingCustom = false
    @AppStorage(AppLanguage.storageKey, store: AppPreferences.defaults) private var languageCode = ""
    @FocusState private var nameFocused: Bool
    @State private var confirmingFreshStart = false
    /// The Continue button hides while typing, so the rest of the form is seen before moving on.
    @State private var keyboardVisible = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                progress
                    .padding(.top, 12)
                ScrollView {
                    Group {
                        switch step {
                        case .welcome: welcome
                        case .baby: babyStep
                        case .plan: planStep
                        case .reminders: remindersStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
                if !keyboardVisible {
                    footer
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .confirmationDialog("Start fresh?", isPresented: $confirmingFreshStart, titleVisibility: .visible) {
            Button("Delete old data and start fresh", role: .destructive) {
                vm.discardBackup()
                go(.baby)
            }
        } message: {
            Text("The data from before can't be brought back afterwards.")
        }
        .sheet(item: $editingTiming) { template in
            PlanTimingSheet(name: template.name, timing: Binding(
                get: { chosen[template.key] ?? PlanTiming(template) },
                set: { chosen[template.key] = $0 }
            ))
        }
        .sheet(isPresented: $addingCustom) {
            ItemEditorSheet(mode: .new(nil), draft: draftState) { item, doneAt in
                customItems.append(item)
                if let doneAt { customDoneAt[item.id] = doneAt }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 22) {
            AppMark()
                .frame(width: 150, height: 150)
                .padding(.top, 30)
            Text("Baby Care Clock")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppPalette.text)
            Text("Gentle reminders for feeds, naps, vitamins and medicines, so you can rest a little easier.")
                .font(.title3)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)
            if let backup = vm.restorableBackup {
                restoreCard(backup)
            } else {
                features
            }
            languagePicker
        }
    }

    /// A drop-down of languages, each in its own script; the screen switches as soon as one is picked.
    private var languagePicker: some View {
        HStack(spacing: 12) {
            Label("Language", systemImage: "globe")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.text)
            Spacer(minLength: 8)
            Menu {
                ForEach(AppLanguage.options) { option in
                    Button {
                        languageCode = option.code
                        SoundManager.shared.selection()
                    } label: {
                        if option.code == AppLanguage.code {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(verbatim: option.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(verbatim: AppLanguage.name)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppPalette.primaryDeep)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(AppPalette.primary.opacity(0.14), in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassPanel()
    }

    private func restoreCard(_ backup: CareState) -> some View {
        let name = backup.baby?.name ?? String(appLocalized: "your baby")
        let items = CareFormat.items(backup.items.count)
        let since = backup.events.map(\.date).min()
        let found = since.map { String(appLocalized: "We found \(name)'s data from before you reinstalled the app: \(items) in the care plan, with history since \($0.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLanguage.locale))).") }
            ?? String(appLocalized: "We found \(name)'s data from before you reinstalled the app: \(items) in the care plan.")
        return VStack(alignment: .leading, spacing: 10) {
            Label("Welcome back", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.headline)
                .foregroundStyle(AppPalette.primaryDeep)
            Text(found)
                .font(.subheadline)
                .foregroundStyle(AppPalette.text)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 16) {
            feature("bell.badge.fill", "A reminder the moment something is due")
            feature("hand.tap.fill", "One tap to log it, even half asleep")
            feature("clock.arrow.circlepath", "A clear history to share with your doctor")
            feature("lock.fill", "Everything stays on this iPhone")
        }
        .padding(20)
        .glassPanel()
    }

    private var babyStep: some View {
        VStack(spacing: 22) {
            title("Who are we caring for?", subtitle: "Add a photo to see it in the app and on your Home Screen widget.")
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    BabyAvatar(photo: photo, name: name, size: 130)
                    Image(systemName: photo == nil ? "camera.fill" : "pencil")
                        .font(.headline)
                        .foregroundStyle(AppPalette.onPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppPalette.primary, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                }
            }
            .accessibilityLabel(photo == nil ? "Add a photo" : "Change photo")

            VStack(spacing: 0) {
                TextField("Baby's name", text: $name)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }
                    .padding(16)
                Divider().padding(.leading, 16)
                Toggle("Add birth date", isOn: $hasBirthDate.animation())
                    .padding(16)
                if hasBirthDate {
                    DatePicker("Born", selection: $birthDate, in: Date().addingTimeInterval(-5 * 365 * 86_400)...Date(), displayedComponents: .date)
                        .padding([.horizontal, .bottom], 16)
                }
            }
            .glassPanel()

            CaregiverRolePicker(role: $role, babyName: name)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()
            Text("Only stored on this iPhone. Never uploaded.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("What would you like to track?", subtitle: "Pick what you need. Tap the timing to change it.")
            ForEach([CareKind.care, .medicine]) { kind in
                VStack(alignment: .leading, spacing: 8) {
                    Text(kind.sectionTitle.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(AppPalette.secondaryText)
                        .padding(.leading, 4)
                    VStack(spacing: 0) {
                        let templates = CareTemplate.templates(for: kind)
                        ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                            if index > 0 { Divider().padding(.leading, 52) }
                            templateRow(template)
                        }
                        ForEach(customItems.filter { $0.kind == kind }) { item in
                            Divider().padding(.leading, 52)
                            customRow(item)
                        }
                    }
                    .padding(.vertical, 4)
                    .glassPanel()
                }
            }
            Button { addingCustom = true } label: {
                Label("Add your own", systemImage: "plus.circle.fill")
            }
            .buttonStyle(SoftButtonStyle())
            Text("You can change timings, add or remove anything anytime from the Care Plan tab.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    /// Tick, icon and name toggle the item; the timing underneath opens the timing sheet.
    private func templateRow(_ template: CareTemplate) -> some View {
        let timing = chosen[template.key]
        let isOn = timing != nil
        let toggle = {
            withAnimation(.snappy) { chosen[template.key] = isOn ? nil : PlanTiming(template) }
            SoundManager.shared.selection()
        }
        return HStack(alignment: .center, spacing: 12) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOn ? AppPalette.primary : AppPalette.secondaryText.opacity(0.5))
                    Image(systemName: template.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.deepTint(for: template.kind))
                        .frame(width: 22)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(template.name)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            VStack(alignment: .leading, spacing: 2) {
                Button(action: toggle) {
                    Text(template.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppPalette.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)

                Button {
                    if !isOn { chosen[template.key] = PlanTiming(template) }
                    editingTiming = template
                } label: {
                    HStack(spacing: 3) {
                        Text((timing ?? PlanTiming(template)).summary)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(isOn ? AppPalette.primaryDeep : AppPalette.secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func customRow(_ item: CareItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppPalette.primary)
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.deepTint(for: item.kind))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                Text(CareFormat.schedule(item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.primaryDeep)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy) {
                    customItems.removeAll { $0.id == item.id }
                    customDoneAt[item.id] = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppPalette.secondaryText.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// What's been picked so far, so "Add your own" can spot a duplicate name.
    private var draftState: CareState {
        CareState(items: chosenItems() + customItems)
    }

    private func chosenItems(now: Date = Date()) -> [CareItem] {
        CareTemplate.all.compactMap { template in
            chosen[template.key].map { $0.apply(to: template.makeItem(now: now), now: now) }
        }
    }

    private var remindersStep: some View {
        VStack(spacing: 22) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppPalette.overdue, AppPalette.primary)
                .frame(width: 130, height: 130)
                .background(AppPalette.primary.opacity(0.12), in: Circle())
                .padding(.top, 20)
            title("Never miss a dose", subtitle: "We'll send a notification right when each item is due. Press and hold a reminder to tap Done or Snooze without opening the app.")
            Text("Baby Care Clock is a reminder tool, not medical advice. Always follow your pediatrician's guidance.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: Pieces

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? AppPalette.primary : AppPalette.primary.opacity(0.18))
                    .frame(width: item == step ? 26 : 8, height: 8)
            }
        }
        .animation(.snappy, value: step)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case .welcome:
                if let backup = vm.restorableBackup {
                    Button(backup.baby.map { String(appLocalized: "Restore \($0.name)'s data") } ?? String(appLocalized: "Restore my data")) { vm.restoreBackup() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Start fresh") { confirmingFreshStart = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.secondaryText)
                        .frame(minHeight: 36)
                } else {
                    Button("Get started") { go(.baby) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            case .baby:
                Button("Continue") { go(.plan) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.5 : 1)
                back(.welcome)
            case .plan:
                Button(chosen.isEmpty && customItems.isEmpty ? "Skip for now" : "Continue") { go(.reminders) }
                    .buttonStyle(PrimaryButtonStyle())
                back(.baby)
            case .reminders:
                Button("Allow reminders") {
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not now") { finish() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(minHeight: 36)
            }
        }
    }

    private func back(_ target: Step) -> some View {
        Button("Back") { go(target) }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppPalette.secondaryText)
            .frame(minHeight: 36)
    }

    private func title(_ text: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.title.weight(.bold))
                .foregroundStyle(AppPalette.text)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppPalette.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppPalette.primaryDeep)
                .frame(width: 36, height: 36)
                .background(AppPalette.primary.opacity(0.14), in: Circle())
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.text)
        }
    }

    private func hideKeyboard() {
        nameFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func go(_ target: Step) {
        nameFocused = false
        withAnimation(.smooth) { step = target }
        if target == .baby, trimmedName.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocused = true }
        }
    }

    private func finish() {
        vm.completeOnboarding(
            baby: BabyProfile(name: trimmedName, birthDate: hasBirthDate ? birthDate : nil, caregiverRole: role.trimmingCharacters(in: .whitespacesAndNewlines)),
            photo: photo,
            items: chosenItems() + customItems,
            doneAt: customDoneAt
        )
    }
}

/// How often a ready-made item repeats, as chosen during setup.
struct PlanTiming: Equatable {
    var intervalMinutes: Int
    /// Clock times (minutes after midnight); empty means every `intervalMinutes`.
    var times: [Int]

    init(_ template: CareTemplate) {
        intervalMinutes = template.intervalMinutes
        times = template.times
    }

    var summary: String {
        times.isEmpty ? CareFormat.interval(intervalMinutes) : CareFormat.schedule(apply(to: CareItem(kind: .care, name: "", symbol: "", intervalMinutes: 1440, firstDue: Date())))
    }

    /// Interval items start counting from now; set-time items are first due at their next time.
    func apply(to item: CareItem, now: Date = Date()) -> CareItem {
        var item = item
        if times.isEmpty {
            item.schedule = .interval
            item.intervalMinutes = intervalMinutes
            item.firstDue = now.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        } else {
            item.schedule = .times(times.sorted())
            item.intervalMinutes = max(CareEngine.minimumIntervalMinutes, 1440 / times.count)
            item.firstDue = now
        }
        return item
    }
}

/// Change how often a ready-made item repeats: every few hours, or at set times each day.
private struct PlanTimingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let name: String
    @Binding var timing: PlanTiming
    @State private var draft: PlanTiming
    @State private var useTimes: Bool

    private let intervalPresets = [60, 120, 180, 240, 360, 480, 720]

    init(name: String, timing: Binding<PlanTiming>) {
        self.name = name
        _timing = timing
        _draft = State(initialValue: timing.wrappedValue)
        _useTimes = State(initialValue: !timing.wrappedValue.times.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Repeats", selection: $useTimes) {
                        Text("Interval").tag(false)
                        Text("Set times").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if useTimes {
                    Section {
                        ForEach(draft.times.indices, id: \.self) { index in
                            HStack {
                                DatePicker("Time \(index + 1)", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                                if draft.times.count > 1 {
                                    Button { draft.times.remove(at: index) } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(AppPalette.overdueText)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove time \(index + 1)")
                                }
                            }
                        }
                        if draft.times.count < CareEngine.maximumTimesPerDay {
                            Button {
                                draft.times.append(min((draft.times.max() ?? 480) + 240, 1380))
                            } label: {
                                Label("Add a time", systemImage: "plus.circle.fill")
                            }
                        }
                    } footer: {
                        Text("Due every day at these times, even if one was given a little early or late.")
                    }
                } else {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(intervalPresets, id: \.self) { minutes in
                                ChoiceChip(title: CareFormat.interval(minutes), isSelected: draft.intervalMinutes == minutes) {
                                    draft.intervalMinutes = minutes
                                    SoundManager.shared.selection()
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    } footer: {
                        Text("The next one is due this long after the last time it was done.")
                    }
                }
            }
            .softFormBackground()
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var result = draft
                        if !useTimes { result.times = [] }
                        timing = result
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: useTimes) { _, on in
                if on, draft.times.isEmpty { draft.times = [540] }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = draft.times.indices.contains(index) ? draft.times[index] : 540
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                if draft.times.indices.contains(index) { draft.times[index] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
            }
        )
    }
}

/// The app's mark: a soft clock face with a little heart, drawn in SwiftUI.
struct AppMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(LinearGradient(colors: [AppPalette.medicine, Color(light: 0xFFC9B8, dark: 0xB07A8C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.66)
                    .shadow(color: AppPalette.primaryDeep.opacity(0.2), radius: size * 0.05, y: size * 0.02)
                ForEach(0..<12) { tick in
                    Capsule()
                        .fill(AppPalette.medicine)
                        .frame(width: size * 0.018, height: size * (tick % 3 == 0 ? 0.06 : 0.035))
                        .offset(y: -size * 0.27)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                Capsule()
                    .fill(Color(UIColor(hex: 0x6A58E0)))
                    .frame(width: size * 0.04, height: size * 0.17)
                    .offset(y: -size * 0.085)
                    .rotationEffect(.degrees(-50))
                Capsule()
                    .fill(Color(UIColor(hex: 0x6A58E0)))
                    .frame(width: size * 0.04, height: size * 0.23)
                    .offset(y: -size * 0.115)
                    .rotationEffect(.degrees(60))
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.09))
                    .foregroundStyle(Color(UIColor(hex: 0xF2948A)))
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
