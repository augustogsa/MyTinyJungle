import SwiftUI

/// Server-driven switches from Content/config.json (published with the content pack, live after the next
/// manifest check): the oldest app version still allowed, and feature flags to turn things off without a release.
/// Unknown flags default to on, so an old config never hides a feature by accident.
@MainActor
enum RemoteConfig {
    private struct Config: Decodable { var minVersion: String?; var flags: [String: Bool]? }

    private static var config: Config? {
        _ = ContentStore.shared.revision
        return ContentFiles.data("config.json").flatMap { try? JSONDecoder().decode(Config.self, from: $0) }
    }

    static func flag(_ name: String) -> Bool { config?.flags?[name] ?? true }

    static var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// True when this build is older than the server's minimum.
    static var updateRequired: Bool {
        guard let min = config?.minVersion else { return false }
        return appVersion.compare(min, options: .numeric) == .orderedAscending
    }
}

private struct UpdateGate: ViewModifier {
    @Environment(\.openURL) private var openURL
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: .constant(RemoteConfig.updateRequired)) {
            VStack(spacing: 16) {
                Spacer()
                ErtyView(mood: .wave, size: 140)
                Text("Time for an update", comment: "Forced update title").font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                Text("This version of My Tiny Jungle is too old to keep your plants in sync. The new one is free and takes a moment.", comment: "Forced update message")
                    .font(.body).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                Spacer()
                Button { openURL(URL(string: "https://apps.apple.com/app/id6836292367")!) } label: {
                    Text("Update now", comment: "Forced update button").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }.buttonStyle(.glassProminent).tint(Jungle.forest)
            }
            .padding(24)
            .jungleBackdrop()
            .interactiveDismissDisabled()
        }
    }
}

extension View {
    /// Blocks the app with an update screen when the server says this version is no longer supported.
    func updateGate() -> some View { modifier(UpdateGate()) }
}
