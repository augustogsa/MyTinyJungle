import Testing
import Foundation
@testable import MyTinyJungle

@MainActor
struct ParserTests {
    let milo = ChatParser.PlantRef(id: UUID(), name: "Milo", speciesID: "monstera-deliciosa")
    let luna = ChatParser.PlantRef(id: UUID(), name: "Luna", speciesID: "calathea")
    var all: [ChatParser.PlantRef] { [milo, luna] }

    @Test func multiPlantWatering() {
        let r = ChatParser.parse("Watered Milo and Luna this morning", plants: all)
        #expect(r.actions.count == 1)
        #expect(r.actions[0].kind == .water)
        #expect(Set(r.actions[0].plantIDs) == [milo.id, luna.id])
    }

    @Test func portugueseYesterday() {
        let now = Date()
        let r = ChatParser.parse("Ontem reguei a Luna", plants: all, now: now)
        #expect(r.actions.first?.kind == .water)
        #expect(r.actions.first?.plantIDs == [luna.id])
        #expect(Calendar.current.isDate(r.actions[0].date, inSameDayAs: now.addingTimeInterval(-86_400)))
    }

    @Test func soilDryIsNotWatering() {
        let r = ChatParser.parse("Milo's soil is dry", plants: all)
        #expect(r.actions.map(\.kind) == [.soilCheck])
        #expect(r.actions[0].soil == .dry)
    }

    @Test func soilReplyInPlantChat() {
        let r = ChatParser.parse("wet", plants: all, context: milo.id)
        #expect(r.actions.first?.soil == .wet)
    }

    @Test func negation() {
        let r = ChatParser.parse("I didn't water Milo", plants: all)
        #expect(r.actions.isEmpty)
    }

    @Test func question() {
        let r = ChatParser.parse("Why are Milo's leaves yellow?", plants: all)
        #expect(r.isQuestion)
        #expect(r.questionPlantIDs == [milo.id])
    }

    @Test func repotWithSize() {
        let r = ChatParser.parse("repotted Milo into a 24 cm pot", plants: all)
        let a = r.actions.first { $0.kind == .repot }
        #expect(a?.value == 24)
    }

    @Test func move() {
        let r = ChatParser.parse("moved Luna to the bedroom", plants: all)
        #expect(r.actions.first { $0.kind == .move }?.detail == "bedroom")
    }

    @Test func everyone() {
        let r = ChatParser.parse("fed everyone today", plants: all)
        #expect(r.actions.first?.plantIDs.count == 2)
    }
}

@MainActor
struct ProductTests {
    @Test func mixWithNPKIsSubstrate() {
        let p = ProductAnalyzer.analyze(text: "Aroid mix, pine bark, perlite, coco coir, NPK 3-1-2")
        #expect(p.category == .substrate)
        #expect(p.name == "Aroid mix")
    }
    @Test func npkParsed() {
        let p = ProductAnalyzer.analyze(text: "Universal Liquid Plant Food\nNPK 7-3-6\nDilute 5 ml per litre")
        #expect(p.category == .fertilizer)
        #expect(p.npk?.n == 7 && p.npk?.p == 3 && p.npk?.k == 6)
    }

    @Test func substrateIngredients() {
        let p = ProductAnalyzer.analyze(text: "Aroid Potting Mix\nIngredients: orchid bark, perlite, coco coir, worm castings")
        #expect(p.category == .substrate)
        #expect(p.ingredients.contains("perlite"))
        #expect((p.aeration ?? 0) > 0.6)
    }

    @Test func portugueseLabel() {
        let p = ProductAnalyzer.analyze(text: "Terra universal\nComposição: turfa, fibra de coco, perlite\nAdubo N 10% P2O5 5% K2O 8%")
        #expect(p.ingredients.contains("peat"))
        #expect(p.npk?.n == 10)
    }

    @Test func unknownNeverSuitable() {
        let p = ProductAnalyzer.analyze(text: "Super Grow")
        let plant = Plant(name: "Milo", speciesID: "monstera-deliciosa")
        let c = ProductAnalyzer.compatibility(p, plants: [plant])
        #expect(c.first?.verdict == .unknown)
    }

    @Test func peatyMixBadForCactus() {
        let p = ProductAnalyzer.analyze(text: "Moisture control potting soil: peat, compost, vermiculite")
        let cactus = Plant(name: "Spike", speciesID: "cactus-generic")
        #expect(ProductAnalyzer.compatibility(p, plants: [cactus]).first?.verdict == .notRecommended)
    }
}

@MainActor
struct EngineTests {
    @Test func speciesLoaded() { #expect(SpeciesLibrary.shared.all.count >= 40) }

    @Test func learnsSlowerDrying() {
        let p = Plant(name: "Z", speciesID: "monstera-deliciosa")
        let water = CareEvent(kind: .water, date: Date().addingTimeInterval(-12 * 86_400))
        p.events = [water]
        CareEngine.learn(from: .wet, plant: p)
        #expect((p.learnedDryDays ?? 0) > 9.5)
    }
}
