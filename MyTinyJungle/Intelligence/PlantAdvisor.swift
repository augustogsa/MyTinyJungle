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
        case .dry?: water = .init(symbol: "drop.fill", title: "Water today", detail: "The soil in your photo looks dry. Water slowly until it drains, then let it \(s.waterStyle == .moist ? "stay lightly moist" : "dry again"). (Photo estimate: feel it to be sure.)")
        case .wet?: water = .init(symbol: "drop", title: "Don't water yet", detail: "The soil in your photo looks wet. Wait, then I'll ask for a soil check in a few days. (Photo estimate.)")
        case .slightlyMoist?: water = .init(symbol: "drop.halffull", title: "Check in 2–3 days", detail: "Soil looks slightly moist. \(s.waterRule)")
        case nil: water = .init(symbol: "hand.point.down", title: "Feel the soil first", detail: "\(s.waterRule) Usually every \(Int(s.dryMin))–\(Int(s.dryMax)) days indoors. I'll learn the real rhythm from your checks.")
        }

        let growing = CareEngine.isGrowingSeason(now)
        let food = WelcomePlan.Item(symbol: "leaf.arrow.triangle.circlepath",
            title: growing ? "Feed every \(Int(s.feedWeeks)) weeks" : "No food until spring",
            detail: s.feed == "none" ? "Never: it catches its own food. Rainwater only." : growing ? "Wait 2–3 weeks while it settles in, then \(feedPhrase(s.feed)). \(s.fertilizer.map { "\($0.name), \($0.npk)." } ?? "")" : "It's resting season, so feeding now only builds up salts. I'll remind you in spring.")

        // Spot: light + temperature + humidity, matched to rooms you already use.
        let compatibleRooms = existing.compactMap { p -> String? in
            guard let ps = p.species, !p.location.isEmpty, ps.light == s.light else { return nil }
            return p.location
        }.uniqued()
        var spotDetail = "\(s.lightRule) Keep it between \(Climate.temp(s.tempMin)) and \(Climate.temp(s.tempMax)), away from radiators and drafts."
        if s.humidityMin >= 55 { spotDetail += " Loves humidity: a bathroom with a window or a group of plants is ideal." }
        if let fit = Climate.shared.fit(s) { spotDetail += " " + fit }
        if Climate.shared.homeAir == .dry && s.humidityMin >= 50 { spotDetail += " Your home runs dry, so a humidifier or a plant group will help." }
        if let room = compatibleRooms.first { spotDetail += " \(room.capitalized) suits it, since plants there have the same light needs." }
        let spot = WelcomePlan.Item(symbol: "sun.max", title: spotTitle(s.light), detail: spotDetail)

        // Neighbours: plants with matching light, humidity and water style feel better together (shared microclimate).
        let mates = existing.filter { p in
            guard let ps = p.species, !p.isArchived else { return false }
            return ps.light == s.light && abs(ps.humidityMin - s.humidityMin) <= 10 && waterBand(ps.waterStyle) == waterBand(s.waterStyle)
        }
        let neighbours: WelcomePlan.Item? = mates.isEmpty ? nil : .init(symbol: "person.2.fill",
            title: "Happiest near \(mates.prefix(3).map(\.name).joined(separator: ", "))",
            detail: "They share light, humidity and watering rhythm. Grouping them raises local humidity and makes care easier\(mates.contains { CareEngine.mood(for: $0) == .needsYou } ? ". Check them for pests before grouping." : ".")")

        let pot = WelcomePlan.Item(symbol: "arrow.up.bin", title: "Pot & soil",
            detail: "\(s.soilPlan) Drainage holes always. \(s.waterStyle == .dry ? "Terracotta helps it dry out." : s.waterStyle == .moist ? "Plastic or glazed ceramic holds moisture better." : "Any material works with good drainage.") Usually needs a bigger pot every \(Int(s.repotYears)) year\(s.repotYears == 1 ? "" : "s"), only 2–5 cm wider.")

        var safety: WelcomePlan.Item?
        if s.toxicCats || s.toxicDogs {
            let pets = settings.hasCats || settings.hasDogs
            safety = .init(symbol: "pawprint.fill", title: pets ? "Keep away from your pets" : "Not pet-safe",
                           detail: "Toxic or irritating if chewed (ASPCA).\(settings.hasKids ? " Keep it out of children's reach too." : "")")
        }

        let personality: Personality = switch s.family {
        case "Marantaceae": .dramatic
        case "Cactaceae", "Crassulaceae", "Asphodelaceae": .independent
        case "Araceae": s.growth == "fast" ? .chatty : .cheerful
        case "Orchidaceae": .calm
        case "Lamiaceae", "Solanaceae": .curious
        default: .cheerful
        }

        let name = nameIdeas(for: s, personality: personality, existing: existing).first ?? s.en
        return WelcomePlan(firstWater: water, food: food, spot: spot, neighbours: neighbours, potAndSoil: pot, safety: safety,
                           suggestedName: name, suggestedPersonality: personality,
                           outdoorsHint: s.outdoor == true || ["Lamiaceae", "Solanaceae", "Oleaceae", "Rutaceae"].contains(s.family))
    }

    static func waterBand(_ w: Species.WaterStyle) -> Int { w == .dry ? 0 : w == .moist ? 2 : 1 }

    static func spotTitle(_ l: Species.Light) -> String {
        switch l {
        case .low: "Shady corner is fine"
        case .medium: "Near a window, out of direct sun"
        case .bright: "Close to a bright window"
        case .direct: "Sunniest window or outside"
        }
    }

    static func feedPhrase(_ f: String) -> String {
        switch f {
        case "cactus": "use a cactus feed at half strength"
        case "orchid": "use orchid feed, weakly and often"
        case "acid": "use an ericaceous (acid) feed"
        case "citrus": "use a citrus feed with iron and magnesium"
        case "bloom": "use a balanced feed, then a high-potassium one while it flowers"
        case "light": "use a balanced liquid feed at half strength"
        default: "use a balanced liquid feed as the label says"
        }
    }

    /// Name ideas from the species itself (puns on its name), its family and its personality. Never repeats a name already in the jungle.
    static func nameIdeas(for s: Species?, personality: Personality? = nil, existing: [Plant] = []) -> [String] {
        let byID: [String: [String]] = [
            "monstera-deliciosa": ["Monty", "Swiss", "Cheesy", "Delilah"],
            "epipremnum-aureum": ["Goldie", "Posh", "Vinnie", "Trailblazer"],
            "sansevieria": ["Sergeant", "Sabre", "Snakey", "Zara"],
            "zamioculcas": ["Zeke", "Zuzu", "Zen"],
            "spathiphyllum": ["Lily", "Peaches", "Dove"],
            "ficus-lyrata": ["Fiddle", "Fifi", "Lyra"],
            "phalaenopsis": ["Mothra", "Phala", "Orla"],
            "calathea": ["Cala", "Prayer", "Drama"],
            "aloe-vera": ["Aloha", "Vera", "Gel"],
            "ocimum-basilicum": ["Basil", "Pesto", "Genovese"],
            "echeveria": ["Rosetta", "Echo", "Chubby"],
            "chlorophytum": ["Spidey", "Charlotte", "Webster"],
        ]
        var pool: [String] = []
        if let s {
            pool += byID[s.id] ?? []
            let first = s.en.split(separator: " ").first.map(String.init) ?? s.en
            if first.count >= 4 { pool += [String(first.prefix(4)) + "y", first] }
            let fam: [String] = switch s.family {
            case "Araceae": ["Milo", "Ollie", "Leo", "Kiki", "Bruno"]
            case "Marantaceae": ["Luna", "Diva", "Iris", "Stella"]
            case "Cactaceae", "Crassulaceae", "Asphodelaceae": ["Spike", "Prickles", "Sunny", "Pepe"]
            case "Moraceae": ["Figgy", "Rex", "Bonnie"]
            case "Orchidaceae": ["Grace", "Pearl", "Lola"]
            case "Lamiaceae": ["Minty", "Rosie", "Sage"]
            case "Rosaceae": ["Rosa", "Ruby", "Thorny"]
            case "Asteraceae": ["Daisy", "Sunny", "Goldie"]
            default: ["Olive", "Pip", "Juno", "Willow"]
            }
            pool += fam
        }
        let mood: [String] = switch personality ?? .cheerful {
        case .cheerful: ["Sunny", "Pip", "Coco"]
        case .calm: ["Zen", "Willow", "Sage"]
        case .dramatic: ["Diva", "Duchess", "Romeo"]
        case .curious: ["Nemo", "Scout", "Pixel"]
        case .independent: ["Rocky", "Solo", "Boss"]
        case .chatty: ["Ziggy", "Gossip", "Bubbles"]
        }
        pool += mood
        let used = Set(existing.map { $0.name.folded })
        return pool.uniqued().filter { !used.contains($0.folded) }
    }

    /// Best spot for it: a room you already use with the same light needs, else the classic room for its needs.
    static func suggestedRoom(for s: Species, existing: [Plant]) -> String {
        if let room = existing.first(where: { $0.species?.light == s.light && !$0.location.isEmpty })?.location { return room.capitalized }
        if s.family == "Lamiaceae" { return "Kitchen" }
        if s.humidityMin >= 60 { return "Bathroom" }
        switch s.light {
        case .direct: return "Balcony"
        case .bright: return "Living room"
        case .medium: return "Bedroom"
        case .low: return "Office"
        }
    }
}
