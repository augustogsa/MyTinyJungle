import SwiftUI
import SwiftData

/// Where you grow: place, climate, home conditions and rooms. Used by Settings and onboarding.
struct ClimateForm: View {
    @Bindable private var climate = Climate.shared
    @State private var city = ""
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JungleGroup(title: "Where you live", footer: "Only your rough area (about 10 km) is used, to read your local climate and weather. It never leaves for anything else.") {
                Button { Task { await climate.useMyLocation() } } label: {
                    JungleRow(icon: .globe, title: "Use my location", subtitle: climate.profile.map { "\($0.place)\($0.country.isEmpty ? "" : ", \($0.country)")" } ?? "Rough area only", chevron: true)
                }.buttonStyle(.plain)
                JungleDivider()
                JungleRow(icon: .travel, title: "Or type a city") {
                    TextField("Lisbon, São Paulo…", text: $city).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        .submitLabel(.search)
                        .onSubmit { let c = city; Task { await climate.setPlace(named: c) } }
                }
                if climate.busy {
                    JungleDivider()
                    HStack { ProgressView(); Text("Reading your climate…").foregroundStyle(Jungle.subtle) }.padding(14)
                } else if let e = climate.lastError {
                    JungleDivider()
                    Text(e).font(.footnote).foregroundStyle(Jungle.terracotta).padding(14)
                }
            }
            if climate.profile != nil, !compact {
                JungleGroup(title: "Your climate") {
                    JungleRow(icon: .weather, title: climate.biome, subtitle: climate.koppen.map { "Köppen \($0)" })
                    if let z = climate.hardinessZone {
                        JungleDivider()
                        JungleRow(icon: .frost, title: "Hardiness zone \(z)", subtitle: climate.profile?.coldestNight.map { "Coldest nights around \(Climate.temp($0))" })
                    }
                    JungleDivider()
                    JungleRow(icon: .calendar, title: climate.isSouth ? "Southern hemisphere" : "Northern hemisphere",
                              subtitle: climate.isTropical ? "Seasons follow the rains" : "Seasons set from your local temperatures")
                }
            }
            JungleGroup(title: "Inside your home", footer: "This tunes how fast pots dry out.") {
                JungleRow(icon: .hot, title: "Heating in winter") { Toggle("", isOn: $climate.heating).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .cold, title: "Air conditioning in summer") { Toggle("", isOn: $climate.aircon).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .humidity, title: "The air feels") {
                    Picker("", selection: $climate.homeAir) { ForEach(Climate.HomeAir.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden().tint(Jungle.subtle)
                }
                JungleDivider()
                JungleRow(icon: .windCloud, title: "Draughty windows or doors") { Toggle("", isOn: $climate.drafts).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .sunflower, title: "I grow plants outside too", subtitle: "Balcony, terrace or garden") { Toggle("", isOn: $climate.growsOutside).labelsHidden() }
            }
        }
    }
}

/// Light per room, so care can match each spot.
struct RoomLightForm: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Space.name) private var spaces: [Space]
    private let suggestions = ["Living room", "Bedroom", "Kitchen", "Bathroom", "Office"]

    var body: some View {
        JungleGroup(title: "Light in each room", footer: "Bright means near a sunny window. You can change these any time in Spaces.") {
            ForEach(Array(rooms.enumerated()), id: \.element) { i, name in
                if i > 0 { JungleDivider() }
                JungleRow(icon: .sunny, title: name) {
                    Picker("", selection: binding(name)) {
                        Text("Low").tag(Species.Light.low); Text("Medium").tag(Species.Light.medium)
                        Text("Bright").tag(Species.Light.bright); Text("Sunny").tag(Species.Light.direct)
                    }.labelsHidden().tint(Jungle.subtle)
                }
            }
        }
    }
    private var rooms: [String] { (spaces.map(\.name) + suggestions).uniqued().prefix(8).map { $0 } }
    private func binding(_ name: String) -> Binding<Species.Light> {
        Binding(get: { spaces.first { $0.name == name }?.light ?? .medium }, set: { v in
            if let s = spaces.first(where: { $0.name == name }) { s.light = v } else { ctx.insert(Space(name: name, light: v)) }
            try? ctx.save()
            JungleRooms.sync((try? ctx.fetch(FetchDescriptor<Space>())) ?? [])
        })
    }
}

struct ClimateSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ClimateForm()
                RoomLightForm()
            }
            .padding(16)
        }
        .jungleBackdrop()
        .navigationTitle("Where you grow")
        .navigationBarTitleDisplayMode(.inline)
    }
}
