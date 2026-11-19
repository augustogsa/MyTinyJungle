import UserNotifications
import SwiftData
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Security

/// Sign in with Apple or Google, verified by api.mytinyjungle.com so the same account works on iPhone, iPad and Android.
/// The profile lives in the Keychain; plants sync through the API (JungleSync).
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
    var busy = false
    var signedIn: Bool { account != nil }
    var googleAvailable: Bool { !((Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String) ?? "").isEmpty }

    private init() { account = Keychain.load() }

    #if DEBUG
    /// QA only: `-apiTestSession <refreshToken> <userId>` signs in as a server test account. Runs first thing at launch.
    nonisolated static func applyTestSession() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-apiTestSession"), args.count > i + 2 else { return }
        SessionStore.save(userID: args[i + 2], refresh: args[i + 1])
        Keychain.save(.init(provider: .apple, id: "qa", name: "QA", email: "qa@mytinyjungle.test"))
    }
    #endif

    // MARK: Apple

    func configure(_ request: ASAuthorizationAppleIDRequest) { request.requestedScopes = [.fullName, .email] }

    func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let c = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let given = c.fullName?.givenName
            // Apple sends name and email only the first time; keep what we had.
            let old = Keychain.load()
            let local = Account(provider: .apple, id: c.user, name: given ?? (old?.id == c.user ? old?.name : nil), email: c.email ?? (old?.id == c.user ? old?.email : nil))
            guard let tokenData = c.identityToken, let token = String(data: tokenData, encoding: .utf8) else { failed(); return }
            Task { await connect(local, provider: "apple", idToken: token) }
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code != .canceled { error = Grammar.pt(String(localized: "Apple sign-in didn't finish. Try again.", comment: "Sign-in error under Apple button; calm; max 50 chars")) }
        }
    }

    // MARK: Google

    func signInWithGoogle() {
        guard googleAvailable, let root = AdsManager.rootController() else { return }
        Task {
            do {
                let r = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
                let u = r.user
                guard let token = u.idToken?.tokenString else { failed(); return }
                await connect(.init(provider: .google, id: u.userID ?? UUID().uuidString, name: u.profile?.givenName, email: u.profile?.email), provider: "google", idToken: token)
            } catch {
                if (error as NSError).code != GIDSignInError.canceled.rawValue { self.error = Grammar.pt(String(localized: "Google sign-in didn't finish. Try again.", comment: "Sign-in error under Google button; calm; max 50 chars")) }
            }
        }
    }

    /// Verifies the identity with the server, then keeps the profile and starts syncing.
    private func connect(_ local: Account, provider: String, idToken: String) async {
        busy = true
        defer { busy = false }
        do {
            try await JungleAPI.shared.signIn(provider: provider, idToken: idToken, name: local.name)
            save(local)
            if let n = local.name, !n.isEmpty { await JungleAPI.shared.updateName(n) }
            await Store.shared.didSignIn()
            await JungleSync.shared.sync()
            if let t = UserDefaults.standard.string(forKey: "push.token") { await JungleAPI.shared.setPushToken(t) }
            await Household.shared.redeemPendingInvite()
            await Household.shared.sync()
            await AppAttest.ensure()
            await Referrals.redeemPending()
        } catch JungleAPI.APIError.offline {
            error = Grammar.pt(String(localized: "No connection. Check your internet and try again.", comment: "Sign-in error when offline; calm; max 60 chars"))
        } catch {
            failed()
        }
    }

    private func failed() {
        error = Grammar.pt(String(localized: "Sign-in didn't finish. Try again.", comment: "Generic sign-in error; calm; max 50 chars"))
    }

    // MARK: Session

    /// On launch: drop the session if Apple revoked it; restore Google silently. Profiles from before
    /// accounts moved to the server have no server session: sign in once more (plants stay on the phone
    /// and upload on that sign-in).
    func refresh() async {
        guard let a = account else { return }
        if !JungleAPI.shared.hasSession { Keychain.delete(); account = nil; return }
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
        BrainCache.clear()
        JungleSync.shared.reset()
        Task { await JungleAPI.shared.signOut() }
    }

    /// Deletes the account and everything it owns: the server account (erased for good after 30 days),
    /// Google access, the session, and all plants, history and photos here and in iCloud.
    @MainActor func deleteAccountAndData(_ ctx: ModelContext) async -> Bool {
        do { try await JungleAPI.shared.deleteAccount() } catch JungleAPI.APIError.signedOut {} catch {
            self.error = Grammar.pt(String(localized: "Couldn't reach the server. Check your connection and try again.", comment: "Account deletion error; calm; max 70 chars"))
            return false
        }
        JungleSync.shared.reset()
        if account?.provider == .google { try? await GIDSignIn.sharedInstance.disconnect() }
        for t in [Plant.self, CareEvent.self, ChatMessage.self, OwnedProduct.self, Space.self, CareTask.self, Propagation.self] as [any PersistentModel.Type] {
            try? ctx.delete(model: t)
        }
        try? ctx.save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        if account?.provider == .google { GIDSignIn.sharedInstance.signOut() }
        Keychain.delete(); account = nil
        return true
    }

    private func save(_ a: Account) {
        account = a; error = nil
        Keychain.save(a)
        if let n = a.name, !n.isEmpty, JungleSettings.shared.ownerName.isEmpty { JungleSettings.shared.ownerName = n }
    }
}

fileprivate enum Keychain {
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
