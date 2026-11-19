import Foundation
import SwiftData

enum Personality: String, Codable, CaseIterable, Identifiable {
    case cheerful, calm, dramatic, curious, independent, chatty
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cheerful: Grammar.pt(String(localized: "Cheerful", comment: "Plant personality name"))
        case .calm: Grammar.pt(String(localized: "Calm", comment: "Plant personality name"))
        case .dramatic: Grammar.pt(String(localized: "Dramatic", comment: "Plant personality name"))
        case .curious: Grammar.pt(String(localized: "Curious", comment: "Plant personality name"))
        case .independent: Grammar.pt(String(localized: "Independent", comment: "Plant personality name"))
        case .chatty: Grammar.pt(String(localized: "Chatty", comment: "Plant personality name"))
        }
    }
    var blurb: String {
        switch self {
        case .cheerful: Grammar.pt(String(localized: "Positive and playful", comment: "Plant personality description; short"))
        case .calm: Grammar.pt(String(localized: "Gentle and reassuring", comment: "Plant personality description; short"))
        case .dramatic: Grammar.pt(String(localized: "Expressive, a little theatrical", comment: "Plant personality description; short"))
        case .curious: Grammar.pt(String(localized: "Asks you questions", comment: "Plant personality description; short"))
        case .independent: Grammar.pt(String(localized: "Speaks only when needed", comment: "Plant personality description; short"))
        case .chatty: Grammar.pt(String(localized: "Loves to talk", comment: "Plant personality description; short"))
        }
    }
}

enum CareKind: String, Codable, CaseIterable {
    case water, feed, mist, repot, prune, move, rotate, clean, soilCheck, photo, note, measure, newLeaf, flower, treat, health, propagate
    var label: String {
        switch self {
        case .water: Grammar.pt(String(localized: "Watered", comment: "Care log entry label, past tense; short"))
        case .feed: Grammar.pt(String(localized: "Fed", comment: "Care log entry label, past tense; short"))
        case .mist: Grammar.pt(String(localized: "Misted", comment: "Care log entry label, past tense; short"))
        case .repot: Grammar.pt(String(localized: "Repotted", comment: "Care log entry label, past tense; short"))
        case .prune: Grammar.pt(String(localized: "Pruned", comment: "Care log entry label, past tense; short"))
        case .move: Grammar.pt(String(localized: "Moved", comment: "Care log entry label, past tense; short"))
        case .rotate: Grammar.pt(String(localized: "Rotated", comment: "Care log entry label, past tense; short"))
        case .clean: Grammar.pt(String(localized: "Cleaned leaves", comment: "Care log entry label, past tense; short"))
        case .soilCheck: Grammar.pt(String(localized: "Soil check", comment: "Care log entry label, past tense; short"))
        case .photo: Grammar.pt(String(localized: "Photo", comment: "Care log entry label, past tense; short"))
        case .note: Grammar.pt(String(localized: "Note", comment: "Care log entry label, past tense; short"))
        case .measure: Grammar.pt(String(localized: "Measured", comment: "Care log entry label, past tense; short"))
        case .newLeaf: Grammar.pt(String(localized: "New leaf", comment: "Care log entry label, past tense; short"))
        case .flower: Grammar.pt(String(localized: "Flowering", comment: "Care log entry label, past tense; short"))
        case .treat: Grammar.pt(String(localized: "Treated", comment: "Care log entry label, past tense; short"))
        case .health: Grammar.pt(String(localized: "Health check", comment: "Care log entry label, past tense; short"))
        case .propagate: Grammar.pt(String(localized: "Propagation", comment: "Care log entry label, past tense; short"))
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
        case .dry: Grammar.pt(String(localized: "Dry", comment: "Soil moisture state"))
        case .slightlyMoist: Grammar.pt(String(localized: "Slightly moist", comment: "Soil moisture state"))
        case .wet: Grammar.pt(String(localized: "Wet", comment: "Soil moisture state"))
        }
    }
}

enum PotMaterial: String, Codable, CaseIterable, Identifiable {
    case plastic, terracotta, ceramic, glass, concrete, fabric, metal, wood, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .plastic: Grammar.pt(String(localized: "Plastic", comment: "Pot material"))
        case .terracotta: Grammar.pt(String(localized: "Terracotta", comment: "Pot material"))
        case .ceramic: Grammar.pt(String(localized: "Ceramic", comment: "Pot material"))
        case .glass: Grammar.pt(String(localized: "Glass", comment: "Pot material"))
        case .concrete: Grammar.pt(String(localized: "Concrete", comment: "Pot material"))
        case .fabric: Grammar.pt(String(localized: "Fabric", comment: "Pot material"))
        case .metal: Grammar.pt(String(localized: "Metal", comment: "Pot material"))
        case .wood: Grammar.pt(String(localized: "Wood", comment: "Pot material"))
        case .other: Grammar.pt(String(localized: "Other", comment: "Pot material"))
        }
    }
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
    /// Grammatical gender of the name for languages that need it (pt: "da Dourada" / "do Sargento"). Empty = inferred.
    var nameGenderRaw: String = ""
    var nameGender: Grammar.Gender {
        get { Grammar.Gender(rawValue: nameGenderRaw) ?? Grammar.infer(name) }
        set { nameGenderRaw = newValue.rawValue }
    }
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
    /// Growing medium: soil, chunky, cactus, leca, pon, sphagnum, water, mounted, terrarium, ground. Nil = soil.
    var medium: String?
    /// cutting, seedling, acclimating, repotted, dormant, flowering, recovering, unknown_history. Nil = normal.
    var lifeStage: String?
    var lifeStageAt: Date?
    var potSelfWatering: Bool?
    var potCachepot: Bool?
    /// too_small, ok, too_big
    var potSizeFit: String?
    /// A faux plant: kept for looks, never asks for care.
    var isArtificial: Bool = false
    /// Several plants share this pot.
    var sharesPot: Bool = false

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
    func lastEvent(_ kind: CareKind) -> CareEvent? { let raw = kind.rawValue; return (events ?? []).filter { $0.kindRaw == raw }.max { $0.date < $1.date } }
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
nonisolated struct LogCard: Codable, Equatable {
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
            case .cutting: Grammar.pt(String(localized: "Cutting taken", comment: "Propagation stage; short"))
            case .rooting: Grammar.pt(String(localized: "Roots forming", comment: "Propagation stage; short"))
            case .potting: Grammar.pt(String(localized: "Ready to pot", comment: "Propagation stage; short"))
            case .growing: Grammar.pt(String(localized: "Growing", comment: "Propagation stage; short"))
            case .done: Grammar.pt(String(localized: "New plant", comment: "Propagation stage; short"))
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
