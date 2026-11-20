import SwiftUI
import SwiftData
import CloudKit
import MessageUI

// MARK: small pieces used everywhere

struct MemberAvatar: View {
    let member: Member
    var size: CGFloat = 32
    var body: some View {
        Text(member.initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(Jungle.background)
            .frame(width: size, height: size)
            .background(member.color.gradient, in: Circle())
            .overlay(alignment: .bottomTrailing) {
                if member.isAway() {
                    Image(systemName: "airplane").font(.system(size: size * 0.28, weight: .bold)).foregroundStyle(Jungle.text)
                        .padding(2).background(Jungle.surface, in: Circle()).offset(x: 2, y: 2)
                }
            }
            .accessibilityLabel(member.name)
    }
}

struct MemberStack: View {
    let members: [Member]
    var size: CGFloat = 28
    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(members.prefix(4)) { MemberAvatar(member: $0, size: size).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 2)) }
        }
    }
}

/// "Your turn" / "Ana's turn" capsule. Hidden when the jungle isn't shared.
struct TurnPill: View {
    let plantID: UUID
    private var house = Household.shared
    init(plantID: UUID) { self.plantID = plantID }
    var body: some View {
        if let t = house.turn(for: plantID) {
            HStack(spacing: 5) {
                MemberAvatar(member: t.member, size: 18)
                Text(HouseText.turnLabel(t)).font(.caption.weight(.semibold)).foregroundStyle(t.isMe ? Jungle.accentText : Jungle.subtle)
            }
            .padding(.leading, 3).padding(.trailing, 9).padding(.vertical, 3)
            .background((t.isMe ? Jungle.mint : Jungle.mist), in: Capsule())
        }
    }
}

// MARK: Today / Care card

/// Shared-jungle card: asks for me, my turns, last thing someone did. Kind, never blaming.
struct HouseholdTodayCard: View {
    let plants: [Plant]
    @State private var hub = false
    private var house = Household.shared
    init(plants: [Plant]) { self.plants = plants }

    var body: some View {
        if house.isShared {
            VStack(alignment: .leading, spacing: 12) {
                Button { hub = true } label: {
                    HStack(spacing: 10) {
                        MemberStack(members: house.members, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(house.state?.name ?? "").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                            Text(summary).font(.subheadline).foregroundStyle(Jungle.subtle).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.tertiary)
                    }
                }.buttonStyle(.plain)
                ForEach(house.openRequestsForMe) { r in RequestRow(request: r) }
                if let a = latest {
                    Divider()
                    HStack(spacing: 8) {
                        if let m = house.member(a.memberID) { MemberAvatar(member: m, size: 22) }
                        Text(HouseText.feed(a, house)).font(.footnote).foregroundStyle(Jungle.text)
                        Spacer(minLength: 0)
                        Text(a.date.formatted(.relative(presentation: .named))).font(.caption2).foregroundStyle(Jungle.subtle)
                    }
                }
            }
            .padding(16)
            .jungleCard()
            .sheet(isPresented: $hub) { NavigationStack { SharedJungleView() } }
        }
    }

    private var mine: [Plant] { plants.filter { CareEngine.needsYou($0) && house.turn(for: $0.id)?.isMe == true } }
    private var latest: Activity? { house.state?.activity.first { $0.kind == .care && $0.memberID != house.meID && $0.date > Date().addingTimeInterval(-2 * 86_400) } }
    private var summary: String {
        let needing = plants.filter { CareEngine.needsYou($0) }
        if needing.isEmpty { return Grammar.pt(String(localized: "Everyone's plants are happy today", comment: "Shared jungle card: nothing needed")) }
        if mine.isEmpty {
            let others = Set(needing.compactMap { house.turn(for: $0.id)?.member.firstName })
            return others.count == 1 ? Grammar.pt(String(localized: "\(others.first!) has today's care. Enjoy a day off.", comment: "Shared card: other member's turn; %@ first name")) : Grammar.pt(String(localized: "Others have today's care. Enjoy a day off.", comment: "Shared card: others' turn"))
        }
        return mine.count == 1 ? Grammar.pt(String(localized: "\(mine[0].name) is your turn today", comment: "Shared card; %@ plant name")) : Grammar.pt(String(localized: "\(mine.count) plants are your turn today", comment: "Shared card; %lld count"))
    }
}

