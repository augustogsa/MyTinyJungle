import Foundation
import SwiftData
import CryptoKit
import Observation

/// Two-way sync between SwiftData and api.mytinyjungle.com, so the same jungle shows up on every device.
///
/// The models stay as they are. A ledger remembers, per record, the server version and a hash of what was
/// last synced. Local edits are found by re-hashing; deletions are ledger entries with no local object.
/// Pull first (server changes since the cursor), then push. Stale pushes return the server copy, which wins.
/// Photos travel separately as encrypted media keyed by the record id.
@Observable @MainActor
final class JungleSync {
    static let shared = JungleSync()

    enum Status: Equatable { case idle, syncing, offline, failed }
    private(set) var status: Status = .idle
    private(set) var lastSync: Date? = UserDefaults.standard.object(forKey: "jungleSync.last") as? Date
    private(set) var jungleID: String?

    private var container: ModelContainer?
    private var ledger = Ledger.load()
    private var running = false
    private var again = false
    private var debounce: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    /// Changes made by this engine are not echoed back as local edits.
    private var applying = false

    func start(_ container: ModelContainer) {
        self.container = container
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSoon() }
        }
    }

    /// Sync a few seconds after the last local save.
    func scheduleSoon() {
        guard !applying, JungleAPI.shared.hasSession else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Forget everything about the server (sign-out, account deletion). Local plants stay.
    func reset() {
        ledger = Ledger()
        ledger.save()
        jungleID = nil
        lastSync = nil
        UserDefaults.standard.removeObject(forKey: "jungleSync.last")
    }

    func sync() async {
        guard let container, JungleAPI.shared.hasSession else { return }
        if running { again = true; return }
        running = true
        status = .syncing
        defer { running = false }
        repeat {
            again = false
            do {
                if ledger.userID != JungleAPI.shared.userID { ledger = Ledger(userID: JungleAPI.shared.userID) }
                let jungles = try await JungleAPI.shared.jungles()
                guard let personal = jungles.first(where: { $0.isPersonal })?.id else { throw JungleAPI.APIError.http(500, "no_jungle") }
                jungleID = personal
                let ctx = container.mainContext
                try await pull(ctx)
                try await push(ctx, jungle: personal)
                ledger.save()
                lastSync = Date()
                UserDefaults.standard.set(lastSync, forKey: "jungleSync.last")
                status = .idle
            } catch JungleAPI.APIError.offline {
                status = .offline; ledger.save(); return
            } catch JungleAPI.APIError.signedOut {
                status = .idle; return
            } catch {
                status = .failed; ledger.save(); return
            }
        } while again
    }

    var summary: String {
        switch status {
        case .syncing: return Grammar.pt(String(localized: "Syncing…", comment: "Sync status in Settings; max 30 chars"))
        case .offline: return Grammar.pt(String(localized: "Waiting for a connection", comment: "Sync status in Settings; max 30 chars"))
        case .failed: return Grammar.pt(String(localized: "Didn't sync. Tap to try again.", comment: "Sync status in Settings; max 40 chars"))
        case .idle:
            if let lastSync { return Grammar.pt(String(localized: "Synced \(lastSync.formatted(.relative(presentation: .named)))", comment: "Sync status; %@ relative date like 'yesterday' or '5 minutes ago'")) }
            return Grammar.pt(String(localized: "On every device you sign in to", comment: "Sync status before first sync; max 40 chars"))
        }
    }

    // MARK: Pull

    private func pull(_ ctx: ModelContext) async throws {
        struct Page: Decodable { var changes: [Remote]; var cursor: Int64; var more: Bool }
        var more = true
        while more {
            let page: Page = try await JungleAPI.shared.get("/v1/sync/pull", query: [.init(name: "since", value: String(ledger.cursor)), .init(name: "limit", value: "500")])
            // Parents before children so relationships resolve.
            let ordered = page.changes.sorted { Kind.order($0.entity) < Kind.order($1.entity) }
            applying = true
            for r in ordered { try await apply(r, ctx) }
            try? ctx.save()
            applying = false
            ledger.cursor = page.cursor
            more = page.more
        }
    }

    private func apply(_ r: Remote, _ ctx: ModelContext) async throws {
        guard let kind = Kind(rawValue: r.entity), let id = UUID(uuidString: r.id) else { return }
        let key = Ledger.key(kind, id)
        if r.deleted {
            kind.delete(id, ctx)
            ledger.entries[key] = nil
            return
        }
        guard let payload = try? kind.decode(r.data) else { return }
        var photoHash = ledger.entries[key]?.photo
        if kind.hasPhoto {
            if let remoteHash = payload.photoHash, remoteHash != photoHash, let jid = jungleID ?? Optional(r.jungleId) {
                if let data = try await JungleAPI.shared.download("/v1/media/\(jid)/\(id.uuidString.lowercased())") {
                    payload.photoData = data
                    photoHash = remoteHash
                }
            } else if payload.photoHash == nil {
                payload.photoData = nil
                photoHash = nil
            } else {
                payload.keepLocalPhoto = true
            }
        }
        payload.upsert(id: id, ctx)
        ledger.entries[key] = .init(version: r.version, hash: payload.hash(), photo: photoHash)
    }

    // MARK: Push

    private func push(_ ctx: ModelContext, jungle: String) async throws {
        var changes: [Change] = []
        var seen = Set<String>()
        var photoUploads: [(UUID, Data, String)] = []
        let now = Date()
        for kind in Kind.allCases {
            for item in kind.locals(ctx) {
                let key = Ledger.key(kind, item.id)
                seen.insert(key)
                let entry = ledger.entries[key]
                var payload = item.payload
                if kind.hasPhoto, let data = item.photo {
                    let ph = Self.sha(data)
                    payload.photoHash = ph
                    if entry?.photo != ph { photoUploads.append((item.id, data, ph)) }
                }
                let h = payload.hash()
                if entry?.hash == h && (!kind.hasPhoto || entry?.photo == payload.photoHash) { continue }
                changes.append(Change(jungleId: jungle, entity: kind.rawValue, id: item.id.uuidString.lowercased(), data: payload.json(),
                                      deleted: false, baseVersion: entry?.version, clientUpdatedAt: now, hash: h, photoHash: payload.photoHash))
            }
        }
        // Ledger entries with no local object were deleted here.
        for (key, entry) in ledger.entries where !seen.contains(key) {
            guard let (kind, id) = Ledger.parse(key) else { continue }
            changes.append(Change(jungleId: jungle, entity: kind.rawValue, id: id.uuidString.lowercased(), data: ["deleted": true],
                                  deleted: true, baseVersion: entry.version, clientUpdatedAt: now, hash: "", photoHash: nil))
        }
        for (id, data, _) in photoUploads {
            try await JungleAPI.shared.upload("/v1/media/\(jungle)/\(id.uuidString.lowercased())", data: data, contentType: Self.mime(data))
        }
        struct Result: Decodable { var id: String; var entity: String; var status: String; var version: Int64?; var server: Remote? }
        struct Response: Decodable { var results: [Result] }
        struct Body: Encodable { var changes: [Change] }
        for batch in stride(from: 0, to: changes.count, by: 200).map({ Array(changes[$0..<min($0 + 200, changes.count)]) }) {
            let res: Response = try await JungleAPI.shared.send("POST", "/v1/sync/push", body: Body(changes: batch))
            applying = true
            for (change, r) in zip(batch, res.results) {
                guard let kind = Kind(rawValue: change.entity), let id = UUID(uuidString: change.id) else { continue }
                let key = Ledger.key(kind, id)
                switch r.status {
                case "ok":
                    ledger.entries[key] = change.deleted ? nil : .init(version: r.version ?? 0, hash: change.hash, photo: change.photoHash)
                case "conflict":
                    if let server = r.server { try await apply(server, ctx) }
                default:
                    break // invalid / forbidden: leave it; it is retried next time and visible in logs.
                }
            }
            try? ctx.save()
            applying = false
        }
    }

    // MARK: Helpers

    nonisolated static func sha(_ d: Data) -> String { SHA256.hash(data: d).prefix(16).map { String(format: "%02x", $0) }.joined() }

    nonisolated static func mime(_ d: Data) -> String {
        if d.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if d.count > 12, d[8..<12] == Data("WEBP".utf8) { return "image/webp" }
        if d.count > 12, d[4..<8] == Data("ftyp".utf8) { return "image/heic" }
        return "image/jpeg"
    }
}

