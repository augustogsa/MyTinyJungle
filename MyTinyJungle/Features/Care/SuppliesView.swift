import SwiftUI

/// Soil, food, pots and treatments: stock on the server, low-stock push from it.
nonisolated struct Supply: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var name: String
    var qty: Double
    var unit: String
    var lowAt: Double?
    var low: Bool?
    static let kinds = ["soil", "fertiliser", "pot", "pesticide", "other"]
}

nonisolated struct PlantSupplies: Decodable, Equatable {
    nonisolated struct Item: Decodable, Equatable, Identifiable { var kind: String; var name: String; var why: String?; var have: Bool?; var id: String { kind + name } }
    var items: [Item]
}

@MainActor
enum SuppliesAPI {
    static let openKey = "openSupplies"
    static func list() async throws -> [Supply] {
        nonisolated struct R: Decodable { let supplies: [Supply] }
        let r: R = try await JungleAPI.shared.get("/v1/me/supplies"); return r.supplies
    }
    static func save(_ s: Supply) async throws -> Supply {
        nonisolated struct B: Encodable { let kind, name: String; let qty: Double; let unit: String; let lowAt: Double? }
        return try await JungleAPI.shared.send("PUT", "/v1/me/supplies/\(s.id)", body: B(kind: s.kind, name: s.name, qty: s.qty, unit: s.unit, lowAt: s.lowAt))
    }
    static func delete(_ id: String) async {
        nonisolated struct R: Decodable {}
        let _: R? = try? await JungleAPI.shared.send("DELETE", "/v1/me/supplies/\(id)", body: Optional<String>.none)
    }
    static func forPlant(_ id: UUID) async throws -> PlantSupplies {
        try await JungleAPI.shared.get("/v1/plants/\(id.uuidString.lowercased())/supplies", query: [URLQueryItem(name: "lang", value: PlantSituation.lang)])
    }
    static func label(_ kind: String) -> String {
        switch kind {
        case "soil": Grammar.pt(String(localized: "Soil", comment: "Supply kind; max 14 chars"))
        case "fertiliser": Grammar.pt(String(localized: "Plant food", comment: "Supply kind: fertilizer; max 14 chars"))
        case "pot": Grammar.pt(String(localized: "Pots", comment: "Supply kind; max 14 chars"))
        case "pesticide": Grammar.pt(String(localized: "Pest care", comment: "Supply kind: pesticide/treatment; max 14 chars"))
        default: Grammar.pt(String(localized: "Other", comment: "Supply kind; max 14 chars"))
        }
    }
    static func symbol(_ kind: String) -> String {
        switch kind { case "soil": "shippingbox.fill"; case "fertiliser": "leaf.fill"; case "pot": "cylinder.fill"; case "pesticide": "ladybug.fill"; default: "tray.fill" }
    }
}

