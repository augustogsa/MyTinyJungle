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
        add("medium", plant.growingMedium.rawValue)
        if let st = plant.activeLifeStage(now) { add("lifeStage", st.rawValue) }
        add("outdoor", plant.isOutdoor || plant.growingMedium == .ground ? "true" : "false")
        if plant.potSelfWatering == true { add("potSetup", "selfWatering"); add("pot", "self-watering") }
        if plant.potCachepot == true { add("potSetup", "cachepot"); add("pot", "cachepot") }
        add("potSetup", plant.potHasDrainage ? "drainage" : "no-drainage")
        if let m = plant.potMaterialRaw { add("potSetup", "material:" + m) }
        if let f = plant.potSizeFit { add("potSetup", "sizeFit:" + f) }
        if plant.sharesPot { add("pot", "multiple-plants") }
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

/// Local weather the server used for its answer. Accepts a plain sentence or {summary|text, tMin, tMax, rain}.
nonisolated struct ServerWeather: Codable, Equatable {
    var summary: String?
    var tMin: Double?
    var tMax: Double?
    var rain: Double?
    enum K: String, CodingKey { case summary, text, tMin, tMax, rain }
    init(from d: Decoder) throws {
        if let s = try? d.singleValueContainer().decode(String.self) { summary = s; return }
        let c = try d.container(keyedBy: K.self)
        summary = (try? c.decode(String.self, forKey: .summary)) ?? (try? c.decode(String.self, forKey: .text))
        tMin = try? c.decode(Double.self, forKey: .tMin); tMax = try? c.decode(Double.self, forKey: .tMax); rain = try? c.decode(Double.self, forKey: .rain)
    }
    func encode(to e: Encoder) throws { var c = e.container(keyedBy: K.self); try c.encodeIfPresent(summary, forKey: .summary); try c.encodeIfPresent(tMin, forKey: .tMin); try c.encodeIfPresent(tMax, forKey: .tMax); try c.encodeIfPresent(rain, forKey: .rain) }
    /// One line for the UI.
    @MainActor var line: String? {
        if let s = summary, !s.isEmpty { return s }
        guard let lo = tMin, let hi = tMax else { return nil }
        let r = rain.map { $0 >= 1 ? " · " + Climate.rain($0) : "" } ?? ""
        return Grammar.pt(String(localized: "Weather where it lives: \(Climate.tempRange(lo, hi))\(r)", comment: "Line under a server answer; args temperature range and optional rain amount"))
    }
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
    nonisolated struct AskReply: Decodable { var answers: [BrainAnswer]?; var weather: ServerWeather? }

    /// Asks with `Accept: text/event-stream` and falls back to the JSON reply. `onPartial` sees answers as they stream in.
    static func ask(_ q: String, plant: Plant?, onPartial: (@MainActor ([BrainAnswer]) -> Void)? = nil) async -> [BrainAnswer] {
        guard JungleAPI.shared.hasSession else { return [] }
        nonisolated struct B: Encodable { let q, lang: String; let species: String?; let situation: [String: [String]]? }
        let sit = PlantSituation.build(plant)
        let body = B(q: q, lang: PlantSituation.lang, species: plant?.species?.scientific, situation: sit.isEmpty ? nil : sit)
        let r: AskReply?
        do {
            let partial = AskCollector()
            let s = try await JungleAPI.shared.stream("/v1/brain/ask", body: body) { e in
                guard let now = await partial.add(e) else { return }
                if let onPartial { await MainActor.run { onPartial(now) } }
            }
            switch s {
            case .json(let d): r = try JungleAPI.decoder.decode(AskReply.self, from: d)
            case .events(let es): r = Self.reply(from: es)
            }
        } catch { ServerNotice.show(error); r = nil }
        var out = r?.answers?.filter { !$0.text.isEmpty } ?? []
        if !out.isEmpty, let w = r?.weather?.line { out.append(BrainAnswer(kind: "weather", title: Grammar.pt(String(localized: "Weather", comment: "Settings section title")), text: w)) }
        return out
    }

    /// Folds stream events into one reply. Events: `answer` (one BrainAnswer), `weather` (ServerWeather),
    /// or any event whose data is a whole reply ({answers, weather}); `done` ends the stream.
    nonisolated static func reply(from events: [JungleAPI.Event]) -> AskReply {
        var r = AskReply(answers: [], weather: nil)
        let dec = JungleAPI.decoder
        for e in events where e.name != "done" && e.name != "error" {
            if e.name == "weather", let w = try? dec.decode(ServerWeather.self, from: e.data) { r.weather = w; continue }
            if let a = try? dec.decode(BrainAnswer.self, from: e.data) { r.answers?.append(a); continue }
            if let whole = try? dec.decode(AskReply.self, from: e.data), whole.answers != nil || whole.weather != nil {
                if let a = whole.answers { r.answers?.append(contentsOf: a) }
                if let w = whole.weather { r.weather = w }
            }
        }
        return r
    }

    private actor AskCollector {
        var events: [JungleAPI.Event] = []
        func add(_ e: JungleAPI.Event) -> [BrainAnswer]? {
            events.append(e)
            let a = Brain.reply(from: events).answers?.filter { !$0.text.isEmpty } ?? []
            return a.isEmpty ? nil : a
        }
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
                        Label { Text(s).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: { Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(Jungle.accentText) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous).strokeBorder(Jungle.cardEdge, lineWidth: 0.5))
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
    /// Candidates from our own model, matched to the species library. Gives up after 20 s.
    static func identify(_ photo: BrainPhoto) async -> [PlantIdentifier.Candidate] { await identifyScene(photo).candidates }

    nonisolated struct IdentifyReply: Decodable {
        nonisolated struct C: Decodable { let id: String; let scientific: String; let score: Double }
        var candidates: [C]?
        var scene: PhotoScene?
        var used: [String]?
        var tips: [ScanTip]?
        enum K: String, CodingKey { case candidates, scene, used, tips }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            candidates = try c.decodeIfPresent([C].self, forKey: .candidates)
            scene = try? c.decodeIfPresent(PhotoScene.self, forKey: .scene)
            used = try? c.decodeIfPresent([String].self, forKey: .used)
            tips = try? c.decodeIfPresent([ScanTip].self, forKey: .tips)
        }
    }
    nonisolated struct SceneReply: Decodable { var scene: PhotoScene? }

    /// One photo of a multi-photo upload: `{photo, kind}`.
    nonisolated struct PhotoPart: Encodable, Sendable { let photo, kind: String }
    nonisolated struct Identified { var candidates: [PlantIdentifier.Candidate]; var scene: PhotoScene?; var used: [ShotKind]; var tips: [ScanTip]; var timedOut = false }

    static func identifyScene(_ photo: BrainPhoto) async -> (candidates: [PlantIdentifier.Candidate], scene: PhotoScene?) {
        let r = await identify(shots: [(photo, .leaf)])
        return (r.candidates, r.scene)
    }

    /// POSTs `photos: [{photo, kind}]` (1…8); a server that answers 400 to that gets the first photo alone as `photo`.
    nonisolated static func sendPhotos<E: Encodable & Sendable>(_ path: String, many: E, single: E) async throws -> Data {
        do { return try await JungleAPI.shared.sendData("POST", path, body: many) }
        catch JungleAPI.APIError.http(400, _) { return try await JungleAPI.shared.sendData("POST", path, body: single) }
    }

    /// Candidates plus what the photos show around the plant (medium, pot, stage, faux, several plants), which kinds
    /// the server used and tips for photos that would firm it up. The scene comes inside the identify reply; only a
    /// reply without it gets a separate /v1/brain/scene call. Cached by every photo's sha256 and kind.
    static let identifyTimeout: Double = 12

    static func identify(shots: [(BrainPhoto, ShotKind)]) async -> Identified {
        guard JungleAPI.shared.hasSession, let first = shots.first?.0 else { return Identified(candidates: [], used: [], tips: []) }
        nonisolated struct B: Encodable, Sendable { var photos: [PhotoPart]?; var photo: String?; let lang: String; var sceneV = 2 }
        let lang = PlantSituation.lang
        let parts = shots.prefix(ScanPlan.cap).map { PhotoPart(photo: $0.0.base64, kind: $0.1.rawValue) }
        let key = shots.count == 1 ? BrainCache.key("identify", first.sha, lang)
            : BrainCache.key("identify-many", shots.map { "\($0.0.sha):\($0.1.rawValue)" }.joined(separator: ","), lang)
        var r: IdentifyReply? = BrainCache.get(key)
        if r == nil {
            // 12 s, then the caller shows "Taking longer than usual" with a retry instead of guessing.
            let got: IdentifyReply?? = await withTimeout(identifyTimeout) {
                do {
                    let d = try await sendPhotos("/v1/brain/identify", many: B(photos: Array(parts), lang: lang), single: B(photo: first.base64, lang: lang))
                    let r = try JungleAPI.decoder.decode(IdentifyReply.self, from: d)
                    if !(r.candidates ?? []).isEmpty { BrainCache.put(key, d) }
                    return .some(r)
                } catch { await MainActor.run { ServerNotice.show(error) }; return .some(nil) }
            }
            guard let got else { return Identified(candidates: [], used: [], tips: [], timedOut: true) }
            r = got
        }
        if let got = r, got.scene == nil, !(got.candidates ?? []).isEmpty { r?.scene = await scene(first) }
        let lib = SpeciesLibrary.shared
        let cands = (r?.candidates ?? []).compactMap { c in
            let sp = lib.species(id: c.id) ?? lib.all.first { $0.scientific.folded == c.scientific.folded }
            return sp.map { PlantIdentifier.Candidate(species: $0, confidence: c.score, source: "My Tiny Jungle") }
        }
        return Identified(candidates: cands, scene: r?.scene, used: (r?.used ?? []).map(ShotKind.init(wire:)), tips: r?.tips ?? [])
    }

    /// Fallback for a reply without `scene`.
    static func scene(_ photo: BrainPhoto) async -> PhotoScene? {
        nonisolated struct B: Encodable { let photo, lang: String }
        let lang = PlantSituation.lang
        let key = BrainCache.key("scene", photo.sha, lang)
        if let hit: SceneReply = BrainCache.get(key) { return hit.scene }
        let got: PhotoScene?? = await withTimeout(15) {
            guard let d = try? await JungleAPI.shared.sendData("POST", "/v1/brain/scene", body: B(photo: photo.base64, lang: lang)),
                  let r = try? JungleAPI.decoder.decode(SceneReply.self, from: d) else { return nil }
            if r.scene != nil { BrainCache.put(key, d) }
            return r.scene
        }
        return got ?? nil
    }

    /// First of the work or the timeout; nil on timeout.
    nonisolated static func withTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { g in
            g.addTask { await work() }
            g.addTask { try? await Task.sleep(for: .seconds(seconds)); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first
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
    var weather: ServerWeather?
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
                            Label { Text(w).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Jungle.terracotta) }
                                .foregroundStyle(Jungle.text)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Jungle.warmFill, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                        }
                        ForEach(rows(p), id: \.1) { r in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: r.0).foregroundStyle(Jungle.accentText).frame(width: 22)
                                Text(r.1).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        ForEach(p.advice ?? [], id: \.self) { a in
                            Label { Text(a).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "leaf.fill").foregroundStyle(Jungle.leaf) }
                                .foregroundStyle(Jungle.text)
                        }
                        if let w = p.weather?.line { Label(w, systemImage: "cloud.sun").font(.footnote).foregroundStyle(Jungle.subtle) }
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

