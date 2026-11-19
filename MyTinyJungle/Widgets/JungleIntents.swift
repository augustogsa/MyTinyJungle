import AppIntents
import SwiftData
import Foundation

/// A plant, for Siri, Shortcuts and Spotlight.
struct PlantEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Plant", comment: "App Intents: entity type name"))
    static let defaultQuery = PlantQuery()
    let id: UUID
    @Property(title: LocalizedStringResource("Name", comment: "App Intents: plant name property"))
    var name: String

    init(id: UUID, name: String) { self.id = id; self.name = name }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct PlantQuery: EntityStringQuery {
    @MainActor private func all() -> [Plant] {
        let ctx = MyTinyJungleApp.shared.mainContext
        return ((try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.name)]))) ?? []).filter { !$0.isArtificial }
    }
    func entities(for identifiers: [UUID]) async throws -> [PlantEntity] {
        await MainActor.run { let ids = Set(identifiers); return all().filter { ids.contains($0.id) }.map { PlantEntity(id: $0.id, name: $0.name) } }
    }
    func entities(matching string: String) async throws -> [PlantEntity] {
        await MainActor.run {
            all().filter { $0.name.localizedStandardContains(string) || ($0.species?.commonName.localizedStandardContains(string) ?? false) }
                .map { PlantEntity(id: $0.id, name: $0.name) }
        }
    }
    func suggestedEntities() async throws -> [PlantEntity] {
        await MainActor.run { all().map { PlantEntity(id: $0.id, name: $0.name) } }
    }
}

struct LogWateringIntent: AppIntent {
    static let title = LocalizedStringResource("Log Watering", comment: "App Intents: action title")
    static let description = IntentDescription(LocalizedStringResource("Logs that you watered a plant.", comment: "App Intents: action description"))

    @Parameter(title: LocalizedStringResource("Plant", comment: "App Intents: parameter title"))
    var plant: PlantEntity

    static var parameterSummary: some ParameterSummary { Summary("Log watering for \(\.$plant)") }

    init() {}
    init(plant: PlantEntity) { self.plant = plant }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = plant.id
        let name: String? = await MainActor.run {
            let ctx = MyTinyJungleApp.shared.mainContext
            guard let p = try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { $0.id == id })).first else { return nil }
            // Retried runs must not log twice: skip if this plant was watered in the last ten minutes.
            let recent = (p.events ?? []).contains { $0.kind == p.waterKind && $0.date > Date().addingTimeInterval(-600) }
            if !recent { JungleBrain.quick(p.waterKind, plants: [p], in: ctx) }
            return p.name
        }
        guard let name else { throw IntentError.plantGone }
        return .result(dialog: IntentDialog(LocalizedStringResource("Done. \(name) is watered.", comment: "Siri reply after logging watering; arg plant name")))
    }
}

struct WhatNeedsCareIntent: AppIntent {
    static let title = LocalizedStringResource("What Needs Care Today", comment: "App Intents: action title")
    static let description = IntentDescription(LocalizedStringResource("Tells you which plants need something today.", comment: "App Intents: action description"))

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[PlantEntity]> {
        let (list, plants): (String, [PlantEntity]) = await MainActor.run {
            let ctx = MyTinyJungleApp.shared.mainContext
            let all = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
            let due = WidgetSnapshot.due(all)
            return (due.map { "\($0.0.name): \(Answerer.label($0.1.kind))" }.formatted(.list(type: .and)), due.map { PlantEntity(id: $0.0.id, name: $0.0.name) })
        }
        if plants.isEmpty {
            return .result(value: [], dialog: IntentDialog(LocalizedStringResource("Nothing today. Your jungle is happy.", comment: "Siri reply: no care due today")))
        }
        return .result(value: plants, dialog: IntentDialog(LocalizedStringResource("Today: \(list).", comment: "Siri reply: care due today; arg list like 'Leo: water and Fern: soil check'")))
    }
}

struct AddPlantIntent: AppIntent {
    static let title = LocalizedStringResource("Add a Plant", comment: "App Intents: action title")
    static let description = IntentDescription(LocalizedStringResource("Opens My Tiny Jungle to add a new plant.", comment: "App Intents: action description"))
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await MainActor.run { _ = DeepLink.handle(URL(string: "mytinyjungle://add")!) }
        return .result()
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case plantGone
    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource("I couldn't find that plant in your jungle.", comment: "Siri error: plant not found")
    }
}

struct JungleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWateringIntent(), phrases: [
            "Log watering for \(\.$plant) in \(.applicationName)",
            "I watered \(\.$plant) in \(.applicationName)",
            "Water \(\.$plant) in \(.applicationName)",
        ], shortTitle: LocalizedStringResource("Log Watering", comment: "Shortcut tile title"), systemImageName: "drop.fill")
        AppShortcut(intent: WhatNeedsCareIntent(), phrases: [
            "What needs care today in \(.applicationName)",
            "What do my plants need in \(.applicationName)",
            "Check my \(.applicationName)",
        ], shortTitle: LocalizedStringResource("Needs Care Today", comment: "Shortcut tile title"), systemImageName: "leaf.fill")
        AppShortcut(intent: AddPlantIntent(), phrases: [
            "Add a plant in \(.applicationName)",
            "Add a plant to \(.applicationName)",
        ], shortTitle: LocalizedStringResource("Add a Plant", comment: "Shortcut tile title"), systemImageName: "plus.circle.fill")
    }
}