struct SuppliesView: View {
    @State private var items: [Supply] = []
    @State private var editing: Supply?
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(Jungle.subtle) }
            if loaded && items.isEmpty && error == nil {
                JungleEmptyState(mood: .soilbag, title: Grammar.pt(String(localized: "No supplies yet", comment: "Supplies empty state title; max 30 chars")),
                                 message: Grammar.pt(String(localized: "Keep track of soil, plant food and treatments. I'll let you know when something runs low.", comment: "Supplies empty state")),
                                 actionTitle: JungleAPI.shared.hasSession ? Grammar.pt(String(localized: "Add a supply", comment: "VoiceOver: add supply button")) : nil) { editing = Supply(id: UUID().uuidString.lowercased(), kind: "soil", name: "", qty: 1, unit: "L", lowAt: nil) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            }
            ForEach(Supply.kinds, id: \.self) { k in
                let group = items.filter { $0.kind == k }
                if !group.isEmpty {
                    Section(SuppliesAPI.label(k)) {
                        ForEach(group) { s in
                            Button { editing = s } label: {
                                HStack {
                                    Label(s.name, systemImage: SuppliesAPI.symbol(s.kind)).foregroundStyle(Jungle.text)
                                    Spacer()
                                    Text("\(s.qty.formatted()) \(s.unit)").monospacedDigit().foregroundStyle(s.low == true ? Jungle.warmText : Jungle.subtle)
                                    if s.low == true { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Jungle.terracotta).accessibilityLabel(Grammar.pt(String(localized: "Running low", comment: "Supply badge"))) }
                                }
                            }
                        }
                        .onDelete { idx in for i in idx { let s = group[i]; items.removeAll { $0.id == s.id }; Task { await SuppliesAPI.delete(s.id) } } }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).jungleBackdrop()
        .navigationTitle(Grammar.pt(String(localized: "Supplies", comment: "Screen title; max 20 chars")))
        .toolbar {
            if JungleAPI.shared.hasSession {
            Button { editing = Supply(id: UUID().uuidString.lowercased(), kind: "soil", name: "", qty: 1, unit: "L", lowAt: nil) } label: { Image(systemName: "plus") }
                .accessibilityLabel(Grammar.pt(String(localized: "Add a supply", comment: "VoiceOver: add supply button")))
            }
        }
        .sheet(item: $editing) { s in
            SupplyEditor(supply: s) { saved in
                if let i = items.firstIndex(where: { $0.id == saved.id }) { items[i] = saved } else { items.append(saved) }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        defer { loaded = true }
        guard JungleAPI.shared.hasSession else { error = Grammar.pt(String(localized: "Sign in to keep your supplies.", comment: "Supplies when signed out")); return }
        do { items = try await SuppliesAPI.list(); error = nil }
        catch { self.error = ServerNotice.message(for: error) ?? Grammar.pt(String(localized: "Couldn't load your supplies. Pull to try again.", comment: "Supplies load error")) }
    }
}

private struct SupplyEditor: View {
    @State var supply: Supply
    var onSave: (Supply) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var warn = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Picker(Grammar.pt(String(localized: "Kind", comment: "Supply editor field")), selection: $supply.kind) {
                    ForEach(Supply.kinds, id: \.self) { Label(SuppliesAPI.label($0), systemImage: SuppliesAPI.symbol($0)).tag($0) }
                }
                TextField(Grammar.pt(String(localized: "Name", comment: "Plant name field placeholder")), text: $supply.name)
                HStack {
                    TextField(Grammar.pt(String(localized: "Amount", comment: "Supply editor field")), value: $supply.qty, format: .number).keyboardType(.decimalPad)
                    TextField(Grammar.pt(String(localized: "Unit", comment: "Supply editor field: L, kg, pcs")), text: $supply.unit).frame(maxWidth: 90).multilineTextAlignment(.trailing)
                }
                Toggle(Grammar.pt(String(localized: "Tell me when it's low", comment: "Supply editor toggle")), isOn: Binding(get: { supply.lowAt != nil }, set: { supply.lowAt = $0 ? (supply.lowAt ?? max(1, supply.qty / 4)) : nil }))
                if supply.lowAt != nil {
                    TextField(Grammar.pt(String(localized: "Low at", comment: "Supply editor field: threshold")), value: Binding(get: { supply.lowAt ?? 0 }, set: { supply.lowAt = $0 }), format: .number).keyboardType(.decimalPad)
                }
                if warn { Text(Grammar.pt(String(localized: "Couldn't save right now. Try again in a moment.", comment: "Supply save error"))).foregroundStyle(Jungle.warmText) }
            }
            .tint(Jungle.forest)
            .navigationTitle(supply.name.isEmpty ? Grammar.pt(String(localized: "New supply", comment: "Screen title; max 20 chars")) : supply.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { busy = true; defer { busy = false }; do { onSave(try await SuppliesAPI.save(supply)); dismiss() } catch { warn = true } } }
                        .disabled(supply.name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
            }
        }
    }
}

/// On a plant: what soil, pot and food suit it, and whether you have them.
struct PlantSuppliesCard: View {
    let plant: Plant
    @State private var data: PlantSupplies?

    var body: some View {
        Group {
            if let d = data, !d.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(Grammar.pt(String(localized: "What I like", comment: "Plant screen section: recommended soil, pot, food; plant voice; max 24 chars")))
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(d.items) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: SuppliesAPI.symbol(i.kind)).foregroundStyle(Jungle.accentText).frame(width: 22).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i.name).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                                    if let w = i.why { Text(w).font(.caption).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true) }
                                }
                                Spacer()
                                if i.have == true { Image(systemName: "checkmark.circle.fill").foregroundStyle(Jungle.leaf).accessibilityLabel(Grammar.pt(String(localized: "You have it", comment: "VoiceOver: supply already in stock"))) }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        NavigationLink { SuppliesView() } label: {
                            Label(Grammar.pt(String(localized: "My supplies", comment: "Link to supplies screen")), systemImage: "shippingbox").font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
                }
            }
        }
        .task(id: plant.id) {
            guard JungleAPI.shared.hasSession, plant.speciesID != nil else { return }
            data = try? await SuppliesAPI.forPlant(plant.id)
        }
    }
}

/// mytinyjungle://supplies opens this over everything.
struct SuppliesLinkSheet: ViewModifier {
    @AppStorage(SuppliesAPI.openKey) private var open = false
    func body(content: Content) -> some View {
        content.sheet(isPresented: $open) { NavigationStack { SuppliesView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { open = false } } } } }
    }
}
