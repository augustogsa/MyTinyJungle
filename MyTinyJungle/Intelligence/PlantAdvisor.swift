import Foundation

/// Turns species knowledge + the photo read + the rest of the jungle into a first care plan.
struct WelcomePlan {
    struct Item: Identifiable { let id = UUID(); let symbol: String; let title: String; let detail: String }
    var firstWater: Item
    var food: Item
    var spot: Item
    var neighbours: Item?
    var potAndSoil: Item
    var safety: Item?
    var suggestedName: String
    var suggestedPersonality: Personality
    var outdoorsHint: Bool
}

enum PlantAdvisor {
    static func plan(species s: Species, read: PhotoRead?, existing: [Plant], now: Date = Date(), settings: JungleSettings = .shared) -> WelcomePlan {
        // Water: photo soil estimate first, then the species rule.
        let water: WelcomePlan.Item
        switch read?.soilMoisture {
        case .dry?: water = .init(symbol: "drop.fill", title: String(localized: "Water today", comment: "Welcome care plan for a newly added plant: card title."), detail: s.waterStyle == .moist ? String(localized: "The soil in your photo looks dry. Water slowly until it drains, then let it stay lightly moist. (Photo estimate: feel it to be sure.)", comment: "Welcome care plan for a newly added plant.") : String(localized: "The soil in your photo looks dry. Water slowly until it drains, then let it dry again. (Photo estimate: feel it to be sure.)", comment: "Welcome care plan for a newly added plant."))
        case .wet?: water = .init(symbol: "drop", title: String(localized: "Don't water yet", comment: "Welcome care plan for a newly added plant: card title."), detail: String(localized: "The soil in your photo looks wet. Wait, then I'll ask for a soil check in a few days. (Photo estimate.)", comment: "Welcome care plan for a newly added plant."))
        case .slightlyMoist?: water = .init(symbol: "drop.halffull", title: String(localized: "Check in 2–3 days", comment: "Welcome care plan for a newly added plant: card title."), detail: String(localized: "Soil looks slightly moist. \(s.waterRule)", comment: "Welcome care plan for a newly added plant. %@ = watering rule sentence."))
        case nil: water = .init(symbol: "hand.point.down", title: String(localized: "Feel the soil first", comment: "Welcome care plan for a newly added plant: card title."), detail: String(localized: "\(s.waterRule) Usually every \(Int(s.dryMin))–\(Int(s.dryMax)) days indoors. I'll learn the real rhythm from your checks.", comment: "Welcome care plan for a newly added plant. Args: watering rule, min and max days."))
        }

        let growing = CareEngine.isGrowingSeason(now)
        let food = WelcomePlan.Item(symbol: "leaf.arrow.triangle.circlepath",
            title: growing ? String(localized: "Feed every \(Int(s.feedWeeks)) weeks", comment: "Welcome care plan for a newly added plant: card title. %lld = weeks (plural).") : String(localized: "No food until spring", comment: "Welcome care plan for a newly added plant: card title."),
            detail: s.feed == "none" ? String(localized: "Never: it catches its own food. Rainwater only.", comment: "Welcome care plan for a newly added plant: carnivorous plant.") : growing ? [String(localized: "Wait 2–3 weeks while it settles in, then \(feedPhrase(s.feed)).", comment: "Welcome care plan for a newly added plant. %@ = feeding instruction starting lowercase with a verb (e.g. 'use a cactus feed at half strength')."), s.fertilizer.map { "\($0.name), \($0.npk)." }].compactMap { $0 }.joined(separator: " ") : String(localized: "It's resting season, so feeding now only builds up salts. I'll remind you in spring.", comment: "Welcome care plan for a newly added plant."))

        // Spot: light + temperature + humidity, matched to rooms you already use.
        let compatibleRooms = existing.compactMap { p -> String? in
            guard let ps = p.species, !p.location.isEmpty, ps.light == s.light else { return nil }
            return p.location
        }.uniqued()
        var spotDetail = String(localized: "\(s.lightRule) Keep it between \(Climate.temp(s.tempMin)) and \(Climate.temp(s.tempMax)), away from radiators and drafts.", comment: "Welcome care plan for a newly added plant. Args: light rule, min and max temperature.")
        if s.humidityMin >= 55 { spotDetail += " " + String(localized: "Loves humidity: a bathroom with a window or a group of plants is ideal.", comment: "Welcome care plan for a newly added plant.") }
        if let fit = Climate.shared.fit(s) { spotDetail += " " + fit }
        if Climate.shared.homeAir == .dry && s.humidityMin >= 50 { spotDetail += " " + String(localized: "Your home runs dry, so a humidifier or a plant group will help.", comment: "Welcome care plan for a newly added plant.") }
        if let room = compatibleRooms.first { spotDetail += " " + String(localized: "\(room.capitalized) suits it, since plants there have the same light needs.", comment: "Welcome care plan for a newly added plant. %@ = room name.") }
        let spot = WelcomePlan.Item(symbol: "sun.max", title: spotTitle(s.light), detail: spotDetail)

        // Neighbours: plants with matching light, humidity and water style feel better together (shared microclimate).
        let mates = existing.filter { p in
            guard let ps = p.species, !p.isArchived else { return false }
            return ps.light == s.light && abs(ps.humidityMin - s.humidityMin) <= 10 && waterBand(ps.waterStyle) == waterBand(s.waterStyle)
        }
        let neighbours: WelcomePlan.Item? = mates.isEmpty ? nil : .init(symbol: "person.2.fill",
            title: String(localized: "Happiest near \(mates.prefix(3).map(\.name).formatted(.list(type: .and)))", comment: "Welcome care plan for a newly added plant: card title. %@ = list of plant names."),
            detail: mates.contains { CareEngine.mood(for: $0) == .needsYou } ? String(localized: "They share light, humidity and watering rhythm. Grouping them raises local humidity and makes care easier. Check them for pests before grouping.", comment: "Welcome care plan for a newly added plant.") : String(localized: "They share light, humidity and watering rhythm. Grouping them raises local humidity and makes care easier.", comment: "Welcome care plan for a newly added plant."))

        let pot = WelcomePlan.Item(symbol: "arrow.up.bin", title: String(localized: "Pot & soil", comment: "Welcome care plan for a newly added plant: card title."),
            detail: [s.soilPlan, String(localized: "Drainage holes always.", comment: "Welcome care plan for a newly added plant."), s.waterStyle == .dry ? String(localized: "Terracotta helps it dry out.", comment: "Welcome care plan for a newly added plant. Terracotta = vaso de barro.") : s.waterStyle == .moist ? String(localized: "Plastic or glazed ceramic holds moisture better.", comment: "Welcome care plan for a newly added plant.") : String(localized: "Any material works with good drainage.", comment: "Welcome care plan for a newly added plant."), String(localized: "Usually needs a bigger pot every \(Int(s.repotYears)) years, only 2–5 cm wider.", comment: "Welcome care plan for a newly added plant. %lld = years (plural).")].joined(separator: " "))

        var safety: WelcomePlan.Item?
        if s.toxicCats || s.toxicDogs {
            let pets = settings.hasCats || settings.hasDogs
            safety = .init(symbol: "pawprint.fill", title: pets ? String(localized: "Keep away from your pets", comment: "Welcome care plan for a newly added plant: card title.") : String(localized: "Not pet-safe", comment: "Welcome care plan for a newly added plant: card title."),
                           detail: settings.hasKids ? String(localized: "Toxic or irritating if chewed (ASPCA). Keep it out of children's reach too.", comment: "Welcome care plan for a newly added plant.") : String(localized: "Toxic or irritating if chewed (ASPCA).", comment: "Welcome care plan for a newly added plant."))
        }

        let personality: Personality = switch s.family {
        case "Marantaceae": .dramatic
        case "Cactaceae", "Crassulaceae", "Asphodelaceae": .independent
        case "Araceae": s.growth == "fast" ? .chatty : .cheerful
        case "Orchidaceae": .calm
        case "Lamiaceae", "Solanaceae": .curious
        default: .cheerful
        }

        let name = nameIdeas(for: s, personality: personality, existing: existing).first ?? s.commonName
        return WelcomePlan(firstWater: water, food: food, spot: spot, neighbours: neighbours, potAndSoil: pot, safety: safety,
                           suggestedName: name, suggestedPersonality: personality,
                           outdoorsHint: s.outdoor == true || ["Lamiaceae", "Solanaceae", "Oleaceae", "Rutaceae"].contains(s.family))
    }

