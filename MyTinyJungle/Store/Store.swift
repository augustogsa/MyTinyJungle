import Foundation
import StoreKit
import Observation

/// My Tiny Jungle Plus: €1.99/month or €11.99/year. StoreKit 2, verified on device.
@Observable
final class Store {
    static let shared = Store()
    static let groupName = "My Tiny Jungle Plus"
    static let monthlyID = "com.simpleappscompany.mytinyjungle.plus.monthly"
    static let yearlyID = "com.simpleappscompany.mytinyjungle.plus.yearly"
    static let productIDs = [monthlyID, yearlyID]
    static let freePlantLimit = 5

    private(set) var isPlus = false
    private(set) var products: [Product] = []
    private var updates: Task<Void, Never>?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-plus") { isPlus = true }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProducts() }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs))?.sorted { $0.price < $1.price } ?? []
    }

    func refresh() async {
        var active = ProcessInfo.processInfo.arguments.contains("-plus")
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil { active = true }
        }
        isPlus = active
    }

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
        case .morePlants: String(localized: "Room for more than \(Store.freePlantLimit) green friends", comment: "Plus feature title; arg is free plant limit")
        case .scanCompatibility: String(localized: "See what suits each plant", comment: "Plus feature title")
        case .inventory: String(localized: "Keep your growing inventory", comment: "Plus feature title")
        }
    }
}
