import SwiftUI
import SwiftData
import UserNotifications

/// The shared jungle brain: members, whose turn it is, cover requests, travel hand-offs,
/// the activity feed, and syncing care between phones so nobody double-waters.
@Observable @MainActor
final class Household {
    static let shared = Household()

    private(set) var state: HouseState?
    private(set) var meID: String = UserDefaults.standard.string(forKey: "house.me") ?? "me-\(UUID().uuidString.prefix(8))"
    private(set) var location: HouseholdCloud.Location?
    private(set) var syncing = false
    private(set) var lastError: String?
    /// The current single-use invite link for the invite sheet.
    var inviteURL: URL?
    static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-householdDemo") }

    private let fileURL = URL.applicationSupportDirectory.appendingPathComponent("household.json")
    private let careKinds: Set<CareKind> = [.water, .feed, .mist, .repot, .prune, .rotate, .clean, .treat]

    private init() {
        UserDefaults.standard.set(meID, forKey: "house.me")
        if let d = UserDefaults.standard.data(forKey: "house.location") { location = try? JSONDecoder().decode(HouseholdCloud.Location.self, from: d) }
        if !Self.demo, let d = try? Data(contentsOf: fileURL) { state = try? JSONDecoder().decode(HouseState.self, from: d) }
    }

    // MARK: reading

    var isShared: Bool { (state?.activeMembers.count ?? 0) > 1 }
    var active: Bool { state != nil }
    var me: Member? { state?.member(meID) }
    var isOwner: Bool { me?.role == .owner }
    var members: [Member] { state?.activeMembers ?? [] }
    var others: [Member] { members.filter { $0.id != meID } }
    func member(_ id: String?) -> Member? { state?.member(id) }
    func name(_ id: String?) -> String { id == meID ? Grammar.pt(String(localized: "You", comment: "Shared jungle: the current user, as a subject; capitalized")) : member(id)?.firstName ?? Grammar.pt(String(localized: "Someone", comment: "Shared jungle: unknown member")) }

    struct Turn: Equatable {
        enum Why { case assigned, rotation, covering, away }
        let member: Member
        let why: Why
        var isMe: Bool { member.id == Household.shared.meID }
    }

    /// Who should care for this plant next: the plan, travel and cover first, then fairness.
    func turn(for plantID: UUID, now: Date = Date()) -> Turn? {
        guard let s = state, isShared else { return nil }
        let eligible = s.activeMembers.filter { $0.canCare(now) }
        guard !eligible.isEmpty else { return nil }
        // An accepted cover beats everything while it lasts.
        if let r = s.requests.first(where: { $0.state == .accepted && $0.until > now && $0.plantIDs.contains(plantID) }),
           let c = s.member(r.coverID), !c.removed { return Turn(member: c, why: .covering) }
        if case .person(let id)? = s.plans[plantID], let m = s.member(id), !m.removed {
            if m.canCare(now) { return Turn(member: m, why: .assigned) }
            if let c = s.member(m.awayCoverID), c.canCare(now) { return Turn(member: c, why: .away) }
            return rotation(plantID, among: eligible.filter { $0.id != m.id }, s, now).map { Turn(member: $0, why: .away) }
        }
        return rotation(plantID, among: eligible, s, now).map { Turn(member: $0, why: .rotation) }
    }

    /// Not whoever did it last; then whoever has done least this month; then whoever waited longest.
    private func rotation(_ plantID: UUID, among list: [Member], _ s: HouseState, _ now: Date) -> Member? {
        guard !list.isEmpty else { return nil }
        let last = lastCare(plantID)?.memberID
        let pool = list.count > 1 ? list.filter { $0.id != last } : list
        return pool.min { a, b in
            let la = load(a.id, now), lb = load(b.id, now)
            if la != lb { return la < lb }
            let ta = lastCare(plantID, by: a.id)?.date ?? .distantPast, tb = lastCare(plantID, by: b.id)?.date ?? .distantPast
            if ta != tb { return ta < tb }
            return a.joinedAt < b.joinedAt
        }
    }

    func lastCare(_ plantID: UUID, by member: String? = nil) -> Activity? {
        state?.activity.first { $0.kind == .care && $0.plantID == plantID && (member == nil || $0.memberID == member) }
    }

