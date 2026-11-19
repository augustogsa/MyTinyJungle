import SwiftUI
import SwiftData
import CoreLocation
import UserNotifications

/// What the app already knows about a plant's spot and recent care, in the server's situation vocabulary.
@MainActor
enum PlantSituation {
    static var lang: String { Bundle.main.preferredLocalizations.first ?? "en" }

    static func build(_ plant: Plant?, now: Date = Date()) -> [String: [String]] {
        let c = Climate.shared
        var s: [String: [String]] = [:]
        func add(_ k: String, _ v: String) { if !(s[k]?.contains(v) ?? false) { s[k, default: []].append(v) } }

        let winter = c.isWinter(now), summer = c.isPeakSummer(now)
        if c.heating && winter { add("room", "heater") }
        if c.aircon && summer { add("room", "aircon") }
        if c.drafts { add("room", "draft") }
        switch c.homeAir { case .dry: add("humidity", "low"); case .humid: add("humidity", "high"); default: break }
        if let t = c.forecast.first { if t.tMin <= 3 { add("temp", "cold") } else if t.tMax >= 32 { add("temp", "hot") } }

        guard let plant else { return s }
        let space = space(for: plant)
        let place = ((space?.name ?? "") + " " + plant.location).folded
        func has(_ words: [String]) -> Bool { words.contains { place.contains($0) } }
        if plant.isOutdoor || space?.isOutdoor == true { add("room", "outdoor") }
        if has(["balcon", "varanda", "sacada", "balkon", "terrace", "terraco", "terrasse", "ベランダ", "バルコニー"]) { add("room", "balcony") }
        if has(["bathroom", "banheiro", "bano", "salle de bain", "badezimmer", "浴室", "お風呂", "風呂"]) { add("room", "bathroom") }
        if has(["kitchen", "cozinha", "cocina", "cuisine", "kuche", "キッチン", "台所"]) { add("room", "kitchen") }
        if has(["office", "escritorio", "oficina", "bureau", "buro", "arbeitszimmer", "書斎", "オフィス"]) { add("room", "office") }
        if let space {
            switch space.light { case .low: add("room", "dark"); add("light", "low"); case .direct: add("light", "high"); default: break }
            switch space.windowFacing { case "South": add("room", "window-south"); case "North": add("room", "window-north"); default: break }
        }

        let ev = plant.sortedEvents
        func days(_ k: CareKind) -> Double? { ev.first { $0.kind == k }.map { now.timeIntervalSince($0.date) / 86_400 } }
        if let w = days(.water) { if w <= 2 { add("watered", "recent") } else if w >= 21 { add("watered", "long-ago") } }
        if let soil = ev.first(where: { $0.soil != nil })?.soil, let d = days(.soilCheck), d <= 3 { add("soil", soil.rawValue) }
        if !plant.potHasDrainage { add("pot", "no-drainage") }
        switch plant.potMaterial { case .terracotta: add("pot", "terracotta"); case .plastic: add("pot", "plastic"); default: break }
        if let d = plant.lastRepotAt.map({ now.timeIntervalSince($0) / 86_400 }) ?? days(.repot), d <= 21 { add("event", "repotted") }
        if let d = days(.move), d <= 14 { add("event", "moved") }
        if now.timeIntervalSince(plant.acquiredAt) / 86_400 <= 21 { add("event", "new-plant") }
        if let d = days(.feed), d <= 7 { add("event", "fertilized") }
        if let d = days(.propagate), d <= 30 { add("event", "propagated") }
        return s
    }

    private static func space(for plant: Plant) -> Space? {
        guard !plant.location.isEmpty, let ctx = plant.modelContext else { return nil }
        let name = plant.location.folded
        return ((try? ctx.fetch(FetchDescriptor<Space>())) ?? []).first { $0.name.folded == name }
    }

