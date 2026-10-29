import SwiftUI

struct CarePlanView: View {
    @EnvironmentObject private var vm: CareViewModel
    @State private var editorMode: ItemEditorSheet.Mode?
    @State private var deleting: CareItem?
    @State private var showingVaccines = false
    @AppStorage("carePlanOpenSections") private var openSections = ""

    var body: some View {
        NavigationStack {
            List {
                if vm.state.items.isEmpty {
                    EmptyStateCard(
                        symbol: "list.bullet.clipboard",
                        title: "Your care plan is empty",
                        message: "Add the feeds, naps, vitamins and medicines you want reminders for.",
                        actionTitle: "Add something",
                        action: { editorMode = .new(nil) }
                    )
                    .cardRow(top: 12)
                }

                SectionToggle(title: String(appLocalized: "Vaccinations"), isOpen: isOpen(Self.vaccinesSection)) { toggle(Self.vaccinesSection) }
                    .cardRow(top: 10, bottom: 2)
                if isOpen(Self.vaccinesSection) {
                    Button { showingVaccines = true } label: {
                        VaccinesRow(next: VaccineEngine.nextVisit(in: vm.state), isSetUp: !vm.state.vaccines.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .cardRow(top: 4, bottom: 4)
                }

                let finished = CareEngine.finished(for: vm.state)
                let finishedIDs = Set(finished.map(\.id))
                ForEach([CareKind.care, .medicine]) { kind in
                    let items = vm.state.items.filter { $0.kind == kind && !finishedIDs.contains($0.id) }.sorted { $0.name < $1.name }
                    if !items.isEmpty {
                        SectionToggle(title: kind.sectionTitle, isOpen: isOpen(kind.rawValue)) { toggle(kind.rawValue) }
                            .cardRow(top: 10, bottom: 2)
                        if isOpen(kind.rawValue) {
                            ForEach(items) { item in
                                planRow(item, isFinished: false)
                            }
                        }
                    }
                }

                if !finished.isEmpty {
                    Section {
                        ForEach(finished) { item in
                            planRow(item, isFinished: true)
                        }
                    } header: {
                        Text("FINISHED")
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(AppPalette.secondaryText)
                            .padding(.leading, 4)
                    }
                    .listSectionSeparator(.hidden)
                }

                if !vm.state.items.isEmpty {
                    Text("Tap any item to change its name, times or dosage.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .cardRow(top: 12, bottom: 40)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Care Plan")
            .navigationDestination(isPresented: $showingVaccines) { VaccinesView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editorMode = .new(nil) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add to care plan")
                }
            }
            .sheet(item: $editorMode) { mode in
                ItemEditorSheet(mode: mode)
            }
            .confirmationDialog(
                "Delete \(deleting?.name ?? "")?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { item in
                Button("Delete", role: .destructive) { vm.deleteItem(item.id) }
            } message: { _ in
                Text("Its reminders and history will be removed too.")
            }
        }
    }
}

extension CarePlanView {
    static let vaccinesSection = "vaccines"

    /// Which sections are open, remembered between visits. All start closed.
    func isOpen(_ id: String) -> Bool { openSections.split(separator: ",").contains(Substring(id)) }

    func toggle(_ id: String) {
        var ids = Set(openSections.split(separator: ",").map(String.init))
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        withAnimation(.snappy) { openSections = ids.sorted().joined(separator: ",") }
        SoundManager.shared.selection()
    }

    func planRow(_ item: CareItem, isFinished: Bool) -> some View {
        Button { editorMode = .edit(item) } label: {
            PlanRow(item: item, due: CareEngine.nextDue(for: item, in: vm.state), isFinished: isFinished)
        }
        .buttonStyle(.plain)
        .cardRow(top: 4, bottom: 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleting = item } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// A section heading that opens or closes its section, like a drop-down.
private struct SectionToggle: View {
    let title: String
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(AppPalette.secondaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }
}

private struct PlanRow: View {
    let item: CareItem
    let due: Date
    let isFinished: Bool

    var body: some View {
        HStack(spacing: 14) {
            SymbolBadge(symbol: item.symbol, kind: item.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                Text([CareFormat.schedule(item), item.dosage].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isFinished {
                Text("Done")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.doneText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppPalette.done.opacity(0.2), in: Capsule())
            } else if !item.schedule.isAsNeeded {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppPalette.secondaryText)
                    Text(due.shortTime)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.text)
                }
            }
            if !item.remindersOn && !item.schedule.isAsNeeded && !isFinished {
                Image(systemName: "bell.slash.fill")
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
                    .accessibilityLabel("Reminders off")
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.secondaryText.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 20)
        .opacity(isFinished ? 0.7 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct VaccinesRow: View {
    let next: VaccineVisit?
    let isSetUp: Bool

    var body: some View {
        HStack(spacing: 14) {
            SymbolBadge(symbol: "syringe.fill", kind: .medicine, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vaccinations")
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryText)
                    .lineLimit(1)
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

    private var subtitle: String {
        guard isSetUp else { return String(appLocalized: "Set up the schedule and reminders") }
        guard let next else { return String(appLocalized: "All vaccines given") }
        return String(appLocalized: "Next: \(next.displayTitle) · \(next.dueDate.formatted(.dateTime.locale(AppLanguage.locale).day().month(.abbreviated)))")
    }
}
