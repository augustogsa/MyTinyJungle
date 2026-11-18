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
        func known(_ words: String...) -> Species.Problem? { s?.problems?.first { p in words.contains { p.sign.folded.contains($0) } } }

        if yellow > 0.1 {
            let wet = r.soilMoisture == .wet || (sinceWater.map { w in expected.map { w < $0 * 0.6 } ?? false } ?? false)
            if wet {
                out.append(.init(title: String(localized: "Too much water, most likely", comment: "Photo diagnosis finding title. Short."), detail: known("wet", "molhad", "encharc", "excesso de agua")?.fix ?? (s?.waterStyle == .moist ? String(localized: "Let the soil dry on top before the next drink, and make sure the pot drains.", comment: "Photo diagnosis advice: overwatering, plant likes moist soil.") : String(localized: "Let the soil dry well down before the next drink, and make sure the pot drains.", comment: "Photo diagnosis advice: overwatering."))))
            } else if r.soilMoisture == .dry {
                out.append(.init(title: String(localized: "Thirsty and stressed", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "Dry soil with yellowing: water deeply until it drains, then keep a steadier rhythm.", comment: "Photo diagnosis advice.")))
            } else if let p = known("yellow", "amarel") {
                out.append(.init(title: p.sign, detail: String(localized: "\(p.cause). \(p.fix)", comment: "Photo diagnosis: cause and fix sentences from the species data. Keep punctuation.")))
            } else {
                out.append(.init(title: String(localized: "Some yellowing", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "Old lower leaves yellow naturally. On new leaves, check light and food.", comment: "Photo diagnosis advice.")))
            }
        }
        if brown > 0.1 {
            if let p = known("brown", "marrom", "castanh") ?? known("crisp", "seca", "queimad") {
                out.append(.init(title: p.sign, detail: String(localized: "\(p.cause). \(p.fix)", comment: "Photo diagnosis: cause and fix sentences from the species data. Keep punctuation.")))
            } else if (s?.humidityMin ?? 40) >= 50 {
                out.append(.init(title: String(localized: "Dry air", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "\(s?.commonName ?? String(localized: "This plant", comment: "Fallback subject when species is unknown.")) likes \(Int(s?.humidityMin ?? 50))%+ humidity. Group plants or use a humidifier.", comment: "Photo diagnosis advice. Args: plant common name, minimum humidity percent.")))
            } else {
                out.append(.init(title: String(localized: "Brown patches", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "Check for sunburn on the sunny side, or a long dry spell.", comment: "Photo diagnosis advice.")))
            }
        }
        if r.greenShare < 0.12, yellow < 0.1, r.health != .unknown, let s, s.light == .bright || s.light == .direct {
            out.append(.init(title: String(localized: "Pale growth", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "Leaves look washed out. \(s.lightRule)", comment: "Photo diagnosis advice. %@ = the species light rule sentence.")))
        }
        if r.soilVisible, let m = r.soilMoisture {
            switch m {
            case .dry where s?.waterStyle == .moist: out.append(.init(title: String(localized: "Soil looks dry", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "\(s?.commonName ?? "") likes to stay lightly moist. Water today.", comment: "Photo diagnosis advice. %@ = plant common name.")))
            case .wet where s?.waterStyle == .dry: out.append(.init(title: String(localized: "Soil looks wet", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "\(s?.commonName ?? "") wants to dry out fully. Hold off and check the drainage.", comment: "Photo diagnosis advice. %@ = plant common name.")))
            default: break
            }
        }
        if out.isEmpty, r.health == .lush || r.health == .good {
            out.append(.init(title: String(localized: "Looking healthy", comment: "Photo diagnosis finding title. Short."), detail: String(localized: "Keep the routine. \(s?.tip ?? "")", comment: "Photo diagnosis: plant looks healthy. %@ = a species care tip sentence (may be empty).")))
        }
        // Nutrient hints from where the yellow shows up is beyond a photo; point to the leaf-language lesson instead.
        if yellow > 0.2, r.soilMoisture != .wet, let iron = Knowledge.shared.deficiencies.first(where: { $0.id == (s?.phMax ?? 7 <= 6 ? "iron" : "nitrogen") }) {
            out.append(.init(title: String(localized: "Could be hunger (\(iron.name.lowercased()))", comment: "Photo diagnosis finding title: possible nutrient deficiency. %@ = nutrient name, lowercase."), detail: "\(iron.signs) \(iron.fix)"))
        }
        if let pest = s?.pestList.first, r.health == .someStress || r.health == .stressed {
            out.append(.init(title: String(localized: "Rule out \(pest.name.lowercased())", comment: "Photo diagnosis finding title: check for a pest. %@ = pest name, lowercase."), detail: "\(pest.signs) \(pest.fix)"))
        }
        return out
    }
}
