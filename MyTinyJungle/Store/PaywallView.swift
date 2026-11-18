import SwiftUI
import StoreKit
import SwiftData

/// Compact paywall: short header, benefits, then a plan carousel (yearly first) and one buy button.
struct PaywallView: View {
    var reason: PlusFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var products: [Product] = []
    @State private var selected: Product.ID?
    @State private var buying = false
    @State private var height: CGFloat = 700
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    private var ordered: [Product] { products.sorted { ($0.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) < ($1.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) } }
    private var current: Product? { ordered.first { $0.id == selected } ?? ordered.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    VStack(alignment: .leading, spacing: 18) {
                        perk(.pottedPlant, "Every plant gets a place", "Adopt as many green friends as your windowsills can hold.")
                        perk(.firstAid, "Catch trouble early", "A droopy leaf or a yellow tip? You'll know what to do before it gets worse.")
                        perk(.fertilizer, "The right food, every time", "Scan a bag of soil or fertilizer and see which plants will love it.")
                        perk(.careHands, "Just you and your plants", "No ads. Quiet, calm care, the way it should feel.")
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: -14) {
                ForEach(Array(plants.prefix(5).enumerated()), id: \.element.id) { i, p in
                    PlantAvatar(data: p.photo, size: 56)
                        .overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 3))
                        .zIndex(Double(10 - i))
                }
                if plants.isEmpty { Icon3DView(.pottedPlant, size: 56) }
                ZStack {
                    Circle().fill(Jungle.forest)
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 56, height: 56).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 3))
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(headline).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subline).font(.body).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headline: String {
        switch reason {
        case .morePlants: "Your jungle is ready to grow"
        case .scanCompatibility: "Feed them what they love"
        case .inventory: "Everything they need, in one place"
        case nil: "Give every plant the love it deserves"
        }
    }

    private var subline: String {
        let names = plants.prefix(2).map(\.name)
        let family = names.count == 2 ? "\(names[0]), \(names[1]) and the rest of the family" : "Your plants"
        switch reason {
        case .morePlants: return "\(family) would love some company. Plus makes room for all of them."
        default: return "\(family) will thank you. Plus gives you everything to keep them happy."
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
                Group { if buying { ProgressView().tint(.white) } else { Text(current.map { $0.subscription?.subscriptionPeriod.unit == .year ? "Grow with Plus · \($0.displayPrice)/year" : "Grow with Plus · \($0.displayPrice)/month" } ?? "Grow with Plus").font(.headline) } }
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
            Text("Renews automatically. Cancel anytime in Settings, no hard feelings. Your plants stay yours either way.").font(.caption2).foregroundStyle(Jungle.subtle)
        }
    }
}