    /// Care moments in the last 30 days.
    func load(_ memberID: String, _ now: Date = Date()) -> Int {
        let since = now.addingTimeInterval(-30 * 86_400)
        return state?.activity.filter { $0.kind == .care && $0.memberID == memberID && $0.date > since }.count ?? 0
    }
    /// Each member's share of the last 30 days, for the gentle balance bar.
    var balance: [(Member, Double)] {
        let loads = members.map { ($0, Double(load($0.id))) }
        let total = max(1, loads.map(\.1).reduce(0, +))
        return loads.map { ($0.0, $0.1 / total) }
    }

    /// Daily notes only go to whoever's turn it is; anyone is told if a plant has waited too long.
    func shouldRemindMe(_ plant: Plant, now: Date = Date()) -> Bool {
        guard let t = turn(for: plant.id, now: now) else { return true }
        return t.isMe || CareEngine.status(for: plant, now: now) == .struggling
    }

    var openRequestsForMe: [CoverRequest] {
        (state?.requests ?? []).filter { $0.state == .open && $0.fromID != meID && ($0.toID == nil || $0.toID == meID) && $0.until > Date() && !dismissed.contains($0.id) }
    }
    var myOpenRequests: [CoverRequest] { (state?.requests ?? []).filter { $0.state == .open && $0.fromID == meID && $0.until > Date() } }
    var coveringNow: [CoverRequest] { (state?.requests ?? []).filter { $0.state == .accepted && $0.until > Date() && ($0.coverID == meID || $0.fromID == meID) } }
    private var dismissed: Set<String> { Set(UserDefaults.standard.stringArray(forKey: "house.dismissed") ?? []) }

    // MARK: changing

    func create(kind: HouseKind, name: String, plants: [Plant]) async {
        let myName = JungleSettings.shared.ownerName.isEmpty ? Grammar.pt(String(localized: "Me", comment: "Shared jungle: fallback member name for yourself")) : JungleSettings.shared.ownerName
        if let id = HouseholdCloud.myID { adoptMeID(id) }
        var s = HouseState(name: name.isEmpty ? kind.defaultName : name, kind: kind)
        s.members = [Member(id: meID, name: myName, role: .owner, colorIndex: 0)]
        s.activity = [Activity(kind: .created, memberID: meID)]
        state = s
        roster(plants)
        persist()
        await prepareInvite()
    }

    /// Puts the jungle on the server (first time) and makes a fresh single-use invite link.
    func prepareInvite() async {
        guard let s = state, !Self.demo else { return }
        guard HouseholdCloud.available else {
            lastError = Grammar.pt(String(localized: "Sign in from Settings to invite people. Your shared jungle is ready the moment you do.", comment: "Shared jungle: invite needs an account"))
            return
        }
        do {
            if let id = HouseholdCloud.myID { adoptMeID(id) }
            let loc: HouseholdCloud.Location
            if let l = location { loc = l } else {
                loc = try await HouseholdCloud.create(state: state ?? s)
                setLocation(loc)
            }
            let until = state?.sitterInviteUntil.flatMap { $0 > Date() ? $0 : nil }
            inviteURL = try await HouseholdCloud.invite(at: loc, sitterUntil: until)
            lastError = nil
        } catch {
            lastError = Grammar.pt(String(localized: "Couldn't make an invite just now. Check your connection and try again.", comment: "Shared jungle: invite creation failed"))
        }
    }

    /// Opened from an invite link.
    func accept(code: String) async {
        guard HouseholdCloud.available else {
            UserDefaults.standard.set(code, forKey: "house.pendingInvite")
            lastError = Grammar.pt(String(localized: "Sign in from Settings to join this jungle. The invite will be waiting.", comment: "Shared jungle: joining needs an account"))
            return
        }
        do {
            let loc = try await HouseholdCloud.redeem(code: code)
            UserDefaults.standard.removeObject(forKey: "house.pendingInvite")
            if let id = HouseholdCloud.myID { adoptMeID(id) }
            if location != loc { state = nil }
            setLocation(loc)
            await sync()
            guard var s = state else { return }
            if s.member(meID) == nil || s.member(meID)?.removed == true {
                let myName = JungleSettings.shared.ownerName.isEmpty ? Grammar.pt(String(localized: "Me", comment: "Shared jungle: fallback member name for yourself")) : JungleSettings.shared.ownerName
                s.members.removeAll { $0.id == meID }
                var newbie = Member(id: meID, name: myName, colorIndex: s.members.count)
                if let u = s.sitterInviteUntil, u > Date() { newbie.sittingUntil = u; s.sitterInviteUntil = nil }
                s.members.append(newbie)
                s.activity.insert(Activity(kind: .joined, memberID: meID), at: 0)
                state = s
                await commit()
            }
            UserDefaults.standard.set(2, forKey: "selectedTab")
            UserDefaults.standard.set(true, forKey: "house.openHub")
        } catch {
            lastError = Grammar.pt(String(localized: "That invite didn't open. Ask for a fresh link.", comment: "Shared jungle: accepting invite failed"))
        }
    }

