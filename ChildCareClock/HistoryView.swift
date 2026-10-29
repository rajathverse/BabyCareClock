import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var vm: CareViewModel
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var editing: EditTarget?
    @State private var pickingDate = false

    private struct EditTarget: Identifiable {
        let event: CareEvent
        let item: CareItem
        var id: UUID { event.id }
    }

    /// How far back the day strip goes.
    private let dayCount = 60

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                list(now: context.date)
            }
            .background(AppBackground())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { pickingDate = true } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Choose a date")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    shareMenu
                }
            }
            .sheet(item: $editing) { target in
                EditEventSheet(event: target.event, item: target.item)
            }
            .sheet(isPresented: $pickingDate) {
                datePickerSheet
            }
        }
    }

    private func list(now: Date) -> some View {
        let entries = CareEngine.timeline(for: selectedDay, in: vm.state, now: now)
        let logged = entries.filter { $0.kind == .done || $0.kind == .skipped }

        return List {
            dayStrip(now: now)
                .cardRow(top: 4, bottom: 8)
                .listRowInsets(EdgeInsets())

            if !logged.isEmpty {
                DaySummary(entries: logged)
                    .cardRow(bottom: 10)
            }

            if entries.isEmpty {
                EmptyStateCard(
                    symbol: "moon.stars.fill",
                    title: "Nothing logged",
                    message: Calendar.current.isDateInToday(selectedDay)
                        ? "Things you mark as done today will appear here."
                        : "Nothing was logged on this day."
                )
                .cardRow()
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    TimelineRow(entry: entry, isFirst: index == 0, isLast: index == entries.count - 1, now: now)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let id = entry.eventID, let event = vm.state.events.first(where: { $0.id == id }) {
                                editing = EditTarget(event: event, item: entry.item)
                            }
                        }
                        .cardRow(top: 0, bottom: 0)
                        .swipeActions(edge: .trailing) {
                            if let id = entry.eventID {
                                Button(role: .destructive) { vm.deleteEvent(id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
                Color.clear.frame(height: 40).cardRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dayStrip(now: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = (0..<dayCount).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let loggedDays = Set(vm.state.events.map { calendar.startOfDay(for: $0.date) })

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        DayChip(
                            day: day,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                            isToday: calendar.isDate(day, inSameDayAs: today),
                            hasLogs: loggedDays.contains(day)
                        ) {
                            selectedDay = day
                            SoundManager.shared.selection()
                        }
                        .id(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onAppear { proxy.scrollTo(selectedDay, anchor: .trailing) }
            .onChange(of: selectedDay) { _, day in
                withAnimation { proxy.scrollTo(day, anchor: .center) }
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Day", selection: Binding(
                get: { selectedDay },
                set: { selectedDay = Calendar.current.startOfDay(for: $0) }
            ), in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Go to day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { pickingDate = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var shareMenu: some View {
        let report = CareReport(day: selectedDay, state: vm.state, now: Date())
        Menu {
            ShareLink(item: report.text, subject: Text(report.title), preview: SharePreview(report.title)) {
                Label("Share as text", systemImage: "text.alignleft")
            }
            if let image = report.image() {
                ShareLink(item: image, preview: SharePreview(report.title, image: image)) {
                    Label("Share as image", systemImage: "photo")
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share this day")
    }
}

private struct DayChip: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let hasLogs: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(isToday ? String(appLocalized: "Today") : day.formatted(.dateTime.locale(AppLanguage.locale).weekday(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                Text(day.formatted(.dateTime.locale(AppLanguage.locale).day()))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Circle()
                    .fill(hasLogs ? (isSelected ? AppPalette.onPrimary : AppPalette.done) : .clear)
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(isSelected ? AppPalette.onPrimary : AppPalette.text)
            .frame(width: 54, height: 72)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppPalette.primary.gradient)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: AppLanguage.locale)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Count per item for the day, e.g. "Feed ×6".
private struct DaySummary: View {
    let entries: [CareTimelineEntry]

    private struct ItemCount {
        let item: CareItem
        let count: Int
    }

    private var counts: [ItemCount] {
        let grouped = Dictionary(grouping: entries.filter { $0.kind == .done }) { (entry: CareTimelineEntry) in entry.item.id }
        let counts: [ItemCount] = grouped.values.map { ItemCount(item: $0[0].item, count: $0.count) }
        return counts.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.item.name < rhs.item.name : lhs.count > rhs.count
        }
    }

    var body: some View {
        let done = entries.filter { $0.kind == .done }
        let counts = counts

        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: summaryText(done: done.count))
                .font(.headline)
                .foregroundStyle(AppPalette.text)
            if !counts.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(counts, id: \.item.id) { entry in
                        HStack(spacing: 5) {
                            Image(systemName: entry.item.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.deepTint(for: entry.item.kind))
                            Text(verbatim: "\(entry.item.name) ×\(entry.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.text)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppPalette.tint(for: entry.item.kind).opacity(0.2), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func summaryText(done: Int) -> String {
        let skipped = entries.filter { $0.kind == .skipped }.count
        let doneText = String(appLocalized: "\(done) done")
        return skipped > 0 ? doneText + " · " + String(appLocalized: "\(skipped) skipped") : doneText
    }
}

private struct TimelineRow: View {
    let entry: CareTimelineEntry
    let isFirst: Bool
    let isLast: Bool
    let now: Date

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(entry.date.shortTime)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .planned ? AppPalette.secondaryText : AppPalette.text)
                .frame(width: 74, alignment: .trailing)

            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(isFirst ? .clear : lineColor).frame(width: 2)
                    Rectangle().fill(isLast ? .clear : lineColor).frame(width: 2)
                }
                dot
            }
            .frame(width: 16)

            HStack(spacing: 12) {
                SymbolBadge(symbol: entry.item.symbol, kind: entry.item.kind, size: 36)
                    .opacity(entry.kind == .planned ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.item.name)
                        .font(.headline)
                        .foregroundStyle(entry.kind == .planned ? AppPalette.secondaryText : AppPalette.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(subtitleColor)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                if entry.kind != .planned {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var lineColor: Color { AppPalette.primary.opacity(0.25) }

    @ViewBuilder
    private var dot: some View {
        switch entry.kind {
        case .done:
            Circle().fill(AppPalette.done).frame(width: 12, height: 12)
        case .skipped:
            Circle().fill(AppPalette.secondaryText.opacity(0.5)).frame(width: 12, height: 12)
        case .overdue:
            Circle().fill(AppPalette.overdue).frame(width: 12, height: 12)
        case .planned:
            Circle().stroke(AppPalette.primary, lineWidth: 2).frame(width: 11, height: 11)
        }
    }

    private var subtitle: String? {
        switch entry.kind {
        case .done:
            let parts = [entry.note, entry.item.dosage].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .skipped:
            return String(appLocalized: "Skipped")
        case .overdue:
            return String(appLocalized: "Overdue · \(CareFormat.duration(now.timeIntervalSince(entry.date))) late")
        case .planned:
            return String(appLocalized: "Planned")
        }
    }

    private var subtitleColor: Color {
        entry.kind == .overdue ? AppPalette.overdueText : AppPalette.secondaryText
    }
}