/// The server's read of the photo around the plant. Every part is optional; values below 0.6 confidence are ignored.
/// What the photos show around the plant, as the server sends it: every field `{value, conf}` (value "unknown"
/// or null with conf 0 when nothing was read). Decoding never throws: an odd field only loses that field, never
/// the identify answer it rides in.
nonisolated struct PhotoScene: Decodable, Equatable {
    nonisolated struct Soil: Equatable { var medium: String?; var confidence: Double? }
    nonisolated struct PlantPart: Equatable { var artificial: Bool?; var multiple: Bool?; var lifeStage: String?; var confidence: Double?; var stageConfidence: Double? }
    nonisolated struct Pot: Equatable { var selfWatering: Bool?; var cachepot: Bool?; var drainage: Bool?; var material: String?; var sizeFit: String?; var confidence: Double? }
    nonisolated struct Outdoor: Equatable { var value: Bool?; var confidence: Double? }
    var soil: Soil?
    var plant: PlantPart?
    var pot: Pot?
    var outdoor: Outdoor?

    /// One `{value, conf}` field; a value of any JSON type, "unknown" read as nothing.
    nonisolated struct SV: Decodable, Equatable {
        var text: String?; var flag: Bool?; var conf: Double = 0
        enum K: String, CodingKey { case value, conf }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            conf = (try? c.decode(Double.self, forKey: .conf)) ?? 0
            if let b = try? c.decode(Bool.self, forKey: .value) { flag = b }
            else if let t = try? c.decode(String.self, forKey: .value), t != "unknown", !t.isEmpty {
                text = t
                if t == "yes" || t == "true" { flag = true } else if t == "no" || t == "false" { flag = false }
            }
        }
    }
    private struct Wire: Decodable {
        struct P: Decodable { var stage, artificial, multiple: SV? }
        struct Po: Decodable { var material, drainage, cachepot, rootbound: SV? }
        struct S: Decodable { var medium: SV? }
        struct R: Decodable { var room: SV? }
        var plant: P?; var pot: Po?; var soil: S?; var surroundings: R?
    }
    private struct Lenient<T: Decodable>: Decodable {
        var v: T?
        init(from d: Decoder) throws { v = try? T(from: d) }
    }

    init(soil: Soil? = nil, plant: PlantPart? = nil, pot: Pot? = nil, outdoor: Outdoor? = nil) {
        self.soil = soil; self.plant = plant; self.pot = pot; self.outdoor = outdoor
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: AnyKey.self)
        func part<T: Decodable>(_ k: String, _ t: T.Type) -> T? { (try? c.decode(Lenient<T>.self, forKey: AnyKey(k)))?.v }
        if let s = part("soil", Wire.S.self)?.medium { soil = Soil(medium: s.text, confidence: s.conf) }
        if let p = part("plant", Wire.P.self) {
            plant = PlantPart(artificial: p.artificial?.flag, multiple: p.multiple?.flag, lifeStage: p.stage?.text,
                              confidence: p.artificial?.conf, stageConfidence: p.stage?.conf)
        }
        if let p = part("pot", Wire.Po.self) {
            let confs = [p.material, p.drainage, p.cachepot].compactMap { $0?.conf }
            pot = Pot(cachepot: p.cachepot?.flag, drainage: p.drainage?.flag, material: p.material?.text,
                      sizeFit: p.rootbound?.flag == true ? "too_small" : nil, confidence: confs.max())
        }
        if let r = part("surroundings", Wire.R.self)?.room, let room = r.text {
            outdoor = Outdoor(value: room == "outdoor" || room == "balcony", confidence: r.conf)
        }
    }
    private struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    static let sure = 0.6
    @MainActor var medium: GrowingMedium? { (soil?.confidence ?? 0) >= Self.sure ? soil?.medium.flatMap(GrowingMedium.init(scene:)) : nil }
    var artificial: Bool { (plant?.confidence ?? 0) >= Self.sure && plant?.artificial == true }
    var multiple: Bool { plant?.multiple == true && (plant?.confidence ?? 0) >= Self.sure }
    @MainActor var lifeStage: LifeStage? { (plant?.stageConfidence ?? 0) >= Self.sure ? plant?.lifeStage.flatMap(LifeStage.init(scene:)) : nil }
    var potSure: Bool { (pot?.confidence ?? 0) >= Self.sure }
    var isOutdoor: Bool? { (outdoor?.confidence ?? 0) >= Self.sure ? outdoor?.value : nil }
    /// The photo clearly shows a real, living plant.
    var looksAlive: Bool { (plant?.confidence ?? 0) >= Self.sure && plant?.artificial == false }
}
