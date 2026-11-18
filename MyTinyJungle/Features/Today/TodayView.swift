import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \ChatMessage.date) private var allMessages: [ChatMessage]
    @Query private var propagations: [Propagation]
    @State private var chipKind: CareKind?
    @State private var soilPlant: Plant?
    @State private var showSettings = false
    @State private var path = NavigationPath()
    @State private var paywall = false
    @State private var addingPlant = false
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var guide: CareGuide?

    private var jungleMessages: [ChatMessage] { allMessages.filter { $0.plant == nil }.suffix(12) }
    private var requests: [(Plant, PlantRequest)] {
        plants.flatMap { p in CareEngine.requests(for: p).filter { $0.priority <= 2 }.prefix(1).map { (p, $0) } }
            .sorted { $0.1.priority < $1.1.priority }
    }

    private var upcoming: Int { Agenda.items(plants: plants, tasks: [], days: 7).count }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        header
                        if plants.isEmpty { EmptyJungle { addingPlant = true } }
                        else {
                            if requests.isEmpty {
                                Button { selectedTab = 2 } label: { CaughtUpCard(plants: plants) }.buttonStyle(.plain).id("today")
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(requests.count > 1 ? String(localized: "Today's care · \(requests.count)", comment: "Section title; %lld number of tasks") : String(localized: "Today's care", comment: "Section title"), action: requests.count > 1 ? String(localized: "See all", comment: "Section action; max 12 chars") : nil) { path.append(TodayRoute.watering) }
                                    if requests.count == 1, let (p, r) = requests.first {
                                        CareStoryCard(plant: p, request: r, onAction: { handle($0, plant: p) }, onOpen: { path.append(p.id) }, fullWidth: true)
                                    } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(requests, id: \.1.id) { p, r in
                                                CareStoryCard(plant: p, request: r, onAction: { handle($0, plant: p) }, onOpen: { path.append(p.id) })
                                            }
                                        }
                                        .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.viewAligned)
                                    .scrollClipDisabled()
                                    }
                                }
                                .id("today")
                            }
                            ComingUpCard(plants: plants, propagations: propagations) { path.append($0) }
                            Button { path.append(TodayRoute.health) } label: { JungleHealthCard(plants: plants, needIDs: Set(plants.filter { CareEngine.needsYou($0) }.map(\.id))) }.buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(String(localized: "Your plants", comment: "Section title"), action: String(localized: "See all", comment: "Section action; max 12 chars")) { selectedTab = 1 }
                                carousel
                            }
                            summary
                            conversations
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                                .animation(.snappy, value: requests.map(\.1.id))
                .safeAreaInset(edge: .bottom) {
                    GlassComposer(placeholder: plants.isEmpty ? String(localized: "Tell me about your first plant…", comment: "Chat input placeholder, no plants yet") : String(localized: "Tell me how your plants are doing…", comment: "Chat input placeholder"),
                                  showChips: !plants.isEmpty, onChip: { chipKind = $0 }) { text, photo in
                        sendFromToday(text, photo)
                    }
                }
            }
            .jungleBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TodayRoute.self, destination: route)
            .navigationDestination(for: UUID.self) { id in
                if let p = plants.first(where: { $0.id == id }) { PlantHomeView(plant: p) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $paywall) { PaywallView(reason: .morePlants) }
            .sheet(isPresented: $addingPlant) { AddPlantFlow() }
            .fullScreenCover(item: $guide) { GuidePlayerView(guide: $0, plant: guidePlant) }
            .confirmationDialog(chipTitle, isPresented: Binding(get: { chipKind != nil }, set: { if !$0 { chipKind = nil } }), titleVisibility: .visible) {
                if let kind = chipKind {
                    ForEach(plants) { p in
                        Button(p.name) {
                            if kind == .soilCheck { soilPlant = p } else { JungleBrain.quick(kind, plants: [p], in: ctx, announce: true) }
                        }
                    }
                    if kind != .soilCheck && plants.count > 1 {
                        Button("All plants") { JungleBrain.quick(kind, plants: plants, in: ctx, announce: true) }
                    }
                }
            }
            .confirmationDialog(soilPlant.map { String(localized: "How does \($0.name)'s soil feel?", comment: "Dialog title; %@ plant name") } ?? String(localized: "How does the soil feel?", comment: "Dialog title"), isPresented: Binding(get: { soilPlant != nil }, set: { if !$0 { soilPlant = nil } }), titleVisibility: .visible) {
                ForEach(SoilState.allCases, id: \.self) { s in
                    Button(s.label) { if let p = soilPlant { JungleBrain.quick(.soilCheck, soil: s, plants: [p], in: ctx, announce: true) } }
                }
            }
        }
    }

    /// Plant cards with real photos, like a little shelf.
    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(plants) { p in
                    Button { path.append(p.id) } label: { PlantShelfCard(plant: p) }.buttonStyle(.plain)
                }
                Button { addingPlant = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(.title2, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.accentText)
                            .frame(width: 52, height: 52).background(Jungle.mint, in: Circle())
                        Text("Add plant").font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text)
                    }
                    .frame(width: 120, height: 186).jungleCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var guidePlant: Plant? { plants.first { CareEngine.mood(for: $0) == .needsYou } ?? plants.first }
    private var guideOfDay: CareGuide {
        if let p = guidePlant, let g = GuideLibrary.suggested(for: p).first, CareEngine.mood(for: p) == .needsYou { return g }
        let all = GuideLibrary.all
        return all[(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0) % all.count]
    }

    @ViewBuilder private func route(_ r: TodayRoute) -> some View {
        switch r {
        case .watering: WateringListView()
        case .health: JungleHealthView()
        case .season: ScrollView { SeasonGuideView(plants: plants).padding(16) }.jungleBackdrop().navigationTitle("Seasons")
        case .learn: GuidesView(plant: guidePlant)
        case .chat: JungleChatView()
        }
    }

    /// Health-app style summary cards. Every card opens something.
    private var summary: some View {
        let waterItems = Agenda.items(plants: plants, tasks: [], days: 30).filter { $0.kind == .soilCheck || $0.kind == .water }

        var seen = Set<UUID>()
        let upcoming: [(Plant, Date)] = waterItems.compactMap { i in
            guard let p = i.plant, seen.insert(p.id).inserted else { return nil }
            return (p, i.date)
        }.prefix(3).map { $0 }
                let season = SeasonGuideView.current()
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "At a glance", comment: "Section title"))
            HStack(alignment: .top, spacing: 12) {
                Button { path.append(TodayRoute.watering) } label: {
                    SummaryCard(title: String(localized: "Next sips", comment: "Card title: upcoming waterings; playful; max 16 chars"), symbol: "drop.fill", tint: Color(red: 0.27, green: 0.5, blue: 0.72)) {
                        if upcoming.isEmpty {
                            Text(plants.isEmpty ? "Add a plant and I'll plan its drinks." : "Everyone's had a drink. Relax!" as LocalizedStringKey)
                                .font(.subheadline).foregroundStyle(Jungle.subtle).lineLimit(3, reservesSpace: true)
                        } else {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(upcoming, id: \.0.id) { p, d in
                                    HStack(spacing: 8) {
                                        PlantAvatar(data: p.photo, size: 24)
                                        Text(p.name).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text).lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(shortDay(d)).font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                Button { path.append(TodayRoute.season) } label: {
                    SummaryCard(title: season.rawValue, symbol: season.symbol, tint: Color(red: 0.72, green: 0.56, blue: 0.2)) {
                        Text(seasonTip(season)).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .buttonStyle(.plain)
            Button { path.append(TodayRoute.learn) } label: {
                HStack(spacing: 14) {
                    GuideIcon(guide: guideOfDay)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's little lesson").font(.caption).foregroundStyle(Jungle.subtle)
                        Text(guideOfDay.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).lineLimit(1)
                        Text("\(guideOfDay.minutes) min").font(.caption).foregroundStyle(Jungle.subtle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                }
                .padding(14).jungleCard()
            }
            .buttonStyle(.plain)
            NativeAdCard(slot: "today")
        }
    }

    private func shortDay(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) || d < Date() { return String(localized: "Today", comment: "Short day label; max 10 chars") }
        if cal.isDateInTomorrow(d) { return String(localized: "Tomorrow", comment: "Short day label; max 10 chars") }
        return d.formatted(.dateTime.weekday(.abbreviated))
    }

    private func seasonTip(_ s: SeasonGuideView.Season) -> String {
        if let local = Climate.shared.seasonTip(plants: plants) { return local }
        return switch s {
        case .spring: String(localized: "Fresh leaves are coming. Time for new pots and their first meal.", comment: "Spring tip")
        case .summer: String(localized: "Long sunny days. Peek at the soil a little more often.", comment: "Summer tip")
        case .autumn: String(localized: "Cozy season. One last meal, then let them rest.", comment: "Autumn tip")
        case .winter: String(localized: "Sleepy time. Less water, no food, keep them off cold glass.", comment: "Winter tip; Brazilian winter is mild/dry")
        }
    }

    private func relativeDay(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return String(localized: "Today", comment: "Short day label; max 10 chars") }
        if cal.isDateInTomorrow(d) { return String(localized: "Tomorrow", comment: "Short day label; max 10 chars") }
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
        return n < 7 ? d.formatted(.dateTime.weekday(.wide)) : String(localized: "In \(n) days", comment: "Relative day; %lld days (plural)")
    }

    /// Each plant's latest line, like a messages inbox.
    private func sendFromToday(_ text: String, _ photo: Data?) {
        JungleBrain.handle(text, photo: photo, plant: nil, plants: plants, in: ctx)
        path.append(TodayRoute.chat)
    }

    private var conversations: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "Conversations", comment: "Section title: chats with plants"))
            VStack(spacing: 0) {
                Button { path.append(TodayRoute.chat) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            ForEach(Array(plants.prefix(3).enumerated()), id: \.element.id) { i, p in
                                PlantAvatar(data: p.photo, size: 26).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 1.5))
                                    .offset(x: CGFloat(i - 1) * 9, y: i == 1 ? -7 : 5)
                            }
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Your jungle").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                                Spacer()
                                if let last = jungleMessages.last { Text(last.date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(Jungle.subtle) }
                            }
                            Text(jungleMessages.last.map { $0.text.isEmpty ? String(localized: "Photo", comment: "Last message preview when it's a photo") : $0.text } ?? String(localized: "Talk to everyone at once", comment: "Group chat preview"))
                                .font(.subheadline).foregroundStyle(Jungle.subtle).lineLimit(1)
                        }
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 70)
                ForEach(plants) { p in
                    let last = (p.messages ?? []).max { $0.date < $1.date }
                    NavigationLink { PlantChatView(plant: p) } label: {
                        HStack(spacing: 12) {
                            PlantAvatar(data: p.photo, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(p.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                                    Spacer()
                                    if let last { Text(last.date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(Jungle.subtle) }
                                }
                                Text(last?.text.isEmpty == false ? last!.text : PlantVoice.happy(p))
                                    .font(.subheadline).foregroundStyle(Jungle.subtle).lineLimit(1)
                            }
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if p.id != plants.last?.id { Divider().padding(.leading, 70) }
                }
            }
            .jungleCard()
        }
    }

    private var chipTitle: String {
        switch chipKind {
        case .water: String(localized: "Who did you water?", comment: "Plant picker title")
        case .feed: String(localized: "Who did you feed?", comment: "Plant picker title")
        case .soilCheck: String(localized: "Whose soil did you check?", comment: "Plant picker title")
        default: String(localized: "Which plant?", comment: "Plant picker title")
        }
    }

    private var header: some View {
        TabHeader(title: greeting, subtitle: contextLine, dot: plants.isEmpty ? nil : (requests.isEmpty ? Jungle.leaf : Jungle.terracotta)) {
            HeaderButton(symbol: "gearshape", label: String(localized: "Settings", comment: "Accessibility label")) { showSettings = true }
        }
    }

    /// One calm line that ties the day, season and plants together.
    private var contextLine: String {
        if plants.isEmpty { return String(localized: "Let's grow your little jungle.", comment: "Today subtitle, no plants") }
        if requests.isEmpty { return String(localized: "Everyone's happy today", comment: "Today subtitle, nothing due") }
        return String(localized: "\(requests.count) plants need you today", comment: "Today subtitle; %lld count (plural)")
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = JungleSettings.shared.ownerName
        if name.isEmpty { return h < 12 ? String(localized: "Good morning", comment: "Greeting") : h < 18 ? String(localized: "Good afternoon", comment: "Greeting") : String(localized: "Good evening", comment: "Greeting") }
        return h < 12 ? String(localized: "Good morning, \(name)", comment: "Greeting; %@ user name") : h < 18 ? String(localized: "Good afternoon, \(name)", comment: "Greeting; %@ user name") : String(localized: "Good evening, \(name)", comment: "Greeting; %@ user name")
    }

    private func send(_ text: String) {
        if text == String(localized: "See Plus", comment: "Chat suggestion chip opening paywall; max 14 chars") { paywall = true; return }
        JungleBrain.handle(text, plant: nil, plants: plants, in: ctx) }

    private func handle(_ action: RequestCard.Action, plant: Plant) {
        switch action {
        case .soil(let s): withAnimation(.snappy) { JungleBrain.quick(.soilCheck, soil: s, plants: [plant], in: ctx, announce: true) }
        case .care(let k): withAnimation(.snappy) { JungleBrain.quick(k, plants: [plant], in: ctx, announce: true) }
        case .ack:
            let e = CareEvent(kind: .note, note: "safety-ack", source: "chip"); e.plant = plant; ctx.insert(e); try? ctx.save()
        case .open: path.append(plant.id)
        }
    }
}

