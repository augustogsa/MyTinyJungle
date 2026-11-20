import Testing
import Foundation
@testable import MyTinyJungle

/// The server-tuned brain config: decoding the GET /v1/brain/config reply, defaults when fields are missing,
/// bands, scan plans, cards, and generic answer cards with chips and actions.
@MainActor struct BrainConfigTests {
    static let reply = #"""
    {"v":1,"scene":{"sure":0.7,"timeoutS":10},
     "identify":{"timeoutS":9,"maxCandidates":2,"maxTips":1,"onDeviceCandidates":false,
       "bands":[{"id":"couldBe","min":0,"tone":"warn"},{"id":"sure","min":0.9,"tone":"good","word":"Certeza"},{"id":"likely","min":0.5,"tone":"good"}]},
     "ask":{"server":true,"feedback":false},
     "scan":{"cap":6,"plans":{"identify":{"order":["whole","leaf","leaf","mystery"],"weights":{"whole":0.5},"other":0.01}},
       "hints":{"leaf":"Chega pertinho"},"howTo":[{"icon":"leaf","title":"Luz boa","text":"Perto da janela"}]},
     "flags":{"serverIdentify":false},
     "cards":[{"id":"c1","surface":"scan","title":"Dica","body":"Use luz natural","actions":[{"label":"Ver","link":"mytinyjungle://today"}]},{"id":"c2","title":"Oi"}],
     "experiments":{"bands":"b"},
     "somethingNew":{"x":1}}
    """#

    @Test func decodesServerReplyAndIgnoresUnknownKeys() throws {
        let c = try JSONDecoder().decode(BrainConfig.self, from: Data(Self.reply.utf8))
        #expect(c.scene?.sure == 0.7)
        #expect(c.identify?.maxCandidates == 2)
        #expect(c.scan?.cap == 6)
        #expect(c.flags?["serverIdentify"] == false)
        #expect(c.experiments?["bands"] == "b")
        #expect(c.cards?.count == 2)
    }

    @Test func emptyConfigMeansBundledDefaults() throws {
        let c = try JSONDecoder().decode(BrainConfig.self, from: Data("{}".utf8))
        #expect(BrainTuning.bands(in: c).map(\.id) == ["veryLikely", "likely", "couldBe"])
        #expect(BrainTuning.band(0.85, in: c).id == "veryLikely")
        #expect(BrainTuning.band(0.6, in: c).id == "likely")
        #expect(BrainTuning.band(0.1, in: c).id == "couldBe")
        #expect(ScanPurpose.identify.order(in: c).first == .leaf)
        #expect(ScanPurpose.identify.weight(.leaf, in: c) == 0.35)
        #expect(ScanPurpose.doctor.weight(.underside, in: c) == 0.2)
    }

    @Test func serverBandsSortAndWordsWin() throws {
        let c = try JSONDecoder().decode(BrainConfig.self, from: Data(Self.reply.utf8))
        let top = BrainTuning.band(0.95, in: c)
        #expect(top.id == "sure" && top.words == "Certeza")
        #expect(BrainTuning.band(0.6, in: c).id == "likely")
        #expect(BrainTuning.band(-1, in: c).id == "couldBe")
        #expect(!BrainTuning.band(0.6, in: c).words.isEmpty)
    }

    @Test func serverScanPlanDedupesAndMapsUnknownKinds() throws {
        let c = try JSONDecoder().decode(BrainConfig.self, from: Data(Self.reply.utf8))
        #expect(ScanPurpose.identify.order(in: c) == [.whole, .leaf, .other])
        #expect(ScanPurpose.identify.weight(.whole, in: c) == 0.5)
        #expect(ScanPurpose.identify.weight(.flower, in: c) == 0.01)
        #expect(ScanPurpose.doctor.order(in: c).first == .leaf)  // no doctor plan: ours
    }

    @Test func cardsBySurface() throws {
        let c = try JSONDecoder().decode(BrainConfig.self, from: Data(Self.reply.utf8))
        #expect(BrainTuning.cards("scan", in: c).map(\.id) == ["c1"])
        #expect(BrainTuning.cards("today", in: c).map(\.id) == ["c2"])
        #expect(BrainTuning.cards("scan", in: c).first?.actions?.first?.link == "mytinyjungle://today")
    }

    @Test func genericAnswerCardDecodesChipsAndActions() throws {
        let raw = #"{"id":"overwatering","kind":"brandNewKind","title":"T","text":"x","chips":["How often?","How often?","Repot?"],"actions":[{"label":"Scan","link":"mytinyjungle://add"}],"link":"https://mytinyjungle.com"}"#
        let a = try JSONDecoder().decode(BrainAnswer.self, from: Data(raw.utf8))
        #expect(a.kind == "brandNewKind" && a.id == "overwatering")
        #expect(a.actions?.first?.label == "Scan")
        #expect(Brain.chips([a]) == ["How often?", "Repot?"])
        let old = try JSONDecoder().decode(BrainAnswer.self, from: Data(#"{"kind":"topic","title":"T","text":"x"}"#.utf8))
        #expect(old.chips == nil && old.id == nil)
    }

    @Test func streamEventsCarryCardFields() {
        let e = JungleAPI.Event(name: "answer", data: Data(#"{"id":"a","kind":"symptom","title":"T","text":"x","chips":["Why?"]}"#.utf8))
        let r = Brain.reply(from: [e, JungleAPI.Event(name: "done", data: Data("{}".utf8))])
        #expect(r.answers?.first?.chips == ["Why?"])
    }
}
