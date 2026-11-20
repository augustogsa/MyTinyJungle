import SwiftUI
import CoreImage.CIFilterBuiltins

/// Plant passport: a public care card (species and care only) behind a link and a QR code.
@MainActor
enum PassportAPI {
    nonisolated struct Card: Decodable, Equatable {
        nonisolated struct Sp: Decodable, Equatable { var id: String?; var scientific: String?; var name: String? }
        var species: Sp?
        var light: String?
        var waterEveryDays: Double?
        var feedEveryWeeks: Double?
        var tip: String?
        var notes: String?
    }
    nonisolated struct Shared: Decodable, Equatable { var token: String; var url: String; var card: Card? }
    static let importKey = "passportImport"

    static func share(_ plantID: UUID, notes: String) async throws -> Shared {
        nonisolated struct B: Encodable { let notes: String }
        return try await JungleAPI.shared.send("POST", "/v1/plants/\(plantID.uuidString.lowercased())/passport", query: [URLQueryItem(name: "lang", value: PlantSituation.lang)], body: B(notes: notes))
    }
    static func stop(_ plantID: UUID) async {
        nonisolated struct R: Decodable {}
        let _: R? = try? await JungleAPI.shared.send("DELETE", "/v1/plants/\(plantID.uuidString.lowercased())/passport", body: Optional<String>.none)
    }
    static func card(_ token: String) async throws -> Card {
        try await JungleAPI.shared.get("/v1/passports/\(token)", query: [URLQueryItem(name: "lang", value: PlantSituation.lang)])
    }
    static func importPlant(_ token: String) async throws {
        nonisolated struct B: Encodable { let lang: String }
        nonisolated struct R: Decodable { let plantId: String }
        let _: R = try await JungleAPI.shared.send("POST", "/v1/passports/\(token)/import", body: B(lang: PlantSituation.lang))
        await JungleSync.shared.sync()
    }

    /// mytinyjungle://passport/<token> or https://…/p/<token>
    static func token(from url: URL) -> String? {
        let p = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "mytinyjungle", url.host() == "passport" { return p.first }
        if let i = p.firstIndex(of: "p"), i + 1 < p.count, url.host()?.contains("mytinyjungle") == true { return p[i + 1] }
        return nil
    }

    static func qr(_ s: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8); f.correctionLevel = "M"
        guard let o = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(o, from: o.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Share sheet for a plant's passport.
struct PassportSheet: View {
    let plant: Plant
    var preset: PassportAPI.Shared? = nil
    var presetNotes = ""
    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var shared: PassportAPI.Shared?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(Grammar.pt(String(localized: "A care card anyone can open: species, light, water and your tips. Never your name, photos or address.", comment: "Plant passport explanation")))
                        .font(.subheadline).foregroundStyle(Jungle.subtle)
                    TextField(Grammar.pt(String(localized: "Your care notes (optional)", comment: "Plant passport notes field")), text: $notes, axis: .vertical).lineLimit(2...5)
                }
                if let s = shared, let url = URL(string: s.url) {
                    Section {
                        if let img = PassportAPI.qr(s.url) {
                            Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 220).frame(maxWidth: .infinity)
                                .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityLabel(Grammar.pt(String(localized: "QR code for \(plant.name)'s passport", comment: "VoiceOver: passport QR; arg plant name")))
                        }
                        ShareLink(item: url, subject: Text(plant.name), message: Text(Grammar.pt(String(localized: "How to care for my \(plant.species?.commonName ?? plant.name)", comment: "Passport share message; arg species")))) {
                            Label(Grammar.pt(String(localized: "Share link", comment: "Button")), systemImage: "square.and.arrow.up")
                        }
                        if let img = PassportAPI.qr(s.url) {
                            ShareLink(item: Image(uiImage: img), preview: SharePreview(plant.name, image: Image(uiImage: img))) {
                                Label(Grammar.pt(String(localized: "Share QR code", comment: "Button")), systemImage: "qrcode")
                            }
                        }
                        Button(Grammar.pt(String(localized: "Stop sharing", comment: "Button: turn off plant passport")), role: .destructive) {
                            Task { await PassportAPI.stop(plant.id); shared = nil }
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(Jungle.warmText) } }
            }
            .scrollContentBackground(.hidden).jungleBackdrop()
            .onAppear { if shared == nil, let preset { shared = preset; notes = presetNotes } }
            .navigationTitle(Grammar.pt(String(localized: "Plant passport", comment: "Screen title; max 20 chars")))
            .navigationBarTitleDisplayMode(.inline)
            .tint(Jungle.forest)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(shared == nil ? Grammar.pt(String(localized: "Create", comment: "Button: create plant passport")) : Grammar.pt(String(localized: "Update", comment: "Button: refresh plant passport"))) { Task { await share() } }
                        .disabled(busy)
                }
            }
        }
    }

    private func share() async {
        Analytics.log("passport_share")
        guard JungleAPI.shared.hasSession else { error = Grammar.pt(String(localized: "Sign in to share a passport.", comment: "Passport when signed out")); return }
        busy = true; defer { busy = false }
        await JungleSync.shared.sync()
        do { shared = try await PassportAPI.share(plant.id, notes: notes); error = nil }
        catch { self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't share right now. Try again in a moment.", comment: "Passport share error")) }
    }
}