    /// Rounded coordinates, only when location permission was already granted. Never asks.
    static var coords: (lat: Double, lon: Double)? {
        let st = CLLocationManager().authorizationStatus
        guard st == .authorizedWhenInUse || st == .authorizedAlways, let p = Climate.shared.profile else { return nil }
        return (round1(p.lat), round1(p.lon))
    }
    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

/// Server "brain": answers from its own knowledge, free for signed-in users.
nonisolated struct BrainAnswer: Codable, Equatable, Hashable {
    var kind: String
    var title: String
    var text: String
    var steps: [String]?
}

nonisolated struct BrainCard: Codable, Equatable {
    var brain: [BrainAnswer]
}

extension ChatMessage {
    var brainAnswers: [BrainAnswer] {
        guard cardRaw.hasPrefix("{\"brain\"") else { return [] }
        return (try? JSONDecoder().decode(BrainCard.self, from: Data(cardRaw.utf8)))?.brain ?? []
    }
}

@MainActor
enum Brain {
    static func ask(_ q: String, plant: Plant?) async -> [BrainAnswer] {
        guard JungleAPI.shared.hasSession else { return [] }
        nonisolated struct B: Encodable { let q, lang: String; let species: String?; let situation: [String: [String]]? }
        nonisolated struct R: Decodable { let answers: [BrainAnswer] }
        let sit = PlantSituation.build(plant)
        let body = B(q: q, lang: PlantSituation.lang, species: plant?.species?.scientific, situation: sit.isEmpty ? nil : sit)
        let r: R? = try? await JungleAPI.shared.send("POST", "/v1/brain/ask", body: body)
        return r?.answers.filter { !$0.text.isEmpty } ?? []
    }

    static func feedback(ref: String, helped: Bool) async {
        nonisolated struct B: Encodable { let ref: String; let helped: Bool }
        nonisolated struct Empty: Decodable {}
        let _: Empty? = try? await JungleAPI.shared.send("POST", "/v1/diagnose/feedback", body: B(ref: ref, helped: helped))
    }

