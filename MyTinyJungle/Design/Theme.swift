import SwiftUI
import UIKit

extension Color {
    /// A named token from Assets.xcassets/Jungle (light + dark colorsets).
    fileprivate static func token(_ name: String) -> Color { Color(name) }
    /// Base token, switching to its elevated twin for sheets, popovers and covers in dark mode (HIG Dark Mode › base and elevated).
    fileprivate static func token(_ name: String, elevated: String) -> Color {
        Color(uiColor: UIColor { t in
            UIColor(named: t.userInterfaceLevel == .elevated ? elevated : name, in: nil, compatibleWith: t) ?? .systemBackground
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// My Tiny Jungle palette as semantic tokens. Every value lives in Assets.xcassets/Jungle with a light and a dark variant;
/// Android mirrors the same names and hex values.
enum Jungle {
    // Backgrounds (base vs elevated, grouped hierarchy)
    static let background = Color.token("Background", elevated: "BackgroundElevated")
    static let surface = Color.token("Surface", elevated: "SurfaceElevated")
    static let surfaceRaised = Color.token("SurfaceRaised")
    static let fill = Color.token("Fill")
    static let fillSubtle = Color.token("FillSubtle")
    static let fillStrong = Color.token("FillStrong")
    /// Accent-tinted fill for selected states and secondary buttons (never brown or terracotta).
    static let accentFill = Color.token("AccentFill")
    static let chipSelected = Color.token("ChipSelected")
    static let onChipSelected = Color.token("OnChipSelected")
    static let separator = Color.token("Separator")
    // Labels
    static let text = Color.token("Label")
    static let subtle = Color.token("SecondaryLabel")
    static let tertiary = Color.token("TertiaryLabel")
    static let quaternary = Color.token("QuaternaryLabel")
    static let accentText = Color.token("AccentText")
    static let warmText = Color.token("WarmText")
    // Brand and controls
    static let tint = Color.token("Tint")
    static let forest = Color.token("Forest")
    static let onForest = Color.token("OnForest")
    static let leaf = Color.token("Leaf")
    static let sage = Color.token("Sage")
    static let sun = Color.token("Sun")
    static let sunFill = Color.token("SunFill")
    static let peach = Color.token("Peach")
    static let warmFill = Color.token("WarmFill")
    static let terracotta = Color.token("Terracotta")
    static let sky = Color.token("Sky")
    static let gold = Color.token("Gold")
    static let teal = Color.token("Teal")
    static let plum = Color.token("Plum")
    static let brick = Color.token("Brick")
    static let indigo = Color.token("Indigo")
    // Chat
    static let incoming = Color.token("IncomingBubble")
    static let userBubble = Color.token("UserBubble")

    // Legacy names, same tokens
    static var cream: Color { background }
    static var mist: Color { fillSubtle }
    static var mint: Color { fill }
    static var border: Color { separator }
    /// Card outline: a hairline in light, none in dark (cards separate by lightness there).
    static let cardEdge = Color(uiColor: UIColor { t in t.userInterfaceStyle == .dark ? .clear : (UIColor(named: "Separator") ?? .separator) })

    static let radius: CGFloat = 20
    static let innerRadius: CGFloat = 12
}

struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.cardEdge, lineWidth: 0.5))
            // Dark mode separates by lightness (base #000, card #1C1C1E), not shadow.
            .shadow(color: Color(red: 0.24, green: 0.3, blue: 0.2).opacity(scheme == .dark ? 0 : 0.06), radius: 10, y: 4)
    }
}

/// Filter / choice chip. Unselected: neutral fill. Selected: brand forest in light, accent tint + accent label in dark.
struct JungleChip: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
            .foregroundStyle(selected ? Jungle.onChipSelected : Jungle.text)
            .background(selected ? Jungle.chipSelected : Jungle.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Jungle.separator, lineWidth: 0.5))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    func jungleCard() -> some View { modifier(CardBackground()) }
    func jungleChip(selected: Bool) -> some View { modifier(JungleChip(selected: selected)) }
    /// Primary action: accent fill with on-accent ink (white on forest in light, dark ink on bright green in dark).
    func junglePrimary() -> some View { tint(Jungle.forest).foregroundStyle(Jungle.onForest) }
}

/// Real photo of the plant or a calm leaf placeholder.
struct PlantAvatar: View {
    let data: Data?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data, let image = Thumbs.image(data, side: size) {
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
            Text(title.uiLocalized).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            Spacer()
            if let action { Button(action.uiLocalized, action: onAction).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.accentText) }
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
            Text(value).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).contentTransition(.numericText())
            Text(label.uiLocalized).font(.footnote).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
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
            Text(text.uiLocalized)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(Jungle.text)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(tint.opacity(0.22), in: Capsule())
    }
}

extension String {
    /// Runtime catalog lookup for strings handed to shared components as plain `String` literals.
    /// Already-localized or user text has no catalog entry and comes back unchanged.
    var uiLocalized: String { Bundle.main.localizedString(forKey: self, value: self, table: nil) }
}
