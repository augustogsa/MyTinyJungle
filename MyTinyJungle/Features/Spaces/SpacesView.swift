import SwiftUI
import SwiftData

/// My Spaces: rooms, windows, balconies with conditions and how every plant fits.
struct SpacesView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @State private var adding = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if spaces.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add your rooms").font(.headline).foregroundStyle(Jungle.text)
                        Text("Tell me about each room's light and I'll tell you which plants feel best where.").foregroundStyle(Jungle.subtle)
                        Button("Add a space", systemImage: "plus") { adding = true }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
                }
                ForEach(spaces) { space in
                    NavigationLink { SpaceDetailView(space: space) } label: { SpaceCard(space: space, plants: plantsIn(space)) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .jungleBackdrop()
        .navigationTitle("My Spaces")
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add space") }
        .sheet(isPresented: $adding) { SpaceEditor(space: nil) }
        .onAppear(perform: syncFromPlants)
    }

    private func plantsIn(_ s: Space) -> [Plant] { plants.filter { $0.location.folded == s.name.folded } }

    /// Rooms mentioned in chat become spaces automatically.
    private func syncFromPlants() {
        let known = Set(spaces.map { $0.name.folded })
        var added = Set<String>()
        for p in plants where !p.location.isEmpty && !known.contains(p.location.folded) && !added.contains(p.location.folded) {
            let sp = Space(name: p.location.capitalized, light: p.species?.light ?? .medium, outdoor: p.isOutdoor)
            ctx.insert(sp)
            added.insert(p.location.folded)
        }
        if !added.isEmpty { try? ctx.save() }
    }
}

struct SpaceCard: View {
    let space: Space
    let plants: [Plant]
    var body: some View {
        let fits = plants.compactMap { p in p.species.map { PlacementEngine.fit($0, in: space).fit } }
        let good = fits.filter { $0 >= .good }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: space.isOutdoor ? "sun.horizon" : "house").foregroundStyle(Jungle.leaf)
                Text(space.name).font(.headline).foregroundStyle(Jungle.text)
                Spacer()
                if !fits.isEmpty {
                    Text(good == fits.count ? "Optimal" : "\(good)/\(fits.count) happy")
                        .font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
                        .background((good == fits.count ? Jungle.leaf : Jungle.sun).opacity(0.25), in: Capsule())
                }
            }
            HStack(spacing: 14) {
                Label(PlacementEngine.lightLabel(space.light), systemImage: PlacementEngine.lightSymbol(space.light))
                if let t = space.temperature { Label("\(Int(t)) °C", systemImage: "thermometer.medium") }
                if let h = space.humidity { Label("\(Int(h))%", systemImage: "humidity") }
            }
            .font(.caption).foregroundStyle(Jungle.subtle)
            HStack(spacing: -10) {
                ForEach(plants.prefix(6)) { PlantAvatar(data: $0.photo, size: 34).overlay(Circle().stroke(Jungle.mist, lineWidth: 2)) }
                if plants.isEmpty { Text("No plants here yet").font(.caption).foregroundStyle(Jungle.subtle) }
            }
        }
        .padding(14).jungleCard()
    }
}

struct SpaceDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var allPlants: [Plant]
    @Bindable var space: Space
    @State private var editing = false

    var body: some View {
        let here = allPlants.filter { $0.location.folded == space.name.folded }
        let candidates = allPlants.filter { $0.location.folded != space.name.folded }
            .compactMap { p -> (Plant, PlacementEngine.Fit)? in p.species.map { (p, PlacementEngine.fit($0, in: space).fit) } }
            .filter { $0.1 >= .good }
        List {
            Section("Conditions") {
                LabeledContent("Light", value: PlacementEngine.lightLabel(space.light))
                if !space.windowFacing.isEmpty { LabeledContent("Window faces", value: space.windowFacing) }
                LabeledContent("Temperature", value: space.temperature.map { "\(Int($0)) °C" } ?? "Not set")
                LabeledContent("Humidity", value: space.humidity.map { "\(Int($0))%" } ?? "Not set")
                LabeledContent("Outdoors", value: space.isOutdoor ? "Yes" : "No")
            }
            Section("Plants here") {
                if here.isEmpty { Text("Nobody lives here yet.").foregroundStyle(Jungle.subtle) }
                ForEach(here) { p in
                    if let s = p.species {
                        let f = PlacementEngine.fit(s, in: space)
                        NavigationLink { PlantHomeView(plant: p) } label: {
                            HStack(spacing: 12) {
                                PlantAvatar(data: p.photo, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundStyle(Jungle.text)
                                    Text(f.reasons.joined(separator: " · ")).font(.caption).foregroundStyle(Jungle.subtle)
                                }
                                Spacer()
                                Label(f.fit.label, systemImage: f.fit.symbol).labelStyle(.iconOnly).foregroundStyle(f.fit >= .good ? Jungle.accentText : Jungle.warmText)
                            }
                        }
                    }
                }
            }
            if !candidates.isEmpty {
                Section("Would also love it here") {
                    ForEach(candidates, id: \.0.id) { p, fit in
                        HStack {
                            PlantAvatar(data: p.photo, size: 32)
                            Text(p.name)
                            Spacer()
                            Button("Move here") {
                                JungleBrain.apply(.init(kind: .move, plantIDs: [p.id], date: Date(), detail: space.name), to: p, in: ctx, now: Date(), source: "space")
                                try? ctx.save()
                            }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                        }
                    }
                }
            }
            Section("Insight") { Text(insight(here)).font(.subheadline) }
        }
        .navigationTitle(space.name)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { SpaceEditor(space: space) }
    }

    private func insight(_ here: [Plant]) -> String {
        let s = here.compactMap(\.species)
        guard !s.isEmpty else { return "Set the light right and I'll suggest plants for this spot." }
        let humid = s.filter { $0.humidityMin >= 55 }
        let poor = here.filter { $0.species.map { PlacementEngine.fit($0, in: space).fit < .good } ?? false }
        if !poor.isEmpty { return "\(poor.map(\.name).joined(separator: ", ")) would be happier elsewhere. Tap them to see their best place." }
        if !humid.isEmpty && (space.humidity ?? 45) < 55 { return "Conditions are great for \(s.count - humid.count) of \(s.count) plants. Consider a humidifier for the humidity lovers." }
        return "Conditions suit all \(s.count) plant\(s.count == 1 ? "" : "s") here. 🌿"
    }
}