// MARK: - Wire types

struct Remote: Decodable {
    var jungleId: String
    var entity: String
    var id: String
    var data: JSONValue
    var deleted: Bool
    var version: Int64
}

private struct Change: Encodable {
    var jungleId: String
    var entity: String
    var id: String
    var data: [String: JSONValue]
    var deleted: Bool
    var baseVersion: Int64?
    var clientUpdatedAt: Date
    var hash: String
    var photoHash: String?
    enum CodingKeys: String, CodingKey { case jungleId, entity, id, data, deleted, baseVersion, clientUpdatedAt }
}

/// Minimal JSON tree so records pass through without losing fields from newer app versions.
enum JSONValue: Codable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

extension JSONValue: ExpressibleByBooleanLiteral { init(booleanLiteral v: Bool) { self = .bool(v) } }

// MARK: - Ledger

private struct Ledger: Codable {
    struct Entry: Codable { var version: Int64; var hash: String; var photo: String? }
    var userID: String?
    var cursor: Int64 = 0
    var entries: [String: Entry] = [:]

    static func key(_ k: Kind, _ id: UUID) -> String { "\(k.rawValue)/\(id.uuidString.lowercased())" }
    static func parse(_ key: String) -> (Kind, UUID)? {
        let p = key.split(separator: "/")
        guard p.count == 2, let k = Kind(rawValue: String(p[0])), let id = UUID(uuidString: String(p[1])) else { return nil }
        return (k, id)
    }

    static var url: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "jungle-sync-ledger.json")
    }
    static func load() -> Ledger { (try? JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))) ?? Ledger() }
    func save() { try? JSONEncoder().encode(self).write(to: Self.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
}
