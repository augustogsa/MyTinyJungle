import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Security

/// Sign in with Apple or Google. The account lives in the Keychain; plant data syncs through the user's iCloud.
@Observable @MainActor
final class AuthManager {
    static let shared = AuthManager()

    struct Account: Codable, Equatable {
        enum Provider: String, Codable { case apple, google }
        var provider: Provider
        var id: String
        var name: String?
        var email: String?
    }

    private(set) var account: Account?
    var error: String?
    var signedIn: Bool { account != nil }
    var googleAvailable: Bool { !((Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String) ?? "").isEmpty }

    private init() { account = Keychain.load() }

    // MARK: Apple

    func configure(_ request: ASAuthorizationAppleIDRequest) { request.requestedScopes = [.fullName, .email] }

    func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let c = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let given = c.fullName?.givenName
            // Apple sends name and email only the first time; keep what we had.
            let old = Keychain.load()
            save(.init(provider: .apple, id: c.user, name: given ?? (old?.id == c.user ? old?.name : nil), email: c.email ?? (old?.id == c.user ? old?.email : nil)))
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = String(localized: "Apple sign-in didn't finish. Try again.", comment: "Sign-in error under Apple button; calm; max 50 chars") }
        }
    }

    // MARK: Google

    func signInWithGoogle() {
        guard googleAvailable, let root = AdsManager.rootController() else { return }
        Task {
            do {
                let r = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
                let u = r.user
                save(.init(provider: .google, id: u.userID ?? UUID().uuidString, name: u.profile?.givenName, email: u.profile?.email))
            } catch {
                if (error as NSError).code != GIDSignInError.canceled.rawValue { self.error = String(localized: "Google sign-in didn't finish. Try again.", comment: "Sign-in error under Google button; calm; max 50 chars") }
            }
        }
    }

    // MARK: Session

    /// On launch: drop the session if Apple revoked it; restore Google silently.
    func refresh() async {
        guard let a = account else { return }
        switch a.provider {
        case .apple:
            let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: a.id)
            if state == .revoked || state == .notFound { signOut() }
        case .google:
            if googleAvailable { _ = try? await GIDSignIn.sharedInstance.restorePreviousSignIn() }
        }
    }

    func signOut() {
        if account?.provider == .google { GIDSignIn.sharedInstance.signOut() }
        Keychain.delete(); account = nil
    }

    private func save(_ a: Account) {
        account = a; error = nil
        Keychain.save(a)
        if let n = a.name, !n.isEmpty, JungleSettings.shared.ownerName.isEmpty { JungleSettings.shared.ownerName = n }
    }
}

private enum Keychain {
    static let service = "com.simpleappscompany.mytinyjungle.account"
    static func save(_ a: AuthManager.Account) {
        guard let data = try? JSONEncoder().encode(a) else { return }
        delete()
        SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecValueData: data,
                    kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock] as CFDictionary, nil)
    }
    static func load() -> AuthManager.Account? {
        var out: AnyObject?
        let q = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary
        guard SecItemCopyMatching(q, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(AuthManager.Account.self, from: d)
    }
    static func delete() { SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary) }
}
