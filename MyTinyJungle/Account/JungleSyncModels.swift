import Foundation
import SwiftData

/// What a model looks like on the wire. Dates are seconds since 1970 (exact round trip), optionals are null.
/// Unknown fields from newer app versions are kept and sent back untouched.
final class Payload {
    let kind: Kind
    var fields: [String: JSONValue]
    var photoHash: String?
    var photoData: Data?
    var keepLocalPhoto = false

    init(_ kind: Kind, _ fields: [String: JSONValue]) { self.kind = kind; self.fields = fields }

    func json() -> [String: JSONValue] {
        var f = fields
        if kind.hasPhoto { f["photo"] = photoHash.map(JSONValue.string) ?? .null }
        return f
    }

    func hash() -> String {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        return JungleSync.sha((try? e.encode(json())) ?? Data())
    }

    func upsert(id: UUID, _ ctx: ModelContext) { kind.upsert(id, self, ctx) }

    // Typed readers.
    func s(_ k: String) -> String { if case .string(let v) = fields[k] { v } else { "" } }
    func so(_ k: String) -> String? { if case .string(let v) = fields[k] { v } else { nil } }
    func b(_ k: String, _ d: Bool = false) -> Bool { if case .bool(let v) = fields[k] { v } else { d } }
    func d(_ k: String) -> Double? { if case .number(let v) = fields[k] { v } else { nil } }
    func i(_ k: String) -> Int { Int(d(k) ?? 0) }
    func t(_ k: String) -> Date { d(k).map(Date.init(timeIntervalSince1970:)) ?? Date() }
    func to(_ k: String) -> Date? { d(k).map(Date.init(timeIntervalSince1970:)) }
    func obj(_ k: String) -> [String: JSONValue]? { if case .object(let o) = fields[k] { o } else { nil } }
    func bo(_ k: String) -> Bool? { if case .bool(let v) = fields[k] { v } else { nil } }
    func u(_ k: String) -> UUID? { so(k).flatMap(UUID.init(uuidString:)) }
    func strings(_ k: String) -> [String] {
        if case .array(let a) = fields[k] { a.compactMap { if case .string(let s) = $0 { s } else { nil } } } else { [] }
    }
}

private func v(_ s: String) -> JSONValue { .string(s) }
private func v(_ s: String?) -> JSONValue { s.map(JSONValue.string) ?? .null }
private func v(_ b: Bool) -> JSONValue { .bool(b) }
private func v(_ d: Double?) -> JSONValue { d.map(JSONValue.number) ?? .null }
private func v(_ i: Int) -> JSONValue { .number(Double(i)) }
private func v(_ t: Date) -> JSONValue { .number(t.timeIntervalSince1970) }
private func v(_ t: Date?) -> JSONValue { t.map { v($0) } ?? .null }
private func v(_ u: UUID?) -> JSONValue { u.map { .string($0.uuidString.lowercased()) } ?? .null }
private func v(_ a: [String]) -> JSONValue { .array(a.map(JSONValue.string)) }
private func v(_ b: Bool?) -> JSONValue { b.map(JSONValue.bool) ?? .null }

struct LocalItem { let id: UUID; let payload: Payload; let photo: Data? }

/// Synced entity types, in parent-first order. Raw values are the server's entity names.
enum Kind: String, CaseIterable {
    case space, plant = "plant", careEvent = "care_event", chatMessage = "chat_message", ownedProduct = "owned_product",
         careTask = "care_task", propagation

    static func order(_ entity: String) -> Int { allCases.firstIndex { $0.rawValue == entity } ?? 99 }

    var hasPhoto: Bool { self == .plant || self == .careEvent || self == .chatMessage }

    func decode(_ data: JSONValue) throws -> Payload {
        guard case .object(var o) = data else { throw CocoaError(.coderInvalidValue) }
        var ph: String?
        if case .string(let h) = o["photo"] { ph = h }
        o["photo"] = nil
        let p = Payload(self, o)
        p.photoHash = ph
        return p
    }

    private func find<T: PersistentModel>(_ t: T.Type, _ id: UUID, _ ctx: ModelContext, _ pred: Predicate<T>) -> T? {
        let all = (try? ctx.fetch(FetchDescriptor(predicate: pred))) ?? []
        // iCloud mirroring and server sync can both deliver the same record once; keep one.
        for extra in all.dropFirst() { ctx.delete(extra) }
        return all.first
    }

