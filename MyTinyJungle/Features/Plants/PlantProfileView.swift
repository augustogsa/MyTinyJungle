import SwiftUI
import SwiftData

/// Fields still exist, prefilled from chat, editable by tap.
struct PlantProfileView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable var plant: Plant
    @State private var choosingSpecies = false
    @State private var species: Species?
    @State private var confirmArchive = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        PlantAvatar(data: plant.photo, size: 72)
                        VStack(alignment: .leading) {
                            TextField("Name", text: $plant.name).font(.system(.title3, design: .rounded, weight: .semibold))
                            Text(plant.species?.scientific ?? "").font(.caption).italic().foregroundStyle(Jungle.subtle)
                        }
                    }
                }
                Section("Identity") {
                    Button { choosingSpecies = true } label: { LabeledContent("Species", value: plant.species?.commonName ?? "Choose") }
                    Picker("Personality", selection: Binding(get: { plant.personality }, set: { plant.personality = $0 })) {
                        ForEach(Personality.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Home") {
                    TextField("Room or spot", text: $plant.location)
                    Toggle("Outdoors", isOn: $plant.isOutdoor)
                }
                Section("Pot & soil") {
                    LabeledContent("Pot diameter") {
                        TextField("cm", value: $plant.potDiameterCm, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Material", selection: Binding(get: { plant.potMaterial ?? .plastic }, set: { plant.potMaterial = $0 })) {
                        ForEach(PotMaterial.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Drainage holes", isOn: $plant.potHasDrainage)
                    TextField("Soil / substrate", text: $plant.substrate)
                    if let s = plant.species { Text("Ideal: \(s.mixLabel)").font(.footnote).foregroundStyle(Jungle.subtle) }
                }
                Section("Measurements") {
                    LabeledContent("Height") {
                        TextField("cm", value: $plant.heightCm, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    DatePicker("With you since", selection: $plant.acquiredAt, displayedComponents: .date)
                }
                if let s = plant.species {
                    Section("What \(plant.name) needs") {
                        Label(s.waterRule, systemImage: "drop")
                        Label(s.lightRule, systemImage: "sun.max")
                        Label("Humidity above \(Int(s.humidityMin))%", systemImage: "humidity")
                        Label("\(Int(s.tempMin))–\(Int(s.tempMax)) °C", systemImage: "thermometer.medium")
                        if s.toxicCats || s.toxicDogs { Label("Toxic to pets if chewed", systemImage: "pawprint").foregroundStyle(Jungle.warmText) }
                        Text(s.tip).font(.footnote).foregroundStyle(Jungle.subtle)
                    }
                    Section("Learned") {
                        LabeledContent("Dries in", value: "~\(Int(CareEngine.expectedDryDays(for: plant).rounded())) days")
                        Text(plant.learnedDryDays == nil ? "Learning from your soil checks." : "Learned from your soil checks.").font(.footnote).foregroundStyle(Jungle.subtle)
                    }
                }
                Section("Timeline") {
                    let events = plant.sortedEvents.filter { $0.note != "safety-ack" }
                    if events.isEmpty { Text("Nothing yet").foregroundStyle(Jungle.subtle) }
                    ForEach(events.prefix(50)) { e in
                        HStack(alignment: .top) {
                            Icon3DView(Icon3D.care(e.kind), size: 26).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(e))
                                Text(e.date, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(Jungle.subtle)
                            }
                            Spacer()
                            if let d = e.photo, let img = UIImage(data: d) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { ctx.delete(events[i]) }
                        try? ctx.save()
                    }
                }
                Section {
                    Button("Archive \(plant.name)", role: .destructive) { confirmArchive = true }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { try? ctx.save(); dismiss() } } }
            .sheet(isPresented: $choosingSpecies) { SpeciesPicker(selection: $species) }
            .onChange(of: species) { _, s in if let s { plant.speciesID = s.id; plant.learnedDryDays = nil } }
            .confirmationDialog("Archive \(plant.name)?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("It passed away", role: .destructive) { archive("passed") }
                Button("Gave it away") { archive("given") }
                Button("Other") { archive("other") }
            } message: { Text("Its history and photos are kept.") }
        }
    }

    private func title(_ e: CareEvent) -> String {
        var t = e.kind.label
        if let s = e.soil { t += ": \(s.label.lowercased())" }
        if let v = e.value { t += " · \(Int(v)) cm" }
        if !e.note.isEmpty, e.kind != .photo || e.note != "First photo" { t += " · \(e.note)" }
        return t
    }

    private func archive(_ reason: String) {
        plant.isArchived = true
        plant.archivedReason = reason
        try? ctx.save()
        dismiss()
    }
}
