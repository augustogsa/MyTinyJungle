import SwiftUI
import StoreKit
import SwiftData

/// Compact paywall: short header, benefits, then a plan carousel (yearly first) and one buy button.
struct PaywallView: View {
    var reason: PlusFeature?
    /// Plan to preselect, from a website link: "monthly" or "yearly".
    var plan: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @State private var products: [Product] = []
    @State private var selected: Product.ID?
    @State private var buying = false
    @State private var height: CGFloat = 700
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    private var ordered: [Product] { products.sorted { ($0.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) < ($1.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) } }
    private var current: Product? { ordered.first { $0.id == selected } ?? ordered.first }

    var body: some View { tracked.screen("paywall") }
    @ViewBuilder private var tracked: some View {
        DuoCompanion(mood: .award, title: "Grow without limits", detail: "Every plant, every tool, all in one place.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    VStack(alignment: .leading, spacing: 18) {
                        perk(.pottedPlant, Grammar.pt(String(localized: "Every plant gets a place", comment: "Paywall benefit title; max 32 chars")), Grammar.pt(String(localized: "Adopt as many green friends as your windowsills can hold.", comment: "Paywall benefit detail")))
                        perk(.firstAid, Grammar.pt(String(localized: "Catch trouble early", comment: "Paywall benefit title; max 32 chars")), Grammar.pt(String(localized: "A droopy leaf or a yellow tip? You'll know what to do before it gets worse.", comment: "Paywall benefit detail")))
                        perk(.fertilizer, Grammar.pt(String(localized: "The right food, every time", comment: "Paywall benefit title; max 32 chars")), Grammar.pt(String(localized: "Scan a bag of soil or fertilizer and see which plants will love it.", comment: "Paywall benefit detail")))
                        perk(.careHands, Grammar.pt(String(localized: "Just you and your plants", comment: "Paywall benefit title; max 32 chars")), Grammar.pt(String(localized: "No ads. Quiet, calm care, the way it should feel.", comment: "Paywall benefit detail")))
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
                let want = plan == "monthly" ? Store.monthlyID : plan == "yearly" ? Store.yearlyID : nil
                selected = ordered.first { $0.id == want }?.id ?? ordered.first?.id
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
        case .morePlants: Grammar.pt(String(localized: "Your jungle is ready to grow", comment: "Paywall headline"))
        case .scanCompatibility: Grammar.pt(String(localized: "Feed them what they love", comment: "Paywall headline"))
        case .inventory: Grammar.pt(String(localized: "Everything they need, in one place", comment: "Paywall headline"))
        case nil: Grammar.pt(String(localized: "Give every plant the love it deserves", comment: "Paywall headline"))
        }
    }

    private var subline: String {
        let names = plants.prefix(2).map(\.name)
        if names.count == 2 {
            switch reason {
            case .morePlants: return Grammar.pt(String(localized: "\(names[0]), \(names[1]) and the rest of the family would love some company. Greenhouse and Jungle make room for all of them.", comment: "Paywall subline; args are two plant names"))
            default: return Grammar.pt(String(localized: "\(names[0]), \(names[1]) and the rest of the family will thank you. Greenhouse and Jungle give you everything to keep them happy.", comment: "Paywall subline; args are two plant names"))
            }
        }
        switch reason {
        case .morePlants: return Grammar.pt(String(localized: "Your plants would love some company. Greenhouse and Jungle make room for all of them.", comment: "Paywall subline"))
        default: return Grammar.pt(String(localized: "Your plants will thank you. Greenhouse and Jungle give you everything to keep them happy.", comment: "Paywall subline"))
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
            if ordered.isEmpty { ErtyView(mood: .idle, size: 96).frame(height: 120).frame(maxWidth: .infinity) }
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
                    VStack(alignment: .leading, spacing: 0) {
                        Text(yearly ? Grammar.pt(String(localized: "Jungle", comment: "Paywall yearly plan name, same as the website")) : Grammar.pt(String(localized: "Greenhouse", comment: "Paywall monthly plan name, same as the website"))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        Text(yearly ? Grammar.pt(String(localized: "Yearly", comment: "Paywall plan period")) : Grammar.pt(String(localized: "Monthly", comment: "Paywall plan period"))).font(.caption2.weight(.semibold)).foregroundStyle(Jungle.subtle)
                    }
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(on ? Jungle.forest : Jungle.tertiary)
                }
                Text(p.displayPrice).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text(yearly ? Grammar.pt(String(localized: "\((p.price / 12).formatted(p.priceFormatStyle))/month", comment: "Paywall: yearly price per month; arg is price")) : Grammar.pt(String(localized: "per month", comment: "Paywall: monthly plan caption")))
                    .font(.caption).foregroundStyle(Jungle.subtle)
                if let save, save > 0 {
                    Text(Grammar.pt(String(localized: "Save \((Double(save) / 100).formatted(.percent))", comment: "Paywall yearly saving badge; arg is percent like 40%"))).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
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
                    if case .success(.verified) = try? await purchase(p, options: Store.shared.accountToken.map { [.appAccountToken($0)] } ?? []) { await Store.shared.refresh(); dismiss() }
                    buying = false
                }
            } label: {
                Group { if buying { ProgressView().tint(.white) } else { Text(current.map { $0.subscription?.subscriptionPeriod.unit == .year ? Grammar.pt(String(localized: "Start Jungle · \($0.displayPrice)/year", comment: "Paywall buy button for the yearly plan named Jungle; arg is price")) : Grammar.pt(String(localized: "Start Greenhouse · \($0.displayPrice)/month", comment: "Paywall buy button for the monthly plan named Greenhouse; arg is price")) } ?? Grammar.pt(String(localized: "Choose a plan", comment: "Paywall buy button"))).font(.headline) } }
                    .frame(maxWidth: .infinity).frame(height: 50)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).junglePrimary()
            .disabled(current == nil || buying)
            HStack(spacing: 16) {
                Button("Restore") { Task { await Store.shared.restore(); if Store.shared.isPlus { dismiss() } } }
                Link("Terms", destination: URL(string: "https://www.mytinyjungle.com/terms")!)
                Link("Privacy", destination: URL(string: "https://www.mytinyjungle.com/privacy")!)
            }
            .font(.footnote).foregroundStyle(Jungle.subtle)
            Text("Renews automatically. Cancel anytime in Settings, no hard feelings. Your plants stay yours either way.").font(.caption2).foregroundStyle(Jungle.subtle)
        }
    }
}
