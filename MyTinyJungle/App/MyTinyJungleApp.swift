import SwiftUI
import SwiftData

@main
struct MyTinyJungleApp: App {
    let container: ModelContainer = {
        let schema = Schema([Plant.self, CareEvent.self, ChatMessage.self, OwnedProduct.self])
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
    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "bubble.left.and.text.bubble.right", value: 0) { TodayView() }
            Tab("Plants", systemImage: "leaf", value: 1) { PlantsView() }
            Tab("Scan", systemImage: "barcode.viewfinder", value: 2) { ScanView() }
        }
    }
}