    static func waterBand(_ w: Species.WaterStyle) -> Int { w == .dry ? 0 : w == .moist ? 2 : 1 }

    static func spotTitle(_ l: Species.Light) -> String {
        switch l {
        case .low: String(localized: "Shady corner is fine", comment: "Welcome plan: best spot card title. Max 34 chars.")
        case .medium: String(localized: "Near a window, out of direct sun", comment: "Welcome plan: best spot card title. Max 34 chars.")
        case .bright: String(localized: "Close to a bright window", comment: "Welcome plan: best spot card title. Max 34 chars.")
        case .direct: String(localized: "Sunniest window or outside", comment: "Welcome plan: best spot card title. Max 34 chars.")
        }
    }

    static func feedPhrase(_ f: String) -> String {
        switch f {
        case "cactus": String(localized: "use a cactus feed at half strength", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        case "orchid": String(localized: "use orchid feed, weakly and often", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        case "acid": String(localized: "use an ericaceous (acid) feed", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        case "citrus": String(localized: "use a citrus feed with iron and magnesium", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        case "bloom": String(localized: "use a balanced feed, then a high-potassium one while it flowers", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        case "light": String(localized: "use a balanced liquid feed at half strength", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        default: String(localized: "use a balanced liquid feed as the label says", comment: "Feeding instruction, starts lowercase with a verb, completes 'then …'.")
        }
    }

    /// Name ideas from the species itself (puns on its name), its family and its personality. Never repeats a name already in the jungle.
    static func nameIdeas(for s: Species?, personality: Personality? = nil, existing: [Plant] = []) -> [String] {
        func names(_ list: String) -> [String] { list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let byID: [String: [String]] = [
            "monstera-deliciosa": names(String(localized: "Monty, Swiss, Cheesy, Delilah", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "epipremnum-aureum": names(String(localized: "Goldie, Posh, Vinnie, Trailblazer", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "sansevieria": names(String(localized: "Sergeant, Sabre, Snakey, Zara", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "zamioculcas": names(String(localized: "Zeke, Zuzu, Zen", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "spathiphyllum": names(String(localized: "Lily, Peaches, Dove", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "ficus-lyrata": names(String(localized: "Fiddle, Fifi, Lyra", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "phalaenopsis": names(String(localized: "Mothra, Phala, Orla", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "calathea": names(String(localized: "Cala, Prayer, Drama", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "aloe-vera": names(String(localized: "Aloha, Vera, Gel", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "ocimum-basilicum": names(String(localized: "Basil, Pesto, Genovese", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "echeveria": names(String(localized: "Rosetta, Echo, Chubby", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
            "chlorophytum": names(String(localized: "Spidey, Charlotte, Webster", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count")),
        ]
        var pool: [String] = []
        if let s {
            pool += byID[s.id] ?? []
            let first = s.commonName.split(separator: " ").first.map(String.init) ?? s.en
            if first.count >= 4 { pool += Locale.current.language.languageCode?.identifier == "en" ? [String(first.prefix(4)) + "y", first] : [first] }
            let fam: [String] = switch s.family {
            case "Araceae": names(String(localized: "Milo, Ollie, Leo, Kiki, Bruno", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Marantaceae": names(String(localized: "Luna, Diva, Iris, Stella", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Cactaceae", "Crassulaceae", "Asphodelaceae": names(String(localized: "Spike, Prickles, Sunny, Pepe", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Moraceae": names(String(localized: "Figgy, Rex, Bonnie", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Orchidaceae": names(String(localized: "Grace, Pearl, Lola", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Lamiaceae": names(String(localized: "Minty, Rosie, Sage", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Rosaceae": names(String(localized: "Rosa, Ruby, Thorny", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            case "Asteraceae": names(String(localized: "Daisy, Sunny, Goldie", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            default: names(String(localized: "Olive, Pip, Juno, Willow", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
            }
            pool += fam
        }
        let mood: [String] = switch personality ?? .cheerful {
        case .cheerful: names(String(localized: "Sunny, Pip, Coco", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        case .calm: names(String(localized: "Zen, Willow, Sage", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        case .dramatic: names(String(localized: "Diva, Duchess, Romeo", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        case .curious: names(String(localized: "Nemo, Scout, Pixel", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        case .independent: names(String(localized: "Rocky, Solo, Boss", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        case .chatty: names(String(localized: "Ziggy, Gossip, Bubbles", comment: "Comma-separated pet-name ideas for a plant; give local, playful names a native would pick, same count"))
        }
        pool += mood
        let used = Set(existing.map { $0.name.folded })
        return pool.uniqued().filter { !used.contains($0.folded) }
    }

    /// Best spot for it: a room you already use with the same light needs, else the classic room for its needs.
    static func suggestedRoom(for s: Species, existing: [Plant]) -> String {
        if let room = existing.first(where: { $0.species?.light == s.light && !$0.location.isEmpty })?.location { return room.capitalized }
        if s.family == "Lamiaceae" { return String(localized: "Kitchen", comment: "Suggested room name for a new plant, capitalized.") }
        if s.humidityMin >= 60 { return String(localized: "Bathroom", comment: "Suggested room name for a new plant, capitalized.") }
        switch s.light {
        case .direct: return String(localized: "Balcony", comment: "Suggested room name for a new plant, capitalized.")
        case .bright: return String(localized: "Living room", comment: "Suggested room name for a new plant, capitalized.")
        case .medium: return String(localized: "Bedroom", comment: "Suggested room name for a new plant, capitalized.")
        case .low: return String(localized: "Office", comment: "Suggested room name for a new plant, capitalized.")
        }
    }
}
