import Foundation
import UIKit
import UserNotifications
import SwiftData

/// One gentle daily note at your time, outside quiet hours, built from the 14-day forecast.
/// Actions (Watered, Soil still wet, Tomorrow) log care in the background. Rescheduled on every change.
enum CareReminders {
    static let enabledKey = "careReminders"
    static let hourKey = "careReminderHour"
    static let category = "care.plant"
    static let categoryMany = "care.many"
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    static var hour: Int {
        get { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 9 }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    static func registerCategories() { PlantNote.registerCategories() }

    @discardableResult
    static func requestPermission() async -> Bool {
        if DemoSeeder.photoDir != nil { return false } // screenshot demo: no system prompt over the UI
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Snoozed plants stay quiet until this date.
    static func snoozed(_ id: UUID) -> Bool {
        (UserDefaults.standard.object(forKey: "snooze.\(id)") as? Date).map { $0 > Date() } ?? false
    }

    @MainActor
    static func reschedule(_ ctx: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("care-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let plants = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let needing = plants.filter { CareEngine.needsYou($0) && !snoozed($0.id) }.count
        try? await center.setBadgeCount(enabled ? needing : 0)
        guard enabled, await center.notificationSettings().authorizationStatus == .authorized, !plants.isEmpty else { return }
        let props = (try? ctx.fetch(FetchDescriptor<Propagation>())) ?? []
        let cal = Calendar.current, now = Date()
        let forecast = CareForecast.items(for: plants, propagations: props, now: now)

        for offset in 0..<CareForecast.horizon {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let raw = cal.date(bySettingHour: hour, minute: CarePrefs.minute, second: 0, of: day) else { continue }
            let fire = CarePrefs.gentle(raw)
            guard fire > now else { continue }
            // Plants that truly need you that morning, plus anything planned that day.
            let thirsty = Set(forecast.filter { $0.kind == .water && cal.isDate($0.date, inSameDayAs: day) }.compactMap(\.plantID))
            let due = !CarePrefs.isOn(.water) ? [] : plants.filter { p in
                guard !snoozed(p.id) || offset > 0 else { return false }
                // Shared jungle: only whoever's turn it is (anyone if a plant has waited too long).
                guard Household.shared.shouldRemindMe(p, now: fire) else { return false }
                return offset == 0 ? CareEngine.status(for: p, now: fire).needsAttention : thirsty.contains(p.id)
            }
            let planned = forecast.filter { cal.isDate($0.date, inSameDayAs: day) && !due.map(\.id).contains($0.plantID ?? UUID()) && $0.kind != .weather }
            guard !due.isEmpty || !planned.isEmpty else { continue }
            let c = (await content(due: due, planned: planned, at: fire)).mutableCopy() as! UNMutableNotificationContent
            c.badge = NSNumber(value: due.count)
            let trig = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "care-\(offset)", content: c, trigger: trig))
        }

        // Frost, heat or storms for plants outside: an evening heads-up, never in quiet hours.
        if CarePrefs.isOn(.weather), let alert = Climate.shared.alerts(for: plants, now: now).first {
            let outside = plants.filter { alert.plantNames.contains($0.name) }
            let c = await PlantNote.make(.weather, plants: outside.isEmpty ? plants.filter(\.isOutdoor) : outside, title: alert.title, body: alert.detail)
            let evening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            let fire = CarePrefs.gentle(evening > now ? evening : now.addingTimeInterval(15 * 60))
            try? await center.add(UNNotificationRequest(identifier: "care-weather", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSince(now)), repeats: false)))
        }

