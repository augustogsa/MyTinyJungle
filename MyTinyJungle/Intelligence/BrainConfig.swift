import Foundation
import os
import SwiftUI

/// The brain's tunables from GET /v1/brain/config: thresholds, timeouts, scan plan, copy overrides, flags, cards and
/// experiments. Every field is optional; a missing one means the bundled default below. Improving the brain is a
/// server change, never a build.
nonisolated struct BrainConfig: Codable, Equatable, Sendable {
    struct Scene: Codable, Equatable, Sendable { var sure: Double?; var timeoutS: Double? }
    struct Band: Codable, Equatable, Sendable { var id: String?; var min: Double; var tone: String?; var word: String? }
    struct Identify: Codable, Equatable, Sendable {
        var timeoutS, remoteTimeoutS, minRevealS: Double?
        var maxCandidates, maxTips: Int?
        var onDeviceCandidates: Bool?
        var bands: [Band]?
    }
    struct Diagnose: Codable, Equatable, Sendable { var maxTips: Int? }
    struct Ask: Codable, Equatable, Sendable { var server, feedback: Bool? }
    struct Plan: Codable, Equatable, Sendable { var order: [String]?; var weights: [String: Double]?; var other: Double? }
    struct Step: Codable, Equatable, Sendable { var icon: String?; var title: String; var text: String? }
    struct Scan: Codable, Equatable, Sendable {
        var cap: Int?
        var usefulMin, repeatBonus, floor: Double?
        var plans: [String: Plan]?
        var howTo: [Step]?
        var hints: [String: String]?
    }
    struct Action: Codable, Equatable, Hashable, Sendable { var label: String; var link: String }
    /// A generic card: the app draws any of these, so a new tip or notice needs no build.
    struct Card: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var surface: String?
        var icon: String?
        var title: String?
        var body: String?
        var chips: [String]?
        var actions: [Action]?
        var link: String?
    }

    var v: Int?
    var scene: Scene?
    var identify: Identify?
    var diagnose: Diagnose?
    var ask: Ask?
    var scan: Scan?
    var flags: [String: Bool]?
    var cards: [Card]?
    var experiments: [String: String]?
}

/// The config in force: last server copy (kept across launches), else bundled defaults. Readable from any thread.
nonisolated enum BrainTuning {
    static let changed = Notification.Name("BrainTuning.changed")
    private static let d = UserDefaults.standard
    private static let state = OSAllocatedUnfairLock<BrainConfig>(initialState: cached() ?? BrainConfig())

    static var current: BrainConfig { state.withLock { $0 } }

    static func adopt(_ c: BrainConfig) {
        let old = state.withLock { s -> BrainConfig in let o = s; s = c; return o }
        if old != c { NotificationCenter.default.post(name: changed, object: nil) }
    }

    private static func cached() -> BrainConfig? {
        d.data(forKey: "brainConfig.json").flatMap { try? JSONDecoder().decode(BrainConfig.self, from: $0) }
    }

    /// GET with If-None-Match; 304 keeps what we have. Offline or a bad reply keeps the last copy.
    static func refresh() async {
        let lang = await MainActor.run { PlantSituation.lang }
        let tag = d.string(forKey: "brainConfig.lang") == lang ? d.string(forKey: "brainConfig.etag") : nil
        guard let (code, data, etag) = try? await JungleAPI.shared.getConditional("/v1/brain/config", query: [URLQueryItem(name: "lang", value: lang)], etag: tag) else { return }
        guard code == 200, let c = try? JSONDecoder().decode(BrainConfig.self, from: data) else { return }
        d.set(data, forKey: "brainConfig.json"); d.set(etag, forKey: "brainConfig.etag"); d.set(lang, forKey: "brainConfig.lang")
        adopt(c)
    }

    // MARK: Tunables with their bundled defaults

    static var sceneSure: Double { current.scene?.sure ?? 0.6 }
    static var sceneTimeout: Double { current.scene?.timeoutS ?? 15 }
    static var identifyTimeout: Double { current.identify?.timeoutS ?? 12 }
    static var remoteTimeout: Double { current.identify?.remoteTimeoutS ?? 12 }
    static var minReveal: Double { current.identify?.minRevealS ?? 1.6 }
    static var maxCandidates: Int { max(1, current.identify?.maxCandidates ?? 3) }
    static var identifyTips: Int { max(0, current.identify?.maxTips ?? 3) }
    static var doctorTips: Int { max(0, current.diagnose?.maxTips ?? 3) }
    static var onDeviceCandidates: Bool { current.identify?.onDeviceCandidates ?? true }
    static var askServer: Bool { current.ask?.server ?? true }
    static var askFeedback: Bool { current.ask?.feedback ?? true }
    static func flag(_ name: String) -> Bool { current.flags?[name] ?? true }

    static var bands: [BrainConfig.Band] { bands(in: current) }

    static func bands(in cfg: BrainConfig) -> [BrainConfig.Band] {
        let b = (cfg.identify?.bands ?? []).sorted { $0.min > $1.min }
        return b.isEmpty ? [.init(id: "veryLikely", min: 0.8, tone: "good"), .init(id: "likely", min: 0.5, tone: "good"), .init(id: "couldBe", min: 0, tone: "warn")] : b
    }

    /// The band a match confidence falls in (the lowest one when below them all).
    static func band(_ c: Double, in cfg: BrainConfig = current) -> BrainConfig.Band {
        let b = bands(in: cfg)
        return b.first { c >= $0.min } ?? b[b.count - 1]
    }

    static var scanCap: Int { min(12, max(1, current.scan?.cap ?? 8)) }
    static var usefulMin: Double { current.scan?.usefulMin ?? 0.1 }
    static var repeatBonus: Double { current.scan?.repeatBonus ?? 0.04 }
    static var sureFloor: Double { current.scan?.floor ?? 0.2 }
    static func hint(_ kind: String) -> String? { current.scan?.hints?[kind].flatMap { $0.isEmpty ? nil : $0 } }
    static var howTo: [BrainConfig.Step] { current.scan?.howTo ?? [] }
    static func cards(_ surface: String, in cfg: BrainConfig = current) -> [BrainConfig.Card] { (cfg.cards ?? []).filter { ($0.surface ?? "today") == surface } }
}

