import SwiftUI

/// Weekly digest from the server: what's due, what to watch, what grew, the week's photos.
nonisolated struct Digest: Decodable, Equatable {
    nonisolated struct Item: Decodable, Equatable, Identifiable {
        var kind: String
        var plantId: String?
        var plant: String?
        var date: Date?
        var overdue: Bool?
        var title: String?
        var value: Double?
        var eventId: String?
        var media: String?
        var id: String { [kind, plantId ?? "", eventId ?? "", title ?? "", date.map { "\($0.timeIntervalSince1970)" } ?? ""].joined(separator: "|") }
    }
    var week: String?
    var due: [Item]
    var watch: [Item]
    var grew: [Item]
    var photos: [Item]

    enum CodingKeys: String, CodingKey { case week, due, watch, grew, photos }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        week = (try? c.decode(String.self, forKey: .week)) ?? (try? c.decode(Int.self, forKey: .week)).map(String.init)
        due = (try? c.decode([Item].self, forKey: .due)) ?? []
        watch = (try? c.decode([Item].self, forKey: .watch)) ?? []
        grew = (try? c.decode([Item].self, forKey: .grew)) ?? []
        photos = (try? c.decode([Item].self, forKey: .photos)) ?? []
    }
    var isEmpty: Bool { due.isEmpty && watch.isEmpty && grew.isEmpty && photos.isEmpty }
}

@MainActor
enum DigestAPI {
    static let onKey = "weeklyDigest"
    static let openKey = "openDigest"
    static var isOn: Bool { UserDefaults.standard.object(forKey: onKey) as? Bool ?? true }

    static func load() async throws -> Digest { try await JungleAPI.shared.get("/v1/me/digest") }

    @discardableResult static func set(_ on: Bool) async -> Bool {
        UserDefaults.standard.set(on, forKey: onKey)
        guard JungleAPI.shared.hasSession else { return on }
        nonisolated struct B: Encodable { let on: Bool; let deviceId: String; let lang: String }
        nonisolated struct Empty: Decodable {}
        let _: Empty? = try? await JungleAPI.shared.send("PUT", "/v1/me/digest", body: B(on: on, deviceId: JungleAPI.deviceID, lang: PlantSituation.lang))
        return on
    }

    /// Tell the server once per launch (default on), so the weekly push reaches this device.
    static func sync() async { await set(isOn) }

    /// mytinyjungle://digest, from the weekly push or a link.
    @discardableResult static func handle(_ url: URL) -> Bool {
        guard url.scheme == "mytinyjungle", url.host() == "digest" || url.path().contains("digest") else { return false }
        UserDefaults.standard.set(true, forKey: openKey)
        return true
    }
}

/// Opens the digest over everything when a digest link arrives.
struct DigestLinkSheet: ViewModifier {
    @AppStorage(DigestAPI.openKey) private var open = false
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .onChange(of: open, initial: true) { _, o in if o { shown = true; open = false } }
            .sheet(isPresented: $shown) { NavigationStack { DigestView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { shown = false } } } } }
    }
}