struct RequestCard: View {
    enum Action { case soil(SoilState), care(CareKind), ack, open }
    let plant: Plant
    let request: PlantRequest
    var onAction: (Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PlantAvatar(data: plant.photo, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text(plant.species?.commonName ?? String(localized: "Unknown species", comment: "Plant card subtitle when species unknown")).font(.caption).foregroundStyle(Jungle.subtle)
                }
                Spacer()
                Image(systemName: icon).foregroundStyle(request.priority == 0 ? Jungle.terracotta : Jungle.leaf).accessibilityHidden(true)
            }
            Text("“\(PlantVoice.say(request, plant: plant))”", comment: "Quoted plant speech; use pt-BR quotes")
            Text(request.reason).font(.caption).foregroundStyle(Jungle.subtle)
            HStack(spacing: 8) { buttons }
        }
        .padding(14)
        .jungleCard()
        .contentShape(Rectangle())
    }

    /// Just the action buttons, for hosting inside other cards.
    var buttonsOnly: some View {
        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { buttons } }
            .tint(Jungle.forest).controlSize(.regular)
    }

    private var icon: String {
        switch request.kind {
        case .water: "drop.fill"
        case .checkSoil: "hand.point.down.fill"
        case .feed: "leaf.arrow.triangle.circlepath"
        case .checkRoots: "arrow.up.bin"
        case .portrait: "camera"
        case .safety: "pawprint.fill"
        case .pauseFeeding: "moon.zzz"
        }
    }

    @ViewBuilder private var buttons: some View {
        switch request.kind {
        case .checkSoil:
            ForEach(SoilState.allCases, id: \.self) { s in
                Button(s == .slightlyMoist ? String(localized: "Moist", comment: "Soil feel button; max 10 chars") : s.label) { onAction(.soil(s)) }.buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule)
            }
        case .water:
            Button("Watered", systemImage: "drop.fill") { onAction(.care(.water)) }.buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule)
        case .feed:
            Button("Fed", systemImage: "checkmark") { onAction(.care(.feed)) }.buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule)
            Button("Ask why") { onAction(.open) }.buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule)
        case .safety:
            Button("Got it") { onAction(.ack) }.buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule)
        default:
            Button("Talk to \(plant.name)") { onAction(.open) }.buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule)
        }
    }
}

