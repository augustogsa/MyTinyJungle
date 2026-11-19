import SwiftUI
import UserNotifications

/// Little rewards for caring together: points, a plant-themed level and badges, all worked out
/// from the shared activity log so every phone agrees and nothing extra syncs.
struct CareProfile {
    struct Badge: Identifiable {
        let id: String
        let icon: Icon3D
        let title: String
        let detail: String
        let progress: Double
        var earned: Bool { progress >= 1 }
    }
    struct Level { let index: Int; let title: String; let floor: Int; let next: Int? }

    let member: Member
    let cares: Int
    let waterings: Int
    let covers: Int
    let thanks: Int
    let sitterCares: Int
    let activeDays: Int        // distinct care days in the last 14
    let plants: Int            // distinct plants cared for
    let fairShare: Bool
    var points: Int { cares * 10 + covers * 25 + thanks * 5 + sitterCares * 5 }

    static let floors = [0, 50, 150, 350, 700, 1200]
    static func levelTitle(_ i: Int) -> String {
        switch i {
        case 0: Grammar.pt(String(localized: "Sprout", comment: "Care level 1 title; short"))
        case 1: Grammar.pt(String(localized: "Seedling", comment: "Care level 2 title; short"))
        case 2: Grammar.pt(String(localized: "Green thumb", comment: "Care level 3 title; short"))
        case 3: Grammar.pt(String(localized: "Plant whisperer", comment: "Care level 4 title; short"))
        case 4: Grammar.pt(String(localized: "Jungle keeper", comment: "Care level 5 title; short"))
        default: Grammar.pt(String(localized: "Jungle legend", comment: "Care level 6 title; short"))
        }
    }
    var level: Level {
        let i = Self.floors.lastIndex { points >= $0 } ?? 0
        return Level(index: i, title: Self.levelTitle(i), floor: Self.floors[i], next: i + 1 < Self.floors.count ? Self.floors[i + 1] : nil)
    }
    var levelProgress: Double {
        guard let n = level.next else { return 1 }
        return Double(points - level.floor) / Double(n - level.floor)
    }

    var badges: [Badge] {
        func r(_ a: Int, _ b: Int) -> Double { min(1, Double(a) / Double(b)) }
        return [
            Badge(id: "first", icon: .waterDrops, title: Grammar.pt(String(localized: "First drop", comment: "Badge title")), detail: Grammar.pt(String(localized: "Log your first care", comment: "Badge goal")), progress: r(cares, 1)),
            Badge(id: "buddy", icon: .wateringCan, title: Grammar.pt(String(localized: "Watering buddy", comment: "Badge title")), detail: Grammar.pt(String(localized: "\(min(waterings, 20)) of 20 waterings", comment: "Badge progress")), progress: r(waterings, 20)),
            Badge(id: "neighbour", icon: .careHands, title: Grammar.pt(String(localized: "Good neighbour", comment: "Badge title: covered for someone")), detail: Grammar.pt(String(localized: "Cover for someone once", comment: "Badge goal")), progress: r(covers, 1)),
            Badge(id: "hero", icon: .award, title: Grammar.pt(String(localized: "Cover hero", comment: "Badge title: covered 5 times")), detail: Grammar.pt(String(localized: "\(min(covers, 5)) of 5 covers", comment: "Badge progress")), progress: r(covers, 5)),
            Badge(id: "sitter", icon: .travel, title: Grammar.pt(String(localized: "Plant sitter", comment: "Badge title")), detail: Grammar.pt(String(localized: "Care for a jungle while its people are away", comment: "Badge goal")), progress: r(sitterCares, 1)),
            Badge(id: "trusted", icon: .shieldStar, title: Grammar.pt(String(localized: "Trusted sitter", comment: "Badge title")), detail: Grammar.pt(String(localized: "\(min(sitterCares, 10)) of 10 sitter visits", comment: "Badge progress")), progress: r(sitterCares, 10)),
            Badge(id: "loved", icon: .heartPin, title: Grammar.pt(String(localized: "Much loved", comment: "Badge title: received thanks")), detail: Grammar.pt(String(localized: "\(min(thanks, 5)) of 5 thank-yous", comment: "Badge progress")), progress: r(thanks, 5)),
            Badge(id: "steady", icon: .calendarCheck, title: Grammar.pt(String(localized: "Steady hands", comment: "Badge title: cared on many days")), detail: Grammar.pt(String(localized: "Care on \(min(activeDays, 7)) of 7 days in two weeks", comment: "Badge progress")), progress: r(activeDays, 7)),
            Badge(id: "fair", icon: .clover, title: Grammar.pt(String(localized: "Fair and square", comment: "Badge title: shared care evenly")), detail: Grammar.pt(String(localized: "Do your fair share this month", comment: "Badge goal")), progress: fairShare ? 1 : 0),
            Badge(id: "all", icon: .garden, title: Grammar.pt(String(localized: "Knows every leaf", comment: "Badge title: cared for every plant")), detail: Grammar.pt(String(localized: "Care for 5 different plants", comment: "Badge goal")), progress: r(plants, 5)),
        ]
    }
    var earned: [Badge] { badges.filter(\.earned) }