struct SpaceEditor: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    var space: Space?
    @State private var name = ""
    @State private var light: Species.Light = .medium
    @State private var outdoor = false
    @State private var facing = ""
    @State private var temp: Double?
    @State private var humidity: Double?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Living room)", text: $name)
                Section {
                    Picker("Light", selection: $light) {
                        ForEach([Species.Light.low, .medium, .bright, .direct], id: \.self) { Label(PlacementEngine.lightLabel($0), systemImage: PlacementEngine.lightSymbol($0)).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                } header: { Text("How bright is it?") } footer: { Text("Bright = you could read comfortably all day without lamps. Direct = sun patches on the floor.") }
                Section {
                    Picker("Window faces", selection: $facing) {
                        Text("Not sure").tag("")
                        ForEach(["North", "East", "South", "West"], id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Outdoors", isOn: $outdoor)
                    LabeledContent("Temperature °C") { TextField("optional", value: $temp, format: .number).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                    LabeledContent("Humidity %") { TextField("optional", value: $humidity, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
            }
            .navigationTitle(space == nil ? "New space" : "Edit space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                if let space { name = space.name; light = space.light; outdoor = space.isOutdoor; facing = space.windowFacing; temp = space.temperature; humidity = space.humidity }
            }
        }
    }

    private func save() {
        let s = space ?? Space(name: name)
        if space == nil { ctx.insert(s) }
        s.name = name.trimmingCharacters(in: .whitespaces)
        s.light = light; s.isOutdoor = outdoor; s.windowFacing = facing; s.temperature = temp; s.humidity = humidity
        try? ctx.save()
        dismiss()
    }
}

/// Best place for a plant: every space ranked, with a what-if compare against where it lives now.
struct BestPlaceView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Space.createdAt) private var spaces: [Space]
    @State private var adding = false
    let plant: Plant

    var body: some View {
        List {
            if let s = plant.species {
                let ranked = spaces.map { ($0, PlacementEngine.fit(s, in: $0)) }.sorted { $0.1.fit > $1.1.fit }
                let current = spaces.first { $0.name.folded == plant.location.folded }
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(PlacementEngine.lightLabel(s.light), systemImage: PlacementEngine.lightSymbol(s.light)).font(.headline)
                        Text("\(Int(s.tempMin))–\(Int(s.tempMax)) °C · humidity \(Int(s.humidityMin))%+").font(.subheadline).foregroundStyle(Jungle.subtle)
                        Text(s.lightRule).font(.subheadline)
                    }
                } header: { Text("What \(plant.name) needs") }
                if ranked.isEmpty {
                    Section { Button("Add your rooms to compare", systemImage: "plus") { adding = true } }
                } else {
                    Section("Your spaces") {
                        ForEach(ranked, id: \.0.id) { space, f in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: f.fit.symbol).foregroundStyle(f.fit >= .good ? Jungle.leaf : Jungle.terracotta)
                                    Text(space.name).font(.headline)
                                    if space.id == current?.id { Text("Now").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Jungle.sun.opacity(0.4), in: Capsule()) }
                                    Spacer()
                                    Text(f.fit.label).font(.subheadline).foregroundStyle(Jungle.subtle)
                                }
                                Text(f.reasons.joined(separator: " · ")).font(.caption).foregroundStyle(Jungle.subtle)
                                if let current, current.id != space.id {
                                    Text(compare(s, from: current, to: space)).font(.caption).foregroundStyle(Jungle.text)
                                    Button("Move \(plant.name) here") {
                                        JungleBrain.apply(.init(kind: .move, plantIDs: [plant.id], date: Date(), detail: space.name), to: plant, in: ctx, now: Date(), source: "space")
                                        try? ctx.save(); dismiss()
                                    }
                                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                                } else if current == nil {
                                    Button("\(plant.name) lives here") {
                                        plant.location = space.name; try? ctx.save(); dismiss()
                                    }
                                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                Text("Set \(plant.name)'s species first.")
            }
        }
        .navigationTitle("Best place for \(plant.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $adding) { SpaceEditor(space: nil) }
    }

    /// What-if: predicted change when moving.
    private func compare(_ s: Species, from a: Space, to b: Space) -> String {
        let dl = PlacementEngine.lightIndex(b.light) - PlacementEngine.lightIndex(a.light)
        var parts: [String] = []
        if dl > 0 { parts.append("More light, faster growth. Water needs go up slightly") }
        if dl < 0 { parts.append("Less light, slower growth. Water a little less") }
        if b.isOutdoor != a.isOutdoor { parts.append(b.isOutdoor ? "Outdoors: dries faster, watch for pests" : "Indoors: dries slower") }
        if parts.isEmpty { parts.append("Similar conditions") }
        return "If moved: " + parts.joined(separator: "; ") + ". Expect 2–3 weeks to adjust."
    }
}
