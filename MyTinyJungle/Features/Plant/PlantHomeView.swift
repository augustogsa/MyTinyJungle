import SwiftUI
import SwiftData
import PhotosUI

/// The plant's own page: hero photo, mood, quick actions, Overview / Story / Care / About.
struct PlantHomeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Query private var spaces: [Space]
    @Bindable var plant: Plant

    enum Tab: String, CaseIterable {
        case overview = "Overview", story = "Timeline", care = "Care", about = "About"
        var label: String {
            switch self {
            case .overview: String(localized: "Overview", comment: "Plant page segment; max 10 chars")
            case .story: String(localized: "Timeline", comment: "Plant page segment; max 10 chars")
            case .care: String(localized: "Care", comment: "Plant page segment; max 10 chars")
            case .about: String(localized: "About", comment: "Plant page segment; max 10 chars")
            }
        }
    }
    @State private var tab: Tab = .overview
    @State private var sheet: Sheet?
    @State private var guide: CareGuide?
    @State private var showGuides = false
    @State private var pick: PhotosPickerItem?

    enum Sheet: String, Identifiable { case water, health, repot, place, edit, propagate; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                actions
                Picker("Section", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.label) } }
                    .pickerStyle(.segmented).padding(.horizontal, 16)
                Group {
                    switch tab {
                    case .overview: overview
                    case .story: PlantStoryView(plant: plant, pick: $pick)
                    case .care: PlantCarePlanView(plant: plant)
                    case .about: PlantAboutView(plant: plant)
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
            .padding(.bottom, 32)
            .animation(.snappy, value: tab)
        }
        .ignoresSafeArea(edges: .top)
        .jungleBackdrop()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink { PlantChatView(plant: plant) } label: { Image(systemName: "bubble.left.and.bubble.right") }
                    .accessibilityLabel("Talk to \(plant.name)")
                Menu {
                    Button("Edit details", systemImage: "pencil") { sheet = .edit }
                    Button("Best place", systemImage: "house") { sheet = .place }
                    Button("Health check", systemImage: "stethoscope") { sheet = .health }
                    Button("Repotting check", systemImage: "arrow.up.bin") { sheet = .repot }
                    Button("Propagate", systemImage: "scissors") { sheet = .propagate }
                    PhotosPicker(selection: $pick, matching: .images) { Label("New photo", systemImage: "camera") }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .water: WaterSheet(plant: plant)
            case .health: HealthCheckView(plant: plant)
            case .repot: RepotCheckView(plant: plant)
            case .place: NavigationStack { BestPlaceView(plant: plant) }
            case .edit: PlantProfileView(plant: plant)
            case .propagate: NavigationStack { StartPropagationView(parent: plant) }
            }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self) {
                    let data = ImageShrinker.jpeg(d)
                    let e = CareEvent(kind: .photo, source: "profile"); e.photo = data; e.plant = plant
                    ctx.insert(e); plant.photo = data; try? ctx.save()
                }
                pick = nil
            }
        }
    }

    private var mood: CareEngine.Mood { CareEngine.mood(for: plant) }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear.frame(height: 380).frame(maxWidth: .infinity)
                .overlay {
                    if let d = plant.photo, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill() }
                    else { ZStack { Jungle.mint; Icon3DView(.pottedPlant, size: 120) } }
                }
                .clipped()
            let hasPhoto = plant.photo != nil
            if hasPhoto { LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom) }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(hasPhoto ? Color.white : Jungle.text)
                    Text(plant.species?.scientific ?? String(localized: "Unknown species", comment: "Shown when species not set; max 20 chars")).font(.subheadline).italic().foregroundStyle(hasPhoto ? Color.white.opacity(0.9) : Jungle.subtle)
                }
                Spacer()
                StatusBadge(status: CareEngine.status(for: plant))
            }
            .padding(.horizontal, 16).padding(.bottom, 50)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            ActionTile(title: String(localized: "Water", comment: "Quick action tile; verb; max 10 chars"), symbol: "drop.fill", tint: Jungle.forest) { sheet = .water }
            ActionTile(title: String(localized: "Feed", comment: "Quick action tile: fertilize; verb; max 10 chars"), symbol: "leaf.arrow.triangle.circlepath", tint: Jungle.leaf) {
                withAnimation { JungleBrain.quick(.feed, plants: [plant], in: ctx, announce: true) }
            }
            ActionTile(title: String(localized: "Repot", comment: "Quick action tile; verb; max 10 chars"), symbol: "arrow.up.bin", tint: Jungle.terracotta) { sheet = .repot }
            ActionTile(title: String(localized: "Check", comment: "Quick action tile: health check; max 10 chars"), symbol: "stethoscope", tint: Jungle.leaf) { sheet = .health }
        }
        .padding(.horizontal, 16)
        .offset(y: -34).padding(.bottom, -34)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            PlantForecastSection(plant: plant)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(String(localized: "How-to for \(plant.name)", comment: "Section title: guides for this plant; arg plant name"), action: String(localized: "All", comment: "Section action: see all; max 8 chars")) { showGuides = true }
                let picks = Array(GuideLibrary.suggested(for: plant).prefix(3))
                VStack(spacing: 0) {
                    ForEach(picks) { g in
                        Button { guide = g } label: { GuideRow(guide: g) }.buttonStyle(.plain)
                        if g.id != picks.last?.id { Divider().padding(.leading, 76) }
                    }
                }
                .jungleCard()
            }
            .fullScreenCover(item: $guide) { GuidePlayerView(guide: $0, plant: plant) }
            .navigationDestination(isPresented: $showGuides) { GuidesView(plant: plant) }
            NavigationLink { PlantChatView(plant: plant) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        PlantAvatar(data: plant.photo, size: 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(plant.name) says").font(.caption.weight(.semibold)).foregroundStyle(Jungle.warmText)
                            Text(mood == .needsYou ? String(localized: "Needs you today", comment: "Plant mood headline; max 22 chars") : mood == .fine ? String(localized: "Has a small request", comment: "Plant mood headline; max 22 chars") : String(localized: "Feeling good", comment: "Plant mood headline; max 22 chars"))
                                .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        }
                        Spacer(minLength: 0)
                        Text("Chat").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                    }
                    Text("“\(currentLine)”").font(.body).foregroundStyle(Jungle.text).multilineTextAlignment(.leading)
                    HStack(spacing: 14) {
                        ForEach(statusFacts, id: \.1) { f in
                            HStack(spacing: 5) { Icon3DView(f.0, size: 18); Text(f.1).font(.caption).foregroundStyle(Jungle.subtle) }
                        }
                    }
                }
                .padding(14)
                .background(Jungle.sun.opacity(0.22), in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                InfoRow(symbol: "sparkles", title: String(localized: "Personality", comment: "Info row title"), value: String(localized: "\(plant.personality.label) · \(plant.personality.blurb)", comment: "Personality name · short description"))
                Divider().padding(.leading, 44)
                Button { sheet = .place } label: {
                    InfoRow(symbol: "house", title: String(localized: "Location", comment: "Info row title"), value: locationLine, chevron: true, icon: plant.location.isEmpty ? .homeLeaf : .room(plant.location))
                }.buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { sheet = .edit } label: {
                    InfoRow(symbol: "cylinder", title: String(localized: "Pot", comment: "Info row title"), value: potLine, chevron: true)
                }.buttonStyle(.plain)
                Divider().padding(.leading, 44)
                InfoRow(symbol: "square.stack.3d.down.right", title: String(localized: "Soil", comment: "Info row title"), value: plant.substrate.isEmpty ? (plant.species.map { String(localized: "Ideal: \($0.mixLabel)", comment: "Ideal soil mix; arg mix description") } ?? String(localized: "Not set", comment: "Value placeholder when nothing set; max 12 chars")) : plant.substrate)
                Divider().padding(.leading, 44)
                InfoRow(symbol: "calendar", title: String(localized: "Next care", comment: "Info row title"), value: nextCare)
            }
            .jungleCard()
            NativeAdCard(slot: "plant-\(plant.id)")
        }
    }

    /// The facts behind the voice line, so the message never stands alone.
    private var statusFacts: [(Icon3D, String)] {
        var out: [(Icon3D, String)] = []
        if let w = plant.lastEvent(.water)?.date {
            let d = Int(CareEngine.days(from: w)); out.append((.waterDrops, d == 0 ? String(localized: "Watered today", comment: "Status fact; max 18 chars") : String(localized: "Watered \(d)d ago", comment: "Status fact; N days ago, short; plural; max 18 chars")))
        } else { out.append((.waterDrops, String(localized: "No water logged", comment: "Status fact; max 18 chars"))) }
        out.append((.soilTest, nextCare))
        return out
    }

    private var currentLine: String {
        if let r = CareEngine.requests(for: plant).first(where: { $0.priority <= 2 }) { return PlantVoice.say(r, plant: plant) }
        if let leaf = plant.lastEvent(.newLeaf), CareEngine.days(from: leaf.date) < 14 { return String(localized: "I'm growing really well! I just pushed a new leaf.", comment: "Plant voice, first person, proud and happy") }
        return PlantVoice.happy(plant)
    }
    private var locationLine: String {
        guard !plant.location.isEmpty else { return String(localized: "Tap to find my best spot", comment: "Location row value, plant voice; max 30 chars") }
        if let sp = spaces.first(where: { $0.name.folded == plant.location.folded }) {
            return String(localized: "\(plant.location.capitalized) · \(PlacementEngine.lightLabel(sp.light))", comment: "Room name · light level")
        }
        return plant.location.capitalized
    }
    private var potLine: String {
        var parts: [String] = []
        if let d = plant.potDiameterCm { parts.append("Ø " + PlantFormat.cm(d)) }
        if let m = plant.potMaterial { parts.append(m.label) }
        parts.append(plant.potHasDrainage ? String(localized: "Drainage", comment: "Pot has drainage holes; max 12 chars") : String(localized: "No drainage", comment: "Pot without drainage holes; max 14 chars"))
        return parts.joined(separator: " · ")
    }
    private var nextCare: String {
        let expected = CareEngine.expectedDryDays(for: plant)
        guard let w = plant.lastEvent(.water)?.date else { return String(localized: "Soil check today", comment: "Next care; max 24 chars") }
        let left = Int((expected - CareEngine.days(from: w)).rounded())
        return left <= 0 ? String(localized: "Soil check today", comment: "Next care; max 24 chars") : String(localized: "Soil check in \(left) days", comment: "Next care; plural; max 24 chars")
    }
}

