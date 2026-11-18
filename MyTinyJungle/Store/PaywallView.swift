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

    private var ordered: [Product] { products.sorted { ($0.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) < ($1.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) } }
    private var current: Product? { ordered.first { $0.id == selected } ?? ordered.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tiny Jungle Plus").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(reason?.title ?? "Everything your jungle needs, without ads.")
                            .font(.body).foregroundStyle(Jungle.subtle)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        perk(.pottedPlant, "Unlimited plants", "Grow your jungle past the free limit.")
                        perk(.shieldStar, "No ads", "A calm app, nothing in the way.")
                        perk(.fertilizer, "Scan every label", "See which plants a soil or fertilizer suits.")
                        perk(.healthShield, "Plant Doctor first", "New insights reach Plus before anyone.")
                    }
                    plans
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { footer }
            .jungleBackdrop()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } } }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if ordered.isEmpty { ProgressView().frame(height: 120).frame(maxWidth: .infinity) }
                ForEach(ordered) { p in planCard(p) }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
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
                Text(p.displayPrice).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text(yearly ? "per year · \((p.price / 12).formatted(p.priceFormatStyle))/month" : "per month")
                    .font(.caption).foregroundStyle(Jungle.subtle)
                if let save, save > 0 {
                    Text("Save \(save)%").font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Jungle.mint, in: Capsule())
                } else { Text(" ").font(.caption).padding(.vertical, 3) }
            }
            .padding(16).frame(width: 220, alignment: .leading)
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
            Text("Renews automatically. Cancel anytime in Settings.").font(.caption2).foregroundStyle(Jungle.subtle)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
        .background(.bar)
    }
}
