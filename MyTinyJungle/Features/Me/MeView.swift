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
    private var name: String { JungleSettings.shared.ownerName.isEmpty ? Grammar.pt(String(localized: "Plant parent", comment: "Me tab header fallback when owner has no name; max 20 chars")) : JungleSettings.shared.ownerName }

    private var sinceText: String { since.formatted(.dateTime.month(.abbreviated).year()) }
    private var roomCount: Int { Set(plants.map(\.location).filter { !$0.isEmpty }).count }
    private var since: Date { plants.map(\.acquiredAt).min() ?? Date() }
    private var daysTogether: Int { max(1, Int(CareEngine.days(from: since))) }
    private var careCount: Int { events.filter { ![.photo, .note].contains($0.kind) }.count }
    private var happy: Int { plants.filter { !CareEngine.needsYou($0) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TabHeader(title: name, subtitle: store.isPlus ? Grammar.pt(String(localized: "Plus · Growing since \(sinceText)", comment: "Me header subtitle for Plus members; arg is month+year")) : Grammar.pt(String(localized: "Growing since \(sinceText)", comment: "Me header subtitle; arg is month+year like Mar 2025"))) {
                        HeaderButton(symbol: "gearshape", label: Grammar.pt(String(localized: "Settings", comment: "Accessibility label for settings button"))) { settings = true }
                    }
                    header
                    HStack(spacing: 10) {
                        NavigationLink { SpacesView() } label: { shortcut(.home, Grammar.pt(String(localized: "Spaces", comment: "Me shortcut title: rooms in the home")), Grammar.pt(String(localized: "\(roomCount) rooms", comment: "Me shortcut subtitle: number of rooms with plants"))) }
                        NavigationLink { PropagationListView() } label: { shortcut(.seedling, Grammar.pt(String(localized: "Cuttings", comment: "Me shortcut title: propagation cuttings")), props.isEmpty ? Grammar.pt(String(localized: "Start one", comment: "Me cuttings shortcut subtitle when none")) : Grammar.pt(String(localized: "\(props.count) growing", comment: "Me cuttings shortcut subtitle: number of cuttings growing"))) }
                    }
                    .buttonStyle(.plain)
                    SharedJungleRow()
                    milestones
                    if !store.isPlus { plusCard }
                    JungleGroup(title: Grammar.pt(String(localized: "Your jungle", comment: "Me section title"))) {
                        NavigationLink { GuidesView() } label: { JungleRow(icon: .tools, title: Grammar.pt(String(localized: "How-to guides", comment: "Me row title")), chevron: true) }
                        JungleDivider()
                        NavigationLink { TravelPlanView() } label: { JungleRow(icon: .travel, title: Grammar.pt(String(localized: "Going away", comment: "Me row title: travel plan")), subtitle: Grammar.pt(String(localized: "Plan care for a trip", comment: "Me row subtitle")), chevron: true) }
                    }
                    .buttonStyle(.plain)
                    JungleGroup(title: Grammar.pt(String(localized: "Account", comment: "Me section title"))) {
                        Button { if store.isPlus { settings = true } else { paywall = .morePlants } } label: {
                            JungleRow(icon: .addPlant, title: "My Tiny Jungle Plus", chevron: true) { Text(store.isPlus ? "Active" : "Free").foregroundStyle(Jungle.subtle) }
                        }
                        JungleDivider()
                        Button { settings = true } label: { JungleRow(icon: .profile, title: Grammar.pt(String(localized: "Settings", comment: "Me row title")), chevron: true) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .jungleBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let p = plants.first(where: { $0.id == id }) { PlantHomeView(plant: p) }
            }
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $paywall) { PaywallView(reason: $0) }
        }
    }

    // MARK: header: your jungle at a glance (plant photos, name, three numbers)

    private var header: some View {
        NavigationLink { JungleHealthView() } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    HStack(spacing: -14) {
                        ForEach(Array(plants.prefix(4).enumerated()), id: \.offset) { _, p in
                            PlantAvatar(data: p.photo, size: 46).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 3))
                        }
                        if plants.isEmpty { Icon3DView(.pottedSprout, size: 46) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your jungle").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        Text(happy == plants.count ? Grammar.pt(String(localized: "Everyone's happy", comment: "Me header: all plants are fine")) : Grammar.pt(String(localized: "\(plants.count - happy) would love some attention", comment: "Me header: number of plants needing care")))
                            .font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 0) {
                    stat(plants.count.formatted(), plants.count == 1 ? Grammar.pt(String(localized: "plant", comment: "Me stat caption under a count of 1 plant")) : Grammar.pt(String(localized: "plants", comment: "Me stat caption under a plant count")))
                    Divider().frame(height: 30)
                    stat(happy.formatted(), Grammar.pt(String(localized: "happy", comment: "Me stat caption under number of happy plants; lowercase, short")))
                    Divider().frame(height: 30)
                    stat(careCount.formatted(), Grammar.pt(String(localized: "care moments", comment: "Me stat caption under number of care actions logged; short")))
                    Divider().frame(height: 30)
                    stat(daysTogether >= 365 ? (daysTogether / 365).formatted() : daysTogether.formatted(), daysTogether >= 730 ? Grammar.pt(String(localized: "years", comment: "Me stat caption: years together")) : daysTogether >= 365 ? Grammar.pt(String(localized: "year", comment: "Me stat caption: one year together")) : Grammar.pt(String(localized: "days", comment: "Me stat caption: days together")))
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
        .accessibilityHint(Text("Opens jungle health", comment: "Accessibility hint on Me header card"))
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

    struct Milestone: Identifiable { let id: String; let icon: Icon3D; let title: String; let progress: Double; let detail: String
        var done: Bool { progress >= 1 } }
    private var milestoneList: [Milestone] {
        let waters = events.filter { $0.kind == .water }.count
        let leaves = events.filter { $0.kind == .newLeaf }.count
        func r(_ a: Int, _ b: Int) -> Double { b == 0 ? 0 : min(1, Double(a) / Double(b)) }
        return [
            .init(id: "first", icon: .pottedSprout, title: Grammar.pt(String(localized: "First plant", comment: "Milestone title")), progress: r(plants.count, 1), detail: Grammar.pt(String(localized: "Add your first plant", comment: "Milestone detail"))),
            .init(id: "five", icon: .plantStand, title: Grammar.pt(String(localized: "Little jungle", comment: "Milestone title: have 5 plants")), progress: r(plants.count, 5), detail: Grammar.pt(String(localized: "\(min(plants.count, 5)) of 5 plants", comment: "Milestone progress detail"))),
            .init(id: "leaf", icon: .sprout, title: Grammar.pt(String(localized: "New growth", comment: "Milestone title")), progress: r(leaves, 3), detail: Grammar.pt(String(localized: "\(min(leaves, 3)) of 3 new leaves logged", comment: "Milestone progress detail"))),
            .init(id: "prop", icon: .seedling, title: Grammar.pt(String(localized: "Propagator", comment: "Milestone title: started a cutting")), progress: r(props.count, 1), detail: Grammar.pt(String(localized: "Start your first cutting", comment: "Milestone detail"))),
            .init(id: "happy", icon: .award, title: Grammar.pt(String(localized: "All happy", comment: "Milestone title")), progress: plants.isEmpty ? 0 : r(happy, plants.count), detail: Grammar.pt(String(localized: "\(happy) of \(plants.count) plants happy", comment: "Milestone progress detail"))),
            .init(id: "water", icon: .waterDrops, title: Grammar.pt(String(localized: "Hydration hero", comment: "Milestone title: 50 waterings")), progress: r(waters, 50), detail: Grammar.pt(String(localized: "\(min(waters, 50)) of 50 waterings", comment: "Milestone progress detail"))),
            .init(id: "year", icon: .blossomTree, title: Grammar.pt(String(localized: "One year", comment: "Milestone title")), progress: r(daysTogether, 365), detail: Grammar.pt(String(localized: "\(min(daysTogether, 365)) of 365 days", comment: "Milestone progress detail"))),
        ]
    }

    private var milestones: some View {
        let list = milestoneList
        let next = list.filter { !$0.done }.max { $0.progress < $1.progress }
        return NavigationLink { MilestonesView(list: list) } label: { JungleGroup(title: Grammar.pt(String(localized: "Milestones · \(list.filter(\.done).count) of \(list.count)", comment: "Me section title with earned/total milestones"))) {
            if let next {
                HStack(spacing: 12) {
                    Icon3DView(next.icon, size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Next: \(next.title)").font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                            Spacer()
                            Text(next.progress.formatted(.percent.precision(.fractionLength(0)))).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
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
                        .accessibilityLabel(m.done ? Grammar.pt(String(localized: "\(m.title), earned", comment: "Accessibility: milestone earned; arg is title")) : Grammar.pt(String(localized: "\(m.title), \(m.detail)", comment: "Accessibility: milestone title then progress detail")))
                }
            }
            .padding(.vertical, 12)
        } }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens all milestones", comment: "Accessibility hint on Me milestones card"))
    }

    private var plusCard: some View {
        Button { paywall = .morePlants } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My Tiny Jungle Plus").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text("Room for every plant you love, early help when one struggles, and the right food for each.").font(.subheadline).foregroundStyle(Jungle.text.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("See Plus").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Jungle.leaf, in: Capsule())
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
                Icon3DView(.addPlant, size: 56)
            }
            .padding(16)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.leaf.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Every milestone with its progress: earned ones on top, then the closest next.
struct MilestonesView: View {
    let list: [MeView.Milestone]
    private var sorted: [MeView.Milestone] { list.filter(\.done) + list.filter { !$0.done }.sorted { $0.progress > $1.progress } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JungleGroup(title: Grammar.pt(String(localized: "\(list.filter(\.done).count) of \(list.count) earned", comment: "Milestones screen section title"))) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { JungleDivider() }
                        HStack(spacing: 12) {
                            Icon3DView(m.icon, size: 40)
                                .saturation(m.done ? 1 : 0).opacity(m.done ? 1 : 0.45)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(m.title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                                    Spacer()
                                    if m.done {
                                        Label { Text("Earned", comment: "Milestone state") } icon: { Image(systemName: "checkmark") }
                                            .font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                                    } else {
                                        Text(m.progress.formatted(.percent.precision(.fractionLength(0)))).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                                    }
                                }
                                if !m.done { ProgressView(value: m.progress).tint(Jungle.leaf) }
                                Text(m.detail).font(.caption).foregroundStyle(Jungle.subtle)
                            }
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle(Text("Milestones", comment: "Milestones screen title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
