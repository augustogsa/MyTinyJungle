import SwiftUI
import SwiftData
import PhotosUI

extension Brain {
    nonisolated struct BatchItem: Decodable {
        nonisolated struct Box: Decodable { var x, y, w, h: Double }
        nonisolated struct Cand: Decodable { var id: String?; var scientific: String?; var name: String?; var score: Double? }
        var box: Box
        var candidates: [Cand]
        var confident: Bool
    }
    nonisolated struct BatchResult: Decodable { var items: [BatchItem]; var truncated: Bool? }

    /// Every plant in one shelf photo.
    static func identifyBatch(_ photo: BrainPhoto) async throws -> BatchResult {
        nonisolated struct B: Encodable { let photo, lang: String }
        let lang = PlantSituation.lang, key = BrainCache.key("identify-batch", photo.sha, lang)
        if let hit: BatchResult = BrainCache.get(key) { return hit }
        let d = try await JungleAPI.shared.sendData("POST", "/v1/brain/identify-batch", body: B(photo: photo.base64, lang: lang))
        let r = try JungleAPI.decoder.decode(BatchResult.self, from: d)
        if !r.items.isEmpty { BrainCache.put(key, d) }
        return r
    }

    /// The owner's pick after identify, so the model learns. Fire and forget.
    static func identifyFeedback(suggested: String, chosen: String?) async {
        guard JungleAPI.shared.hasSession else { return }
        nonisolated struct B: Encodable { let suggested: String; let chosen: String }
        nonisolated struct R: Decodable {}
        let _: R? = try? await JungleAPI.shared.send("POST", "/v1/brain/identify/feedback", body: B(suggested: suggested, chosen: chosen ?? ""))
    }
}

/// One photo of a shelf → one new plant per crop.
struct ShelfImportView: View {
    var initialPhoto: Data? = nil
    var onDone: () -> Void
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var showCamera = false
    @State private var rows: [Row] = []
    @State private var working = false
    @State private var error: String?
    @State private var truncated = false

