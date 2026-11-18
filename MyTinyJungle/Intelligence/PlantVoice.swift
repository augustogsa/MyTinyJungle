import Foundation

/// Turns engine facts into the plant's own voice. Same plant, same personality, everywhere.
enum PlantVoice {
    static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let h = abs(seed.unicodeScalars.reduce(day) { ($0 &* 31) &+ Int($1.value) })
        return options[h % options.count]
    }

    static func say(_ request: PlantRequest, plant: Plant) -> String {
        let p = plant.personality
        let options: [String]
        switch (request.kind, p) {
        case (.water, .dramatic): options = ["I am PARCHED. A drink, please, before I wilt into legend.", "Water. Now. I'm begging you, with my whole leaves."]
        case (.water, .independent): options = ["Water, please.", "Dry. Water when you can."]
        case (.water, .calm): options = ["My soil is dry now. A slow, deep drink would be lovely.", "I'm ready for some water whenever you are."]
        case (.water, .curious): options = ["You felt my soil and it's dry. Water today?", "Dry soil… does that mean drink time?"]
        case (.water, _): options = ["Thanks for checking! My soil is dry, so I'd love a drink.", "Drink time! My soil is dry."]

        case (.checkSoil, .dramatic): options = ["Is it getting dry in here, or is it just me? Check my soil, quickly!", "I sense… dryness. Feel my soil?"]
        case (.checkSoil, .independent): options = ["Check my soil when you pass by.", "Soil check, please."]
        case (.checkSoil, .calm): options = ["Could you feel my soil today? No rush.", "When you have a moment, a quick soil check would help me."]
        case (.checkSoil, .curious): options = ["How does my soil feel today: dry, moist or wet?", "Can you poke my soil and tell me what you feel?"]
        case (.checkSoil, .chatty): options = ["Hi hi! Could you stick a finger in my soil and tell me how it feels? I think I might be getting dry!", "Soil check! I love these. How am I doing down there?"]
        case (.checkSoil, _): options = ["Can you check my soil? I might be getting thirsty.", "Quick soil check today? I think it's drying out."]

        case (.feed, .dramatic): options = ["I am STARVING for nutrients. Well, a bit peckish. Some food?", "Growing season and no snacks? Tragic."]
        case (.feed, .independent): options = ["Food would help me grow. Diluted, please.", "Feeding time."]
        case (.feed, _): options = ["It's growing season. Could I have a little plant food with my next water?", "I'm growing and a bit hungry. A diluted feed with my next drink?"]

        case (.checkRoots, _): options = ["My roots might be getting crowded. Can we check whether I need a bigger home?", "Could you peek at my drainage holes? Roots poking out means I need more room."]
        case (.portrait, .chatty), (.portrait, .cheerful): options = ["Photo day! Take my monthly portrait so we can see how I've grown.", "Say cheese! Time for my monthly photo."]
        case (.portrait, _): options = ["A monthly photo, please. It helps us see how I'm changing.", "Picture time, for my growth timeline."]
        case (.safety, _): options = ["Heads up: I'm not safe for pets to chew. Keep me somewhere they can't reach."]
        case (.pauseFeeding, _): options = ["I'm resting this season. No food for now, please."]
        }
        return pick(options, seed: plant.id.uuidString + request.kind.rawValue)
    }

    static func happy(_ plant: Plant) -> String {
        switch plant.personality {
        case .dramatic: return pick(["I'm absolutely flourishing, darling.", "Thriving. Iconic, even."], seed: plant.name)
        case .independent: return "All good."
        case .calm: return pick(["I'm comfortable and content today.", "All is well here."], seed: plant.name)
        case .curious: return pick(["I'm doing well! What are you up to today?", "Feeling good. Wonder if I'll grow a new leaf soon?"], seed: plant.name)
        case .chatty: return pick(["I'm great! Nice light, happy roots. Did you see my leaves?", "Doing wonderfully, thanks for asking!"], seed: plant.name)
        case .cheerful: return pick(["I'm doing great today!", "Happy and growing!"], seed: plant.name)
        }
    }

    static func thanks(_ kind: CareKind, plant: Plant) -> String {
        let p = plant.personality
        switch kind {
        case .water: return p == .dramatic ? "Ahh, saved! I feel reborn." : p == .independent ? "Thanks." : pick(["Ahh, that's refreshing. Thank you!", "Mmm, thank you for the drink!"], seed: plant.name)
        case .feed: return p == .independent ? "Noted. Thanks." : "Yum, thank you! I'll put it into new growth."
        case .mist: return "Ooh, a little humidity. Thank you!"
        case .repot: return "A new home! I might sulk a little while my roots settle. That's normal."
        case .prune: return "A fresh haircut. I'll push new growth from there."
        case .move: return "New spot! I'll take a few weeks to adjust, so don't worry if I'm quiet."
        case .rotate: return "Thanks for turning me. Now I'll grow straight."
        case .clean: return "Clean leaves! I can catch so much more light now."
        case .newLeaf: return p == .dramatic ? "BEHOLD. A new leaf." : "Yes! A new leaf. I'm proud of it."
        case .flower: return "I'm flowering! 🌸"
        case .treat: return "Thank you for looking after me. Let's check again in a week."
        case .measure: return "Look how tall I'm getting!"
        default: return "Thank you!"
        }
    }

    static func soilReply(_ soil: SoilState, plant: Plant, expected: Double) -> String {
        switch soil {
        case .dry: return plant.personality == .independent ? "Then water me, please. Slowly, until it drains." : "Dry? Then yes, I'd love a drink. Water slowly until it runs out the bottom."
        case .slightlyMoist: return "Still a little moist, so no water yet. I'll ask again in a couple of days."
        case .wet: return "Still wet! I'll wait. Too much water is worse for me than too little. I'll learn that I dry slower than I thought."
        }
    }
}
