import PhotosUI
import SwiftUI

struct VaccinesView: View {
    @EnvironmentObject private var vm: CareViewModel
    @State private var editing: VaccineDose?
    @State private var adding = false
    @State private var confirmingReset = false

    var body: some View {
        Group {
            if vm.state.vaccines.isEmpty {
                VaccineSetupView()
            } else {
                list
            }
        }
        .background(AppBackground())
        .navigationTitle("Vaccinations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.state.vaccines.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { adding = true } label: { Label("Add a vaccine", systemImage: "plus") }
                        Button(role: .destructive) { confirmingReset = true } label: { Label("Start over", systemImage: "arrow.counterclockwise") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .sheet(item: $editing) { dose in
            VaccineEditSheet(dose: dose)
        }
        .sheet(isPresented: $adding) {
            AddVaccineSheet()
        }
        .confirmationDialog("Start the vaccination list over?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Start over", role: .destructive) {
                vm.startVaccines(nil, birthDate: vm.baby?.birthDate ?? Date(), markPastAsGiven: false)
            }
        } message: {
            Text("This clears every vaccine and date you've recorded here.")
        }
    }

    private var list: some View {
        let now = Date()
        let visits = VaccineEngine.visits(for: vm.state.vaccines)
        return List {
            if let next = visits.first(where: { !$0.isComplete }) {
                NextVisitCard(visit: next, now: now) { vm.setVisitGiven(next, on: now) }
                    .cardRow(top: 8, bottom: 10)
            } else {
                EmptyStateCard(symbol: "checkmark.seal.fill", title: "All done", message: "Every vaccine on the list has been given. Wonderful!")
                    .cardRow(top: 8)
            }

            ForEach(visits) { visit in
                Section {
                    ForEach(visit.doses) { dose in
                        DoseRow(dose: dose) {
                            vm.setVaccineGiven(dose.id, on: dose.givenDate == nil ? Date() : nil)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = dose }
                        .cardRow(top: 2, bottom: 2)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { vm.deleteVaccine(dose.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    VisitHeader(visit: visit, now: now)
                }
                .listSectionSeparator(.hidden)
            }

            Text("Based on the IAP schedule. Your pediatrician may advise different timing or extra vaccines, so always follow their card. Tap a vaccine to change its date or add a note.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .cardRow(top: 16, bottom: 40)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

/// First-time setup: pick a schedule and confirm the birth date.
private struct VaccineSetupView: View {
    @EnvironmentObject private var vm: CareViewModel
    @State private var birthDate = Date()
    @State private var markPast = true
    @State private var useSchedule = true
    @State private var scanning = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var reading = false
    @State private var scanned: [ScannedVaccine]?
    @State private var nothingFound = false
    @State private var scanUnavailable = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "syringe.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppPalette.primary)
                    .frame(width: 96, height: 96)
                    .background(AppPalette.primary.opacity(0.12), in: Circle())
                    .padding(.top, 16)
                Text("Never miss a vaccine")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.text)
                Text(setupMessage)
                    .font(.body)
                    .foregroundStyle(AppPalette.secondaryText)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    Picker("List", selection: $useSchedule) {
                        Text("India (IAP)").tag(true)
                        Text("My own list").tag(false)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    if useSchedule {
                        Toggle("Mark past vaccines as given", isOn: $markPast)
                        Text("Turn this off if some earlier vaccines were missed, so they show as due.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                }
                .padding(18)
                .glassPanel()

                if useSchedule {
                    Button("Create schedule") { start() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    if reading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading the card…")
                        }
                        .font(.headline)
                        .foregroundStyle(AppPalette.primaryDeep)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    } else {
                        HStack(spacing: 10) {
                            Button {
                                if DocumentScanner.isAvailable { scanning = true } else { scanUnavailable = true }
                            } label: {
                                Label("Take a photo", systemImage: "camera.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                                Label("Upload a photo", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        Button("Enter manually") { start() }
                            .buttonStyle(SoftButtonStyle())
                    }
                }

                Text("Based on the Indian Academy of Pediatrics (IAP) schedule. It isn't medical advice; your pediatrician's card always comes first, and every date can be changed.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .onAppear { birthDate = vm.baby?.birthDate ?? Date() }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { images in
                scanning = false
                read(images)
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .sheet(item: Binding(get: { scanned.map(ScanResult.init) }, set: { if $0 == nil { scanned = nil } })) { result in
            ScanReviewSheet(vaccines: result.vaccines) { checked in
                vm.addScannedVaccines(checked, birthDate: birthDate)
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            reading = true
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { images.append(image) }
                }
                photoItems = []
                read(images)
            }
        }
        .alert("Couldn't read the card", isPresented: $nothingFound) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No vaccine names were found. Try again in good light, or enter them manually.")
        }
        .alert("Scanning isn't available on this iPhone.", isPresented: $scanUnavailable) {
            Button("OK", role: .cancel) {}
        }
    }

    private struct ScanResult: Identifiable {
        let vaccines: [ScannedVaccine]
        let id = UUID()
    }

    private func read(_ images: [UIImage]) {
        reading = true
        Task {
            let found = await VaccineCardReader.read(images)
            reading = false
            if found.isEmpty { nothingFound = true } else { scanned = found }
        }
    }

    private var setupMessage: String {
        if let name = vm.baby?.name {
            return String(appLocalized: "We'll work out each due date from \(name)'s birth date and remind you 3 days before and on the day.")
        }
        return String(appLocalized: "We'll work out each due date from your baby's birth date and remind you 3 days before and on the day.")
    }

    private func start() {
        if useSchedule {
            vm.startVaccines(.india, birthDate: birthDate, markPastAsGiven: markPast)
        } else {
            if vm.baby?.birthDate == nil, var baby = vm.baby {
                baby.birthDate = birthDate
                vm.updateBaby(baby)
            }
            vm.addVaccine(name: String(appLocalized: "First vaccine"), dueDate: birthDate)
        }
    }
}

struct NextVisitCard: View {
    let visit: VaccineVisit
    let now: Date
    let onAllGiven: () -> Void

    var body: some View {
        let status = VaccineEngine.status(of: visit, now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "syringe.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppPalette.medicineDeep)
                    .frame(width: 52, height: 52)
                    .background(AppPalette.medicine.opacity(0.28), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT VISIT · \(visit.displayTitle.uppercased())")
                        .font(.caption.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(AppPalette.secondaryText)
                    Text(VaccineEngine.dueText(for: visit, now: now))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(status == .overdue ? AppPalette.overdueText : AppPalette.text)
                    Text(verbatim: "\(visit.dueDate.formatted(.dateTime.locale(AppLanguage.locale).weekday(.wide).day().month(.wide))) · \(CareFormat.vaccines(visit.remaining.count))")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.secondaryText)
                }
            }
            if status != .upcoming {
                Button(action: onAllGiven) {
                    Label("All given today", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }
}

private struct VisitHeader: View {
    let visit: VaccineVisit
    let now: Date

    var body: some View {
        let status = VaccineEngine.status(of: visit, now: now)
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(visit.displayTitle)
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                Text(visit.dueDate.formatted(.dateTime.locale(AppLanguage.locale).day().month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundStyle(AppPalette.secondaryText)
            }
            Spacer()
            Text(label(status))
                .font(.caption.weight(.bold))
                .foregroundStyle(color(status))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color(status).opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .textCase(nil)
    }

    private func label(_ status: VaccineVisit.Status) -> String {
        switch status {
        case .given: return String(appLocalized: "Done")
        case .overdue: return String(appLocalized: "Overdue")
        case .dueSoon: return VaccineEngine.dueText(for: visit, now: now)
        case .upcoming: return String(appLocalized: "Upcoming")
        }
    }

    private func color(_ status: VaccineVisit.Status) -> Color {
        switch status {
        case .given: return AppPalette.doneText
        case .overdue: return AppPalette.overdueText
        case .dueSoon: return AppPalette.soonText
        case .upcoming: return AppPalette.secondaryText
        }
    }
}

private struct DoseRow: View {
    let dose: VaccineDose
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: dose.givenDate == nil ? "circle" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(dose.givenDate == nil ? AppPalette.secondaryText.opacity(0.6) : AppPalette.done)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dose.givenDate == nil ? "Mark \(dose.name) as given" : "Mark \(dose.name) as not given")

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.text)
                    .strikethrough(false)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .glassPanel(cornerRadius: 16)
        .opacity(dose.givenDate == nil ? 1 : 0.75)
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let given = dose.givenDate { parts.append(String(appLocalized: "Given \(given.formatted(.dateTime.locale(AppLanguage.locale).day().month(.abbreviated)))")) }
        if !dose.note.isEmpty { parts.append(dose.note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct VaccineEditSheet: View {
    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var dose: VaccineDose
    @State private var isGiven: Bool
    @State private var givenDate: Date

    init(dose: VaccineDose) {
        _dose = State(initialValue: dose)
        _isGiven = State(initialValue: dose.givenDate != nil)
        _givenDate = State(initialValue: dose.givenDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vaccine") {
                    TextField("Name", text: $dose.name)
                    DatePicker("Due", selection: $dose.dueDate, displayedComponents: .date)
                }
                Section {
                    Toggle("Given", isOn: $isGiven)
                    if isGiven {
                        DatePicker("On", selection: $givenDate, in: ...Date(), displayedComponents: .date)
                    }
                    TextField("Note (hospital, batch no.)", text: $dose.note, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    Button("Delete vaccine", role: .destructive) {
                        vm.deleteVaccine(dose.id)
                        dismiss()
                    }
                }
            }
            .softFormBackground()
            .navigationTitle(dose.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dose.givenDate = isGiven ? givenDate : nil
                        vm.updateVaccine(dose)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AddVaccineSheet: View {
    @EnvironmentObject private var vm: CareViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Vaccine name", text: $name)
                    .textInputAutocapitalization(.words)
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
            }
            .softFormBackground()
            .navigationTitle("Add a vaccine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        vm.addVaccine(name: name, dueDate: dueDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
