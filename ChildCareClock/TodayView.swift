import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var vm: CareViewModel
    @AppStorage(AppPreferences.warningMinutes, store: AppPreferences.defaults) private var warningMinutes = AppPreferences.defaultWarningMinutes
    @State private var completing: CareItem?
    @State private var showingSettings = false
    @State private var addingItem = false
    @State private var showingVaccines = false

    let openPlan: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            TimelineView(.periodic(from: .now, by: 15)) { context in
                content(now: context.date)
            }
        }
        .sheet(item: $completing) { item in
            CompletionSheet(item: item)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $addingItem) {
            ItemEditorSheet(mode: .new(nil))
        }
        .sheet(isPresented: $showingVaccines) {
            NavigationStack {
                VaccinesView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingVaccines = false }
                        }
                    }
            }
        }
    }

    private func content(now: Date) -> some View {
        let schedule = CareEngine.schedule(for: vm.state, now: now)
        let asNeeded = CareEngine.asNeeded(for: vm.state, now: now)

        return List {
            header(now: now)
                .cardRow(top: 8, bottom: 10)

            // Vaccination visits show up here from a week before they're due.
            if let visit = VaccineEngine.nextVisit(in: vm.state), VaccineEngine.status(of: visit, now: now) != .upcoming {
                Button { showingVaccines = true } label: {
                    VaccineReminderRow(visit: visit, now: now)
                }
                .buttonStyle(.plain)
                .cardRow(bottom: 10)
            }

            if let next = schedule.first {
                HeroCard(
                    scheduled: next,
                    now: now,
                    warningMinutes: warningMinutes,
                    onDone: { vm.complete(next.item.id) },
                    onDoneEarlier: { completing = next.item },
                    onSnooze: { vm.snooze(next.item.id) }
                )
                .cardRow(bottom: 10)
                .contextMenu { actions(for: next.item) }
                .swipeActions(edge: .leading, allowsFullSwipe: true) { doneSwipe(next.item) }
                .swipeActions(edge: .trailing) { laterSwipes(next.item) }

                if schedule.count > 1 {
                    Text("LATER")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppPalette.secondaryText)
                        .cardRow(top: 10, bottom: 2)

                    ForEach(schedule.dropFirst()) { scheduled in
                        Button { completing = scheduled.item } label: {
                            ItemRow(scheduled: scheduled, now: now, warningMinutes: warningMinutes)
                        }
                        .buttonStyle(.plain)
                        .cardRow(top: 4, bottom: 4)
                        .contextMenu { actions(for: scheduled.item) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) { doneSwipe(scheduled.item) }
                        .swipeActions(edge: .trailing) { laterSwipes(scheduled.item) }
                    }
                }

            }

            if !asNeeded.isEmpty {
                Text("AS NEEDED")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppPalette.secondaryText)
                    .cardRow(top: 10, bottom: 2)

                ForEach(asNeeded) { entry in
                    Button { completing = entry.item } label: {
                        AsNeededRow(entry: entry, now: now)
                    }
                    .buttonStyle(.plain)
                    .cardRow(top: 4, bottom: 4)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) { doneSwipe(entry.item) }
                }
            }

            if !schedule.isEmpty {
                Text("Tap to log · swipe for snooze or skip")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .cardRow(top: 14, bottom: 24)
            } else if asNeeded.isEmpty {
                EmptyStateCard(
                    symbol: "list.bullet.clipboard",
                    title: "Nothing to track yet",
                    message: "Add feeds, naps, vitamins or anything else, and we'll remind you when each one is due.",
                    actionTitle: "Add to care plan",
                    action: { addingItem = true }
                )
                .cardRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// "Good morning," above "Vedika's Dad" (or the baby's name when no role is set).
    private func header(now: Date) -> some View {
        HStack(spacing: 14) {
            BabyAvatar(photo: vm.photo, name: vm.baby?.name ?? "", size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting(now) + ",")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppPalette.secondaryText)
                Text(vm.baby?.caregiverTitle ?? vm.baby?.name ?? "Baby")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.primaryDeep)
                    .frame(width: 44, height: 44)
                    .glassPanel(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private func greeting(_ now: Date) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    @ViewBuilder
    private func actions(for item: CareItem) -> some View {
        Button { vm.complete(item.id) } label: { Label("Done just now", systemImage: "checkmark.circle") }
        Button { completing = item } label: { Label("Done earlier…", systemImage: "clock") }
        Button { vm.snooze(item.id) } label: { Label("Snooze 15 min", systemImage: "clock.arrow.circlepath") }
        Button { vm.skip(item.id) } label: { Label("Skip this one", systemImage: "forward.end") }
    }

    private func doneSwipe(_ item: CareItem) -> some View {
        Button { vm.complete(item.id) } label: { Label("Done", systemImage: "checkmark") }
            .tint(AppPalette.done)
    }

    @ViewBuilder
    private func laterSwipes(_ item: CareItem) -> some View {
        Button { vm.skip(item.id) } label: { Label("Skip", systemImage: "forward.end") }
            .tint(AppPalette.secondaryText)
        Button { vm.snooze(item.id) } label: { Label("Snooze", systemImage: "clock.arrow.circlepath") }
            .tint(AppPalette.soon)
    }
}

/// The big "Next up" card: one large target for a tired parent.
private struct HeroCard: View {
    let scheduled: ScheduledItem
    let now: Date
    let warningMinutes: Int
    let onDone: () -> Void
    let onDoneEarlier: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        let item = scheduled.item
        let status = CareEngine.status(due: scheduled.due, now: now, warningMinutes: warningMinutes)
        let fraction = CareEngine.remainingFraction(for: item, due: scheduled.due, now: now)

        VStack(alignment: .leading, spacing: 18) {
            Text(label(status))
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(AppPalette.statusText(for: status))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppPalette.ring(for: status).opacity(0.18), in: Capsule())

            HStack(spacing: 18) {
                CountdownRing(fraction: fraction, status: status, lineWidth: 11) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(AppPalette.deepTint(for: item.kind))
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppPalette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(countdown(status))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(status == .upcoming ? AppPalette.primaryDeep : AppPalette.statusText(for: status))
                        .contentTransition(.numericText())
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onSnooze) {
                    Label("Snooze", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(SoftButtonStyle())
                .frame(maxWidth: 140)
            }

            Button(action: onDoneEarlier) {
                Text("Done earlier? Pick the time")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.primaryDeep)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.plain)
            .padding(.top, -8)
        }
        .padding(20)
        .glassPanel(cornerRadius: 26)
        .overlay {
            if status == .overdue {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppPalette.overdue.opacity(0.6), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.name), \(CareFormat.relative(due: scheduled.due, now: now))")
    }

    private func label(_ status: CareStatus) -> String {
        switch status {
        case .upcoming: return "NEXT UP"
        case .dueSoon: return "DUE SOON"
        case .overdue: return "OVERDUE"
        }
    }

    private func countdown(_ status: CareStatus) -> String {
        let remaining = scheduled.due.timeIntervalSince(now)
        if abs(remaining) < 60 { return "Due now" }
        return remaining > 0 ? "in \(CareFormat.duration(remaining))" : "\(CareFormat.duration(remaining)) late"
    }

    private var detail: String {
        let item = scheduled.item
        var parts: [String] = []
        if !item.dosage.isEmpty { parts.append(item.dosage) }
        parts.append("due \(dueText)")
        return parts.joined(separator: " · ")
    }

    private var dueText: String {
        let calendar = Calendar.current
        if calendar.isDate(scheduled.due, inSameDayAs: now) { return scheduled.due.shortTime }
        if calendar.isDateInTomorrow(scheduled.due) { return "tomorrow \(scheduled.due.shortTime)" }
        if calendar.isDateInYesterday(scheduled.due) { return "yesterday \(scheduled.due.shortTime)" }
        return scheduled.due.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

struct ItemRow: View {
    let scheduled: ScheduledItem
    let now: Date
    let warningMinutes: Int

    var body: some View {
        let item = scheduled.item
        let status = CareEngine.status(due: scheduled.due, now: now, warningMinutes: warningMinutes)

        HStack(spacing: 14) {
            SymbolBadge(symbol: item.symbol, kind: item.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                Text(item.dosage.isEmpty ? CareFormat.schedule(item) : item.dosage)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(CareFormat.relative(due: scheduled.due, now: now))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(status == .upcoming ? AppPalette.text : AppPalette.statusText(for: status))
                Text(scheduled.due.shortTime)
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
            }
            CountdownRing(fraction: CareEngine.remainingFraction(for: item, due: scheduled.due, now: now), status: status, lineWidth: 4)
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens logging options")
    }
}

/// An as-needed item: when it was last given and whether it's OK to give again.
struct AsNeededRow: View {
    let entry: AsNeededItem
    let now: Date

    var body: some View {
        let item = entry.item
        HStack(spacing: 14) {
            SymbolBadge(symbol: item.symbol, kind: item.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                Text(lastGivenText)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let okAfter = entry.okAfter {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Wait until")
                        .font(.caption)
                        .foregroundStyle(AppPalette.soonText)
                    Text(okAfter.shortTime)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.soonText)
                }
            } else {
                Label("OK to give", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.doneText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens logging options")
    }

    private var lastGivenText: String {
        guard let last = entry.lastGiven else {
            return entry.item.dosage.isEmpty ? "Not given yet" : "\(entry.item.dosage) · not given yet"
        }
        return "Last given \(CareFormat.duration(now.timeIntervalSince(last))) ago"
    }
}

private struct VaccineReminderRow: View {
    let visit: VaccineVisit
    let now: Date

    var body: some View {
        let overdue = VaccineEngine.status(of: visit, now: now) == .overdue
        HStack(spacing: 14) {
            SymbolBadge(symbol: "syringe.fill", kind: .medicine, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(visit.title) vaccines")
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                Text("\(VaccineEngine.dueText(for: visit, now: now)) · \(CareEngine.plural(visit.remaining.count, "vaccine"))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(overdue ? AppPalette.overdueText : AppPalette.soonText)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
