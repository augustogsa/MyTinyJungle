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
                promise(.chat, "Plants tell you when they need water or food")
                promise(.leafTag, "Scan soil and fertilizer to see what fits")
                promise(.shieldCheck, "Backed up to your iCloud, private to you")
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
                Text("We only use your account to keep your jungle safe. No posts, no spam.")
                    .font(.footnote).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center).padding(.top, 6)
            }
        }
        .padding(.horizontal, 24).padding(.top, 40).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Image("SignInLeaves").resizable().scaledToFill().ignoresSafeArea()
                    .blur(radius: 2)
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0.0), .init(color: .clear, location: 0.12), .init(color: .black, location: 0.42)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                LinearGradient(stops: [.init(color: Jungle.cream.opacity(0), location: 0.12), .init(color: Jungle.cream.opacity(0.82), location: 0.48), .init(color: Jungle.cream.opacity(0.94), location: 1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
        }
    }

    private func promise(_ icon: Icon3D, _ text: String) -> some View {
        HStack(spacing: 14) {
            Icon3DView(icon, size: 34).frame(width: 38)
            Text(text).font(.body).foregroundStyle(Jungle.text)
            Spacer(minLength: 0)
        }
    }
}
