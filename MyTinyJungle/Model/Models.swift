import Foundation
import SwiftData

enum Personality: String, Codable, CaseIterable, Identifiable {
    case cheerful, calm, dramatic, curious, independent, chatty
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .cheerful: "Positive and playful"
        case .calm: "Gentle and reassuring"
        case .dramatic: "Expressive, a little theatrical"
        case .curious: "Asks you questions"
        case .independent: "Speaks only when needed"
        case .chatty: "Loves to talk"
        }
    }
}

enum CareKind: String, Codable, CaseIterable {
    case water, feed, mist, repot, prune, move, rotate, clean, soilCheck, photo, note, measure, newLeaf, flower, treat, health, propagate
    var label: String {
        switch self {
        case .water: "Watered"
        case .feed: "Fed"
        case .mist: "Misted"
        case .repot: "Repotted"
        case .prune: "Pruned"
        case .move: "Moved"
        case .rotate: "Rotated"
        case .clean: "Cleaned leaves"
        case .soilCheck: "Soil check"
        case .photo: "Photo"
        case .note: "Note"
        case .measure: "Measured"
        case .newLeaf: "New leaf"
        case .flower: "Flowering"
        case .treat: "Treated"
        case .health: "Health check"
        case .propagate: "Propagation"
        }
    }
    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .feed: "leaf.arrow.triangle.circlepath"
        case .mist: "humidity.fill"
        case .repot: "arrow.up.bin.fill"
        case .prune: "scissors"
        case .move: "arrow.left.arrow.right"
        case .rotate: "arrow.clockwise"
        case .clean: "sparkles"
        case .soilCheck: "hand.point.down.fill"
        case .photo: "camera.fill"
        case .note: "note.text"
        case .measure: "ruler"
        case .newLeaf: "leaf.fill"
        case .flower: "camera.macro"
        case .treat: "cross.case.fill"
        case .health: "stethoscope"
        case .propagate: "scissors.circle"
        }
    }
}

enum SoilState: String, Codable, CaseIterable {
    case dry, slightlyMoist, wet
    var label: String {
        switch self {
        case .dry: "Dry"
        case .slightlyMoist: "Slightly moist"
        case .wet: "Wet"
        }
    }
}

enum PotMaterial: String, Codable, CaseIterable, Identifiable {
    case plastic, terracotta, ceramic, glass, concrete, fabric, metal, wood, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// How much faster the substrate dries than in plastic.
    var dryingFactor: Double {
        switch self {
        case .terracotta, .fabric: 0.8
        case .wood, .concrete: 0.9
        case .glass, .metal: 1.1
        default: 1.0
        }
    }
}

@Model
final class Plant {
    var id: UUID = UUID()
    var name: String = ""
    var speciesID: String?
    var personalityRaw: String = Personality.cheerful.rawValue
    var location: String = ""
    var isOutdoor: Bool = false
    var potDiameterCm: Double?
    var potMaterialRaw: String?
    var potHasDrainage: Bool = true
    var substrate: String = ""
    var heightCm: Double?
    var acquiredAt: Date = Date()
    var lastRepotAt: Date?
    var photo: Data?
    /// Learned days for the substrate to go from watered to dry. Nil until learned.
    var learnedDryDays: Double?
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var archivedReason: String?

    @Relationship(deleteRule: .cascade, inverse: \CareEvent.plant) var events: [CareEvent]? = []
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.plant) var messages: [ChatMessage]? = []

    init(name: String, speciesID: String?, personality: Personality = .cheerful, location: String = "") {
        self.name = name
        self.speciesID = speciesID
        self.personalityRaw = personality.rawValue
        self.location = location
    }

    var personality: Personality {
        get { Personality(rawValue: personalityRaw) ?? .cheerful }
        set { personalityRaw = newValue.rawValue }
    }
    var potMaterial: PotMaterial? {
        get { potMaterialRaw.flatMap(PotMaterial.init(rawValue:)) }
        set { potMaterialRaw = newValue?.rawValue }
    }
    var species: Species? { speciesID.flatMap { SpeciesLibrary.shared.species(id: $0) } }
    var sortedEvents: [CareEvent] { (events ?? []).sorted { $0.date > $1.date } }
    func lastEvent(_ kind: CareKind) -> CareEvent? { sortedEvents.first { $0.kind == kind } }
}

