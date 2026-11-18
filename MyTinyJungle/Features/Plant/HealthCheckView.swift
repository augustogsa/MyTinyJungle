import SwiftUI
import SwiftData
import PhotosUI

/// Plant Doctor: photo → leaf colour + soil + the plant's own history → likely causes and a plan.
struct HealthCheckView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    let plant: Plant

    @State private var photo: Data?
    @State private var read: PhotoRead?
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    @State private var working = false
    @State private var pest: Pest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    viewfinder
                    if working { HStack { ProgressView(); Text("Looking closely…").foregroundStyle(Jungle.subtle) } }
                    if let read { result(read) }
                    pestSection
                    if let pest { PestPlanView(pest: pest, plant: plant, neighbours: neighbours) { dismiss() } }
                }
                .padding(16)
            }
            .background(Jungle.cream)
            .navigationTitle("Health check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if read != nil { ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
            }
            .fullScreenCover(isPresented: $camera) { CameraPicker { d in camera = false; if let d { analyze(d) } }.ignoresSafeArea() }
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
        ZStack {
            Group {
                if let d = photo ?? plant.photo, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill() }
                else { Jungle.mint }
            }
            .frame(height: 260).frame(maxWidth: .infinity).clipped()
            Viewfinder().stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round)).padding(28)
            if photo == nil {
                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { camera = true } label: { Label("Photo", systemImage: "camera.fill") }.buttonStyle(.borderedProminent)
                    }
                    PhotosPicker(selection: $pick, matching: .images) { Label("Library", systemImage: "photo") }.buttonStyle(.bordered)
                    if plant.photo != nil {
                        Button { if let d = plant.photo { analyze(d) } } label: { Text("Use last") }.buttonStyle(.bordered)
                    }
                }
                .buttonBorderShape(.capsule).tint(.white).foregroundStyle(Jungle.forest)
                .padding(.top, 180)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
    }

    private func result(_ r: PhotoRead) -> some View {
        let (title, symbol, color): (String, String, Color) = switch r.health {
        case .lush, .good: ("Healthy", "checkmark.circle.fill", Jungle.leaf)
        case .someStress: ("Some stress", "exclamationmark.circle.fill", Jungle.sun)
        case .stressed: ("Needs attention", "exclamationmark.triangle.fill", Jungle.terracotta)
        case .unknown: ("Not sure yet", "questionmark.circle.fill", Jungle.sage)
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(color)
                VStack(alignment: .leading) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(Jungle.text)
                    Text(r.healthSummary).font(.subheadline).foregroundStyle(Jungle.subtle)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("Analysis").font(.headline).foregroundStyle(Jungle.text)
                LeafBar(read: r)
                analysisRow("Leaf colour", percent(r.greenShare, of: r) + " green", r.health == .lush || r.health == .good)
                analysisRow("Yellowing", r.yellowShare < 0.02 ? "None seen" : percent(r.yellowShare, of: r), r.yellowShare < 0.03)
                analysisRow("Browning", r.brownShare < 0.02 ? "None seen" : percent(r.brownShare, of: r), r.brownShare < 0.03)
                analysisRow("Soil", r.soilMoisture.map { "Looks \($0.label.lowercased())" } ?? "Not visible", r.soilMoisture != .wet)
                analysisRow("Pests", "Can't be ruled out from a photo. Check under the leaves", true, neutral: true)
                Text("Confidence: \(r.health == .unknown ? "low" : "medium"). Based on photo colours and \(plant.name)'s history.").font(.caption).foregroundStyle(Jungle.subtle)
            }
            .padding(14).jungleCard()

            let causes = likelyCauses(r)
            if !causes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I'd do").font(.headline).foregroundStyle(Jungle.text)
                    ForEach(causes, id: \.self) { c in Label(c, systemImage: "arrow.right.circle").font(.subheadline).foregroundStyle(Jungle.text) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            }
        }
    }

    private var pestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pest guard", systemImage: "ant").font(.headline).foregroundStyle(Jungle.text)
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
        return "\(Int((v / total * 100).rounded()))%"
    }

    private func likelyCauses(_ r: PhotoRead) -> [String] {
        guard let s = plant.species else { return ["Set the species so I can reason about causes."] }
        var out: [String] = []
        let expected = CareEngine.expectedDryDays(for: plant)
        let sinceWater = plant.lastEvent(.water).map { CareEngine.days(from: $0.date) }
        if r.yellowShare > 0.03 {
            if let w = sinceWater, w < expected * 0.6 || r.soilMoisture == .wet { out.append("Yellowing + recent water: likely too much water. Let the soil dry \(s.waterStyle == .moist ? "on top" : "deeper") before the next drink.") }
            else { out.append("Yellowing on old lower leaves is normal ageing. On new leaves, check light and feeding.") }
        }
        if r.brownShare > 0.03 {
            out.append(s.humidityMin >= 50 ? "Brown edges: likely dry air. Group plants or add a humidifier (\(Int(s.humidityMin))%+)." : "Brown patches: check for sunburn or long dry spells.")
        }
        if r.soilMoisture == .dry, (sinceWater ?? 99) > expected { out.append("Soil looks dry: water today.") }
        if r.health == .lush || r.health == .good { out.append("Keep the current routine. I'll check again in a month.") }
        return out
    }

    private func analyze(_ raw: Data) {
        let data = ImageShrinker.jpeg(raw)
        photo = data
        working = true
        Task {
            if let img = UIImage(data: data) { read = await PlantVision.read(img) }
            working = false
        }
    }

    private func save() {
        guard let r = read else { return }
        let e = CareEvent(kind: .health, note: r.healthSummary, source: "doctor")
        e.photo = photo
        e.soil = r.soilMoisture
        e.value = r.greenShare / max(r.greenShare + r.yellowShare + r.brownShare, 0.0001) * 100
        e.plant = plant
        ctx.insert(e)
        let m = ChatMessage(text: "Health check saved: \(r.healthSummary)", fromUser: false)
        m.speakerID = plant.id
        ctx.insert(m)
        ctx.insert(CareTask(title: "Health check \(plant.name)", kind: .health, plantID: plant.id, due: Date().addingTimeInterval((r.health == .stressed || r.health == .someStress ? 7 : 30) * 86_400)))
        try? ctx.save()
        dismiss()
    }
}

