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
                if let p = plants.first(where: { $0.id == id }) { PlantChatView(plant: p) }
            }
            .sheet(isPresented: $adding) { AddPlantView() }
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

struct AddPlantView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var species: Species?
    @State private var personality: Personality = .cheerful
    @State private var location = ""
    @State private var outdoor = false
    @State private var photo: Data?
    @State private var pick: PhotosPickerItem?
    @State private var choosingSpecies = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $pick, matching: .images) {
                            VStack(spacing: 6) {
                                PlantAvatar(data: photo, size: 110)
                                Text(photo == nil ? "Add a photo" : "Change photo").font(.footnote)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Who is this?") {
                    TextField("Name (e.g. Milo)", text: $name)
                    Button { choosingSpecies = true } label: {
                        LabeledContent("Species", value: species?.commonName ?? "Choose")
                    }
                }
                Section("Personality") {
                    Picker("Personality", selection: $personality) {
                        ForEach(Personality.allCases) { p in Text(p.label).tag(p) }
                    }
                    Text(personality.blurb).font(.footnote).foregroundStyle(Jungle.subtle)
                }
                Section("Where does it live?") {
                    TextField("Room or spot (e.g. Living room window)", text: $location)
                    Toggle("Outdoors", isOn: $outdoor)
                }
                Section {
                    Text("You can fill in pot, soil and everything else later, just by chatting with your plant.")
                        .font(.footnote).foregroundStyle(Jungle.subtle)
                }
            }
            .navigationTitle("New plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && species == nil) }
            }
            .sheet(isPresented: $choosingSpecies) { SpeciesPicker(selection: $species) }
            .onChange(of: pick) { _, item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self) { photo = ImageShrinker.jpeg(d) } }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let plant = Plant(name: trimmed.isEmpty ? (species?.en ?? "Plant") : trimmed, speciesID: species?.id, personality: personality, location: location)
        plant.isOutdoor = outdoor
        plant.photo = photo
        ctx.insert(plant)
        if let photo {
            let e = CareEvent(kind: .photo, note: "First photo", source: "form"); e.photo = photo; e.plant = plant; ctx.insert(e)
        }
        let intro = species.map { "Hi, I'm \(plant.name)! I'm a \($0.en). \($0.waterRule) When did you last water me?" }
            ?? "Hi, I'm \(plant.name)! What kind of plant am I? And when did you last water me?"
        ctx.insert(ChatMessage(text: intro, fromUser: false, plant: plant, suggestions: ["Today", "Yesterday", "Not sure"]))
        try? ctx.save()
        dismiss()
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
