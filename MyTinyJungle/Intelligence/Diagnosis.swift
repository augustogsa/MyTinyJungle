import Foundation

/// Turns a photo read + the plant's own history into likely causes, matched to the species' known problems.
enum Diagnosis {
    struct Finding: Hashable { let title: String; let detail: String }

    static func findings(_ r: PhotoRead, species s: Species?, plant: Plant? = nil, now: Date = Date()) -> [Finding] {
        var out: [Finding] = []
        let foliage = max(r.greenShare + r.yellowShare + r.brownShare, 0.0001)
        let yellow = r.yellowShare / foliage, brown = r.brownShare / foliage
        let sinceWater = plant?.lastEvent(.water).map { CareEngine.days(from: $0.date, to: now) }
        let expected = plant.map { CareEngine.expectedDryDays(for: $0, at: now) }
        func known(_ word: String) -> Species.Problem? { s?.problems?.first { $0.sign.folded.contains(word) } }

        if yellow > 0.1 {
            let wet = r.soilMoisture == .wet || (sinceWater.map { w in expected.map { w < $0 * 0.6 } ?? false } ?? false)
            if wet {
                out.append(.init(title: "Too much water, most likely", detail: known("wet")?.fix ?? "Let the soil dry \(s?.waterStyle == .moist ? "on top" : "well down") before the next drink, and make sure the pot drains."))
            } else if r.soilMoisture == .dry {
                out.append(.init(title: "Thirsty and stressed", detail: "Dry soil with yellowing: water deeply until it drains, then keep a steadier rhythm."))
            } else if let p = known("yellow") {
                out.append(.init(title: p.sign, detail: "\(p.cause). \(p.fix)"))
            } else {
                out.append(.init(title: "Some yellowing", detail: "Old lower leaves yellow naturally. On new leaves, check light and food."))
            }
        }
        if brown > 0.1 {
            if let p = known("brown") ?? known("crisp") {
                out.append(.init(title: p.sign, detail: "\(p.cause). \(p.fix)"))
            } else if (s?.humidityMin ?? 40) >= 50 {
                out.append(.init(title: "Dry air", detail: "\(s?.en ?? "This plant") likes \(Int(s?.humidityMin ?? 50))%+ humidity. Group plants or use a humidifier."))
            } else {
                out.append(.init(title: "Brown patches", detail: "Check for sunburn on the sunny side, or a long dry spell."))
            }
        }
        if r.greenShare < 0.12, yellow < 0.1, r.health != .unknown, let s, s.light == .bright || s.light == .direct {
            out.append(.init(title: "Pale growth", detail: "Leaves look washed out. \(s.lightRule)"))
        }
        if r.soilVisible, let m = r.soilMoisture {
            switch m {
            case .dry where s?.waterStyle == .moist: out.append(.init(title: "Soil looks dry", detail: "\(s?.en ?? "It") likes to stay lightly moist. Water today."))
            case .wet where s?.waterStyle == .dry: out.append(.init(title: "Soil looks wet", detail: "\(s?.en ?? "It") wants to dry out fully. Hold off and check the drainage."))
            default: break
            }
        }
        if out.isEmpty, r.health == .lush || r.health == .good {
            out.append(.init(title: "Looking healthy", detail: "Keep the routine. \(s?.tip ?? "")"))
        }
        if let pest = s?.pestList.first, r.health == .someStress || r.health == .stressed {
            out.append(.init(title: "Rule out \(pest.name.lowercased())", detail: "\(pest.signs) \(pest.fix)"))
        }
        return out
    }
}