    /// Role line shown under a name: owner, member, or plant sitter with dates.
    var roleLine: String {
        if let u = member.sittingUntil {
            return u > Date() ? Grammar.pt(String(localized: "Plant sitter until \(u.formatted(.dateTime.weekday(.wide).day()))", comment: "Member role line; %@ date")) : Grammar.pt(String(localized: "Plant sitter", comment: "Badge title"))
        }
        return member.role == .owner ? Grammar.pt(String(localized: "Owner", comment: "Member role")) : Grammar.pt(String(localized: "Member", comment: "Member role"))
    }
}

extension Household {
    func profile(_ m: Member, now: Date = Date()) -> CareProfile {
        let acts = state?.activity ?? []
        let mine = acts.filter { $0.kind == .care && $0.memberID == m.id }
        let cal = Calendar.current
        let recentDays = Set(mine.filter { $0.date > now.addingTimeInterval(-14 * 86_400) }.map { cal.startOfDay(for: $0.date) }).count
        let total = members.count
        let share = balance.first { $0.0.id == m.id }?.1 ?? 0
        let fair = total > 1 && load(m.id, now) >= 3 && share >= (1.0 / Double(total)) * 0.8
        return CareProfile(
            member: m,
            cares: mine.count,
            waterings: mine.filter { $0.care == .water }.count,
            covers: acts.filter { $0.kind == .coverYes && $0.memberID == m.id }.count,
            thanks: acts.filter { $0.kind == .thanks && $0.otherID == m.id }.count,
            sitterCares: m.sittingUntil == nil ? 0 : mine.filter { $0.date > m.joinedAt }.count,
            activeDays: recentDays,
            plants: Set(mine.compactMap(\.plantID)).count,
            fairShare: fair)
    }

    /// Who's carried the most love this month: a gentle spotlight, never a ranking of who did least.
    var star: Member? {
        guard isShared else { return nil }
        let best = members.max { load($0.id) < load($1.id) }
        return best.flatMap { load($0.id) >= 3 ? $0 : nil }
    }

    /// A badge I just earned gets a small celebration, once.
    func celebrateNewBadges() async {
        guard let me, isShared, !Self.demo else { return }
        let key = "house.badges.\(meID)"
        let seen = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let p = profile(me)
        let earned = p.earned
        UserDefaults.standard.set(earned.map(\.id), forKey: key)
        guard !seen.isEmpty || UserDefaults.standard.bool(forKey: "\(key).primed") else {
            UserDefaults.standard.set(true, forKey: "\(key).primed"); return
        }
        for b in earned where !seen.contains(b.id) {
            let c = UNMutableNotificationContent()
            c.title = Grammar.pt(String(localized: "New badge: \(b.title)", comment: "Notification title; %@ badge name"))
            c.body = Grammar.pt(String(localized: "Your jungle thanks you. See it on your care profile.", comment: "Notification body for a new badge"))
            c.sound = .default; c.threadIdentifier = "shared-jungle"
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "badge-\(b.id)", content: c, trigger: nil))
        }
    }
}

// MARK: views

