import SwiftUI

/// Add or edit a care plan item.
struct ItemEditorSheet: View {
    enum Mode: Identifiable {
        case new(CareKind?)
        case edit(CareItem)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let item): return item.id.uuidString
            }
        }
    }

    enum Repeat: String, CaseIterable, Identifiable {
        case every
        case times
        case asNeeded

        var id: String { rawValue }
        var title: String {
            switch self {
            case .every: return String(appLocalized: "Interval")
            case .times: return String(appLocalized: "Set times")
            case .asNeeded: return String(appLocalized: "As needed")
            }
        }
    }

    enum Start: String, CaseIterable, Identifiable {
        case dueNow
        case doneAt
        case dueAt

        var id: String { rawValue }
        var title: String {
            switch self {
            case .dueNow: return String(appLocalized: "Due now")
            case .doneAt: return String(appLocalized: "Already done")
            case .dueAt: return String(appLocalized: "Due later")
            }
        }
    }

    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    /// During first-time setup there's no care plan yet: new items are checked against `draft`
    /// and handed back through `onCreate` instead of being saved.
    var draft: CareState? = nil
    var onCreate: ((CareItem, Date?) -> Void)? = nil

    @State private var kind: CareKind
    @State private var name: String
    @State private var symbol: String
    @State private var repeatMode: Repeat
    @State private var intervalMinutes: Int
    @State private var times: [Int]
    @State private var dosage: String
    @State private var notes: String
    @State private var remindersOn: Bool
    @State private var hasEnd: Bool
    @State private var lastDay: Date
    @State private var start = Start.dueNow
    @State private var startDate = Date()
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    /// "Custom" chosen in the add sheet: the name and icon fields appear.
    @State private var isCustom = false

    private let everyPresets = [60, 120, 180, 240, 360, 480, 720, 1440]
    private let gapPresets = [240, 360, 480, 720]
    private let coursePresets = [3, 5, 7, 10, 14]
    private static let defaultTimes = [540]

    init(mode: Mode, draft: CareState? = nil, onCreate: ((CareItem, Date?) -> Void)? = nil) {
        self.mode = mode
        self.draft = draft
        self.onCreate = onCreate
        let today = Calendar.current.startOfDay(for: Date())
        switch mode {
        case .new(let kind):
            let kind = kind ?? .care
            _kind = State(initialValue: kind)
            _name = State(initialValue: "")
            _symbol = State(initialValue: kind.defaultSymbol)
            _repeatMode = State(initialValue: .every)
            _intervalMinutes = State(initialValue: kind == .medicine ? 1440 : 180)
            _times = State(initialValue: Self.defaultTimes)
            _dosage = State(initialValue: "")
            _notes = State(initialValue: "")
            _remindersOn = State(initialValue: true)
            _hasEnd = State(initialValue: false)
            _lastDay = State(initialValue: Calendar.current.date(byAdding: .day, value: 4, to: today) ?? today)
        case .edit(let item):
            _kind = State(initialValue: item.kind)
            _name = State(initialValue: item.name)
            _symbol = State(initialValue: item.symbol)
            switch item.schedule {
            case .interval:
                _repeatMode = State(initialValue: .every)
                _times = State(initialValue: Self.defaultTimes)
            case .times(let saved):
                _repeatMode = State(initialValue: .times)
                _times = State(initialValue: saved)
            case .asNeeded:
                _repeatMode = State(initialValue: .asNeeded)
                _times = State(initialValue: Self.defaultTimes)
            }
            _intervalMinutes = State(initialValue: item.intervalMinutes)
            _dosage = State(initialValue: item.dosage)
            _notes = State(initialValue: item.notes)
            _remindersOn = State(initialValue: item.remindersOn)
            _hasEnd = State(initialValue: item.endDate != nil)
            _lastDay = State(initialValue: item.endDate.map { $0.addingTimeInterval(-1) } ?? (Calendar.current.date(byAdding: .day, value: 4, to: today) ?? today))
            _startDate = State(initialValue: item.firstDue)
        }
    }

    private var editingItem: CareItem? {
        if case .edit(let item) = mode { return item }
        return nil
    }

    /// The start can only be changed for "every" items while nothing has been logged for them.
    private var canChooseStart: Bool {
        guard repeatMode == .every else { return false }
        guard let item = editingItem else { return true }
        return CareEngine.latestEvent(for: item.id, in: vm.state) == nil
    }

    private var dosageHint: String {
        CareTemplate.all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.dosageHint.nonEmpty ?? String(appLocalized: "e.g. 1 drop or 2.5 ml")
    }

    var body: some View {
        NavigationStack {
            Form {
                if editingItem == nil {
                    Section {
                        Picker("Type", selection: $kind) {
                            ForEach(CareKind.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(CareTemplate.templates(for: kind)) { template in
                                ChoiceChip(title: template.name, symbol: template.symbol, isSelected: !isCustom && name == template.name) {
                                    apply(template)
                                }
                            }
                            ChoiceChip(title: String(appLocalized: "Custom"), symbol: "pencil", isSelected: isCustom) {
                                isCustom = true
                                name = ""
                                symbol = kind.defaultSymbol
                                SoundManager.shared.selection()
                            }
                        }
                        .padding(.vertical, 6)
                        if isCustom { nameFields }
                    } header: {
                        Text("Pick one, or make your own")
                    }
                } else {
                    Section("Name") { nameFields }
                }

                repeatSection

                if canChooseStart {
                    Section("Starts") {
                        Picker("Starts", selection: $start) {
                            ForEach(Start.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        switch start {
                        case .dueNow:
                            EmptyView()
                        case .doneAt:
                            DatePicker("Last done", selection: $startDate, in: Date().addingTimeInterval(-7 * 86_400)...Date(), displayedComponents: [.date, .hourAndMinute])
                        case .dueAt:
                            DatePicker("First due", selection: $startDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }

                courseSection

                Section("Details") {
                    if kind == .medicine {
                        TextField("Dosage (\(dosageHint))", text: $dosage)
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                    if repeatMode != .asNeeded {
                        Toggle("Remind me when due", isOn: $remindersOn)
                    }
                }

                if editingItem != nil {
                    Section {
                        Button("Delete from care plan", role: .destructive) { confirmingDelete = true }
                    }
                }

                if kind == .medicine {
                    Section {
                    } footer: {
                        Text("Always follow your pediatrician's or pharmacist's dosing instructions. Baby Care Clock is a reminder tool, not medical advice.")
                    }
                }
            }
            .softFormBackground()
            .navigationTitle(editingItem == nil ? "Add to care plan" : "Edit \(editingItem?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingItem == nil ? "Add" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: kind) { _, newKind in
                if name.isEmpty {
                    symbol = newKind.defaultSymbol
                    intervalMinutes = newKind == .medicine ? 1440 : 180
                }
            }
            .onChange(of: repeatMode) { old, new in
                if new == .asNeeded, !gapPresets.contains(intervalMinutes) { intervalMinutes = 360 }
                if old == .asNeeded, new == .every { intervalMinutes = kind == .medicine ? 1440 : 180 }
            }
            .onChange(of: start) { _, newStart in
                startDate = newStart == .dueAt ? Date().addingTimeInterval(TimeInterval(intervalMinutes * 60)) : Date()
            }
            .alert("Can't save yet", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("Delete \(editingItem?.name ?? "")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item = editingItem { vm.deleteItem(item.id) }
                    dismiss()
                }
            } message: {
                Text("Its reminders and history will be removed too.")
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var nameFields: some View {
        HStack(spacing: 12) {
            SymbolBadge(symbol: symbol, kind: kind, size: 36)
            TextField(kind == .medicine ? "Type any medicine name" : "Type any activity name", text: $name)
                .font(.headline)
                .textInputAutocapitalization(.words)
        }
        DisclosureGroup("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                ForEach(CareSymbols.choices, id: \.self) { choice in
                    Button {
                        symbol = choice
                        SoundManager.shared.selection()
                    } label: {
                        SymbolBadge(symbol: choice, kind: kind, size: 42)
                            .overlay(Circle().stroke(AppPalette.primary, lineWidth: symbol == choice ? 2.5 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.replacingOccurrences(of: ".", with: " "))
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var repeatSection: some View {
        Section {
            Picker("Repeats", selection: $repeatMode) {
                ForEach(Repeat.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            switch repeatMode {
            case .every:
                FlowLayout(spacing: 8) {
                    ForEach(everyPresets, id: \.self) { minutes in
                        ChoiceChip(title: presetTitle(minutes), isSelected: intervalMinutes == minutes) {
                            intervalMinutes = minutes
                        }
                    }
                }
                .padding(.vertical, 6)
                intervalStepper(title: CareFormat.interval(intervalMinutes))

            case .times:
                ForEach(times.indices, id: \.self) { index in
                    HStack {
                        DatePicker("Time \(index + 1)", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                        if times.count > 1 {
                            Button {
                                times.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(AppPalette.overdueText)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove time \(index + 1)")
                        }
                    }
                }
                if times.count < CareEngine.maximumTimesPerDay {
                    Button {
                        times.append(nextSuggestedTime())
                    } label: {
                        Label("Add a time", systemImage: "plus.circle.fill")
                    }
                }
                FlowLayout(spacing: 8) {
                    ChoiceChip(title: String(appLocalized: "Once a day"), isSelected: times == [540]) { times = [540] }
                    ChoiceChip(title: String(appLocalized: "Twice"), isSelected: times == [480, 1200]) { times = [480, 1200] }
                    ChoiceChip(title: String(appLocalized: "3 times"), isSelected: times == [480, 840, 1200]) { times = [480, 840, 1200] }
                }
                .padding(.vertical, 6)

            case .asNeeded:
                FlowLayout(spacing: 8) {
                    ForEach(gapPresets, id: \.self) { minutes in
                        ChoiceChip(title: String(appLocalized: "\(minutes / 60)h"), isSelected: intervalMinutes == minutes) {
                            intervalMinutes = minutes
                        }
                    }
                }
                .padding(.vertical, 6)
                intervalStepper(title: String(appLocalized: "At least \(CareFormat.duration(TimeInterval(intervalMinutes * 60))) apart"))
            }
        } header: {
            Text("Repeats")
        } footer: {
            switch repeatMode {
            case .every: Text("The next one is due this long after the last time it was done.")
            case .times: Text("Due every day at these times, even if one was given a little early or late.")
            case .asNeeded: Text("For things like fever medicine. No reminders. Today shows when it's OK to give again. Use the gap your doctor or the label gives.")
            }
        }
    }

    private var courseSection: some View {
        Section {
            Toggle("Ends on a set day", isOn: $hasEnd.animation())
            if hasEnd {
                FlowLayout(spacing: 8) {
                    ForEach(coursePresets, id: \.self) { days in
                        ChoiceChip(title: CareFormat.days(days), isSelected: isCourse(days)) {
                            lastDay = courseLastDay(days)
                        }
                    }
                }
                .padding(.vertical, 6)
                DatePicker("Last day", selection: $lastDay, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
            }
        } header: {
            Text("Course")
        } footer: {
            if hasEnd {
                Text("After the last day it moves to Finished in your care plan, and its history is kept.")
            }
        }
    }

    // MARK: Helpers

    private func intervalStepper(title: String) -> some View {
        Stepper(value: $intervalMinutes, in: CareEngine.minimumIntervalMinutes...CareEngine.maximumIntervalMinutes, step: 15) {
            Text(title)
                .font(.headline)
                .monospacedDigit()
        }
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = times.indices.contains(index) ? times[index] : 540
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                if times.indices.contains(index) { times[index] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
            }
        )
    }

    private func nextSuggestedTime() -> Int {
        let latest = times.max() ?? 480
        return min(latest + 240, 1380)
    }

    private func courseLastDay(_ days: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: days - 1, to: today) ?? today
    }

    private func isCourse(_ days: Int) -> Bool {
        Calendar.current.isDate(lastDay, inSameDayAs: courseLastDay(days))
    }

    private var endDate: Date? {
        guard hasEnd else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay))
    }

    private var schedule: CareSchedule {
        switch repeatMode {
        case .every: return .interval
        case .times: return .times(times)
        case .asNeeded: return .asNeeded
        }
    }

    /// For set times the interval isn't used for scheduling; keep a sensible value for display and storage.
    private var storedInterval: Int {
        if case .times(let times) = schedule, !times.isEmpty { return max(CareEngine.minimumIntervalMinutes, 1440 / times.count) }
        return intervalMinutes
    }

    private func presetTitle(_ minutes: Int) -> String {
        minutes == 1440 ? String(appLocalized: "Daily") : String(appLocalized: "\(minutes / 60)h")
    }

    private func apply(_ template: CareTemplate) {
        isCustom = false
        name = template.name
        symbol = template.symbol
        intervalMinutes = template.intervalMinutes
        if template.times.isEmpty {
            repeatMode = .every
        } else {
            repeatMode = .times
            times = template.times
        }
        SoundManager.shared.selection()
    }

    private func save() {
        do {
            if var item = editingItem {
                let wasStartable = canChooseStart
                item.name = name
                item.symbol = symbol
                item.schedule = schedule
                item.intervalMinutes = storedInterval
                item.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                item.remindersOn = remindersOn
                item.endDate = endDate
                item.snoozedUntil = nil
                if wasStartable {
                    item.firstDue = start == .dueAt ? startDate : Date()
                } else if case .times = schedule, CareEngine.latestEvent(for: item.id, in: vm.state) == nil {
                    item.firstDue = Date()
                }
                try vm.updateItem(item)
                if wasStartable, start == .doneAt { vm.complete(item.id, at: startDate) }
            } else {
                let item = CareItem(
                    kind: kind,
                    name: name,
                    symbol: symbol,
                    intervalMinutes: storedInterval,
                    schedule: schedule,
                    dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    remindersOn: remindersOn,
                    firstDue: canChooseStart && start == .dueAt ? startDate : Date(),
                    endDate: endDate
                )
                let doneAt = canChooseStart && start == .doneAt ? startDate : nil
                if let onCreate {
                    try CareEngine.validate(item, excluding: nil, in: draft ?? vm.state)
                    onCreate(item, doneAt)
                } else {
                    try vm.addItem(item, alreadyDoneAt: doneAt)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            SoundManager.shared.warning()
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
