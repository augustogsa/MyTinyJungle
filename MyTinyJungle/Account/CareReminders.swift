import Foundation
import UserNotifications
import SwiftData

/// Local care alerts: one morning note per day that has plants due, and a nudge for struggling plants.
/// Rescheduled every time the app goes to the background, so it always matches the latest care log.
enum CareReminders {
    static let enabledKey = "careReminders"
    static let hourKey = "careReminderHour"
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    static var hour: Int {
        get { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 9 }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    static func reschedule(_ ctx: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<8).map { "care-\($0)" } + ["care-struggling"])
        guard enabled, await center.notificationSettings().authorizationStatus == .authorized else { return }
        let plants = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
        guard !plants.isEmpty else { return }
        let cal = Calendar.current, now = Date()

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)),
                  let fire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day), fire > now else { continue }
            let due = plants.filter { CareEngine.status(for: $0, now: fire).needsAttention }
            guard !due.isEmpty else { continue }
            let c = UNMutableNotificationContent()
            let names = due.prefix(3).map(\.name)
            let rest = due.count - names.count
            c.title = due.count == 1 ? "\(names[0]) needs you" : "\(due.count) plants need you today"
            c.body = due.count == 1
                ? line(CareEngine.status(for: due[0], now: fire), name: due[0].name)
                : names.joined(separator: ", ") + (rest > 0 ? " and \(rest) more" : "") + ". Tap to see what each one needs."
            c.sound = .default
            let trig = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "care-\(offset)", content: c, trigger: trig))
        }

        // A struggling plant gets its own nudge in a few hours if nothing changes.
        if let p = plants.first(where: { CareEngine.status(for: $0) == .struggling }) {
            let c = UNMutableNotificationContent()
            c.title = "\(p.name) is struggling"
            c.body = "It's well past its usual watering. Feel the soil and give it a slow drink if it's dry."
            c.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "care-struggling", content: c,
                                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 4 * 3600, repeats: false)))
        }
    }

    private static func line(_ s: PlantStatus, name: String) -> String {
        switch s {
        case .struggling: "\(name) is well past its usual watering. Check it today."
        case .thirsty: "\(name)'s soil should be dry by now. Feel it and water if dry."
        case .checkSoil: "Time for a quick finger test on \(name)'s soil."
        case .petRisk: "\(name) is toxic to pets. Make sure it's out of reach."
        default: "Open Tiny Jungle to see what \(name) needs."
        }
    }
}
