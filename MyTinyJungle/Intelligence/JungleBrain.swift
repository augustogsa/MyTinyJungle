import Foundation
import SwiftData

/// Orchestrates: chat text / chips → parser → records → engine → plant replies.
@MainActor
enum JungleBrain {
    static func refs(_ plants: [Plant]) -> [ChatParser.PlantRef] {
        plants.map { .init(id: $0.id, name: $0.name, speciesID: $0.speciesID) }
    }

    /// Handle a message typed in a plant's chat (plant != nil) or the jungle chat (nil).
    static func handle(_ text: String, photo: Data? = nil, plant context: Plant?, plants: [Plant], in ctx: ModelContext, now: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || photo != nil else { return }
        ctx.insert(ChatMessage(text: trimmed, fromUser: true, plant: context, photo: photo))

        if let photo {
            let targets = context.map { [$0] } ?? (plants.count == 1 ? plants : [])
            for p in targets {
                let e = CareEvent(kind: .photo, date: now, note: trimmed, source: "chat")
                e.photo = photo
                e.plant = p
                ctx.insert(e)
                if p.photo == nil { p.photo = photo }
                reply(String(localized: "Thanks for the photo! It's in my timeline now.", comment: "Plant chat: the plant thanks the user for a photo added to its growth timeline. Warm, first person (the plant speaks)."), plant: context ?? p, in: ctx)
            }
            if targets.isEmpty { reply(String(localized: "Which plant is in this photo? Tell me its name.", comment: "Jungle chat: user sent a photo without saying which plant it shows."), plant: nil, in: ctx, suggestions: plants.prefix(4).map(\.name)) }
            if trimmed.isEmpty { try? ctx.save(); return }
        }

        // New plant by chat: "I got a monstera called Milo".
        if context == nil, mentionsNewPlant(trimmed.folded), !Store.shared.canAddPlant(current: plants.count) {
            reply(String(localized: "Your jungle has \(plants.count) plants, the free limit. My Tiny Jungle Plus lets it grow without limits.", comment: "Jungle chat: free plan plant limit reached. %lld = number of plants. Keep 'My Tiny Jungle Plus' in English."), plant: nil, in: ctx, suggestions: [String(localized: "See Plus", comment: "Chat suggestion chip: see the Plus subscription. Max 14 chars.")])
            try? ctx.save()
            return
        }
        if context == nil, let created = createPlantIfMentioned(trimmed, plants: plants, in: ctx, now: now) {
            let hello = created.species.map {
                String(localized: "Hi, I'm \(created.name)! Nice to meet you. I'm a \($0.commonName) (\($0.scientific)). \($0.waterRule) \(askLastWater)",
                       comment: "Plant chat: a newly added plant introduces itself. Args: plant name, species common name, scientific name, watering rule sentence, then the question 'When did you last water me?'. Cheerful.")
            } ?? String(localized: "Hi, I'm \(created.name)! Nice to meet you. Tell me what kind of plant I am so I can look after myself properly. \(askLastWater)",
                        comment: "Plant chat: a newly added plant of unknown species introduces itself. Args: plant name, then the question 'When did you last water me?'.")
            reply(hello, plant: created, in: ctx, suggestions: [
                String(localized: "Today", comment: "Chat suggestion chip answering 'when did you last water me?'"),
                String(localized: "Yesterday", comment: "Chat suggestion chip answering 'when did you last water me?'"),
                String(localized: "Not sure", comment: "Chat suggestion chip: user doesn't know when they last watered."),
            ])
            reply(String(localized: "Added \(created.name) to your jungle.", comment: "Jungle chat: confirmation a plant was added. %@ = plant name."), plant: nil, in: ctx)
            try? ctx.save()
            return
        }

        // Short answers to the plant's own questions ("When did you last water me?").
        if let context {
            let f = trimmed.folded
            let lastAsk = (context.messages ?? []).filter { !$0.fromUser }.max { $0.date < $1.date }?.text ?? ""
            if lastAsk.contains(askLastWater) || lastAsk.contains("last water"), ChatParser.matches(#"^(today|yesterday|hoje|ontem|anteontem|\d+ days? ago|ha \d+ dias?|faz \d+ dias?|\d+ dias? atras|last week|semana passada)$"#, f) {
                apply(.init(kind: .water, plantIDs: [context.id], date: ChatParser.parseDate(f, now: now)), to: context, in: ctx, now: now)
                if context.location.isEmpty { reply(askWhere, plant: context, in: ctx) }
                try? ctx.save(); return
            }
            if ChatParser.matches(#"^(not sure|no idea|dont know|don't know|nao sei|sei la|nao lembro|nem ideia|nao tenho ideia)$"#, f) {
                reply(String(localized: "No problem. Just feel my soil and tell me if it's dry, moist or wet. That's better than a date anyway.", comment: "Plant chat: user doesn't remember last watering; the plant reassures and asks for a soil feel check."), plant: context, in: ctx, suggestions: soilChips)
                try? ctx.save(); return
            }
            if lastAsk.contains(askWhere) || lastAsk.contains("Where do I live"), context.location.isEmpty, trimmed.count < 40, !trimmed.contains("?") {
                context.location = trimmed
                if ChatParser.matches(#"\b(balcony|garden|terrace|outside|varanda|jardim|terraco|quintal|sacada|area externa|lado de fora)\b"#, f) { context.isOutdoor = true }
                reply(String(localized: "\(trimmed.capitalized), noted. I'll remember where I live.", comment: "Plant chat: plant confirms the room/spot it lives in. %@ = place the user typed."), plant: context, in: ctx)
                try? ctx.save(); return
            }
        }

        let result = ChatParser.parse(trimmed, plants: refs(plants), context: context?.id, now: now)
        let byID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })

