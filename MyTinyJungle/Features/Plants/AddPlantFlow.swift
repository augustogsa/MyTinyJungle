import SwiftUI
import SwiftData
import PhotosUI

/// Photo-first onboarding: snap → read (species, leaf health, soil) → meet your plant with a ready care plan.
struct AddPlantFlow: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]

    enum Stage { case capture, reading, meet }
    @State private var stage: Stage = .capture
    @State private var photo: Data?
    @State private var read: PhotoRead?
    @State private var candidates: [PlantIdentifier.Candidate] = []
    @State private var species: Species?
    @State private var name = ""
    @State private var personality: Personality = .cheerful
    @State private var location = ""
    @State private var outdoor = false
    @State private var pick: PhotosPickerItem?
    @State private var showCamera = false
    @State private var choosingSpecies = false
    @State private var nameEdited = false
    @State private var locationEdited = false

    var body: some View {
        DuoCompanion(mood: .plant, title: "A new green friend", detail: "Snap it, meet it, and it moves in.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture: capture
                case .reading: reading
                case .meet: meet
                }
            }
            .jungleBackdrop()
            .animation(.snappy, value: stage)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $choosingSpecies) { SpeciesPicker(selection: $species) }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in showCamera = false; if let data { start(with: data) } }.ignoresSafeArea()
            }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task { if let d = try? await item.loadTransferable(type: Data.self) { start(with: d) }; pick = nil }
            }
            .onChange(of: species) { _, s in
                guard let s else { return }
                if stage == .capture { stage = .meet }
                let plan = PlantAdvisor.plan(species: s, read: read, existing: plants)
                personality = plan.suggestedPersonality
                if !nameEdited { name = plan.suggestedName }
                if !locationEdited { location = PlantAdvisor.suggestedRoom(for: s, existing: plants); outdoor = plan.outdoorsHint || Icon3D.room(location) == .balcony }
            }
        }
    }

    // MARK: capture

    private var capture: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(Jungle.mint).frame(width: 180, height: 180)
                Image(systemName: "camera.macro").font(.system(size: 64, weight: .light)).foregroundStyle(Jungle.leaf)
            }
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Snap your new plant").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text("Get the whole plant and a bit of its soil in the shot. I'll work out who it is, how it's doing and how to look after it.")
                    .multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Label("Take a photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).fontDesign(.rounded).controlSize(.large)
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).fontDesign(.rounded).controlSize(.large)
                Button("I know the species") { choosingSpecies = true }
                    .font(.subheadline).padding(.top, 4)
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: reading

    private var reading: some View {
        VStack(spacing: 24) {
            Spacer()
            if let photo, let img = UIImage(data: photo) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 220, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Jungle.leaf.opacity(0.5), lineWidth: 2))
                    .phaseAnimator([0.97, 1.0]) { v, p in v.scaleEffect(p) } animation: { _ in .easeInOut(duration: 0.9) }
            }
            ReadingSteps()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: meet

    private var meet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                speciesSection
                if let s = species { factsSection(s) }
                nameSection
                if let read, photo != nil { healthSection(read) }
                if let s = species {
                    let plan = PlantAdvisor.plan(species: s, read: read, existing: plants)
                    planSection(plan)
                    personalitySection
                    homeSection(plan)
                }
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                Text(species == nil && name.isEmpty ? Grammar.pt(String(localized: "Pick the species first", comment: "Save button disabled hint")) : name.isEmpty ? Grammar.pt(String(localized: "Welcome home", comment: "Save button; max 24 chars")) : Grammar.pt(String(localized: "Welcome \(name)", comment: "Save button; arg plant name; max 24 chars")))
                    .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.large)
            .disabled(name.isEmpty && species == nil)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("Meet your plant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo, let img = UIImage(data: photo) { Image(uiImage: img).resizable().scaledToFill() }
                else { ZStack { Jungle.mint; Image(systemName: "leaf").font(.system(size: 60)).foregroundStyle(Jungle.leaf) } }
            }
            .frame(height: 280).frame(maxWidth: .infinity)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(species?.commonName ?? Grammar.pt(String(localized: "New plant", comment: "Hero title before species chosen"))).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.white)
                if let s = species { Text(s.scientific).font(.subheadline).italic().foregroundStyle(.white.opacity(0.85)) }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius + 4, style: .continuous))
    }

    private var popular: [Species] {
        ["monstera-deliciosa", "epipremnum-aureum", "sansevieria", "zamioculcas", "spathiphyllum", "ficus-lyrata", "phalaenopsis", "calathea", "aloe-vera", "ocimum-basilicum", "echeveria", "chlorophytum"]
            .compactMap { SpeciesLibrary.shared.species(id: $0) }
    }

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(candidates.isEmpty ? "Which plant is this?" : "I think I'm a…").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(candidates) { c in
                        Button {
                            withAnimation(.snappy) { species = c.species }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.species.commonName).font(.subheadline.weight(.semibold))
                                Text(c.id == candidates.first?.id ? Grammar.pt(String(localized: "Best match", comment: "Species candidate tag; max 14 chars")) : c.source).font(.caption2).opacity(0.8)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundStyle(species == c.species ? Color.white : Jungle.text)
                            .background(species == c.species ? Jungle.forest : Jungle.mist, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button { choosingSpecies = true } label: {
                        Label(candidates.isEmpty ? "Search species" : "Something else", systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Jungle.mist, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if candidates.isEmpty {
                Text("Popular plants").font(.subheadline).foregroundStyle(Jungle.subtle)
                FlowChips(items: popular.map(\.commonName), selected: species?.commonName) { name in
                    withAnimation(.snappy) { species = popular.first { $0.commonName == name } }
                }
            } else if let s = species, !candidates.contains(where: { $0.species == s }) {
                Text("Chosen: \(s.commonName)").font(.caption).foregroundStyle(Jungle.subtle)
            }
        }
    }

    private var nameIdeas: [String] { PlantAdvisor.nameIdeas(for: species, personality: personality, existing: plants) }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What's my name?").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Spacer()
                Button {
                    let ideas = nameIdeas.filter { $0 != name }
                    withAnimation(.snappy) { name = ideas.randomElement() ?? name; nameEdited = false }
                } label: { Label("Shuffle", systemImage: "dice").font(.subheadline.weight(.medium)) }
                .accessibilityHint("Suggests another name")
            }
            TextField("Name", text: Binding(get: { name }, set: { name = $0; nameEdited = true }))
                .font(.system(.title2, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
                .submitLabel(.done)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(nameIdeas.prefix(8), id: \.self) { idea in
                        Button(idea) { withAnimation(.snappy) { name = idea; nameEdited = false } }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium)).fontDesign(.rounded)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(name == idea ? Color.white : Jungle.text)
                            .background(name == idea ? Jungle.forest : Jungle.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Jungle.border, lineWidth: name == idea ? 0 : 0.5))
                    }
                }
            }
            Text(species == nil ? "Ideas from its personality. Pick the species for names made for it." : "Ideas from its species, family and personality.")
                .font(.caption).foregroundStyle(Jungle.subtle)
        }
        .padding(14).jungleCard()
    }

    /// Everything the app already knows about it, at a glance.
    private func factsSection(_ s: Species) -> some View {
        let petsOK = !(s.toxicCats || s.toxicDogs)
        let facts: [(String, String, String, Color)] = [
            ("drop.fill", Grammar.pt(String(localized: "Water", comment: "Fact tile label; max 10 chars")), Grammar.pt(String(localized: "Every \(Int(s.dryMin))–\(Int(s.dryMax)) days", comment: "Watering interval range in days; max 18 chars")), Jungle.leaf),
            ("sun.max.fill", Grammar.pt(String(localized: "Light", comment: "Fact tile label; max 10 chars")), PlacementEngine.lightLabel(s.light), Jungle.sun),
            ("humidity.fill", Grammar.pt(String(localized: "Humidity", comment: "Fact tile label; max 10 chars")), PlantFormat.percent(s.humidityMin) + "+", Jungle.leaf),
            ("thermometer.medium", Grammar.pt(String(localized: "Temp", comment: "Fact tile label: temperature; max 10 chars")), Climate.tempRange(s.tempMin, s.tempMax), Jungle.terracotta),
            (petsOK ? "pawprint.fill" : "exclamationmark.triangle.fill", Grammar.pt(String(localized: "Pets", comment: "Fact tile label; max 10 chars")), petsOK ? Grammar.pt(String(localized: "Safe", comment: "Pet safety value; max 10 chars")) : Grammar.pt(String(localized: "Toxic", comment: "Pet safety value; max 10 chars")), petsOK ? Jungle.leaf : Jungle.terracotta),
            ("leaf.arrow.triangle.circlepath", Grammar.pt(String(localized: "Feed", comment: "Fact tile label: fertilize; max 10 chars")), Grammar.pt(String(localized: "Every \(Int(s.feedWeeks)) wk", comment: "Feeding interval, weeks abbreviated; plural; max 14 chars")), Jungle.leaf),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(facts, id: \.1) { f in
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: f.0).font(.subheadline).foregroundStyle(f.3)
                    Text(f.2).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.8)
                    Text(f.1).font(.caption2).foregroundStyle(Jungle.subtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10).jungleCard()
                .accessibilityElement(children: .combine)
            }
        }
        .transition(.opacity)
    }

    private func healthSection(_ r: PhotoRead) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("First look", systemImage: "eye").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Text(r.healthSummary).foregroundStyle(Jungle.text)
            LeafBar(read: r)
            if r.soilVisible, let m = r.soilMoisture {
                Label("Soil looks \(m.label.lowercased())", systemImage: "hand.point.down").font(.subheadline).foregroundStyle(Jungle.text)
            }
            Text("Estimated from the photo's colours. I'll get more precise as we go.").font(.caption).foregroundStyle(Jungle.subtle)
        }
        .padding(14).jungleCard()
    }

    private func planSection(_ p: WelcomePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How I like to live").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            ForEach([p.firstWater, p.food, p.spot] + [p.neighbours, p.potAndSoil, p.safety].compactMap { $0 }) { item in
                HStack(alignment: .top, spacing: 12) {
                    SmartIcon(symbol: item.symbol, size: 28).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                        Text(item.detail).font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                }
            }
        }
        .padding(14).jungleCard()
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personality").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Personality.allCases) { p in
                        Button(p.label) {
                            withAnimation(.snappy) {
                                personality = p
                                if !nameEdited { name = nameIdeas.first ?? name }
                            }
                        }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(personality == p ? Color.white : Jungle.text)
                            .background(personality == p ? Jungle.leaf : Jungle.mist, in: Capsule())
                    }
                }
            }
            Text(personality.blurb).font(.caption).foregroundStyle(Jungle.subtle)
        }
    }

    private func homeSection(_ plan: WelcomePlan) -> some View {
        let rooms = (plants.map(\.location).filter { !$0.isEmpty } + [Grammar.pt(String(localized: "Living room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Bedroom", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Kitchen", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Bathroom", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Office", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Dining room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Kids room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Hallway", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Windowsill", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Balcony", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Terrace", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Garden", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Greenhouse", comment: "Room suggestion chip; stored as the plant location; max 16 chars"))]).uniqued()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Where will I live?").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            TextField("Room or spot", text: Binding(get: { location }, set: { location = $0; locationEdited = true }))
                .padding(12).background(Jungle.mist, in: RoundedRectangle(cornerRadius: Jungle.innerRadius))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rooms.prefix(14), id: \.self) { r in
                        let on = location.folded == r.folded
                        Button {
                            location = r; locationEdited = true
                            outdoor = [.balcony, .patio, .garden, .backyard, .shed].contains(Icon3D.room(r))
                        } label: {
                            HStack(spacing: 6) { Icon3DView(.room(r), size: 20); Text(r.capitalized) }
                                .font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(on ? Jungle.mint : Jungle.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? Jungle.leaf : Jungle.border, lineWidth: on ? 1.5 : 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Toggle("Outdoors", isOn: $outdoor)
        }
    }

    // MARK: actions

    private func start(with raw: Data) {
        let data = ImageShrinker.jpeg(raw)
        photo = data
        stage = .reading
        Task {
            guard let img = UIImage(data: data) else { return }
            async let local = PlantVision.read(img)
            async let remote = PlantIdentifier.remote(data)
            async let ours = Brain.identify(data)
            let r = await local
            var rem = await ours
            for cand in await remote where !rem.contains(where: { $0.species == cand.species }) { rem.append(cand) }
            let minimum = Task { try? await Task.sleep(for: .seconds(1.6)) }
            _ = await minimum.value
            read = r
            var c = rem
            for cand in PlantIdentifier.candidates(from: r) where !c.contains(where: { $0.species == cand.species }) { c.append(cand) }
            candidates = Array(c.prefix(5))
            withAnimation(.snappy) {
                stage = .meet
                species = candidates.first?.species
                if species == nil, !nameEdited { name = nameIdeas.first ?? "" }
            }
        }
    }

    private func save() {
        guard species != nil || !name.isEmpty else { return }
        let s = species
        let plant = Plant(name: name.isEmpty ? (s?.commonName ?? Grammar.pt(String(localized: "Plant", comment: "Default plant name"))) : name, speciesID: s?.id, personality: personality, location: location)
        plant.isOutdoor = outdoor
        plant.photo = photo
        ctx.insert(plant); Analytics.track("plant_added")
        ErtyCheer.shared.show(.celebrate, Grammar.pt(String(localized: "Welcome home, \(plant.name)", comment: "Little celebration when a plant is added; arg is plant name")))
        if let photo {
            let e = CareEvent(kind: .photo, note: "First photo", source: "onboarding"); e.photo = photo; e.plant = plant; ctx.insert(e)
        }
        if let m = read?.soilMoisture {
            let e = CareEvent(kind: .soilCheck, note: Grammar.pt(String(localized: "Photo estimate", comment: "Timeline note: soil estimated from photo")), source: "photo"); e.soil = m; e.plant = plant; ctx.insert(e)
        }
        if let s {
            let plan = PlantAdvisor.plan(species: s, read: read, existing: plants.filter { $0.id != plant.id })
            let hello = Grammar.pt(String(localized: "Hi, I'm \(plant.name)! I'm a \(s.commonName) (\(s.scientific)).", comment: "Plant voice intro in chat; args plant name, common species name, scientific name"))
            let tips = [plan.firstWater.title, plan.spot.title, plan.neighbours?.title].compactMap { $0 }.map { "\($0)." }
            let intro = ([hello] + (read.map { [$0.healthSummary] } ?? []) + tips).joined(separator: " ")
            let sugg = read?.soilMoisture == .dry ? [Grammar.pt(String(localized: "Watered", comment: "Chat quick reply chip; max 14 chars"))] : [Grammar.pt(String(localized: "Dry", comment: "Chat quick reply chip: soil feels dry; max 14 chars")), Grammar.pt(String(localized: "Slightly moist", comment: "Chat quick reply chip: soil state; max 14 chars")), Grammar.pt(String(localized: "Wet", comment: "Chat quick reply chip: soil feels wet; max 14 chars"))]
            ctx.insert(ChatMessage(text: intro, fromUser: false, plant: plant, suggestions: sugg))
            let j = ChatMessage(text: Grammar.pt(String(localized: "Hi everyone! I'm new here. \(plan.spot.title.lowercased().capitalizedFirst).", comment: "Plant voice in group chat; arg sentence about its spot")), fromUser: false)
            j.speakerID = plant.id
            ctx.insert(j)
        } else {
            ctx.insert(ChatMessage(text: Grammar.pt(String(localized: "Hi, I'm \(plant.name)! What kind of plant am I?", comment: "Plant voice intro when species unknown; arg plant name")), fromUser: false, plant: plant))
        }
        try? ctx.save()
        dismiss()
    }
}

private extension String { var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() } }

/// Leaf colour share bar: green / yellow / brown.
struct LeafBar: View {
    let read: PhotoRead
    var body: some View {
        let total = max(read.greenShare + read.yellowShare + read.brownShare, 0.0001)
        GeometryReader { geo in
            HStack(spacing: 2) {
                Rectangle().fill(Jungle.leaf).frame(width: geo.size.width * read.greenShare / total)
                Rectangle().fill(Jungle.sun).frame(width: geo.size.width * read.yellowShare / total)
                Rectangle().fill(Jungle.terracotta).frame(width: geo.size.width * read.brownShare / total)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .accessibilityLabel("Leaf colour: \((read.greenShare / total).formatted(.percent.precision(.fractionLength(0)))) green")
    }
}

private struct ReadingSteps: View {
    @State private var step = 0
    private let steps = [Grammar.pt(String(localized: "Looking at the leaves…", comment: "Loading step while reading photo; plant voice; max 30 chars")), Grammar.pt(String(localized: "Working out the species…", comment: "Loading step while reading photo; plant voice; max 30 chars")), Grammar.pt(String(localized: "Checking the soil…", comment: "Loading step while reading photo; plant voice; max 30 chars")), Grammar.pt(String(localized: "Writing my care plan…", comment: "Loading step while reading photo; plant voice; max 30 chars"))]
    var body: some View {
        VStack(spacing: 10) {
            ErtyView(mood: .scan, size: 96)
            Text(steps[step % steps.count]).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                .contentTransition(.opacity)
                .id(step)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation { step += 1 }
            }
        }
    }
}

/// System camera for the first photo.
struct CameraPicker: UIViewControllerRepresentable {
    var onDone: (Data?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onDone: (Data?) -> Void
        init(onDone: @escaping (Data?) -> Void) { self.onDone = onDone }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onDone((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { onDone(nil) }
    }
}
