import SwiftUI
import UIKit

extension Color {
    /// A colour that switches between a light-mode and dark-mode hex value.
    init(light: UInt32, dark: UInt32) {
        self = Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Soft pastel palette. Pastels are used for fills and rings; the deeper "text" shades keep
/// labels readable against them.
enum AppPalette {
    static let primary = Color(light: 0x8B7CF6, dark: 0xB3A8FF)
    static let primaryDeep = Color(light: 0x6A58E0, dark: 0xCFC7FF)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x1C1828)

    static let text = Color(light: 0x3B3450, dark: 0xECE8F4)
    static let secondaryText = Color(light: 0x6F6786, dark: 0xA59DB8)

    static let medicine = Color(light: 0xB9A6F7, dark: 0x8F7FD9)
    static let medicineDeep = Color(light: 0x6F5AD9, dark: 0xD3C9FF)
    static let care = Color(light: 0x7CCFC3, dark: 0x4FA89C)
    static let careDeep = Color(light: 0x2C8A7D, dark: 0x9BE3D8)

    static let done = Color(light: 0x8FD9B0, dark: 0x5DB585)
    static let doneText = Color(light: 0x2F7D52, dark: 0x9FE3BD)
    static let soon = Color(light: 0xF5C77E, dark: 0xD9A85A)
    static let soonText = Color(light: 0x99661A, dark: 0xF3CD8C)
    static let overdue = Color(light: 0xF2948A, dark: 0xE07A70)
    static let overdueText = Color(light: 0xB84A40, dark: 0xF5A79F)

    static let backgroundTop = Color(light: 0xF8F5FF, dark: 0x1C1828)
    static let backgroundMiddle = Color(light: 0xFFF4EF, dark: 0x181524)
    static let backgroundBottom = Color(light: 0xF1FAF6, dark: 0x141220)
    static let blobLavender = Color(light: 0xE4DBFF, dark: 0x3A2F63)
    static let blobPeach = Color(light: 0xFFDCCD, dark: 0x3B2440)
    static let blobMint = Color(light: 0xD3F2E6, dark: 0x173A37)

    static func tint(for kind: CareKind) -> Color {
        kind == .medicine ? medicine : care
    }

    static func deepTint(for kind: CareKind) -> Color {
        kind == .medicine ? medicineDeep : careDeep
    }

    static func ring(for status: CareStatus) -> Color {
        switch status {
        case .upcoming: return primary
        case .dueSoon: return soon
        case .overdue: return overdue
        }
    }

    static func statusText(for status: CareStatus) -> Color {
        switch status {
        case .upcoming: return secondaryText
        case .dueSoon: return soonText
        case .overdue: return overdueText
        }
    }
}

/// The soft lavender → peach → mint backdrop used behind every screen.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.backgroundTop, AppPalette.backgroundMiddle, AppPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { proxy in
                let width = proxy.size.width
                Circle()
                    .fill(AppPalette.blobLavender)
                    .frame(width: width * 0.9)
                    .blur(radius: 70)
                    .offset(x: -width * 0.35, y: -width * 0.35)
                Circle()
                    .fill(AppPalette.blobPeach)
                    .frame(width: width * 0.75)
                    .blur(radius: 80)
                    .offset(x: width * 0.5, y: proxy.size.height * 0.25)
                Circle()
                    .fill(AppPalette.blobMint)
                    .frame(width: width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -width * 0.2, y: proxy.size.height * 0.7)
            }
            .opacity(0.8)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

private struct GlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.55), lineWidth: 0.7))
            .shadow(color: AppPalette.primaryDeep.opacity(colorScheme == .dark ? 0.0 : 0.07), radius: 14, y: 6)
    }
}

/// An SF Symbol in a soft tinted circle, coloured by the item's category.
struct SymbolBadge: View {
    let symbol: String
    let kind: CareKind
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(AppPalette.deepTint(for: kind))
            .frame(width: size, height: size)
            .background(AppPalette.tint(for: kind).opacity(0.28), in: Circle())
            .accessibilityHidden(true)
    }
}
