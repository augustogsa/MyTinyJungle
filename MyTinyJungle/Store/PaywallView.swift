import SwiftUI
import StoreKit

struct PaywallView: View {
    var reason: PlusFeature?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: Store.productIDs) {
            VStack(spacing: 14) {
                Image(systemName: "leaf.circle.fill").font(.system(size: 56)).foregroundStyle(Jungle.forest).accessibilityHidden(true)
                Text("Tiny Jungle Plus").font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                if let reason { Text(reason.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.leaf) }
                VStack(alignment: .leading, spacing: 10) {
                    perk("leaf", "Unlimited plants")
                    perk("barcode.viewfinder", "Scan soil & fertilizer: see which plants it suits")
                    perk("tray.full", "Growing inventory & shopping list")
                    perk("stethoscope", "Plant Doctor & memory insights, coming first to Plus")
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Jungle.cream)
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.simpleappscompany.com/mytinyjungle/terms")!, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.simpleappscompany.com/mytinyjungle/privacy")!, for: .privacyPolicy)
        .tint(Jungle.forest)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result { await Store.shared.refresh(); dismiss() }
        }
    }

    private func perk(_ symbol: String, _ text: String) -> some View {
        Label { Text(text).foregroundStyle(Jungle.text) } icon: { Image(systemName: symbol).foregroundStyle(Jungle.leaf) }
    }
}
