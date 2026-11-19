import Foundation
import StoreKit
import Observation

/// My Tiny Jungle Plus: €1.99/month or €11.99/year. StoreKit 2, verified on device and on the server, so Plus
/// bought on any platform unlocks every device signed in to the account.
@Observable
final class Store {
    static let shared = Store()
    static let groupName = "My Tiny Jungle"
    static let monthlyID = "com.simpleappscompany.mytinyjungle.plus.monthly"
    static let yearlyID = "com.simpleappscompany.mytinyjungle.plus.yearly"
    static let productIDs = [monthlyID, yearlyID]
    static let freePlantLimit = 5

    private(set) var isPlus = false
    /// True when the active plan is the yearly Jungle plan; false for Greenhouse (monthly).
    private(set) var isYearly = false
    /// Name of the active plan, as on the website: Greenhouse (monthly) or Jungle (yearly).
    var planName: String { isYearly ? Grammar.pt(String(localized: "Jungle", comment: "Yearly plan name")) : Grammar.pt(String(localized: "Greenhouse", comment: "Monthly plan name")) }
    private(set) var products: [Product] = []
    private var updates: Task<Void, Never>?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-plus") { isPlus = true }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result {
                    await self?.report(result.jwsRepresentation, id: t.id)
                    await t.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProducts() }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs))?.sorted { $0.price < $1.price } ?? []
    }

    /// Plus bought elsewhere (Android, another Apple ID) as the server sees it for this account.
    private var serverPlus = false

    /// Ties purchases to the account; the server only credits a transaction to this user id.
    var accountToken: UUID? { JungleAPI.shared.userID.flatMap(UUID.init(uuidString:)) }

    func refresh() async {
        var active = ProcessInfo.processInfo.arguments.contains("-plus"), yearly = active
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                active = true; yearly = t.productID == Self.yearlyID
                await report(result.jwsRepresentation, id: t.id)
            }
        }
        if JungleAPI.shared.hasSession, let me = try? await JungleAPI.shared.me() { serverPlus = me.plus }
        isPlus = active || serverPlus; isYearly = yearly
    }

    /// Sends a verified transaction to the server once, so other devices see Plus.
    func report(_ jws: String, id: UInt64) async {
        guard JungleAPI.shared.hasSession else { return }
        let key = "store.reported"
        var done = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let tag = "\(JungleAPI.shared.userID ?? "")/\(id)"
        guard !done.contains(tag) else { return }
        if (try? await JungleAPI.shared.postAppleTransaction(jws)) != nil {
            done.insert(tag)
            UserDefaults.standard.set(Array(done.suffix(200)), forKey: key)
        }
    }

    func didSignIn() async { await refresh() }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    func canAddPlant(current: Int) -> Bool { isPlus || current < Self.freePlantLimit }
}

enum PlusFeature: String, Identifiable {
    case morePlants, scanCompatibility, inventory
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morePlants: Grammar.pt(String(localized: "Room for more than \(Store.freePlantLimit) green friends", comment: "Plus feature title; arg is free plant limit"))
        case .scanCompatibility: Grammar.pt(String(localized: "See what suits each plant", comment: "Plus feature title"))
        case .inventory: Grammar.pt(String(localized: "Keep your growing inventory", comment: "Plus feature title"))
        }
    }
}