extension BrainConfig.Band {
    /// Plain words for the band: the server's word, else ours for its id, else ours for its tone.
    @MainActor var words: String {
        if let word, !word.isEmpty { return word }
        switch id {
        case "veryLikely": return Grammar.pt(String(localized: "Very likely", comment: "Species match confidence in plain words; max 16 chars"))
        case "likely": return Grammar.pt(String(localized: "Likely", comment: "Species match confidence in plain words; max 16 chars"))
        case "couldBe": return Grammar.pt(String(localized: "Could be", comment: "Species match confidence in plain words: low; max 16 chars"))
        default: return tone == "good" ? Grammar.pt(String(localized: "Likely", comment: "Species match confidence in plain words; max 16 chars"))
            : Grammar.pt(String(localized: "Could be", comment: "Species match confidence in plain words: low; max 16 chars"))
        }
    }
    @MainActor var color: Color { tone == "good" ? Jungle.leaf : Jungle.sun }
}

// MARK: - Server cards

/// Cards the server puts on a surface ("today", "scan"): title, body, chips, buttons and a deep link.
struct ServerCards: View {
    let surface: String
    var onChip: (String) -> Void = { _ in }
    @State private var cards: [BrainConfig.Card] = []
    @AppStorage("serverCards.hidden") private var hiddenRaw = ""

    var body: some View {
        let shown = cards.filter { !hiddenRaw.split(separator: ",").contains(Substring($0.id)) }
        VStack(spacing: 10) {
            ForEach(shown) { c in ServerCardView(card: c, onChip: onChip) { hiddenRaw = (hiddenRaw.isEmpty ? "" : hiddenRaw + ",") + c.id } }
        }
        .onAppear { cards = BrainTuning.cards(surface) }
        .onReceive(NotificationCenter.default.publisher(for: BrainTuning.changed).receive(on: RunLoop.main)) { _ in cards = BrainTuning.cards(surface) }
    }
}

struct ServerCardView: View {
    let card: BrainConfig.Card
    var onChip: (String) -> Void = { _ in }
    var onClose: (() -> Void)?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if let icon = card.icon, UIImage(systemName: icon) != nil { Image(systemName: icon).font(.title3).foregroundStyle(Jungle.leaf).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 4) {
                    if let t = card.title, !t.isEmpty { Text(t).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text) }
                    if let b = card.body, !b.isEmpty { Text(b).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Jungle.subtle).frame(width: 28, height: 28) }
                        .accessibilityLabel(Grammar.pt(String(localized: "Close", comment: "VoiceOver: close button")))
                }
            }
            CardButtons(chips: card.chips ?? [], actions: card.actions ?? [], onChip: onChip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).jungleCard()
        .contentShape(Rectangle())
        .onTapGesture { if let l = card.link, let u = URL(string: l) { openURL(u) } }
    }
}

/// Follow-up chips (asked on tap) and deep-link buttons, shared by server cards and brain answers.
struct CardButtons: View {
    let chips: [String]
    let actions: [BrainConfig.Action]
    var onChip: (String) -> Void = { _ in }
    @Environment(\.openURL) private var openURL

    var body: some View {
        if !chips.isEmpty || !actions.isEmpty {
            CenteredFlow(spacing: 8) {
                ForEach(actions, id: \.self) { a in
                    Button(a.label) { if let u = URL(string: a.link) { openURL(u) } }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.small).tint(Jungle.tint)
                }
                ForEach(chips, id: \.self) { c in
                    Button(c) { onChip(c) }.buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                }
            }
        }
    }
}
