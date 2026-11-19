import SwiftUI
import SwiftData
import GoogleSignIn
import Combine
import UserNotifications

@main
struct MyTinyJungleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container: ModelContainer?
    static let shared: ModelContainer = {
        #if DEBUG
        AuthManager.applyTestSession()
        #endif
        let schema = Schema([Plant.self, CareEvent.self, ChatMessage.self, OwnedProduct.self, Space.self, CareTask.self, Propagation.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        // iCloud backup: mirror to the private CloudKit database until the account syncs through the API
        // (then the server is the backup, and two mirrors would deliver every record twice). Never for tests or demo data.
        if CloudBackup.enabled && !JungleAPI.shared.hasSession && !inMemory && DemoSeeder.photoDir == nil,
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
            Group {
                if let container { MainScene(container: container) } else { LaunchSplash() }
            }
            .task {
                // The store (and its iCloud mirror) opens off the main thread, so the first frame is never blocked.
                guard container == nil else { return }
                let started = Date()
                let c = await Task.detached(priority: .userInitiated) { MyTinyJungleApp.shared }.value
                NotificationDelegate.shared.container = c
                let shown = Date().timeIntervalSince(started)
                if shown < 1.2 { try? await Task.sleep(for: .seconds(1.2 - shown)) }
                withAnimation(.easeOut(duration: 0.35)) { container = c }
            }
        }
    }
}

/// The app once the store is open.
private struct MainScene: View {
    let container: ModelContainer
    var body: some View {
            RootView()
                .modifier(ErtyCheerOverlay())
                .task { if ProcessInfo.processInfo.arguments.contains("-ertyDemo") { try? await Task.sleep(for: .seconds(1)); ErtyCheer.shared.show(.water, "Watered · Goldie") } }
                .tint(Jungle.tint)
                .task { DemoSeeder.seedIfAsked(container.mainContext) }
                .task { try? await Task.sleep(for: .seconds(2)); AdPool.shared.start() }
                .task {
                    JungleSync.shared.start(container)
                    Task { await ContentStore.shared.refresh() }
                    #if DEBUG
                    Task { await HouseholdSelfTest.run() }
                    #endif
                    await AuthManager.shared.refresh(); await CloudBackup.shared.refresh()
                    await Store.shared.refresh()
                    await JungleSync.shared.sync()
                }
                .onOpenURL { url in
                    if DigestAPI.handle(url) || DeepLink.handle(url) { return }
                    if let code = HouseholdCloud.code(from: url) { Task { await Household.shared.accept(code: code) } }
                    else if let code = Referrals.code(from: url) { Task { await Referrals.received(code) } }
                    else if !PlanLink.handle(url) { GIDSignIn.sharedInstance.handle(url) }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { a in
                    if let url = a.webpageURL, let code = HouseholdCloud.code(from: url) { Task { await Household.shared.accept(code: code) } }
                    else if let url = a.webpageURL, let code = Referrals.code(from: url) { Task { await Referrals.received(code) } }
                }
                .updateGate()
                .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.modelContext) private var ctx
    @AppStorage("selectedTab") private var tab = 0
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("openPlantChat") private var openChat = ""
    @State private var openHouse = false
    var body: some View {
        let skip = DemoSeeder.photoDir != nil || ProcessInfo.processInfo.arguments.contains("-uiTesting")
        // `-setupChat` opens the setup chat directly (screenshots and QA, no sign-in needed).
        if ProcessInfo.processInfo.arguments.contains("-setupChat") && !onboarded {
            SetupChatView { onboarded = true }
        } else if !skip && !AuthManager.shared.signedIn {
            SignInView()
        } else if !skip && !onboarded {
            SetupChatView { onboarded = true }
        } else { tabs }
    }
    private var tabs: some View {
        tabView
            .background(GrammarSync())
            .modifier(PlanLinkSheet())
            .modifier(DigestLinkSheet())
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
                if p == .background { Task { await CareReminders.reschedule(ctx) }; Task { await JungleSync.shared.sync() } }
                if p == .active { Task { await JungleSync.shared.sync() }; Task { await ContentStore.shared.refresh() } }
                if p == .active { Task { await Household.shared.sync(ctx); if UserDefaults.standard.bool(forKey: "house.openHub") { UserDefaults.standard.set(false, forKey: "house.openHub"); openHouse = true } }; Task { await Climate.shared.refreshClimate(); await Climate.shared.refreshForecast(); ProactiveVoice.speak(ctx); await CareReminders.reschedule(ctx) } }
            }
            // Reschedule on every change to the care log.
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in
                Task { await CareReminders.reschedule(ctx) }
                Task { await Household.shared.onLocalChange(ctx) }
            }
            .sheet(isPresented: $openHouse) { NavigationStack { SharedJungleView() } }
            .task {
                if Household.demo { try? await Task.sleep(for: .seconds(1.5)); Household.shared.seedDemo(ctx) }
                await Household.shared.sync(ctx)
                if ProcessInfo.processInfo.arguments.contains("-openSharedJungle") { openHouse = true }
                if DemoSeeder.demoOpen == "chat" {
                    for _ in 0..<60 { if let p = (try? ctx.fetch(FetchDescriptor<Plant>()))?.first(where: { !($0.messages ?? []).isEmpty }) { try? await Task.sleep(for: .seconds(1.5)); openChat = p.id.uuidString; break }; try? await Task.sleep(for: .seconds(0.5)) }
                }
            }
            .task {
                JungleRooms.sync((try? ctx.fetch(FetchDescriptor<Space>())) ?? [])
                await Climate.shared.refreshClimate()
                await Climate.shared.refreshForecast()
                ProactiveVoice.speak(ctx)
                if CareReminders.enabled, DemoSeeder.photoDir == nil, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined {
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
        // Plant names in any message open that plant (Today pushes inside its own stack).
        .plantLinks()
    }
    /// 3D tab icon: full colour when selected, faded grey when not.
    private func tabLabel(_ title: LocalizedStringKey, _ key: String, _ value: Int) -> some View {
        Label { Text(title) } icon: { Image("TabIcons/\(key)\(tab == value ? "On" : "Off")").renderingMode(.original) }
    }
}


/// Keeps `Grammar.names` in sync with the plants and housemates, so Portuguese sentences get "da Dourada" / "do Sargento".
private struct GrammarSync: View {
    @Query private var plants: [Plant]
    var body: some View {
        Color.clear
            .onAppear(perform: sync)
            .onChange(of: plants.map { "\($0.name)|\($0.nameGenderRaw)" }) { sync() }
    }
    private func sync() {
        var m: [String: Grammar.Gender] = [:]
        for member in Household.shared.members { m[member.firstName] = Grammar.infer(member.firstName) }
        for p in plants where !p.name.isEmpty { m[p.name] = p.nameGender }
        Grammar.names = m
    }
}
