import SwiftUI
import SwiftData
import PhotosUI

/// The plant's own page: hero photo, mood, quick actions, Overview / Story / Care / About.
struct PlantHomeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Query private var spaces: [Space]
    @Bindable var plant: Plant

    enum Tab: String, CaseIterable { case overview = "Overview", story = "Timeline", care = "Care", about = "About" }
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
                Picker("Section", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) } }
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
                    Text(plant.species?.scientific ?? "Unknown species").font(.subheadline).italic().foregroundStyle(hasPhoto ? Color.white.opacity(0.9) : Jungle.subtle)
                }
                Spacer()
                StatusBadge(status: CareEngine.status(for: plant))
            }
            .padding(.horizontal, 16).padding(.bottom, 50)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            ActionTile(title: "Water", symbol: "drop.fill", tint: Jungle.forest) { sheet = .water }
            ActionTile(title: "Feed", symbol: "leaf.arrow.triangle.circlepath", tint: Jungle.leaf) {
                withAnimation { JungleBrain.quick(.feed, plants: [plant], in: ctx, announce: true) }
            }
            ActionTile(title: "Repot", symbol: "arrow.up.bin", tint: Jungle.terracotta) { sheet = .repot }
            ActionTile(title: "Check", symbol: "stethoscope", tint: Jungle.leaf) { sheet = .health }
        }
        .padding(.horizontal, 16)
        .offset(y: -34).padding(.bottom, -34)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("How-to for \(plant.name)", action: "All") { showGuides = true }
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
                            Text(mood == .needsYou ? "Needs you today" : mood == .fine ? "Has a small request" : "Feeling good")
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
                InfoRow(symbol: "sparkles", title: "Personality", value: plant.personality.label + " · " + plant.personality.blurb)
                Divider().padding(.leading, 44)
                Button { sheet = .place } label: {
                    InfoRow(symbol: "house", title: "Location", value: locationLine, chevron: true, icon: plant.location.isEmpty ? .homeLeaf : .room(plant.location))
                }.buttonStyle(.plain)
                Divider().padding(.leading, 44)
                Button { sheet = .edit } label: {
                    InfoRow(symbol: "cylinder", title: "Pot", value: potLine, chevron: true)
                }.buttonStyle(.plain)
                Divider().padding(.leading, 44)
                InfoRow(symbol: "square.stack.3d.down.right", title: "Soil", value: plant.substrate.isEmpty ? (plant.species.map { "Ideal: \($0.mixLabel)" } ?? "Not set") : plant.substrate)
                Divider().padding(.leading, 44)
                InfoRow(symbol: "calendar", title: "Next care", value: nextCare)
            }
            .jungleCard()
        }
    }

    /// The facts behind the voice line, so the message never stands alone.
    private var statusFacts: [(Icon3D, String)] {
        var out: [(Icon3D, String)] = []
        if let w = plant.lastEvent(.water)?.date {
            let d = Int(CareEngine.days(from: w)); out.append((.waterDrops, d == 0 ? "Watered today" : "Watered \(d)d ago"))
        } else { out.append((.waterDrops, "No water logged")) }
        out.append((.soilTest, nextCare))
        return out
    }

    private var currentLine: String {
        if let r = CareEngine.requests(for: plant).first(where: { $0.priority <= 2 }) { return PlantVoice.say(r, plant: plant) }
        if let leaf = plant.lastEvent(.newLeaf), CareEngine.days(from: leaf.date) < 14 { return "I'm growing really well! I just pushed a new leaf." }
        return PlantVoice.happy(plant)
    }
    private var locationLine: String {
        guard !plant.location.isEmpty else { return "Tap to find my best spot" }
        if let sp = spaces.first(where: { $0.name.folded == plant.location.folded }) {
            return "\(plant.location.capitalized) · \(PlacementEngine.lightLabel(sp.light))"
        }
        return plant.location.capitalized
    }
    private var potLine: String {
        var parts: [String] = []
        if let d = plant.potDiameterCm { parts.append("Ø \(Int(d)) cm") }
        if let m = plant.potMaterial { parts.append(m.label) }
        parts.append(plant.potHasDrainage ? "Drainage" : "No drainage")
        return parts.joined(separator: " · ")
    }
    private var nextCare: String {
        let expected = CareEngine.expectedDryDays(for: plant)
        guard let w = plant.lastEvent(.water)?.date else { return "Soil check today" }
        let left = Int((expected - CareEngine.days(from: w)).rounded())
        return left <= 0 ? "Soil check today" : "Soil check in \(left) day\(left == 1 ? "" : "s")"
    }
}

