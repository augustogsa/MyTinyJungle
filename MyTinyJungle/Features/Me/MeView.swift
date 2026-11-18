import SwiftUI
import SwiftData

/// Me: an Airbnb-style profile. Who you are as a plant parent, your milestones, your places and tools.
struct MeView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Query private var owned: [OwnedProduct]
    @Query private var props: [Propagation]
    @Query private var events: [CareEvent]
    @State private var settings = false
    @State private var paywall: PlusFeature?
    private var store = Store.shared
    private var name: String { JungleSettings.shared.ownerName.isEmpty ? "Plant parent" : JungleSettings.shared.ownerName }

    private var since: Date { plants.map(\.acquiredAt).min() ?? Date() }
    private var daysTogether: Int { max(1, Int(CareEngine.days(from: since))) }
    private var careCount: Int { events.filter { ![.photo, .note].contains($0.kind) }.count }
    private var happy: Int { plants.filter { CareEngine.mood(for: $0) != .needsYou }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profileCard
                    HStack(spacing: 12) {
                        NavigationLink { SpacesView() } label: { bigTile(.home, "My spaces", "\(Set(plants.map(\.location).filter { !$0.isEmpty }).count) rooms") }
                        NavigationLink { PropagationListView() } label: { bigTile(.seedling, "Propagation", props.isEmpty ? "Start a cutting" : "\(props.count) growing") }
                    }
                    .buttonStyle(.plain)
                    milestones
                    if !store.isPlus { plusCard }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your jungle").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).padding(.bottom, 4)
                        NavigationLink { ScanView() } label: { row(.fertilizer, "Inventory and shopping", owned.isEmpty ? nil : "\(owned.count)") }
                        Divider().padding(.leading, 58)
                        NavigationLink { GuidesView() } label: { row(.tools, "How-to guides", nil) }
                        Divider().padding(.leading, 58)
                        NavigationLink { TravelPlanView() } label: { row(.travel, "Going away", nil) }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).padding(.bottom, 4)
                        Button { if store.isPlus { settings = true } else { paywall = .morePlants } } label: { row(.crown, "Tiny Jungle Plus", store.isPlus ? "Active" : "€1.99/mo") }
                        Divider().padding(.leading, 58)
                        Button { settings = true } label: { row(.profile, "Settings", nil) }
                        if !store.isPlus {
                            Divider().padding(.leading, 58)
                            Button { AdsManager.shared.presentPrivacyOptions() } label: { row(.shieldCheck, "Privacy & ads choices", nil) }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
            .jungleBackdrop()
            .navigationTitle("Profile")
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $paywall) { PaywallView(reason: $0) }
        }
    }

    // MARK: profile card (Airbnb host card: identity left, stats right)

    private var profileCard: some View {
        Button { settings = true } label: {
            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .background(LinearGradient(colors: [Jungle.leaf, Jungle.forest], startPoint: .top, endPoint: .bottom), in: Circle())
                        Icon3DView(store.isPlus ? .crown : .shieldLeaf, size: 34)
                            .offset(x: 6, y: 4)
                    }
                    Text(name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.7)
                    Text((store.isPlus ? "Plus · " : "") + "Growing since \(since.formatted(.dateTime.month(.abbreviated).year()))").font(.subheadline).foregroundStyle(Jungle.subtle)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 0) {
                    stat("\(plants.count)", plants.count == 1 ? "Plant" : "Plants")
                    Divider()
                    stat("\(careCount)", "Care moments")
                    Divider()
                    stat(daysTogether >= 365 ? "\(daysTogether / 365)" : "\(daysTogether)", daysTogether >= 365 ? "Years growing" : "Days growing")
                }
                .frame(width: 120)
            }
            .padding(.vertical, 22).padding(.horizontal, 12)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens settings")
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(v).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            Text(l).font(.caption2.weight(.medium)).foregroundStyle(Jungle.subtle)
        }
        .padding(.vertical, 8)
    }

    private func bigTile(_ icon: Icon3D, _ title: String, _ sub: String) -> some View {
        VStack(spacing: 10) {
            Icon3DView(icon, size: 72)
            VStack(spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(sub).font(.caption).foregroundStyle(Jungle.subtle)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    // MARK: milestones

    private struct Milestone: Identifiable { let id: String; let icon: Icon3D; let title: String; let done: Bool; let detail: String }
    private var milestoneList: [Milestone] {
        let waters = events.filter { $0.kind == .water }.count
        let leaves = events.filter { $0.kind == .newLeaf }.count
        return [
            .init(id: "first", icon: .pottedSprout, title: "First plant", done: !plants.isEmpty, detail: "Add a plant"),
            .init(id: "five", icon: .plantStand, title: "Little jungle", done: plants.count >= 5, detail: "\(min(plants.count, 5))/5 plants"),
            .init(id: "water", icon: .waterDrops, title: "Hydration hero", done: waters >= 50, detail: "\(min(waters, 50))/50 drinks"),
            .init(id: "leaf", icon: .sprout, title: "New growth", done: leaves >= 3, detail: "\(min(leaves, 3))/3 new leaves"),
            .init(id: "prop", icon: .seedling, title: "Propagator", done: !props.isEmpty, detail: "Start a cutting"),
            .init(id: "happy", icon: .award, title: "All happy", done: !plants.isEmpty && happy == plants.count, detail: "\(happy)/\(plants.count) happy"),
            .init(id: "year", icon: .blossomTree, title: "One year", done: daysTogether >= 365, detail: "\(min(daysTogether, 365))/365 days"),
        ]
    }

    private var milestones: some View {
        let list = milestoneList
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Milestones").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Spacer()
                Text("\(list.filter(\.done).count) of \(list.count)").font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(list) { m in
                        VStack(spacing: 8) {
                            Icon3DView(m.icon, size: 56)
                                .saturation(m.done ? 1 : 0).opacity(m.done ? 1 : 0.45)
                            Text(m.title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text).lineLimit(1)
                            Text(m.done ? "Unlocked" : m.detail).font(.caption2).foregroundStyle(m.done ? Jungle.accentText : Jungle.subtle)
                        }
                        .frame(width: 112).padding(.vertical, 14)
                        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var plusCard: some View {
        Button { paywall = .morePlants } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tiny Jungle Plus").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text("Unlimited plants, label scanning for every plant and no ads.").font(.subheadline).foregroundStyle(Jungle.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Icon3DView(.crown, size: 64)
            }
            .padding(18)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func row(_ icon: Icon3D, _ t: String, _ v: String?) -> some View {
        HStack(spacing: 14) {
            Icon3DView(icon, size: 40).frame(width: 44)
            Text(t).font(.body).foregroundStyle(Jungle.text)
            Spacer()
            if let v { Text(v).foregroundStyle(Jungle.subtle) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.subtle)
        }
        .padding(.vertical, 10).contentShape(Rectangle())
    }
}
