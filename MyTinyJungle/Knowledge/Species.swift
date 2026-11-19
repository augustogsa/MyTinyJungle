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
    var difficulty: Int? = nil
    var bloom: String? = nil
    var tags: [String]? = nil
    /// Local common name injected by L10nData for the current language.
    var local: String? = nil

    struct Problem: Codable, Hashable { let sign: String; let cause: String; let fix: String }

    var commonName: String { local ?? en }

    var waterRule: String {
        switch waterStyle {
        case .dry: Grammar.pt(String(localized: "Water only when the soil is completely dry.", comment: "Watering rule for a plant species; one sentence"))
        case .half: Grammar.pt(String(localized: "Water when the top half of the soil is dry.", comment: "Watering rule for a plant species; one sentence"))
        case .top: Grammar.pt(String(localized: "Water when the top 2–3 cm are dry.", comment: "Watering rule for a plant species; one sentence"))
        case .moist: Grammar.pt(String(localized: "Keep the soil lightly moist, never soggy.", comment: "Watering rule for a plant species; one sentence"))
        }
    }
    var lightRule: String {
        switch light {
        case .low: Grammar.pt(String(localized: "Tolerates low light. Happier in medium light.", comment: "Light need for a plant species; one sentence"))
        case .medium: Grammar.pt(String(localized: "Medium, indirect light.", comment: "Light need for a plant species; one sentence"))
        case .bright: Grammar.pt(String(localized: "Bright, indirect light. A little gentle morning sun is fine.", comment: "Light need for a plant species; one sentence"))
        case .direct: Grammar.pt(String(localized: "Lots of light, including direct sun.", comment: "Light need for a plant species; one sentence"))
        }
    }
    var mixLabel: String {
        if let soil = Knowledge.shared.soil(mix) { return soil.short }
        return switch mix {
        case "aroid": Grammar.pt(String(localized: "chunky aroid mix (bark, perlite, coco coir)", comment: "Soil mix name, lowercase, used inside a sentence"))
        case "cactus": Grammar.pt(String(localized: "gritty cactus & succulent mix", comment: "Soil mix name, lowercase, used inside a sentence"))
        case "orchid": Grammar.pt(String(localized: "orchid bark mix", comment: "Soil mix name, lowercase, used inside a sentence"))
        case "acid": Grammar.pt(String(localized: "acidic (ericaceous) mix", comment: "Soil mix name, lowercase, used inside a sentence"))
        case "citrus": Grammar.pt(String(localized: "citrus mix", comment: "Soil mix name, lowercase, used inside a sentence"))
        case "vegetable": Grammar.pt(String(localized: "vegetable / herb potting mix", comment: "Soil mix name, lowercase, used inside a sentence"))
        default: Grammar.pt(String(localized: "good universal potting mix with extra perlite", comment: "Soil mix name, lowercase, used inside a sentence"))
        }
    }
}

final class SpeciesLibrary {
    static let shared = SpeciesLibrary()
    let all: [Species]
    private let byID: [String: Species]

    init(bundle: Bundle = .main) {
        if let data = ContentFiles.data("data/species.json"),
           let list = try? JSONDecoder().decode([Species].self, from: L10nData.localize(data)) {
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
        return all.filter { ([$0.en, $0.pt, $0.local ?? "", $0.scientific, $0.family] + ($0.aliases ?? [])).contains { $0.folded.contains(q) } }
    }

    /// Best match of a species mentioned inside free text ("my new monstera").
    func mentioned(in text: String) -> Species? {
        let t = " " + text.folded.replacingOccurrences(of: #"[^a-z0-9' ]"#, with: " ", options: .regularExpression) + " "
        var best: (Species, Int)?
        for s in all {
            for name in [s.en, s.pt, s.local ?? "", s.scientific] + (s.aliases ?? []) + s.scientific.split(separator: " ").prefix(1).map(String.init) {
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
