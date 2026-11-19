import Foundation
import SwiftData
import WidgetKit

/// What the Home and Lock Screen widgets show, written to the shared App Group after every care change.
/// The same shape lives in JungleWidgets/Snapshot.swift; keep both in step.
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
}

@MainActor
enum WidgetSnapshot {
    static func symbol(_ k: PlantRequest.Kind) -> String {
        switch k {
        case .water, .refreshWater, .topUp, .soak: "drop.fill"
        case .mist: "humidity.fill"
        case .feed, .pauseFeeding: "leaf.fill"
        case .quarantine, .treatFollowUp: "ladybug.fill"
        case .checkSoil, .checkRoots: "hand.point.up.left.fill"
        case .portrait: "camera.fill"
        case .safety: "pawprint.fill"
        case .askDone: "questionmark.circle.fill"
        }
    }

    static func symbol(_ k: ReminderKind) -> String {
        switch k {
        case .water: "drop.fill"
        case .mist: "humidity.fill"
        case .feed: "leaf.fill"
        case .pests: "ladybug.fill"
        case .repot: "arrow.up.bin.fill"
        default: "leaf"
        }
    }

    /// Plants with something to do today, most urgent first.
    static func due(_ plants: [Plant], now: Date = Date()) -> [(Plant, PlantRequest)] {
        plants.filter { !$0.isArchived && !$0.isArtificial }
            .compactMap { p in CareEngine.requests(for: p, now: now).filter { $0.priority <= 2 }.min { $0.priority < $1.priority }.map { (p, $0) } }
            .sorted { $0.1.priority < $1.1.priority }
    }

    static func make(_ plants: [Plant], now: Date = Date()) -> JungleWidgetSnapshot {
        let live = plants.filter { !$0.isArchived && !$0.isArtificial }
        let due = due(live, now: now)
        let end = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let next = CareForecast.items(for: live, days: 14, now: now).filter { $0.date >= end }.min { $0.date < $1.date }
        let mood: String, line: String
        if live.isEmpty {
            mood = "wave"; line = Grammar.pt(String(localized: "Add your first plant", comment: "Widget: no plants yet; max 24 chars"))
        } else if due.isEmpty {
            mood = "happy"; line = Grammar.pt(String(localized: "Everyone's happy", comment: "Widget: nothing due today; max 20 chars"))
        } else if due.contains(where: { $0.1.priority == 0 }) {
            mood = "water"; line = Grammar.pt(String(localized: "Some plants need you", comment: "Widget: urgent care today; max 22 chars"))
        } else {
            mood = "love"; line = Grammar.pt(String(localized: "A little care today", comment: "Widget: some care due today; max 22 chars"))
        }
        return JungleWidgetSnapshot(
            updated: now, plantCount: live.count,
            due: due.prefix(6).map { .init(id: $0.0.id.uuidString, name: $0.0.name, need: Answerer.label($0.1.kind), symbol: symbol($0.1.kind), urgent: $0.1.priority == 0) },
            next: next.map { .init(id: $0.plantID?.uuidString, name: $0.plantName, line: $0.line, date: $0.date, symbol: symbol($0.kind)) },
            mood: mood, moodLine: line)
    }

    private static var last: JungleWidgetSnapshot?

    /// Writes the snapshot and asks WidgetKit to redraw, only when something changed.
    static func write(_ plants: [Plant]) {
        guard let url = JungleWidgetSnapshot.url else { return }
        var s = make(plants)
        let stamp = s.updated
        s.updated = last?.updated ?? stamp
        if s == last { return }
        s.updated = stamp
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: url, options: .atomic)
        last = s
        WidgetCenter.shared.reloadAllTimelines()
    }
}
