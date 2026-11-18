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
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(shown) { p in
                                NavigationLink(value: p.id) { PlantTile(plant: p) }.buttonStyle(.plain)
                            }
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

    private var summary: some View {
        let moods = plants.map { CareEngine.mood(for: $0) }
        let t = moods.filter { $0 == .thriving }.count, f = moods.filter { $0 == .fine }.count, n = moods.filter { $0 == .needsYou }.count
        let score = (Double(t) + Double(f) * 0.7) / Double(max(1, plants.count))
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Jungle.mint, lineWidth: 8)
                Circle().trim(from: 0, to: score).stroke(Jungle.leaf, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(score * 100))%").font(.headline).foregroundStyle(Jungle.text)
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("Collection health").font(.headline).foregroundStyle(Jungle.text)
                HStack(spacing: 12) {
                    legend(Jungle.leaf, "\(t) thriving")
                    legend(Jungle.sun, "\(f) fine")
                    legend(Jungle.terracotta, "\(n) need you")
                }
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
        let mood = CareEngine.mood(for: plant)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let d = plant.photo, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack { Jungle.mint; Image(systemName: "leaf.fill").font(.system(size: 40)).foregroundStyle(Jungle.leaf) }
                    }
                }
                .frame(height: 140).frame(maxWidth: .infinity).clipped()
                StatusPill(text: mood == .needsYou ? "Needs you" : mood == .fine ? "Fine" : "Thriving",
                           symbol: mood == .needsYou ? "drop.fill" : "leaf.fill",
                           tint: mood == .needsYou ? Jungle.peach : Jungle.surface)
                    .background(Jungle.surface.opacity(0.85), in: Capsule())
                    .padding(8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.name).font(.headline).foregroundStyle(Jungle.text).lineLimit(1)
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
