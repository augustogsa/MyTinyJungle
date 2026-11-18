import SwiftUI
import SwiftData
import PhotosUI

struct PlantsView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @State private var adding = false
    @State private var paywall = false
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if plants.isEmpty {
                    EmptyJungle().padding(16)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(plants) { p in
                        NavigationLink(value: p.id) { PlantTile(plant: p) }.buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Jungle.cream)
            .navigationTitle("Plants")
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
}

struct PlantTile: View {
    let plant: Plant
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let d = plant.photo, let img = UIImage(data: d) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack { Jungle.mint; Image(systemName: "leaf").font(.largeTitle).foregroundStyle(Jungle.leaf) }
                    }
                }
                .frame(height: 150).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                moodBadge.padding(8)
            }
            Text(plant.name).font(.headline).foregroundStyle(Jungle.text).lineLimit(1)
            Text(plant.species?.commonName ?? "Unknown species").font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
        }
        .padding(8)
        .jungleCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var moodBadge: some View {
        switch CareEngine.mood(for: plant) {
        case .needsYou: Image(systemName: "drop.fill").padding(6).background(.thinMaterial, in: Circle()).foregroundStyle(Jungle.terracotta).accessibilityLabel("Needs you")
        case .fine: Image(systemName: "hand.point.down.fill").padding(6).background(.thinMaterial, in: Circle()).foregroundStyle(Jungle.leaf).accessibilityLabel("Has a request")
        case .thriving: EmptyView()
        }
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
