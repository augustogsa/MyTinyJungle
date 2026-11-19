import SwiftUI

/// Shared jungle: who lives with the plants, who looks after which, and what happened.
/// Plain Codable so it syncs as one CloudKit record in a shared zone (CKShare) and caches on disk.

enum HouseKind: String, Codable, CaseIterable, Identifiable {
    case couple, family, housemates, friends
    var id: String { rawValue }
    var label: String {
        switch self {
        case .couple: Grammar.pt(String(localized: "Couple", comment: "Household type; max 14 chars"))
        case .family: Grammar.pt(String(localized: "Family", comment: "Household type; max 14 chars"))
        case .housemates: Grammar.pt(String(localized: "Housemates", comment: "Household type; max 14 chars"))
        case .friends: Grammar.pt(String(localized: "Friends", comment: "Household type: friends who plant-sit; max 14 chars"))
        }
    }
    var blurb: String {
        switch self {
        case .couple: Grammar.pt(String(localized: "Two plant parents, one jungle", comment: "Household type description; short"))
        case .family: Grammar.pt(String(localized: "Everyone at home helps, kids too", comment: "Household type description; short"))
        case .housemates: Grammar.pt(String(localized: "Shared flat, shared plants, fair turns", comment: "Household type description; short"))
        case .friends: Grammar.pt(String(localized: "Friends who water while you're away", comment: "Household type description; short"))
        }
    }
    var icon: Icon3D {
        switch self { case .couple: .heartPin; case .family: .home; case .housemates: .livingRoom; case .friends: .bouquet }
    }
    var defaultName: String {
        switch self {
        case .couple: Grammar.pt(String(localized: "Our jungle", comment: "Default shared jungle name for a couple; max 24 chars"))
        case .family: Grammar.pt(String(localized: "Family jungle", comment: "Default shared jungle name; max 24 chars"))
        case .housemates: Grammar.pt(String(localized: "Flat jungle", comment: "Default shared jungle name for housemates; max 24 chars"))
        case .friends: Grammar.pt(String(localized: "Plant pals", comment: "Default shared jungle name for friends; max 24 chars"))
        }
    }
}

enum MemberRole: String, Codable { case owner, member }

struct Member: Codable, Identifiable, Hashable {
    var id: String            // CloudKit user record name, or a local id before iCloud answers
    var name: String
    var role: MemberRole = .member
    var colorIndex: Int = 0
    var joinedAt: Date = Date()
    /// Away (travel) until this date: their turns pass to others meanwhile.
    var awayUntil: Date?
    var awayCoverID: String?
    var removed = false
    /// Plant sitter: a guest who cares for the jungle until this date, then steps back.
    var sittingUntil: Date?
    var isSitter: Bool { sittingUntil != nil }
    func isSitting(_ now: Date = Date()) -> Bool { sittingUntil.map { $0 > now } ?? false }
    /// Can take turns right now: home, and if a sitter, still on duty.
    func canCare(_ now: Date = Date()) -> Bool { !removed && !isAway(now) && (!isSitter || isSitting(now)) }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }
    func isAway(_ now: Date = Date()) -> Bool { awayUntil.map { $0 > now } ?? false }
    static let palette: [Color] = [Jungle.leaf, Jungle.terracotta, Color(red: 0.42, green: 0.55, blue: 0.78), Color(red: 0.78, green: 0.62, blue: 0.25), Color(red: 0.62, green: 0.48, blue: 0.72), Color(red: 0.3, green: 0.6, blue: 0.58)]
    var color: Color { Self.palette[colorIndex % Self.palette.count] }
}

/// How one plant is looked after: by everyone in turns (default) or by one person.
enum CarePlan: Codable, Hashable {
    case rotate
    case person(String)
}

struct Activity: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case care, joined, left, removed, askCover, coverYes, away, back, thanks, created }
    var id: String = UUID().uuidString
    var kind: Kind
    var memberID: String
    var date: Date = Date()
    var plantID: UUID?
    var plantName: String?
    var careRaw: String?
    var otherID: String?
    var eventID: UUID?
    var care: CareKind? { careRaw.flatMap(CareKind.init(rawValue:)) }
}

struct CoverRequest: Codable, Identifiable, Hashable {
    enum State: String, Codable { case open, accepted, done, withdrawn }
    var id: String = UUID().uuidString
    var fromID: String
    var toID: String?          // nil asks everyone
    var plantIDs: [UUID]
    var until: Date
    var note: String = ""
    var state: State = .open
    var coverID: String?
    var date: Date = Date()
}

/// A light copy of each plant so members who joined see the same jungle.
struct SharedPlant: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var speciesID: String?
    var location: String
    var thumb: Data?
}

struct HouseState: Codable {
    var name: String
    var kind: HouseKind
    var createdAt = Date()
    var members: [Member] = []
    var plans: [UUID: CarePlan] = [:]
    var activity: [Activity] = []
    var requests: [CoverRequest] = []
    var plants: [SharedPlant] = []
    var updatedAt = Date()
    /// The next person to join through the link arrives as a plant sitter until this date.
    var sitterInviteUntil: Date?

    var activeMembers: [Member] { members.filter { !$0.removed } }
    func member(_ id: String?) -> Member? { members.first { $0.id == id } }

    /// Merge two copies: members and requests by id (newest wins), activity is a union.
    mutating func merge(_ other: HouseState) {
        let newer = other.updatedAt > updatedAt
        if newer { name = other.name; kind = other.kind; plans = other.plans }
        var pl = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        for o in other.plants where newer || pl[o.id] == nil { pl[o.id] = o }
        plants = pl.values.sorted { $0.name < $1.name }
        var m = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        for o in other.members { if newer || m[o.id] == nil { m[o.id] = o } }
        members = m.values.sorted { $0.joinedAt < $1.joinedAt }
        var r = Dictionary(uniqueKeysWithValues: requests.map { ($0.id, $0) })
        for o in other.requests {
            if let mine = r[o.id] { if o.state.rank > mine.state.rank { r[o.id] = o } } else { r[o.id] = o }
        }
        requests = r.values.sorted { $0.date > $1.date }
        let ids = Set(activity.map(\.id))
        activity = (activity + other.activity.filter { !ids.contains($0.id) }).sorted { $0.date > $1.date }
        if activity.count > 400 { activity = Array(activity.prefix(400)) }
        updatedAt = max(updatedAt, other.updatedAt)
    }
}

private extension CoverRequest.State {
    var rank: Int { switch self { case .open: 0; case .accepted: 1; case .done, .withdrawn: 2 } }
}
