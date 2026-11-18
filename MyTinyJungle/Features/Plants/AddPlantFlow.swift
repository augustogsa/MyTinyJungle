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

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture: capture
                case .reading: reading
                case .meet: meet
                }
            }
            .background(Jungle.cream)
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
                if !nameEdited { name = plan.suggestedName }
                personality = plan.suggestedPersonality
                if plan.outdoorsHint && location.isEmpty { outdoor = true }
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
                Text("Snap your new plant").font(.title2.weight(.bold)).foregroundStyle(Jungle.text)
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
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
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
                Text(species == nil ? "Pick the species first" : "Welcome \(name.isEmpty ? "home" : name) 🌱")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
            .disabled(species == nil && name.isEmpty)
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
                TextField("Name", text: $name, prompt: Text("Name").foregroundStyle(.white.opacity(0.7)))
                    .font(.largeTitle.weight(.bold)).foregroundStyle(.white)
                    .onChange(of: name) { _, _ in nameEdited = true }
                if let s = species { Text(s.scientific).font(.subheadline).italic().foregroundStyle(.white.opacity(0.85)) }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius + 4, style: .continuous))
    }

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(candidates.isEmpty ? "Which plant is this?" : "I think I'm a…").font(.headline).foregroundStyle(Jungle.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(candidates) { c in
                        Button {
                            withAnimation(.snappy) { species = c.species }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.species.commonName).font(.subheadline.weight(.semibold))
                                Text(c.id == candidates.first?.id ? "Best match" : c.source).font(.caption2).opacity(0.8)
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
            if let s = species, !candidates.contains(where: { $0.species == s }) {
                Text("Chosen: \(s.commonName)").font(.caption).foregroundStyle(Jungle.subtle)
            }
        }
    }

    private func healthSection(_ r: PhotoRead) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("First look", systemImage: "eye").font(.headline).foregroundStyle(Jungle.text)
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
            Text("How I like to live").font(.headline).foregroundStyle(Jungle.text)
            ForEach([p.firstWater, p.food, p.spot] + [p.neighbours, p.potAndSoil, p.safety].compactMap { $0 }) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.symbol).font(.title3).foregroundStyle(item.symbol == "pawprint.fill" ? Jungle.terracotta : Jungle.leaf).frame(width: 28)
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
            Text("Personality").font(.headline).foregroundStyle(Jungle.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Personality.allCases) { p in
                        Button(p.label) { withAnimation(.snappy) { personality = p } }
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
        let rooms = (plants.map(\.location).filter { !$0.isEmpty } + ["Living room", "Bedroom", "Kitchen", "Bathroom", "Office", "Balcony"]).uniqued()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Where will I live?").font(.headline).foregroundStyle(Jungle.text)
            TextField("Room or spot", text: $location)
                .padding(12).background(Jungle.mist, in: RoundedRectangle(cornerRadius: Jungle.innerRadius))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rooms.prefix(8), id: \.self) { r in
                        Button(r.capitalized) {
                            location = r
                            if ["balcony", "garden", "terrace", "varanda", "jardim"].contains(r.folded) { outdoor = true }
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
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
            let r = await local
            let rem = await remote
            let minimum = Task { try? await Task.sleep(for: .seconds(1.6)) }
            _ = await minimum.value
            read = r
            var c = rem
            for cand in PlantIdentifier.candidates(from: r) where !c.contains(where: { $0.species == cand.species }) { c.append(cand) }
            candidates = Array(c.prefix(5))
            withAnimation(.snappy) {
                stage = .meet
                species = candidates.first?.species
            }
        }
    }

    private func save() {
        guard species != nil || !name.isEmpty else { return }
        let s = species
        let plant = Plant(name: name.isEmpty ? (s?.en ?? "Plant") : name, speciesID: s?.id, personality: personality, location: location)
        plant.isOutdoor = outdoor
        plant.photo = photo
        ctx.insert(plant)
        if let photo {
            let e = CareEvent(kind: .photo, note: "First photo", source: "onboarding"); e.photo = photo; e.plant = plant; ctx.insert(e)
        }
        if let m = read?.soilMoisture {
            let e = CareEvent(kind: .soilCheck, note: "Photo estimate", source: "photo"); e.soil = m; e.plant = plant; ctx.insert(e)
        }
        if let s {
            let plan = PlantAdvisor.plan(species: s, read: read, existing: plants.filter { $0.id != plant.id })
            var intro = "Hi, I'm \(plant.name)! I'm a \(s.en) (\(s.scientific)). "
            intro += read.map { $0.healthSummary + " " } ?? ""
            intro += "\(plan.firstWater.title). \(plan.spot.title)."
            if let n = plan.neighbours { intro += " \(n.title)." }
            let sugg = read?.soilMoisture == .dry ? ["Watered"] : ["Dry", "Slightly moist", "Wet"]
            ctx.insert(ChatMessage(text: intro, fromUser: false, plant: plant, suggestions: sugg))
            let j = ChatMessage(text: "Hi everyone! I'm new here. \(plan.spot.title.lowercased().capitalizedFirst).", fromUser: false)
            j.speakerID = plant.id
            ctx.insert(j)
        } else {
            ctx.insert(ChatMessage(text: "Hi, I'm \(plant.name)! What kind of plant am I?", fromUser: false, plant: plant))
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
        .accessibilityLabel("Leaf colour: \(Int(read.greenShare / total * 100))% green")
    }
}

private struct ReadingSteps: View {
    @State private var step = 0
    private let steps = ["Looking at the leaves…", "Working out the species…", "Checking the soil…", "Writing my care plan…"]
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(steps[step % steps.count]).font(.headline).foregroundStyle(Jungle.text)
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