struct RequestRow: View {
    let request: CoverRequest
    private var house = Household.shared
    init(request: CoverRequest) { self.request = request }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                if let m = house.member(request.fromID) { MemberAvatar(member: m, size: 28) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(Grammar.pt(String(localized: "\(house.name(request.fromID)) could use a hand", comment: "Cover request title; %@ first name"))).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText).padding(.leading, 14)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(HouseText.askLine(request, plantName: house.state?.plants.first { $0.id == request.plantIDs.first }?.name ?? ""))
                        if !request.note.isEmpty { Text(request.note).foregroundStyle(Jungle.subtle) }
                        HStack(spacing: 8) {
                            Button { withAnimation { house.dismissRequest(request.id) } } label: {
                                Text("Not this time", comment: "Decline cover request button; kind").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered).tint(Jungle.text)
                            Button { withAnimation { house.acceptCover(request.id) } } label: {
                                Text("I've got it", comment: "Accept cover request button").foregroundStyle(.white).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).junglePrimary()
                        }
                        .controlSize(.regular).buttonBorderShape(.capsule).fontDesign(.rounded)
                    }
                    .font(.subheadline).foregroundStyle(Jungle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .messageBubble(fill: Jungle.incoming)
                }
            }
        }
    }
}

// MARK: plant page section

struct PlantShareSection: View {
    let plant: Plant
    @State private var ask = false
    private var house = Household.shared
    init(plant: Plant) { self.plant = plant }
    var body: some View {
        if house.isShared {
            JungleGroup(title: Grammar.pt(String(localized: "Shared care", comment: "Plant page section title"))) {
                JungleRow(icon: .careHands, title: Grammar.pt(String(localized: "Looked after by", comment: "Plant page row: who cares for this plant"))) {
                    Menu {
                        Picker(selection: Binding(get: { house.state?.plans[plant.id] ?? .rotate }, set: { house.setPlan(plant.id, $0) })) {
                            Label { Text("Take turns", comment: "Care plan: rotate between members") } icon: { Image(systemName: "arrow.triangle.2.circlepath") }.tag(CarePlan.rotate)
                            ForEach(house.members) { m in Text(m.id == house.meID ? Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) : m.firstName).tag(CarePlan.person(m.id)) }
                        } label: { EmptyView() }
                    } label: {
                        HStack(spacing: 4) { Text(planLabel); Image(systemName: "chevron.up.chevron.down").font(.caption2) }
                            .font(.subheadline).foregroundStyle(Jungle.accentText)
                    }
                }
                JungleDivider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        TurnPill(plantID: plant.id)
                        if let a = house.lastCare(plant.id) {
                            Text(HouseText.careLine(house.name(a.memberID), a.care ?? .water, plant.name, recent: false) + " " + a.date.formatted(.relative(presentation: .named)))
                                .font(.caption).foregroundStyle(Jungle.subtle)
                        }
                    }
                    Spacer(minLength: 0)
                    if house.turn(for: plant.id)?.isMe == true {
                        Button { ask = true } label: { Text("Ask for a hand", comment: "Plant page button: ask another member to cover") }
                            .buttonStyle(.bordered).controlSize(.small).tint(Jungle.tint)
                    }
                }
                .padding(.vertical, 12)
            }
            .sheet(isPresented: $ask) { AskCoverView(preselected: [plant.id]).presentationDetents([.medium, .large]) }
        }
    }
    private var planLabel: String {
        if case .person(let id)? = house.state?.plans[plant.id] { return id == house.meID ? Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) : house.name(id) }
        return Grammar.pt(String(localized: "Take turns", comment: "Care plan: rotate between members"))
    }
}

// MARK: hub

