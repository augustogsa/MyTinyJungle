import SwiftUI
import SwiftData

@main
struct MyTinyJungleApp: App {
    let container: ModelContainer = {
        let schema = Schema([Plant.self, CareEvent.self, ChatMessage.self, OwnedProduct.self, Space.self, CareTask.self, Propagation.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            fatalError("Store failed to open: \(error)")
        }
    }()

    init() { Self.roundedTitles() }

    /// Navigation titles in SF Pro Rounded, warm forest ink.
    private static func roundedTitles() {
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            let d = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: d, size: 0))
        }
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xE4EBE2) : UIColor(hex: 0x3E4E3D) }
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        a.largeTitleTextAttributes = [.font: rounded(.largeTitle, .bold), .foregroundColor: ink]
        a.titleTextAttributes = [.font: rounded(.headline, .semibold), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
        let s2 = UINavigationBarAppearance(); s2.configureWithDefaultBackground()
        s2.largeTitleTextAttributes = a.largeTitleTextAttributes; s2.titleTextAttributes = a.titleTextAttributes
        UINavigationBar.appearance().compactAppearance = s2
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Jungle.forest)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("selectedTab") private var tab = 0
    @AppStorage("onboarded") private var onboarded = false
    var body: some View {
        if !onboarded && !ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            OnboardingView { onboarded = true }
        } else { tabs }
    }
    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "bubble.left.and.text.bubble.right", value: 0) { TodayView() }
            Tab("Plants", systemImage: "leaf", value: 1) { PlantsView() }
            Tab("Care", systemImage: "calendar", value: 2) { CareView() }
            Tab("Scan", systemImage: "barcode.viewfinder", value: 3) { ScanView() }
            Tab("Me", systemImage: "person.crop.circle", value: 4) { MeView() }
        }
    }
}
