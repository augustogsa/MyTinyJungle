import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

/// First screen: the app, three promises, and sign in with Apple or Google.
struct SignInView: View {
    @Environment(\.colorScheme) private var scheme
    private var auth = AuthManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Image("AppMark").resizable().scaledToFit().frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                .accessibilityHidden(true)
            Text("My Tiny Jungle").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                .padding(.top, 20)
            Text("Your plants, talking to you.").font(.body).foregroundStyle(Jungle.subtle).padding(.top, 4)
            VStack(alignment: .leading, spacing: 16) {
                promise(.chat, "Plants tell you when they need water or food")
                promise(.leafTag, "Scan soil and fertilizer to see what fits")
                promise(.shieldCheck, "Backed up to your iCloud, private to you")
            }
            .padding(.top, 32).padding(.horizontal, 8)
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue, onRequest: auth.configure, onCompletion: auth.handleApple)
                    .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                    .frame(height: 52).clipShape(Capsule())
                if auth.googleAvailable {
                    Button { auth.signInWithGoogle() } label: {
                        HStack(spacing: 10) {
                            Image("GoogleG").resizable().frame(width: 18, height: 18)
                            Text("Continue with Google").font(.system(size: 19, weight: .medium))
                        }
                        .foregroundStyle(Color(white: 0.12))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(white: 0.75), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if let e = auth.error { Text(e).font(.footnote).foregroundStyle(Jungle.warmText) }
                Text("We only use your account to keep your jungle safe. No posts, no spam.")
                    .font(.caption).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center).padding(.top, 4)
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .jungleBackdrop()
    }

    private func promise(_ icon: Icon3D, _ text: String) -> some View {
        HStack(spacing: 14) {
            Icon3DView(icon, size: 34).frame(width: 38)
            Text(text).font(.body).foregroundStyle(Jungle.text)
            Spacer(minLength: 0)
        }
    }
}