struct MoodPill: View {
    let mood: CareEngine.Mood
    var body: some View {
        let (text, symbol, color): (String, String, Color) = switch mood {
        case .thriving: (String(localized: "Thriving", comment: "Mood pill; max 14 chars"), "leaf.fill", Jungle.leaf)
        case .fine: (String(localized: "Has a request", comment: "Mood pill; max 16 chars"), "hand.wave.fill", Jungle.sun)
        case .needsYou: (String(localized: "Needs you", comment: "Mood pill / status; max 12 chars"), "drop.fill", Jungle.terracotta)
        }
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).foregroundStyle(Jungle.text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Jungle.surface, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

struct ActionTile: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                SmartIcon(symbol: symbol, size: 30, tint: tint)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(Jungle.text)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .jungleCard()
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let symbol: String
    let title: String
    let value: String
    var chevron = false
    var icon: Icon3D? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group { if let icon { Icon3DView(icon, size: 30) } else { SmartIcon(symbol: symbol, size: 26) } }.frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Text(value).font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            Spacer(minLength: 0)
            if chevron { Image(systemName: "chevron.right").font(.caption).foregroundStyle(Jungle.subtle) }
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

/// "Milo's story": first vs latest photo, milestones and the full timeline.
/// Full life timeline: every event since the plant joined, grouped by month, with photos and growth.
struct PlantStoryView: View {
    let plant: Plant
    @Binding var pick: PhotosPickerItem?
    @Query private var props: [Propagation]
    enum Filter: String, CaseIterable {
        case all = "All", photos = "Photos", care = "Care", growth = "Growth", health = "Health"
        var label: String {
            switch self {
            case .all: String(localized: "All", comment: "Timeline filter chip; max 10 chars")
            case .photos: String(localized: "Photos", comment: "Timeline filter chip; max 10 chars")
            case .care: String(localized: "Care", comment: "Timeline filter chip; max 10 chars")
            case .growth: String(localized: "Growth", comment: "Timeline filter chip; max 10 chars")
            case .health: String(localized: "Health", comment: "Timeline filter chip; max 10 chars")
            }
        }
    }
    @State private var filter: Filter = .all

    private var events: [CareEvent] { plant.sortedEvents.filter { $0.note != "safety-ack" } }
    /// First moment: the earlier of when it joined and its oldest logged event.
    private var born: Date { min(plant.acquiredAt, events.last?.date ?? plant.acquiredAt) }

    private var shown: [CareEvent] {
        events.filter { e in
            switch filter {
            case .all: true
            case .photos: e.photo != nil
            case .care: [.water, .feed, .mist, .soilCheck, .rotate, .clean, .prune, .repot, .move].contains(e.kind)
            case .growth: [.newLeaf, .flower, .measure, .propagate, .photo].contains(e.kind)
            case .health: [.health, .treat].contains(e.kind)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            facts
            careRecords
            let photos = events.filter { $0.photo != nil }
            if photos.count >= 2, let first = photos.last, let last = photos.first {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(String(localized: "Then and now", comment: "Section title: first vs latest photo"))
                    HStack(spacing: 8) {
                        compare(first, label: first.date.formatted(.dateTime.month(.abbreviated).year()))
                        compare(last, label: String(localized: "Now", comment: "Label on latest photo; max 8 chars"))
                    }
                }
            }
            if heights.count >= 2 { growthChart }
            PhotosPicker(selection: $pick, matching: .images) {
                Label(photos.isEmpty ? String(localized: "Add the first photo", comment: "Button; max 24 chars") : String(localized: "Add this month's photo", comment: "Button; max 26 chars"), systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.forest).controlSize(.large)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button { withAnimation(.snappy) { filter = f } } label: {
                            Text(f.label).font(.subheadline.weight(.medium))
                                .foregroundStyle(filter == f ? Color.white : Jungle.text)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(filter == f ? Jungle.forest : Jungle.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(filter == f ? .clear : Jungle.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
            timeline
        }
    }

    // MARK: Facts grid (species, days, last watered, lineage)

    private var facts: some View {
        let parent = props.first { $0.childID == plant.id }
        let offspring = props.filter { $0.parentID == plant.id }.count
        let days = max(0, Int(CareEngine.days(from: born)))
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
            fact("leaf", String(localized: "Species", comment: "Fact label; max 14 chars"), plant.species?.commonName ?? String(localized: "Unknown", comment: "Fact value; max 12 chars"))
            fact("calendar", String(localized: "Days with you", comment: "Fact label; max 14 chars"), days.formatted())
            fact("drop", String(localized: "Last watered", comment: "Fact label; max 14 chars"), plant.lastEvent(.water).map { $0.date.formatted(.dateTime.day().month(.abbreviated)) } ?? String(localized: "Not yet", comment: "Fact value; max 12 chars"))
            fact("list.bullet", String(localized: "Moments", comment: "Fact label: number of timeline events; max 14 chars"), events.count.formatted())
            fact("arrow.up.forward", String(localized: "Parent", comment: "Fact label: mother plant; max 14 chars"), parent == nil ? String(localized: "None", comment: "Fact value; max 12 chars") : String(localized: "Cutting", comment: "Fact value: grown from a cutting; max 12 chars"))
            fact("arrow.triangle.branch", String(localized: "Offspring", comment: "Fact label: cuttings taken; max 14 chars"), offspring == 0 ? String(localized: "None", comment: "Fact value; max 12 chars") : offspring.formatted())
        }
        .padding(16).jungleCard()
    }

    private func fact(_ s: String, _ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(t, systemImage: s).font(.caption).foregroundStyle(Jungle.subtle)
            Text(v).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Care records row

    private var careRecords: some View {
        let kinds: [CareKind] = [.water, .feed, .prune, .repot, .treat, .clean]
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "Care records", comment: "Section title"))
            HStack(spacing: 0) {
                ForEach(kinds, id: \.self) { k in
                    let last = plant.lastEvent(k)
                    VStack(spacing: 4) {
                        Icon3DView(Icon3D.care(k), size: 32).saturation(last == nil ? 0.2 : 1)
                            .frame(width: 44, height: 44).background(last == nil ? Jungle.mist : Jungle.mint, in: Circle())
                        Text(short(k)).font(.caption2.weight(.medium)).foregroundStyle(Jungle.text)
                        Text(last.map { $0.date.formatted(.dateTime.day().month(.defaultDigits)) } ?? "–").font(.caption2).foregroundStyle(Jungle.subtle)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 12).jungleCard()
        }
    }

    private func short(_ k: CareKind) -> String {
        switch k { case .water: String(localized: "Water", comment: "Care record short label under icon; max 8 chars"); case .feed: String(localized: "Feed", comment: "Care record short label under icon; max 8 chars"); case .prune: String(localized: "Prune", comment: "Care record short label under icon; max 8 chars"); case .repot: String(localized: "Repot", comment: "Care record short label under icon; max 8 chars"); case .treat: String(localized: "Pests", comment: "Care record short label under icon; max 8 chars"); case .clean: String(localized: "Dust", comment: "Care record short label under icon; max 8 chars"); default: k.label }
    }

    // MARK: Growth chart from measurements

    private var heights: [(Date, Double)] {
        events.filter { $0.kind == .measure && $0.value != nil }.map { ($0.date, $0.value!) }.reversed()
    }

    private var growthChart: some View {
        let h = heights
        let maxV = h.map(\.1).max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "Growth", comment: "Section title: height chart"))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(h.suffix(10).enumerated()), id: \.offset) { _, p in
                    VStack(spacing: 4) {
                        Text(Int(p.1).formatted()).font(.caption2.weight(.semibold)).foregroundStyle(Jungle.text)
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Jungle.leaf)
                            .frame(height: max(8, 110 * p.1 / maxV))
                        Text(p.0.formatted(.dateTime.month(.abbreviated))).font(.caption2).foregroundStyle(Jungle.subtle)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(14).jungleCard()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Height grew from \(PlantFormat.cm(h.first?.1 ?? 0, wide: true)) to \(PlantFormat.cm(h.last?.1 ?? 0, wide: true))")
        }
    }

    // MARK: Timeline grouped by month

    private var timeline: some View {
        let cal = Calendar.current
        let groups = Dictionary(grouping: shown) { cal.date(from: cal.dateComponents([.year, .month], from: $0.date))! }
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(groups.keys.sorted(by: >), id: \.self) { month in
                VStack(alignment: .leading, spacing: 0) {
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).padding(.bottom, 10)
                    ForEach(groups[month] ?? []) { e in row(e) }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(born.formatted(.dateTime.day())).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text(born.formatted(.dateTime.month(.abbreviated))).font(.caption2).foregroundStyle(Jungle.subtle)
                }
                .frame(width: 40)
                Image(systemName: "heart.fill").foregroundStyle(Jungle.terracotta).frame(width: 20)
                Text("Joined your jungle on \(born.formatted(date: .long, time: .omitted)).").foregroundStyle(Jungle.text)
            }
        }
    }