struct SharedJungleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.name) private var plants: [Plant]
    @State private var invite = false
    @State private var ask = false
    @State private var away = false
    @State private var confirmLeave = false
    @State private var removing: Member?
    @State private var name = ""
    private var house = Household.shared

    var body: some View {
        DuoCompanion(mood: .love, title: "Shared jungle", detail: "Take turns, never double-water.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        Group {
            if house.active { hub } else { HouseSetupView(plants: plants) }
        }
        .jungleBackdrop()
        .navigationTitle(house.active ? (house.state?.name ?? "") : Grammar.pt(String(localized: "Shared jungle", comment: "Screen title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("Done") } }
            if house.active {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { ManageJungleView() } label: { Image(systemName: "person.2.badge.gearshape") }
                        .accessibilityLabel(Text("Manage", comment: "Manage shared jungle screen title"))
                }
            }
        }
        .task { await house.sync(ctx) }
        .refreshable { await house.sync(ctx) }
    }

    private var hub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !house.openRequestsForMe.isEmpty || !house.myOpenRequests.isEmpty || !house.coveringNow.isEmpty {
                    JungleGroup(title: Grammar.pt(String(localized: "Hand-offs", comment: "Hub section: cover requests"))) {
                        VStack(spacing: 10) {
                            ForEach(house.openRequestsForMe) { RequestRow(request: $0) }
                            ForEach(house.myOpenRequests) { r in
                                JungleRow(icon: .careHands, title: Grammar.pt(String(localized: "Waiting for a yes", comment: "Hub row: my open cover request")), subtitle: HouseText.askLine(r, plantName: plantName(r.plantIDs.first))) {
                                    Button { house.withdraw(r.id) } label: { Text("Withdraw", comment: "Cancel my cover request") }.font(.subheadline)
                                }
                            }
                            ForEach(house.coveringNow) { r in
                                JungleRow(icon: .calendarHeart, title: r.coverID == house.meID ? Grammar.pt(String(localized: "You're covering for \(house.name(r.fromID))", comment: "Hub row; %@ name")) : Grammar.pt(String(localized: "\(house.name(r.coverID)) is covering for you", comment: "Hub row; %@ name")),
                                          subtitle: Grammar.pt(String(localized: "\(plantName(r.plantIDs.first)) until \(r.until.formatted(.dateTime.weekday(.wide).day()))", comment: "Hub row subtitle; %1$@ plant, %2$@ date")))
                            }
                        }.padding(.vertical, 12)
                    }
                }
                JungleGroup(title: Grammar.pt(String(localized: "People", comment: "Hub section: members")), footer: Grammar.pt(String(localized: "Turns go to whoever didn't do it last, keeping things fair across the month.", comment: "Hub footer explaining turn logic"))) {
                    ForEach(house.members) { m in
                        NavigationLink { MemberProfileView(member: m) } label: {
                            HStack(spacing: 12) {
                                LevelAvatar(profile: house.profile(m), size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(m.id == house.meID ? Grammar.pt(String(localized: "\(m.name) (you)", comment: "Member row name for yourself")) : m.name).foregroundStyle(Jungle.text)
                                        if house.star?.id == m.id { Image(systemName: "star.fill").font(.caption2).foregroundStyle(Jungle.sun) }
                                    }
                                    Text(memberLine(m)).font(.caption).foregroundStyle(Jungle.subtle)
                                    ProfileStrip(profile: house.profile(m))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.tertiary)
                            }
                            .padding(.vertical, 10).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        JungleDivider()
                    }
                    NavigationLink { ManageJungleView() } label: {
                        JungleRow(icon: .profile, title: Grammar.pt(String(localized: "Manage people", comment: "Hub row: add, remove members, name, leave")),
                                  subtitle: Grammar.pt(String(localized: "Invite, remove, rename or stop sharing", comment: "Hub row subtitle")), chevron: true)
                    }.buttonStyle(.plain)
                }
                if house.isShared { HouseStatsView() }
                JungleGroup(title: Grammar.pt(String(localized: "Who looks after what", comment: "Hub section: plant assignments"))) {
                    ForEach(plants) { p in
                        HStack(spacing: 12) {
                            PlantAvatar(data: p.photo, size: 36)
                            Text(p.name).foregroundStyle(Jungle.text).lineLimit(1)
                            Spacer()
                            TurnPill(plantID: p.id)
                            Menu {
                                Picker(selection: Binding(get: { house.state?.plans[p.id] ?? .rotate }, set: { house.setPlan(p.id, $0) })) {
                                    Text("Take turns", comment: "Care plan: rotate between members").tag(CarePlan.rotate)
                                    ForEach(house.members) { m in Text(m.id == house.meID ? Grammar.pt(String(localized: "Me", comment: "Care plan option: only me")) : m.firstName).tag(CarePlan.person(m.id)) }
                                } label: { EmptyView() }
                            } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Jungle.subtle).frame(width: 44, height: 44) }
                                .accessibilityLabel(Text(Grammar.pt(String(localized: "Who looks after \(p.name)", comment: "Accessibility: assignment menu; %@ plant"))))
                        }
                        .padding(.vertical, 8)
                        if p.id != plants.last?.id { JungleDivider() }
                    }
                }
                JungleGroup(title: Grammar.pt(String(localized: "Your part", comment: "Hub section: my actions"))) {
                    Button { ask = true } label: { JungleRow(icon: .careHands, title: Grammar.pt(String(localized: "Ask someone to cover", comment: "Hub row")), subtitle: Grammar.pt(String(localized: "Busy day? Pass a plant along.", comment: "Hub row subtitle")), chevron: true) }.buttonStyle(.plain)
                    JungleDivider()
                    Button { away = true } label: {
                        JungleRow(icon: .travel, title: house.me?.isAway() == true ? Grammar.pt(String(localized: "Away until \(house.me!.awayUntil!.formatted(.dateTime.weekday(.wide).day()))", comment: "Hub row: I'm travelling; %@ date")) : Grammar.pt(String(localized: "Going away", comment: "Hub row: travel hand-off")),
                                  subtitle: Grammar.pt(String(localized: "Your turns pass on while you travel", comment: "Hub row subtitle")), chevron: true)
                    }.buttonStyle(.plain)
                }
                JungleGroup(title: Grammar.pt(String(localized: "Activity", comment: "Hub section: feed"))) {
                    HouseTimeline(limit: 8)
                    if (house.state?.activity.count ?? 0) > 8 {
                        JungleDivider()
                        NavigationLink { HouseTimelineScreen() } label: {
                            Text("See all activity", comment: "Hub: open full timeline").font(.subheadline.weight(.medium)).foregroundStyle(Jungle.accentText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .onAppear { name = house.state?.name ?? "" }
        .sheet(isPresented: $invite) { InviteView() }
        .sheet(isPresented: $ask) { AskCoverView(preselected: []).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $away) { AwayView().presentationDetents([.medium]) }
        .confirmationDialog(house.isOwner ? Grammar.pt(String(localized: "Stop sharing this jungle?", comment: "Dialog title")) : Grammar.pt(String(localized: "Leave this jungle?", comment: "Dialog title")), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(role: .destructive) { Task { await house.leave(); dismiss() } } label: { Text(house.isOwner ? Grammar.pt(String(localized: "Stop sharing", comment: "Owner ends shared jungle")) : Grammar.pt(String(localized: "Leave", comment: "Member leaves button"))) }
        } message: {
            Text(house.isOwner ? Grammar.pt(String(localized: "Everyone else loses access. Your plants and history stay with you.", comment: "Stop sharing explanation")) : Grammar.pt(String(localized: "Plants you already have stay on your iPhone. You can be invited again anytime.", comment: "Leave explanation")))
        }
        .confirmationDialog(Grammar.pt(String(localized: "Remove \(removing?.firstName ?? "")?", comment: "Remove member dialog; %@ name")), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button(role: .destructive) { if let m = removing { house.remove(m.id) } } label: { Text("Remove", comment: "Confirm remove member") }
        } message: { Text("Their turns go back to the rest of you. They keep their own plants.", comment: "Remove member explanation") }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Icon3DView(house.state?.kind.icon ?? .home, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(house.state?.kind.label ?? "").font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                Text(house.isShared ? Grammar.pt(String(localized: "\(house.members.count) people · \(plants.count) plants", comment: "Hub header; %1$lld people, %2$lld plants")) : Grammar.pt(String(localized: "Just you so far. Invite someone to share the care.", comment: "Hub header when alone")))
                    .font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            Spacer(minLength: 0)
            MemberStack(members: house.members)
        }
        .padding(16).jungleCard()
    }

    private func plantName(_ id: UUID?) -> String { plants.first { $0.id == id }?.name ?? house.state?.plants.first { $0.id == id }?.name ?? "" }
    private func memberLine(_ m: Member) -> String {
        if m.isAway() { return Grammar.pt(String(localized: "Away until \(m.awayUntil!.formatted(.dateTime.weekday(.wide).day()))", comment: "Member status: travelling; %@ date")) }
        let mine = plants.filter { house.turn(for: $0.id)?.member.id == m.id && CareEngine.needsYou($0) }.count
        let role = house.profile(m).roleLine
        return mine == 0 ? role : Grammar.pt(String(localized: "\(role) · \(mine) to do", comment: "Member status: role and count of plants on their turn"))
    }
}

// MARK: setup

struct HouseSetupView: View {
    let plants: [Plant]
    @State private var kind: HouseKind = .couple
    @State private var name = ""
    @State private var working = false
    @State private var invite = false
    private var house = Household.shared
    init(plants: [Plant]) { self.plants = plants }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: -10) { Icon3DView(.careHands, size: 64); Icon3DView(.pottedPlant, size: 64) }
                    Text("Care for your plants together", comment: "Shared jungle setup headline").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    Text("Invite the people you live with. Everyone gets reminders on their turn, sees who watered last, and can pass a plant along when life gets busy.", comment: "Shared jungle setup body")
                        .font(.body).foregroundStyle(Jungle.subtle)
                }
                JungleGroup(title: Grammar.pt(String(localized: "Who's sharing?", comment: "Setup section: household type"))) {
                    ForEach(HouseKind.allCases) { k in
                        Button { withAnimation(.snappy) { kind = k } } label: {
                            JungleRow(icon: k.icon, title: k.label, subtitle: k.blurb) {
                                Image(systemName: kind == k ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(kind == k ? Jungle.forest : Jungle.border)
                            }
                        }.buttonStyle(.plain)
                        if k != HouseKind.allCases.last { JungleDivider() }
                    }
                }
                JungleGroup(title: Grammar.pt(String(localized: "Name", comment: "Setup section: jungle name"))) {
                    TextField(kind.defaultName, text: $name).padding(.vertical, 14)
                }
                Button {
                    working = true
                    Task { await house.create(kind: kind, name: name, plants: plants); working = false; invite = true }
                } label: {
                    HStack { if working { ProgressView().tint(.white) }; Text("Start and invite", comment: "Setup primary button") }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.glassProminent).junglePrimary().disabled(working)
                Label { Text("Uses iCloud sharing. Only people you invite can join.", comment: "Setup privacy note") } icon: { Image(systemName: "lock.fill") }
                    .font(.footnote).foregroundStyle(Jungle.subtle)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .sheet(isPresented: $invite) { InviteView() }
    }
}