    /// An invite opened before signing in is redeemed right after.
    func redeemPendingInvite() async {
        if let code = UserDefaults.standard.string(forKey: "house.pendingInvite"), HouseholdCloud.available { await accept(code: code) }
    }

    func rename(_ name: String) { mutate { $0.name = name } }
    /// Invite mode: the next person who joins is a plant sitter until `until` (nil = a regular member).
    func setSitterInvite(_ until: Date?) { mutate { $0.sitterInviteUntil = until } }
    /// Owner turns someone into a sitter for a while, or back into a member.
    func setSitting(_ memberID: String, until: Date?) {
        mutate { s in if let i = s.members.firstIndex(where: { $0.id == memberID }) { s.members[i].sittingUntil = until } }
    }
    func setPlan(_ plantID: UUID, _ plan: CarePlan) { mutate { $0.plans[plantID] = plan == .rotate ? nil : plan } }

    /// "Can you take this one?" — to one person or to everyone.
    func askCover(plants: [UUID], to: String?, until: Date, note: String = "") {
        mutate {
            $0.requests.insert(CoverRequest(fromID: meID, toID: to, plantIDs: plants, until: until, note: note), at: 0)
            $0.activity.insert(Activity(kind: .askCover, memberID: meID, plantID: plants.first, plantName: plantName(plants.first), otherID: to), at: 0)
        }
    }
    func acceptCover(_ id: String) {
        mutate { s in
            guard let i = s.requests.firstIndex(where: { $0.id == id }), s.requests[i].state == .open else { return }
            s.requests[i].state = .accepted; s.requests[i].coverID = meID
            s.activity.insert(Activity(kind: .coverYes, memberID: meID, plantID: s.requests[i].plantIDs.first, plantName: plantName(s.requests[i].plantIDs.first), otherID: s.requests[i].fromID), at: 0)
        }
    }
    func dismissRequest(_ id: String) {
        UserDefaults.standard.set(Array(dismissed.union([id])), forKey: "house.dismissed")
        mutate { _ in }
    }
    func withdraw(_ id: String) { mutate { s in if let i = s.requests.firstIndex(where: { $0.id == id }) { s.requests[i].state = .withdrawn } } }

