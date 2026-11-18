import SwiftUI
import SwiftData
import PhotosUI

/// My Collection: filter, search and a health summary over photo tiles.
struct PlantsView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @State private var adding = false
    @State private var paywall = false
    @State private var query = ""
    enum Filter: String, CaseIterable { case all = "All", needs = "Needs you", indoors = "Indoors", outdoors = "Outdoors" }
    @State private var filter: Filter = .all
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var shown: [Plant] {
        plants.filter { p in
            let f: Bool = switch filter {
            case .all: true
            case .needs: CareEngine.mood(for: p) == .needsYou
            case .indoors: !p.isOutdoor
            case .outdoors: p.isOutdoor
            }
            return f && (query.isEmpty || p.name.localizedCaseInsensitiveContains(query) || (p.species?.commonName.localizedCaseInsensitiveContains(query) ?? false))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if plants.isEmpty {
                        EmptyJungle { adding = true }
                    } else {
                        summary
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Filter.allCases, id: \.self) { f in
                                    Button { withAnimation(.snappy) { filter = f } } label: {
                                        Text(f.rawValue).font(.subheadline.weight(.medium))
                                            .foregroundStyle(filter == f ? Color.white : Jungle.text)
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(filter == f ? Jungle.forest : Jungle.surface, in: Capsule())
                                            .overlay(Capsule().strokeBorder(filter == f ? .clear : Jungle.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(filter == f ? .isSelected : [])
                                }
                            }
                        }
                        .scrollClipDisabled()
                        if shown.isEmpty {
                            Text("No plants here.").foregroundStyle(Jungle.subtle).frame(maxWidth: .infinity).padding(.top, 30)
                        }
                        // Ads sit between grid rows only: after row 4, then every 8 rows (free users).
                        let perRow = columns.count
                        let chunks = AdSlots.chunks(shown.count, perRow: perRow)
                        ForEach(chunks.indices, id: \.self) { i in
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(shown[chunks[i]]) { p in
                                    NavigationLink(value: p.id) { PlantTile(plant: p) }.buttonStyle(.plain)
                                }
                            }
                            if i < chunks.count - 1 { NativeAdCard() }
                        }
                    }
                }
                .padding(16)
            }
            .jungleBackdrop()
            .navigationTitle("My Collection")
            .searchable(text: $query, prompt: "Search plants")
            .toolbar {
                Button { if Store.shared.canAddPlant(current: plants.count) { adding = true } else { paywall = true } } label: { Image(systemName: "plus") }.accessibilityLabel("Add plant")
            }
            .navigationDestination(for: UUID.self) { id in
                if let p = plants.first(where: { $0.id == id }) { PlantHomeView(plant: p) }
            }
            .sheet(isPresented: $adding) { AddPlantFlow() }
            .sheet(isPresented: $paywall) { PaywallView(reason: .morePlants) }
        }
    }

    /// Plain-language summary of the jungle: one sentence anyone understands, plus the next thing to do.
    private var summary: some View {
        let moods = plants.map { CareEngine.mood(for: $0) }
        let need = plants.filter { CareEngine.mood(for: $0) == .needsYou }
        let happy = moods.filter { $0 != .needsYou }.count
        let title = plants.isEmpty ? "Your jungle starts here"
            : need.isEmpty ? "All \(plants.count) plants are happy"
            : need.count == 1 ? "\(need[0].name) needs you" : "\(need.count) plants need you"
        let detail = plants.isEmpty ? "Add your first plant and I'll keep track of it."
            : need.isEmpty ? "\(happy) of \(plants.count) are doing well. Nothing to do right now."
            : "\(happy) of \(plants.count) are doing well. Tap \"Needs you\" to see what to do."
        return HStack(spacing: 14) {
            Icon3DView(need.isEmpty ? .shieldLeaf : .wilted, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(detail).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16).jungleCard()
        .accessibilityElement(children: .combine)
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) { Circle().fill(c).frame(width: 8, height: 8); Text(t).font(.caption).foregroundStyle(Jungle.subtle) }
    }
}

struct PlantTile: View {
    let plant: Plant
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Fixed box first, photo as overlay: a wide photo can never push the grid out of line.
                Color.clear.frame(height: 140).frame(maxWidth: .infinity)
                    .overlay {
                        if let d = plant.photo, let img = UIImage(data: d) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            ZStack { Jungle.mint; Icon3DView(plant.species.map(PlantsIcon.for) ?? .pottedPlant, size: 72) }
                        }
                    }
                    .clipped()
                StatusBadge(status: CareEngine.status(for: plant), compact: true).padding(8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).lineLimit(1)
                Text(plant.species?.commonName ?? "Unknown species").font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "drop").font(.caption2).foregroundStyle(Jungle.leaf)
                    Text(nextWater).font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
                }
                .padding(.top, 2)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        .jungleCard()
        .accessibilityElement(children: .combine)
    }

    private var nextWater: String {
        guard let last = plant.lastEvent(.water)?.date else { return "Check soil" }
        let due = last.addingTimeInterval(CareEngine.expectedDryDays(for: plant) * 86_400)
        let d = Int((due.timeIntervalSinceNow / 86_400).rounded())
        return d <= 0 ? "Check soil today" : d == 1 ? "Check in 1 day" : "Check in \(d) days"
    }
}

struct SpeciesPicker: View {
    @Binding var selection: Species?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(SpeciesLibrary.shared.search(query)) { s in
                Button {
                    selection = s
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.commonName).foregroundStyle(Jungle.text)
                        Text(s.scientific).font(.caption).italic().foregroundStyle(Jungle.subtle)
                    }
                }
            }
            .searchable(text: $query, prompt: "Monstera, pothos, cato…")
            .navigationTitle("Species")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

enum PlantsIcon {
    static func `for`(_ s: Species) -> Icon3D {
        switch s.family {
        case "Cactaceae": .cactus
        case "Crassulaceae", "Asphodelaceae": .succulent
        case "Orchidaceae": .flower
        case "Lamiaceae": .herbs
        case "Moraceae": .bonsai
        case "Asparagaceae": .snakePlant
        case "Arecaceae": .palm
        default: .pottedPlant
        }
    }
}
