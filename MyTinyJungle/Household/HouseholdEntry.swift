import SwiftUI

/// Me tab entry: invite when alone, people and your turns when shared.
/// Me tab: your care level and badges from caring together.
struct MyCareProfileCard: View {
    let profile: CareProfile
    var body: some View {
        HStack(spacing: 14) {
            LevelAvatar(profile: profile, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.level.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(Grammar.pt(String(localized: "\(profile.points) points · \(profile.earned.count) badges", comment: "Me care profile card; %1$lld points, %2$lld badges"))).font(.subheadline).foregroundStyle(Jungle.subtle)
                HStack(spacing: 4) { ForEach(profile.earned.suffix(6)) { Icon3DView($0.icon, size: 22) } }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.tertiary)
        }
        .padding(16)
        .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.cardEdge, lineWidth: 0.5))
    }
}

struct SharedJungleRow: View {
    @State private var open = false
    private var house = Household.shared
    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 14) {
                if house.isShared { MemberStack(members: house.members, size: 40) } else { Icon3DView(.careHands, size: 48) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(house.isShared ? (house.state?.name ?? "") : Grammar.pt(String(localized: "Share your jungle", comment: "Me card title: invite people to care together")))
                        .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Text(subtitle).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.tertiary)
            }
            .padding(16)
            .background(Jungle.fill, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { NavigationStack { SharedJungleView() } }
        if house.isShared, let me = house.me {
            NavigationLink { MemberProfileView(member: me) } label: { MyCareProfileCard(profile: house.profile(me)) }.buttonStyle(.plain)
        }
    }
    private var subtitle: String {
        guard house.isShared else {
            return house.active ? Grammar.pt(String(localized: "Waiting for your first invite to be accepted", comment: "Me card: jungle created, nobody joined")) : Grammar.pt(String(localized: "Partner, family or housemates. Take turns, never double-water.", comment: "Me card subtitle: invite pitch"))
        }
        let names = house.others.map(\.firstName).formatted(.list(type: .and))
        return Grammar.pt(String(localized: "With \(names)", comment: "Me card subtitle; %@ list of member names"))
    }
}

/// Settings entry with the same sheet.
struct SharedJungleSettingsGroup: View {
    @State private var open = false
    private var house = Household.shared
    var body: some View {
        JungleGroup(title: Grammar.pt(String(localized: "Shared jungle", comment: "Settings title")), footer: Grammar.pt(String(localized: "Care for your plants with the people you live with.", comment: "Settings footer"))) {
            Button { open = true } label: {
                JungleRow(icon: .careHands, title: house.active ? (house.state?.name ?? "") : Grammar.pt(String(localized: "Invite people", comment: "Settings row")),
                          subtitle: house.isShared ? Grammar.pt(String(localized: "\(house.members.count) people · you're \(house.isOwner ? String(localized: "the owner", comment: "Role phrase") : String(localized: "a member", comment: "Role phrase"))", comment: "Settings row subtitle; %1$lld count, %2$@ role phrase")) : nil, chevron: true) {
                    if house.isShared { MemberStack(members: house.members, size: 24) }
                }
            }.buttonStyle(.plain)
        }
        .sheet(isPresented: $open) { NavigationStack { SharedJungleView() } }
    }
}
