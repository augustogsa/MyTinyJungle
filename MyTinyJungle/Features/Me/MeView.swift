import SwiftUI
import SwiftData

/// Me: your jungle at a glance, milestones, places and account.
struct MeView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    HStack(spacing: 10) {
                        NavigationLink { SpacesView() } label: { shortcut(.home, "Spaces", "\(Set(plants.map(\.location).filter { !$0.isEmpty }).count) rooms") }
                        NavigationLink { PropagationListView() } label: { shortcut(.seedling, "Cuttings", props.isEmpty ? "Start one" : "\(props.count) growing") }
                    }
                    .buttonStyle(.plain)
                    milestones
                    if !store.isPlus { plusCard }
                    JungleGroup(title: "Your jungle") {
                        NavigationLink { GuidesView() } label: { JungleRow(icon: .tools, title: "How-to guides", chevron: true) }
                        JungleDivider()
                        NavigationLink { TravelPlanView() } label: { JungleRow(icon: .travel, title: "Going away", subtitle: "Plan care for a trip", chevron: true) }
                    }
                    .buttonStyle(.plain)
                    JungleGroup(title: "Account") {
                        Button { if store.isPlus { settings = true } else { paywall = .morePlants } } label: {
                            JungleRow(icon: .crown, title: "Tiny Jungle Plus", chevron: true) { Text(store.isPlus ? "Active" : "Free").foregroundStyle(Jungle.subtle) }
                        }
                        JungleDivider()
                        Button { settings = true } label: { JungleRow(icon: .profile, title: "Settings", chevron: true) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .jungleBackdrop()
            .navigationTitle("Me")
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $paywall) { PaywallView(reason: $0) }
        }
    }

    // MARK: header: your jungle at a glance (plant photos, name, three numbers)

    private var header: some View {
        Button { settings = true } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: -14) {
                        ForEach(Array(plants.prefix(4).enumerated()), id: \.offset) { _, p in
                            PlantAvatar(data: p.photo, size: 46).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 3))
                        }
                        if plants.isEmpty { Icon3DView(.pottedSprout, size: 46) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.7)
                        Text((store.isPlus ? "Plus · " : "") + "Growing since \(since.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 0) {
                    stat("\(plants.count)", plants.count == 1 ? "plant" : "plants")
                    Divider().frame(height: 30)
                    stat("\(happy)", "happy")
                    Divider().frame(height: 30)
                    stat("\(careCount)", "care moments")
                    Divider().frame(height: 30)
                    stat(daysTogether >= 365 ? "\(daysTogether / 365)" : "\(daysTogether)", daysTogether >= 730 ? "years" : daysTogether >= 365 ? "year" : "days")
                }
                .padding(.vertical, 10)
                .background(Jungle.mint.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius + 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius + 4, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens settings")
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 0) {
            Text(v).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Text(l).font(.caption2).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortcut(_ icon: Icon3D, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            Icon3DView(icon, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                Text(sub).font(.caption).foregroundStyle(Jungle.subtle)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
    }

    // MARK: milestones

    private struct Milestone: Identifiable { let id: String; let icon: Icon3D; let title: String; let progress: Double; let detail: String
        var done: Bool { progress >= 1 } }
    private var milestoneList: [Milestone] {
        let waters = events.filter { $0.kind == .water }.count
        let leaves = events.filter { $0.kind == .newLeaf }.count
        func r(_ a: Int, _ b: Int) -> Double { b == 0 ? 0 : min(1, Double(a) / Double(b)) }
        return [
            .init(id: "first", icon: .pottedSprout, title: "First plant", progress: r(plants.count, 1), detail: "Add your first plant"),
            .init(id: "five", icon: .plantStand, title: "Little jungle", progress: r(plants.count, 5), detail: "\(min(plants.count, 5)) of 5 plants"),
            .init(id: "leaf", icon: .sprout, title: "New growth", progress: r(leaves, 3), detail: "\(min(leaves, 3)) of 3 new leaves logged"),
            .init(id: "prop", icon: .seedling, title: "Propagator", progress: r(props.count, 1), detail: "Start your first cutting"),
            .init(id: "happy", icon: .award, title: "All happy", progress: plants.isEmpty ? 0 : r(happy, plants.count), detail: "\(happy) of \(plants.count) plants happy"),
            .init(id: "water", icon: .waterDrops, title: "Hydration hero", progress: r(waters, 50), detail: "\(min(waters, 50)) of 50 waterings"),
            .init(id: "year", icon: .blossomTree, title: "One year", progress: r(daysTogether, 365), detail: "\(min(daysTogether, 365)) of 365 days"),
        ]
    }

    private var milestones: some View {
        let list = milestoneList
        let next = list.filter { !$0.done }.max { $0.progress < $1.progress }
        return JungleGroup(title: "Milestones · \(list.filter(\.done).count) of \(list.count)") {
            if let next {
                HStack(spacing: 12) {
                    Icon3DView(next.icon, size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Next: \(next.title)").font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                            Spacer()
                            Text("\(Int(next.progress * 100))%").font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                        }
                        ProgressView(value: next.progress).tint(Jungle.leaf)
                        Text(next.detail).font(.caption).foregroundStyle(Jungle.subtle)
                    }
                }
                .padding(.vertical, 12)
                Divider()
            }
            HStack(spacing: 0) {
                ForEach(list) { m in
                    Icon3DView(m.icon, size: 30)
                        .saturation(m.done ? 1 : 0).opacity(m.done ? 1 : 0.35)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(m.title), \(m.done ? "earned" : m.detail)")
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var plusCard: some View {
        Button { paywall = .morePlants } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tiny Jungle Plus").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text("Room for every plant you love, the right food for each one, and no ads.").font(.subheadline).foregroundStyle(Jungle.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Icon3DView(.crown, size: 48)
            }
            .padding(16)
            .background(Jungle.sun.opacity(0.25), in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
