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
    @State private var carouselWidth: CGFloat = 402

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

    @State private var size: CGSize = .zero
    @State private var fold: CGRect?

    /// Two pages when there's room: across the Duo's fold, or a landscape window. Leading width and gap.
    private var split: (lead: CGFloat, gap: CGFloat)? { PageSpread.split(size: size, fold: fold) }

    var body: some View {
        Group {
            if let split { wide(split) } else { phone }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                ContentImage("art/signin-leaves.jpg", fallback: "SignInLeaves").scaledToFill().ignoresSafeArea()

                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .clear, location: 0.12), .init(color: .black, location: 0.42)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                LinearGradient(stops: [.init(color: Jungle.cream.opacity(0), location: 0.12), .init(color: Jungle.cream.opacity(0.82), location: 0.48), .init(color: Jungle.cream.opacity(0.94), location: 1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onFoldDivisionChange { fold = $0 }
    }

    private func brand(erty: CGFloat) -> some View {
        VStack(spacing: 0) {
            ErtyView(mood: .wave, size: erty)
            Text("My Tiny Jungle").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                .padding(.top, 18)
            Text("Your plants, talking to you.").font(.body).foregroundStyle(Jungle.subtle).padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }

    private var buttons: some View {
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
    }

    private var phone: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            brand(erty: 132).padding(.bottom, 28)
            carousel.padding(.bottom, 28)
            buttons.padding(.horizontal, 24)
        }
        .padding(.top, 40).padding(.bottom, 12)
    }

    /// Leading page: Erty and the way in. Trailing page: every feature, one scroll away.
    private func wide(_ split: (lead: CGFloat, gap: CGFloat)) -> some View {
        HStack(spacing: split.gap) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                brand(erty: min(132, size.height * 0.2))
                buttons.frame(maxWidth: 340).padding(.top, 36)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32).padding(.vertical, 24)
            .frame(width: split.lead)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("All the help a plant parent could wish for").font(.title3.weight(.semibold)).foregroundStyle(Jungle.text)
                        .padding(.horizontal, 4).padding(.bottom, 4)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 12) {
                        ForEach(Self.features) { tile($0) }
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 28).padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Feature carousel

    /// Wide enough that every title fits; the neighbours peek in at both edges.
    /// Measured from the carousel's own width (never the screen), capped so a wide or unfolded display keeps a card, not a banner.
    private var cardWidth: CGFloat { min(max(carouselWidth, 200) - 88, 420) }

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
            .contentMargins(.horizontal, max(0, (carouselWidth - cardWidth) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page, anchor: .center)
            .scrollIndicators(.hidden)
            .frame(height: 190)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                guard let i = shown.firstIndex(where: { $0.id == (page ?? shown.first?.id) }) else { continue }
                withAnimation(.smooth(duration: 0.6)) { page = shown[(i + 1) % shown.count].id }
            }
        }
    }

    /// Compact feature tile for the two-page layout's grid.
    private func tile(_ f: Feature) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Icon3DView(f.icon, size: 34)
            Text(f.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText).fixedSize(horizontal: false, vertical: true)
            Text(f.detail).font(.footnote).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
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
