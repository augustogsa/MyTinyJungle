import Foundation

/// Server plumbing for the shared jungle (api.mytinyjungle.com). The household is a jungle on the server;
/// its state (turns, cover asks, activity, plant roster) is one JSON document merged on the devices and
/// written with compare-and-swap on its version. Works across iPhone and Android, one account per person.
/// Invites are single-use codes behind https://mytinyjungle.com/join/<code>; sitter invites carry their end date.
enum HouseholdCloud {
    /// Where the household lives, remembered after create or join.
    struct Location: Codable, Equatable { var jungleID: String }

    enum Failure: Error { case gone }

    static var available: Bool { JungleAPI.shared.hasSession }
    static var myID: String? { JungleAPI.shared.userID }

    private static var versions: [String: Int64] {
        get { (UserDefaults.standard.dictionary(forKey: "house.versions") as? [String: Int64]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "house.versions") }
    }

    private struct Doc: Codable { var data: HouseState; var version: Int64 }
    private struct Put: Encodable { var data: HouseState; var baseVersion: Int64? }
    private struct Saved: Decodable { var version: Int64 }

    /// Creates the household jungle on the server and stores the first state.
    static func create(state: HouseState) async throws -> Location {
        struct B: Encodable { let name: String }
        struct R: Decodable { let id: String }
        let r: R = try await JungleAPI.shared.send("POST", "/v1/jungles", body: B(name: String(state.name.prefix(60))))
        let loc = Location(jungleID: r.id)
        try await save(state, at: loc)
        return loc
    }

    /// A fresh single-use invite link. A sitter invite makes the joiner a sitter until the date.
    static func invite(at loc: Location, sitterUntil: Date?) async throws -> URL {
        struct B: Encodable { let role: String; let until: Date? }
        let i: JungleAPI.Invite = try await JungleAPI.shared.send("POST", "/v1/jungles/\(loc.jungleID)/invites",
                                                                  body: B(role: sitterUntil == nil ? "member" : "sitter", until: sitterUntil))
        guard let url = URL(string: i.url) else { throw JungleAPI.APIError.http(500, "bad_url") }
        return url
    }

    static func redeem(code: String) async throws -> Location {
        struct R: Decodable { let jungleId: String }
        let r: R = try await JungleAPI.shared.send("POST", "/v1/invites/\(code)/redeem", body: JungleAPI.Empty())
        return Location(jungleID: r.jungleId)
    }

    /// Current state, nil when the jungle has none yet. Throws `.gone` when I'm no longer a member.
    static func fetch(at loc: Location) async throws -> HouseState? {
        do {
            let d: Doc = try await JungleAPI.shared.get("/v1/jungles/\(loc.jungleID)/house")
            versions[loc.jungleID] = d.version
            return d.data
        } catch JungleAPI.APIError.http(404, _) {
            let jungles = try await JungleAPI.shared.jungles()
            if !jungles.contains(where: { $0.id == loc.jungleID }) { throw Failure.gone }
            return nil
        }
    }

    /// Compare-and-swap; on a conflict merge the server copy in and try again, so nobody's change is lost.
    @discardableResult
    static func save(_ state: HouseState, at loc: Location) async throws -> HouseState {
        var merged = state
        for _ in 0..<4 {
            do {
                let r: Saved = try await JungleAPI.shared.send("PUT", "/v1/jungles/\(loc.jungleID)/house",
                                                               body: Put(data: merged, baseVersion: versions[loc.jungleID]))
                versions[loc.jungleID] = r.version
                return merged
            } catch JungleAPI.APIError.http(409, _) {
                guard let remote = try await fetch(at: loc) else { versions[loc.jungleID] = nil; continue }
                merged.merge(remote)
            }
        }
        return merged
    }

    /// Owner removes someone: their access ends on the server at once.
    static func removeParticipant(_ userID: String, at loc: Location) async {
        let _: JungleAPI.OK? = try? await JungleAPI.shared.send("DELETE", "/v1/jungles/\(loc.jungleID)/members/\(userID)", body: Optional<JungleAPI.Empty>.none)
    }

    /// Member leaves; owner ends the jungle for everyone.
    static func leave(at loc: Location, owner: Bool) async {
        if owner {
            let _: JungleAPI.OK? = try? await JungleAPI.shared.send("DELETE", "/v1/jungles/\(loc.jungleID)", body: Optional<JungleAPI.Empty>.none)
        } else if let me = myID {
            await removeParticipant(me, at: loc)
        }
        versions[loc.jungleID] = nil
    }

    /// Invite code from a link like https://mytinyjungle.com/join/ABCD234XYZ.
    static func code(from url: URL) -> String? {
        let p = url.pathComponents
        guard let i = p.firstIndex(of: "join"), i + 1 < p.count else { return nil }
        let code = p[i + 1].uppercased()
        return code.count == 10 && code.allSatisfy({ $0.isLetter || $0.isNumber }) ? code : nil
    }
}

#if DEBUG
/// `-houseSelfTest`: create → invite → read → stale write merges → end, against the live API. Logs PASS/FAIL.
enum HouseholdSelfTest {
    static func run() async {
        guard ProcessInfo.processInfo.arguments.contains("-houseSelfTest"), HouseholdCloud.available else { return }
        do {
            var s = HouseState(name: "Self test", kind: .couple)
            s.members = [Member(id: HouseholdCloud.myID ?? "me", name: "Tester", role: .owner)]
            let loc = try await HouseholdCloud.create(state: s)
            let url = try await HouseholdCloud.invite(at: loc, sitterUntil: Date().addingTimeInterval(86_400))
            guard HouseholdCloud.code(from: url) != nil else { throw JungleAPI.APIError.http(0, "code") }
            guard let read = try await HouseholdCloud.fetch(at: loc), read.name == "Self test" else { throw JungleAPI.APIError.http(0, "read") }
            // Another device wrote meanwhile: the stale save must merge, not overwrite.
            var other = read; other.activity.insert(Activity(kind: .joined, memberID: "other"), at: 0)
            try await HouseholdCloud.save(other, at: loc)
            UserDefaults.standard.set(["x": Int64(0)].merging([loc.jungleID: Int64(1)]) { a, _ in a }, forKey: "house.versions")
            var mine = read; mine.activity.insert(Activity(kind: .thanks, memberID: "me"), at: 0)
            let merged = try await HouseholdCloud.save(mine, at: loc)
            guard merged.activity.contains(where: { $0.memberID == "other" }), merged.activity.contains(where: { $0.memberID == "me" }) else { throw JungleAPI.APIError.http(0, "merge") }
            await HouseholdCloud.leave(at: loc, owner: true)
            do { _ = try await HouseholdCloud.fetch(at: loc); throw JungleAPI.APIError.http(0, "still there") } catch HouseholdCloud.Failure.gone {}
            print("HOUSE SELF TEST PASS \(url.absoluteString)")
        } catch {
            print("HOUSE SELF TEST FAIL \(error)")
        }
    }
}
#endif
