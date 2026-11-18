import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = JungleSettings.shared
    @State private var paywall = false
    @State private var confirmSignOut = false
    @Environment(\.modelContext) private var ctx
    private var plus: Bool { Store.shared.isPlus }
    private var auth = AuthManager.shared
    private var cloud = CloudBackup.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let a = auth.account {
                        JungleGroup(title: String(localized: "Account", comment: "Settings title")) {
                            JungleRow(icon: .profile, title: a.email ?? a.name ?? String(localized: "Signed in", comment: "Settings account row fallback"), subtitle: a.provider == .apple ? String(localized: "Signed in with Apple", comment: "Settings account subtitle") : String(localized: "Signed in with Google", comment: "Settings account subtitle"))
                            JungleDivider()
                            Button { confirmSignOut = true } label: { JungleRow(icon: .mail, title: String(localized: "Sign out", comment: "Settings title")) }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: String(localized: "iCloud backup", comment: "Settings title"), footer: String(localized: "Your plants, photos and history copy to your private iCloud. Sign in to the same iCloud on a new iPhone and your jungle comes back on its own.", comment: "Settings footer")) {
                        JungleRow(icon: .weather, title: String(localized: "Back up to iCloud", comment: "Settings title"), subtitle: cloud.summary) {
                            let blocked = cloud.status == .noAccount || (cloud.status == .unavailable && !cloud.pendingRestart)
                            Toggle("", isOn: Binding(get: { CloudBackup.enabled && !blocked }, set: { cloud.setEnabled($0) })).labelsHidden()
                                .disabled(blocked)
                        }
                    }
                    JungleGroup(title: String(localized: "Care alerts", comment: "Settings title"), footer: String(localized: "How and when your plants can reach you.", comment: "Settings footer")) {
                        NavigationLink { ReminderSettingsView() } label: {
                            JungleRow(icon: .notification, title: String(localized: "Reminders", comment: "Settings title"), subtitle: ReminderSettingsView.summary, chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: String(localized: "You", comment: "Settings title")) {
                        JungleRow(icon: .profile, title: String(localized: "Name", comment: "Settings title")) {
                            TextField("Your name", text: $settings.ownerName).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        }
                        JungleDivider()
                        NavigationLink { ClimateSettingsView() } label: {
                            JungleRow(icon: .globe, title: String(localized: "Where you grow", comment: "Settings title"), subtitle: Climate.shared.profile.map { String(localized: "\($0.place) · \(Climate.shared.biome)", comment: "Settings row subtitle: city and climate type") } ?? String(localized: "Set your place for local climate and weather", comment: "Settings row subtitle when no place"), chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: String(localized: "At home", comment: "Settings title"), footer: String(localized: "We'll gently warn you about plants that could hurt them.", comment: "Settings footer")) {
                        JungleRow(icon: .shieldCheck, title: String(localized: "Cats", comment: "Settings title")) { Toggle("", isOn: $settings.hasCats).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .shieldLeaf, title: String(localized: "Dogs", comment: "Settings title")) { Toggle("", isOn: $settings.hasDogs).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .heartPin, title: String(localized: "Small children", comment: "Settings title")) { Toggle("", isOn: $settings.hasKids).labelsHidden() }
                    }
                    JungleGroup(title: String(localized: "Tiny Jungle Plus", comment: "Settings title")) {
                        if plus {
                            JungleRow(icon: .crown, title: String(localized: "Plus is active", comment: "Settings title"), subtitle: String(localized: "Thank you for growing with us", comment: "Settings subtitle"))
                            JungleDivider()
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                JungleRow(icon: .calendarClock, title: String(localized: "Manage subscription", comment: "Settings title"), chevron: true)
                            }.buttonStyle(.plain)
                        } else {
                            Button { paywall = true } label: {
                                JungleRow(icon: .crown, title: String(localized: "Get Plus", comment: "Settings title"), subtitle: String(localized: "Room for every plant, and no ads", comment: "Settings subtitle"), chevron: true)
                            }.buttonStyle(.plain)
                        }
                        JungleDivider()
                        Button { Task { await Store.shared.restore() } } label: {
                            JungleRow(icon: .repeat, title: String(localized: "Restore purchases", comment: "Settings title"))
                        }.buttonStyle(.plain)
                    }
                    if !plus {
                        JungleGroup(title: String(localized: "Privacy", comment: "Settings title"), footer: String(localized: "Your plants' photos and stories stay yours. Ads help keep Tiny Jungle free for everyone.", comment: "Settings footer")) {
                            Button { AdsManager.shared.presentPrivacyOptions() } label: {
                                JungleRow(icon: .shieldStar, title: String(localized: "Privacy and ad choices", comment: "Settings title"), chevron: true)
                            }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: String(localized: "About", comment: "Settings title"), footer: String(localized: "Our care tips come from botanists and trusted plant sources like Kew Gardens and the ASPCA. Every plant is a little different, so trust your fingers in the soil too.", comment: "Settings footer")) {
                        JungleRow(icon: .leafTag, title: String(localized: "Version", comment: "Settings title")) {
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").foregroundStyle(Jungle.subtle)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .jungleBackdrop()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $paywall) { PaywallView() }
            .task { await cloud.refresh() }
            .confirmationDialog("Sign out of My Tiny Jungle?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { auth.signOut(); dismiss() }
            } message: { Text("Your plants stay on this iPhone and in iCloud.") }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
