import SwiftUI

/// "When was it done?" Quick backdating choices, an exact-time picker and an optional note.
struct CompletionSheet: View {
    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    let item: CareItem

    @State private var minutesAgo: Int? = 0
    @State private var customDate = Date()
    @State private var note = ""

    private let quickChoices: [(String, Int)] = [
        (String(appLocalized: "Just now"), 0),
        (String(appLocalized: "5 min ago"), 5),
        (String(appLocalized: "15 min"), 15),
        (String(appLocalized: "30 min"), 30),
        (String(appLocalized: "1 hour"), 60),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        SymbolBadge(symbol: item.symbol, kind: item.kind, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppPalette.text)
                            Text(item.dosage.isEmpty ? CareFormat.schedule(item) : "\(item.dosage) · \(CareFormat.schedule(item))")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                    }

                    if let warning = gapWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.soonText)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppPalette.soon.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(item.schedule.isAsNeeded ? "When was it given?" : "When was it done?")
                        FlowLayout(spacing: 8) {
                            ForEach(quickChoices, id: \.1) { title, minutes in
                                ChoiceChip(title: title, isSelected: minutesAgo == minutes) {
                                    minutesAgo = minutes
                                    SoundManager.shared.selection()
                                }
                            }
                            ChoiceChip(title: String(appLocalized: "Other time"), symbol: "calendar", isSelected: minutesAgo == nil) {
                                minutesAgo = nil
                                SoundManager.shared.selection()
                            }
                        }
                        if minutesAgo == nil {
                            DatePicker("Time", selection: $customDate, in: Date().addingTimeInterval(-7 * 86_400)...Date(), displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .glassPanel(cornerRadius: 18)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Note (optional)")
                        TextField(notePlaceholder, text: $note, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(14)
                            .glassPanel(cornerRadius: 16)
                    }

                    Button("Save") { save() }
                        .buttonStyle(PrimaryButtonStyle())

                    if !item.schedule.isAsNeeded {
                    HStack(spacing: 10) {
                        Button {
                            vm.snooze(item.id)
                            dismiss()
                        } label: {
                            Label("Snooze 15 min", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(SoftButtonStyle())
                        Button {
                            vm.skip(item.id)
                            dismiss()
                        } label: {
                            Label("Skip", systemImage: "forward.end")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                    }
                }
                .padding(20)
                .animation(.snappy, value: minutesAgo)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// For as-needed medicine: a gentle warning when the minimum gap hasn't passed yet.
    private var gapWarning: String? {
        guard item.schedule.isAsNeeded, let last = CareEngine.latestEvent(for: item.id, in: vm.state)?.date else { return nil }
        let allowed = last.addingTimeInterval(item.interval)
        guard allowed > Date() else { return nil }
        return String(appLocalized: "Last given \(CareFormat.duration(Date().timeIntervalSince(last))) ago. The minimum gap is \(CareFormat.duration(item.interval)), so wait until \(allowed.shortTime) unless your doctor says otherwise.")
    }

    private var notePlaceholder: String {
        // Match ready-made items in any language by their English name.
        let key = CareTemplate.all.first { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }?.key ?? item.name
        switch key.lowercased() {
        case let name where name.contains("feed"): return String(appLocalized: "e.g. Left side, 15 min")
        case let name where name.contains("diaper"): return String(appLocalized: "e.g. Wet and dirty")
        case let name where name.contains("nap") || name.contains("sleep"): return String(appLocalized: "e.g. Slept 1h 20m")
        default: return String(appLocalized: "Anything worth remembering")
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppPalette.secondaryText)
    }

    private func save() {
        let date = minutesAgo.map { Date().addingTimeInterval(TimeInterval(-$0 * 60)) } ?? customDate
        vm.complete(item.id, at: date, note: note)
        dismiss()
    }
}

/// Edit or delete something already logged.
struct EditEventSheet: View {
    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    let event: CareEvent
    let item: CareItem

    @State private var date: Date
    @State private var note: String
    @State private var confirmingDelete = false

    init(event: CareEvent, item: CareItem) {
        self.event = event
        self.item = item
        _date = State(initialValue: event.date)
        _note = State(initialValue: event.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        SymbolBadge(symbol: item.symbol, kind: item.kind)
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            Text(event.kind == .done ? "Done" : "Skipped")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                    }
                }
                Section("Time") {
                    if event.kind == .done {
                        DatePicker("Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    } else {
                        DatePicker("Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section {
                    Button("Delete entry", role: .destructive) { confirmingDelete = true }
                }
            }
            .softFormBackground()
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.updateEvent(event.id, date: date, note: note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    vm.deleteEvent(event.id)
                    dismiss()
                }
            } message: {
                Text("The next due time for \(item.name) will be recalculated.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Wraps children onto new lines, like text. Used for chip groups.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
