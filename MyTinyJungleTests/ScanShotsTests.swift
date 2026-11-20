import Testing
import Foundation
import UIKit
@testable import MyTinyJungle

/// Multi-photo scan: kind suggestions, missing chips, sureness, cap and the wire shape.
@MainActor struct ScanShotsTests {
    @Test func suggestsByOrderAndMode() {
        #expect(ScanPlan.suggest(.identify, taken: []) == .leaf)
        #expect(ScanPlan.suggest(.identify, taken: [.leaf]) == .whole)
        #expect(ScanPlan.suggest(.identify, taken: [.leaf, .whole]) == .flower)
        #expect(ScanPlan.suggest(.doctor, taken: [.leaf, .whole]) == .underside)
        #expect(ScanPlan.suggest(.doctor, taken: [.leaf, .whole, .underside]) == .soil)
        #expect(ScanPlan.suggest(.doctor, taken: [.leaf], wanted: .pot) == .pot)
    }

    @Test func missingPutsWantedFirst() {
        #expect(ScanPlan.missing(.doctor, taken: [.leaf]) == [.whole, .underside, .soil])
        #expect(ScanPlan.missing(.doctor, taken: [.leaf], wanted: .pot).first == .pot)
        #expect(ScanPlan.missing(.identify, taken: ScanPurpose.identify.useful).isEmpty)
    }

    @Test func surenessGrowsAndCaps() {
        let one = ScanPlan.sureness(.identify, taken: [.leaf])
        let two = ScanPlan.sureness(.identify, taken: [.leaf, .whole])
        #expect(ScanPlan.sureness(.identify, taken: []) == 0)
        #expect(one > 0 && one < 0.4)
        #expect(two > one)
        #expect(ScanPlan.sureness(.doctor, taken: ShotKind.allCases) == 1)
    }

    @Test func trayTagsRetagsRemovesAndCaps() {
        let t = ScanTray(); t.purpose = .doctor
        let a = t.add(Data([1]))!, b = t.add(Data([2]))!
        #expect(a.kind == .leaf && b.kind == .whole)
        t.wanted = .soil
        #expect(t.add(Data([3]))?.kind == .soil && t.wanted == nil)
        t.retag(a.id, .roots)
        #expect(t.shots.first?.kind == .roots)
        t.remove(b.id)
        #expect(t.shots.count == 2)
        for i in 0..<10 { t.add(Data([UInt8(i + 10)])) }
        #expect(t.shots.count == ScanPlan.cap && t.isFull && t.room == 0)
        #expect(t.add(Data([99])) == nil)
        t.clear()
        #expect(t.isEmpty)
    }

    @Test func wireKindsAndTips() throws {
        #expect(ShotKind(wire: "UNDERSIDE") == .underside)
        #expect(ShotKind(wire: "mystery") == .other)
        let d = Data(#"{"candidates":[],"used":["leaf","pot"],"tips":[{"kind":"underside","why":"Pests hide there"}]}"#.utf8)
        let r = try JSONDecoder().decode(Brain.IdentifyReply.self, from: d)
        #expect(r.used == ["leaf", "pot"])
        #expect(r.tips?.first?.shotKind == .underside)
        let body = try JSONEncoder().encode([Brain.PhotoPart(photo: "abc", kind: ShotKind.whole.rawValue)])
        #expect(String(decoding: body, as: UTF8.self).contains(#""kind":"whole""#))
    }
}

/// First-look leaves, no fixed fallback guesses, identify timeout.
@MainActor struct ScanFixTests {
    @Test func wholePlantLeavesAreJudged() {
        var r = PhotoRead(); r.greenShare = 0.04
        #expect(r.health == .unknown)
        r.wholePlant = true
        #expect(r.health != .unknown)
        var q = PhotoRead(); q.sceneHasLeaves = true
        #expect(q.health != .unknown)
    }

    @Test func genericLabelsGiveNoGuesses() {
        var r = PhotoRead(); r.labels = [("houseplant", 0.9), ("foliage", 0.8), ("potted_plant", 0.7), ("flower", 0.6)]
        #expect(PlantIdentifier.candidates(from: r).isEmpty)
    }

    @Test func identifyTimeoutIs12Seconds() { #expect(Brain.identifyTimeout == 12) }
}

/// The live identify reply: a {value, conf} scene with null lists must keep every candidate.
struct IdentifyReplyTests {
    let live = #"{"candidates":[{"id":"maranta-lemon-lime","scientific":"Maranta leuconeura 'Lemon Lime'","name":"x","score":0.15},{"id":"maranta","scientific":"Maranta leuconeura","name":"y","score":0.08}],"confident":false,"scene":{"plant":{"heightCm":{"value":null,"conf":0},"stage":{"value":"seedling","conf":0.6},"issues":null,"artificial":{"value":false,"conf":0.75},"multiple":{"value":"unknown","conf":0}},"pot":{"material":{"value":"plastic","conf":0.52},"drainage":{"value":"unknown","conf":0},"cachepot":{"value":"unknown","conf":0}},"soil":{"medium":{"value":"soil","conf":0.42},"surface":null},"surroundings":{"room":{"value":"balcony","conf":0.72},"near":[]}},"sceneDepth":"quick","used":["leaf","whole"],"tips":[]}"#

    @Test func liveReplyKeepsCandidatesAndReadsScene() throws {
        let r = try JSONDecoder().decode(Brain.IdentifyReply.self, from: Data(live.utf8))
        #expect(r.candidates?.map(\.id) == ["maranta-lemon-lime", "maranta"])
        let s = try #require(r.scene)
        #expect(s.looksAlive)
        #expect(!s.artificial)
        #expect(s.isOutdoor == true)
        #expect(s.plant?.lifeStage == "seedling")
        #expect(s.soil?.medium == "soil" && !s.potSure)
    }

    @Test func brokenSceneNeverDropsCandidates() throws {
        let odd = #"{"candidates":[{"id":"maranta","scientific":"Maranta leuconeura","score":0.3}],"scene":{"plant":42,"pot":"x"},"used":7}"#
        let r = try JSONDecoder().decode(Brain.IdentifyReply.self, from: Data(odd.utf8))
        #expect(r.candidates?.first?.id == "maranta")
    }
}
