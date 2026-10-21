import SwiftUI

/// Soft palette for the Watch (always dark).
enum WatchPalette {
    static let primary = Color(red: 0.70, green: 0.66, blue: 1.0)
    static let medicine = Color(red: 0.83, green: 0.79, blue: 1.0)
    static let care = Color(red: 0.61, green: 0.89, blue: 0.85)
    static let done = Color(red: 0.62, green: 0.89, blue: 0.74)
    static let soon = Color(red: 0.95, green: 0.80, blue: 0.55)
    static let overdue = Color(red: 0.96, green: 0.65, blue: 0.62)

    static func tint(for kind: CareKind) -> Color { kind == .medicine ? medicine : care }
}

struct WatchContentView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                list(now: context.date)
            }
            .navigationTitle(store.state.baby?.caregiverTitle ?? store.state.baby?.name ?? "Care Clock")
        }
        .tint(WatchPalette.primary)
    }

    @ViewBuilder
    private func list(now: Date) -> some View {
        let schedule = CareEngine.schedule(for: store.state, now: now)
        let asNeeded = CareEngine.asNeeded(for: store.state, now: now)

        if !store.state.isSetUp {
            VStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundStyle(WatchPalette.primary)
                Text("Open Baby Care Clock on your iPhone to get started.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        } else if schedule.isEmpty && asNeeded.isEmpty {
            Text("Nothing scheduled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            List {
                if let next = schedule.first {
                    Section {
                        NextUpCard(scheduled: next, now: now)
                    }
                }
                if schedule.count > 1 {
                    Section("Later") {
                        ForEach(schedule.dropFirst()) { scheduled in
                            NavigationLink {
                                WatchItemView(item: scheduled.item)
                            } label: {
                                WatchRow(item: scheduled.item, detail: CareFormat.relative(due: scheduled.due, now: now), detailColor: scheduled.due <= now ? WatchPalette.overdue : .secondary)
                            }
                            .swipeActions(edge: .leading) {
                                Button { store.complete(scheduled.item.id) } label: { Label("Done", systemImage: "checkmark") }
                                    .tint(WatchPalette.done)
                            }
                        }
                    }
                }
                if !asNeeded.isEmpty {
                    Section("As needed") {
                        ForEach(asNeeded) { entry in
                            NavigationLink {
                                WatchItemView(item: entry.item)
                            } label: {
                                WatchRow(
                                    item: entry.item,
                                    detail: entry.okAfter.map { "Wait until \($0.formatted(date: .omitted, time: .shortened))" } ?? "OK to give",
                                    detailColor: entry.okAfter == nil ? WatchPalette.done : WatchPalette.soon
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NextUpCard: View {
    @EnvironmentObject private var store: WatchStore
    let scheduled: ScheduledItem
    let now: Date

    var body: some View {
        let item = scheduled.item
        let overdue = scheduled.due <= now
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.title3)
                    .foregroundStyle(WatchPalette.tint(for: item.kind))
                VStack(alignment: .leading, spacing: 0) {
                    Text(overdue ? "OVERDUE" : "NEXT UP")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(overdue ? WatchPalette.overdue : .secondary)
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                }
            }
            Group {
                if overdue {
                    Text(CareFormat.relative(due: scheduled.due, now: now))
                } else {
                    Text(timerInterval: now...scheduled.due, countsDown: true)
                }
            }
            .font(.system(.title2, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(overdue ? WatchPalette.overdue : WatchPalette.primary)

            Button { store.complete(item.id) } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchPalette.primary)
            .foregroundStyle(.black)

            Button("Snooze 15 min") { store.snooze(item.id) }
                .font(.footnote)
        }
        .padding(.vertical, 4)
    }
}

private struct WatchRow: View {
    let item: CareItem
    let detail: String
    let detailColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .foregroundStyle(WatchPalette.tint(for: item.kind))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(detailColor)
            }
        }
    }
}

private struct WatchItemView: View {
    @EnvironmentObject private var store: WatchStore
    @Environment(\.dismiss) private var dismiss
    let item: CareItem

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(WatchPalette.tint(for: item.kind))
                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if !item.dosage.isEmpty {
                    Text(item.dosage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.complete(item.id)
                    dismiss()
                } label: {
                    Label("Done now", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPalette.primary)
                .foregroundStyle(.black)
                if !item.schedule.isAsNeeded {
                    Button("Snooze 15 min") {
                        store.snooze(item.id)
                        dismiss()
                    }
                }
            }
        }
    }
}