struct MoodPill: View {
    let mood: CareEngine.Mood
    var body: some View {
        let (text, symbol, color): (String, String, Color) = switch mood {
        case .thriving: ("Thriving", "leaf.fill", Jungle.leaf)
        case .fine: ("Has a request", "hand.wave.fill", Jungle.sun)
        case .needsYou: ("Needs you", "drop.fill", Jungle.terracotta)
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
    enum Filter: String, CaseIterable { case all = "All", photos = "Photos", care = "Care", growth = "Growth", health = "Health" }
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
                    SectionTitle("Then and now")
                    HStack(spacing: 8) {
                        compare(first, label: first.date.formatted(.dateTime.month(.abbreviated).year()))
                        compare(last, label: "Now")
                    }
                }
            }
            if heights.count >= 2 { growthChart }
            PhotosPicker(selection: $pick, matching: .images) {
                Label(photos.isEmpty ? "Add the first photo" : "Add this month's photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.forest).controlSize(.large)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button { withAnimation(.snappy) { filter = f } } label: {
                            Text(f.rawValue).font(.subheadline.weight(.medium))
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
            fact("leaf", "Species", plant.species?.commonName ?? "Unknown")
            fact("calendar", "Days with you", "\(days)")
            fact("drop", "Last watered", plant.lastEvent(.water).map { $0.date.formatted(.dateTime.day().month(.abbreviated)) } ?? "Not yet")
            fact("list.bullet", "Moments", "\(events.count)")
            fact("arrow.up.forward", "Parent", parent == nil ? "None" : "Cutting")
            fact("arrow.triangle.branch", "Offspring", offspring == 0 ? "None" : "\(offspring)")
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
            SectionTitle("Care records")
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
        switch k { case .water: "Water"; case .feed: "Feed"; case .prune: "Prune"; case .repot: "Repot"; case .treat: "Pests"; case .clean: "Dust"; default: k.label }
    }

    // MARK: Growth chart from measurements

    private var heights: [(Date, Double)] {
        events.filter { $0.kind == .measure && $0.value != nil }.map { ($0.date, $0.value!) }.reversed()
    }

    private var growthChart: some View {
        let h = heights
        let maxV = h.map(\.1).max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Growth")
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(h.suffix(10).enumerated()), id: \.offset) { _, p in
                    VStack(spacing: 4) {
                        Text("\(Int(p.1))").font(.caption2.weight(.semibold)).foregroundStyle(Jungle.text)
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
            .accessibilityLabel("Height grew from \(Int(h.first?.1 ?? 0)) to \(Int(h.last?.1 ?? 0)) centimetres")
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
                    Image(uiImage: img).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 180)
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
        case .water: "Watered" + (e.value.map { ", \(Int($0)) ml" } ?? "") + "."
        case .feed: "Fed" + (e.productName.map { " with \($0)" } ?? "") + "."
        case .soilCheck: "Soil felt \((e.soil?.label ?? "checked").lowercased())."
        case .mist: "Misted."
        case .rotate: "Turned toward the light."
        case .clean: "Leaves cleaned."
        case .newLeaf: "I grew a new leaf!"
        case .flower: "I flowered!"
        case .repot: "You repotted me" + (e.value.map { " into a \(Int($0)) cm pot" } ?? "") + "."
        case .move: "Moved to \(e.note.isEmpty ? "a new spot" : e.note)."
        case .health: "Health check: \(e.note)"
        case .treat: "Treated" + (e.note.isEmpty ? "." : " for \(e.note).")
        case .measure: "\(Int(e.value ?? 0)) cm tall."
        case .propagate: "A cutting of me started a new life."
        case .prune: "Fresh haircut."
        case .photo: e.note.isEmpty ? "New portrait." : e.note
        default: e.note.isEmpty ? e.kind.label : e.note
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
                row(.water, "Water", "When the soil is \(s.map { $0.waterStyle == .dry ? "fully dry" : $0.waterStyle == .moist ? "just drying on top" : "half dry" } ?? "dry"), about every \(expected) days", plant.learnedDryDays != nil ? "Learned from your checks" : "Adapts to your home")
                Divider().padding(.leading, 44)
                row(.feed, "Feed", s.map { CareEngine.isGrowingSeason() ? "Every \(Int($0.feedWeeks)) weeks" : "Paused until spring" } ?? "Set species", s.map { PlantAdvisor.feedPhrase($0.feed).capitalized } ?? "")
                Divider().padding(.leading, 44)
                row(.rotate, "Rotate", "A quarter turn every 2 weeks", "Even growth toward the light")
                Divider().padding(.leading, 44)
                row(.clean, "Clean leaves", "Every month", "Dusty leaves catch less light")
                Divider().padding(.leading, 44)
                row(.repot, "Repot", repotLine, s.map { "Usually every \(Int($0.repotYears)) year(s)" } ?? "")
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

    private var repotLine: String {
        guard let s = plant.species else { return "When roots fill the pot" }
        let since = CareEngine.days(from: plant.lastRepotAt ?? plant.acquiredAt)
        let left = s.repotYears * 365 - since
        if left <= 0 { return "Check the roots this \(CareEngine.isWinter() ? "spring" : "season")" }
        let months = Int(left / 30)
        return months <= 1 ? "Check in a few weeks" : "Check in ~\(months) months"
    }

    private func row(_ kind: CareKind, _ title: String, _ value: String, _ hint: String) -> some View {
        let last = plant.lastEvent(kind)
        return HStack(alignment: .top, spacing: 12) {
            Icon3DView(Icon3D.care(kind), size: 26).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Text(value).font(.subheadline).foregroundStyle(Jungle.text)
                Text(hint + (last.map { " · last \(CareEngine.relative($0.date))" } ?? "")).font(.caption).foregroundStyle(Jungle.subtle)
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
                stat("Health", healthValue, "heart.fill")
                stat("Growth", "\(recent(.newLeaf)) new", "leaf.fill")
                stat("Checks", "\(recent(.soilCheck))", "hand.point.down.fill")
            }
            VStack(spacing: 0) {
                InfoRow(symbol: "calendar", title: "Joined home", value: plant.acquiredAt.formatted(.dateTime.day().month().year()))
                Divider().padding(.leading, 44)
                InfoRow(symbol: "hourglass", title: "With you", value: age)
                if let s = plant.species {
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "leaf", title: "Species", value: "\(s.en) · \(s.scientific)")
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "tree", title: "Family", value: s.family)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "sun.max", title: "Light", value: s.lightRule)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "thermometer.medium", title: "Comfort", value: "\(Int(s.tempMin))–\(Int(s.tempMax)) °C · humidity \(Int(s.humidityMin))%+")
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "pawprint", title: "Toxicity", value: s.toxicityLine)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "lightbulb", title: "Good to know", value: s.tip)
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
        switch CareEngine.mood(for: plant) { case .thriving: "Great"; case .fine: "Good"; case .needsYou: "Needs you" }
    }
    private var age: String {
        let d = Int(CareEngine.days(from: plant.acquiredAt))
        return d < 31 ? "\(d) days" : d < 365 ? "\(d / 30) months" : "\(d / 365) yr \((d % 365) / 30) mo"
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
                        Text(needsWater ? "\(plant.name) needs water" : "Watering \(plant.name)").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(needsWater ? "My soil is dry and it's time for a drink." : "Feel the soil 3–4 cm deep first. If it's still moist, wait.")
                            .multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
                    }
                    VStack(spacing: 0) {
                        InfoRow(symbol: "drop", title: "Amount", value: amount)
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "arrow.down.to.line", title: "Method", value: method(s))
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "calendar", title: "Next watering", value: "In about \(expected) days. I'll ask for a soil check first.")
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
        guard let d = plant.potDiameterCm else { return "Until water runs out of the drainage holes, then empty the saucer." }
        let litres = 0.75 * Double.pi * pow(d / 2, 2) * d * 0.9 / 1000
        let share = plant.species?.waterStyle == .dry ? 0.12 : plant.species?.waterStyle == .moist ? 0.25 : 0.2
        let ml = litres * share * 1000
        let lo = Int((ml * 0.8 / 50).rounded() * 50), hi = Int((ml * 1.2 / 50).rounded() * 50)
        return "About \(max(lo, 50))–\(max(hi, 100)) ml for a \(Int(d)) cm pot, until it just drains."
    }
    private func method(_ s: Species?) -> String {
        switch s?.waterStyle {
        case .dry?: "Soak deeply, drain fully, then leave it dry. Never leave it sitting in water."
        case .moist?: "Water evenly around the pot with room-temperature water. \(s?.humidityMin ?? 0 >= 55 ? "Rain or filtered water is best." : "")"
        default: "Slowly, until a little drains out, then empty the saucer."
        }
    }
    private func remind(hours: Double) {
        ctx.insert(CareTask(title: "Water \(plant.name)", kind: .water, plantID: plant.id, due: Date().addingTimeInterval(hours * 3600)))
        try? ctx.save()
        dismiss()
    }
}
