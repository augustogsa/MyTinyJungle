import SwiftUI
import CloudKit

/// Receives "join this jungle" taps from iCloud share links, warm or cold launch.
final class HouseholdSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let m = options.cloudKitShareMetadata { Task { @MainActor in await Household.shared.accept(m) } }
    }
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in await Household.shared.accept(metadata) }
    }
}

/// Me tab entry: invite when alone, people and your turns when shared.
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
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.subtle.opacity(0.7))
            }
            .padding(16)
            .background(Jungle.mint.opacity(0.7), in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { NavigationStack { SharedJungleView() } }
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
