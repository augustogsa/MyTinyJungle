import SwiftUI
import SwiftData

/// Me: collection health, whisper, spaces, inventory, Plus and settings.
struct MeView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Query private var owned: [OwnedProduct]
    @Query private var props: [Propagation]
    @State private var settings = false
    @State private var paywall: PlusFeature?
    private var store = Store.shared

    private var moods: [CareEngine.Mood] { plants.map { CareEngine.mood(for: $0) } }
    private var thriving: Int { moods.filter { $0 == .thriving }.count }
    private var fine: Int { moods.filter { $0 == .fine }.count }
    private var needs: Int { moods.filter { $0 == .needsYou }.count }
    private var recovering: Int { plants.filter { p in p.lastEvent(.treat).map { CareEngine.days(from: $0.date) < 21 } ?? false }.count }
    private var score: Double { plants.isEmpty ? 0 : (Double(thriving) + Double(fine) * 0.7) / Double(plants.count) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(Jungle.mint, lineWidth: 12)
                            Circle().trim(from: 0, to: score).stroke(Jungle.leaf, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("\(Int(score * 100))%").font(.title2.weight(.bold)).foregroundStyle(Jungle.text)
                        }
                        .frame(width: 96, height: 96)
                        .accessibilityLabel("Collection health \(Int(score * 100)) percent")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Collection health").font(.headline).foregroundStyle(Jungle.text)
                            Text("\(plants.count) plants").foregroundStyle(Jungle.subtle)
                        }
                        Spacer()
                    }
                    .padding(16).jungleCard()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        stat("Thriving", thriving, Jungle.leaf)
                        stat("Doing fine", fine, Jungle.sage)
                        stat("Recovering", recovering, Jungle.sun)
                        stat("Needs you", needs, Jungle.terracotta)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Plant whisper", systemImage: "leaf.fill").font(.headline).foregroundStyle(Jungle.forest)
                        Text(whisper).foregroundStyle(Jungle.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Jungle.mint, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                    VStack(spacing: 0) {
                        NavigationLink { SpacesView() } label: { row("Spaces", "house", nil) }
                        Divider()
                        NavigationLink { PropagationListView() } label: { row("Propagation", "scissors", props.isEmpty ? nil : "\(props.count)") }
                        Divider()
                        NavigationLink { ScanView() } label: { row("Inventory and shopping", "tray.full", owned.isEmpty ? nil : "\(owned.count)") }
                        Divider()
                        Button { if !store.isPlus { paywall = .morePlants } } label: { row("Tiny Jungle Plus", "sparkle", store.isPlus ? "Active" : "€1.99/mo") }
                        Divider()
                        Button { settings = true } label: { row("Settings", "gearshape", nil) }
                    }
                    .buttonStyle(.plain).jungleCard()
                }
                .padding(16)
            }
            .background(Jungle.cream)
            .navigationTitle(JungleSettings.shared.ownerName.isEmpty ? "Me" : JungleSettings.shared.ownerName)
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $paywall) { PaywallView(reason: $0) }
        }
    }

    private var whisper: String {
        if plants.isEmpty { return "Your jungle is waiting for its first plant." }
        if let p = plants.first(where: { CareEngine.mood(for: $0) == .needsYou }) { return "\(p.name) could use a little attention today." }
        if let p = plants.max(by: { ($0.lastEvent(.newLeaf)?.date ?? .distantPast) < ($1.lastEvent(.newLeaf)?.date ?? .distantPast) }), p.lastEvent(.newLeaf) != nil { return "\(p.name) grew a new leaf recently. Keep doing what you're doing." }
        return "Everyone is happy. Rotate a pot today for even growth."
    }

    private func stat(_ t: String, _ n: Int, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(n)").font(.title.weight(.bold)).foregroundStyle(c)
            Text(t).font(.subheadline).foregroundStyle(Jungle.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14).jungleCard()
    }

    private func row(_ t: String, _ s: String, _ v: String?) -> some View {
        HStack {
            Image(systemName: s).foregroundStyle(Jungle.leaf).frame(width: 28)
            Text(t).foregroundStyle(Jungle.text)
            Spacer()
            if let v { Text(v).foregroundStyle(Jungle.subtle) }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Jungle.subtle)
        }
        .padding(14).contentShape(Rectangle())
    }
}