    /// Reply in a chat with answer cards.
    static func replyCards(_ answers: [BrainAnswer], plant: Plant?, in ctx: ModelContext, alsoJungle: Bool) {
        func make(_ p: Plant?) -> ChatMessage {
            let m = ChatMessage(text: "", fromUser: false, plant: p)
            m.cardRaw = (try? String(data: JSONEncoder().encode(BrainCard(brain: answers)), encoding: .utf8)) ?? ""
            return m
        }
        ctx.insert(make(plant))
        if alsoJungle, let plant { let m = make(nil); m.speakerID = plant.id; ctx.insert(m) }
    }
}

struct BrainAnswerCards: View {
    let answers: [BrainAnswer]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(answers, id: \.self) { a in
                VStack(alignment: .leading, spacing: 6) {
                    if !a.title.isEmpty { Text(a.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text) }
                    Text(a.text).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                    ForEach(Array((a.steps ?? []).enumerated()), id: \.offset) { i, s in
                        Label { Text(s).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: { Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(Jungle.forest) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
            }
        }
        .textSelection(.enabled)
    }
}

/// Frost & heatwave push alerts for the user's rough area.
@MainActor
enum WeatherWatch {
    private static let d = UserDefaults.standard
    static var isOn: Bool { d.bool(forKey: "weatherWatch.on") }

    /// Turns alerts on/off. Asks for when-in-use location once when turning on. Returns the resulting state.
    @discardableResult static func set(_ on: Bool) async -> Bool {
        if on {
            var lat = d.object(forKey: "weatherWatch.lat") as? Double, lon = d.object(forKey: "weatherWatch.lon") as? Double
            if let l = await LocationOnce.shared.request() { lat = l.coordinate.latitude; lon = l.coordinate.longitude }
            else if lat == nil, let p = Climate.shared.profile { lat = p.lat; lon = p.lon }
            guard let lat, let lon else { return false }
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            d.set(PlantSituation.round1(lat), forKey: "weatherWatch.lat"); d.set(PlantSituation.round1(lon), forKey: "weatherWatch.lon")
        }
        d.set(on, forKey: "weatherWatch.on")
        d.set(true, forKey: "weatherWatch.pending")
        await sync()
        return on
    }

    /// Sends the current choice when signed in; retried on next launch if it couldn't go out.
    static func sync() async {
        guard d.bool(forKey: "weatherWatch.pending"), JungleAPI.shared.hasSession else { return }
        nonisolated struct B: Encodable { let lat, lon: Double; let lang: String; let on: Bool; let deviceId: String }
        nonisolated struct Empty: Decodable {}
        let b = B(lat: d.double(forKey: "weatherWatch.lat"), lon: d.double(forKey: "weatherWatch.lon"), lang: PlantSituation.lang, on: isOn, deviceId: JungleAPI.deviceID)
        do {
            let _: Empty? = try await JungleAPI.shared.send("PUT", "/v1/me/weather-watch", body: b)
            d.set(false, forKey: "weatherWatch.pending")
        } catch is JungleAPI.APIError {
            // offline or refused: retry on next launch
        } catch {
            d.set(false, forKey: "weatherWatch.pending")   // 2xx with an empty body
        }
    }
}

// MARK: - Identify from photo (our own model)

extension Brain {
    /// Candidates from our own model, matched to the species library. Gives up after 15 s.
    static func identify(_ jpeg: Data) async -> [PlantIdentifier.Candidate] {
        guard JungleAPI.shared.hasSession else { return [] }
        nonisolated struct B: Encodable { let photo, lang: String }
        nonisolated struct C: Decodable { let id: String; let scientific: String; let score: Double }
        nonisolated struct R: Decodable { let candidates: [C]? }
        let body = B(photo: jpeg.base64EncodedString(), lang: PlantSituation.lang)
        let r: R? = await withTaskGroup(of: R?.self) { g in
            g.addTask { try? await JungleAPI.shared.send("POST", "/v1/brain/identify", body: body) }
            g.addTask { try? await Task.sleep(for: .seconds(15)); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first
        }
        let lib = SpeciesLibrary.shared
        return (r?.candidates ?? []).compactMap { c in
            let sp = lib.species(id: c.id) ?? lib.all.first { $0.scientific.folded == c.scientific.folded }
            return sp.map { PlantIdentifier.Candidate(species: $0, confidence: c.score, source: "My Tiny Jungle") }
        }
    }
}

// MARK: - Care plan for where it lives

nonisolated struct BrainCarePlan: Codable, Equatable {
    var waterEveryDays: [Double]?
    var feedEveryWeeks: Double?
    var light: String?
    var humidityMin: Double?
    var tempRange: [Double]?
    var mix: String?
    var repotEveryYears: Double?
    var toxicCats: Bool?
    var toxicDogs: Bool?
    var tip: String?
    var warnings: [String]?
    var advice: [String]?
}

@MainActor
enum CarePlans {
    nonisolated struct Cached: Codable { let key: String; let at: Date; let plan: BrainCarePlan }

    static func key(_ plant: Plant) -> String {
        let sit = PlantSituation.build(plant).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.joined(separator: ","))" }.joined(separator: ";")
        return "\(plant.speciesID ?? plant.species?.scientific ?? "")|\(plant.location)|\(sit)|\(PlantSituation.lang)"
    }

    static func cached(_ plant: Plant) -> Cached? {
        guard let d = UserDefaults.standard.data(forKey: "carePlan.\(plant.id)") else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: d)
    }

    /// Cached plan, refreshed weekly or when the plant's room/situation changes.
    static func load(_ plant: Plant) async -> BrainCarePlan? {
        let k = key(plant), old = cached(plant)
        if let old, old.key == k, Date().timeIntervalSince(old.at) < 7 * 86_400 { return old.plan }
        guard JungleAPI.shared.hasSession, let species = plant.speciesID ?? plant.species?.scientific else { return old?.plan }
        nonisolated struct B: Encodable { let species, lang: String; let situation: [String: [String]]?; let lat, lon: Double? }
        let sit = PlantSituation.build(plant), at = PlantSituation.coords
        let body = B(species: species, lang: PlantSituation.lang, situation: sit.isEmpty ? nil : sit, lat: at?.lat, lon: at?.lon)
        guard let plan: BrainCarePlan = try? await JungleAPI.shared.send("POST", "/v1/brain/care-plan", body: body) else { return old?.plan }
        if let d = try? JSONEncoder().encode(Cached(key: k, at: Date(), plan: plan)) { UserDefaults.standard.set(d, forKey: "carePlan.\(plant.id)") }
        return plan
    }
}

struct CarePlanCard: View {
    let plant: Plant
    @State private var plan: BrainCarePlan?

