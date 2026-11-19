import Testing
import Foundation
@testable import MyTinyJungle

@MainActor
struct MediumTests {
    func plant(_ m: GrowingMedium, wateredDaysAgo: Double? = 12) -> Plant {
        let p = Plant(name: "Leo", speciesID: "epipremnum-aureum")
        p.growingMedium = m
        p.acquiredAt = Date().addingTimeInterval(-10 * 86_400)
        p.createdAt = Date()
        if let d = wateredDaysAgo {
            let e = CareEvent(kind: p.waterKind, date: Date().addingTimeInterval(-d * 86_400)); p.events = [e]
        }
        return p
    }

    @Test func waterCultureNeverAsksForWater() {
        let p = plant(.water, wateredDaysAgo: 9)
        let kinds = CareEngine.requests(for: p).map(\.kind)
        #expect(!kinds.contains(.water) && !kinds.contains(.checkSoil))
        #expect(kinds.contains(.refreshWater))
        #expect(CareEngine.status(for: p) == .tend)
    }

    @Test func soilStillChecks() {
        let p = plant(.soil, wateredDaysAgo: 12)
        #expect(CareEngine.requests(for: p).map(\.kind).contains { $0 == .checkSoil || $0 == .askDone })
    }

    @Test func lecaTopsUp() {
        #expect(CareEngine.requests(for: plant(.leca, wateredDaysAgo: 8)).map(\.kind).contains(.topUp))
    }

    @Test func longOverdueAsksInstead() {
        let p = plant(.water, wateredDaysAgo: 20)
        UserDefaults.standard.removeObject(forKey: CareEngine.notYetKey(p))
        #expect(CareEngine.requests(for: p).map(\.kind).contains(.askDone))
    }

    @Test func fakePlantNeedsNothing() {
        let p = plant(.soil, wateredDaysAgo: 40); p.isArtificial = true
        #expect(CareEngine.requests(for: p).isEmpty)
    }

    @Test func treatmentRounds() {
        let p = plant(.soil, wateredDaysAgo: 1)
        p.events?.append(CareEvent(kind: .treat, date: Date().addingTimeInterval(-7 * 86_400)))
        let kinds = CareEngine.requests(for: p).map(\.kind)
        #expect(kinds.contains(.quarantine) && kinds.contains(.treatFollowUp))
    }

    @Test func repottedPausesFeeding() {
        let p = plant(.soil, wateredDaysAgo: 1); p.setLifeStage(.repotted)
        #expect(!CareEngine.requests(for: p).map(\.kind).contains(.feed))
    }

    @Test func changedTheWaterLogsRefresh() {
        let ref = ChatParser.PlantRef(id: UUID(), name: "Leo", speciesID: nil)
        for t in ["changed Leo's water", "troquei a água do Leo", "Changed the water"] {
            let r = ChatParser.parse(t, plants: [ref], context: ref.id)
            #expect(r.actions.first?.kind == .water, "\(t)")
            #expect(r.actions.first?.detail == "refresh", "\(t)")
        }
    }

    @Test func situationCarriesSetup() {
        let p = plant(.leca); p.potCachepot = true; p.setLifeStage(.dormant)
        let s = PlantSituation.build(p)
        #expect(s["medium"] == ["leca"])
        #expect(s["lifeStage"] == ["dormant"])
        #expect(s["potSetup"]?.contains("cachepot") == true)
        #expect(s["outdoor"] == ["false"])
    }
}
