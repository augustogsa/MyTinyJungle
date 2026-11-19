import SwiftUI

/// Referral links: https://mytinyjungle.com/r/<code>. A friend who installs from the link and signs in
/// within a week gets a month of Plus, and so does the sender (granted by the server).
enum Referrals {
    private static let pendingKey = "referral.pending"

    static func code(from url: URL) -> String? {
        let p = url.pathComponents
        guard let i = p.firstIndex(of: "r"), i + 1 < p.count else { return nil }
        let c = p[i + 1].uppercased()
        return c.count == 8 && c.allSatisfy({ $0.isLetter || $0.isNumber }) ? c : nil
    }

    /// Keeps the code until there is an account to redeem it with.
    static func received(_ code: String) async {
        UserDefaults.standard.set(code, forKey: pendingKey)
        await redeemPending()
    }

    static func redeemPending() async {
        guard JungleAPI.shared.hasSession, let code = UserDefaults.standard.string(forKey: pendingKey) else { return }
        do {
            let _: JungleAPI.EntitlementsResponse = try await JungleAPI.shared.send("POST", "/v1/referrals/\(code)/redeem", body: JungleAPI.Empty())
            UserDefaults.standard.removeObject(forKey: pendingKey)
            await Store.shared.refresh()
        } catch JungleAPI.APIError.http(let status, _) where (400..<500).contains(status) {
            UserDefaults.standard.removeObject(forKey: pendingKey) // used, too old, own code: nothing to retry
        } catch {}
    }

    struct Mine: Decodable { var code: String; var url: String; var joined: Int }
    static func mine() async -> Mine? { try? await JungleAPI.shared.get("/v1/me/referral") }
}

/// Settings row: share your link; both of you get a month of Plus.
struct ReferralRow: View {
    @State private var mine: Referrals.Mine?
    var body: some View {
        Group {
            if let mine, let url = URL(string: mine.url) {
                ShareLink(item: url, message: Text(Grammar.pt(String(localized: "I care for my plants with My Tiny Jungle. Get it with my link and we both get a month of Plus.", comment: "Referral share message; friendly; max 140 chars")))) {
                    JungleRow(icon: .award, title: Grammar.pt(String(localized: "Invite a friend", comment: "Settings row: share referral link")),
                              subtitle: Grammar.pt(String(localized: "You both get a month of Plus · \(mine.joined) joined", comment: "Referral row subtitle; %lld friends who joined")), chevron: true)
                }.buttonStyle(.plain)
            }
        }
        .task { if JungleAPI.shared.hasSession { mine = await Referrals.mine() } }
    }
}