    var body: some View {
        Group {
            if let p = plan {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(Grammar.pt(String(localized: "Care plan for where it lives", comment: "Plant screen section title: care plan adapted to the plant's room and climate; max 32 chars")))
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(p.warnings ?? [], id: \.self) { w in
                            Label { Text(w).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                                .foregroundStyle(Jungle.text)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                        }
                        ForEach(rows(p), id: \.1) { r in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: r.0).foregroundStyle(Jungle.forest).frame(width: 22)
                                Text(r.1).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        ForEach(p.advice ?? [], id: \.self) { a in
                            Label { Text(a).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "leaf.fill").foregroundStyle(Jungle.leaf) }
                                .foregroundStyle(Jungle.text)
                        }
                        if let t = p.tip, !t.isEmpty { Text(t).font(.footnote).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true) }
                    }
                    .padding(14).jungleCard()
                }
            }
        }
        .task(id: CarePlans.key(plant)) {
            if plan == nil { plan = CarePlans.cached(plant)?.plan }
            if let fresh = await CarePlans.load(plant) { plan = fresh }
        }
    }

    private func rows(_ p: BrainCarePlan) -> [(String, String)] {
        var out: [(String, String)] = []
        if let w = p.waterEveryDays, w.count == 2 {
            let lo = Int(w[0]), hi = Int(w[1])
            out.append(("drop.fill", lo == hi ? Grammar.pt(String(localized: "Water about every \(lo) days", comment: "Care plan row; arg days"))
                                              : Grammar.pt(String(localized: "Water every \(lo)–\(hi) days", comment: "Care plan row; args min and max days"))))
        }
        if let f = p.feedEveryWeeks {
            out.append(("leaf.arrow.triangle.circlepath", f <= 0 ? Grammar.pt(String(localized: "No feeding for now, it's resting", comment: "Care plan row: no fertilizer this season"))
                                                               : Grammar.pt(String(localized: "Feed every \(Int(f)) weeks", comment: "Care plan row; arg weeks"))))
        }
        if let l = p.light, !l.isEmpty { out.append(("sun.max.fill", l)) }
        if let h = p.humidityMin, h > 0 { out.append(("humidity.fill", Grammar.pt(String(localized: "Humidity at least \(Int(h))%", comment: "Care plan row; arg percent")))) }
        if let t = p.tempRange, t.count == 2 { out.append(("thermometer.medium", Climate.tempRange(t[0], t[1]))) }
        if let m = p.mix, !m.isEmpty { out.append(("square.stack.3d.down.right", m)) }
        if let r = p.repotEveryYears, r > 0 { out.append(("arrow.up.bin.fill", Grammar.pt(String(localized: "Repot every \(Int(r.rounded())) years", comment: "Care plan row; arg years")))) }
        if p.toxicCats == true || p.toxicDogs == true {
            out.append(("pawprint.fill", Grammar.pt(String(localized: "Keep away from pets", comment: "Care plan row: toxic to cats or dogs"))))
        }
        return out
    }
}