/// Level ring with the member's avatar inside.
struct LevelAvatar: View {
    let profile: CareProfile
    var size: CGFloat = 84
    var body: some View {
        ZStack {
            Circle().stroke(Jungle.border, lineWidth: 5)
            Circle().trim(from: 0, to: profile.levelProgress).stroke(profile.member.color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            MemberAvatar(member: profile.member, size: size - 16)
        }
        .frame(width: size, height: size)
    }
}

struct MemberProfileView: View {
    let member: Member
    private var house = Household.shared
    init(member: Member) { self.member = member }

    var body: some View {
        DuoCompanion(mood: .award, title: "Care profile", detail: "Badges, levels and the care that earned them.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        let p = house.profile(member)
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    LevelAvatar(profile: p, size: 96)
                    Text(member.name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    HStack(spacing: 6) {
                        Text(p.level.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText)
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Jungle.mint, in: Capsule())
                        Text(p.roleLine).font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                    if house.star?.id == member.id {
                        Label { Text("This month's jungle star", comment: "Profile: most care this month") } icon: { Image(systemName: "star.fill").foregroundStyle(Jungle.sun) }
                            .font(.footnote.weight(.medium)).foregroundStyle(Jungle.text)
                    }
                    if let n = p.level.next {
                        Text(Grammar.pt(String(localized: "\(n - p.points) points to \(CareProfile.levelTitle(p.level.index + 1))", comment: "Profile: points to next level; %1$lld points, %2$@ level name")))
                            .font(.caption).foregroundStyle(Jungle.subtle)
                    }
                }
                .padding(.top, 8)
                HStack(spacing: 0) {
                    stat(p.points, Grammar.pt(String(localized: "points", comment: "Profile stat caption")))
                    Divider().frame(height: 30)
                    stat(p.cares, Grammar.pt(String(localized: "care moments", comment: "Me stat caption under number of care actions logged; short")))
                    Divider().frame(height: 30)
                    stat(p.covers, Grammar.pt(String(localized: "covers", comment: "Profile stat caption: times covered for someone")))
                    Divider().frame(height: 30)
                    stat(p.thanks, Grammar.pt(String(localized: "thanks", comment: "Profile stat caption: thank-yous received")))
                }
                .padding(.vertical, 12).jungleCard()
                JungleGroup(title: Grammar.pt(String(localized: "Badges · \(p.earned.count) of \(p.badges.count)", comment: "Profile section; earned of total"))) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 16) {
                        ForEach(p.badges) { b in
                            VStack(spacing: 6) {
                                Icon3DView(b.icon, size: 46).saturation(b.earned ? 1 : 0).opacity(b.earned ? 1 : 0.35)
                                Text(b.title).font(.caption.weight(.semibold)).foregroundStyle(Jungle.text).multilineTextAlignment(.center).lineLimit(2)
                                if b.earned {
                                    Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(Jungle.leaf).frame(height: 6)
                                } else {
                                    ProgressView(value: b.progress).tint(Jungle.leaf).frame(width: 54, height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(b.earned ? Grammar.pt(String(localized: "\(b.title), earned", comment: "Accessibility: milestone earned; arg is title")) : Grammar.pt(String(localized: "\(b.title), \(b.detail)", comment: "Accessibility: milestone title then progress detail")))
                        }
                    }
                    .padding(.vertical, 16)
                }
                if let next = p.badges.filter({ !$0.earned }).max(by: { $0.progress < $1.progress }) {
                    HStack(spacing: 12) {
                        Icon3DView(next.icon, size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Grammar.pt(String(localized: "Next: \(next.title)", comment: "Profile: closest badge"))).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                            Text(next.detail).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14).jungleCard()
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .jungleBackdrop()
        .navigationTitle(member.id == house.meID ? Grammar.pt(String(localized: "Your care profile", comment: "Profile screen title, own")) : member.firstName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 0) {
            Text(v.formatted()).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Text(l).font(.caption2).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity)
    }
}

/// One-line level and badge strip for rows.
struct ProfileStrip: View {
    let profile: CareProfile
    var body: some View {
        HStack(spacing: 4) {
            Text(profile.level.title).font(.caption2.weight(.semibold)).foregroundStyle(Jungle.accentText)
            ForEach(profile.earned.suffix(3)) { Icon3DView($0.icon, size: 16) }
        }
    }
}
