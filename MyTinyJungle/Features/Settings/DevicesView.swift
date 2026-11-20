import SwiftUI

/// Every phone and tablet signed in to the account, newest first.
struct DevicesView: View {
    @State private var devices: [JungleAPI.Device] = []
    @State private var failed = false

    var body: some View { tracked.screen("devices") }
    @ViewBuilder private var tracked: some View {
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

/// Settings: a copy of everything the server holds about you, as one JSON file (GDPR / LGPD access right).
struct ExportDataRow: View {
    @State private var file: URL?
    @State private var busy = false
    @State private var failed = false
    var body: some View {
        Button { Task { await export() } } label: {
            JungleRow(icon: .box, title: Grammar.pt(String(localized: "Download my data", comment: "Settings title")),
                      subtitle: failed ? Grammar.pt(String(localized: "Couldn't prepare it. Try again.", comment: "Data export error; max 40 chars")) : nil) {
                if busy { ProgressView() }
            }
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .sheet(item: $file) { ShareSheet(items: [$0]).ignoresSafeArea() }
    }

    private func export() async {
        busy = true; failed = false
        defer { busy = false }
        guard let data = try? await JungleAPI.shared.download("/v1/me/export") else { failed = true; return }
        let url = FileManager.default.temporaryDirectory.appending(path: "my-tiny-jungle-data.json")
        do { try data.write(to: url, options: [.atomic, .completeFileProtection]); file = url } catch { failed = true }
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ c: UIActivityViewController, context: Context) {}
}
