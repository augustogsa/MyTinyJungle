import Foundation

struct ParsedAction {
    var kind: CareKind
    var plantIDs: [UUID]
    var date: Date
    var soil: SoilState?
    var value: Double?
    var detail: String?
}

struct ParseResult {
    var actions: [ParsedAction] = []
    var isQuestion = false
    var questionPlantIDs: [UUID] = []
    var unresolvedPlants = false
    var mentionedSpecies: Species?
}

/// Rules-first natural language understanding (EN + PT). Deterministic, offline, testable.
/// Foundation Models is a second pass only when this returns nothing useful.
enum ChatParser {
    struct PlantRef { let id: UUID; let name: String; let speciesID: String? }

    private static let lexicon: [(CareKind, [String])] = [
        (.water, [#"\bwater(ed|ing)?\b"#, #"\bgave .{0,20}(a )?drink\b"#, #"\bdrink\b"#, #"\bregu?(ei|ou|amos|ar|ado)\b"#, #"\bdei agua\b"#, #"\bagua\b"#]),
        (.feed, [#"\bfed\b"#, #"\bfeed(ing)?\b"#, #"\bfertili[sz](ed|er|ing|e)\b"#, #"\bplant food\b"#, #"\badub(ei|ou|o|ar|ado)\b"#, #"\bfertilizei\b"#, #"\bnutrient"#]),
        (.mist, [#"\bmist(ed|ing)?\b"#, #"\bspray(ed)?\b"#, #"\bborrif"#, #"\bpulveriz"#]),
        (.repot, [#"\brepott?(ed|ing)?\b"#, #"\bnew pot\b"#, #"\btransplant"#, #"\bmudei de vaso\b"#, #"\btroquei (o )?vaso\b"#, #"\btransplantei\b"#, #"\bbigger pot\b"#]),
        (.prune, [#"\bprun(ed|ing|e)\b"#, #"\btrimm?(ed|ing)?\b"#, #"\bcut back\b"#, #"\bpod(ei|ar|ou)\b"#]),
        (.rotate, [#"\brotat(ed|e|ing)\b"#, #"\bturned (it|him|her)\b"#, #"\brodei\b"#]),
        (.clean, [#"\bwip(ed|e)\b"#, #"\bclean(ed)? (the )?leaves\b"#, #"\blimpei\b"#, #"\bdusted\b"#]),
        (.treat, [#"\btreat(ed)?\b"#, #"\bneem\b"#, #"\binsecticid"#, #"\btratei\b"#, #"\bsoap spray\b"#]),
        (.newLeaf, [#"\bnew leaf\b"#, #"\bnew leaves\b"#, #"\bfolhas? novas?\b"#, #"\bnova folha\b"#, #"\bunfurl"#]),
        (.flower, [#"\bflower(ing|ed|s)?\b"#, #"\bbloom(ing|ed|s)?\b"#, #"\bflor(es|iu|ir)?\b"#]),
    ]

    private static let questionStarts = ["why", "how", "when", "what", "which", "should", "can", "could", "is", "are", "does", "do", "will",
                                         "porque", "por que", "como", "quando", "qual", "quais", "devo", "posso", "sera", "o que", "e normal", "esta"]

    static func parse(_ raw: String, plants: [PlantRef], context: UUID? = nil, now: Date = Date()) -> ParseResult {
        let text = raw.folded.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ParseResult()
        guard !text.isEmpty else { return result }

        result.mentionedSpecies = SpeciesLibrary.shared.mentioned(in: text)
        let targets = resolvePlants(text, plants: plants, context: context, species: result.mentionedSpecies)
        result.unresolvedPlants = targets.isEmpty

        let isQuestion = raw.contains("?") || questionStarts.contains { text.hasPrefix($0 + " ") }
        if isQuestion {
            result.isQuestion = true
            result.questionPlantIDs = targets
            return result
        }

        let date = parseDate(text, now: now)

        // Soil observation.
        if let soil = parseSoil(text) {
            result.actions.append(.init(kind: .soilCheck, plantIDs: targets, date: date, soil: soil))
        }

        for (kind, patterns) in lexicon where patterns.contains(where: { matches($0, text) }) {
            if kind == .water, result.actions.contains(where: { $0.kind == .soilCheck }), !matches(#"\b(watered|reguei|regou|gave)\b"#, text) { continue }
            if negated(kind: kind, text: text) { continue }
            result.actions.append(.init(kind: kind, plantIDs: targets, date: date))
        }

        if let place = parseMove(text) {
            result.actions.append(.init(kind: .move, plantIDs: targets, date: date, detail: place))
        }
        if let cm = firstNumber(#"(\d+(?:[.,]\d+)?)\s?cm"#, text), matches(#"\b(tall|height|high|mede|altura|grew|cresceu)\b"#, text) || !text.contains("pot") {
            if !matches(#"\bpot|vaso\b"#, text) {
                result.actions.append(.init(kind: .measure, plantIDs: targets, date: date, value: cm))
            }
        }
        if let cm = firstNumber(#"(\d+(?:[.,]\d+)?)\s?cm"#, text), matches(#"\bpot|vaso\b"#, text),
           let i = result.actions.firstIndex(where: { $0.kind == .repot }) {
            result.actions[i].value = cm
        }
        return result
    }

    // MARK: pieces

    static func resolvePlants(_ text: String, plants: [PlantRef], context: UUID?, species: Species?) -> [UUID] {
        if matches(#"\b(all|everyone|everybody|every plant|all of them|todas|todos)\b"#, text) { return plants.map(\.id) }
        let named = plants.filter { p in
            let n = NSRegularExpression.escapedPattern(for: p.name.folded)
            return !n.isEmpty && matches(#"\b"# + n + #"\b"#, text)
        }
        if !named.isEmpty { return named.map(\.id) }
        if let species {
            let same = plants.filter { $0.speciesID == species.id }
            if !same.isEmpty { return same.map(\.id) }
        }
        if let context { return [context] }
        if plants.count == 1 { return plants.map(\.id) }
        return []
    }

    static func parseSoil(_ text: String) -> SoilState? {
        let soilWord = #"(soil|substrate|earth|dirt|terra|substrato|it|she|he|is|feels|esta|ta)"#
        if matches(#"^(dry|bone dry|seco|seca|sequinha)$"#, text) || matches(soilWord + #".{0,15}\b(bone )?dry\b"#, text) || matches(#"\b(terra|substrato) .{0,10}sec[oa]\b"#, text) { return .dry }
        if matches(#"^(wet|soggy|encharcad[oa]|molhad[oa])$"#, text) || matches(soilWord + #".{0,15}\b(wet|soggy|encharcad|molhad)"#, text) { return .wet }
        if matches(#"^(moist|damp|slightly moist|humid[oa]|umid[oa])$"#, text) || matches(soilWord + #".{0,15}\b(moist|damp|humid|umid)"#, text) { return .slightlyMoist }
        return nil
    }

    static func parseMove(_ text: String) -> String? {
        let patterns = [#"\bmoved? (?:[a-z]+ (?:and [a-z]+ )?)?(?:to|into|onto|next to|by) (?:the )?([a-z ]{3,30})"#,
                        #"\bput (?:it|him|her|them) (?:in|on|by|near) (?:the )?([a-z ]{3,30})"#,
                        #"\bmudei (?:[a-z]+ )?para (?:a |o )?([a-z ]{3,30})"#]
        for p in patterns {
            if let m = capture(p, text) {
                let cleaned = m.components(separatedBy: CharacterSet(charactersIn: ".,!;")).first?
                    .replacingOccurrences(of: #"\b(today|yesterday|this morning|hoje|ontem)\b.*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces) ?? m
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    static func parseDate(_ text: String, now: Date) -> Date {
        let cal = Calendar.current
        func back(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }
        if matches(#"\b(day before yesterday|anteontem)\b"#, text) { return back(2) }
        if matches(#"\b(yesterday|last night|ontem)\b"#, text) { return back(1) }
        if let n = firstNumber(#"(\d+) days? ago"#, text) ?? firstNumber(#"ha (\d+) dias?"#, text) { return back(Int(n)) }
        if matches(#"\b(last week|semana passada)\b"#, text) { return back(7) }
        let weekdays = [("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5), ("friday", 6), ("saturday", 7),
                        ("domingo", 1), ("segunda", 2), ("terca", 3), ("quarta", 4), ("quinta", 5), ("sexta", 6), ("sabado", 7)]
        let today = cal.component(.weekday, from: now)
        for (name, wd) in weekdays where matches(#"\b(on |last |na |no )?"# + name + #"\b"#, text) {
            var diff = today - wd
            if diff <= 0 { diff += 7 }
            return back(diff)
        }
        return now
    }

    static func negated(kind: CareKind, text: String) -> Bool {
        matches(#"\b(didn'?t|did not|haven'?t|have not|not|never|nao|forgot to|esqueci)\b .{0,12}\b(water|fed|feed|mist|repot|prun|regu|adub)"#, text)
    }

    // MARK: regex helpers
    static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
    static func capture(_ pattern: String, _ text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
    static func firstNumber(_ pattern: String, _ text: String) -> Double? {
        capture(pattern, text).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }
}