// MARK: invite

struct InviteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mail = false
    @State private var copied = false
    @State private var sitter = Household.shared.state?.sitterInviteUntil.map { $0 > Date() } ?? false
    @State private var sitterUntil = Household.shared.state?.sitterInviteUntil ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    private var house = Household.shared

    private var url: URL? { house.inviteURL ?? (Household.demo ? URL(string: "https://mytinyjungle.com/join/DEMO234XYZ") : nil) }
    private var message: String {
        let me = house.me?.firstName ?? ""
        if sitter {
            return Grammar.pt(String(localized: "\(me) asked you to plant-sit \(house.state?.name ?? "our plants") until \(sitterUntil.formatted(.dateTime.weekday(.wide).day().month())). My Tiny Jungle shows you exactly what each plant needs, and you'll earn a Plant sitter badge.", comment: "Sitter invite message; %1$@ inviter, %2$@ jungle name, %3$@ date"))
        }
        return Grammar.pt(String(localized: "\(me) invited you to care for \(house.state?.name ?? "our plants") together on My Tiny Jungle. We'll take turns, and the app tells us whose turn it is.", comment: "Invite message text; %1$@ inviter name, %2$@ jungle name"))
    }

    var body: some View {
        DuoCompanion(mood: .wave, title: "Invite someone", detail: "Partner, family or housemates.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        MemberStack(members: house.members, size: 44)
                        Text("Invite to \(house.state?.name ?? "")", comment: "Invite headline; %@ jungle name").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).multilineTextAlignment(.center)
                        Text(blurb).font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    VStack(spacing: 12) {
                        Picker(selection: $sitter) {
                            Text("Someone at home", comment: "Invite mode: regular member").tag(false)
                            Text("A plant sitter", comment: "Invite mode: temporary plant sitter").tag(true)
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                        if sitter {
                            DatePicker(selection: $sitterUntil, in: Date()..., displayedComponents: .date) {
                                Label { Text("Sitting until", comment: "Invite: sitter end date") } icon: { Image(systemName: "calendar") }.foregroundStyle(Jungle.text)
                            }
                            Text("They get your plants' turns while you're away, earn a Plant sitter badge on their profile, and step back on their own when it ends.", comment: "Invite: sitter explanation")
                                .font(.footnote).foregroundStyle(Jungle.subtle).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14).jungleCard()
                    .onChange(of: sitter) { _, on in house.setSitterInvite(on ? sitterUntil : nil); Task { await house.prepareInvite() } }
                    .onChange(of: sitterUntil) { _, d in if sitter { house.setSitterInvite(d); Task { await house.prepareInvite() } } }
                    if let url {
                        VStack(spacing: 10) {
                            ShareLink(item: url, subject: Text(house.state?.name ?? ""), message: Text(message)) {
                                Label { Text("Share invite link", comment: "Invite primary button") } icon: { Image(systemName: "square.and.arrow.up") }
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                            }.buttonStyle(.glassProminent).junglePrimary()
                            HStack(spacing: 10) {
                                Button { if MFMailComposeViewController.canSendMail() { mail = true } else { openMailto(url) } } label: {
                                    Label { Text("Email", comment: "Invite by email button") } icon: { Image(systemName: "envelope") }.frame(maxWidth: .infinity, minHeight: 44)
                                }
                                Button { UIPasteboard.general.url = url; withAnimation { copied = true } } label: {
                                    Label { Text(copied ? Grammar.pt(String(localized: "Copied", comment: "Link copied confirmation")) : Grammar.pt(String(localized: "Copy link", comment: "Invite button"))) } icon: { Image(systemName: copied ? "checkmark" : "link") }.frame(maxWidth: .infinity, minHeight: 44)
                                }
                            }
                            .buttonStyle(.bordered).tint(Jungle.tint)
                            Text("Each link works once and expires in 7 days.", comment: "Invite: link rules").font(.footnote).foregroundStyle(Jungle.subtle).padding(.top, 4)
                        }
                    } else if let err = house.lastError {
                        VStack(spacing: 12) {
                            Icon3DView(.weather, size: 48)
                            Text(err).font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                            Button { Task { await house.prepareInvite() } } label: { Text("Try again", comment: "Retry button") }.buttonStyle(.bordered)
                        }.padding(16).frame(maxWidth: .infinity).jungleCard()
                    } else {
                        ErtyLoading(text: "", mood: .idle).padding(20)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        step(1, Grammar.pt(String(localized: "They open the link and get the app", comment: "Invite how-it-works step")))
                        step(2, Grammar.pt(String(localized: "They sign in and join with one tap", comment: "Invite how-it-works step")))
                        step(3, Grammar.pt(String(localized: "Your plants show up on their iPhone, turns included", comment: "Invite how-it-works step")))
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
                    NativeAdCard(slot: "invite")
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
            .jungleBackdrop()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("Done") } } }
            .task { await house.prepareInvite() }
            .sheet(isPresented: $mail) { if let url { MailComposer(subject: house.state?.name ?? "My Tiny Jungle", body: message + "\n\n" + url.absoluteString).ignoresSafeArea() } }
        }
    }

    private var blurb: String {
        if sitter { return Grammar.pt(String(localized: "Going away? Invite a friend or neighbour to plant-sit. They see what each plant needs and get reminders until you're back.", comment: "Invite blurb, plant sitter")) }
        return switch house.state?.kind ?? .couple {
        case .couple: Grammar.pt(String(localized: "Your partner gets reminders on their turn and sees when you've watered. No more double drinks.", comment: "Invite blurb, couple"))
        case .family: Grammar.pt(String(localized: "Everyone at home can help. Turns rotate fairly, kids included.", comment: "Invite blurb, family"))
        case .housemates: Grammar.pt(String(localized: "Fair turns for the shared plants, and a heads-up when someone's away.", comment: "Invite blurb, housemates"))
        case .friends: Grammar.pt(String(localized: "Perfect for plant-sitting. They see exactly what each plant needs.", comment: "Invite blurb, friends"))
        }
    }
    private func step(_ n: Int, _ t: String) -> some View {
        HStack(spacing: 12) {
            Text(n.formatted()).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Jungle.accentText).frame(width: 28, height: 28).background(Jungle.mint, in: Circle())
            Text(t).font(.subheadline).foregroundStyle(Jungle.text)
        }
    }
    private func openMailto(_ url: URL) {
        var c = URLComponents(); c.scheme = "mailto"
        c.queryItems = [.init(name: "subject", value: house.state?.name), .init(name: "body", value: message + "\n\n" + url.absoluteString)]
        if let u = c.url { UIApplication.shared.open(u) }
    }
}

