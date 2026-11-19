import SwiftUI

/// Every phone and tablet signed in to the account, newest first.
struct DevicesView: View {
    @State private var devices: [JungleAPI.Device] = []
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JungleGroup(title: Grammar.pt(String(localized: "Signed in", comment: "Devices screen group title")),
                            footer: Grammar.pt(String(localized: "Your plants, photos and Plus follow you to every device signed in to this account, iPhone or Android.", comment: "Devices screen footer"))) {
                    if devices.isEmpty {
                        JungleRow(icon: .repeat, title: failed ? Grammar.pt(String(localized: "Couldn't load your devices.", comment: "Devices screen error; max 40 chars")) : Grammar.pt(String(localized: "Loading…", comment: "Loading row; max 20 chars")))
                    }
                    ForEach(Array(devices.enumerated()), id: \.element.id) { i, d in
                        if i > 0 { JungleDivider() }
                        JungleRow(icon: .profile, title: name(d), subtitle: subtitle(d))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle(Grammar.pt(String(localized: "Your devices", comment: "Settings title")))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { devices = try await JungleAPI.shared.me().devices } catch { failed = true }
        }
    }

    private func name(_ d: JungleAPI.Device) -> String {
        let base = d.model ?? (d.platform == "android" ? "Android" : "iPhone")
        return d.thisDevice ? Grammar.pt(String(localized: "\(base) (this one)", comment: "Device name for the current device; %@ is the model like iPhone")) : base
    }

    private func subtitle(_ d: JungleAPI.Device) -> String {
        Grammar.pt(String(localized: "Last seen \(d.lastSeenAt.formatted(.relative(presentation: .named)))", comment: "Device row subtitle; %@ relative date"))
    }
}
