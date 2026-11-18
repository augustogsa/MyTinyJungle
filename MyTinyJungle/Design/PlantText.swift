import SwiftUI
import SwiftData

/// Message text where every plant name is the plant itself: bold, in the jungle accent
/// (dark green in light mode, light green in dark mode) and a link that opens that plant.
/// Use it for any line the app writes about plants: Coming up, forecasts, chat, alerts.
struct PlantText: View {
    let text: String
    /// Limit to these plants (e.g. one plant's page); nil means every plant you own.
    var plants: [Plant]? = nil
    /// The plant whose page this is: its name is still bold, but not a link back to itself.
    var current: UUID? = nil
    @Query private var allPlants: [Plant]

    init(_ text: String, plants: [Plant]? = nil, current: UUID? = nil) {
        self.text = text
        self.plants = plants
        self.current = current
    }

    var body: some View {
        Text(PlantText.attributed(text, plants: plants ?? allPlants, current: current))
            .tint(Jungle.accentText)
    }

    static let scheme = "tinyjungle-plant"

    static func url(for id: UUID) -> URL { URL(string: "\(scheme)://\(id.uuidString)")! }

    static func plantID(from url: URL) -> UUID? {
        guard url.scheme == scheme, let host = url.host() else { return nil }
        return UUID(uuidString: host)
    }

    /// Longest names first so "Lili Pink" wins over "Lili"; whole words only.
    static func attributed(_ text: String, plants: [Plant], current: UUID? = nil) -> AttributedString {
        var result = AttributedString(text)
        var taken: [Range<String.Index>] = []
        let named = plants.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.name.count > $1.name.count }
        for plant in named {
            var searchFrom = text.startIndex
            while let r = text.range(of: plant.name, options: [.caseInsensitive, .diacriticInsensitive], range: searchFrom..<text.endIndex) {
                searchFrom = r.upperBound
                let before = r.lowerBound == text.startIndex ? nil : text[text.index(before: r.lowerBound)]
                let after = r.upperBound == text.endIndex ? nil : text[r.upperBound]
                guard !(before?.isLetter ?? false), !(after?.isLetter ?? false),
                      !taken.contains(where: { $0.overlaps(r) }),
                      let lower = AttributedString.Index(r.lowerBound, within: result),
                      let upper = AttributedString.Index(r.upperBound, within: result) else { continue }
                taken.append(r)
                if plant.id != current { result[lower..<upper].link = url(for: plant.id) }
                result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
                result[lower..<upper].foregroundColor = Jungle.accentText
            }
        }
        return result
    }
}

private struct PlantLinkSheet: Identifiable { let id: UUID }

private struct PlantLinksModifier: ViewModifier {
    /// Push inside the current stack when there is one; otherwise open the plant in a sheet.
    var push: ((UUID) -> Void)?
    @State private var sheet: PlantLinkSheet?
    @Query private var plants: [Plant]

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let id = PlantText.plantID(from: url) else { return .systemAction }
                guard plants.contains(where: { $0.id == id }) else { return .handled }
                if let push { push(id) } else { sheet = PlantLinkSheet(id: id) }
                return .handled
            })
            .sheet(item: $sheet) { item in
                if let plant = plants.first(where: { $0.id == item.id }) {
                    NavigationStack { PlantHomeView(plant: plant) }
                }
            }
    }
}

extension View {
    /// Makes plant names in `PlantText` open their plant: pushed with `push`, or in a sheet.
    func plantLinks(push: ((UUID) -> Void)? = nil) -> some View {
        modifier(PlantLinksModifier(push: push))
    }
}
