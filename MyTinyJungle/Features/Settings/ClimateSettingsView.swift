import SwiftUI
import SwiftData

/// Where you grow: place, climate, home conditions and rooms. Used by Settings and onboarding.
struct ClimateForm: View {
    @Bindable private var climate = Climate.shared
    @State private var city = ""
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JungleGroup(title: Grammar.pt(String(localized: "Where you live", comment: "Climate settings section title")), footer: Grammar.pt(String(localized: "Only your rough area (about 10 km) is used, to read your local climate and weather. It never leaves for anything else.", comment: "Location privacy footer"))) {
                Button { Task { await climate.useMyLocation() } } label: {
                    JungleRow(icon: .pin, title: Grammar.pt(String(localized: "Use my location", comment: "Climate settings row")), subtitle: climate.profile.map { $0.country.isEmpty ? $0.place : Grammar.pt(String(localized: "\($0.place), \($0.country)", comment: "City, country")) } ?? Grammar.pt(String(localized: "Rough area only", comment: "Location row subtitle when not set")), chevron: true)
                }.buttonStyle(.plain)
                JungleDivider()
                JungleRow(icon: .globe, title: Grammar.pt(String(localized: "Or type a city", comment: "Climate settings row"))) {
                    TextField(Grammar.pt(String(localized: "São Paulo, Lisbon…", comment: "City field placeholder; use local example cities")), text: $city).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        .submitLabel(.search)
                        .onSubmit { let c = city; Task { await climate.setPlace(named: c) } }
                }
                if climate.busy {
                    JungleDivider()
                    ErtyLoading(text: Grammar.pt(String(localized: "Reading your climate…", comment: "Climate lookup in progress")), mood: .rain, size: 72).padding(14)
                } else if let e = climate.lastError {
                    JungleDivider()
                    Text(e).font(.footnote).foregroundStyle(Jungle.terracotta).padding(14)
                }
            }
            if climate.profile != nil, !compact {
                JungleGroup(title: Grammar.pt(String(localized: "Your climate", comment: "Climate settings section title"))) {
                    JungleRow(icon: climate.biomeIcon, title: climate.biome, subtitle: climate.koppen.map { Grammar.pt(String(localized: "Köppen \($0)", comment: "Köppen climate code, e.g. Köppen Cfa")) })
                    if let z = climate.hardinessZone {
                        JungleDivider()
                        JungleRow(icon: .frost, title: Grammar.pt(String(localized: "Hardiness zone \(z)", comment: "USDA hardiness zone")), subtitle: climate.profile?.coldestNight.map { Grammar.pt(String(localized: "Coldest nights around \(Climate.temp($0))", comment: "Arg is a temperature")) })
                    }
                    JungleDivider()
                    JungleRow(icon: .heartPin, title: climate.isSouth ? Grammar.pt(String(localized: "Southern hemisphere", comment: "Climate row")) : Grammar.pt(String(localized: "Northern hemisphere", comment: "Climate row")),
                              subtitle: climate.isTropical ? Grammar.pt(String(localized: "Seasons follow the rains", comment: "Climate row subtitle, tropical")) : Grammar.pt(String(localized: "Seasons set from your local temperatures", comment: "Climate row subtitle")))
                }
            }
            JungleGroup(title: Grammar.pt(String(localized: "Inside your home", comment: "Climate settings section title")), footer: Grammar.pt(String(localized: "This tunes how fast pots dry out.", comment: "Climate settings footer"))) {
                JungleRow(icon: .radiator, title: Grammar.pt(String(localized: "Heating in winter", comment: "Home condition toggle"))) { Toggle("", isOn: $climate.heating).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .airConditioner, title: Grammar.pt(String(localized: "Air conditioning in summer", comment: "Home condition toggle"))) { Toggle("", isOn: $climate.aircon).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .humidity, title: Grammar.pt(String(localized: "The air feels", comment: "Home air humidity picker row, followed by dry/normal/humid"))) {
                    Picker("", selection: $climate.homeAir) { ForEach(Climate.HomeAir.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden().tint(Jungle.subtle)
                }
                JungleDivider()
                JungleRow(icon: .windCloud, title: Grammar.pt(String(localized: "Draughty windows or doors", comment: "Home condition toggle"))) { Toggle("", isOn: $climate.drafts).labelsHidden() }
                JungleDivider()
                JungleRow(icon: .garden, title: Grammar.pt(String(localized: "I grow plants outside too", comment: "Home condition toggle")), subtitle: Grammar.pt(String(localized: "Balcony, terrace or garden", comment: "Toggle subtitle"))) { Toggle("", isOn: $climate.growsOutside).labelsHidden() }
            }
        }
    }
}

/// Light per room, so care can match each spot.
struct RoomLightForm: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Space.name) private var spaces: [Space]
    private let suggestions = [Grammar.pt(String(localized: "Living room", comment: "Suggested room name")), Grammar.pt(String(localized: "Bedroom", comment: "Suggested room name")), Grammar.pt(String(localized: "Kitchen", comment: "Suggested room name")), Grammar.pt(String(localized: "Bathroom", comment: "Suggested room name")), Grammar.pt(String(localized: "Office", comment: "Suggested room name"))]

    var body: some View {
        JungleGroup(title: Grammar.pt(String(localized: "Light in each room", comment: "Settings section title")), footer: Grammar.pt(String(localized: "Bright means near a sunny window. You can change these any time in Spaces.", comment: "Room light footer"))) {
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
    var body: some View { tracked.screen("climate_settings") }
    @ViewBuilder private var tracked: some View {
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
