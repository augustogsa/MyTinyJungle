import SwiftUI
import SwiftData
import PhotosUI

/// Photo-first onboarding: snap → read (species, leaf health, soil) → meet your plant with a ready care plan.
struct AddPlantFlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]

    enum Stage { case capture, reading, slow, meet }
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
    /// No real identification came back: on-device guesses are suggestions only.
    @State private var unsure = false
    @State private var nameSeed = UInt64.random(in: 1...UInt64.max)
    @State private var setup = PlantSetupDraft()
    @State private var sceneOutdoor: Bool?
    /// Our server's top guess, reported back with the owner's pick.
    @State private var serverTop: String?
    @State private var shelf = false
    /// A photo the Scan camera already took: skips straight to reading it.
    private let initialPhoto: Data?
    /// Photos from a multi-photo scan: all go to identify; the whole-plant one becomes the plant's photo.
    private let initialShots: [ScanShot]
    private let onMorePhoto: ((ShotKind) -> Void)?
    @State private var shots: [ScanShot] = []
    @State private var tips: [ScanTip] = []
    init(initialPhoto: Data? = nil, initialShots: [ScanShot] = [], onMorePhoto: ((ShotKind) -> Void)? = nil) {
        self.initialPhoto = initialPhoto; self.initialShots = initialShots; self.onMorePhoto = onMorePhoto
    }

    var body: some View {
        DuoCompanion(mood: .plant, title: "A new green friend", detail: "Snap it, meet it, and it moves in.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture: capture
                case .reading: reading
                case .slow: slow
                case .meet: meet
                }
            }
            .jungleBackdrop()
            .animation(.snappy, value: stage)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $choosingSpecies) { SpeciesPicker(selection: $species) }
            .task {
                guard photo == nil else { return }
                if !initialShots.isEmpty { start(shots: initialShots) } else if let initialPhoto { start(with: initialPhoto) }
            }
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
                if !nameEdited { name = nameIdeas.first ?? "" }
                if !locationEdited { location = PlantAdvisor.suggestedRoom(for: s, existing: plants); outdoor = sceneOutdoor ?? (plan.outdoorsHint || Icon3D.room(location) == .balcony) }
            }
        }
    }

    // MARK: capture

    private var capture: some View {
        captureBody.sheet(isPresented: $shelf) { ShelfImportView { dismiss() } }
    }

    private var captureBody: some View {
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
                    .buttonStyle(.borderedProminent).junglePrimary().fontDesign(.rounded).controlSize(.large)
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).fontDesign(.rounded).controlSize(.large)
                Button("I know the species") { choosingSpecies = true }
                    .font(.subheadline).padding(.top, 4)
                Button(Grammar.pt(String(localized: "A whole shelf at once", comment: "Add plant: identify several plants from one photo; max 28 chars")), systemImage: "square.grid.3x2") { shelf = true }
                    .font(.subheadline)
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: reading

    private var reading: some View {
        VStack(spacing: 24) {
            Spacer()
            if let photo, let img = Thumbs.image(photo, side: 280) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 220, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Jungle.leaf.opacity(0.5), lineWidth: 2))
                    .phaseAnimator(reduceMotion ? [1.0] : [0.97, 1.0]) { v, p in v.scaleEffect(p) } animation: { _ in .easeInOut(duration: 0.9) }
            }
            ReadingSteps()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// The server took longer than 12 s: say so and offer a retry, never a silent guess.
    private var slow: some View {
        VStack(spacing: 18) {
            Spacer()
            ErtyView(mood: .scan, size: 110)
            VStack(spacing: 6) {
                Text(Grammar.pt(String(localized: "Taking longer than usual", comment: "Add plant: identify timed out; title; max 30 chars")))
                    .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text(Grammar.pt(String(localized: "My plant brain is a bit slow right now. Try again, or search for it yourself.", comment: "Add plant: identify timed out; body")))
                    .font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 10) {
                Button { start(shots: shots) } label: {
                    Label(Grammar.pt(String(localized: "Try again", comment: "Button: retry; max 18 chars")), systemImage: "arrow.clockwise").font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).junglePrimary()
                Button { withAnimation(.snappy) { stage = .meet }; choosingSpecies = true } label: {
                    Label(Grammar.pt(String(localized: "Search species", comment: "Add plant result button; max 20 chars")), systemImage: "magnifyingglass").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.bordered).tint(Jungle.forest)
            }
            .buttonBorderShape(.capsule).controlSize(.large)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: meet

    private var meet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 0) {
                    resultHero
                    speciesCard.padding(.horizontal, 12).offset(y: -36).padding(.bottom, -36)
                }
                if shots.count > 1 { ScanShotStrip(shots: shots).padding(.horizontal, 4) }
                if let onMorePhoto, !tips.isEmpty { ScanTipsCard(tips: Array(tips.prefix(BrainTuning.identifyTips)), onPick: onMorePhoto) }
                step(2, Grammar.pt(String(localized: "Name it", comment: "Add plant result: step title; max 24 chars"))) { nameCard }
                step(3, Grammar.pt(String(localized: "How it lives", comment: "Plant settings section title; max 24 chars"))) { livesCard }
                if let read, photo != nil { healthCard(read) }
                if let s = species { factsSection(s) }
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                Text(species == nil && name.isEmpty ? Grammar.pt(String(localized: "Pick the species first", comment: "Save button disabled hint")) : name.isEmpty ? Grammar.pt(String(localized: "Welcome home", comment: "Save button; max 24 chars")) : Grammar.pt(String(localized: "Welcome \(name)", comment: "Save button; arg plant name; max 24 chars")))
                    .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).junglePrimary().buttonBorderShape(.capsule).controlSize(.large)
            .disabled(name.isEmpty && species == nil)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle(Grammar.pt(String(localized: "Meet your plant", comment: "Add plant result screen title; max 24 chars")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step<C: View>(_ n: Int, _ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: "\(n)").font(.caption.weight(.bold)).foregroundStyle(Jungle.onForest)
                    .frame(width: 22, height: 22).background(Jungle.forest, in: Circle())
                Text(title).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var resultHero: some View {
        Group {
            if let photo, let img = Thumbs.image(photo, side: 440) { Image(uiImage: img).resizable().scaledToFill() }
            else { ZStack { Jungle.mint; Icon3DView(.pottedPlant, size: 90) } }
        }
        .frame(height: 300).frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityLabel(Grammar.pt(String(localized: "Your photo", comment: "VoiceOver: the scanned plant photo on the result screen")))
    }

    /// Plain words for how sure the match is: bands and words from the brain config.
    private func sureWords(_ c: Double) -> (String, Color) {
        let b = BrainTuning.band(c)
        return (b.words, b.color)
    }

    private var speciesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(verbatim: "1").font(.caption.weight(.bold)).foregroundStyle(Jungle.onForest)
                    .frame(width: 22, height: 22).background(Jungle.forest, in: Circle())
                Text(Grammar.pt(String(localized: "Who it is", comment: "Add plant result: step title; max 24 chars"))).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.subtle)
                Spacer()
                if let s = species, let c = candidates.first(where: { $0.species == s }) {
                    let w = sureWords(c.confidence)
                    Text(w.0).font(.caption.weight(.bold)).foregroundStyle(Jungle.text)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(w.1.opacity(0.25), in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
            if let s = species {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.commonName).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    Text(s.scientific).font(.subheadline).italic().foregroundStyle(Jungle.subtle)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Grammar.pt(String(localized: "I couldn't tell who this is", comment: "Add plant result: no species match; max 32 chars"))).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    Text(Grammar.pt(String(localized: "Search for it, or try another photo of a leaf up close.", comment: "Add plant result: no species match, what to do"))).font(.subheadline).foregroundStyle(Jungle.subtle)
                }
            }
            let others = candidates.filter { $0.species != species }.prefix(3)
            if !others.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(species == nil ? Grammar.pt(String(localized: "Could it be one of these?", comment: "Add plant result: alternatives header; max 30 chars")) : Grammar.pt(String(localized: "Or maybe", comment: "Add plant result: alternatives header; max 20 chars")))
                        .font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(others)) { c in
                                Button { withAnimation(.snappy) { species = c.species; if !nameEdited { name = nameIdeas.first ?? name } } } label: {
                                    HStack(spacing: 8) {
                                        Icon3DView(Self.icon(for: c.species), size: 28)
                                            .frame(width: 36, height: 36).background(Jungle.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(c.species.commonName).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).lineLimit(1)
                                            Text(sureWords(c.confidence).0).font(.caption2).foregroundStyle(Jungle.subtle)
                                        }
                                    }
                                    .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 5)
                                    .background(Jungle.fillSubtle, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Jungle.border, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(Grammar.pt(String(localized: "Choose this species", comment: "VoiceOver hint on a species alternative")))
                            }
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Button { choosingSpecies = true } label: {
                    Label(species == nil ? Grammar.pt(String(localized: "Search species", comment: "Add plant result button; max 20 chars")) : Grammar.pt(String(localized: "Not it? Search", comment: "Add plant result button; max 20 chars")), systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: species == nil ? .infinity : nil)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Jungle.forest)
                if species == nil {
                    Button { anotherPhoto() } label: {
                        Label(Grammar.pt(String(localized: "Try another photo", comment: "Add plant result button; max 20 chars")), systemImage: "camera").lineLimit(1).minimumScaleFactor(0.8)
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Jungle.forest)
                }
            }
        }
        .padding(16)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Jungle.cardEdge, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    static func icon(for s: Species) -> Icon3D {
        switch s.group ?? "" {
        case "cactus": .cactus; case "succulent": .succulent; case "fern": .fern; case "palm": .palm; case "orchid", "flowering", "bulb": .flower
        case "herb-soft", "herb": .herbs; case "vegetable": .salad; case "ficus", "shrub", "tree": .tree
        default: .pottedPlant
        }
    }

    /// Back to the scanner on a leaf when Scan opened us; else the system camera.
    private func anotherPhoto() {
        if let onMorePhoto { onMorePhoto(.leaf) } else { showCamera = true }
    }

    private var nameIdeas: [String] { PlantAdvisor.nameIdeas(for: species, personality: personality, existing: plants, seed: nameSeed) }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField(Grammar.pt(String(localized: "Name", comment: "Plant name field placeholder")), text: Binding(get: { name }, set: { name = $0; nameEdited = true }))
                    .font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                    .submitLabel(.done)
                Button {
                    let ideas = nameIdeas.filter { $0 != name }
                    withAnimation(.snappy) { name = ideas.randomElement() ?? name; nameEdited = false }
                } label: { Image(systemName: "dice").font(.body.weight(.semibold)).foregroundStyle(Jungle.accentText).frame(width: 40, height: 40).background(Jungle.mint, in: Circle()) }
                .accessibilityLabel(Grammar.pt(String(localized: "Shuffle", comment: "Add plant: suggest another name")))
            }
            .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
            .background(Jungle.fillSubtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(nameIdeas.prefix(5), id: \.self) { idea in
                        Button(idea) { withAnimation(.snappy) { name = idea; nameEdited = false } }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium)).fontDesign(.rounded)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .jungleChip(selected: name == idea)
                            .accessibilityAddTraits(name == idea ? .isSelected : [])
                    }
                }
            }
        }
        .padding(14).jungleCard()
    }

    private var rooms: [String] {
        (plants.map(\.location).filter { !$0.isEmpty } + [Grammar.pt(String(localized: "Living room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Bedroom", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Kitchen", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Bathroom", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Office", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Dining room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Kids room", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Hallway", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Windowsill", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Balcony", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Terrace", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Garden", comment: "Room suggestion chip; stored as the plant location; max 16 chars")), Grammar.pt(String(localized: "Greenhouse", comment: "Room suggestion chip; stored as the plant location; max 16 chars"))]).uniqued()
    }

    /// Pot as one pick instead of three toggles.
    private enum PotPick: Hashable { case holes, noHoles, cachepot, selfWatering }
    private var potPick: Binding<PotPick> {
        Binding(get: { setup.selfWatering ? .selfWatering : setup.cachepot ? .cachepot : setup.drainage ? .holes : .noHoles },
                set: { p in setup.selfWatering = p == .selfWatering; setup.cachepot = p == .cachepot; setup.drainage = p == .holes || p == .cachepot })
    }
    private enum KindPick: Hashable { case single, several, faux }
    private var kindPick: Binding<KindPick> {
        Binding(get: { setup.artificial ? .faux : setup.multiple ? .several : .single },
                set: { k in setup.artificial = k == .faux; setup.multiple = k == .several })
    }

    private var livesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(Grammar.pt(String(localized: "Indoors or out", comment: "Add plant: segmented indoor/outdoor pick")), selection: $outdoor) {
                Text(Grammar.pt(String(localized: "Indoors", comment: "Segment: plant lives inside; max 12 chars"))).tag(false)
                Text(Grammar.pt(String(localized: "Outdoors", comment: "Segment: plant lives outside; max 12 chars"))).tag(true)
            }
            .pickerStyle(.segmented).padding(.bottom, 10)
            if setup.fromPhoto {
                Label(Grammar.pt(String(localized: "Filled in from your photo. Tap to change.", comment: "Add plant: setup fields were guessed from the photo")), systemImage: "camera.viewfinder")
                    .font(.caption).foregroundStyle(Jungle.subtle).padding(.bottom, 4)
            }
            pickRow(Icon3D.room(location.isEmpty ? "home" : location), Grammar.pt(String(localized: "Room", comment: "Add plant row label: where it lives; max 14 chars")), value: location.isEmpty ? Grammar.pt(String(localized: "Choose", comment: "Add plant: empty picker value; max 12 chars")) : location.capitalized) {
                ForEach(rooms.prefix(14), id: \.self) { r in
                    Button(r.capitalized) { location = r; locationEdited = true; outdoor = [.balcony, .patio, .garden, .backyard, .shed].contains(Icon3D.room(r)) }
                }
            }
            Divider().padding(.leading, 44)
            pickRow(.soil, Grammar.pt(String(localized: "Roots in", comment: "Add plant: growing medium label; max 16 chars")), value: setup.medium.label) {
                Picker("", selection: $setup.medium) { ForEach(GrowingMedium.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
            }
            if setup.medium.inPot {
                Divider().padding(.leading, 44)
                pickRow(.pot, Grammar.pt(String(localized: "Pot", comment: "Scan photo kind: the pot and its drainage; max 14 chars")), value: potLabel(potPick.wrappedValue)) {
                    Picker("", selection: potPick) { ForEach([PotPick.holes, .noHoles, .cachepot, .selfWatering], id: \.self) { Text(potLabel($0)).tag($0) } }
                }
            }
            Divider().padding(.leading, 44)
            pickRow(.sprout, Grammar.pt(String(localized: "Right now", comment: "Add plant: life stage label; max 16 chars")), value: stageLabel(setup.stage)) {
                Picker("", selection: $setup.stage) {
                    Text(stageLabel(nil)).tag(LifeStage?.none)
                    ForEach(LifeStage.allCases) { Text($0.label).tag(Optional($0)) }
                }
            }
            Divider().padding(.leading, 44)
            pickRow(.pottedPlant, Grammar.pt(String(localized: "Kind", comment: "Add plant row: single, several in one pot, or faux; max 14 chars")), value: kindLabel(kindPick.wrappedValue)) {
                Picker("", selection: kindPick) { ForEach([KindPick.single, .several, .faux], id: \.self) { Text(kindLabel($0)).tag($0) } }
            }
            Divider().padding(.leading, 44)
            pickRow(.clover, Grammar.pt(String(localized: "Personality", comment: "Add plant row label; max 14 chars")), value: personality.label) {
                Picker("", selection: Binding(get: { personality }, set: { personality = $0; if !nameEdited { name = nameIdeas.first ?? name } })) {
                    ForEach(Personality.allCases) { Text($0.label).tag($0) }
                }
            }
            if setup.artificial {
                Label(Grammar.pt(String(localized: "Looks like a faux plant! I'll keep it in your jungle for the looks, no care needed.", comment: "Add plant: artificial plant detected; friendly")), systemImage: "sparkles")
                    .font(.footnote).foregroundStyle(Jungle.text)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Jungle.sunFill, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                    .padding(.top, 8)
            }
        }
        .padding(14).jungleCard()
    }

    private func potLabel(_ p: PotPick) -> String {
        switch p {
        case .holes: Grammar.pt(String(localized: "With holes", comment: "Pot pick: has drainage holes; max 18 chars"))
        case .noHoles: Grammar.pt(String(localized: "No holes", comment: "Pot pick: no drainage holes; max 18 chars"))
        case .cachepot: Grammar.pt(String(localized: "In a cachepot", comment: "Pot pick: nursery pot inside a decorative outer pot; max 18 chars"))
        case .selfWatering: Grammar.pt(String(localized: "Self-watering", comment: "Pot pick: self-watering pot; max 18 chars"))
        }
    }

    private func kindLabel(_ k: KindPick) -> String {
        switch k {
        case .single: Grammar.pt(String(localized: "One plant", comment: "Add plant kind pick; max 18 chars"))
        case .several: Grammar.pt(String(localized: "Several in one pot", comment: "Add plant kind pick; max 18 chars"))
        case .faux: Grammar.pt(String(localized: "Faux plant", comment: "Toggle: artificial plant"))
        }
    }

    private func pickRow<M: View>(_ icon: Icon3D, _ title: String, value: String, @ViewBuilder menu: () -> M) -> some View {
        Menu { menu() } label: {
            HStack(spacing: 12) {
                Icon3DView(icon, size: 26).frame(width: 32)
                Text(title).font(.subheadline).foregroundStyle(Jungle.text)
                Spacer(minLength: 8)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold)).foregroundStyle(Jungle.subtle)
            }
            .padding(.vertical, 11).contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func healthCard(_ r: PhotoRead) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Icon3DView(.healthShield, size: 34)
            VStack(alignment: .leading, spacing: 8) {
                Text(Grammar.pt(String(localized: "First look", comment: "Add plant result: photo health card title; max 20 chars"))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(r.healthSummary).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                if r.health != .unknown { LeafBar(read: r) }
                if r.soilVisible, let m = r.soilMoisture {
                    Label(Grammar.pt(String(localized: "Soil looks \(m.label.lowercased())", comment: "Health analysis soil value; arg is soil state like dry/moist/wet (lowercase); max 18 chars")), systemImage: "hand.point.down").font(.footnote).foregroundStyle(Jungle.subtle)
                }
                Text(Grammar.pt(String(localized: "Estimated from the photo's colours. I'll get more precise as we go.", comment: "Add plant: first look footnote"))).font(.caption).foregroundStyle(Jungle.subtle)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
        .accessibilityElement(children: .combine)
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
        return VStack(alignment: .leading, spacing: 10) {
            Text(Grammar.pt(String(localized: "What I need", comment: "Add plant result: species care facts title; plant voice; max 20 chars"))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 14) {
                ForEach(facts, id: \.1) { f in
                    VStack(alignment: .leading, spacing: 3) {
                        Image(systemName: f.0).font(.subheadline).foregroundStyle(f.3)
                        Text(f.2).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text).lineLimit(1).minimumScaleFactor(0.8)
                        Text(f.1).font(.caption2).foregroundStyle(Jungle.subtle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(14).jungleCard()
        .transition(.opacity)
    }

    // MARK: actions

    private func start(with raw: Data) { start(shots: [ScanShot(data: raw, kind: .leaf)]) }

    private func start(shots all: [ScanShot]) {
        guard let lead = all.first(where: { $0.kind == .leaf }) ?? all.first else { return }
        shots = all
        // The plant's own photo is the whole-plant shot when there is one.
        let data = ImageShrinker.jpeg((all.first { $0.kind == .whole } ?? all[0]).data)
        photo = data
        stage = .reading
        Task {
            // One 768 px upload per photo for every call; the on-device read runs alongside the server.
            let parts = await Task.detached(priority: .userInitiated) { all.map { (BrainPhoto.make($0.data), $0.kind) } }.value
            let bp = parts.first { $0.1 == lead.kind }?.0 ?? parts[0].0
            guard let img = bp.image ?? UIImage(data: data) else { return }
            async let local = PlantVision.read(img, wholePlant: lead.kind == .whole || all.count == 1)
            async let remote = Brain.withTimeout(BrainTuning.remoteTimeout) { await PlantIdentifier.remote(bp.jpeg) }
            async let ours = Brain.identify(shots: parts)
            var r = await local
            let scene = await ours
            if scene.timedOut { withAnimation(.snappy) { stage = .slow }; return }
            tips = scene.tips
            if scene.scene?.looksAlive == true { r.sceneHasLeaves = true }
            var rem = scene.candidates
            serverTop = scene.candidates.first?.species.id
            if let sc = scene.scene { setup.apply(sc); sceneOutdoor = sc.isOutdoor; if let o = sc.isOutdoor { outdoor = o } }
            for cand in await remote ?? [] where !rem.contains(where: { $0.species == cand.species }) { rem.append(cand) }
            let minimum = Task { try? await Task.sleep(for: .seconds(BrainTuning.minReveal)) }
            _ = await minimum.value
            read = r
            // Photo-based top 3 only: the server first, then on-device matches by name. No fixed fallback list.
            var c = rem
            if BrainTuning.onDeviceCandidates {
                for cand in PlantIdentifier.candidates(from: r) where !c.contains(where: { $0.species == cand.species }) { c.append(cand) }
            }
            unsure = c.isEmpty
            candidates = Array(c.prefix(BrainTuning.maxCandidates))
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
        setup.write(to: plant)
        ctx.insert(plant); Analytics.track("plant_added")
        if let top = serverTop { Task { await Brain.identifyFeedback(suggested: top, chosen: s?.id) } }
        ErtyCheer.shared.show(.celebrate, Grammar.pt(String(localized: "Welcome home, \(plant.name)", comment: "Little celebration when a plant is added; arg is plant name")))
        if let photo {
            let e = CareEvent(kind: .photo, note: "First photo", source: "onboarding"); e.photo = photo; e.plant = plant; ctx.insert(e)
        }
        if setup.artificial {
            ctx.insert(ChatMessage(text: Grammar.pt(String(localized: "Hi, I'm \(plant.name)! Faux and fabulous: I never get thirsty, so you can relax. A little dusting keeps me shiny.", comment: "Artificial plant intro in chat, playful; arg plant name")), fromUser: false, plant: plant))
            try? ctx.save(); dismiss(); return
        }
        if let m = read?.soilMoisture, setup.medium.usesSoil {
            let e = CareEvent(kind: .soilCheck, note: Grammar.pt(String(localized: "Photo estimate", comment: "Timeline note: soil estimated from photo")), source: "photo"); e.soil = m; e.plant = plant; ctx.insert(e)
        }
        if let s {
            let plan = PlantAdvisor.plan(species: s, read: read, existing: plants.filter { $0.id != plant.id })
            let hello = Grammar.pt(String(localized: "Hi, I'm \(plant.name)! I'm a \(s.commonName) (\(s.scientific)).", comment: "Plant voice intro in chat; args plant name, common species name, scientific name"))
            let tips = [plan.firstWater.title, plan.spot.title, plan.neighbours?.title].compactMap { $0 }.map { "\($0)." }
            let intro = ([hello] + (read.map { [$0.healthSummary] } ?? []) + tips).joined(separator: " ")
            let sugg = !setup.medium.usesSoil ? [String]() : read?.soilMoisture == .dry ? [Grammar.pt(String(localized: "Watered", comment: "Chat quick reply chip; max 14 chars"))] : [Grammar.pt(String(localized: "Dry", comment: "Chat quick reply chip: soil feels dry; max 14 chars")), Grammar.pt(String(localized: "Slightly moist", comment: "Chat quick reply chip: soil state; max 14 chars")), Grammar.pt(String(localized: "Wet", comment: "Chat quick reply chip: soil feels wet; max 14 chars"))]
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
