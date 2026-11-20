import SwiftUI
import SwiftData
import PhotosUI

/// Plant Doctor: photo → leaf colour + soil + the plant's own history → likely causes and a plan.
struct HealthCheckView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    let plant: Plant
    /// Store screenshots: a finished AI doctor answer for the plant's own photo.
    var demo: AIDiagnosis? = nil

    @State private var photo: Data?
    @State private var read: PhotoRead?
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    @State private var working = false
    @State private var pest: Pest?
    /// A photo the Scan camera already took.
    private let initialPhoto: Data?
    /// Photos from a multi-photo scan: all go to the AI doctor, the leaf one feeds the on-device read.
    private let initialShots: [ScanShot]
    private let onMorePhoto: ((ShotKind) -> Void)?
    @State private var shots: [ScanShot] = []
    init(plant: Plant, initialPhoto: Data? = nil, initialShots: [ScanShot] = [], onMorePhoto: ((ShotKind) -> Void)? = nil, demo: AIDiagnosis? = nil) {
        self.plant = plant; self.demo = demo; self.initialPhoto = initialPhoto; self.initialShots = initialShots; self.onMorePhoto = onMorePhoto
    }

    var body: some View { tracked.screen("health_check") }
    @ViewBuilder private var tracked: some View {
        DuoCompanion(mood: .scan, title: "Health check", detail: "Snap a photo and learn what it needs.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    viewfinder
                    if working { ErtyLoading(text: Grammar.pt(String(localized: "Looking closely…"))) }
                    if let demo, let photo { AIDoctorCard(photo: photo, plant: plant, preset: demo).padding(16).jungleCard() } else {
                    if let read { result(read) }
                    if read != nil, let photo, BrainTuning.flag("serverDiagnose") { AIDoctorCard(photo: photo, plant: plant, shots: shots, onMorePhoto: onMorePhoto) }
                    pestSection
                    }
                    if let pest { PestPlanView(pest: pest, plant: plant, neighbours: neighbours) { dismiss() } }
                }
                .padding(16)
            }
            .jungleBackdrop()
            .navigationTitle("Health check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if read != nil { ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
            }
            .fullScreenCover(isPresented: $camera) { CameraPicker { d in camera = false; if let d { analyze(d) } }.ignoresSafeArea() }
            .task {
                guard photo == nil else { return }
                if let lead = initialShots.first(where: { $0.kind == .leaf }) ?? initialShots.first { shots = initialShots; analyze(lead.data, keepShots: true) }
                else if let initialPhoto { analyze(initialPhoto) }
            }
            .onAppear { if demo != nil, photo == nil, let d = plant.photo { photo = ImageShrinker.jpeg(d) } }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task { if let d = try? await item.loadTransferable(type: Data.self) { analyze(d) }; pick = nil }
            }
        }
    }

    private var neighbours: [Plant] {
        plants.filter { $0.id != plant.id && !plant.location.isEmpty && $0.location.folded == plant.location.folded }
    }

    private var viewfinder: some View {
        VStack(spacing: 12) {
        ZStack {
            Group {
                if let d = photo ?? plant.photo, let img = Thumbs.image(d, side: 440) { Image(uiImage: img).resizable().scaledToFill() }
                else { Jungle.mint }
            }
            .frame(height: 260).frame(maxWidth: .infinity).clipped()
            Viewfinder().stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round)).padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        if shots.count > 1 { ScanShotStrip(shots: shots) }
        if photo == nil {
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { camera = true } label: { Label("Photo", systemImage: "camera.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).junglePrimary()
                }
                PhotosPicker(selection: $pick, matching: .images) { Label("Library", systemImage: "photo").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                if plant.photo != nil {
                    Button { if let d = plant.photo { analyze(d) } } label: { Label("Use last", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.85)
            .controlSize(.large).font(.subheadline.weight(.semibold)).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.forest)
            .frame(maxWidth: .infinity)
        }
        }
    }

    private func result(_ r: PhotoRead) -> some View {
        let (title, symbol, color): (String, String, Color) = switch r.health {
        case .lush, .good: (Grammar.pt(String(localized: "Healthy", comment: "Health check verdict title; upbeat; max 18 chars")), "checkmark.circle.fill", Jungle.leaf)
        case .someStress: (Grammar.pt(String(localized: "Some stress", comment: "Health check verdict title; gentle; max 18 chars")), "exclamationmark.circle.fill", Jungle.sun)
        case .stressed: (Grammar.pt(String(localized: "Needs attention", comment: "Health check verdict title; caring, not alarming; max 20 chars")), "exclamationmark.triangle.fill", Jungle.terracotta)
        case .unknown: (Grammar.pt(String(localized: "Not sure yet", comment: "Health check verdict when photo is unclear; max 18 chars")), "questionmark.circle.fill", Jungle.sage)
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(.largeTitle, design: .rounded)).foregroundStyle(color)
                VStack(alignment: .leading) {
                    Text(title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    Text(r.healthSummary).font(.subheadline).foregroundStyle(Jungle.subtle)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Analysis").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                LeafBar(read: r)
                analysisRow(Grammar.pt(String(localized: "Leaf colour", comment: "Health analysis row label; max 16 chars")), Grammar.pt(String(localized: "\(percent(r.greenShare, of: r)) green", comment: "Health analysis value: share of green leaf area, e.g. 82% green; max 14 chars")), r.health == .lush || r.health == .good)
                analysisRow(Grammar.pt(String(localized: "Yellowing", comment: "Health analysis row label: yellow leaves; max 16 chars")), r.yellowShare < 0.02 ? Grammar.pt(String(localized: "None seen", comment: "Health analysis value when no yellow/brown seen; max 14 chars")) : percent(r.yellowShare, of: r), r.yellowShare < 0.03)
                analysisRow(Grammar.pt(String(localized: "Browning", comment: "Health analysis row label: brown leaves/tips; max 16 chars")), r.brownShare < 0.02 ? Grammar.pt(String(localized: "None seen", comment: "Health analysis value when no yellow/brown seen; max 14 chars")) : percent(r.brownShare, of: r), r.brownShare < 0.03)
                if plant.growingMedium.usesSoil { analysisRow(Grammar.pt(String(localized: "Soil", comment: "Health analysis row label; max 16 chars")), r.soilMoisture.map { Grammar.pt(String(localized: "Looks \($0.label.lowercased())", comment: "Health analysis soil value; arg is soil state like dry/moist/wet (lowercase); max 18 chars")) } ?? Grammar.pt(String(localized: "Not visible", comment: "Health analysis soil value when soil not in photo; max 14 chars")), r.soilMoisture != .wet) } else { analysisRow(Grammar.pt(String(localized: "Roots in", comment: "Add plant: growing medium label; max 16 chars")), plant.growingMedium.label, true, neutral: true) }
                analysisRow(Grammar.pt(String(localized: "Pests", comment: "Health analysis row label; max 16 chars")), Grammar.pt(String(localized: "Can't be ruled out from a photo. Check under the leaves", comment: "Health analysis pests value; friendly advice; max 70 chars")), true, neutral: true)
                Text(r.health == .unknown ? Grammar.pt(String(localized: "Confidence: low. Based on photo colours and \(plant.name)'s history.", comment: "Health check footnote; arg is plant name")) : Grammar.pt(String(localized: "Confidence: medium. Based on photo colours and \(plant.name)'s history.", comment: "Health check footnote; arg is plant name"))).font(.caption).foregroundStyle(Jungle.subtle)
            }
            .padding(14).jungleCard()

            let causes = likelyCauses(r)
            if !causes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I'd do").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    ForEach(causes, id: \.self) { c in Label(c, systemImage: "arrow.right.circle").font(.subheadline).foregroundStyle(Jungle.text) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            }
        }
    }

    private var pestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pest guard", systemImage: "ant").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Text("Seeing any of these? Tap it.").font(.subheadline).foregroundStyle(Jungle.subtle)
            FlowChips(items: Pest.allCases.map(\.sign), selected: pest?.sign) { sign in
                withAnimation(.snappy) { pest = Pest.allCases.first { $0.sign == sign } }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
    }

    private func analysisRow(_ t: String, _ v: String, _ ok: Bool, neutral: Bool = false) -> some View {
        HStack {
            Image(systemName: neutral ? "info.circle" : ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(neutral ? Jungle.subtle : ok ? Jungle.leaf : Jungle.terracotta)
            Text(t).foregroundStyle(Jungle.text)
            Spacer()
            Text(v).font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.trailing)
        }
    }

    private func percent(_ v: Double, of r: PhotoRead) -> String {
        let total = max(r.greenShare + r.yellowShare + r.brownShare, 0.0001)
        return (v / total).formatted(.percent.precision(.fractionLength(0)))
    }

    private func likelyCauses(_ r: PhotoRead) -> [String] {
        guard plant.species != nil else { return [Grammar.pt(String(localized: "Set the species so I can reason about causes.", comment: "Health check: plant voice asks user to set species; max 60 chars"))] }
        return Diagnosis.findings(r, species: plant.species, plant: plant).map { Grammar.pt(String(localized: "\($0.title): \($0.detail)", comment: "Diagnosis finding: title, colon, detail")) }
    }

    private func analyze(_ raw: Data, keepShots: Bool = false) {
        if !keepShots { shots = [] }
        let data = ImageShrinker.jpeg(raw)
        photo = data
        working = true
        Task {
            // The doctor's upload is prepared while the on-device read runs, so asking it starts sending at once.
            async let upload: Void = Task.detached(priority: .utility) { _ = BrainPhoto.make(data) }.value
            if let img = UIImage(data: data) { read = await PlantVision.read(img) }
            working = false
            _ = await upload
        }
    }

    private func save() {
        guard let r = read else { return }
        let e = CareEvent(kind: .health, note: r.healthSummary, source: "doctor")
        e.photo = photo
        if plant.growingMedium.usesSoil { e.soil = r.soilMoisture }
        e.value = r.greenShare / max(r.greenShare + r.yellowShare + r.brownShare, 0.0001) * 100
        e.plant = plant
        ctx.insert(e)
        let m = ChatMessage(text: Grammar.pt(String(localized: "Health check saved: \(r.healthSummary)", comment: "Chat message after saving a health check; arg is summary sentence")), fromUser: false)
        m.speakerID = plant.id
        ctx.insert(m)
        ctx.insert(CareTask(title: Grammar.pt(String(localized: "Health check \(plant.name)", comment: "Care task title; arg is plant name; max 40 chars")), kind: .health, plantID: plant.id, due: Date().addingTimeInterval((r.health == .stressed || r.health == .someStress ? 7 : 30) * 86_400)))
        try? ctx.save()
        dismiss()
    }
}

enum Pest: String, CaseIterable, Identifiable {
    case spiderMites, mealybugs, fungusGnats, thrips, scale, aphids
    var id: String { rawValue }
    var sign: String {
        switch self {
        case .spiderMites: Grammar.pt(String(localized: "Fine webbing", comment: "Pest sign chip: spider mites; max 18 chars"))
        case .mealybugs: Grammar.pt(String(localized: "White fluff", comment: "Pest sign chip: mealybugs; max 18 chars"))
        case .fungusGnats: Grammar.pt(String(localized: "Tiny flies", comment: "Pest sign chip: fungus gnats; max 18 chars"))
        case .thrips: Grammar.pt(String(localized: "Silver streaks", comment: "Pest sign chip: thrips; max 18 chars"))
        case .scale: Grammar.pt(String(localized: "Brown bumps", comment: "Pest sign chip: scale insects; max 18 chars"))
        case .aphids: Grammar.pt(String(localized: "Green clusters", comment: "Pest sign chip: aphids; max 18 chars"))
        }
    }
    var name: String {
        switch self {
        case .spiderMites: Grammar.pt(String(localized: "Spider mites", comment: "Pest name"))
        case .mealybugs: Grammar.pt(String(localized: "Mealybugs", comment: "Pest name"))
        case .fungusGnats: Grammar.pt(String(localized: "Fungus gnats", comment: "Pest name"))
        case .thrips: Grammar.pt(String(localized: "Thrips", comment: "Pest name"))
        case .scale: Grammar.pt(String(localized: "Scale insects", comment: "Pest name"))
        case .aphids: Grammar.pt(String(localized: "Aphids", comment: "Pest name"))
        }
    }
    var steps: [String] {
        switch self {
        case .spiderMites: [Grammar.pt(String(localized: "Isolate it from other plants", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Rinse leaves top and bottom in the shower", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Wipe with mild soapy water every 3–4 days", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Raise humidity: mites love dry air", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Neem or insecticidal soap if it persists (follow the label)", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        case .mealybugs: [Grammar.pt(String(localized: "Isolate it", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Dab each cluster with cotton and rubbing alcohol", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Check leaf joints and under the pot rim", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Repeat weekly for 3–4 weeks", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        case .fungusGnats: [Grammar.pt(String(localized: "Let the top soil dry out well: larvae need wet soil", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Yellow sticky traps for the adults", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Water from the bottom for a few weeks", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Top-dress with sand or grit", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        case .thrips: [Grammar.pt(String(localized: "Isolate it", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Shower the leaves", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Blue sticky traps", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Insecticidal soap or spinosad, weekly (follow the label)", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        case .scale: [Grammar.pt(String(localized: "Isolate it", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Scrape bumps off gently with a soft brush or fingernail", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Wipe with alcohol on a cotton pad", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Repeat weekly", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        case .aphids: [Grammar.pt(String(localized: "Spray off with water", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Wipe with mild soapy water", comment: "Pest treatment step; imperative, short; max 70 chars")), Grammar.pt(String(localized: "Check new growth every few days", comment: "Pest treatment step; imperative, short; max 70 chars"))]
        }
    }
    var spreads: Bool { self != .fungusGnats }
}

struct PestPlanView: View {
    @Environment(\.modelContext) private var ctx
    let pest: Pest
    let plant: Plant
    let neighbours: [Plant]
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ant.fill").foregroundStyle(Jungle.terracotta)
                Text(Grammar.pt(String(localized: "Possibly \(pest.name)"))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            }
            Text("Based on what you saw. Confirm with a close look under the leaves.").font(.caption).foregroundStyle(Jungle.subtle)
            ForEach(Array(pest.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(Jungle.onForest).frame(width: 22, height: 22).background(Jungle.forest, in: Circle())
                    Text(step).font(.subheadline).foregroundStyle(Jungle.text)
                }
            }
            if pest.spreads && !neighbours.isEmpty {
                Label("Also inspect \(neighbours.map(\.name).formatted(.list(type: .and))). They share \(plant.location). Not infected, just exposed.", systemImage: "eye")
                    .font(.subheadline).foregroundStyle(Jungle.text)
            }
            Button {
                let e = CareEvent(kind: .treat, note: Grammar.pt(String(localized: "Started treatment: \(pest.name)", comment: "Timeline note; arg is pest name")), source: "doctor"); e.plant = plant; ctx.insert(e)
                for n in neighbours where pest.spreads {
                    ctx.insert(CareTask(title: Grammar.pt(String(localized: "Inspect \(n.name) for \(pest.name.lowercased())", comment: "Care task title; args plant name, pest name lowercase; max 45 chars")), kind: .health, plantID: n.id, due: Date().addingTimeInterval(86_400)))
                }
                let m = ChatMessage(text: Grammar.pt(String(localized: "I might have \(pest.name.lowercased()). Thanks for starting my treatment. I'll remind you to repeat it in about 6 days, three rounds in all.", comment: "Plant voice in chat, first person, grateful; arg pest name lowercase")), fromUser: false)
                m.speakerID = plant.id
                ctx.insert(m)
                try? ctx.save()
                onStart()
            } label: { Label("Start treatment plan", systemImage: "cross.case.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).junglePrimary().fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.large)
        }
        .padding(14).jungleCard()
    }
}

struct Viewfinder: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 34
        for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0), (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x, y: y + dy * l)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + dx * l, y: y))
        }
        return p
    }
}

/// Wrapping chips.
struct FlowChips: View {
    let items: [String]
    var selected: String?
    var onTap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button(item) { onTap(item) }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .jungleChip(selected: selected == item)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > b.maxX, x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
