import SwiftUI
import SwiftData
import GoogleSignIn
import Combine
import UserNotifications

@main
struct MyTinyJungleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer = MyTinyJungleApp.shared
    static let shared: ModelContainer = {
        let schema = Schema([Plant.self, CareEvent.self, ChatMessage.self, OwnedProduct.self, Space.self, CareTask.self, Propagation.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        // iCloud backup: mirror to the private CloudKit database. Never for tests or demo data.
        if CloudBackup.enabled && !inMemory && DemoSeeder.photoDir == nil,
           let c = try? ModelContainer(for: schema, configurations: ModelConfiguration(cloudKitDatabase: .private(CloudBackup.containerID))) {
            CloudBackup.activeThisLaunch = true
            return c
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none))
        } catch {
            fatalError("Store failed to open: \(error)")
        }
    }()

    init() {
        Self.roundedTitles()
        NotificationDelegate.shared.container = Self.shared
    }

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
                .task { DemoSeeder.seedIfAsked(container.mainContext) }
                .task { try? await Task.sleep(for: .seconds(2)); AdPool.shared.start() }
                .task { await AuthManager.shared.refresh(); await CloudBackup.shared.refresh() }
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.modelContext) private var ctx
    @AppStorage("selectedTab") private var tab = 0
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("openPlantChat") private var openChat = ""
    var body: some View {
        let skip = DemoSeeder.photoDir != nil || ProcessInfo.processInfo.arguments.contains("-uiTesting")
        if !skip && !AuthManager.shared.signedIn {
            SignInView()
        } else if !skip && !onboarded {
            OnboardingView { onboarded = true }
        } else { tabs }
    }
    private var tabs: some View {
        tabView
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-notifyDemo") else { return }
                try? await Task.sleep(for: .seconds(2))
                await PlantNote.demo(ctx)
            }
            // A tap on a plant's note opens its chat.
            .sheet(isPresented: Binding(get: { !openChat.isEmpty }, set: { if !$0 { openChat = "" } })) {
                if let p = (try? ctx.fetch(FetchDescriptor<Plant>()))?.first(where: { $0.id.uuidString == openChat }) {
                    NavigationStack { PlantChatView(plant: p) }
                }
            }
            .onChange(of: phase) { _, p in
                if p == .background { Task { await CareReminders.reschedule(ctx) } }
                if p == .active { Task { await Climate.shared.refreshClimate(); await Climate.shared.refreshForecast(); ProactiveVoice.speak(ctx); await CareReminders.reschedule(ctx) } }
            }
            // Reschedule on every change to the care log.
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in
                Task { await CareReminders.reschedule(ctx) }
            }
            .task {
                JungleRooms.sync((try? ctx.fetch(FetchDescriptor<Space>())) ?? [])
                await Climate.shared.refreshClimate()
                await Climate.shared.refreshForecast()
                ProactiveVoice.speak(ctx)
                if CareReminders.enabled, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined {
                    await CareReminders.requestPermission()
                }
                await CareReminders.reschedule(ctx)
            }
    }
    private var tabView: some View {
        TabView(selection: $tab) {
            Tab(value: 0) { TodayView() } label: { tabLabel("Today", "today", 0) }
            Tab(value: 1) { PlantsView() } label: { tabLabel("Plants", "plants", 1) }
            Tab(value: 2) { CareView() } label: { tabLabel("Care", "care", 2) }
            Tab(value: 3) { ScanView() } label: { tabLabel("Scan", "scan", 3) }
            Tab(value: 4) { MeView() } label: { tabLabel("Me", "me", 4) }
        }
    }
    /// 3D tab icon: full colour when selected, faded grey when not.
    private func tabLabel(_ title: String, _ key: String, _ value: Int) -> some View {
        Label { Text(title) } icon: { Image("TabIcons/\(key)\(tab == value ? "On" : "Off")").renderingMode(.original) }
    }
}
