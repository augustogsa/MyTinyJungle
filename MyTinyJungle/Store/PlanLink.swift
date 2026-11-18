import SwiftUI

/// Links from mytinyjungle.com ("Choose this plan") open the paywall with that plan selected:
/// https://www.mytinyjungle.com/plus?plan=yearly (or /pt/plus).
enum PlanLink {
    static let key = "openPaywallPlan"

    @discardableResult
    static func handle(_ url: URL) -> Bool {
        guard let host = url.host(), host.hasSuffix("mytinyjungle.com"),
              url.path().hasSuffix("/plus") else { return false }
        let plan = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "plan" }?.value
        UserDefaults.standard.set(plan == "monthly" ? "monthly" : "yearly", forKey: key)
        return true
    }
}

/// Presents the paywall when a plan link arrives, once the user is past sign-in and setup.
struct PlanLinkSheet: ViewModifier {
    @AppStorage(PlanLink.key) private var plan = ""
    @State private var shown: String?
    func body(content: Content) -> some View {
        content
            .onChange(of: plan, initial: true) { _, p in if !p.isEmpty { shown = p; plan = "" } }
            .sheet(item: Binding(get: { shown.map { Wrapped(id: $0) } }, set: { shown = $0?.id })) { PaywallView(plan: $0.id) }
    }
    private struct Wrapped: Identifiable { let id: String }
}
