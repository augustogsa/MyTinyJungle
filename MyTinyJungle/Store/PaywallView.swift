import SwiftUI
import StoreKit

/// Compact paywall: short header, benefits, then a plan carousel (yearly first) and one buy button.
struct PaywallView: View {
    var reason: PlusFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var products: [Product] = []
    @State private var selected: Product.ID?
    @State private var buying = false
    @State private var height: CGFloat = 700

    private var ordered: [Product] { products.sorted { ($0.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) < ($1.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) } }
    private var current: Product? { ordered.first { $0.id == selected } ?? ordered.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tiny Jungle Plus").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(reason?.title ?? "Give every plant the love it deserves.")
                            .font(.body).foregroundStyle(Jungle.subtle)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        perk(.pottedPlant, "Room for every plant you love", "No limits on your growing family.")
                        perk(.shieldStar, "Calm, ad-free care", "Just you and your plants, nothing in between.")
                        perk(.fertilizer, "The right food for each plant", "Scan any soil or fertilizer and see who will thrive on it.")
                        perk(.healthShield, "Plant Doctor, always first", "New ways to keep your plants healthy reach you first.")
                    }
                    plans
                    footer
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 70 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .presentationDetents([.height(height)])
            .jungleBackdrop()
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() } } }
            .task {
                products = (try? await Product.products(for: Store.productIDs)) ?? []
                selected = ordered.first?.id
            }
        }
    }

    private func perk(_ icon: Icon3D, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Icon3DView(icon, size: 34).frame(width: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(detail).font(.subheadline).foregroundStyle(Jungle.subtle)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var plans: some View {
        HStack(spacing: 12) {
            if ordered.isEmpty { ProgressView().frame(height: 120).frame(maxWidth: .infinity) }
            ForEach(ordered) { p in planCard(p) }
        }
    }

    private func planCard(_ p: Product) -> some View {
        let yearly = p.subscription?.subscriptionPeriod.unit == .year
        let on = p.id == (selected ?? ordered.first?.id)
        let monthly = ordered.first { $0.subscription?.subscriptionPeriod.unit == .month }
        let save: Int? = {
            guard yearly, let m = monthly else { return nil }
            let full = NSDecimalNumber(decimal: m.price * 12).doubleValue, y = NSDecimalNumber(decimal: p.price).doubleValue
            return full > 0 ? Int(((1 - y / full) * 100).rounded()) : nil
        }()
        return Button { selected = p.id } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(yearly ? "Yearly" : "Monthly").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(on ? Jungle.forest : Jungle.subtle.opacity(0.5))
                }
                Text(p.displayPrice).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text(yearly ? "\((p.price / 12).formatted(p.priceFormatStyle))/month" : "per month")
                    .font(.caption).foregroundStyle(Jungle.subtle)
                if let save, save > 0 {
                    Text("Save \(save)%").font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Jungle.mint, in: Capsule())
                } else { Text(" ").font(.caption).padding(.vertical, 3) }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(on ? Jungle.forest : Jungle.border, lineWidth: on ? 2 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let p = current else { return }
                buying = true
                Task {
                    if case .success(.verified) = try? await purchase(p) { await Store.shared.refresh(); dismiss() }
                    buying = false
                }
            } label: {
                Group { if buying { ProgressView().tint(.white) } else { Text("Continue").font(.headline) } }
                    .frame(maxWidth: .infinity).frame(height: 50)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Jungle.forest)
            .disabled(current == nil || buying)
            HStack(spacing: 16) {
                Button("Restore") { Task { await Store.shared.restore(); if Store.shared.isPlus { dismiss() } } }
                Link("Terms", destination: URL(string: "https://www.simpleappscompany.com/mytinyjungle/terms")!)
                Link("Privacy", destination: URL(string: "https://www.simpleappscompany.com/mytinyjungle/privacy")!)
            }
            .font(.footnote).foregroundStyle(Jungle.subtle)
            Text("Renews automatically. Cancel anytime in Settings, no hard feelings.").font(.caption2).foregroundStyle(Jungle.subtle)
        }
    }
}
