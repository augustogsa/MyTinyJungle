import Foundation
import SwiftData

/// Every kind of care the jungle can remind you about. Each can be switched off in Settings.
enum ReminderKind: String, CaseIterable, Identifiable, Codable {
    case water, soilCheck, feed, mist, rotate, repot, prune, clean, pests, propagation, seasonal, travel, weather
    var id: String { rawValue }
    var title: String {
        switch self {
        case .water: Grammar.pt(String(localized: "Drinks", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .soilCheck: Grammar.pt(String(localized: "Soil hellos", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .feed: Grammar.pt(String(localized: "Plant snacks", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .mist: Grammar.pt(String(localized: "Misty mornings", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .rotate: Grammar.pt(String(localized: "Little turns", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .repot: Grammar.pt(String(localized: "Roomier pots", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .prune: Grammar.pt(String(localized: "Trims", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .clean: Grammar.pt(String(localized: "Leaf baths", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .pests: Grammar.pt(String(localized: "Bug peeks", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .propagation: Grammar.pt(String(localized: "Baby plants", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .seasonal: Grammar.pt(String(localized: "Seasonal moves", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .travel: Grammar.pt(String(localized: "Trip prep", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        case .weather: Grammar.pt(String(localized: "Frost and heat", comment: "Reminder kind title in Settings, playful. Max 22 chars."))
        }
    }
    var blurb: String {
        switch self {
        case .water: Grammar.pt(String(localized: "When someone's thirsty", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .soilCheck: Grammar.pt(String(localized: "A quick finger in the soil", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .feed: Grammar.pt(String(localized: "Food in the growing months", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .mist: Grammar.pt(String(localized: "For the humidity lovers", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .rotate: Grammar.pt(String(localized: "So everyone grows straight", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .repot: Grammar.pt(String(localized: "When roots want more room", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .prune: Grammar.pt(String(localized: "A tidy-up in spring", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .clean: Grammar.pt(String(localized: "Dust off so leaves can breathe", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .pests: Grammar.pt(String(localized: "A gentle look under leaves", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .propagation: Grammar.pt(String(localized: "Checking on your cuttings", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .seasonal: Grammar.pt(String(localized: "Moving in or out with the seasons", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .travel: Grammar.pt(String(localized: "Getting everyone ready before you go", comment: "Reminder kind subtitle in Settings, short and warm."))
        case .weather: Grammar.pt(String(localized: "Heads-ups for plants outside", comment: "Reminder kind subtitle in Settings, short and warm."))
        }
    }
    var icon: Icon3D {
        switch self {
        case .water: .waterDrops
        case .soilCheck: .soilTest
        case .feed: .fertilizer
        case .mist: .mistRain
        case .rotate: .repeat
        case .repot: .pot
        case .prune: .tools
        case .clean: .leaves
        case .pests: .bug
        case .propagation: .seedling
        case .seasonal: .autumnLeaf
        case .travel: .travel
        case .weather: .frost
        }
    }
    var careKind: CareKind {
        switch self {
        case .water: .water
        case .soilCheck: .soilCheck
        case .feed: .feed
        case .mist: .mist
        case .rotate: .rotate
        case .repot: .repot
        case .prune: .prune
        case .clean: .clean
        case .pests: .health
        case .propagation: .propagate
        case .seasonal, .weather: .move
        case .travel: .water
        }
    }
}

/// Your reminder wishes: time, quiet hours, which kinds.
enum CarePrefs {
    private static let d = UserDefaults.standard
    static var minute: Int {
        get { d.object(forKey: "careReminderMinute") as? Int ?? 0 }
        set { d.set(newValue, forKey: "careReminderMinute") }
    }
    static var quietOn: Bool {
        get { d.object(forKey: "quietOn") as? Bool ?? true }
        set { d.set(newValue, forKey: "quietOn") }
    }
    static var quietStart: Int {
        get { d.object(forKey: "quietStart") as? Int ?? 21 }
        set { d.set(newValue, forKey: "quietStart") }
    }
    static var quietEnd: Int {
        get { d.object(forKey: "quietEnd") as? Int ?? 8 }
        set { d.set(newValue, forKey: "quietEnd") }
    }
    static var chatNudges: Bool {
        get { d.object(forKey: "chatNudges") as? Bool ?? true }
        set { d.set(newValue, forKey: "chatNudges") }
    }
    static func isOn(_ k: ReminderKind) -> Bool { d.object(forKey: "remind.\(k.rawValue)") as? Bool ?? true }
    static func set(_ k: ReminderKind, _ on: Bool) { d.set(on, forKey: "remind.\(k.rawValue)") }

    static func isQuiet(hour h: Int) -> Bool {
        guard quietOn, quietStart != quietEnd else { return false }
        return quietStart < quietEnd ? (h >= quietStart && h < quietEnd) : (h >= quietStart || h < quietEnd)
    }
    /// Pushes a time out of quiet hours to the moment they end.
    static func gentle(_ date: Date) -> Date {
        let cal = Calendar.current
        guard isQuiet(hour: cal.component(.hour, from: date)) else { return date }
        var day = cal.startOfDay(for: date)
        if cal.component(.hour, from: date) >= quietStart && quietStart > quietEnd { day = cal.date(byAdding: .day, value: 1, to: day)! }
        return cal.date(bySettingHour: quietEnd, minute: 0, second: 0, of: day) ?? date
    }

    // Trip saved from Going away.
    static var trip: (leave: Date, back: Date)? {
        get {
            guard let l = d.object(forKey: "trip.leave") as? Date, let b = d.object(forKey: "trip.back") as? Date, b > Date() else { return nil }
            return (l, b)
        }
        set {
            d.set(newValue?.leave, forKey: "trip.leave")
            d.set(newValue?.back, forKey: "trip.back")
        }
    }
}

struct ForecastItem: Identifiable, Hashable {
    let plantID: UUID?
    let plantName: String
    let date: Date
    let kind: ReminderKind
    /// Short, warm line ("Pesto will be thirsty Friday").
    let line: String
    var id: String { "\(plantID?.uuidString ?? "jungle")-\(kind.rawValue)-\(Int(date.timeIntervalSince1970 / 86_400))" }
}

/// Looks two weeks ahead for every plant. Pure: it reads the care log, species, pot, season and weather.
enum CareForecast {
    static let horizon = 14
    private static let cal = Calendar.current

    static func items(for plants: [Plant], propagations: [Propagation] = [], days: Int = horizon, now: Date = Date(), respectPrefs: Bool = true) -> [ForecastItem] {
        var out = plants.filter { !$0.isArchived }.flatMap { plant(for: $0, days: days, now: now) }
        out += propagationItems(propagations, plants: plants, now: now, days: days)
        out += travelItems(plants, now: now, days: days)
        out += weatherItems(plants, now: now)
        if respectPrefs { out = out.filter { CarePrefs.isOn($0.kind) } }
        return out.sorted { $0.date < $1.date }
    }

    static func plant(for p: Plant, days: Int = horizon, now: Date = Date()) -> [ForecastItem] {
        let end = now.addingTimeInterval(Double(days) * 86_400)
        let s = p.species
        var out: [ForecastItem] = []
        func add(_ d: Date, _ k: ReminderKind, _ line: String) {
            guard d <= end else { return }
            out.append(.init(plantID: p.id, plantName: p.name, date: max(d, now), kind: k, line: line))
        }

        // Water: when the substrate should be dry, from the learned rhythm.
        let expected = CareEngine.expectedDryDays(for: p, at: now)
        if let w = p.lastEvent(.water)?.date {
            var next = w.addingTimeInterval(expected * 86_400)
            if let c = p.lastEvent(.soilCheck), c.date > w, c.soil != .dry { next = max(next, c.date.addingTimeInterval(max(1, expected * 0.3) * 86_400)) }
            let first = max(next, now)
            add(first, .water, Grammar.pt(String(localized: "\(p.name) will be thirsty \(dayWord(first, now))", comment: "Forecast line on Today/agenda, warm, no final period. Args: plant name, when (today, tomorrow, weekday, next weekday, in N weeks).")))
            let hello = first.addingTimeInterval(-86_400)
            if hello > now { add(hello, .soilCheck, Grammar.pt(String(localized: "A quick soil hello for \(p.name)", comment: "Forecast line on Today/agenda, warm, no final period. Playful: check the soil. %@ = plant name."))) }
            var again = first.addingTimeInterval(expected * 86_400)
            while again <= end { add(again, .water, Grammar.pt(String(localized: "\(p.name) will be thirsty again \(dayWord(again, now))", comment: "Forecast line on Today/agenda, warm, no final period. Args: plant name, when."))); again += expected * 86_400 }
        } else {
            add(now, .soilCheck, Grammar.pt(String(localized: "Say hello to \(p.name)'s soil so we can learn its rhythm", comment: "Forecast line on Today/agenda, warm, no final period. %@ = plant name.")))
        }

        // Feed in the growing season only, skipping fresh soil.
        if let s, s.feed != "none" {
            var f = p.lastEvent(.feed).map { $0.date.addingTimeInterval(s.feedWeeks * 7 * 86_400) } ?? now
            let fresh = p.lastRepotAt.map { $0.addingTimeInterval(42 * 86_400) } ?? .distantPast
            if f < fresh { f = fresh }
            while f <= end {
                if CareEngine.isGrowingSeason(f) { add(f, .feed, Grammar.pt(String(localized: "\(p.name) would love a little snack \(dayWord(max(f, now), now))", comment: "Forecast line on Today/agenda, warm, no final period. Snack = fertilizer, playful. Args: plant name, when."))); break }
                f += 7 * 86_400
            }
        }

        // Mist: humidity lovers, more often when the air or the heating is dry.
        if let s, s.humidityMin >= 60, !p.isOutdoor {
            let every: Double = Climate.shared.indoorFactor(now) < 1 || CareEngine.isWinter(now) ? 2 : 4
            let m = p.lastEvent(.mist).map { $0.date.addingTimeInterval(every * 86_400) } ?? now
            add(m, .mist, Grammar.pt(String(localized: "\(p.name) is dreaming of a misty morning", comment: "Forecast line on Today/agenda, warm, no final period. Misting reminder. %@ = plant name.")))
        }

        // Rotate every two weeks for even growth (not for plants outside).
        if !p.isOutdoor {
            let r = p.lastEvent(.rotate).map { $0.date.addingTimeInterval(14 * 86_400) } ?? now.addingTimeInterval(3 * 86_400)
            add(r, .rotate, Grammar.pt(String(localized: "Give \(p.name) a little turn toward the light", comment: "Forecast line on Today/agenda, warm, no final period. %@ = plant name.")))
        }

        // Clean leaves monthly; big leaves gather dust.
        // Never-done tasks are spread across the fortnight so day one isn't a pile.
        func slot(_ period: Int, _ shift: Int) -> Date {
            let day = Int(now.timeIntervalSince1970 / 86_400)
            let off = ((Int(p.id.uuid.0) + shift - day) % period + period) % period
            return now.addingTimeInterval(Double(off) * 86_400)
        }
        let c = p.lastEvent(.clean).map { $0.date.addingTimeInterval(30 * 86_400) } ?? slot(30, 0)
        add(c, .clean, Grammar.pt(String(localized: "\(p.name)'s leaves would love a soft wipe", comment: "Forecast line on Today/agenda, warm, no final period. %@ = plant name.")))

        // Pest peek every three weeks, weekly for species prone to pests in dry warm rooms.
        let prone = !(s?.pests ?? []).isEmpty
        let pestEvery: Double = prone && Climate.shared.indoorFactor(now) < 1 ? 10 : 21
        let pk = (p.lastEvent(.health)?.date ?? p.lastEvent(.treat)?.date).map { $0.addingTimeInterval(pestEvery * 86_400) } ?? slot(21, 5)
        add(pk, .pests, prone ? Grammar.pt(String(localized: "A gentle peek under \(p.name)'s leaves for \(s!.pestList.first?.name.lowercased() ?? s!.pests!.first!.lowercased().replacingOccurrences(of: "-", with: " "))", comment: "Forecast line on Today/agenda, warm, no final period. Pest check. Args: plant name, pest name lowercase.")) : Grammar.pt(String(localized: "A gentle peek under \(p.name)'s leaves", comment: "Forecast line on Today/agenda, warm, no final period. Pest check. %@ = plant name.")))

        // Prune: early growing season, once a year.
        if let s, s.growth != "slow" {
            let lastPrune = p.lastEvent(.prune)?.date ?? .distantPast
            if let start = nextSeasonStart(.spring, from: now), CareEngine.days(from: lastPrune, to: start) > 300 {
                add(start, .prune, Grammar.pt(String(localized: "\(p.name) will be ready for a spring trim \(dayWord(start, now))", comment: "Forecast line on Today/agenda, warm, no final period. Args: plant name, when.")))
            }
        }

        // Repot: when overdue, plan it for the next growing window.
        if let s {
            let since = CareEngine.days(from: p.lastRepotAt ?? p.acquiredAt, to: now)
            if since > s.repotYears * 365 - 30 {
                let when = CareEngine.isGrowingSeason(now) ? now.addingTimeInterval(2 * 86_400) : (nextSeasonStart(.spring, from: now) ?? now)
                add(when, .repot, Grammar.pt(String(localized: "\(p.name) could use a roomier pot \(when > end ? String(localized: "in spring", comment: "Time phrase used inside a forecast line.") : dayWord(when, now))", comment: "Forecast line on Today/agenda, warm, no final period. Args: plant name, when.")))
            }
        }

        // Seasonal moves: plants that summer outside come in before the cold, out after the frost.
        if let s, s.outdoor == true || p.isOutdoor {
            let days14 = Climate.shared.upcoming(now, days: days)
            if p.isOutdoor, let cold = days14.first(where: { $0.tMin < s.tempMin + 2 }) {
                add(cold.date.addingTimeInterval(-86_400), .seasonal, Grammar.pt(String(localized: "Time to bring \(p.name) inside before nights drop to \(Climate.temp(cold.tMin))", comment: "Forecast line on Today/agenda, warm, no final period. Args: plant name, formatted temperature.")))
            } else if !p.isOutdoor, CareEngine.isGrowingSeason(now), !days14.isEmpty, days14.allSatisfy({ $0.tMin >= s.tempMin + 4 }) {
                add(now.addingTimeInterval(86_400), .seasonal, Grammar.pt(String(localized: "Nights are soft now. \(p.name) could enjoy some summer outside", comment: "Forecast line on Today/agenda, warm, no final period. Mild nights. %@ = plant name.")))
            }
        }
        return out
    }

    static func propagationItems(_ props: [Propagation], plants: [Plant], now: Date, days: Int) -> [ForecastItem] {
        props.compactMap { pr in
            guard pr.stage != .done else { return nil }
            let parent = plants.first { $0.id == pr.parentID }?.name ?? Grammar.pt(String(localized: "your cutting", comment: "Fallback for a parent plant name in propagation reminders."))
            let weeks: Double = pr.stage == .cutting ? 1 : pr.stage == .rooting ? 3 : 2
            let d = max(now, pr.startedAt.addingTimeInterval(weeks * 7 * 86_400))
            guard d <= now.addingTimeInterval(Double(days) * 86_400) else { return nil }
            let line = switch pr.stage {
            case .cutting: Grammar.pt(String(localized: "Peek at \(parent)'s cutting and freshen its water", comment: "Forecast line on Today/agenda, warm, no final period. %@ = parent plant name."))
            case .rooting: Grammar.pt(String(localized: "\(parent)'s baby might have roots long enough to pot", comment: "Forecast line on Today/agenda, warm, no final period. Baby = cutting (pt: mudinha). %@ = parent plant name."))
            case .potting: Grammar.pt(String(localized: "Time to tuck \(parent)'s baby into its own pot", comment: "Forecast line on Today/agenda, warm, no final period. %@ = parent plant name."))
            default: Grammar.pt(String(localized: "See how \(parent)'s little one is growing", comment: "Forecast line on Today/agenda, warm, no final period. %@ = parent plant name."))
            }
            return ForecastItem(plantID: pr.parentID, plantName: parent, date: d, kind: .propagation, line: line)
        }
    }

    static func travelItems(_ plants: [Plant], now: Date, days: Int) -> [ForecastItem] {
        guard let trip = CarePrefs.trip, trip.leave > now.addingTimeInterval(-86_400) else { return [] }
        let away = trip.back.timeIntervalSince(trip.leave) / 86_400
        let eve = max(now, trip.leave.addingTimeInterval(-86_400))
        var out = [ForecastItem(plantID: nil, plantName: "", date: eve, kind: .travel, line: Grammar.pt(String(localized: "Tomorrow you travel. Give everyone a deep, slow drink tonight", comment: "Forecast line on Today/agenda, warm, no final period. Trip prep.")))]
        for p in plants where CareEngine.expectedDryDays(for: p) * 1.3 < away {
            out.append(.init(plantID: p.id, plantName: p.name, date: max(now, trip.leave.addingTimeInterval(-2 * 86_400)), kind: .travel, line: Grammar.pt(String(localized: "\(p.name) will need a sitter or a wick while you're away", comment: "Forecast line on Today/agenda, warm, no final period. Trip prep. %@ = plant name."))))
        }
        return out
    }

    static func weatherItems(_ plants: [Plant], now: Date) -> [ForecastItem] {
        Climate.shared.alerts(for: plants, now: now).map { a in
            ForecastItem(plantID: nil, plantName: "", date: now, kind: .weather, line: a.title)
        }
    }

    // MARK: helpers

    static func nextSeasonStart(_ phase: Climate.Phase, from now: Date) -> Date? {
        var d = cal.startOfDay(for: now)
        if Climate.shared.phase(d) == phase { return d }
        for _ in 0..<370 {
            d = cal.date(byAdding: .day, value: 1, to: d)!
            if Climate.shared.phase(d) == phase { return d }
        }
        return nil
    }

    static func dayWord(_ d: Date, _ now: Date = Date()) -> String {
        if cal.isDate(d, inSameDayAs: now) { return Grammar.pt(String(localized: "today", comment: "Time phrase at the end of a forecast line ('Milo will be thirsty today').")) }
        if cal.isDate(d, inSameDayAs: now.addingTimeInterval(86_400)) { return Grammar.pt(String(localized: "tomorrow", comment: "Time phrase at the end of a forecast line.")) }
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
        let weekday = d.formatted(.dateTime.weekday(.wide))
        if n < 7 { return Grammar.pt(String(localized: "on \(weekday)", comment: "Time phrase at the end of a forecast line. %@ = weekday name (e.g. 'Friday'). pt: just the weekday, no preposition.")) }
        if n < 14 { return Grammar.pt(String(localized: "next \(weekday)", comment: "Time phrase at the end of a forecast line. %@ = weekday name. pt: use '%@ que vem' to avoid gender agreement.")) }
        if n < 60 { return Grammar.pt(String(localized: "in \(n / 7) weeks", comment: "Time phrase at the end of a forecast line. %lld = weeks (plural).")) }
        return Grammar.pt(String(localized: "in \(d.formatted(.dateTime.month(.wide)))", comment: "Time phrase at the end of a forecast line. %@ = month name."))
    }
}

/// Warm observations for Today and chat: patterns, streaks, milestones, gentle check-ins.
struct JungleInsight: Identifiable, Hashable {
    enum Tone { case comingUp, pattern, streak, milestone, missYou }
    let id: String
    let plantID: UUID?
    let tone: Tone
    let icon: Icon3D
    let text: String
}

enum InsightEngine {
    static func insights(plants: [Plant], propagations: [Propagation] = [], now: Date = Date()) -> [JungleInsight] {
        var out: [JungleInsight] = []
        let live = plants.filter { !$0.isArchived }
        // Coming up: one gentle line per plant, the soonest, skipping today (Today's care covers that).
        let forecast = CareForecast.items(for: live, propagations: propagations, now: now)
        var seen = Set<String>()
        for f in forecast where !Calendar.current.isDate(f.date, inSameDayAs: now) || f.kind == .weather || f.kind == .travel {
            let key = f.plantID?.uuidString ?? f.kind.rawValue
            guard !seen.contains(key), [.water, .repot, .feed, .weather, .travel, .seasonal, .propagation, .prune].contains(f.kind) else { continue }
            seen.insert(key)
            out.append(.init(id: f.id, plantID: f.plantID, tone: .comingUp, icon: f.kind.icon, text: Grammar.pt(String(localized: "\(f.line).", comment: "Insight card: a forecast line as a sentence, adds the final period. Keep as is."))))
        }
        for p in live {
            // Missed checks already show as Today's care; only patterns go here.
            if let pat = pattern(for: p, now: now), !pat.id.hasSuffix("-missed") { out.append(pat) }
            let streak = careStreak(p, now: now)
            if streak >= 3 {
                out.append(.init(id: "\(p.id)-streak", plantID: p.id, tone: .streak, icon: .award, text: Grammar.pt(String(localized: "\(streak) waterings in a row right on time for \(p.name). You two have a rhythm.", comment: "Insight: care streak. Args: count (plural), plant name."))))
            }
            let age = Int(CareEngine.days(from: p.acquiredAt, to: now))
            for m in [30, 100, 180, 365, 730] where age >= m && age < m + 7 {
                out.append(.init(id: "\(p.id)-age\(m)", plantID: p.id, tone: .milestone, icon: .celebrate, text: m >= 365 ? Grammar.pt(String(localized: "\(m / 365) years together with \(p.name) this week. Happy plantiversary!", comment: "Insight: anniversary. Args: years (plural), plant name. Plantiversary = playful 'plant anniversary' (pt: plantiversário).")) : Grammar.pt(String(localized: "\(p.name) has been with you \(m) days. Look how far you've come.", comment: "Insight: milestone. Args: plant name, days (plural)."))))
            }
            let leaves = (p.events ?? []).filter { $0.kind == .newLeaf && CareEngine.days(from: $0.date, to: now) < 30 }.count
            if leaves >= 2 { out.append(.init(id: "\(p.id)-leaves", plantID: p.id, tone: .milestone, icon: .growth, text: Grammar.pt(String(localized: "\(leaves) new leaves on \(p.name) this month. It's happy with you.", comment: "Insight. Args: count (plural), plant name.")))) }
            let last = p.sortedEvents.first?.date ?? p.createdAt
            if CareEngine.days(from: last, to: now) > 10 {
                out.append(.init(id: "\(p.id)-miss", plantID: p.id, tone: .missYou, icon: .heartPin, text: Grammar.pt(String(localized: "\(p.name) hasn't had a visit in a while. A quick hello would make its day.", comment: "Insight: plant misses you. %@ = plant name."))))
            }
        }
        let order: [JungleInsight.Tone] = [.pattern, .comingUp, .milestone, .streak, .missYou]
        return out.sorted { (order.firstIndex(of: $0.tone) ?? 9) < (order.firstIndex(of: $1.tone) ?? 9) }
    }

    /// Overwatering and missed checks, read from the real log.
    static func pattern(for p: Plant, now: Date = Date()) -> JungleInsight? {
        let ev = p.sortedEvents.filter { CareEngine.days(from: $0.date, to: now) < 30 }
        let waters = ev.filter { $0.kind == .water }.map(\.date).sorted()
        let expected = CareEngine.expectedDryDays(for: p, at: now)
        let wetChecks = ev.filter { $0.kind == .soilCheck && $0.soil == .wet }.count
        if waters.count >= 3 {
            let gaps = zip(waters.dropFirst(), waters).map { CareEngine.days(from: $1, to: $0) }
            let avg = gaps.reduce(0, +) / Double(gaps.count)
            if avg < expected * 0.55 || wetChecks >= 2 {
                return .init(id: "\(p.id)-over", plantID: p.id, tone: .pattern, icon: .puddle, text: Grammar.pt(String(localized: "\(p.name) has been getting drinks closer together than it dries. Let it rest a few days and feel the soil first.", comment: "Insight: overwatering pattern. %@ = plant name.")))
            }
        }
        if let w = p.lastEvent(.water)?.date, CareEngine.days(from: w, to: now) > expected * 1.6,
           (p.lastEvent(.soilCheck)?.date ?? .distantPast) < w {
            return .init(id: "\(p.id)-missed", plantID: p.id, tone: .pattern, icon: .wilted, text: Grammar.pt(String(localized: "It's been a while since anyone checked on \(p.name). It may be quietly thirsty.", comment: "Insight: missed check. %@ = plant name.")))
        }
        return nil
    }

    /// Consecutive waterings within ±35% of the expected rhythm.
    static func careStreak(_ p: Plant, now: Date = Date()) -> Int {
        let waters = (p.events ?? []).filter { $0.kind == .water }.map(\.date).sorted(by: >)
        guard waters.count >= 2 else { return 0 }
        let expected = CareEngine.expectedDryDays(for: p, at: now)
        var n = 0
        for (a, b) in zip(waters, waters.dropFirst()) {
            let gap = CareEngine.days(from: b, to: a)
            if abs(gap - expected) <= expected * 0.35 { n += 1 } else { break }
        }
        return n
    }
}

/// Plants speak up in chat on their own: once a day at most per plant, three a day for the jungle.
enum ProactiveVoice {
    @MainActor
    static func speak(_ ctx: ModelContext, now: Date = Date()) {
        guard CarePrefs.chatNudges else { return }
        let plants = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let d = UserDefaults.standard
        let today = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        var spoken = 0
        for p in plants where spoken < 3 {
            let key = "voice.\(p.id)"
            guard d.integer(forKey: key) != today else { continue }
            var text: String?
            var chips: [String] = []
            if let pat = InsightEngine.pattern(for: p, now: now) {
                text = voice(pat, plant: p)
                chips = JungleBrain.soilChips
            } else if let r = CareEngine.requests(for: p, now: now).first(where: { $0.priority <= 1 && ($0.kind == .water || $0.kind == .checkSoil) }) {
                text = PlantVoice.say(r, plant: p)
                chips = r.kind == .water ? [JungleBrain.wateredChip] : JungleBrain.soilChips
            } else if let f = CareForecast.plant(for: p, now: now).first(where: { [.feed, .mist, .repot, .prune].contains($0.kind) && Calendar.current.isDate($0.date, inSameDayAs: now) && CarePrefs.isOn($0.kind) }) {
                text = nudge(f.kind, plant: p)
            }
            guard let text else { continue }
            d.set(today, forKey: key)
            JungleBrain.reply(text, plant: p, in: ctx, suggestions: chips, alsoJungle: true)
            spoken += 1
        }
        if spoken > 0 { try? ctx.save() }
    }

    static func voice(_ i: JungleInsight, plant p: Plant) -> String {
        i.id.hasSuffix("-over")
            ? PlantVoice.pick([Grammar.pt(String(localized: "I've been feeling a bit soggy lately. Could you check my soil before the next drink?", comment: "Plant speaks up on its own in chat: overwatered. Gentle, first person.")), Grammar.pt(String(localized: "My roots like a little breathing room between drinks. Feel me first?", comment: "Plant speaks up on its own in chat: overwatered. Gentle, first person."))], seed: p.name)
            : PlantVoice.pick([Grammar.pt(String(localized: "Hey, it's me. Haven't seen you in a few days. How does my soil feel?", comment: "Plant speaks up on its own in chat: nobody checked in a while. Friendly, first person.")), Grammar.pt(String(localized: "Just checking in. Could you give my soil a little poke?", comment: "Plant speaks up on its own in chat: asks for a soil check. Friendly, first person."))], seed: p.name)
    }

    static func nudge(_ k: ReminderKind, plant p: Plant) -> String {
        switch k {
        case .feed: Grammar.pt(String(localized: "I'm growing so much. A little snack this week would be lovely.", comment: "Plant speaks up on its own in chat with a gentle care nudge. First person, warm."))
        case .mist: Grammar.pt(String(localized: "The air feels a bit dry. A soft mist would feel like home.", comment: "Plant speaks up on its own in chat with a gentle care nudge. First person, warm."))
        case .repot: Grammar.pt(String(localized: "My roots are getting snug. Maybe a roomier pot soon?", comment: "Plant speaks up on its own in chat with a gentle care nudge. First person, warm."))
        case .prune: Grammar.pt(String(localized: "Spring's here. A light trim would help me grow fuller.", comment: "Plant speaks up on its own in chat with a gentle care nudge. First person, warm."))
        default: Grammar.pt(String(localized: "Thinking of you. Come say hi.", comment: "Plant speaks up on its own in chat with a gentle care nudge. First person, warm."))
        }
    }
}
