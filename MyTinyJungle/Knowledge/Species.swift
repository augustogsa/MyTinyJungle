import Foundation

struct Species: Codable, Identifiable, Hashable {
    enum WaterStyle: String, Codable { case dry, half, top, moist }
    enum Light: String, Codable { case low, medium, bright, direct }

    let id: String
    let scientific: String
    let en: String
    let pt: String
    let family: String
    let waterStyle: WaterStyle
    let dryMin: Double
    let dryMax: Double
    let light: Light
    let humidityMin: Double
    let tempMin: Double
    let tempMax: Double
    let toxicCats: Bool
    let toxicDogs: Bool
    let retention: Double
    let aeration: Double
    let phMin: Double
    let phMax: Double
    let mix: String
    let feed: String
    let feedWeeks: Double
    let growth: String
    let repotYears: Double
    let tip: String
    // Deep knowledge (optional so older entries still decode).
    var group: String? = nil
    var origin: String? = nil
    var habit: String? = nil
    var about: String? = nil
    var propagation: [String]? = nil
    var pests: [String]? = nil
    var problems: [Problem]? = nil
    var repotNotes: String? = nil
    var winterFactor: Double? = nil
    var summerFactor: Double? = nil
    var outdoor: Bool? = nil
    var aliases: [String]? = nil
    var wikidata: String? = nil

    struct Problem: Codable, Hashable { let sign: String; let cause: String; let fix: String }

    var commonName: String { Locale.current.language.languageCode?.identifier == "pt" ? pt : en }

    var waterRule: String {
        switch waterStyle {
        case .dry: "Water only when the soil is completely dry."
        case .half: "Water when the top half of the soil is dry."
        case .top: "Water when the top 2–3 cm are dry."
        case .moist: "Keep the soil lightly moist, never soggy."
        }
    }
    var lightRule: String {
        switch light {
        case .low: "Tolerates low light. Happier in medium light."
        case .medium: "Medium, indirect light."
        case .bright: "Bright, indirect light. A little gentle morning sun is fine."
        case .direct: "Lots of light, including direct sun."
        }
    }
    var mixLabel: String {
        if let soil = Knowledge.shared.soil(mix) { return soil.short }
        return switch mix {
        case "aroid": "chunky aroid mix (bark, perlite, coco coir)"
        case "cactus": "gritty cactus & succulent mix"
        case "orchid": "orchid bark mix"
        case "acid": "acidic (ericaceous) mix"
        case "citrus": "citrus mix"
        case "vegetable": "vegetable / herb potting mix"
        default: "good universal potting mix with extra perlite"
        }
    }
}

final class SpeciesLibrary {
    static let shared = SpeciesLibrary()
    let all: [Species]
    private let byID: [String: Species]

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "species", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Species].self, from: data) {
            all = list.sorted { $0.en < $1.en }
        } else {
            all = []
        }
        byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    func species(id: String) -> Species? { byID[id] }

    func search(_ query: String) -> [Species] {
        let q = query.folded
        guard !q.isEmpty else { return all }
        return all.filter { ([$0.en, $0.pt, $0.scientific, $0.family] + ($0.aliases ?? [])).contains { $0.folded.contains(q) } }
    }

    /// Best match of a species mentioned inside free text ("my new monstera").
    func mentioned(in text: String) -> Species? {
        let t = " " + text.folded.replacingOccurrences(of: #"[^a-z0-9' ]"#, with: " ", options: .regularExpression) + " "
        var best: (Species, Int)?
        for s in all {
            for name in [s.en, s.pt, s.scientific] + (s.aliases ?? []) + s.scientific.split(separator: " ").prefix(1).map(String.init) {
                let n = name.folded
                if n.count >= 4, t.contains(" " + n), n.count > (best?.1 ?? 0) { best = (s, n.count) }
            }
        }
        return best?.0
    }
}

extension String {
    var folded: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased() }
}