    func delete(_ id: UUID, _ ctx: ModelContext) {
        switch self {
        case .space: if let o = find(Space.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .plant: if let o = find(Plant.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .careEvent: if let o = find(CareEvent.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .chatMessage: if let o = find(ChatMessage.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .ownedProduct: if let o = find(OwnedProduct.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .careTask: if let o = find(CareTask.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        case .propagation: if let o = find(Propagation.self, id, ctx, #Predicate { $0.id == id }) { ctx.delete(o) }
        }
    }

    func upsert(_ id: UUID, _ p: Payload, _ ctx: ModelContext) {
        func photo(_ current: Data?) -> Data? { p.keepLocalPhoto ? current : p.photoData }
        switch self {
        case .space:
            let o = find(Space.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = Space(name: ""); n.id = id; ctx.insert(n); return n }()
            o.name = p.s("name"); o.lightRaw = p.s("light"); o.isOutdoor = p.b("isOutdoor"); o.humidity = p.d("humidity")
            o.temperature = p.d("temperature"); o.windowFacing = p.s("windowFacing"); o.createdAt = p.t("createdAt")
        case .plant:
            let o = find(Plant.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = Plant(name: "", speciesID: nil); n.id = id; ctx.insert(n); return n }()
            o.name = p.s("name"); o.nameGenderRaw = p.s("nameGender"); o.speciesID = p.so("speciesID"); o.personalityRaw = p.s("personality")
            o.location = p.s("location"); o.isOutdoor = p.b("isOutdoor"); o.potDiameterCm = p.d("potDiameterCm"); o.potMaterialRaw = p.so("potMaterial")
            o.potHasDrainage = p.b("potHasDrainage", true); o.substrate = p.s("substrate"); o.heightCm = p.d("heightCm"); o.acquiredAt = p.t("acquiredAt")
            o.lastRepotAt = p.to("lastRepotAt"); o.learnedDryDays = p.d("learnedDryDays"); o.createdAt = p.t("createdAt")
            o.isArchived = p.b("isArchived"); o.archivedReason = p.so("archivedReason"); o.photo = photo(o.photo)
            o.medium = p.so("medium"); o.lifeStage = p.so("lifeStage"); o.lifeStageAt = p.to("lifeStageAt")
            if let out = p.bo("outdoor") { o.isOutdoor = out }
            o.isArtificial = p.b("artificial"); o.sharesPot = p.b("multiple")
            if let ps = p.obj("potSetup") {
                func pb(_ k: String) -> Bool? { if case .bool(let x) = ps[k] { x } else { nil } }
                func pstr(_ k: String) -> String? { if case .string(let x) = ps[k] { x } else { nil } }
                o.potSelfWatering = pb("selfWatering"); o.potCachepot = pb("cachepot")
                if let d = pb("drainage") { o.potHasDrainage = d }
                if let m = pstr("material") { o.potMaterialRaw = m }
                o.potSizeFit = pstr("sizeFit")
            }
        case .careEvent:
            let o = find(CareEvent.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = CareEvent(kind: .note); n.id = id; ctx.insert(n); return n }()
            o.kindRaw = p.s("kind"); o.date = p.t("date"); o.note = p.s("note"); o.value = p.d("value"); o.soilRaw = p.so("soil")
            o.productName = p.so("productName"); o.source = p.s("source"); o.photo = photo(o.photo)
            o.plant = p.u("plantID").flatMap { pid in find(Plant.self, pid, ctx, #Predicate { $0.id == pid }) }
        case .chatMessage:
            let o = find(ChatMessage.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = ChatMessage(text: "", fromUser: true); n.id = id; ctx.insert(n); return n }()
            o.text = p.s("text"); o.fromUser = p.b("fromUser", true); o.date = p.t("date"); o.suggestionsRaw = p.s("suggestions")
            o.speakerID = p.u("speakerID"); o.cardRaw = p.s("card"); o.photo = photo(o.photo)
            o.plant = p.u("plantID").flatMap { pid in find(Plant.self, pid, ctx, #Predicate { $0.id == pid }) }
        case .ownedProduct:
            let o = find(OwnedProduct.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = OwnedProduct(name: "", category: ""); n.id = id; ctx.insert(n); return n }()
            o.name = p.s("name"); o.categoryRaw = p.s("category"); o.barcode = p.so("barcode"); o.npkN = p.d("npkN"); o.npkP = p.d("npkP")
            o.npkK = p.d("npkK"); o.ingredients = p.strings("ingredients"); o.rawText = p.s("rawText"); o.addedAt = p.t("addedAt")
            o.onShoppingList = p.b("onShoppingList")
        case .careTask:
            let o = find(CareTask.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = CareTask(title: "", kind: .note, plantID: nil, due: Date()); n.id = id; ctx.insert(n); return n }()
            o.title = p.s("title"); o.kindRaw = p.s("kind"); o.plantID = p.u("plantID"); o.due = p.t("due"); o.done = p.b("done")
            o.createdAt = p.t("createdAt")
        case .propagation:
            let o = find(Propagation.self, id, ctx, #Predicate { $0.id == id }) ?? { let n = Propagation(parentID: UUID(), method: ""); n.id = id; ctx.insert(n); return n }()
            o.parentID = p.u("parentID") ?? o.parentID; o.method = p.s("method"); o.startedAt = p.t("startedAt"); o.stageRaw = p.i("stage")
            o.childID = p.u("childID"); o.note = p.s("note")
        }
    }

    /// Every local object of this kind as a payload. Unknown fields from the ledger's last pull are not kept
    /// here; the server merges nothing, so the newest app version's shape wins.
    func locals(_ ctx: ModelContext) -> [LocalItem] {
        func all<T: PersistentModel>(_ t: T.Type) -> [T] { (try? ctx.fetch(FetchDescriptor<T>())) ?? [] }
        switch self {
        case .space:
            return all(Space.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "name": v(o.name), "light": v(o.lightRaw), "isOutdoor": v(o.isOutdoor), "humidity": v(o.humidity),
                "temperature": v(o.temperature), "windowFacing": v(o.windowFacing), "createdAt": v(o.createdAt)]), photo: nil) }
        case .plant:
            return all(Plant.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "name": v(o.name), "nameGender": v(o.nameGenderRaw), "speciesID": v(o.speciesID), "personality": v(o.personalityRaw),
                "location": v(o.location), "isOutdoor": v(o.isOutdoor), "potDiameterCm": v(o.potDiameterCm), "potMaterial": v(o.potMaterialRaw),
                "potHasDrainage": v(o.potHasDrainage), "substrate": v(o.substrate), "heightCm": v(o.heightCm), "acquiredAt": v(o.acquiredAt),
                "lastRepotAt": v(o.lastRepotAt), "learnedDryDays": v(o.learnedDryDays), "createdAt": v(o.createdAt),
                "isArchived": v(o.isArchived), "archivedReason": v(o.archivedReason),
                "medium": v(o.medium), "lifeStage": v(o.lifeStage), "lifeStageAt": v(o.lifeStageAt), "outdoor": v(o.isOutdoor),
                "artificial": v(o.isArtificial), "multiple": v(o.sharesPot),
                "potSetup": .object(["selfWatering": v(o.potSelfWatering), "cachepot": v(o.potCachepot), "drainage": v(o.potHasDrainage),
                                     "material": v(o.potMaterialRaw), "sizeFit": v(o.potSizeFit)])]), photo: o.photo) }
        case .careEvent:
            return all(CareEvent.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "kind": v(o.kindRaw), "date": v(o.date), "note": v(o.note), "value": v(o.value), "soil": v(o.soilRaw),
                "productName": v(o.productName), "source": v(o.source), "plantID": v(o.plant?.id)]), photo: o.photo) }
        case .chatMessage:
            return all(ChatMessage.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "text": v(o.text), "fromUser": v(o.fromUser), "date": v(o.date), "suggestions": v(o.suggestionsRaw),
                "speakerID": v(o.speakerID), "card": v(o.cardRaw), "plantID": v(o.plant?.id)]), photo: o.photo) }
        case .ownedProduct:
            return all(OwnedProduct.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "name": v(o.name), "category": v(o.categoryRaw), "barcode": v(o.barcode), "npkN": v(o.npkN), "npkP": v(o.npkP),
                "npkK": v(o.npkK), "ingredients": v(o.ingredients), "rawText": v(o.rawText), "addedAt": v(o.addedAt),
                "onShoppingList": v(o.onShoppingList)]), photo: nil) }
        case .careTask:
            return all(CareTask.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "title": v(o.title), "kind": v(o.kindRaw), "plantID": v(o.plantID), "due": v(o.due), "done": v(o.done),
                "createdAt": v(o.createdAt)]), photo: nil) }
        case .propagation:
            return all(Propagation.self).map { o in LocalItem(id: o.id, payload: Payload(self, [
                "parentID": v(o.parentID), "method": v(o.method), "startedAt": v(o.startedAt), "stage": v(o.stageRaw),
                "childID": v(o.childID), "note": v(o.note)]), photo: nil) }
        }
    }
}
