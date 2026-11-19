import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = JungleSettings.shared
    @State private var paywall = false
    @State private var weatherWatch = WeatherWatch.isOn
    @State private var digestOn = DigestAPI.isOn
    @State private var weatherNote: String?
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var iconPicker = false
    @State private var appIcon = JungleAppIcon.current
    @Environment(\.modelContext) private var ctx
    private var plus: Bool { Store.shared.isPlus }
    private var auth = AuthManager.shared
    private var cloud = CloudBackup.shared
    private var sync = JungleSync.shared

    private static var legalLinks: [(path: String, icon: Icon3D, title: String)] {
        [("privacy", .shieldCheck, Grammar.pt(String(localized: "Privacy Policy", comment: "Settings link to the privacy policy"))),
         ("terms", .leafTag, Grammar.pt(String(localized: "Terms of Use", comment: "Settings link to the terms of use"))),
         ("support", .chat, Grammar.pt(String(localized: "Help and support", comment: "Settings link to the support page")))]
    }

    private static func site(_ path: String) -> URL {
        URL(string: "https://mytinyjungle.com/\(Grammar.isPortuguese ? "pt/" : "")\(path)")!
    }

    var body: some View {
        DuoCompanion(mood: .notes, title: "Settings", detail: "Make the jungle yours.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let a = auth.account {
                        JungleGroup(title: Grammar.pt(String(localized: "Account", comment: "Settings title"))) {
                            JungleRow(icon: .profile, title: a.email ?? a.name ?? Grammar.pt(String(localized: "Signed in", comment: "Settings account row fallback")), subtitle: a.provider == .apple ? Grammar.pt(String(localized: "Signed in with Apple", comment: "Settings account subtitle")) : Grammar.pt(String(localized: "Signed in with Google", comment: "Settings account subtitle")))
                            JungleDivider()
                            Button { Task { await sync.sync() } } label: { JungleRow(icon: .repeat, title: Grammar.pt(String(localized: "Sync", comment: "Settings title")), subtitle: sync.summary) }.buttonStyle(.plain)
                            JungleDivider()
                            NavigationLink { DevicesView() } label: { JungleRow(icon: .calendarClock, title: Grammar.pt(String(localized: "Your devices", comment: "Settings title")), chevron: true) }.buttonStyle(.plain)
                            JungleDivider()
                            ExportDataRow()
                            JungleDivider()
                            ReferralRow()
                            JungleDivider()
                            Button { confirmSignOut = true } label: { JungleRow(icon: .mail, title: Grammar.pt(String(localized: "Sign out", comment: "Settings title"))) }.buttonStyle(.plain)
                            JungleDivider()
                            Button { confirmDelete = true } label: { JungleRow(icon: .emptyPot, title: Grammar.pt(String(localized: "Delete account and data", comment: "Settings title"))) }.buttonStyle(.plain)
                        }
                    }
                    SharedJungleSettingsGroup()
                    if !JungleAPI.shared.hasSession {
                    JungleGroup(title: Grammar.pt(String(localized: "iCloud backup", comment: "Settings title")), footer: Grammar.pt(String(localized: "Your plants, photos and history copy to your private iCloud. Sign in to the same iCloud on a new iPhone and your jungle comes back on its own.", comment: "Settings footer"))) {
                        JungleRow(icon: .weather, title: Grammar.pt(String(localized: "Back up to iCloud", comment: "Settings title")), subtitle: cloud.summary) {
                            let blocked = cloud.status == .noAccount || (cloud.status == .unavailable && !cloud.pendingRestart)
                            Toggle("", isOn: Binding(get: { CloudBackup.enabled && !blocked }, set: { cloud.setEnabled($0) })).labelsHidden()
                                .disabled(blocked)
                        }
                    }
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "Care alerts", comment: "Settings title")), footer: Grammar.pt(String(localized: "How and when your plants can reach you.", comment: "Settings footer"))) {
                        NavigationLink { ReminderSettingsView() } label: {
                            JungleRow(icon: .notification, title: Grammar.pt(String(localized: "Reminders", comment: "Settings title")), subtitle: ReminderSettingsView.summary, chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "You", comment: "Settings title"))) {
                        JungleRow(icon: .profile, title: Grammar.pt(String(localized: "Name", comment: "Settings title"))) {
                            TextField("Your name", text: $settings.ownerName).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        }
                        JungleDivider()
                        NavigationLink { ClimateSettingsView() } label: {
                            JungleRow(icon: .globe, title: Grammar.pt(String(localized: "Where you grow", comment: "Settings title")), subtitle: Climate.shared.profile.map { Grammar.pt(String(localized: "\($0.place) · \(Climate.shared.biome)", comment: "Settings row subtitle: city and climate type")) } ?? Grammar.pt(String(localized: "Set your place for local climate and weather", comment: "Settings row subtitle when no place")), chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "Home screen", comment: "Settings title"))) {
                        Button { iconPicker = true } label: {
                            HStack(spacing: 12) {
                                Image(appIcon.preview).resizable().scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("App icon").font(.body).foregroundStyle(Jungle.text)
                                    Text(appIcon.title).font(.caption).foregroundStyle(Jungle.subtle)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.tertiary)
                            }
                            .padding(.vertical, 11).frame(minHeight: 52).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "At home", comment: "Settings title")), footer: Grammar.pt(String(localized: "We'll gently warn you about plants that could hurt them.", comment: "Settings footer"))) {
                        JungleRow(icon: .cat, title: Grammar.pt(String(localized: "Cats", comment: "Settings title"))) { Toggle("", isOn: $settings.hasCats).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .dog, title: Grammar.pt(String(localized: "Dogs", comment: "Settings title"))) { Toggle("", isOn: $settings.hasDogs).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .kid, title: Grammar.pt(String(localized: "Small children", comment: "Settings title"))) { Toggle("", isOn: $settings.hasKids).labelsHidden() }
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "Weather", comment: "Settings section title")), footer: weatherNote ?? Grammar.pt(String(localized: "We'll send a heads-up before frost or a heatwave hits your area.", comment: "Settings footer for frost and heatwave alerts"))) {
                        JungleRow(icon: .frost, title: Grammar.pt(String(localized: "Frost & heatwave alerts", comment: "Settings toggle title; max 30 chars"))) {
                            Toggle("", isOn: Binding(get: { weatherWatch }, set: { on in
                                weatherWatch = on; weatherNote = nil
                                Task {
                                    let now = await WeatherWatch.set(on)
                                    weatherWatch = now
                                    if on && !now { weatherNote = Grammar.pt(String(localized: "We need your rough location to send alerts. You can allow it in the Settings app.", comment: "Settings footer: location missing for weather alerts")) }
                                }
                            })).labelsHidden()
                        }
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "Weekly digest", comment: "Me row subtitle / Settings toggle: weekly summary")), footer: Grammar.pt(String(localized: "A Sunday note with what's coming up, who to watch and who grew.", comment: "Settings footer under the weekly digest toggle"))) {
                        JungleRow(icon: .calendarClock, title: Grammar.pt(String(localized: "Weekly digest", comment: "Me row subtitle / Settings toggle: weekly summary"))) {
                            Toggle("", isOn: Binding(get: { digestOn }, set: { on in digestOn = on; Task { await DigestAPI.set(on) } })).labelsHidden()
                        }
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "Your plan", comment: "Settings title"))) {
                        if plus {
                            JungleRow(icon: .addPlant, title: Grammar.pt(String(localized: "\(Store.shared.planName) is active", comment: "Settings title")), subtitle: Grammar.pt(String(localized: "Thank you for growing with us", comment: "Settings subtitle")))
                            JungleDivider()
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                JungleRow(icon: .calendarClock, title: Grammar.pt(String(localized: "Manage subscription", comment: "Settings title")), chevron: true)
                            }.buttonStyle(.plain)
                        } else {
                            Button { paywall = true } label: {
                                JungleRow(icon: .addPlant, title: Grammar.pt(String(localized: "See plans", comment: "Settings title")), subtitle: Grammar.pt(String(localized: "Room for every plant, and no ads", comment: "Settings subtitle")), chevron: true)
                            }.buttonStyle(.plain)
                        }
                        JungleDivider()
                        Button { Task { await Store.shared.restore() } } label: {
                            JungleRow(icon: .repeat, title: Grammar.pt(String(localized: "Restore purchases", comment: "Settings title")))
                        }.buttonStyle(.plain)
                    }
                    if !plus {
                        JungleGroup(title: Grammar.pt(String(localized: "Privacy", comment: "Settings title")), footer: Grammar.pt(String(localized: "Your plants' photos and stories stay yours. Ads help keep My Tiny Jungle free for everyone.", comment: "Settings footer"))) {
                            Button { AdsManager.shared.presentPrivacyOptions() } label: {
                                JungleRow(icon: .shieldStar, title: Grammar.pt(String(localized: "Privacy and ad choices", comment: "Settings title")), chevron: true)
                            }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: Grammar.pt(String(localized: "About", comment: "Settings title")), footer: Grammar.pt(String(localized: "Our care tips come from botanists and trusted plant sources like Kew Gardens and the ASPCA. Every plant is a little different, so trust your fingers in the soil too.", comment: "Settings footer"))) {
                        JungleRow(icon: .leafTag, title: Grammar.pt(String(localized: "Version", comment: "Settings title"))) {
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").foregroundStyle(Jungle.subtle)
                        }
                        ForEach(Self.legalLinks, id: \.path) { l in
                            JungleDivider()
                            Link(destination: Self.site(l.path)) {
                                JungleRow(icon: l.icon, title: l.title, chevron: true)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .jungleBackdrop()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $paywall) { PaywallView() }
            .sheet(isPresented: $iconPicker, onDismiss: { appIcon = JungleAppIcon.current }) { AppIconPickerView() }
            .task { await cloud.refresh() }
            .confirmationDialog("Sign out of My Tiny Jungle?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { auth.signOut(); dismiss() }
            } message: { Text("Your plants stay on this iPhone and in your account. Sign in again to keep syncing.") }
            .confirmationDialog("Delete your account and all data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { Task { if await auth.deleteAccountAndData(ctx) { dismiss() } } }
            } message: { Text("This deletes your account and erases every plant, photo and care history on every device. It can't be undone. Subscriptions are managed in your Apple account.") }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
