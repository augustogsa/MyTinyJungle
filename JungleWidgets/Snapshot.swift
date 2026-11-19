import Foundation

/// Same shape as MyTinyJungle/Widgets/WidgetSnapshot.swift; the app writes it, the widgets read it.
nonisolated struct JungleWidgetSnapshot: Codable, Equatable {
    struct Due: Codable, Hashable { var id: String; var name: String; var need: String; var symbol: String; var urgent: Bool }
    struct Next: Codable, Hashable { var id: String?; var name: String; var line: String; var date: Date; var symbol: String }
    var updated: Date
    var plantCount: Int
    var due: [Due]
    var next: Next?
    var mood: String
    var moodLine: String

    static let group = "group.com.simpleappscompany.mytinyjungle"
    static var url: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget.json") }

    static func load() -> JungleWidgetSnapshot? {
        guard let url, let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(JungleWidgetSnapshot.self, from: d)
    }

    static let sample = JungleWidgetSnapshot(
        updated: .now, plantCount: 5,
        due: [.init(id: UUID().uuidString, name: "Leo", need: String(localized: "water", comment: "Widget preview care need"), symbol: "drop.fill", urgent: true),
              .init(id: UUID().uuidString, name: "Fern", need: String(localized: "light mist", comment: "Widget preview care need"), symbol: "humidity.fill", urgent: false)],
        next: .init(id: nil, name: "Goldie", line: String(localized: "Goldie will be thirsty Friday", comment: "Widget preview next care line"), date: .now.addingTimeInterval(3 * 86_400), symbol: "drop.fill"),
        mood: "love", moodLine: String(localized: "A little care today", comment: "Widget: some care due today; max 22 chars"))
}