    /// Travel: my turns pass to one person (or fair rotation) until I'm back.
    func setAway(until: Date?, cover: String?) {
        mutate { s in
            guard let i = s.members.firstIndex(where: { $0.id == meID }) else { return }
            s.members[i].awayUntil = until; s.members[i].awayCoverID = cover
            s.activity.insert(Activity(kind: until == nil ? .back : .away, memberID: meID, otherID: cover), at: 0)
        }
    }
    func thank(_ a: Activity) {
        mutate { $0.activity.insert(Activity(kind: .thanks, memberID: meID, plantID: a.plantID, plantName: a.plantName, otherID: a.memberID), at: 0) }
    }
    func remove(_ memberID: String) {
        guard isOwner, memberID != meID else { return }
        mutate { s in
            if let i = s.members.firstIndex(where: { $0.id == memberID }) { s.members[i].removed = true }
            for (k, v) in s.plans where v == .person(memberID) { s.plans[k] = nil }
            s.activity.insert(Activity(kind: .removed, memberID: meID, otherID: memberID), at: 0)
        }
        if let loc = location { Task { await HouseholdCloud.removeParticipant(memberID, at: loc) } }
    }
    /// Leave (member) or stop sharing (owner). Plants already on this phone stay.
    func leave() async {
        if var s = state, let i = s.members.firstIndex(where: { $0.id == meID }), !isOwner {
            s.members[i].removed = true
            s.activity.insert(Activity(kind: .left, memberID: meID), at: 0)
            state = s
            await commit()
        }
        if let loc = location { await HouseholdCloud.leave(at: loc, owner: isOwner) }
        state = nil; inviteURL = nil; location = nil
        UserDefaults.standard.removeObject(forKey: "house.location")
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func mutate(_ f: (inout HouseState) -> Void) {
        guard var s = state else { return }
        f(&s); s.updatedAt = Date(); state = s
        persist()
        Task { await commit() }
    }

    // MARK: syncing care

    /// After any save: publish my new care, mirror the plant list, then pull everyone else's.
    func onLocalChange(_ ctx: ModelContext) async {
        guard var s = state else { return }
        let since = Date().addingTimeInterval(-3 * 86_400)
        let events = (try? ctx.fetch(FetchDescriptor<CareEvent>(predicate: #Predicate { $0.date > since }))) ?? []
        let known = Set(s.activity.compactMap(\.eventID))
        let mine = events.filter { careKinds.contains($0.kind) && !$0.source.hasPrefix("house:") && !known.contains($0.id) && $0.plant != nil }
        let before = s.plants
        let plants = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
        guard !mine.isEmpty || roster(plants, into: &s) != before else { return }
        for e in mine.sorted(by: { $0.date < $1.date }) {
            s.activity.insert(Activity(kind: .care, memberID: meID, date: e.date, plantID: e.plant?.id, plantName: e.plant?.name, careRaw: e.kindRaw, eventID: e.id), at: 0)
            // Doing a plant you asked someone to cover closes the ask.
            for i in s.requests.indices where s.requests[i].state == .open && s.requests[i].fromID == meID && s.requests[i].plantIDs.contains(e.plant!.id) { s.requests[i].state = .done }
        }
        s.activity.sort { $0.date > $1.date }
        s.updatedAt = Date(); state = s
        persist()
        await commit()
        await celebrateNewBadges()
    }

    func sync(_ ctx: ModelContext? = nil) async {
        guard !Self.demo, HouseholdCloud.available else { if let ctx { apply(ctx) }; return }
        guard let loc = location else {
            if let id = HouseholdCloud.myID { adoptMeID(id) }
            // A jungle made before it lived on the server (beta): the owner moves it up; members get re-invited.
            if let s = state, s.member(meID)?.role == .owner || s.members.count <= 1, let loc = try? await HouseholdCloud.create(state: s) {
                setLocation(loc)
            } else if state != nil, location == nil { state = nil; try? FileManager.default.removeItem(at: fileURL) }
            if let ctx { apply(ctx) }
            return
        }
        syncing = true; defer { syncing = false }
        let remote: HouseState?
        do { remote = try await HouseholdCloud.fetch(at: loc) }
        catch HouseholdCloud.Failure.gone {
            // The owner removed me or ended the jungle.
            state = nil; location = nil; inviteURL = nil
            UserDefaults.standard.removeObject(forKey: "house.location")
            try? FileManager.default.removeItem(at: fileURL)
            return
        } catch { return }
        guard let remote else { await commit(); return }
        let old = state
        var s = state ?? remote
        s.merge(remote)
        state = s
        persist()
        if let ctx { apply(ctx) }
        await notifyNews(old: old, new: s)
        await celebrateNewBadges()
    }

    private func commit() async {
        guard let loc = location, let s = state, !Self.demo, HouseholdCloud.available else { return }
        if let merged = try? await HouseholdCloud.save(s, at: loc) { state = merged; persist() }
    }

    /// Others' care lands in my timeline so CareEngine knows Goldie was just watered.
    func apply(_ ctx: ModelContext) {
        guard let s = state else { return }
        let all = (try? ctx.fetch(FetchDescriptor<Plant>())) ?? []
        var byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for sp in s.plants where byID[sp.id] == nil {
            let p = Plant(name: sp.name, speciesID: sp.speciesID, location: sp.location)
            p.id = sp.id; p.photo = sp.thumb
            ctx.insert(p); byID[sp.id] = p
        }
        let existing = Set(((try? ctx.fetch(FetchDescriptor<CareEvent>())) ?? []).map(\.id))
        var changed = false
        for a in s.activity where a.kind == .care && a.memberID != meID {
            guard let eid = a.eventID, !existing.contains(eid), let pid = a.plantID, let p = byID[pid], let k = a.care else { continue }
            let e = CareEvent(kind: k, date: a.date, source: "house:\(a.memberID)")
            e.id = eid; e.plant = p
            ctx.insert(e); changed = true
        }
        if changed || !s.plants.isEmpty { try? ctx.save() }
    }

    @discardableResult
    private func roster(_ plants: [Plant], into s: inout HouseState) -> [SharedPlant] {
        var map = Dictionary(uniqueKeysWithValues: s.plants.map { ($0.id, $0) })
        for p in plants {
            let thumb = map[p.id]?.thumb ?? p.photo.flatMap { BrainPhoto.encode($0, maxSide: 160, quality: 0.6) }
            map[p.id] = SharedPlant(id: p.id, name: p.name, speciesID: p.speciesID, location: p.location, thumb: thumb)
        }
        s.plants = map.values.sorted { $0.name < $1.name }
        return s.plants
    }
    private func roster(_ plants: [Plant]) { if var s = state { roster(plants, into: &s); state = s } }

    private func plantName(_ id: UUID?) -> String? { state?.plants.first { $0.id == id }?.name }

    private func adoptMeID(_ id: String) {
        guard id != meID else { return }
        if var s = state { for i in s.members.indices where s.members[i].id == meID { s.members[i].id = id }; state = s }
        meID = id; UserDefaults.standard.set(id, forKey: "house.me")
    }
    private func setLocation(_ l: HouseholdCloud.Location) {
        location = l
        UserDefaults.standard.set(try? JSONEncoder().encode(l), forKey: "house.location")
    }
    private func persist() {
        guard let s = state, !Self.demo else { return }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(s).write(to: fileURL, options: .atomic)
    }

    // MARK: notifications

    static let coverCategory = "house.cover"
    static let acceptAction = "house.accept"

    static func registerCategory() async {
        let c = UNUserNotificationCenter.current()
        var cats = await c.notificationCategories()
        let yes = UNNotificationAction(identifier: acceptAction, title: Grammar.pt(String(localized: "I've got it", comment: "Notification action: accept covering plant care; max 20 chars")), options: [], icon: .init(systemImageName: "hand.thumbsup.fill"))
        cats.insert(UNNotificationCategory(identifier: coverCategory, actions: [yes], intentIdentifiers: []))
        c.setNotificationCategories(cats)
    }

    func handleNotification(_ r: UNNotificationResponse) {
        guard r.actionIdentifier == Self.acceptAction, let id = r.notification.request.content.userInfo["request"] as? String else { return }
        acceptCover(id)
    }

    /// What changed since last look, told kindly: care by others, asks for me, yeses to my asks.
    private func notifyNews(old: HouseState?, new: HouseState) async {
        guard let old, CareReminders.enabled else { return }
        let seen = Set(old.activity.map(\.id))
        let fresh = new.activity.filter { !seen.contains($0.id) && $0.memberID != meID && $0.date > Date().addingTimeInterval(-6 * 3600) }
        for a in fresh.prefix(3) {
            let who = new.member(a.memberID)?.firstName ?? ""
            var body: String?, title = new.name, cat: String?, info: [String: Any] = [:]
            switch a.kind {
            case .care: body = HouseText.careLine(who, a.care ?? .water, a.plantName ?? "")
            case .askCover where a.otherID == nil || a.otherID == meID:
                if let r = new.requests.first(where: { $0.fromID == a.memberID && $0.state == .open }) {
                    title = Grammar.pt(String(localized: "\(who) could use a hand", comment: "Notification title: member asks for help; %@ first name"))
                    body = HouseText.askLine(r, plantName: a.plantName ?? "")
                    cat = Self.coverCategory; info["request"] = r.id
                }
            case .coverYes where a.otherID == meID: body = Grammar.pt(String(localized: "\(who) has got \(a.plantName ?? "it"). Enjoy the break.", comment: "Notification: member accepted covering; %1$@ name, %2$@ plant name"))
            case .thanks where a.otherID == meID: body = Grammar.pt(String(localized: "\(who) says thank you for caring for \(a.plantName ?? "the jungle").", comment: "Notification: thanks from member; %1$@ name, %2$@ plant"))
            case .joined: body = Grammar.pt(String(localized: "\(who) joined. Turns are now shared fairly.", comment: "Notification: new member joined the shared jungle; %@ name"))
            default: break
            }
            guard let body else { continue }
            let c = UNMutableNotificationContent()
            c.title = title; c.body = body; c.sound = .default; c.threadIdentifier = "shared-jungle"
            c.interruptionLevel = a.kind == .care ? .passive : .active
            if let cat { c.categoryIdentifier = cat }
            c.userInfo = info
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "house-\(a.id)", content: c, trigger: nil))
        }
    }

    // MARK: demo (screenshots and QA only)

    func seedDemo(_ ctx: ModelContext) {
        guard Self.demo, !ProcessInfo.processInfo.arguments.contains("-householdSetup") else { return }
        let plants = ((try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []).sorted { $0.name < $1.name }
        let me = JungleSettings.shared.ownerName.isEmpty ? "Sam" : JungleSettings.shared.ownerName
        var s = HouseState(name: Grammar.pt(String(localized: "Our jungle", comment: "Default shared jungle name for a couple; max 24 chars")), kind: .couple)
        let now = Date()
        s.members = [Member(id: meID, name: me, role: .owner, colorIndex: 0, joinedAt: now.addingTimeInterval(-90 * 86_400)),
                     Member(id: "ana", name: "Ana", colorIndex: 1, joinedAt: now.addingTimeInterval(-60 * 86_400)),
                     Member(id: "leo", name: "Leo", colorIndex: 2, joinedAt: now.addingTimeInterval(-20 * 86_400))]
        var acts: [Activity] = []
        for (i, p) in plants.enumerated() {
            for e in p.sortedEvents.prefix(6) where careKinds.contains(e.kind) {
                let who = [meID, "ana", "leo", "ana"][(i + Int(e.date.timeIntervalSince1970 / 86_400)) % 4]
                acts.append(Activity(kind: .care, memberID: who, date: e.date, plantID: p.id, plantName: p.name, careRaw: e.kindRaw, eventID: e.id))
            }
        }
        if let first = plants.first {
            acts.append(Activity(kind: .care, memberID: "ana", date: now.addingTimeInterval(-40 * 60), plantID: first.id, plantName: first.name, careRaw: CareKind.water.rawValue, eventID: UUID()))
            if plants.count > 1 { s.plans[plants[1].id] = .person("ana") }
            if plants.count > 2 {
                s.requests = [CoverRequest(fromID: "leo", toID: nil, plantIDs: [plants[2].id], until: now.addingTimeInterval(3 * 86_400), note: Grammar.pt(String(localized: "Away this weekend", comment: "Demo cover request note")))]
                acts.append(Activity(kind: .askCover, memberID: "leo", date: now.addingTimeInterval(-2 * 3600), plantID: plants[2].id, plantName: plants[2].name))
            }
        }
        // A plant sitter on duty this week, with a few visits, a cover and some thank-yous.
        var bia = Member(id: "bia", name: "Bia Costa", colorIndex: 4, joinedAt: now.addingTimeInterval(-4 * 86_400))
        bia.sittingUntil = now.addingTimeInterval(5 * 86_400)
        s.members.append(bia)
        for (d, p) in plants.prefix(4).enumerated() {
            acts.append(Activity(kind: .care, memberID: "bia", date: now.addingTimeInterval(-Double(d + 1) * 86_400 + 3600), plantID: p.id, plantName: p.name, careRaw: CareKind.water.rawValue))
        }
        if let p = plants.first {
            acts.append(Activity(kind: .thanks, memberID: meID, date: now.addingTimeInterval(-86_400), plantID: p.id, plantName: p.name, otherID: "bia"))
            acts.append(Activity(kind: .coverYes, memberID: meID, date: now.addingTimeInterval(-9 * 86_400), plantID: p.id, plantName: p.name, otherID: "ana"))
            acts.append(Activity(kind: .thanks, memberID: "ana", date: now.addingTimeInterval(-9 * 86_400 + 3600), plantID: p.id, plantName: p.name, otherID: meID))
        }
        acts.append(Activity(kind: .joined, memberID: "bia", date: bia.joinedAt))
        acts.append(Activity(kind: .joined, memberID: "leo", date: s.members[2].joinedAt))
        acts.append(Activity(kind: .joined, memberID: "ana", date: s.members[1].joinedAt))
        s.activity = acts.sorted { $0.date > $1.date }
        state = s
        roster(plants)
        persist()
    }
}

/// Warm, blame-free lines used by cards, the feed and notifications.
enum HouseText {
    static func careLine(_ who: String, _ k: CareKind, _ plant: String, recent: Bool = true) -> String {
        switch k {
        case .water where !recent: Grammar.pt(String(localized: "\(who) watered \(plant).", comment: "Shared jungle feed, older entry; %1$@ member name, %2$@ plant name"))
        case .water: Grammar.pt(String(localized: "\(who) just watered \(plant).", comment: "Shared jungle feed/notification; %1$@ member name, %2$@ plant name"))
        case .feed: Grammar.pt(String(localized: "\(who) fed \(plant).", comment: "Shared jungle feed; %1$@ member, %2$@ plant"))
        case .mist: Grammar.pt(String(localized: "\(who) misted \(plant).", comment: "Shared jungle feed; %1$@ member, %2$@ plant"))
        case .repot: Grammar.pt(String(localized: "\(who) repotted \(plant).", comment: "Shared jungle feed; %1$@ member, %2$@ plant"))
        default: Grammar.pt(String(localized: "\(who) cared for \(plant).", comment: "Shared jungle feed, generic care; %1$@ member, %2$@ plant"))
        }
    }
    static func askLine(_ r: CoverRequest, plantName: String) -> String {
        let day = r.until.formatted(.dateTime.weekday(.wide))
        return r.plantIDs.count > 1
            ? Grammar.pt(String(localized: "Could you look after \(r.plantIDs.count) plants until \(day)?", comment: "Cover request text; %1$lld plant count, %2$@ weekday"))
            : Grammar.pt(String(localized: "Could you look after \(plantName) until \(day)?", comment: "Cover request text; %1$@ plant name, %2$@ weekday"))
    }
    static func turnLabel(_ t: Household.Turn) -> String {
        if t.isMe {
            return t.why == .covering ? Grammar.pt(String(localized: "You're covering", comment: "Turn pill; short, max 18 chars")) : Grammar.pt(String(localized: "Your turn", comment: "Turn pill: it's your turn to care; max 18 chars"))
        }
        let n = t.member.firstName
        return t.why == .covering ? Grammar.pt(String(localized: "\(n) is covering", comment: "Turn pill; %@ first name")) : Grammar.pt(String(localized: "\(n)'s turn", comment: "Turn pill: it's this person's turn; %@ first name"))
    }
    static func feed(_ a: Activity, _ h: Household) -> String {
        let who = h.name(a.memberID), other = h.name(a.otherID)
        let plant = a.plantName ?? ""
        switch a.kind {
        case .care: return careLine(who, a.care ?? .water, plant, recent: a.date > Date().addingTimeInterval(-6 * 3600))
        case .joined where h.member(a.memberID)?.isSitter == true: return Grammar.pt(String(localized: "\(who) joined as plant sitter.", comment: "Feed: plant sitter joined; %@ name"))
        case .joined: return Grammar.pt(String(localized: "\(who) joined the jungle.", comment: "Feed: member joined; %@ name"))
        case .left: return Grammar.pt(String(localized: "\(who) left the jungle.", comment: "Feed: member left; %@ name"))
        case .removed: return Grammar.pt(String(localized: "\(other) is no longer in the jungle.", comment: "Feed: member removed by owner; %@ name. Neutral, no blame"))
        case .askCover: return a.otherID == nil ? Grammar.pt(String(localized: "\(who) asked for a hand with \(plant).", comment: "Feed: cover request to everyone; %1$@ name, %2$@ plant")) : Grammar.pt(String(localized: "\(who) asked \(other) to take \(plant).", comment: "Feed: cover request to one member; %1$@ name, %2$@ other name, %3$@ plant"))
        case .coverYes: return Grammar.pt(String(localized: "\(who) is covering \(plant) for \(other).", comment: "Feed: member accepted cover; %1$@ name, %2$@ plant, %3$@ other name"))
        case .away: return a.otherID == nil ? Grammar.pt(String(localized: "\(who) is away. Turns are shared meanwhile.", comment: "Feed: member travelling; %@ name")) : Grammar.pt(String(localized: "\(who) is away. \(other) is covering.", comment: "Feed: member travelling, other covers; %1$@ name, %2$@ cover name"))
        case .back: return Grammar.pt(String(localized: "\(who) is back home.", comment: "Feed: member back from trip; %@ name"))
        case .thanks: return Grammar.pt(String(localized: "\(who) thanked \(other) for \(plant).", comment: "Feed: thanks; %1$@ name, %2$@ other, %3$@ plant"))
        case .created: return Grammar.pt(String(localized: "\(who) started the shared jungle.", comment: "Feed: jungle created; %@ name"))
        }
    }
}
