import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

/// First screen: the app, three promises, and sign in with Apple or Google.
struct SignInView: View {
    @Environment(\.colorScheme) private var scheme
    private var auth = AuthManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Image("AppMark").resizable().scaledToFit().frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
                    .accessibilityHidden(true)
                Text("My Tiny Jungle").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .padding(.top, 18)
                Text("Your plants, talking to you.").font(.body).foregroundStyle(Jungle.subtle).padding(.top, 2)
            }
            .padding(.bottom, 28)
            VStack(alignment: .leading, spacing: 14) {
                promise(.wateringCan, "No more guessing, no more losses", "Your plants tell you when they're thirsty, gently and right on time.")
                promise(.firstAid, "Droopy leaf? Let's save it", "Snap a photo and learn what your plant needs to feel better.")
                promise(.shieldLeaf, "Safe for your furry family", "Know which plants are gentle with cats, dogs and little ones.")
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
                        .overlay(Capsule().strokeBorder(Color(white: 0.8), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if let e = auth.error { Text(e).font(.footnote).foregroundStyle(Jungle.warmText) }
                Text("Your jungle lives safely in your iCloud. Never shared, never sold.")
                    .font(.footnote).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center).padding(.top, 6)
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
