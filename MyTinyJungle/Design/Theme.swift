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
    static let subtle = Color(light: 0x6B7A6A, dark: 0x9AA898)
    static let border = Color(light: 0xDDE5D9, dark: 0x2E3A2F)

    static let radius: CGFloat = 20
    static let innerRadius: CGFloat = 12
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Jungle.mist, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
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