        if result.isQuestion {
            let targets = result.questionPlantIDs.compactMap { byID[$0] }
            if targets.count == 1 || context != nil {
                let p = context ?? targets[0]
                let a = Answerer.answer(trimmed, plant: p, plants: plants, now: now)
                reply(a.text, plant: p, in: ctx, suggestions: a.suggestions, alsoJungle: context == nil)
            } else {
                let a = Answerer.answer(trimmed, plant: nil, plants: plants, now: now)
                reply(a.text, plant: nil, in: ctx, suggestions: a.suggestions)
            }
            try? ctx.save()
            return
        }

        if result.actions.isEmpty {
            if let context {
                let note = CareEvent(kind: .note, date: now, note: trimmed)
                note.plant = context
                ctx.insert(note)
                reply(String(localized: "Noted in my journal.", comment: "Plant chat: the plant saved the user's message as a note in its journal."), plant: context, in: ctx)
            } else {
                reply(plants.isEmpty ? String(localized: "I'd love to meet your first plant! Try \"I have a monstera called Milo in the living room\".", comment: "Jungle chat: no plants yet; example sentence the user can type to add one (translate the example into natural Portuguese the parser understands, e.g. 'Tenho uma costela-de-adão chamada Milo na sala').")
                      : String(localized: "Hmm, I'm not sure what you mean. You could say \"watered \(plants.prefix(2).map(\.name).formatted(.list(type: .and)))\", or just ask me anything about them.", comment: "Jungle chat: message not understood. %@ = one or two plant names as a list. Example uses the verb 'watered' (pt: 'reguei')."), plant: nil, in: ctx)
            }
            try? ctx.save()
            return
        }

        var summary: [String] = []
        var entries: [LogCard.Entry] = []
        var cardDate = now
        for action in result.actions {
            let targets = action.plantIDs.compactMap { byID[$0] }
            if targets.isEmpty { continue }
            for p in targets {
                let e = apply(action, to: p, in: ctx, now: now, speak: context != nil)
                entries.append(.init(plantID: p.id, eventID: e.id, kind: e.kindRaw))
            }
            cardDate = action.date
            summary.append(cardLine(action.kind, targets, date: action.date, now: now))
        }

