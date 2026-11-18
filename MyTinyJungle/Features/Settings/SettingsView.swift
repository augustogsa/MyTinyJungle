import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = JungleSettings.shared
    @State private var paywall = false
    private var plus: Bool { Store.shared.isPlus }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    JungleGroup(title: "You") {
                        JungleRow(icon: .profile, title: "Name") {
                            TextField("Your name", text: $settings.ownerName).multilineTextAlignment(.trailing).foregroundStyle(Jungle.subtle)
                        }
                        JungleDivider()
                        JungleRow(icon: .globe, title: "Southern hemisphere", subtitle: "Brazil, Australia, South Africa…") {
                            Toggle("", isOn: $settings.southernHemisphere).labelsHidden()
                        }
                    }
                    JungleGroup(title: "At home", footer: "Plants that are unsafe for pets or children warn you.") {
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
                                JungleRow(icon: .crown, title: "Get Plus", subtitle: "Unlimited plants, every scan, no ads", chevron: true)
                            }.buttonStyle(.plain)
                        }
                        JungleDivider()
                        Button { Task { await Store.shared.restore() } } label: {
                            JungleRow(icon: .repeat, title: "Restore purchases")
                        }.buttonStyle(.plain)
                    }
                    if !plus {
                        JungleGroup(title: "Privacy", footer: "Your plant photos and data stay on your device. Ads keep Tiny Jungle free.") {
                            Button { AdsManager.shared.presentPrivacyOptions() } label: {
                                JungleRow(icon: .shieldStar, title: "Privacy and ad choices", chevron: true)
                            }.buttonStyle(.plain)
                        }
                    }
                    JungleGroup(title: "About", footer: "Care knowledge comes from open botanical sources (Kew POWO, GBIF, ASPCA, extension guides). It is guidance, not a guarantee. Always check the soil.") {
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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