struct MailComposer: UIViewControllerRepresentable {
    let subject: String, body: String
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject); vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> C { C() }
    final class C: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ c: MFMailComposeViewController, didFinishWith r: MFMailComposeResult, error: Error?) { c.dismiss(animated: true) }
    }
}


// MARK: ask cover / away

struct AskCoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.name) private var plants: [Plant]
    @State private var picked: Set<UUID>
    @State private var to: String?
    @State private var until = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var note = ""
    private var house = Household.shared
    init(preselected: [UUID]) { _picked = State(initialValue: Set(preselected)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $to) {
                        Text("Anyone", comment: "Ask cover: send to everyone").tag(String?.none)
                        ForEach(house.others) { Text($0.firstName).tag(Optional($0.id)) }
                    } label: { Text("Ask", comment: "Ask cover: recipient picker label") }
                    DatePicker(selection: $until, in: Date()..., displayedComponents: .date) { Text("Until", comment: "Ask cover: end date") }
                    TextField(Grammar.pt(String(localized: "Add a note (optional)", comment: "Ask cover note placeholder")), text: $note)
                }
                Section {
                    ForEach(plants) { p in
                        Button { if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) } } label: {
                            HStack {
                                PlantAvatar(data: p.photo, size: 30)
                                Text(p.name).foregroundStyle(Jungle.text)
                                Spacer()
                                Image(systemName: picked.contains(p.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(picked.contains(p.id) ? Jungle.forest : Jungle.border)
                            }
                        }
                    }
                } header: { Text("Plants", comment: "Ask cover: plant list header") }
            }
            .navigationTitle(Text("Ask for a hand", comment: "Ask cover screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("Cancel") } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { house.askCover(plants: Array(picked), to: to, until: until, note: note); dismiss() } label: { Text("Send", comment: "Send cover request") }.disabled(picked.isEmpty)
                }
            }
        }
    }
}

