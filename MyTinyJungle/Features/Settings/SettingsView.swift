import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = JungleSettings.shared
    @State private var paywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tiny Jungle Plus") {
                    if Store.shared.isPlus {
                        Label("You're a Plus member. Thank you!", systemImage: "checkmark.seal.fill").foregroundStyle(Jungle.forest)
                        Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    } else {
                        Button("See Plus: €1.99/month or €11.99/year") { paywall = true }
                        Button("Remove ads with Tiny Jungle Plus", systemImage: "nosign") { paywall = true }
                    }
                    Button("Restore purchases") { Task { await Store.shared.restore() } }
                }
                Section("You") { TextField("Your name", text: $settings.ownerName) }
                Section {
                    Toggle("Cats", isOn: $settings.hasCats)
                    Toggle("Dogs", isOn: $settings.hasDogs)
                    Toggle("Small children", isOn: $settings.hasKids)
                } header: { Text("At home") } footer: { Text("Your plants warn you if they're unsafe for pets.") }
                Section {
                    Toggle("Southern hemisphere", isOn: $settings.southernHemisphere)
                } footer: { Text("Seasons drive feeding, repotting and watering. Brazil and Australia are in the southern hemisphere.") }
                if !Store.shared.isPlus {
                    Section {
                        Button("Privacy & ads choices", systemImage: "hand.raised") { AdsManager.shared.presentPrivacyOptions() }
                    } footer: { Text("Your plant photos and data never leave your device. Ads help keep Tiny Jungle free.") }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    Text("Care knowledge is reviewed from open botanical sources (Kew POWO, GBIF, ASPCA, extension guides). Advice is guidance, not a guarantee. Always check the soil.")
                        .font(.footnote).foregroundStyle(Jungle.subtle)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $paywall) { PaywallView() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