@Model
final class CareEvent {
    var id: UUID = UUID()
    var kindRaw: String = CareKind.note.rawValue
    var date: Date = Date()
    var note: String = ""
    var value: Double?
    var soilRaw: String?
    var productName: String?
    var photo: Data?
    /// "chat", "chip", "scan", "form"
    var source: String = "chat"
    var plant: Plant?

    init(kind: CareKind, date: Date = Date(), note: String = "", source: String = "chat") {
        self.kindRaw = kind.rawValue
        self.date = date
        self.note = note
        self.source = source
    }

    var kind: CareKind { CareKind(rawValue: kindRaw) ?? .note }
    var soil: SoilState? {
        get { soilRaw.flatMap(SoilState.init(rawValue:)) }
        set { soilRaw = newValue?.rawValue }
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var text: String = ""
    var fromUser: Bool = true
    var date: Date = Date()
    var photo: Data?
    /// Nil = the jungle (all plants) thread.
    var plant: Plant?
    /// Suggested quick replies (e.g. "Dry", "Moist", "Wet").
    var suggestionsRaw: String = ""
    /// Plant speaking in the jungle thread (avatar + name header).
    var speakerID: UUID?
    /// JSON payload for rich cards (logged care).
    var cardRaw: String = ""

    init(text: String, fromUser: Bool, plant: Plant? = nil, suggestions: [String] = [], photo: Data? = nil) {
        self.text = text
        self.fromUser = fromUser
        self.plant = plant
        self.suggestionsRaw = suggestions.joined(separator: "|")
        self.photo = photo
    }

    var suggestions: [String] { suggestionsRaw.isEmpty ? [] : suggestionsRaw.components(separatedBy: "|") }

    var logCard: LogCard? {
        get { cardRaw.isEmpty ? nil : try? JSONDecoder().decode(LogCard.self, from: Data(cardRaw.utf8)) }
        set { cardRaw = newValue.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) } ?? "" }
    }
}

/// A logged-care card: which events were recorded, so the card can undo, re-date and add photos.
struct LogCard: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var plantID: UUID
        var eventID: UUID
        var kind: String
    }
    var entries: [Entry]
    var date: Date
    var undone = false
}

@Model
final class OwnedProduct {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = ""
    var barcode: String?
    var npkN: Double?
    var npkP: Double?
    var npkK: Double?
    var ingredients: [String] = []
    var rawText: String = ""
    var addedAt: Date = Date()
    var onShoppingList: Bool = false

    init(name: String, category: String) {
        self.name = name
        self.categoryRaw = category
    }
}


/// A room, window, balcony or garden zone.
@Model
final class Space {
    var id: UUID = UUID()
    var name: String = ""
    var lightRaw: String = Species.Light.medium.rawValue
    var isOutdoor: Bool = false
    var humidity: Double?
    var temperature: Double?
    var windowFacing: String = ""
    var createdAt: Date = Date()

    init(name: String, light: Species.Light = .medium, outdoor: Bool = false) {
        self.name = name
        self.lightRaw = light.rawValue
        self.isOutdoor = outdoor
    }
    var light: Species.Light {
        get { Species.Light(rawValue: lightRaw) ?? .medium }
        set { lightRaw = newValue.rawValue }
    }
}

/// A planned or reminded action ("Remind me later", "Plan repotting", travel prep).
@Model
final class CareTask {
    var id: UUID = UUID()
    var title: String = ""
    var kindRaw: String = CareKind.note.rawValue
    var plantID: UUID?
    var due: Date = Date()
    var done: Bool = false
    var createdAt: Date = Date()

    init(title: String, kind: CareKind, plantID: UUID?, due: Date) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.plantID = plantID
        self.due = due
    }
    var kind: CareKind { CareKind(rawValue: kindRaw) ?? .note }
}

@Model
final class Propagation {
    enum Stage: Int, CaseIterable { case cutting, rooting, potting, growing, done
        var label: String {
            switch self {
            case .cutting: "Cutting taken"
            case .rooting: "Roots forming"
            case .potting: "Ready to pot"
            case .growing: "Growing"
            case .done: "New plant"
            }
        }
    }
    var id: UUID = UUID()
    var parentID: UUID = UUID()
    var method: String = "Water"
    var startedAt: Date = Date()
    var stageRaw: Int = 0
    var childID: UUID?
    var note: String = ""

    init(parentID: UUID, method: String) {
        self.parentID = parentID
        self.method = method
    }
    var stage: Stage {
        get { Stage(rawValue: stageRaw) ?? .cutting }
        set { stageRaw = newValue.rawValue }
    }
}
