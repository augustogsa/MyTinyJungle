import Foundation

/// Localizes the bundled knowledge data (species.json, knowledge.json).
/// Each language ships `Knowledge/Locales/<lang>.json`:
/// `{ "names": { "<species id>": "Local name" }, "text": { "<English text>": "Translation" } }`.
/// Text is swapped before decoding, so every screen reading the data is localized for free.
/// See Documentation/Localization.md.
enum L10nData {
    /// Keys whose values are identifiers or enums and must never be translated.
    private static let frozenKeys: Set<String> = [
        "id", "scientific", "en", "pt", "family", "waterStyle", "light", "mix", "feed", "growth",
        "group", "groups", "pests", "tags", "wikidata", "aliases", "icon", "symbol", "kind", "species", "ids", "url"
    ]

    private struct Table: Decodable { var names: [String: String]? ; var text: [String: String]? }

    private static let table: Table? = {
        for code in Bundle.main.preferredLocalizations + [Locale.current.identifier] {
            for candidate in [code, String(code.prefix(2))] where !candidate.hasPrefix("en") {
                if let url = Bundle.main.url(forResource: candidate, withExtension: "json", subdirectory: nil)
                    ?? Bundle.main.url(forResource: candidate, withExtension: "json", subdirectory: "Locales"),
                   let data = try? Data(contentsOf: url),
                   let t = try? JSONDecoder().decode(Table.self, from: data) { return t }
            }
        }
        return nil
    }()

    /// Translation of one English data string (returns the input when untranslated).
    static func t(_ english: String) -> String { table?.text?[english] ?? english }

    /// Local common name for a species id, if this language has one.
    static func name(_ id: String) -> String? { table?.names?[id] }

    /// Returns JSON data with every translatable string replaced for the current language.
    static func localize(_ data: Data) -> Data {
        guard let table, let obj = try? JSONSerialization.jsonObject(with: data) else { return data }
        let out = walk(obj, key: nil, table: table)
        return (try? JSONSerialization.data(withJSONObject: out)) ?? data
    }

    private static func walk(_ o: Any, key: String?, table: Table) -> Any {
        // Frozen keys hold ids/enums; lists of objects under the same name (knowledge.json "pests") are still walked.
        if let k = key, frozenKeys.contains(k), !(o is [[String: Any]]) { return o }
        switch o {
        case let s as String: return table.text?[s] ?? s
        case let a as [Any]: return a.map { walk($0, key: $0 is [String: Any] ? nil : key, table: table) }
        case let d as [String: Any]:
            var r = [String: Any]()
            for (k, v) in d { r[k] = walk(v, key: k, table: table) }
            if let id = d["id"] as? String, d["scientific"] != nil, let n = table.names?[id] { r["local"] = n }
            return r
        default: return o
        }
    }
}
