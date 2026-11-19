import SwiftUI
import SwiftData
import Charts

// MARK: Manage — people, name, access, leaving

/// Everything about running the shared jungle in one place: who's in it, adding and
/// removing people, its name and stopping or leaving.
struct ManageJungleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = Household.shared.state?.name ?? ""
    @State private var invite = false
    @State private var removing: Member?
    @State private var confirmLeave = false
    private var house = Household.shared

    var body: some View {
        DuoCompanion(mood: .love, title: "Your shared jungle", detail: "Who helps, and how.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JungleGroup(title: Grammar.pt(String(localized: "People", comment: "Manage section: members")),
                            footer: house.isOwner ? Grammar.pt(String(localized: "Removed people keep their own plants. Their turns go back to the rest of you.", comment: "Manage footer: removing members")) : nil) {
                    ForEach(house.members) { m in
                        HStack(spacing: 12) {
                            MemberAvatar(member: m, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.id == house.meID ? Grammar.pt(String(localized: "\(m.name) (you)", comment: "Member row name for yourself")) : m.name).foregroundStyle(Jungle.text)
                                Text(Grammar.pt(String(localized: "\(house.profile(m).roleLine) · joined \(m.joinedAt.formatted(.dateTime.day().month(.abbreviated).year()))", comment: "Manage member subtitle; %1$@ role, %2$@ date")))
                                    .font(.caption).foregroundStyle(Jungle.subtle)
                            }
                            Spacer(minLength: 0)
                            if house.isOwner && m.id != house.meID {
                                Menu {
                                    if m.isSitting() {
                                        Button { house.setSitting(m.id, until: nil) } label: { Label { Text("Make a regular member", comment: "Manage: sitter becomes member") } icon: { Image(systemName: "person.crop.circle.badge.checkmark") } }
                                        Button { house.setSitting(m.id, until: (m.sittingUntil ?? Date()).addingTimeInterval(7 * 86_400)) } label: { Label { Text("Extend sitting a week", comment: "Manage: extend sitter") } icon: { Image(systemName: "calendar.badge.plus") } }
                                    } else {
                                        Button { house.setSitting(m.id, until: Date().addingTimeInterval(7 * 86_400)) } label: { Label { Text("Plant-sit for a week", comment: "Manage: make member a sitter for 7 days") } icon: { Image(systemName: "airplane") } }
                                    }
                                    Button(role: .destructive) { removing = m } label: { Label { Text("Remove", comment: "Remove member button") } icon: { Image(systemName: "person.badge.minus") } }
                                } label: { Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Jungle.subtle).frame(width: 44, height: 44) }
                                .accessibilityLabel(Grammar.pt(String(localized: "Options for \(m.firstName)", comment: "VoiceOver: menu for a jungle member; arg first name")))
                            }
                        }
                        .padding(.vertical, 10)
                        JungleDivider()
                    }
                    Button { invite = true } label: {
                        JungleRow(icon: .mail, title: Grammar.pt(String(localized: "Invite someone", comment: "Hub row")), chevron: true)
                    }.buttonStyle(.plain)
                }
                JungleGroup(title: Grammar.pt(String(localized: "Jungle", comment: "Manage section: jungle details"))) {
                    JungleRow(icon: house.state?.kind.icon ?? .home, title: Grammar.pt(String(localized: "Name", comment: "Hub row: jungle name"))) {
                        if house.isOwner {
                            TextField(house.state?.kind.defaultName ?? "", text: $name)
                                .multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle).submitLabel(.done)
                                .onSubmit { if !name.isEmpty { house.rename(name) } }
                        } else {
                            Text(house.state?.name ?? "").foregroundStyle(Jungle.subtle)
                        }
                    }
                    JungleDivider()
                    JungleRow(icon: .heartPin, title: Grammar.pt(String(localized: "Who's sharing", comment: "Manage row: household type"))) {
                        Text(house.state?.kind.label ?? "").foregroundStyle(Jungle.subtle)
                    }
                }
                JungleGroup(footer: Grammar.pt(String(localized: "Only the people you invite can see this jungle. It lives on our servers, private to its members, who see plant names, photos and care, never your location or account.", comment: "Hub privacy footer"))) {
                    Button(role: .destructive) { confirmLeave = true } label: {
                        Text(house.isOwner ? Grammar.pt(String(localized: "Stop sharing", comment: "Owner ends shared jungle")) : Grammar.pt(String(localized: "Leave this jungle", comment: "Member leaves")))
                            .foregroundStyle(.red).frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle(Text("Manage", comment: "Manage shared jungle screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { if house.isOwner, !name.isEmpty, name != house.state?.name { house.rename(name) } }
        .sheet(isPresented: $invite) { InviteView() }
        .confirmationDialog(Grammar.pt(String(localized: "Remove \(removing?.firstName ?? "")?", comment: "Remove member dialog; %@ name")), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button(role: .destructive) { if let m = removing { withAnimation { house.remove(m.id) } } } label: { Text("Remove", comment: "Confirm remove member") }
        } message: { Text("Their turns go back to the rest of you. They keep their own plants.", comment: "Remove member explanation") }
        .confirmationDialog(house.isOwner ? Grammar.pt(String(localized: "Stop sharing this jungle?", comment: "Dialog title")) : Grammar.pt(String(localized: "Leave this jungle?", comment: "Dialog title")), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(role: .destructive) { Task { await house.leave(); dismiss() } } label: { Text(house.isOwner ? Grammar.pt(String(localized: "Stop sharing", comment: "Owner ends shared jungle")) : Grammar.pt(String(localized: "Leave", comment: "Member leaves button"))) }
        } message: {
            Text(house.isOwner ? Grammar.pt(String(localized: "Everyone else loses access. Your plants and history stay with you.", comment: "Stop sharing explanation")) : Grammar.pt(String(localized: "Plants you already have stay on your iPhone. You can be invited again anytime.", comment: "Leave explanation")))
        }
    }
}

// MARK: Stats — this month

/// Who did what over the last 30 days: totals, a weekly chart by person, and each
/// person's share with their favourite plant.
struct HouseStatsView: View {
    private var house = Household.shared
    private let since = Date().addingTimeInterval(-28 * 86_400)

    private var recent: [Activity] { (house.state?.activity ?? []).filter { $0.date > since } }
    private var care: [Activity] { recent.filter { $0.kind == .care } }

    private struct WeekBar: Identifiable { let week: Date; let member: Member; let count: Int; var id: String { "\(week.timeIntervalSince1970)-\(member.id)" } }

    private var weeks: [WeekBar] {
        let cal = Calendar.current
        let starts = (0..<4).reversed().compactMap { cal.date(byAdding: .weekOfYear, value: -$0, to: cal.dateInterval(of: .weekOfYear, for: Date())!.start) }
        return starts.flatMap { start in
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return house.members.map { m in WeekBar(week: start, member: m, count: care.filter { $0.memberID == m.id && $0.date >= start && $0.date < end }.count) }
        }
    }

    var body: some View {
        JungleGroup(title: Grammar.pt(String(localized: "This month", comment: "Hub section: care balance"))) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    tile(care.count, Grammar.pt(String(localized: "Care moments", comment: "Stat tile label; max 14 chars")), .wateringCan)
                    tile(recent.filter { $0.kind == .coverYes }.count, Grammar.pt(String(localized: "Hand-offs", comment: "Stat tile label; max 14 chars")), .careHands)
                    tile(recent.filter { $0.kind == .thanks }.count, Grammar.pt(String(localized: "Thanks", comment: "Stat tile label; max 14 chars")), .calendarHeart)
                }
                Chart(weeks) { bar in
                    BarMark(x: .value("Week", bar.week, unit: .weekOfYear), y: .value("Care", bar.count))
                        .foregroundStyle(by: .value("Who", bar.member.id))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale(domain: house.members.map(\.id), range: house.members.map(\.color))
                .chartLegend(.hidden)
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(Jungle.border); AxisValueLabel() } }
                .frame(height: 130)
                .accessibilityLabel(Text("Care per week, by person", comment: "Accessibility: weekly chart"))
                VStack(spacing: 0) {
                    ForEach(house.balance, id: \.0.id) { m, share in
                        person(m, share)
                        if m.id != house.balance.last?.0.id { JungleDivider() }
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func tile(_ value: Int, _ label: String, _ icon: Icon3D) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Icon3DView(icon, size: 24)
            Text(value.formatted()).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Jungle.mist, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func person(_ m: Member, _ share: Double) -> some View {
        let mine = care.filter { $0.memberID == m.id }
        let favourite = Dictionary(grouping: mine.compactMap(\.plantName), by: { $0 }).max { $0.value.count < $1.value.count }?.key
        return HStack(spacing: 12) {
            MemberAvatar(member: m, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(m.id == house.meID ? Grammar.pt(String(localized: "You", comment: "Shared jungle: the current user, as a subject; capitalized")) : m.firstName).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                    Spacer()
                    Text("\(mine.count) · \(share.formatted(.percent.precision(.fractionLength(0))))", comment: "Member stat: care count and share; %1$lld count, %2$@ percent")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Jungle.subtle)
                }
                GeometryReader { g in
                    Capsule().fill(Jungle.border).overlay(alignment: .leading) {
                        Capsule().fill(m.color.gradient).frame(width: max(6, g.size.width * share))
                    }
                }
                .frame(height: 6)
                if let favourite {
                    PlantText(Grammar.pt(String(localized: "Most often with \(favourite)", comment: "Member stat: plant they cared for most; %@ plant name")))
                        .font(.caption).foregroundStyle(Jungle.subtle)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: Activity — a timeline

/// Activity as a timeline: days as headers, one node per event on a vertical line,
/// coloured by who did it, with the time on the right and a thanks button for recent care.
struct HouseTimeline: View {
    var limit: Int? = nil
    private var house = Household.shared

    init(limit: Int? = nil) { self.limit = limit }

    private var items: [Activity] {
        let all = house.state?.activity ?? []
        return limit.map { Array(all.prefix($0)) } ?? all
    }

    private var days: [(Date, [Activity])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: items) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        if items.isEmpty {
            Text("Care you all log shows up here.", comment: "Empty activity feed")
                .font(.subheadline).foregroundStyle(Jungle.subtle).padding(.vertical, 14)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(days, id: \.0) { day, events in
                    Text(dayTitle(day)).font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                        .textCase(.uppercase).padding(.top, 14).padding(.bottom, 6)
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, a in
                        node(a, last: i == events.count - 1)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func dayTitle(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return Grammar.pt(String(localized: "Today", comment: "Timeline day header")) }
        if cal.isDateInYesterday(d) { return Grammar.pt(String(localized: "Yesterday", comment: "Timeline day header")) }
        return d.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func node(_ a: Activity, last: Bool) -> some View {
        let color = house.member(a.memberID)?.color ?? Jungle.leaf
        return HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .top) {
                if !last {
                    Rectangle().fill(Jungle.border).frame(width: 2).padding(.top, 30).frame(maxHeight: .infinity)
                }
                Circle().fill(color.opacity(0.16)).frame(width: 30, height: 30)
                    .overlay { symbol(a).font(.system(size: 13, weight: .semibold)).foregroundStyle(color) }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                PlantText(HouseText.feed(a, house)).font(.subheadline).foregroundStyle(Jungle.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let m = house.member(a.memberID) {
                    HStack(spacing: 5) {
                        MemberAvatar(member: m, size: 16)
                        Text(m.id == house.meID ? Grammar.pt(String(localized: "You", comment: "Shared jungle: the current user, as a subject; capitalized")) : m.firstName)
                    }
                    .font(.caption).foregroundStyle(Jungle.subtle)
                }
            }
            .padding(.bottom, last ? 4 : 16)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(a.date.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit()).foregroundStyle(Jungle.subtle)
                thanks(a)
            }
        }
    }

    @ViewBuilder private func symbol(_ a: Activity) -> some View {
        switch a.kind {
        case .care:
            switch a.care ?? .water {
            case .water: Image(systemName: "drop.fill")
            case .feed: Image(systemName: "leaf.arrow.circlepath")
            case .mist: Image(systemName: "humidity.fill")
            case .repot: Image(systemName: "arrow.up.bin.fill")
            case .prune: Image(systemName: "scissors")
            default: Image(systemName: "leaf.fill")
            }
        case .joined, .created: Image(systemName: "person.badge.plus")
        case .left, .removed: Image(systemName: "person.badge.minus")
        case .askCover: Image(systemName: "hand.raised.fill")
        case .coverYes: Image(systemName: "hands.clap.fill")
        case .away: Image(systemName: "airplane")
        case .back: Image(systemName: "house.fill")
        case .thanks: Image(systemName: "heart.fill")
        }
    }

    @ViewBuilder private func thanks(_ a: Activity) -> some View {
        if a.kind == .care && a.memberID != house.meID && a.date > Date().addingTimeInterval(-3 * 86_400) {
            let thanked = house.state?.activity.contains { $0.kind == .thanks && $0.memberID == house.meID && $0.otherID == a.memberID && $0.plantID == a.plantID && $0.date > a.date } == true
            Button { house.thank(a) } label: { Image(systemName: thanked ? "heart.fill" : "heart").foregroundStyle(Jungle.terracotta) }
                .buttonStyle(.plain).disabled(thanked)
                .accessibilityLabel(Text("Say thanks", comment: "Accessibility: thank member button"))
        }
    }
}

/// The full timeline, pushed from "See all".
struct HouseTimelineScreen: View {
    var body: some View {
        ScrollView {
            HouseTimeline().padding(.horizontal, 16).padding(.vertical, 8).jungleCard().padding(16)
        }
        .jungleBackdrop()
        .navigationTitle(Text("Activity", comment: "Hub section: feed"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
