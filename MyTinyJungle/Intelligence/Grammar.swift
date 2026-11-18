import Foundation

/// Brazilian Portuguese puts an article before people's and pets' names, and it contracts with
/// prepositions: "a terra da Dourada", "no Sargento", "pro Pesto", "pela Lili".
/// Translations keep a bare "%@" for the name; `Grammar.pt` fixes the sentence after formatting,
/// using each plant's grammatical gender (inferred from the name, overridable on the plant page).
nonisolated enum Grammar {
    enum Gender: String, Codable, CaseIterable { case feminine = "f", masculine = "m" }

    /// Current plant (and housemate) names → gender. Updated by the app whenever plants change.
    nonisolated(unsafe) static var names: [String: Gender] = [:] {
        didSet { if names != oldValue { cache.removeAll(); rx = Self.compile(names) } }
    }
    nonisolated(unsafe) private static var rx: [(NSRegularExpression, Gender)] = []
    nonisolated(unsafe) private static var cache: [String: String] = [:]

    static let isPortuguese: Bool = (Locale.preferredLanguages.first ?? "").hasPrefix("pt") || Bundle.main.preferredLocalizations.first?.hasPrefix("pt") == true

    // MARK: inference

    private static let maleEndingInA: Set<String> = ["zeca", "juca", "joca", "luca", "nicola", "andrea", "bira", "tuca", "dudu", "kaká", "kaka"]
    private static let femaleEndingInO: Set<String> = []
    private static let femaleNames: Set<String> = ["lili", "lulu", "mimi", "babi", "dani", "gabi", "isa", "bel", "flor", "raquel", "isabel", "mel", "jasmim", "pérola", "perola", "rosa", "íris", "iris", "beatriz", "luz", "paz", "nana", "kiki", "bibi", "cris"]
    private static let maleNames: Set<String> = ["pesto", "monty", "zeca", "sargento", "basil", "milo", "theo", "téo", "leo", "léo", "chico", "tom", "fred", "bob", "max", "rex", "zé", "ze", "joão", "joao", "mané", "mane"]

    static func infer(_ name: String) -> Gender {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        let first = n.split(separator: " ").first.map(String.init) ?? n
        if femaleNames.contains(first) { return .feminine }
        if maleNames.contains(first) || maleEndingInA.contains(first) { return .masculine }
        for suf in ["inha", "ita", "ela", "ina", "ona", "eta", "a", "ã", "ade", "ice", "ez", "ís"] where first.hasSuffix(suf) { return .feminine }
        if first.hasSuffix("i") && first.count <= 5 { return .feminine }
        return .masculine
    }

    // MARK: sentence fixing

    private static let forms: [(prep: String, f: String, m: String)] = [
        ("de", "da", "do"), ("em", "na", "no"), ("por", "pela", "pelo"),
        ("para", "para a", "para o"), ("pra", "pra", "pro"), ("com", "com a", "com o"),
        ("sobre", "sobre a", "sobre o"), ("até", "até a", "até o"), ("e", "e a", "e o"),
    ]

    private static func compile(_ names: [String: Gender]) -> [(NSRegularExpression, Gender)] {
        let preps = forms.map(\.prep).joined(separator: "|")
        // Longest names first so "Dona Rosa" wins over "Rosa".
        return names.keys.filter { !$0.isEmpty }.sorted { $0.count > $1.count }.compactMap { name in
            let esc = NSRegularExpression.escapedPattern(for: name)
            guard let r = try? NSRegularExpression(pattern: "(?<![\\p{L}])(\(preps)) (?=\(esc)(?![\\p{L}]))", options: [.caseInsensitive]) else { return nil }
            return (r, names[name]!)
        }
    }

    /// Adds the right article/contraction before every known name. No-op outside Portuguese.
    static func pt(_ s: String) -> String {
        guard isPortuguese, !rx.isEmpty, s.contains(" ") else { return s }
        if let hit = cache[s] { return hit }
        var out = s
        for (r, g) in rx {
            let matches = r.matches(in: out, range: NSRange(out.startIndex..., in: out))
            guard !matches.isEmpty else { continue }
            var result = "", last = out.startIndex
            for m in matches {
                guard let whole = Range(m.range, in: out), let pr = Range(m.range(at: 1), in: out) else { continue }
                let prep = out[pr].lowercased()
                guard let f = forms.first(where: { $0.prep == prep }) else { continue }
                result += out[last..<whole.lowerBound]
                var rep = g == .feminine ? f.f : f.m
                if out[pr].first?.isUppercase == true { rep = rep.prefix(1).uppercased() + rep.dropFirst() }
                result += rep + " "
                last = whole.upperBound
            }
            result += out[last...]
            out = result
        }
        if cache.count > 4000 { cache.removeAll() }
        cache[s] = out
        return out
    }
}
