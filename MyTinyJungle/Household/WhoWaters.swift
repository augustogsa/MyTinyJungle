import SwiftUI
import SwiftData

/// Server households: roles, pinned plants and the fair watering rotation.
nonisolated struct ServerHousehold: Decodable, Identifiable, Equatable {
    nonisolated struct Member: Decodable, Equatable, Identifiable { var userId: String; var displayName: String?; var role: String; var id: String { userId } }
    nonisolated struct Assignment: Decodable, Equatable { var plantId: String; var userId: String }
    var id: String
    var jungleId: String
    var name: String
    var role: String
    var members: [Member]
    var assignments: [Assignment]
}

nonisolated struct Rotation: Decodable, Equatable {
    nonisolated struct Member: Decodable, Equatable, Identifiable { var userId: String; var displayName: String?; var role: String?; var waterings30d: Int?; var upcoming: Int?; var id: String { userId } }
    nonisolated struct Turn: Decodable, Equatable, Identifiable { var plantId: String?; var plant: String?; var due: Date?; var overdue: Bool?; var userId: String?; var assigned: Bool?; var id: String { "\(plantId ?? "")-\(due?.timeIntervalSince1970 ?? 0)" } }
    var members: [Member]
    var turns: [Turn]
}

@MainActor
enum HouseholdsAPI {
    nonisolated struct Empty: Decodable {}
    static func list() async throws -> [ServerHousehold] {
        nonisolated struct R: Decodable { let households: [ServerHousehold] }
        let r: R = try await JungleAPI.shared.get("/v1/households"); return r.households
    }
    static func create(name: String, jungleId: String?) async throws {
        nonisolated struct B: Encodable { let name: String; let jungleId: String? }
        let _: Empty = try await JungleAPI.shared.send("POST", "/v1/households", body: B(name: name, jungleId: jungleId))
    }
    static func end(_ id: String) async throws { let _: Empty = try await JungleAPI.shared.send("DELETE", "/v1/households/\(id)", body: Optional<String>.none) }
    static func invite(_ id: String, role: String) async throws -> URL? {
        nonisolated struct B: Encodable { let role: String }
        nonisolated struct R: Decodable { let code: String; let url: String }
        let r: R = try await JungleAPI.shared.send("POST", "/v1/households/\(id)/invites", body: B(role: role)); return URL(string: r.url)
    }
    /// Joins by code; false when the code isn't a household invite.
    static func redeem(_ code: String) async -> Bool {
        guard JungleAPI.shared.hasSession else { return false }
        nonisolated struct R: Decodable { let householdId: String }
        guard (try? await JungleAPI.shared.send("POST", "/v1/household-invites/\(code)/redeem", body: Optional<String>.none) as R) != nil else { return false }
        await JungleSync.shared.sync()
        return true
    }
    static func setRole(_ id: String, user: String, role: String) async throws {
        nonisolated struct B: Encodable { let role: String }
        let _: Empty = try await JungleAPI.shared.send("PATCH", "/v1/households/\(id)/members/\(user)", body: B(role: role))
    }
    static func remove(_ id: String, user: String) async throws { let _: Empty = try await JungleAPI.shared.send("DELETE", "/v1/households/\(id)/members/\(user)", body: Optional<String>.none) }
    static func assign(_ id: String, plant: UUID, user: String?) async throws {
        nonisolated struct B: Encodable {
            let plantId: String; let userId: String?
            func encode(to e: Encoder) throws { var c = e.container(keyedBy: K.self); try c.encode(plantId, forKey: .plantId); try c.encode(userId, forKey: .userId) }
            enum K: String, CodingKey { case plantId, userId }
        }
        let _: Empty = try await JungleAPI.shared.send("PUT", "/v1/households/\(id)/assignments", body: B(plantId: plant.uuidString.lowercased(), userId: user))
    }
    static func rotation(_ id: String, days: Int = 7) async throws -> Rotation {
        try await JungleAPI.shared.get("/v1/households/\(id)/rotation", query: [URLQueryItem(name: "days", value: "\(days)")])
    }
    static func roleLabel(_ r: String) -> String {
        r == "owner" ? Grammar.pt(String(localized: "Owner", comment: "Household role; max 12 chars")) : Grammar.pt(String(localized: "Carer", comment: "Household role: can care, can't manage; max 12 chars"))
    }
}

