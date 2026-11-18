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

    enum Action: String { case watered = "care.watered", wet = "care.wet", snooze = "care.snooze" }

    static func registerCategories() {
        let watered = UNNotificationAction(identifier: Action.watered.rawValue, title: "Watered", options: [], icon: .init(systemImageName: "drop.fill"))
        let wet = UNNotificationAction(identifier: Action.wet.rawValue, title: "Soil still wet", options: [], icon: .init(systemImageName: "hand.point.down.fill"))
        let snooze = UNNotificationAction(identifier: Action.snooze.rawValue, title: "Snooze to tomorrow", options: [], icon: .init(systemImageName: "moon.zzz.fill"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [watered, wet, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: categoryMany, actions: [watered, snooze], intentIdentifiers: []),
        ])
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
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
                return offset == 0 ? CareEngine.status(for: p, now: fire).needsAttention : thirsty.contains(p.id)
            }
            let planned = forecast.filter { cal.isDate($0.date, inSameDayAs: day) && !due.map(\.id).contains($0.plantID ?? UUID()) && $0.kind != .weather }
            guard !due.isEmpty || !planned.isEmpty else { continue }
            let c = content(due: due, planned: planned, at: fire)
            c.badge = NSNumber(value: due.count)
            let trig = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "care-\(offset)", content: c, trigger: trig))
        }

        // Frost, heat or storms for plants outside: an evening heads-up, never in quiet hours.
        if CarePrefs.isOn(.weather), let alert = Climate.shared.alerts(for: plants, now: now).first {
            let c = UNMutableNotificationContent()
            c.title = alert.title
            c.body = alert.detail
            c.sound = .default
            c.threadIdentifier = "weather"
            let evening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            let fire = CarePrefs.gentle(evening > now ? evening : now.addingTimeInterval(15 * 60))
            try? await center.add(UNNotificationRequest(identifier: "care-weather", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSince(now)), repeats: false)))
        }

        // A struggling plant gets its own soft nudge a few hours later if nothing changes.
        if CarePrefs.isOn(.water), let p = plants.first(where: { CareEngine.status(for: $0) == .struggling && !snoozed($0.id) }) {
            let c = UNMutableNotificationContent()
            c.title = "\(p.name) misses you"
            c.body = "It's been a while since its last drink. Feel the soil, and if it's dry, a slow, deep sip will perk it right up."
            c.sound = .default
            c.categoryIdentifier = category
            c.userInfo = ["plants": [p.id.uuidString]]
            if let a = attachment(p) { c.attachments = [a] }
            let fire = CarePrefs.gentle(now.addingTimeInterval(4 * 3600))
            try? await center.add(UNNotificationRequest(identifier: "care-struggling", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSince(now), repeats: false)))
        }
    }

    /// Builds the one note of the day.
    static func content(due: [Plant], planned: [ForecastItem], at fire: Date) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.sound = .default
        c.threadIdentifier = "care"
        c.interruptionLevel = .passive
        let ids = due.map(\.id.uuidString)
        c.userInfo = ["plants": ids]
        if due.count == 1, let p = due.first {
            c.title = "\(p.name) is thinking of you"
            c.body = line(CareEngine.status(for: p, now: fire), name: p.name)
            c.categoryIdentifier = category
            if let a = attachment(p) { c.attachments = [a] }
        } else if due.count > 1 {
            let names = ListFormatter.localizedString(byJoining: due.prefix(3).map(\.name)) + (due.count > 3 ? " and \(due.count - 3) more" : "")
            c.title = "\(due.count) plants would love a visit"
            c.body = "\(names) are ready for a little love."
            c.categoryIdentifier = categoryMany
            if let a = attachment(due[0]) { c.attachments = [a] }
        } else {
            c.title = planned.count == 1 ? planned[0].plantName.isEmpty ? "A little plan for today" : "\(planned[0].plantName) has a little wish" : "A gentle plan for today"
            c.interruptionLevel = .passive
        }
        let extras = planned.prefix(due.isEmpty ? 3 : 2).map(\.line)
        if !extras.isEmpty {
            c.body = ([c.body].filter { !$0.isEmpty } + extras.map { $0 + "." }).joined(separator: " ")
        }
        if due.isEmpty, let id = planned.first?.plantID { c.userInfo = ["plants": [id.uuidString], "planned": true] }
        return c
    }

    /// The plant's photo as a thumbnail on the note.
    static func attachment(_ p: Plant) -> UNNotificationAttachment? {
        guard let data = p.photo, let img = UIImage(data: data),
              let jpg = img.preparingThumbnail(of: CGSize(width: 600, height: 600 * img.size.height / max(img.size.width, 1)))?.jpegData(compressionQuality: 0.8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plant-\(p.id)-\(UUID().uuidString.prefix(6)).jpg")
        guard (try? jpg.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: p.id.uuidString, url: url, options: nil)
    }

    private static func line(_ s: PlantStatus, name: String) -> String {
        switch s {
        case .struggling: "It's been a long while since \(name)'s last drink. A slow, deep sip would mean the world."
        case .thirsty: "\(name)'s soil should be dry by now. A little drink would feel wonderful."
        case .checkSoil: "Pop a finger in \(name)'s soil and see how it feels."
        case .petRisk: "\(name) can upset furry friends if nibbled. Maybe a higher shelf?"
        default: "\(name) would love a quick hello today."
        }
    }

    /// Handles a notification action, in the background, and logs real care.
    @MainActor
    static func handle(_ action: String, plantIDs: [String], ctx: ModelContext) async {
        let ids = Set(plantIDs.compactMap(UUID.init))
        let plants = ((try? ctx.fetch(FetchDescriptor<Plant>())) ?? []).filter { ids.contains($0.id) }
        let now = Date()
        switch Action(rawValue: action) {
        case .watered:
            for p in plants { JungleBrain.apply(.init(kind: .water, plantIDs: [p.id], date: now), to: p, in: ctx, now: now, source: "notification") }
        case .wet:
            for p in plants { JungleBrain.apply(.init(kind: .soilCheck, plantIDs: [p.id], date: now, soil: .wet), to: p, in: ctx, now: now, source: "notification") }
        case .snooze:
            let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(3600)
            for p in plants { UserDefaults.standard.set(tomorrow, forKey: "snooze.\(p.id)") }
        case nil: return
        }
        try? ctx.save()
        await reschedule(ctx)
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
        let ids = response.notification.request.content.userInfo["plants"] as? [String] ?? []
        let action = response.actionIdentifier
        await MainActor.run { UserDefaults.standard.set(action, forKey: "lastNotificationAction") }
        guard let container else { return }
        if action == UNNotificationDefaultActionIdentifier {
            await MainActor.run { UserDefaults.standard.set(0, forKey: "selectedTab") }
            return
        }
        await CareReminders.handle(action, plantIDs: ids, ctx: container.mainContext)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        CareReminders.registerCategories()
        return true
    }
}
