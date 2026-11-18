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

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Jungle.forest)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @State private var tab = 0
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