enum Pest: String, CaseIterable, Identifiable {
    case spiderMites, mealybugs, fungusGnats, thrips, scale, aphids
    var id: String { rawValue }
    var sign: String {
        switch self {
        case .spiderMites: "Fine webbing"
        case .mealybugs: "White fluff"
        case .fungusGnats: "Tiny flies"
        case .thrips: "Silver streaks"
        case .scale: "Brown bumps"
        case .aphids: "Green clusters"
        }
    }
    var name: String {
        switch self {
        case .spiderMites: "Spider mites"
        case .mealybugs: "Mealybugs"
        case .fungusGnats: "Fungus gnats"
        case .thrips: "Thrips"
        case .scale: "Scale insects"
        case .aphids: "Aphids"
        }
    }
    var steps: [String] {
        switch self {
        case .spiderMites: ["Isolate it from other plants", "Rinse leaves top and bottom in the shower", "Wipe with mild soapy water every 3–4 days", "Raise humidity: mites love dry air", "Neem or insecticidal soap if it persists (follow the label)"]
        case .mealybugs: ["Isolate it", "Dab each cluster with cotton and rubbing alcohol", "Check leaf joints and under the pot rim", "Repeat weekly for 3–4 weeks"]
        case .fungusGnats: ["Let the top soil dry out well: larvae need wet soil", "Yellow sticky traps for the adults", "Water from the bottom for a few weeks", "Top-dress with sand or grit"]
        case .thrips: ["Isolate it", "Shower the leaves", "Blue sticky traps", "Insecticidal soap or spinosad, weekly (follow the label)"]
        case .scale: ["Isolate it", "Scrape bumps off gently with a soft brush or fingernail", "Wipe with alcohol on a cotton pad", "Repeat weekly"]
        case .aphids: ["Spray off with water", "Wipe with mild soapy water", "Check new growth every few days"]
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
                Text("Possibly \(pest.name)").font(.headline).foregroundStyle(Jungle.text)
            }
            Text("Based on what you saw. Confirm with a close look under the leaves.").font(.caption).foregroundStyle(Jungle.subtle)
            ForEach(Array(pest.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(Jungle.leaf, in: Circle())
                    Text(step).font(.subheadline).foregroundStyle(Jungle.text)
                }
            }
            if pest.spreads && !neighbours.isEmpty {
                Label("Also inspect \(neighbours.map(\.name).joined(separator: ", ")). They share \(plant.location). Not infected, just exposed.", systemImage: "eye")
                    .font(.subheadline).foregroundStyle(Jungle.text)
            }
            Button {
                let e = CareEvent(kind: .treat, note: "Started treatment: \(pest.name)", source: "doctor"); e.plant = plant; ctx.insert(e)
                for d in [3.0, 7.0, 14.0] {
                    ctx.insert(CareTask(title: "Treat & recheck \(plant.name) (\(pest.name))", kind: .treat, plantID: plant.id, due: Date().addingTimeInterval(d * 86_400)))
                }
                for n in neighbours where pest.spreads {
                    ctx.insert(CareTask(title: "Inspect \(n.name) for \(pest.name.lowercased())", kind: .health, plantID: n.id, due: Date().addingTimeInterval(86_400)))
                }
                let m = ChatMessage(text: "I might have \(pest.name.lowercased()). Thanks for starting my treatment. Let's recheck in 3 days.", fromUser: false)
                m.speakerID = plant.id
                ctx.insert(m)
                try? ctx.save()
                onStart()
            } label: { Label("Start treatment plan", systemImage: "cross.case.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
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
                    .foregroundStyle(selected == item ? Color.white : Jungle.text)
                    .background(selected == item ? Jungle.terracotta : Jungle.cream, in: Capsule())
                    .overlay(Capsule().stroke(Jungle.border))
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
