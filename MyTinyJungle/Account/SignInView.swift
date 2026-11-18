import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

/// First screen: the app, a carousel of every feature (website cards, shuffled each visit,
/// gliding on its own and swipeable), and sign in with Apple or Google.
struct SignInView: View {
    @Environment(\.colorScheme) private var scheme
    private var auth = AuthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = SignInView.features.shuffled()
    @State private var page: Icon3D?

    private struct Feature: Identifiable { let icon: Icon3D; let title: LocalizedStringKey; let detail: LocalizedStringKey; var id: Icon3D { icon } }

    /// The same features the website shows in "All the help a plant parent could wish for".
    private static let features: [Feature] = [
        .init(icon: .wateringCan, title: "No more guessing", detail: "Your plants tell you when they're thirsty."),
        .init(icon: .chat, title: "Chat with your plants", detail: "Text them. They reply with personality."),
        .init(icon: .soilTest, title: "Soil-check ritual", detail: "Learns each plant's rhythm for watering."),
        .init(icon: .calendarHeart, title: "Gentle care requests", detail: "Water, feed, mist and turn, right on time."),
        .init(icon: .firstAid, title: "Droopy leaf? Let's save it", detail: "Snap a photo and learn what it needs."),
        .init(icon: .bug, title: "Pest guard", detail: "Spot pests early and follow a simple plan."),
        .init(icon: .pot, title: "Repot check", detail: "Knows when it's time, and which pot and soil."),
        .init(icon: .travel, title: "Going away", detail: "Holiday plans so every plant stays fine."),
        .init(icon: .seedling, title: "Cuttings", detail: "Grow new plants from the ones you love."),
        .init(icon: .sun, title: "Season guide", detail: "What each season means where you live."),
        .init(icon: .fertilizer, title: "Label scanner", detail: "See if a food or soil suits each plant."),
        .init(icon: .livingRoom, title: "Spaces", detail: "Room by room, the right light for each plant."),
        .init(icon: .cat, title: "Safe for pets and kids", detail: "Know which plants are gentle with them."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ErtyView(mood: .wave, size: 132)
                Text("My Tiny Jungle").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .padding(.top, 18)
                Text("Your plants, talking to you.").font(.body).foregroundStyle(Jungle.subtle).padding(.top, 2)
            }
            .padding(.bottom, 28)
            carousel.padding(.bottom, 28)
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue, onRequest: auth.configure, onCompletion: auth.handleApple)
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    .frame(height: 54).clipShape(Capsule())
                if auth.googleAvailable {
                    Button { auth.signInWithGoogle() } label: {
                        HStack(spacing: 8) {
                            Image("GoogleG").resizable().interpolation(.high).frame(width: 20, height: 20)
                            Text("Continue with Google").font(.system(size: 20, weight: .medium))
                        }
                        .foregroundStyle(Color(white: 0.12))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if let e = auth.error { Text(e).font(.footnote).foregroundStyle(Jungle.warmText) }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 40).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Image("SignInLeaves").resizable().scaledToFill().ignoresSafeArea()

                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .clear, location: 0.12), .init(color: .black, location: 0.42)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                LinearGradient(stops: [.init(color: Jungle.cream.opacity(0), location: 0.12), .init(color: Jungle.cream.opacity(0.82), location: 0.48), .init(color: Jungle.cream.opacity(0.94), location: 1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
    }

    // MARK: Feature carousel

    /// Wide enough that every title fits; the neighbours peek in at both edges.
    private var cardWidth: CGFloat { (UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }.first ?? 402) - 88 }

    private var carousel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .center, spacing: 8) {
                    ForEach(shown) { card($0).frame(width: cardWidth)
                        .scrollTransition(.interactive, axis: .horizontal) { c, ph in
                            c.scaleEffect(1 - 0.06 * min(abs(ph.value), 1)).opacity(1 - 0.1 * min(abs(ph.value), 1))
                        }.id($0.id) }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, ((UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }.first ?? 402) - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page, anchor: .center)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: 190)
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                guard let i = shown.firstIndex(where: { $0.id == (page ?? shown.first?.id) }) else { continue }
                withAnimation(.smooth(duration: 0.6)) { page = shown[(i + 1) % shown.count].id }
            }
        }
    }

    private func card(_ f: Feature) -> some View {
        HStack(spacing: 12) {
            Icon3DView(f.icon, size: 40).frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(f.title).font(.headline).foregroundStyle(Jungle.accentText).fixedSize(horizontal: false, vertical: true)
                Text(f.detail).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 18)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}