struct AwayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var until = Calendar.current.date(byAdding: .day, value: 4, to: Date())!
    @State private var cover: String?
    private var house = Household.shared
    var body: some View {
        DuoCompanion(mood: .sleep, title: "Going away", detail: "Holiday plans so every plant stays fine.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(selection: $until, in: Date()..., displayedComponents: .date) { Text("Back on", comment: "Away: return date") }
                    Picker(selection: $cover) {
                        Text("Share fairly", comment: "Away: turns rotate among the rest").tag(String?.none)
                        ForEach(house.others) { Text($0.firstName).tag(Optional($0.id)) }
                    } label: { Text("Your turns go to", comment: "Away: who covers") }
                } footer: { Text("You won't get care reminders while you're away. Everyone sees you're travelling.", comment: "Away footer") }
                if house.me?.isAway() == true {
                    Section { Button { house.setAway(until: nil, cover: nil); dismiss() } label: { Text("I'm back home", comment: "End travel") } }
                }
            }
            .navigationTitle(Text("Going away", comment: "Away screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("Cancel") } }
                ToolbarItem(placement: .confirmationAction) { Button { house.setAway(until: until, cover: cover); dismiss() } label: { Text("Save") } }
            }
            .onAppear { if let u = house.me?.awayUntil, u > Date() { until = u; cover = house.me?.awayCoverID } }
        }
    }
}