        if summary.isEmpty {
            reply(String(localized: "Which plant was that? Mention its name.", comment: "Chat: user logged care but no plant could be matched."), plant: context, in: ctx, suggestions: plants.prefix(4).map(\.name))
        } else if context == nil {
            postCard(entries, date: cardDate, text: summary.joined(separator: "\n"), in: ctx)
        }
        try? ctx.save()
    }

    /// One-tap shortcuts (Water, Feed, Mist…) and soil answers. `announce` posts a card in the jungle thread.
    static func quick(_ kind: CareKind, soil: SoilState? = nil, plants targets: [Plant], in ctx: ModelContext, now: Date = Date(), announce: Bool = false) {
        var entries: [LogCard.Entry] = []
        for p in targets {
            let e = apply(.init(kind: kind, plantIDs: [p.id], date: now, soil: soil), to: p, in: ctx, now: now, source: "chip", speak: !announce || kind == .soilCheck)
            entries.append(.init(plantID: p.id, eventID: e.id, kind: e.kindRaw))
        }
        if !targets.isEmpty {
            let line = "\(kind.label) · \(targets.map(\.name).formatted(.list(type: .and)))"
            Task { @MainActor in ErtyCheer.shared.show(ErtyMood.forCare(kind), line) }
        }
        if announce, !entries.isEmpty {
            postCard(entries, date: now, text: cardLine(kind, targets, date: now, now: now), in: ctx)
        }
        try? ctx.save()
    }

    static func postCard(_ entries: [LogCard.Entry], date: Date, text: String, in ctx: ModelContext) {
        let m = ChatMessage(text: text, fromUser: false)
        m.logCard = LogCard(entries: entries, date: date)
        ctx.insert(m)
    }

    /// Undo a card: delete its events and restore what they changed.
    static func undo(_ message: ChatMessage, plants: [Plant], in ctx: ModelContext) {
        guard var card = message.logCard, !card.undone else { return }
        let byID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        for entry in card.entries {
            guard let p = byID[entry.plantID], let e = (p.events ?? []).first(where: { $0.id == entry.eventID }) else { continue }
            ctx.delete(e)
            if e.kind == .repot { p.lastRepotAt = p.sortedEvents.first { $0.kind == .repot && $0.id != e.id }?.date }
        }
        card.undone = true
        message.logCard = card
        try? ctx.save()
    }

    static func redate(_ message: ChatMessage, to date: Date, plants: [Plant], in ctx: ModelContext) {
        guard var card = message.logCard, !card.undone else { return }
        let byID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        for entry in card.entries {
            if let e = byID[entry.plantID]?.events?.first(where: { $0.id == entry.eventID }) {
                e.date = date
                if e.kind == .repot { byID[entry.plantID]?.lastRepotAt = date }
            }
        }
        card.date = date
        message.logCard = card
        try? ctx.save()
    }

    static func attachPhoto(_ data: Data, to message: ChatMessage, plants: [Plant], in ctx: ModelContext) {
        guard var card = message.logCard else { return }
        let ids = Set(card.entries.map(\.plantID))
        for p in plants where ids.contains(p.id) {
            let e = CareEvent(kind: .photo, note: "", source: "chat")
            e.photo = data
            e.plant = p
            ctx.insert(e)
            p.photo = data
            card.entries.append(.init(plantID: p.id, eventID: e.id, kind: e.kindRaw))
        }
        message.logCard = card
        try? ctx.save()
    }

    @discardableResult
    static func apply(_ action: ParsedAction, to plant: Plant, in ctx: ModelContext, now: Date, source: String = "chat", speak: Bool = true) -> CareEvent {
        let e = CareEvent(kind: action.kind, date: action.date, note: action.detail ?? "", source: source)
        e.value = action.value
        e.soil = action.soil
        e.plant = plant

        switch action.kind {
        case .soilCheck:
            if let soil = action.soil {
                CareEngine.learn(from: soil, plant: plant, at: action.date)
                ctx.insert(e)
                let reply = PlantVoice.soilReply(soil, plant: plant, expected: CareEngine.expectedDryDays(for: plant, at: now))
                self.reply(reply, plant: plant, in: ctx, suggestions: soil == .dry ? [wateredChip] : [])
                return e
            }
        case .water:
            // Watering right after a "dry" check confirms the learned interval.
            if let check = plant.lastEvent(.soilCheck), check.soil == .dry,
               let prev = plant.lastEvent(.water)?.date, check.date > prev {
                CareEngine.learn(from: .dry, plant: plant, at: check.date)
            } else {
                CareEngine.learnFromWatering(plant: plant, at: action.date)
            }
        case .repot:
            plant.lastRepotAt = action.date
            if let cm = action.value { plant.potDiameterCm = cm }
        case .move:
            if let place = action.detail { plant.location = place }
        case .measure:
            if let cm = action.value { plant.heightCm = cm }
        default: break
        }
        ctx.insert(e)
        if speak { reply(PlantVoice.thanks(action.kind, plant: plant), plant: plant, in: ctx) }
        return e
    }

    static func reply(_ text: String, plant: Plant?, in ctx: ModelContext, suggestions: [String] = [], alsoJungle: Bool = false) {
        ctx.insert(ChatMessage(text: text, fromUser: false, plant: plant, suggestions: suggestions))
        if alsoJungle, let plant {
            let m = ChatMessage(text: text, fromUser: false, plant: nil, suggestions: [])
            m.speakerID = plant.id
            ctx.insert(m)
        }
    }

    /// Log card line: "Water · Milo and Fern (yesterday)".
    static func cardLine(_ kind: CareKind, _ targets: [Plant], date: Date, now: Date) -> String {
        let names = targets.map(\.name).formatted(.list(type: .and))
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return String(localized: "\(kind.label) · \(names)", comment: "Chat log card: care action and the plants it was done for. Args: care action label, list of plant names.")
        }
        return String(localized: "\(kind.label) · \(names) (\(CareEngine.relative(date, now)))", comment: "Chat log card for a past day. Args: care action label, list of plant names, relative day like 'yesterday' or '3 days ago'.")
    }

    // MARK: localized chat bits that are also matched later

    nonisolated static var askLastWater: String { String(localized: "When did you last water me?", comment: "Plant chat: the plant asks when it was last watered. Must appear identically inside the plant's introduction.") }
    nonisolated static var askWhere: String { String(localized: "Where do I live: which room or window?", comment: "Plant chat: plant asks which room or window it lives in.") }
    nonisolated static var wateredChip: String { String(localized: "Watered", comment: "Chat suggestion chip: user confirms they watered (pt: 'Reguei'; the chat parser understands it). Max 14 chars.") }
    nonisolated static var soilChips: [String] {
        [String(localized: "Dry", comment: "Chat suggestion chip: the soil feels dry (pt: 'Seca', refers to a terra)."),
         String(localized: "Slightly moist", comment: "Chat suggestion chip: the soil feels slightly moist (pt: 'Levemente úmida')."),
         String(localized: "Wet", comment: "Chat suggestion chip: the soil feels wet (pt: 'Molhada').")]
    }

    // MARK: onboarding by chat

    static func mentionsNewPlant(_ t: String) -> Bool {
        ChatParser.matches(#"\b(new plant|got a|got an|bought|i have a|i have an|adopted|comprei|tenho uma?|nova planta|planta nova|ganhei|adotei|chegou uma?)\b"#, t)
    }

    static func createPlantIfMentioned(_ text: String, plants: [Plant], in ctx: ModelContext, now: Date) -> Plant? {
        let t = text.folded
        guard mentionsNewPlant(t) else { return nil }
        let species = SpeciesLibrary.shared.mentioned(in: t)
        var name = ChatParser.capture(#"\b(?:called|named|chamad[ao]|se chama|nome e|nome) ([a-z][a-z0-9' -]{0,20})"#, t)?
            .components(separatedBy: CharacterSet(charactersIn: ",.!")).first?
            .components(separatedBy: " ").prefix(2).joined(separator: " ")
        name = name.flatMap { $0.replacingOccurrences(of: #"\b(in|on|na|no|em|and|e|que|da|do)$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        guard species != nil || name != nil else { return nil }
        let finalName = (name?.isEmpty == false ? name! : species!.commonName).capitalized
        if plants.contains(where: { $0.name.folded == finalName.folded }) { return nil }
        let plant = Plant(name: finalName, speciesID: species?.id, personality: Personality.allCases.randomElement() ?? .cheerful)
        if let place = ChatParser.capture(#"\b(?:in the|in my|on the|by the|na|no) ([a-z ]{3,25})"#, t) {
            plant.location = place.trimmingCharacters(in: .whitespaces)
        }
        if ChatParser.matches(#"\b(balcony|garden|terrace|outside|outdoor|varanda|jardim|terraco|quintal|sacada|area externa)\b"#, t) { plant.isOutdoor = true }
        plant.acquiredAt = now
        ctx.insert(plant)
        return plant
    }
}
