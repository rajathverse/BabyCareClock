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
    @State private var selected: Set<String> = ["Feed", "Diaper change", "Vitamin D3"]
    @FocusState private var nameFocused: Bool
    @State private var confirmingFreshStart = false

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
                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .confirmationDialog("Start fresh?", isPresented: $confirmingFreshStart, titleVisibility: .visible) {
            Button("Delete old data and start fresh", role: .destructive) {
                vm.discardBackup()
                go(.baby)
            }
        } message: {
            Text("The data from before can't be brought back afterwards.")
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
        }
    }

    private func restoreCard(_ backup: CareState) -> some View {
        let name = backup.baby?.name ?? "your baby"
        let items = CareEngine.plural(backup.items.count, "item")
        let since = backup.events.map(\.date).min()
        return VStack(alignment: .leading, spacing: 10) {
            Label("Welcome back", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.headline)
                .foregroundStyle(AppPalette.primaryDeep)
            Text("We found \(name)'s data from before you reinstalled the app: \(items) in the care plan\(since.map { ", with history since \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "").")
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
            title("What would you like to track?", subtitle: "Pick a few to start. You can change times and add your own later.")
            ForEach(CareKind.allCases) { kind in
                VStack(alignment: .leading, spacing: 10) {
                    Text(kind.sectionTitle.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(AppPalette.secondaryText)
                    FlowLayout(spacing: 8) {
                        ForEach(CareTemplate.templates(for: kind)) { template in
                            ChoiceChip(title: template.name, symbol: template.symbol, isSelected: selected.contains(template.name)) {
                                if selected.contains(template.name) {
                                    selected.remove(template.name)
                                } else {
                                    selected.insert(template.name)
                                }
                                SoundManager.shared.selection()
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()
            }
            Text("Each one starts counting from now. Feeds and diapers repeat every 3 hours, vitamins once a day.")
                .font(.footnote)
                .foregroundStyle(AppPalette.secondaryText)
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
                    Button(backup.baby.map { "Restore \($0.name)'s data" } ?? "Restore my data") { vm.restoreBackup() }
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
                Button(selected.isEmpty ? "Skip for now" : "Continue") { go(.reminders) }
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

    private func title(_ text: String, subtitle: String) -> some View {
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

    private func feature(_ symbol: String, _ text: String) -> some View {
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

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func go(_ target: Step) {
        nameFocused = false
        withAnimation(.smooth) { step = target }
        if target == .baby, trimmedName.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocused = true }
        }
    }

    private func finish() {
        let templates = CareTemplate.all.filter { selected.contains($0.name) }
        vm.completeOnboarding(
            baby: BabyProfile(name: trimmedName, birthDate: hasBirthDate ? birthDate : nil, caregiverRole: role.trimmingCharacters(in: .whitespacesAndNewlines)),
            photo: photo,
            templates: templates
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