    struct Row: Identifiable {
        let id = UUID()
        var crop: UIImage
        var species: Species?
        var suggested: String?
        var name: String
        var keep = true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if rows.isEmpty && !working {
                        VStack(spacing: 12) {
                            ErtyView(mood: .scan, size: 110)
                            Text(Grammar.pt(String(localized: "Snap the whole shelf. I'll find each plant and add them all.", comment: "Shelf import intro")))
                                .multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button { showCamera = true } label: { Label("Take a photo", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                                    .buttonStyle(.borderedProminent).junglePrimary().controlSize(.large)
                            }
                            PhotosPicker(selection: $pick, matching: .images) { Label("Choose from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                                .buttonStyle(.bordered).controlSize(.large)
                        }
                        .buttonBorderShape(.capsule).frame(maxWidth: .infinity).padding(.top, 30)
                    }
                    if working {
                        VStack(spacing: 10) { ErtyView(mood: .scan, size: 96); ProgressView() }.frame(maxWidth: .infinity).padding(.top, 40)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Grammar.pt(String(localized: "Looking for plants", comment: "VoiceOver: shelf import in progress")))
                    }
                    if let error { Text(error).foregroundStyle(Jungle.warmText).frame(maxWidth: .infinity) }
                    if truncated {
                        Label(Grammar.pt(String(localized: "Today's limit stopped me early. Add the rest tomorrow.", comment: "Shelf import: daily limit cut the batch")), systemImage: "moon.zzz")
                            .font(.caption).foregroundStyle(Jungle.subtle)
                    }
                    ForEach($rows) { $r in
                        HStack(spacing: 12) {
                            Image(uiImage: r.crop).resizable().scaledToFill().frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(Grammar.pt(String(localized: "Name", comment: "Plant name field placeholder")), text: $r.name)
                                    .font(.system(.headline, design: .rounded))
                                Text(r.species.map { "\($0.commonName) · \($0.scientific)" } ?? Grammar.pt(String(localized: "Not sure what this is yet", comment: "Shelf import row: unknown species")))
                                    .font(.caption).foregroundStyle(Jungle.subtle)
                            }
                            Spacer()
                            Toggle(Grammar.pt(String(localized: "Add", comment: "Toggle: include this plant")), isOn: $r.keep).labelsHidden()
                                .accessibilityLabel(Grammar.pt(String(localized: "Add \(r.name)", comment: "VoiceOver: include plant toggle; arg name")))
                        }
                        .padding(12).jungleCard()
                    }
                }
                .padding(16)
            }
            .jungleBackdrop()
            .navigationTitle(Grammar.pt(String(localized: "Shelf import", comment: "Screen title; max 20 chars")))
            .navigationBarTitleDisplayMode(.inline)
            .tint(Jungle.forest)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if !rows.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Grammar.pt(String(localized: "Add \(rows.filter(\.keep).count)", comment: "Shelf import confirm; arg count"))) { save() }
                            .disabled(!rows.contains(where: \.keep))
                    }
                }
            }
            .onChange(of: pick) { _, p in Task { if let d = try? await p?.loadTransferable(type: Data.self) { await run(d) } } }
            .task { if let initialPhoto, rows.isEmpty, !working { await run(initialPhoto) } }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { d in showCamera = false; if let d { Task { await run(d) } } }.ignoresSafeArea() }
        }
    }

    private func run(_ data: Data) async {
        guard JungleAPI.shared.hasSession else { error = Grammar.pt(String(localized: "Sign in to find plants on a shelf.", comment: "Shelf import when signed out")); return }
        working = true; error = nil; defer { working = false }
        // Boxes are relative, so the server gets the 768 px upload and the crops come from a sharper local decode.
        let (bp, local) = await Task.detached(priority: .userInitiated) { (BrainPhoto.make(data), BrainPhoto.encode(data, maxSide: 1400, quality: 0.85)) }.value
        guard let img = UIImage(data: local ?? bp.jpeg)?.cgImage else { return }
        do {
            let r = try await Brain.identifyBatch(bp)
            truncated = r.truncated ?? false
            let lib = SpeciesLibrary.shared
            let W = Double(img.width), H = Double(img.height)
            rows = r.items.enumerated().compactMap { i, it in
                let rect = CGRect(x: it.box.x * W, y: it.box.y * H, width: it.box.w * W, height: it.box.h * H).integral
                guard let c = img.cropping(to: rect) else { return nil }
                let top = it.candidates.first
                let sp = it.confident ? (top?.id.flatMap { lib.species(id: $0) } ?? lib.all.first { $0.scientific.folded == (top?.scientific ?? "").folded }) : nil
                let fallback = Grammar.pt(String(localized: "Plant \(i + 1)", comment: "Shelf import default name; arg number"))
                return Row(crop: UIImage(cgImage: c), species: sp, suggested: top?.id, name: sp?.commonName ?? fallback)
            }
            if rows.isEmpty { error = Grammar.pt(String(localized: "I couldn't spot any plants. Try a brighter, closer photo.", comment: "Shelf import found nothing")) }
        } catch {
            self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't read the photo. Try again.", comment: "Shelf import error"))
        }
    }

    private func save() {
        for r in rows where r.keep {
            let p = Plant(name: r.name.isEmpty ? (r.species?.commonName ?? "Plant") : r.name, speciesID: r.species?.id)
            p.photo = r.crop.jpegData(compressionQuality: 0.85)
            ctx.insert(p)
            if let ph = p.photo { let e = CareEvent(kind: .photo, note: "First photo", source: "shelf"); e.photo = ph; e.plant = p; ctx.insert(e) }
            if let s = r.suggested { Task { await Brain.identifyFeedback(suggested: s, chosen: r.species?.id) } }
        }
        try? ctx.save()
        Analytics.track("shelf_import")
        ErtyCheer.shared.show(.celebrate, Grammar.pt(String(localized: "Welcome home, everyone!", comment: "Celebration after adding several plants")))
        dismiss(); onDone()
    }
}