struct DigestView: View {
    @State private var digest: Digest?
    @State private var failed: String?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if loading && digest == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let failed {
                    message(failed)
                } else if let d = digest {
                    if d.isEmpty {
                        message(Grammar.pt(String(localized: "A quiet week. Log some care and next week's digest will fill up.", comment: "Weekly digest empty state")))
                    }
                    section(Grammar.pt(String(localized: "Coming up", comment: "Weekly digest section: care due; max 24 chars")), d.due, symbol: "calendar")
                    section(Grammar.pt(String(localized: "Keep an eye on", comment: "Weekly digest section: plants to watch; max 24 chars")), d.watch, symbol: "eye")
                    section(Grammar.pt(String(localized: "Look who grew", comment: "Weekly digest section: growth moments; max 24 chars")), d.grew, symbol: "leaf.fill")
                    if !d.photos.isEmpty {
                        SectionTitle(Grammar.pt(String(localized: "Photos of the week", comment: "Weekly digest section; max 24 chars")))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(d.photos) { p in DigestPhoto(item: p) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .jungleBackdrop()
        .navigationTitle(Grammar.pt(String(localized: "Your week", comment: "Weekly digest screen title; max 20 chars")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        guard JungleAPI.shared.hasSession else { failed = Grammar.pt(String(localized: "Sign in to get your weekly digest.", comment: "Weekly digest when signed out")); return }
        do { digest = try await DigestAPI.load(); failed = nil }
        catch { failed = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't load your week. Pull to try again.", comment: "Weekly digest load error")) }
    }

    private func message(_ t: String) -> some View {
        VStack(spacing: 12) {
            ErtyView(mood: .notes, size: 96)
            Text(t).multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    @ViewBuilder private func section(_ title: String, _ items: [Digest.Item], symbol: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: Self.symbol(i.kind, fallback: symbol)).foregroundStyle(i.overdue == true ? Jungle.terracotta : Jungle.accentText).frame(width: 22)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.line(i)).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                                if let d = i.date {
                                    Text(i.overdue == true ? Grammar.pt(String(localized: "Overdue since \(d.formatted(.dateTime.weekday(.wide).day()))", comment: "Weekly digest row; arg weekday and day")) : d.formatted(.dateTime.weekday(.wide).day().month()))
                                        .font(.caption).foregroundStyle(i.overdue == true ? Jungle.warmText : Jungle.subtle)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            }
        }
    }

    static func symbol(_ kind: String, fallback: String) -> String {
        switch kind {
        case "water", "overdue_water": "drop.fill"
        case "feed": "leaf.arrow.triangle.circlepath"
        case "task": "checklist"
        case "problem": "exclamationmark.triangle.fill"
        case "quiet": "moon.zzz"
        case "repot": "arrow.up.bin.fill"
        case "newLeaf": "leaf.fill"
        case "flower": "camera.macro"
        case "measure": "ruler"
        case "propagate": "scissors"
        default: fallback
        }
    }

    static func line(_ i: Digest.Item) -> String {
        let n = i.plant ?? ""
        switch i.kind {
        case "water": return Grammar.pt(String(localized: "Water \(n)", comment: "Weekly digest row: watering due; arg plant name"))
        case "feed": return Grammar.pt(String(localized: "Feed \(n)", comment: "Weekly digest row: feeding due; arg plant name"))
        case "overdue_water": return Grammar.pt(String(localized: "\(n) is waiting for a drink", comment: "Weekly digest row; arg plant name"))
        case "problem": return i.title.map { "\(n): \($0)" } ?? Grammar.pt(String(localized: "\(n) had a problem logged", comment: "Weekly digest row; arg plant name"))
        case "quiet": return Grammar.pt(String(localized: "Nothing logged for \(n) in a while", comment: "Weekly digest row; arg plant name"))
        case "repot": return Grammar.pt(String(localized: "\(n) may need a bigger pot", comment: "Weekly digest row; arg plant name"))
        case "newLeaf": return Grammar.pt(String(localized: "\(n) opened a new leaf", comment: "Weekly digest row; arg plant name"))
        case "flower": return Grammar.pt(String(localized: "\(n) is flowering", comment: "Weekly digest row; arg plant name"))
        case "measure": return i.value.map { Grammar.pt(String(localized: "\(n) is \(PlantFormat.cm($0)) tall", comment: "Weekly digest row; args plant name, height")) } ?? Grammar.pt(String(localized: "\(n) was measured", comment: "Weekly digest row; arg plant name"))
        case "propagate": return Grammar.pt(String(localized: "A new cutting from \(n)", comment: "Weekly digest row; arg plant name"))
        default: return [n, i.title].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
        }
    }
}

private struct DigestPhoto: View {
    let item: Digest.Item
    @State private var image: UIImage?
    var body: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
            .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Jungle.fillSubtle } }
            .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
            .accessibilityLabel(Grammar.pt(String(localized: "Photo of \(item.plant ?? "")", comment: "VoiceOver: digest photo; arg plant name")))
            .task {
                guard image == nil, let m = item.media else { return }
                let path = m.hasPrefix("/") ? m : "/" + m
                if let d = try? await JungleAPI.shared.download(path) { image = UIImage(data: d) }
            }
    }
}

/// Friendly words for server limits, shown as a little Erty toast.
@MainActor
enum ServerNotice {
    static func message(for error: Error) -> String? {
        guard case JungleAPI.APIError.http(let code, let reason) = error else { return nil }
        if code == 429 || reason == "daily_limit" { return Grammar.pt(String(localized: "That's enough for today, try again tomorrow.", comment: "Server daily limit reached; friendly")) }
        if code == 503 || reason == "busy" { return Grammar.pt(String(localized: "I'm a little busy right now. Try again in a minute.", comment: "Server busy; friendly")) }
        return nil
    }
    static func show(_ error: Error) {
        if let m = message(for: error) { ErtyCheer.shared.show(.sleep, m) }
    }
}

/// Links from widgets and shortcuts: mytinyjungle://today, mytinyjungle://add, mytinyjungle://plant/<id>.
@MainActor
enum DeepLink {
    static let plantKey = "openPlantID"
    static let addKey = "openAddPlant"

    @discardableResult static func handle(_ url: URL) -> Bool {
        guard url.scheme == "mytinyjungle" else { return false }
        let d = UserDefaults.standard
        switch url.host() {
        case "today": d.set(0, forKey: "selectedTab")
        case "add": d.set(1, forKey: "selectedTab"); d.set(true, forKey: addKey)
        case "plant":
            guard let id = url.pathComponents.dropFirst().first, UUID(uuidString: id) != nil else { return false }
            d.set(1, forKey: "selectedTab"); d.set(id, forKey: plantKey)
        default: return false
        }
        return true
    }
}