struct EmptyJungle: View {
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "leaf").font(.system(.largeTitle, design: .rounded)).foregroundStyle(Jungle.leaf).accessibilityHidden(true)
            Text("Your jungle is waiting").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            Text("Just tell me about a plant, like \"I have a monstera called Milo in the living room\", or add one in Plants with a photo.")
                .foregroundStyle(Jungle.subtle)
            if let onAdd {
                Button(action: onAdd) { Label("Snap your first plant", systemImage: "camera.fill") }
                    .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jungleCard()
    }
}


struct PlantShelfCard: View {
    let plant: Plant
    var body: some View {
        let mood = CareEngine.mood(for: plant)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let d = plant.photo, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill() }
                    else { ZStack { Jungle.mint; Image(systemName: "leaf.fill").font(.system(size: 44)).foregroundStyle(Jungle.leaf) } }
                }
                .frame(width: 150, height: 130).clipped()
                Text(mood == .needsYou ? "Needs you" : mood == .fine ? "Okay" : "Thriving" as LocalizedStringKey)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(mood == .needsYou ? Color.white : Jungle.forest)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(mood == .needsYou ? Jungle.terracotta : Jungle.surface.opacity(0.94), in: Capsule())
                    .padding(8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).lineLimit(1)
                Text(plant.species?.commonName ?? String(localized: "Plant", comment: "Plant tile subtitle when species unknown")).font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 150)
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        .jungleCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mood == .needsYou ? String(localized: "\(plant.name), needs you", comment: "VoiceOver; %@ plant name") : mood == .fine ? String(localized: "\(plant.name), doing fine", comment: "VoiceOver; %@ plant name") : String(localized: "\(plant.name), thriving", comment: "VoiceOver; %@ plant name"))
    }
}