    private func row(_ e: CareEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(e.date.formatted(.dateTime.day())).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(e.date.formatted(.dateTime.weekday(.abbreviated))).font(.caption2).foregroundStyle(Jungle.subtle)
            }
            .frame(width: 40)
            VStack(spacing: 0) {
                Icon3DView(Icon3D.care(e.kind), size: 22)
                    .frame(width: 26, height: 26).background(Jungle.mint, in: Circle())
                Rectangle().fill(Jungle.border).frame(width: 2).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(storyLine(e)).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                if let d = e.photo, let img = UIImage(data: d) {
                    Color.clear.frame(maxWidth: .infinity).frame(height: 180)
                        .overlay { Image(uiImage: img).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Text(e.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(Jungle.subtle)
            }
            .padding(.bottom, 16)
        }
        .accessibilityElement(children: .combine)
    }

    private func storyLine(_ e: CareEvent) -> String {
        switch e.kind {
        case .water: e.value.map { String(localized: "Watered, \(PlantFormat.ml(Int($0))).", comment: "Timeline line; arg amount with unit") } ?? String(localized: "Watered.", comment: "Timeline line")
        case .feed: e.productName.map { String(localized: "Fed with \($0).", comment: "Timeline line; arg fertilizer product name") } ?? String(localized: "Fed.", comment: "Timeline line: fertilized")
        case .soilCheck: e.soil.map { String(localized: "Soil felt \($0.label.lowercased()).", comment: "Timeline line; arg soil state lowercase") } ?? String(localized: "Soil checked.", comment: "Timeline line")
        case .mist: String(localized: "Misted.", comment: "Timeline line")
        case .rotate: String(localized: "Turned toward the light.", comment: "Timeline line")
        case .clean: String(localized: "Leaves cleaned.", comment: "Timeline line")
        case .newLeaf: String(localized: "I grew a new leaf!", comment: "Timeline line, plant voice, proud")
        case .flower: String(localized: "I flowered!", comment: "Timeline line, plant voice, proud")
        case .repot: e.value.map { String(localized: "You repotted me into a \(PlantFormat.cm($0)) pot.", comment: "Timeline line, plant voice; arg pot size with unit") } ?? String(localized: "You repotted me.", comment: "Timeline line, plant voice")
        case .move: e.note.isEmpty ? String(localized: "Moved to a new spot.", comment: "Timeline line") : String(localized: "Moved to \(e.note).", comment: "Timeline line; arg room name")
        case .health: String(localized: "Health check: \(e.note)", comment: "Timeline line; arg summary")
        case .treat: e.note.isEmpty ? String(localized: "Treated.", comment: "Timeline line") : String(localized: "Treated for \(e.note).", comment: "Timeline line; arg pest/problem")
        case .measure: String(localized: "\(PlantFormat.cm(e.value ?? 0)) tall.", comment: "Timeline line; arg height with unit")
        case .propagate: String(localized: "A cutting of me started a new life.", comment: "Timeline line, plant voice, tender")
        case .prune: String(localized: "Fresh haircut.", comment: "Timeline line after pruning, playful")
        case .photo: e.note.isEmpty ? String(localized: "New portrait.", comment: "Timeline line for a new photo, playful") : PlantFormat.note(e.note)
        default: e.note.isEmpty ? e.kind.label : PlantFormat.note(e.note)
        }
    }

    private func compare(_ e: CareEvent, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let d = e.photo, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 170).frame(maxWidth: .infinity).clipped()
            }
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Jungle.text).padding(.horizontal, 8).padding(.vertical, 4)
                .background(.regularMaterial, in: Capsule()).padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
    }
}

