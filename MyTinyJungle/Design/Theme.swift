import SwiftUI
import UIKit

extension Color {
    fileprivate init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// My Tiny Jungle palette. 80% warm neutrals, 15% greens, 5% warm accents.
enum Jungle {
    static let forest = Color(light: 0x2F5D3A, dark: 0x8DBE8F)
    static let leaf = Color(light: 0x5F8F62, dark: 0x7FAF82)
    static let sage = Color(light: 0xA8C7A5, dark: 0x4C6A4E)
    static let cream = Color(light: 0xFCFAF6, dark: 0x141A15)
    static let mist = Color(light: 0xF4F9EF, dark: 0x1C241D)
    static let mint = Color(light: 0xEEF7E8, dark: 0x223024)
    static let sun = Color(light: 0xF6D992, dark: 0xC9A955)
    static let peach = Color(light: 0xF8CDB6, dark: 0xB98A72)
    static let terracotta = Color(light: 0xD9987B, dark: 0xD9987B)
    static let text = Color(light: 0x3E4E3D, dark: 0xE4EBE2)
    /// Secondary text: 5.2:1 on white, 5:1 on cream (HIG / WCAG AA).
    static let subtle = Color(light: 0x5C6B5B, dark: 0xA3B0A1)
    /// Card surface: white on warm cream, lifted grey-green in dark mode.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1E2720)
    /// Accent text on light backgrounds (leaf is too light for small text).
    static let accentText = Color(light: 0x2F5D3A, dark: 0xA6D3A8)
    /// Readable text on sun/peach/terracotta tints.
    static let warmText = Color(light: 0x7A3E22, dark: 0xF2C2A8)
    static let border = Color(light: 0xDDE5D9, dark: 0x2E3A2F)

    static let userBubble = Color(light: 0xDCEFD3, dark: 0x2C4A30)

    static let radius: CGFloat = 20
    static let innerRadius: CGFloat = 12
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Jungle.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border.opacity(0.7), lineWidth: 0.5))
            .shadow(color: Color(red: 0.24, green: 0.3, blue: 0.2).opacity(0.06), radius: 10, y: 4)
    }
}

extension View {
    func jungleCard() -> some View { modifier(CardBackground()) }
}

/// Real photo of the plant or a calm leaf placeholder.
struct PlantAvatar: View {
    let data: Data?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Jungle.mint
                    Image(systemName: "leaf").font(.system(size: size * 0.42)).foregroundStyle(Jungle.leaf)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}


/// Section title used across tabs.
struct SectionTitle: View {
    let title: String
    var action: String? = nil
    var onAction: () -> Void = {}
    init(_ title: String, action: String? = nil, onAction: @escaping () -> Void = {}) { self.title = title; self.action = action; self.onAction = onAction }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Jungle.text)
            Spacer()
            if let action { Button(action, action: onAction).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.accentText) }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Number tile with a coloured icon, text always in readable ink.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    var tint: Color = Jungle.leaf
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 30, height: 30).background(tint.opacity(0.16), in: Circle())
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Jungle.text).contentTransition(.numericText())
            Text(label).font(.footnote).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).jungleCard()
        .accessibilityElement(children: .combine)
    }
}

/// Status pill: tinted background, dark readable text.
struct StatusPill: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Jungle.leaf
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(Jungle.text)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(tint.opacity(0.22), in: Capsule())
    }
}