/// Health-app style card: coloured title row with chevron, then content.
struct SummaryCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SmartIcon(symbol: symbol, size: 22, tint: tint).frame(width: 26, height: 26)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tint == Jungle.leaf ? Jungle.accentText : Jungle.text)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14).jungleCard()
        .contentShape(Rectangle())
    }
}

/// The one thing that matters most right now, voiced by the plant.
struct NextUpCard: View {
    let plant: Plant
    let request: PlantRequest
    let more: Int
    var onAction: (RequestCard.Action) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Jungle.terracotta)
                Text("Next up").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Spacer()
                if more > 0 { Text("+\(more) more today").font(.caption).foregroundStyle(Jungle.subtle) }
            }
            HStack(alignment: .top, spacing: 14) {
                PlantAvatar(data: plant.photo, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    Text("“\(PlantVoice.say(request, plant: plant))”").font(.body).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                    Text(request.reason).font(.footnote).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
                }
            }
            RequestCard(plant: plant, request: request, onAction: onAction).buttonsOnly
        }
        .padding(16).jungleCard()
    }
}

/// When nothing is due: today's ring and what comes next.
struct CaughtUpCard: View {
    let plants: [Plant]
    var body: some View {
        let cal = Calendar.current
        let doneToday = plants.flatMap { $0.events ?? [] }.filter { cal.isDateInToday($0.date) && $0.kind != .note }.count
        let next = Agenda.items(plants: plants, tasks: [], days: 30).first
        HStack(spacing: 16) {
            ZStack {
                DayRing(progress: 1, size: 64)
                Image(systemName: "checkmark").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.forest)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Everyone's happy").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text(doneToday > 0 ? String(localized: "\(doneToday) care moments logged today.", comment: "%lld count (plural)") : String(localized: "No plant needs you today. Just enjoy them.", comment: "Caught-up card"))
                    .font(.subheadline).foregroundStyle(Jungle.subtle)
                if let next {
                    Text("\(next.date.formatted(.dateTime.weekday(.wide))): \(next.title)", comment: "%1$@ weekday, %2$@ task").font(.subheadline.weight(.medium)).foregroundStyle(Jungle.accentText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
        }
        .padding(16).jungleCard()
        .accessibilityElement(children: .combine)
    }
}

struct CompactRequestRow: View {
    let plant: Plant
    let request: PlantRequest
    var body: some View {
        HStack(spacing: 12) {
            PlantAvatar(data: plant.photo, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(PlantVoice.say(request, plant: plant)).font(.subheadline).foregroundStyle(Jungle.subtle).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
        }
        .padding(12).contentShape(Rectangle())
    }
}

enum TodayRoute: Hashable { case watering, health, season, learn, chat }

/// Everything that needs water or a soil check, grouped by day, with one-tap logging.
struct WateringListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]

    var body: some View {
        let items = Agenda.items(plants: plants, tasks: [], days: 14).filter { $0.kind == .soilCheck || $0.kind == .water }
        let days = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }.sorted { $0.key < $1.key }
        let today = days.first { Calendar.current.isDateInToday($0.key) }?.value.compactMap(\.plant) ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if today.count > 1 {
                    Button { withAnimation { JungleBrain.quick(.water, plants: today, in: ctx, announce: true) } } label: {
                        Text("Water all \(today.count) due today").font(.headline).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Jungle.forest)
                }
                if days.isEmpty {
                    JungleGroup { JungleRow(icon: .shieldCheck, title: String(localized: "No one's thirsty for the next two weeks", comment: "Watering list empty state")) }
                }
                ForEach(days, id: \.key) { day, list in
                    JungleGroup(title: String(localized: "\(dayTitle(day)) · \(list.count)", comment: "Group header; %@ day, %lld plant count")) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, item in
                            if let p = item.plant {
                                HStack(spacing: 12) {
                                    NavigationLink(value: p.id) {
                                        HStack(spacing: 12) {
                                            PlantAvatar(data: p.photo, size: 40)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(p.name).foregroundStyle(Jungle.text)
                                                Text(waterLine(p)).font(.caption).foregroundStyle(Jungle.subtle)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }.buttonStyle(.plain)
                                    Button { withAnimation { JungleBrain.quick(.water, plants: [p], in: ctx, announce: true) } } label: {
                                        Icon3DView(.waterDrops, size: 22).frame(width: 40, height: 40).background(Jungle.mint, in: Circle())
                                    }
                                    .buttonStyle(.plain).accessibilityLabel(String(localized: "Log water for \(p.name)", comment: "VoiceOver; %@ plant name"))
                                }
                                .padding(.vertical, 10)
                                if i < list.count - 1 { Divider().padding(.leading, 52) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle("Watering")
    }

    private func dayTitle(_ d: Date) -> String {
        let c = Calendar.current
        if c.isDateInToday(d) { return String(localized: "Today", comment: "Short day label; max 10 chars") }
        if c.isDateInTomorrow(d) { return String(localized: "Tomorrow", comment: "Short day label; max 10 chars") }
        return d.formatted(.dateTime.weekday(.wide).day().month())
    }
    private func waterLine(_ p: Plant) -> String {
        guard let w = p.lastEvent(.water)?.date else { return String(localized: "Feel the soil first", comment: "Watering list subtitle") }
        let d = Int(CareEngine.days(from: w))
        return d == 0 ? String(localized: "Last water today · feel the soil first", comment: "Watering list subtitle") : String(localized: "Last water \(d) days ago · feel the soil first", comment: "%lld days (plural)")
    }
}

/// Every plant's mood, the ones that need you first, with the reason.
struct JungleHealthView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]

    var body: some View {
        let sorted = plants.sorted { rank(CareEngine.mood(for: $0)) < rank(CareEngine.mood(for: $1)) }
        let need = Set(plants.filter { CareEngine.needsYou($0) }.map(\.id))
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    JungleHealthCard(plants: plants, needIDs: need)
                }
                JungleGroup(title: String(localized: "Your plants", comment: "Group title")) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, p in
                        NavigationLink(value: p.id) {
                            HStack(spacing: 12) {
                                PlantAvatar(data: p.photo, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundStyle(Jungle.text)
                                    Text(reason(p)).font(.caption).foregroundStyle(CareEngine.mood(for: p) == .needsYou ? Jungle.warmText : Jungle.subtle).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                StatusBadge(status: CareEngine.status(for: p))
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if i < sorted.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle("Health")
    }

    private func rank(_ m: CareEngine.Mood) -> Int { m == .needsYou ? 0 : m == .fine ? 1 : 2 }
    private func reason(_ p: Plant) -> String {
        if let r = CareEngine.requests(for: p).first { return PlantVoice.say(r, plant: p) }
        return String(localized: "Everyone's feeling good", comment: "Health list reason")
    }
}
