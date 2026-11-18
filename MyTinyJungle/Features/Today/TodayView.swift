import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \ChatMessage.date) private var allMessages: [ChatMessage]
    @State private var chipKind: CareKind?
    @State private var soilPlant: Plant?
    @State private var showSettings = false
    @State private var path = NavigationPath()
    @State private var paywall = false
    @State private var addingPlant = false

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
                            carousel
                            HStack(spacing: 10) {
                                StatTile(value: "\(requests.count)", label: "Requests", symbol: "bell.fill", tint: Jungle.terracotta)
                                StatTile(value: "\(upcoming)", label: "This week", symbol: "calendar", tint: Jungle.leaf)
                                StatTile(value: "\(plants.count - requests.count)", label: "All good", symbol: "checkmark", tint: Jungle.forest)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle("Today")
                                if requests.isEmpty {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sun.max.fill").font(.title3).foregroundStyle(Jungle.sun)
                                        Text("Everyone is happy today. Nothing to do.").foregroundStyle(Jungle.text)
                                    }
                                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
                                }
                                ForEach(requests, id: \.1.id) { plant, req in
                                    RequestCard(plant: plant, request: req) { action in handle(action, plant: plant) }
                                        .onTapGesture { path.append(plant.id) }
                                }
                            }
                            conversations
                        }
                        if !jungleMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle("Jungle chat")
                                ForEach(jungleMessages) { m in
                                    Group {
                                        if m.logCard != nil {
                                            LoggedCardView(message: m, plants: plants)
                                        } else {
                                            MessageBubble(message: m, speaker: m.speakerID.flatMap { id in plants.first { $0.id == id } }) { send($0) }
                                        }
                                    }
                                    .id(m.id)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                }
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: allMessages.count) { withAnimation(.snappy) { proxy.scrollTo("bottom") } }
                .animation(.snappy, value: requests.map(\.1.id))
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 4) {
                        if !plants.isEmpty { QuickChips { chipKind = $0 } }
                        Composer(placeholder: plants.isEmpty ? "Tell me about your plant…" : "What did you do? Ask anything…") { text, photo in
                            JungleBrain.handle(text, photo: photo, plant: nil, plants: plants, in: ctx)
                        }
                    }
                    .padding(.top, 6)
                    .background(.bar)
                }
            }
            .jungleBackdrop()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Label("My Tiny Jungle", systemImage: "leaf.fill").labelStyle(.titleAndIcon)
                        .font(.headline).foregroundStyle(Jungle.accentText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let p = plants.first(where: { $0.id == id }) { PlantHomeView(plant: p) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $paywall) { PaywallView(reason: .morePlants) }
            .sheet(isPresented: $addingPlant) { AddPlantFlow() }
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
            .confirmationDialog("How does \(soilPlant?.name ?? "the") soil feel?", isPresented: Binding(get: { soilPlant != nil }, set: { if !$0 { soilPlant = nil } }), titleVisibility: .visible) {
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
                        Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(Jungle.accentText)
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

    /// Each plant's latest line, like a messages inbox.
    private var conversations: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Conversations")
            VStack(spacing: 0) {
                ForEach(plants) { p in
                    let last = (p.messages ?? []).max { $0.date < $1.date }
                    NavigationLink { PlantChatView(plant: p) } label: {
                        HStack(spacing: 12) {
                            PlantAvatar(data: p.photo, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(p.name).font(.headline).foregroundStyle(Jungle.text)
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
        case .water: "Who did you water?"
        case .feed: "Who did you feed?"
        case .soilCheck: "Whose soil did you check?"
        default: "Which plant?"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting).font(.largeTitle.weight(.bold)).foregroundStyle(Jungle.text)
            Text(plants.isEmpty ? "Let's grow your little jungle." : requests.isEmpty ? "Your plants are happy today." : "Your plants have \(requests.count) update\(requests.count == 1 ? "" : "s").")
                .font(.body).foregroundStyle(Jungle.subtle)
        }
        .padding(.top, 4)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = JungleSettings.shared.ownerName
        let base = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private func send(_ text: String) {
        if text == "See Plus" { paywall = true; return }
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
                    Text(plant.name).font(.headline).foregroundStyle(Jungle.text)
                    Text(plant.species?.commonName ?? "Unknown species").font(.caption).foregroundStyle(Jungle.subtle)
                }
                Spacer()
                Image(systemName: icon).foregroundStyle(request.priority == 0 ? Jungle.terracotta : Jungle.leaf).accessibilityHidden(true)
            }
            Text("“\(PlantVoice.say(request, plant: plant))”").font(.body).foregroundStyle(Jungle.text)
            Text(request.reason).font(.caption).foregroundStyle(Jungle.subtle)
            HStack(spacing: 8) { buttons }
        }
        .padding(14)
        .jungleCard()
        .contentShape(Rectangle())
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
                Button(s == .slightlyMoist ? "Moist" : s.label) { onAction(.soil(s)) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        case .water:
            Button("Watered", systemImage: "drop.fill") { onAction(.care(.water)) }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        case .feed:
            Button("Fed", systemImage: "checkmark") { onAction(.care(.feed)) }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            Button("Ask why") { onAction(.open) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
        case .safety:
            Button("Got it") { onAction(.ack) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
        default:
            Button("Talk to \(plant.name)") { onAction(.open) }.buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }
}

struct EmptyJungle: View {
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "leaf").font(.largeTitle).foregroundStyle(Jungle.leaf).accessibilityHidden(true)
            Text("Your jungle is empty").font(.title3.weight(.semibold)).foregroundStyle(Jungle.text)
            Text("Just tell me about a plant, like \"I have a monstera called Milo in the living room\", or add one in Plants with a photo.")
                .foregroundStyle(Jungle.subtle)
            if let onAdd {
                Button(action: onAdd) { Label("Snap your first plant", systemImage: "camera.fill") }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).padding(.top, 4)
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
                Circle().fill(mood == .needsYou ? Jungle.terracotta : mood == .fine ? Jungle.sun : Jungle.leaf)
                    .frame(width: 12, height: 12).overlay(Circle().stroke(.white, lineWidth: 2)).padding(10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name).font(.headline).foregroundStyle(Jungle.text).lineLimit(1)
                Text(plant.species?.commonName ?? "Plant").font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 150)
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        .jungleCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plant.name), \(mood == .needsYou ? "needs you" : mood == .fine ? "doing fine" : "thriving")")
    }
}
