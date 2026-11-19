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
        (.water, [#"\bwater(ed|ing)?\b"#, #"\b(watred|waterd|waterred|wtered)\b"#, #"\bgave .{0,20}(a )?drink\b"#, #"\bdrink\b"#,
                  #"\bregu?(ei|ou|amos|ar|ado)\b"#, #"\bregad[ao]\b"#, #"\bagu(ei|ou|amos|ar|ado|ada)\b"#, #"\bmolhei\b"#, #"\bfiz a rega\b"#,
                  #"\b(dei|coloquei|botei|joguei|pus) (um pouco de |uma )?agua\b"#]),
        (.feed, [#"\bfed\b"#, #"\bfeed(ing)?\b"#, #"\bfertili[sz](ed|er|ing|e)\b"#, #"\bplant food\b"#, #"\badub(ei|ou|o|ar|ado|amos)\b"#, #"\bfertilizei\b"#, #"\bfertilizante\b"#, #"\bnutrient"#]),
        (.mist, [#"\bmist(ed|ing)?\b"#, #"\bspray(ed)?\b"#, #"\bborrif"#, #"\bpulveriz"#]),
        (.repot, [#"\brepott?(ed|ing)?\b"#, #"\bnew pot\b"#, #"\btransplant"#, #"\b(mudei|troquei)\b.{0,25}\bde vaso\b"#, #"\btroquei (o |de )?vaso\b"#,
                  #"\bvaso (novo|maior)\b"#, #"\breplantei\b"#, #"\btransplantei\b"#, #"\bbigger pot\b"#]),
        (.prune, [#"\bprun(ed|ing|e)\b"#, #"\btrimm?(ed|ing)?\b"#, #"\bcut back\b"#, #"\bpod(ei|ar|ou|amos)\b"#, #"\bdei uma podada\b"#]),
        (.rotate, [#"\brotat(ed|e|ing)\b"#, #"\bturned (it|him|her)\b"#, #"\brodei\b"#, #"\bgirei\b"#, #"\bvirei (ela|ele|o vaso|a planta)\b"#]),
        (.clean, [#"\bwip(ed|e)\b"#, #"\bclean(ed)? (the )?leaves\b"#, #"\blimpei\b"#, #"\btirei a poeira\b"#, #"\bdusted\b"#]),
        (.treat, [#"\btreat(ed)?\b"#, #"\bneem\b"#, #"\binsecticid"#, #"\btratei\b"#, #"\binseticid"#, #"\bapliquei\b"#, #"\bsoap spray\b"#]),
        (.newLeaf, [#"\bnew leaf\b"#, #"\bnew leaves\b"#, #"\bfolhas? novas?\b"#, #"\bnova folha\b"#, #"\bbrot(ou|aram|o novo)\b"#, #"\bunfurl"#]),
        (.flower, [#"\bflower(ing|ed|s)?\b"#, #"\bbloom(ing|ed|s)?\b"#, #"\bflor(es|iu|ir|indo|ida|ido)?\b"#, #"\bflorad"#, #"\bfloresc"#]),
    ]

    private static let questionStarts = ["why", "how", "when", "what", "which", "should", "can", "could", "is", "are", "does", "do", "will",
                                         "porque", "por que", "como", "quando", "qual", "quais", "devo", "posso", "sera", "o que", "e normal", "esta", "pode", "preciso", "tenho que", "onde", "quanto", "quantos", "quantas", "e verdade", "da pra", "vale a pena",
                                         "pq", "porq", "oq", "o q", "qnd", "qdo", "sera que", "pra que", "cade"]

    /// A future or a need ("water Milo tomorrow", "vou regar a Luna") is not a log, unless a past-tense care verb is there too.
    private static let intent = #"\b(tomorrow|tonight|later today|need to|needs?|have to|has to|gotta|should|going to|gonna|will|remind me|amanha|mais tarde|preciso|precisa|tenho que|tem que|vou|vamos|lembra|lembre|lembrar)\b"#
    private static let past = #"\b(watered|watred|waterd|fed|fertili[sz]ed|misted|sprayed|repotted|pruned|trimmed|rotated|wiped|cleaned|dusted|treated|moved|gave|reguei|regou|aguei|molhei|dei|fiz|adubei|borrifei|podei|troquei|mudei|transplantei|replantei|girei|limpei|tirei|tratei|apliquei|coloquei|botei|levei)\b"#
    /// "watered everyone except Zeca", "reguei o Milo mas não a Luna".
    private static let except = #"\b(?:except|but not|apart from|besides|other than|menos|exceto|tirando|fora|mas nao|so nao)(?: (?:a|o|as|os|the|for|pra|pro))? "#

    static func parse(_ raw: String, plants: [PlantRef], context: UUID? = nil, now: Date = Date()) -> ParseResult {
        let text = raw.folded.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ParseResult()
        guard !text.isEmpty else { return result }

        result.mentionedSpecies = SpeciesLibrary.shared.mentioned(in: text)
        let targets = resolvePlants(text, plants: plants, context: context, species: result.mentionedSpecies)
        result.unresolvedPlants = targets.isEmpty

        if raw.contains("?") || questionStarts.contains(where: { text.hasPrefix($0 + " ") }) {
            result.isQuestion = true
            result.questionPlantIDs = targets
            return result
        }
        if matches(intent, text), !matches(past, text) { return result }

        let date = parseDate(text, now: now)
        if let soil = parseSoil(text) {
            result.actions.append(.init(kind: .soilCheck, plantIDs: targets, date: date, soil: soil))
        }
        for (kind, patterns) in lexicon where patterns.contains(where: { matches($0, text) }) {
            if kind == .water, result.actions.contains(where: { $0.kind == .soilCheck }), !matches(#"\b(watered|reguei|regou|aguei|molhei|gave|dei)\b"#, text) { continue }
            if negated(kind: kind, text: text) { continue }
            result.actions.append(.init(kind: kind, plantIDs: targets, date: date))
        }
        // Water culture and reservoirs: "changed the water", "troquei a água", "topped up the LECA".
        let topUp = matches(#"\b(topped (it |her |him |them )?(up|off)|top(ped)? up the|refilled the (reservoir|water)|completei (a )?agua|enchi o reservatorio|complete el agua|rellene el deposito|rempli le reservoir|wasser aufgefullt|水を足し)"#, text)
        let refresh = matches(#"\b((changed|refreshed|swapped|replaced|renewed) (.{0,20} )?water|fresh water|(troquei|renovei|mudei) (.{0,15} )?agua|agua (nova|fresca|trocada)|cambie el agua|change l'?eau|changer l'?eau|wasser gewechselt|水を(替|換|か)え)"#, text)
        if refresh || topUp {
            if !negated(kind: .water, text: text) {
                if let i = result.actions.firstIndex(where: { $0.kind == .water }) { result.actions[i].detail = refresh ? "refresh" : "top-up" }
                else { result.actions.append(.init(kind: .water, plantIDs: targets, date: date, detail: refresh ? "refresh" : "top-up")) }
                result.actions.removeAll { $0.kind == .repot || $0.kind == .move }
            }
        }
        // "sprayed Luna with neem" is a treatment, not misting.
        if result.actions.contains(where: { $0.kind == .treat }), !matches(#"\bmist(ed|ing)?\b"#, text) { result.actions.removeAll { $0.kind == .mist } }

        if let place = parseMove(text) {
            let first = place.split(separator: " ").first.map(String.init) ?? place
            let isPlant = plants.contains { $0.name.folded == first } || SpeciesLibrary.shared.mentioned(in: place) != nil
            if !isPlant, !matches(#"\b(pot|vaso|planter)\b"#, place) { result.actions.append(.init(kind: .move, plantIDs: targets, date: date, detail: place)) }
        }
        if let cm = firstNumber(#"(\d+(?:[.,]\d+)?)\s?cm"#, text) {
            let height = matches(#"\b(tall|height|high|mede|altura|grew|cresceu|esta com|ta com|tem)\b"#, text)
            if let i = result.actions.firstIndex(where: { $0.kind == .repot }), !height || matches(#"\b(pot|vaso)\b"#, text) { result.actions[i].value = cm }
            else if !matches(#"\b(pot|vaso)\b"#, text) { result.actions.append(.init(kind: .measure, plantIDs: targets, date: date, value: cm)) }
        }
        return result
    }

    // MARK: pieces

    static func resolvePlants(_ text: String, plants: [PlantRef], context: UUID?, species: Species?) -> [UUID] {
        func named(_ p: PlantRef) -> Bool {
            let n = NSRegularExpression.escapedPattern(for: p.name.folded)
            return !n.isEmpty && matches(#"\b"# + n + #"\b"#, text)
        }
        let excluded = Set(plants.filter { !$0.name.isEmpty && matches(except + NSRegularExpression.escapedPattern(for: $0.name.folded) + #"\b"#, text) }.map(\.id))
        if matches(#"\b(all|everyone|everybody|every plant|all of them|all plants|the plants|my plants|todas|todos|todo mundo|tudo|as plantas|minhas plantas)\b"#, text) {
            return plants.map(\.id).filter { !excluded.contains($0) }
        }
        let namedPlants = plants.filter { named($0) && !excluded.contains($0.id) }
        if !namedPlants.isEmpty { return namedPlants.map(\.id) }
        // Every owned plant whose species is named ("reguei a jiboia e a zamioculca").
        let bySpecies = plants.filter { p in
            !excluded.contains(p.id) && (p.speciesID.flatMap { SpeciesLibrary.shared.species(id: $0) }.map { SpeciesLibrary.shared.isNamedIn($0, text: text) } ?? false)
        }
        if !bySpecies.isEmpty { return bySpecies.map(\.id) }
        if let species {
            let same = plants.filter { $0.speciesID == species.id }
            if !same.isEmpty { return same.map(\.id) }
        }
        if let context { return [context] }
        if plants.count == 1 { return plants.map(\.id) }
        return []
    }

    static func parseSoil(_ text: String) -> SoilState? {
        let soilWord = #"(soil|substrate|earth|dirt|terra|substrato|it|she|he|is|was|feels|felt|esta|estava|ta|tava)"#
        if matches(#"^(dry|bone dry|seco|seca|sequinh[oa]|bem sec[oa])$"#, text) || matches(soilWord + #".{0,15}\b(bone dry|dry|sec[oa]|sequinh[oa])\b"#, text) ||
            matches(#"\b(terra|substrato) .{0,25}\b(sec[oa]|sequinh[oa])\b"#, text) { return .dry }
        if matches(#"^(wet|soggy|encharcad[oa]|molhad[oa])$"#, text) || matches(soilWord + #".{0,15}\b(wet|soggy|encharcad|molhad)"#, text) ||
            matches(#"\b(terra|substrato) .{0,25}\b(encharcad|molhad)"#, text) { return .wet }
        if matches(#"^(moist|damp|slightly moist|humid[oa]|umid[oa]|levemente umid[oa]|um pouco umid[oa]|umidinh[oa])$"#, text) ||
            matches(soilWord + #".{0,15}\b(moist|damp|humid|umid)"#, text) || matches(#"\b(terra|substrato) .{0,25}\bumid"#, text) { return .slightlyMoist }
        return nil
    }

    static func parseMove(_ text: String) -> String? {
        let patterns = [#"\bmoved? (?:[a-z]+ (?:and [a-z]+ )?)?(?:to|into|onto|next to|by) (?:the )?([a-z ]{3,30})"#,
                        #"\bput (?:it|him|her|them) (?:in|on|by|near) (?:the )?([a-z ]{3,30})"#,
                        #"\bmudei (?:[a-z]+ ){0,3}?(?:para|pra|pro) (?:a |o )?([a-z ]{3,30})"#,
                        #"\b(?:coloquei|levei|botei) (?:[a-z]+ ){0,3}?(?:na|no|para a|para o|pra|pro|perto da|perto do) ([a-z ]{3,30})"#]
        for p in patterns {
            if let m = capture(p, text) {
                let cleaned = m.components(separatedBy: CharacterSet(charactersIn: ".,!;")).first?
                    .replacingOccurrences(of: #"\b(today|yesterday|this morning|hoje|ontem|de manha|agora)\b.*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces) ?? m
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static let numberWords: [String: Int] = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5,
        "seis": 6, "sete": 7, "oito": 8, "nove": 9, "dez": 10]

    static func parseDate(_ text: String, now: Date) -> Date {
        let cal = Calendar.current
        func back(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }
        if matches(#"\b(day before yesterday|anteontem)\b"#, text) { return back(2) }
        if matches(#"\b(yesterday|yday|last night|ontem|onte|onti)\b"#, text) { return back(1) }
        let num = #"(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez)"#
        for (unit, days) in [(#"(?:days?|dias?)"#, 1), (#"(?:weeks?|semanas?)"#, 7)] {
            let w = capture(#"\b"# + num + " " + unit + #" ago\b"#, text) ?? capture(#"\b(?:ha|faz) "# + num + " " + unit + #"\b"#, text) ?? capture(#"\b"# + num + " " + unit + #" atras\b"#, text)
            if let w, let n = Int(w) ?? numberWords[w] { return back(n * days) }
        }
        if matches(#"\b(last week|semana passada|semana retrasada)\b"#, text) { return back(7) }
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
        matches(#"\b(didn'?t|did not|haven'?t|have not|hasn'?t|not|never|nao|nunca|nem|forgot to|esqueci( de)?)\b .{0,12}\b(water|fed|feed|fertili|mist|spray|repot|prun|trim|rotat|wip|clean|treat|regu|rega|agu|adub|borrif|pod|transplant|replant|troquei|molh|gir|limp|trat)"#, text)
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