        // A struggling plant gets its own soft nudge a few hours later if nothing changes.
        if CarePrefs.isOn(.water), let p = plants.first(where: { CareEngine.status(for: $0) == .struggling && !snoozed($0.id) }) {
            let c = await PlantNote.make(.struggling, plants: [p])
            let fire = CarePrefs.gentle(now.addingTimeInterval(4 * 3600))
            try? await center.add(UNNotificationRequest(identifier: "care-struggling", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSince(now), repeats: false)))
        }
    }

    /// Builds the one note of the day: a single plant texts you, several share one warm note.
    static func content(due: [Plant], planned: [ForecastItem], at fire: Date) async -> UNNotificationContent {
        let extras = planned.prefix(due.isEmpty ? 3 : 2).map { $0.line + "." }
        if due.count == 1, let p = due.first {
            let kind: PlantNote.Kind = CareEngine.status(for: p, now: fire) == .struggling ? .struggling
                : CareEngine.requests(for: p, now: fire).contains { $0.kind == .water } ? .water : .soil
            return await PlantNote.make(kind, plants: [p], body: ([PlantNote.voice(kind, plants: [p], now: fire)] + extras.prefix(1)).joined(separator: " "))
        }
        if due.count > 1 {
            return await PlantNote.make(.many, plants: due, body: ([PlantNote.voice(.many, plants: due)] + extras.prefix(1)).joined(separator: " "))
        }
        if planned.contains(where: { $0.kind == .travel }) {
            return await PlantNote.make(.travel, plants: [], body: extras.joined(separator: " "))
        }
        let ids = Set(planned.compactMap(\.plantID))
        let ctx = NotificationDelegate.shared.container?.mainContext
        let ps = ((try? ctx?.fetch(FetchDescriptor<Plant>())) ?? []).filter { ids.contains($0.id) }
        if ps.count == 1, planned.allSatisfy({ $0.kind == .feed }) { return await PlantNote.make(.feed, plants: ps) }
        let c = (await PlantNote.make(.many, plants: ps, title: Grammar.pt(String(localized: "A gentle plan for today", comment: "Daily notification title listing upcoming care; warm; max 40 chars")), body: extras.joined(separator: " "))).mutableCopy() as! UNMutableNotificationContent
        c.interruptionLevel = .passive
        c.relevanceScore = 0.3
        return c
    }

    static func attachment(_ p: Plant) -> UNNotificationAttachment? { PlantNote.attachment(p) }

    private static func line(_ s: PlantStatus, name: String) -> String {
        switch s {
        case .struggling: Grammar.pt(String(localized: "It's been a long while since \(name)'s last drink. A slow, deep sip would mean the world.", comment: "Notification line; %@ plant name; plant very dry; tender"))
        case .thirsty: Grammar.pt(String(localized: "\(name)'s soil should be dry by now. A little drink would feel wonderful.", comment: "Notification line; %@ plant name; time to water"))
        case .checkSoil: Grammar.pt(String(localized: "Pop a finger in \(name)'s soil and see how it feels.", comment: "Notification line; %@ plant name; check soil moisture with finger"))
        case .petRisk: Grammar.pt(String(localized: "\(name) can upset furry friends if nibbled. Maybe a higher shelf?", comment: "Notification line; %@ plant name; toxic to pets; playful"))
        default: Grammar.pt(String(localized: "\(name) would love a quick hello today.", comment: "Notification line; %@ plant name; generic nudge"))
        }
    }

}

/// Receives notification actions, even when the app is not open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    var container: ModelContainer?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run { UserDefaults.standard.set(action, forKey: "lastNotificationAction") }
        if response.notification.request.content.categoryIdentifier == Household.coverCategory {
            await MainActor.run { Household.shared.handleNotification(response) }
            return
        }
        guard let container else { return }
        await PlantNote.handle(response, ctx: container.mainContext)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        CareReminders.registerCategories()
        Task { await Household.registerCategory() }
        application.registerForRemoteNotifications()
        Diagnostics.shared.start()
        return true
    }

    /// The server sends a silent push when someone else changes a jungle we share.
    nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await Self.syncSharedJungle()
    }

    @MainActor private static func syncSharedJungle() async -> UIBackgroundFetchResult {
        guard let ctx = NotificationDelegate.shared.container?.mainContext else { return .noData }
        await Household.shared.sync(ctx)
        await JungleSync.shared.sync()
        return .newData
    }

    nonisolated func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "push.token")
        Task { await JungleAPI.shared.setPushToken(hex) }
    }

}
