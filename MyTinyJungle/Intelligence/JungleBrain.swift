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
                reply("Thanks for the photo! It's in my timeline now.", plant: context ?? p, in: ctx)
            }
            if targets.isEmpty { reply("Which plant is in this photo? Tell me its name.", plant: nil, in: ctx, suggestions: plants.prefix(4).map(\.name)) }
            if trimmed.isEmpty { try? ctx.save(); return }
        }

        // New plant by chat: "I got a monstera called Milo".
        if context == nil, mentionsNewPlant(trimmed.folded), !Store.shared.canAddPlant(current: plants.count) {
            reply("Your jungle has \(plants.count) plants, the free limit. Tiny Jungle Plus lets it grow without limits. 🌱", plant: nil, in: ctx, suggestions: ["See Plus"])
            try? ctx.save()
            return
        }
        if context == nil, let created = createPlantIfMentioned(trimmed, plants: plants, in: ctx, now: now) {
            let s = created.species.map { " I'm a \($0.en) (\($0.scientific)). \($0.waterRule)" } ?? " Tell me what kind of plant I am so I can look after myself properly."
            reply("Hi, I'm \(created.name)! Nice to meet you.\(s) When did you last water me?", plant: created, in: ctx, suggestions: ["Today", "Yesterday", "Not sure"])
            reply("Added \(created.name) to your jungle. 🌱", plant: nil, in: ctx)
            try? ctx.save()
            return
        }

        // Short answers to the plant's own questions ("When did you last water me?").
        if let context {
            let f = trimmed.folded
            let lastAsk = (context.messages ?? []).filter { !$0.fromUser }.max { $0.date < $1.date }?.text ?? ""
            if lastAsk.contains("last water"), ChatParser.matches(#"^(today|yesterday|hoje|ontem|anteontem|\d+ days? ago|ha \d+ dias?|last week)$"#, f) {
                apply(.init(kind: .water, plantIDs: [context.id], date: ChatParser.parseDate(f, now: now)), to: context, in: ctx, now: now)
                if context.location.isEmpty { reply("Where do I live: which room or window?", plant: context, in: ctx) }
                try? ctx.save(); return
            }
            if ChatParser.matches(#"^(not sure|no idea|dont know|don't know|nao sei|sei la)$"#, f) {
                reply("No problem. Just feel my soil and tell me if it's dry, moist or wet. That's better than a date anyway.", plant: context, in: ctx, suggestions: ["Dry", "Slightly moist", "Wet"])
                try? ctx.save(); return
            }
            if lastAsk.contains("Where do I live"), context.location.isEmpty, trimmed.count < 40, !trimmed.contains("?") {
                context.location = trimmed
                if ChatParser.matches(#"\b(balcony|garden|terrace|outside|varanda|jardim|terraco|quintal)\b"#, f) { context.isOutdoor = true }
                reply("\(trimmed.capitalized), noted. I'll remember where I live.", plant: context, in: ctx)
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
                reply("Noted in my journal. ✍️", plant: context, in: ctx)
            } else {
                reply(plants.isEmpty ? "Tell me about your first plant, e.g. \"I have a monstera called Milo in the living room\"."
                      : "I didn't catch a care action there. Try \"watered Milo and Luna this morning\", or ask a question.", plant: nil, in: ctx)
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
            summary.append("\(action.kind.label) · \(targets.map(\.name).joined(separator: ", "))\(dayNote(action.date, now))")
        }

        if summary.isEmpty {
            reply("Which plant was that? Mention its name.", plant: context, in: ctx, suggestions: plants.prefix(4).map(\.name))
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
        if announce, !entries.isEmpty {
            postCard(entries, date: now, text: "\(kind.label) · \(targets.map(\.name).joined(separator: ", "))", in: ctx)
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
                self.reply(reply, plant: plant, in: ctx, suggestions: soil == .dry ? ["Watered"] : [])
                return e
            }
        case .water:
            // Watering right after a "dry" check confirms the learned interval.
            if let check = plant.lastEvent(.soilCheck), check.soil == .dry,
               let prev = plant.lastEvent(.water)?.date, check.date > prev {
                CareEngine.learn(from: .dry, plant: plant, at: check.date)
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

    static func dayNote(_ date: Date, _ now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now) ? "" : " (\(CareEngine.relative(date, now)))"
    }

    // MARK: onboarding by chat

    static func mentionsNewPlant(_ t: String) -> Bool {
        ChatParser.matches(#"\b(new plant|got a|got an|bought|i have a|i have an|adopted|comprei|tenho uma?|nova planta|ganhei)\b"#, t)
    }

    static func createPlantIfMentioned(_ text: String, plants: [Plant], in ctx: ModelContext, now: Date) -> Plant? {
        let t = text.folded
        guard mentionsNewPlant(t) else { return nil }
        let species = SpeciesLibrary.shared.mentioned(in: t)
        var name = ChatParser.capture(#"\b(?:called|named|chamad[ao]|nome) ([a-z][a-z0-9' -]{0,20})"#, t)?
            .components(separatedBy: CharacterSet(charactersIn: ",.!")).first?
            .components(separatedBy: " ").prefix(2).joined(separator: " ")
        name = name.flatMap { $0.replacingOccurrences(of: #"\b(in|on|na|no|em|and|e)$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        guard species != nil || name != nil else { return nil }
        let finalName = (name?.isEmpty == false ? name! : species!.en).capitalized
        if plants.contains(where: { $0.name.folded == finalName.folded }) { return nil }
        let plant = Plant(name: finalName, speciesID: species?.id, personality: Personality.allCases.randomElement() ?? .cheerful)
        if let place = ChatParser.capture(#"\b(?:in the|in my|on the|by the|na|no) ([a-z ]{3,25})"#, t) {
            plant.location = place.trimmingCharacters(in: .whitespaces)
        }
        if ChatParser.matches(#"\b(balcony|garden|terrace|outside|outdoor|varanda|jardim|terraco|quintal)\b"#, t) { plant.isOutdoor = true }
        plant.acquiredAt = now
        ctx.insert(plant)
        return plant
    }
}
