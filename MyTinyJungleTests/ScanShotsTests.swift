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

/// Crop to reticle, first-look leaves, no fixed fallback guesses, identify timeout.
@MainActor struct ScanFixTests {
    @Test func cropMapsReticleThroughAspectFill() throws {
        let r = try #require(ScanCrop.rect(image: CGSize(width: 3000, height: 4000), preview: CGRect(x: 0, y: 0, width: 390, height: 844), reticle: CGRect(x: 50, y: 200, width: 290, height: 362)))
        let s = 844.0 / 4000.0, ox = (390 - 3000 * s) / 2
        #expect(abs(r.minX - (50 - ox) / s) < 2)
        #expect(abs(r.minY - 200 / s) < 2)
        #expect(abs(r.width - 290 / s) < 2)
        #expect(ScanCrop.rect(image: .zero, preview: .zero, reticle: .zero) == nil)
    }

    @Test func cropOutputIsTheReticleSize() throws {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { c in UIColor.green.setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: 400)) }
        let d = try #require(ScanCrop.crop(img, preview: CGRect(x: 0, y: 0, width: 300, height: 400), reticle: CGRect(x: 50, y: 100, width: 200, height: 160)))
        let out = try #require(UIImage(data: d))
        #expect(out.size.width * out.scale == 200 && out.size.height * out.scale == 160)
    }

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
