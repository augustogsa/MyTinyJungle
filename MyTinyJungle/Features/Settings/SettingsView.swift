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
                        JungleGroup(title: "Account") {
                            JungleRow(icon: .profile, title: a.email ?? a.name ?? "Signed in", subtitle: a.provider == .apple ? "Signed in with Apple" : "Signed in with Google")
                            JungleDivider()
                            Button { confirmSignOut = true } label: { JungleRow(icon: .mail, title: "Sign out") }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: "iCloud backup", footer: "Your plants, photos and history copy to your private iCloud. Sign in to the same iCloud on a new iPhone and your jungle comes back on its own.") {
                        JungleRow(icon: .weather, title: "Back up to iCloud", subtitle: cloud.summary) {
                            let blocked = cloud.status == .noAccount || (cloud.status == .unavailable && !cloud.pendingRestart)
                            Toggle("", isOn: Binding(get: { CloudBackup.enabled && !blocked }, set: { cloud.setEnabled($0) })).labelsHidden()
                                .disabled(blocked)
                        }
                    }
                    JungleGroup(title: "Care alerts", footer: "How and when your plants can reach you.") {
                        NavigationLink { ReminderSettingsView() } label: {
                            JungleRow(icon: .notification, title: "Reminders", subtitle: ReminderSettingsView.summary, chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: "You") {
                        JungleRow(icon: .profile, title: "Name") {
                            TextField("Your name", text: $settings.ownerName).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        }
                        JungleDivider()
                        NavigationLink { ClimateSettingsView() } label: {
                            JungleRow(icon: .globe, title: "Where you grow", subtitle: Climate.shared.profile.map { "\($0.place) · \(Climate.shared.biome)" } ?? "Set your place for local climate and weather", chevron: true)
                        }.buttonStyle(.plain)
                    }
                    JungleGroup(title: "At home", footer: "We'll gently warn you about plants that could hurt them.") {
                        JungleRow(icon: .shieldCheck, title: "Cats") { Toggle("", isOn: $settings.hasCats).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .shieldLeaf, title: "Dogs") { Toggle("", isOn: $settings.hasDogs).labelsHidden() }
                        JungleDivider()
                        JungleRow(icon: .heartPin, title: "Small children") { Toggle("", isOn: $settings.hasKids).labelsHidden() }
                    }
                    JungleGroup(title: "Tiny Jungle Plus") {
                        if plus {
                            JungleRow(icon: .crown, title: "Plus is active", subtitle: "Thank you for growing with us")
                            JungleDivider()
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                JungleRow(icon: .calendarClock, title: "Manage subscription", chevron: true)
                            }.buttonStyle(.plain)
                        } else {
                            Button { paywall = true } label: {
                                JungleRow(icon: .crown, title: "Get Plus", subtitle: "Room for every plant, and no ads", chevron: true)
                            }.buttonStyle(.plain)
                        }
                        JungleDivider()
                        Button { Task { await Store.shared.restore() } } label: {
                            JungleRow(icon: .repeat, title: "Restore purchases")
                        }.buttonStyle(.plain)
                    }
                    if !plus {
                        JungleGroup(title: "Privacy", footer: "Your plants' photos and stories stay yours. Ads help keep Tiny Jungle free for everyone.") {
                            Button { AdsManager.shared.presentPrivacyOptions() } label: {
                                JungleRow(icon: .shieldStar, title: "Privacy and ad choices", chevron: true)
                            }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: "About", footer: "Our care tips come from botanists and trusted plant sources like Kew Gardens and the ASPCA. Every plant is a little different, so trust your fingers in the soil too.") {
                        JungleRow(icon: .leafTag, title: "Version") {
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
