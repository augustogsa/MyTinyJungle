import SwiftUI

/// Soft, blurred leaf light behind every screen, like light through a window.
/// Light: warm cream with sage glow. Dark: deep forest with a dim leaf glow.
struct JungleBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var intensity: Double = 1

    var body: some View {
        GeometryReader { g in
            ZStack {
                Jungle.cream
                Circle().fill(Jungle.sage.opacity((scheme == .dark ? 0.35 : 0.55) * intensity))
                    .frame(width: g.size.width * 1.1).offset(x: -g.size.width * 0.35, y: -g.size.height * 0.42)
                Circle().fill(Jungle.sun.opacity((scheme == .dark ? 0.12 : 0.35) * intensity))
                    .frame(width: g.size.width * 0.8).offset(x: g.size.width * 0.45, y: -g.size.height * 0.38)
                Image(systemName: "leaf.fill")
                    .font(.system(size: g.size.width * 0.9))
                    .foregroundStyle(Jungle.leaf.opacity((scheme == .dark ? 0.25 : 0.32) * intensity))
                    .rotationEffect(.degrees(-28))
                    .offset(x: g.size.width * 0.3, y: -g.size.height * 0.3)
                Circle().fill(Jungle.mint.opacity(0.7 * intensity))
                    .frame(width: g.size.width).offset(x: -g.size.width * 0.3, y: g.size.height * 0.45)
            }
            .blur(radius: 60)
            .drawingGroup() // rendered once into a texture, not re-blurred while content scrolls above it
            .overlay(alignment: .bottom) {
                // Fade to plain cream so lower content sits on a calm base.
                LinearGradient(colors: [.clear, Jungle.cream], startPoint: .top, endPoint: .bottom)
                    .frame(height: g.size.height * 0.55)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    func jungleBackdrop() -> some View { background { JungleBackdrop() } }
}
