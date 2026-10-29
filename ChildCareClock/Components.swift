import SwiftUI

/// A ring that drains as the due time approaches, coloured by status.
struct CountdownRing<Center: View>: View {
    let fraction: Double
    let status: CareStatus
    var lineWidth: CGFloat = 10
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppPalette.ring(for: status).opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: status == .overdue ? 1 : max(0.02, fraction))
                .stroke(AppPalette.ring(for: status), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.6), value: fraction)
            center()
        }
    }
}

extension CountdownRing where Center == EmptyView {
    init(fraction: Double, status: CareStatus, lineWidth: CGFloat = 10) {
        self.init(fraction: fraction, status: status, lineWidth: lineWidth) { EmptyView() }
    }
}

/// The baby's photo in a circle, or their initial on a soft gradient.
struct BabyAvatar: View {
    let photo: UIImage?
    let name: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [AppPalette.medicine, AppPalette.care], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        if let initial = name.trimmingCharacters(in: .whitespaces).first {
                            Text(String(initial).uppercased())
                                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: size * 0.45, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(color: AppPalette.primaryDeep.opacity(0.15), radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = AppPalette.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(AppPalette.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppPalette.primaryDeep)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppPalette.primary.opacity(configuration.isPressed ? 0.22 : 0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Selectable capsule used for quick choices (times, intervals, templates).
struct ChoiceChip: View {
    let title: String
    var symbol: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.subheadline.weight(.semibold)) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(isSelected ? AppPalette.onPrimary : AppPalette.text)
            .background(isSelected ? AnyShapeStyle(AppPalette.primary) : AnyShapeStyle(AppPalette.primary.opacity(0.1)), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ToastView: View {
    let toast: Toast
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppPalette.doneText)
            Text(toast.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.text)
                .lineLimit(2)
            Spacer(minLength: 8)
            if toast.canUndo {
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.primaryDeep)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(AppPalette.primary.opacity(0.15), in: Capsule())
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 18)
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", onUndo)
    }
}

struct EmptyStateCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppPalette.primary)
                .frame(width: 72, height: 72)
                .background(AppPalette.primary.opacity(0.12), in: Circle())
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppPalette.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppPalette.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassPanel()
    }
}

extension View {
    /// Clears the default list row chrome so glass cards sit on the app background.
    func cardRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
    }

    /// A grouped Form/List on the soft app background.
    func softFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppBackground())
    }
}

/// "I'm Vedika's…" Mom / Dad / Grandma / Grandpa / Nanny, or a role typed in.
struct CaregiverRolePicker: View {
    @Binding var role: String
    let babyName: String
    @State private var isOther = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if babyName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("I'm the baby's…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
            } else {
                Text("I'm \(babyName.trimmingCharacters(in: .whitespaces))'s…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.secondaryText)
            }
            FlowLayout(spacing: 8) {
                ForEach(BabyProfile.roleChoices, id: \.self) { choice in
                    ChoiceChip(title: BabyProfile.displayRole(choice), isSelected: !isOther && role == choice) {
                        isOther = false
                        role = choice
                        SoundManager.shared.selection()
                    }
                }
                ChoiceChip(title: String(appLocalized: "Other"), isSelected: isOther) {
                    isOther = true
                    if BabyProfile.roleChoices.contains(role) { role = "" }
                    SoundManager.shared.selection()
                }
            }
            if isOther {
                TextField("e.g. Aunt, Amma, Papa", text: $role)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(AppPalette.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onAppear {
            isOther = !role.isEmpty && !BabyProfile.roleChoices.contains(role)
        }
    }
}