/// Smart schedule for one plant: adapted intervals, last done, what's next.
struct PlantCarePlanView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var tasks: [CareTask]
    let plant: Plant

    var body: some View {
        let s = plant.species
        let expected = Int(CareEngine.expectedDryDays(for: plant).rounded())
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                row(.water, String(localized: "Water", comment: "Care plan row title"), waterLine(s, expected), plant.learnedDryDays != nil ? String(localized: "Learned from your checks", comment: "Care plan hint; max 30 chars") : String(localized: "Adapts to your home", comment: "Care plan hint; max 30 chars"))
                Divider().padding(.leading, 44)
                row(.feed, String(localized: "Feed", comment: "Care plan row title: fertilize"), s.map { CareEngine.isGrowingSeason() ? String(localized: "Every \(Int($0.feedWeeks)) weeks", comment: "Feeding interval; plural") : String(localized: "Paused until spring", comment: "Feeding paused in cool season; max 26 chars") } ?? String(localized: "Set species", comment: "Prompt to set species; max 16 chars"), s.map { PlantAdvisor.feedPhrase($0.feed).capitalized } ?? "")
                Divider().padding(.leading, 44)
                row(.rotate, String(localized: "Rotate", comment: "Care plan row title"), String(localized: "A quarter turn every 2 weeks", comment: "Care plan value"), String(localized: "Even growth toward the light", comment: "Care plan hint"))
                Divider().padding(.leading, 44)
                row(.clean, String(localized: "Clean leaves", comment: "Care plan row title"), String(localized: "Every month", comment: "Care plan value"), String(localized: "Dusty leaves catch less light", comment: "Care plan hint"))
                Divider().padding(.leading, 44)
                row(.repot, String(localized: "Repot", comment: "Care plan row title"), repotLine, s.map { String(localized: "Usually every \(Int($0.repotYears)) years", comment: "Repot interval; plural") } ?? "")
            }
            .jungleCard()
            let mine = tasks.filter { $0.plantID == plant.id && !$0.done }.sorted { $0.due < $1.due }
            if !mine.isEmpty {
                Text("Planned").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                ForEach(mine) { t in
                    HStack {
                        Icon3DView(Icon3D.care(t.kind), size: 26)
                        VStack(alignment: .leading) {
                            Text(t.title).foregroundStyle(Jungle.text)
                            Text(t.due.formatted(.dateTime.weekday().day().month())).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        Spacer()
                        Button("Done") { complete(t) }.buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.small)
                    }
                    .padding(12).jungleCard()
                }
            }
        }
    }

    private func waterLine(_ s: Species?, _ expected: Int) -> String {
        switch s?.waterStyle {
        case .dry?: String(localized: "When the soil is fully dry, about every \(expected) days", comment: "Care plan watering; plural days")
        case .moist?: String(localized: "When the soil is just drying on top, about every \(expected) days", comment: "Care plan watering; plural days")
        case .some: String(localized: "When the soil is half dry, about every \(expected) days", comment: "Care plan watering; plural days")
        case nil: String(localized: "When the soil is dry, about every \(expected) days", comment: "Care plan watering; plural days")
        }
    }

    private var repotLine: String {
        guard let s = plant.species else { return String(localized: "When roots fill the pot", comment: "Repot plan value") }
        let since = CareEngine.days(from: plant.lastRepotAt ?? plant.acquiredAt)
        let left = s.repotYears * 365 - since
        if left <= 0 { return CareEngine.isWinter() ? String(localized: "Check the roots this spring", comment: "Repot plan value") : String(localized: "Check the roots this season", comment: "Repot plan value") }
        let months = Int(left / 30)
        return months <= 1 ? String(localized: "Check in a few weeks", comment: "Repot plan value") : String(localized: "Check in ~\(months) months", comment: "Repot plan value; plural")
    }

    private func row(_ kind: CareKind, _ title: String, _ value: String, _ hint: String) -> some View {
        let last = plant.lastEvent(kind)
        return HStack(alignment: .top, spacing: 12) {
            Icon3DView(Icon3D.care(kind), size: 26).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Text(value).font(.subheadline).foregroundStyle(Jungle.text)
                Text(last.map { String(localized: "\(hint) · last \(CareEngine.relative($0.date))", comment: "Care plan hint · last done relative date") } ?? hint).font(.caption).foregroundStyle(Jungle.subtle)
            }
            Spacer()
        }
        .padding(12)
    }

    private func complete(_ t: CareTask) {
        t.done = true
        if t.kind != .note && t.kind != .health { JungleBrain.quick(t.kind, plants: [plant], in: ctx, announce: true) }
        try? ctx.save()
    }
}