/// Opened from a passport link: preview the card, then add the plant.
struct PassportImportSheet: ViewModifier {
    @AppStorage(PassportAPI.importKey) private var token = ""
    @State private var card: PassportAPI.Card?
    @State private var error: String?
    @State private var busy = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { !token.isEmpty }, set: { if !$0 { token = ""; card = nil; error = nil } })) {
            NavigationStack {
                VStack(spacing: 16) {
                    ErtyView(mood: .plant, size: 100)
                    if let c = card {
                        Text(c.species?.name ?? c.species?.scientific ?? "").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        if let s = c.species?.scientific { Text(s).italic().foregroundStyle(Jungle.subtle) }
                        VStack(alignment: .leading, spacing: 8) {
                            if let w = c.waterEveryDays { Label(Grammar.pt(String(localized: "Water about every \(Int(w.rounded())) days", comment: "Passport card line; arg days")), systemImage: "drop.fill") }
                            if let f = c.feedEveryWeeks { Label(Grammar.pt(String(localized: "Feed about every \(Int(f.rounded())) weeks", comment: "Passport card line; arg weeks")), systemImage: "leaf.fill") }
                            if let t = c.tip, !t.isEmpty { Label(t, systemImage: "lightbulb") }
                            if let n = c.notes, !n.isEmpty { Label(n, systemImage: "text.quote") }
                        }
                        .font(.subheadline).foregroundStyle(Jungle.text).frame(maxWidth: .infinity, alignment: .leading).padding(14).jungleCard()
                        Button { Task { await add() } } label: { Label(Grammar.pt(String(localized: "Add to my jungle", comment: "Button: import passport plant")), systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).junglePrimary().controlSize(.large).buttonBorderShape(.capsule).disabled(busy)
                    } else if let error {
                        Text(error).multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
                    } else { ProgressView() }
                    Spacer()
                }
                .padding(20).frame(maxWidth: .infinity).jungleBackdrop()
                .navigationTitle(Grammar.pt(String(localized: "Plant passport", comment: "Screen title; max 20 chars"))).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { token = "" } } }
                .task(id: token) {
                    guard !token.isEmpty else { return }
                    do { card = try await PassportAPI.card(token) }
                    catch { self.error = Grammar.pt(String(localized: "This passport isn't shared anymore.", comment: "Passport link no longer valid")) }
                }
            }
        }
    }

    private func add() async {
        guard JungleAPI.shared.hasSession else { error = Grammar.pt(String(localized: "Sign in to add this plant.", comment: "Passport import when signed out")); card = nil; return }
        busy = true; defer { busy = false }
        do {
            try await PassportAPI.importPlant(token)
            ErtyCheer.shared.show(.celebrate, Grammar.pt(String(localized: "Welcome home, \(card?.species?.name ?? "")", comment: "Little celebration when a plant is added; arg is plant name")))
            UserDefaults.standard.set(1, forKey: "selectedTab"); token = ""
        } catch { self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't add it right now. Try again in a moment.", comment: "Passport import error")); card = nil }
    }
}
