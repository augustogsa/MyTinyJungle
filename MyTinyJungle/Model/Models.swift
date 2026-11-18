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
    case water, feed, mist, repot, prune, move, rotate, clean, soilCheck, photo, note, measure, newLeaf, flower, treat
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

    init(text: String, fromUser: Bool, plant: Plant? = nil, suggestions: [String] = [], photo: Data? = nil) {
        self.text = text
        self.fromUser = fromUser
        self.plant = plant
        self.suggestionsRaw = suggestions.joined(separator: "|")
        self.photo = photo
    }

    var suggestions: [String] { suggestionsRaw.isEmpty ? [] : suggestionsRaw.components(separatedBy: "|") }
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