/// Plant passport: identity, needs, safety, stats.
struct PlantAboutView: View {
    let plant: Plant
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                stat(String(localized: "Health", comment: "Stat label; max 10 chars"), healthValue, "heart.fill")
                stat(String(localized: "Growth", comment: "Stat label; max 10 chars"), String(localized: "\(recent(.newLeaf)) new", comment: "N new leaves in 30 days; plural; max 10 chars"), "leaf.fill")
                stat(String(localized: "Checks", comment: "Stat label: soil checks; max 10 chars"), recent(.soilCheck).formatted(), "hand.point.down.fill")
            }
            VStack(spacing: 0) {
                InfoRow(symbol: "calendar", title: String(localized: "Joined home", comment: "Info row title: date plant arrived"), value: plant.acquiredAt.formatted(.dateTime.day().month().year()))
                Divider().padding(.leading, 44)
                InfoRow(symbol: "hourglass", title: String(localized: "With you", comment: "Info row title: time with owner"), value: age)
                if let s = plant.species {
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "leaf", title: String(localized: "Species", comment: "Info row title"), value: "\(s.commonName) · \(s.scientific)")
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "tree", title: String(localized: "Family", comment: "Info row title: botanical family"), value: s.family)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "sun.max", title: String(localized: "Light", comment: "Info row title"), value: s.lightRule)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "thermometer.medium", title: String(localized: "Comfort", comment: "Info row title: temperature and humidity"), value: String(localized: "\(Climate.tempRange(s.tempMin, s.tempMax)) · humidity \(PlantFormat.percent(s.humidityMin))+", comment: "Temperature range · humidity minimum percent and up"))
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "pawprint", title: String(localized: "Toxicity", comment: "Info row title: pet safety"), value: s.toxicityLine)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "lightbulb", title: String(localized: "Good to know", comment: "Info row title: tip"), value: s.tip)
                    ForEach(PlantKnowledgeRows.rows(for: s, plant: plant), id: \.title) { r in
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: r.symbol, title: r.title, value: r.value)
                    }
                }
            }
            .jungleCard()
            Text("Care data written from RHS, ASPCA, university extension services, Kew POWO and Wikidata.").font(.caption).foregroundStyle(Jungle.subtle)
        }
    }

    private func recent(_ k: CareKind) -> Int { plant.sortedEvents.filter { $0.kind == k && CareEngine.days(from: $0.date) < 30 }.count }
    private var healthValue: String {
        switch CareEngine.mood(for: plant) { case .thriving: String(localized: "Great", comment: "Health stat value; max 10 chars"); case .fine: String(localized: "Good", comment: "Health stat value; max 10 chars"); case .needsYou: String(localized: "Needs you", comment: "Mood pill / status; max 12 chars") }
    }
    private var age: String {
        let d = Int(CareEngine.days(from: plant.acquiredAt))
        let f = DateComponentsFormatter()
        f.unitsStyle = d < 365 ? .full : .abbreviated
        var c = DateComponents()
        if d < 31 { f.allowedUnits = [.day]; c.day = d }
        else if d < 365 { f.allowedUnits = [.month]; c.month = d / 30 }
        else { f.allowedUnits = [.year, .month]; c.year = d / 365; c.month = (d % 365) / 30 }
        return f.string(from: c) ?? d.formatted()
    }
    private func stat(_ t: String, _ v: String, _ s: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: s).foregroundStyle(Jungle.leaf)
            Text(v).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.7)
            Text(t).font(.caption).foregroundStyle(Jungle.subtle)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).jungleCard()
    }
}

