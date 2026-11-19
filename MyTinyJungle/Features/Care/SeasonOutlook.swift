import SwiftUI

/// The next three months at a glance: rest, food, repotting, frost and spring moves, from your climate.
@MainActor
enum SeasonOutlook {
    struct Line: Hashable { let symbol: String; let text: String }
    struct Month: Identifiable { let id: Int; let date: Date; let lines: [Line] }

    static func months(_ plants: [Plant], now: Date = Date(), count: Int = 3) -> [Month] {
        let cal = Calendar.current, c = Climate.shared
        let live = plants.filter { !$0.isArchived && !$0.isArtificial }
        func names(_ ps: [Plant]) -> String { ps.prefix(3).map(\.name).formatted(.list(type: .and)) }
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return (0..<count).compactMap { i -> Month? in
            guard let m = cal.date(byAdding: .month, value: i, to: start), let prev = cal.date(byAdding: .month, value: -1, to: m),
                  let mid = cal.date(byAdding: .day, value: 14, to: m) else { return nil }
            var out: [Line] = []
            if c.isGrowing(prev) && !c.isGrowing(mid) {
                out.append(.init(symbol: "moon.zzz", text: Grammar.pt(String(localized: "Resting season begins: water less and stop feeding until spring.", comment: "Season outlook line for a coming month; warm, practical."))))
            }
            if !c.isGrowing(prev) && c.isGrowing(mid) {
                out.append(.init(symbol: "leaf.arrow.triangle.circlepath", text: Grammar.pt(String(localized: "Growing season is back: start feeding gently, at half strength at first.", comment: "Season outlook line for a coming month; warm, practical."))))
            }
            if c.phase(mid) == .spring {
                let due = live.filter { p in
                    guard let s = p.species, p.growingMedium.inPot, p.growingMedium != .terrarium else { return false }
                    return CareEngine.days(from: p.lastRepotAt ?? p.acquiredAt, to: mid) > s.repotYears * 365 - 30 || p.sizeFit == .tooSmall
                }
                if !due.isEmpty { out.append(.init(symbol: "arrow.up.bin.fill", text: Grammar.pt(String(localized: "Repot window: \(names(due)) could move to a roomier pot.", comment: "Season outlook line for a coming month; warm, practical.")))) }
            }
            if let t = c.monthTemp(mid) {
                let cold = live.filter { p in p.isOutdoor && t < (p.species?.tempMin ?? 10) + 3 }
                if !cold.isEmpty { out.append(.init(symbol: "snowflake", text: Grammar.pt(String(localized: "Frost risk: bring \(names(cold)) inside before nights get cold.", comment: "Season outlook line for a coming month; warm, practical.")))) }
                let wasCold = (c.monthTemp(prev) ?? t) < t
                let outGo = live.filter { p in !p.isOutdoor && p.species?.outdoor == true && wasCold && t >= (p.species?.tempMin ?? 10) + 6 }
                if !outGo.isEmpty { out.append(.init(symbol: "sun.horizon.fill", text: Grammar.pt(String(localized: "Spring move: \(names(outGo)) can summer outside. Start in shade and add sun over 1–2 weeks.", comment: "Season outlook line for a coming month; warm, practical.")))) }
            }
            if c.isPeakSummer(mid) {
                out.append(.init(symbol: "sun.max.fill", text: Grammar.pt(String(localized: "Peak warmth: pots dry faster, so check more often and shade from harsh afternoon sun.", comment: "Season outlook line for a coming month; warm, practical."))))
            }
            if out.isEmpty { out.append(.init(symbol: "checkmark.seal", text: Grammar.pt(String(localized: "A steady month: keep the rhythm you have.", comment: "Season outlook line for a coming month; warm, practical.")))) }
            return Month(id: i, date: m, lines: out)
        }
    }
}

struct SeasonOutlookCard: View {
    let plants: [Plant]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(Grammar.pt(String(localized: "The months ahead", comment: "Care tab section title: season outlook for the next 3 months; max 24 chars")))
            VStack(alignment: .leading, spacing: 14) {
                ForEach(SeasonOutlook.months(plants)) { m in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(m.date.formatted(.dateTime.month(.wide))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        ForEach(m.lines, id: \.self) { l in
                            Label { Text(l.text).font(.subheadline).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: l.symbol).foregroundStyle(Jungle.accentText).frame(width: 24) }
                                .foregroundStyle(Jungle.text)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
        }
    }
}
