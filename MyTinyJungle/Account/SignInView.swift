import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

/// First screen: the app, three features drawn at random from everything it does (so
/// every visit shows something new), and sign in with Apple or Google.
struct SignInView: View {
    @Environment(\.colorScheme) private var scheme
    private var auth = AuthManager.shared
    @State private var shown = Array(SignInView.features.shuffled().prefix(3))

    private struct Feature: Identifiable { let icon: Icon3D; let title: LocalizedStringKey; let detail: LocalizedStringKey; var id: Icon3D { icon } }

    /// The same features the website shows in "All the help a plant parent could wish for".
    private static let features: [Feature] = [
        .init(icon: .wateringCan, title: "No more guessing, no more losses", detail: "Your plants tell you when they're thirsty, gently and right on time."),
        .init(icon: .chat, title: "Chat with your plants", detail: "Write it like a text. They reply with personality."),
        .init(icon: .soilTest, title: "Soil-check ritual", detail: "Learns each plant's rhythm so watering is just right."),
        .init(icon: .calendarHeart, title: "Gentle care requests", detail: "Water, feed, mist and turn, only when it's time."),
        .init(icon: .firstAid, title: "Droopy leaf? Let's save it", detail: "Snap a photo and learn what your plant needs to feel better."),
        .init(icon: .bug, title: "Pest guard", detail: "Spot pests early and follow a simple plan."),
        .init(icon: .pot, title: "Repot check", detail: "Knows when it's time and what pot and soil to use."),
        .init(icon: .travel, title: "Going away", detail: "Holiday plans so every plant is fine while you're gone."),
        .init(icon: .seedling, title: "Cuttings", detail: "Grow new plants from the ones you love."),
        .init(icon: .sun, title: "Season guide", detail: "What each season means for your plants, where you live."),
        .init(icon: .fertilizer, title: "Label scanner", detail: "Know if a food or soil suits each of your plants."),
        .init(icon: .livingRoom, title: "Spaces", detail: "Room by room, the right light for every plant."),
        .init(icon: .shieldLeaf, title: "Safe for your furry family", detail: "Know which plants are gentle with cats, dogs and little ones."),
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
            VStack(alignment: .leading, spacing: 14) {
                ForEach(shown) { promise($0.icon, $0.title, $0.detail) }
            }
            .padding(.bottom, 32)
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
        .padding(.horizontal, 24).padding(.top, 40).padding(.bottom, 12)
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

    private func promise(_ icon: Icon3D, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Icon3DView(icon, size: 36).frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Jungle.text)
                Text(detail).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