/// "Milo needs water": amount from the pot, method from the species, next date from the engine.
struct WaterSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let plant: Plant

    var body: some View {
        let s = plant.species
        let expected = Int(CareEngine.expectedDryDays(for: plant).rounded())
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PlantAvatar(data: plant.photo, size: 120)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "drop.fill").font(.system(.title2, design: .rounded)).foregroundStyle(Jungle.forest)
                                .padding(10).background(.regularMaterial, in: Circle()).offset(x: 10, y: -6)
                        }
                    VStack(spacing: 6) {
                        Text(needsWater ? String(localized: "\(plant.name) needs water", comment: "Water sheet title; arg plant name") : String(localized: "Watering \(plant.name)", comment: "Water sheet title; arg plant name")).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(needsWater ? String(localized: "My soil is dry and it's time for a drink.", comment: "Water sheet, plant voice") : String(localized: "Feel the soil 3–4 cm deep first. If it's still moist, wait.", comment: "Water sheet advice"))
                            .multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
                    }
                    VStack(spacing: 0) {
                        InfoRow(symbol: "drop", title: String(localized: "Amount", comment: "Water sheet row title"), value: amount)
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "arrow.down.to.line", title: String(localized: "Method", comment: "Water sheet row title"), value: method(s))
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "calendar", title: String(localized: "Next watering", comment: "Water sheet row title"), value: String(localized: "In about \(expected) days. I'll ask for a soil check first.", comment: "Water sheet; plural days; plant voice"))
                    }
                    .jungleCard()
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        JungleBrain.quick(.water, plants: [plant], in: ctx, announce: true); dismiss()
                    } label: { Label("Mark as watered", systemImage: "checkmark").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).fontDesign(.rounded).controlSize(.large)
                    Menu {
                        Button("This evening") { remind(hours: 8) }
                        Button("Tomorrow") { remind(hours: 24) }
                        Button("In 2 days") { remind(hours: 48) }
                    } label: { Text("Remind me later").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).fontDesign(.rounded).controlSize(.large)
                }
                .buttonBorderShape(.capsule)
                .padding(16).background(.bar)
            }
            .jungleBackdrop()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private var needsWater: Bool { CareEngine.requests(for: plant).contains { $0.kind == .water } }

    private var amount: String {
        guard let d = plant.potDiameterCm else { return String(localized: "Until water runs out of the drainage holes, then empty the saucer.", comment: "Water amount advice") }
        let litres = 0.75 * Double.pi * pow(d / 2, 2) * d * 0.9 / 1000
        let share = plant.species?.waterStyle == .dry ? 0.12 : plant.species?.waterStyle == .moist ? 0.25 : 0.2
        let ml = litres * share * 1000
        let lo = Int((ml * 0.8 / 50).rounded() * 50), hi = Int((ml * 1.2 / 50).rounded() * 50)
        return String(localized: "About \(max(lo, 50))–\(PlantFormat.ml(max(hi, 100))) for a \(PlantFormat.cm(d)) pot, until it just drains.", comment: "Water amount; args low number, high amount with unit, pot size with unit")
    }
    private func method(_ s: Species?) -> String {
        switch s?.waterStyle {
        case .dry?: String(localized: "Soak deeply, drain fully, then leave it dry. Never leave it sitting in water.", comment: "Watering method")
        case .moist?: s?.humidityMin ?? 0 >= 55 ? String(localized: "Water evenly around the pot with room-temperature water. Rain or filtered water is best.", comment: "Watering method") : String(localized: "Water evenly around the pot with room-temperature water.", comment: "Watering method")
        default: String(localized: "Slowly, until a little drains out, then empty the saucer.", comment: "Watering method")
        }
    }
    private func remind(hours: Double) {
        ctx.insert(CareTask(title: String(localized: "Water \(plant.name)", comment: "Care task title; arg plant name"), kind: .water, plantID: plant.id, due: Date().addingTimeInterval(hours * 3600)))
        try? ctx.save()
        dismiss()
    }
}

/// Locale-aware units for plant screens.
enum PlantFormat {
    static func cm(_ v: Double, wide: Bool = false) -> String {
        Measurement(value: v, unit: UnitLength.centimeters)
            .formatted(.measurement(width: wide ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }
    static func ml(_ v: Int) -> String {
        Measurement(value: Double(v), unit: UnitVolume.milliliters).formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }
    /// 0...100 value as a percent.
    static func percent(_ v: Double) -> String { (v / 100).formatted(.percent.precision(.fractionLength(0))) }
    /// Stored English sentinel notes shown translated.
    static func note(_ n: String) -> String {
        n == "First photo" ? String(localized: "First photo", comment: "Timeline note for the first photo of a plant") : n
    }
}