struct WhoWatersView: View {
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.name) private var plants: [Plant]
    @State private var homes: [ServerHousehold] = []
    @State private var rotation: [String: Rotation] = [:]
    @State private var error: String?
    @State private var loaded = false
    @State private var newName = ""
    @State private var invite: URL?
    @State private var code = ""

    private var me: String? { JungleAPI.shared.userID?.lowercased() }

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(Jungle.subtle) }
            if loaded && homes.isEmpty && error == nil {
                Section {
                    Text(Grammar.pt(String(localized: "Share the watering with the people you live with. I'll take turns fairly and remind whoever's up.", comment: "Who waters empty state")))
                        .foregroundStyle(Jungle.subtle)
                    TextField(Grammar.pt(String(localized: "Household name", comment: "Field placeholder")), text: $newName)
                    Button(Grammar.pt(String(localized: "Start a household", comment: "Button"))) { act { try await HouseholdsAPI.create(name: newName.isEmpty ? Grammar.pt(String(localized: "Home", comment: "Default household name")) : newName, jungleId: JungleSync.shared.jungleID) } }
                }
                Section(Grammar.pt(String(localized: "Got an invite code?", comment: "Section title"))) {
                    TextField("ABCD234XYZ", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button(Grammar.pt(String(localized: "Join", comment: "Button: redeem household invite"))) {
                        Task { if await HouseholdsAPI.redeem(code.uppercased()) { code = ""; await load() } else { error = Grammar.pt(String(localized: "That code didn't work. Ask for a new one.", comment: "Invite redeem failed")) } }
                    }.disabled(code.count < 6)
                }
            }
            ForEach(homes) { h in
                let owner = h.role == "owner"
                Section {
                    if let r = rotation[h.id] {
                        ForEach(r.turns.prefix(10)) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.plant ?? "").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                                    if let d = t.due { Text(t.overdue == true ? Grammar.pt(String(localized: "Overdue", comment: "Rotation row tag")) : d.formatted(.dateTime.weekday(.wide).day())).font(.caption).foregroundStyle(t.overdue == true ? Jungle.warmText : Jungle.subtle) }
                                }
                                Spacer()
                                Text(name(t.userId, in: h)).font(.subheadline).foregroundStyle(t.userId == me ? Jungle.accentText : Jungle.subtle)
                                if t.assigned == true { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Jungle.subtle).accessibilityLabel(Grammar.pt(String(localized: "Pinned", comment: "VoiceOver: plant always goes to this person"))) }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        if r.turns.isEmpty { Text(Grammar.pt(String(localized: "Nobody's up this week.", comment: "Rotation empty"))).foregroundStyle(Jungle.subtle) }
                    } else { ProgressView() }
                } header: { Text(Grammar.pt(String(localized: "This week at \(h.name)", comment: "Who waters section; arg household name"))) }

                Section(Grammar.pt(String(localized: "People", comment: "Section title: household members"))) {
                    ForEach(h.members) { m in
                        HStack {
                            Text(m.userId == me ? Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) : (m.displayName ?? "…")).foregroundStyle(Jungle.text)
                            Spacer()
                            if let s = rotation[h.id]?.members.first(where: { $0.userId == m.userId }), let n = s.waterings30d {
                                Text(Grammar.pt(String(localized: "\(n) waterings", comment: "Member stat, last 30 days; plural"))).font(.caption).foregroundStyle(Jungle.subtle)
                            }
                            Text(HouseholdsAPI.roleLabel(m.role)).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        .swipeActions {
                            if m.userId == me {
                                Button(Grammar.pt(String(localized: "Leave", comment: "Button: leave household")), role: .destructive) { act { try await HouseholdsAPI.remove(h.id, user: m.userId) } }
                            } else if owner {
                                Button(Grammar.pt(String(localized: "Remove", comment: "Remove member button")), role: .destructive) { act { try await HouseholdsAPI.remove(h.id, user: m.userId) } }
                                Button(m.role == "owner" ? Grammar.pt(String(localized: "Make carer", comment: "Button")) : Grammar.pt(String(localized: "Make owner", comment: "Button"))) {
                                    act { try await HouseholdsAPI.setRole(h.id, user: m.userId, role: m.role == "owner" ? "carer" : "owner") }
                                }.tint(Jungle.forest)
                            }
                        }
                    }
                    if owner {
                        Menu {
                            Button(Grammar.pt(String(localized: "Invite a carer", comment: "Menu: invite with carer role"))) { act { invite = try await HouseholdsAPI.invite(h.id, role: "carer") } }
                            Button(Grammar.pt(String(localized: "Invite an owner", comment: "Menu: invite with owner role"))) { act { invite = try await HouseholdsAPI.invite(h.id, role: "owner") } }
                        } label: { Label(Grammar.pt(String(localized: "Invite someone", comment: "Button")), systemImage: "person.badge.plus") }
                    }
                    if let invite { ShareLink(item: invite) { Label(Grammar.pt(String(localized: "Share invite link", comment: "Button")), systemImage: "square.and.arrow.up") } }
                }

                if owner {
                    Section {
                        ForEach(plants.filter { !$0.isArtificial }) { p in
                            let pinned = h.assignments.first { $0.plantId.lowercased() == p.id.uuidString.lowercased() }?.userId
                            Picker(p.name, selection: Binding(get: { pinned ?? "" }, set: { u in act { try await HouseholdsAPI.assign(h.id, plant: p.id, user: u.isEmpty ? nil : u) } })) {
                                Text(Grammar.pt(String(localized: "Take turns", comment: "Care plan: rotate between members"))).tag("")
                                ForEach(h.members) { m in Text(m.userId == me ? Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) : (m.displayName ?? "…")).tag(m.userId) }
                            }
                        }
                    } header: { Text(Grammar.pt(String(localized: "Who looks after what", comment: "Section title: pin plants to people"))) }
                    Section {
                        Button(Grammar.pt(String(localized: "End household", comment: "Button")), role: .destructive) { act { try await HouseholdsAPI.end(h.id) } }
                    } footer: { Text(Grammar.pt(String(localized: "The plants stay in the jungle.", comment: "Footer under end household"))) }
                }
            }
        }
        .scrollContentBackground(.hidden).jungleBackdrop().tint(Jungle.forest)
        .navigationTitle(Grammar.pt(String(localized: "Who waters", comment: "Screen title; max 20 chars")))
        .task { await load() }
        .refreshable { await load() }
    }

    private func name(_ id: String?, in h: ServerHousehold) -> String {
        guard let id else { return "–" }
        if id == me { return Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) }
        return h.members.first { $0.userId == id }?.displayName ?? "…"
    }

    private func act(_ f: @escaping () async throws -> Void) {
        Task {
            do { try await f(); await load() }
            catch { self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't do that right now. Try again in a moment.", comment: "Generic server action error")) }
        }
    }

    private func load() async {
        defer { loaded = true }
        guard JungleAPI.shared.hasSession else { error = Grammar.pt(String(localized: "Sign in to share the watering.", comment: "Who waters when signed out")); return }
        do {
            homes = try await HouseholdsAPI.list(); error = nil
            for h in homes { rotation[h.id] = try? await HouseholdsAPI.rotation(h.id) }
        } catch { self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't load. Pull to try again.", comment: "Generic load error")) }
    }
}
