import SwiftUI
import CloudKit
import CoreData

/// iCloud backup: SwiftData mirrors the store to the user's private CloudKit database.
/// Restore is automatic on any device signed in to the same iCloud account.
@Observable @MainActor
final class CloudBackup {
    static let shared = CloudBackup()
    static let containerID = "iCloud.com.simpleappscompany.mytinyjungle"
    private static let key = "iCloudBackup"

    /// Read before the store opens; a change applies on next launch.
    nonisolated static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    /// Whether the store actually opened with CloudKit this launch.
    nonisolated(unsafe) static var activeThisLaunch = false

    enum Status: Equatable { case checking, on, noAccount, off, unavailable }
    private(set) var status: Status = .checking
    private(set) var lastSync: Date? = UserDefaults.standard.object(forKey: "iCloudLastSync") as? Date
    private(set) var syncing = false
    private(set) var pendingRestart = false

    private init() {
        NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { note in
            guard let e = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let ended = e.endDate, ok = e.succeeded
            MainActor.assumeIsolated {
                self.syncing = ended == nil
                if let ended, ok { self.lastSync = ended; UserDefaults.standard.set(ended, forKey: "iCloudLastSync") }
            }
        }
    }

    func refresh() async {
        guard Self.enabled else { status = .off; return }
        guard Self.activeThisLaunch else { status = .unavailable; return }
        let s = try? await CKContainer(identifier: Self.containerID).accountStatus()
        status = s == .available ? .on : .noAccount
    }

    func setEnabled(_ on: Bool) {
        Self.enabled = on
        pendingRestart = on != Self.activeThisLaunch
        status = on ? (Self.activeThisLaunch ? .on : .unavailable) : .off
    }

    var summary: String {
        switch status {
        case .checking: "Checking iCloud…"
        case .on: syncing ? "Backing up…" : lastSync.map { "Last backup \($0.formatted(.relative(presentation: .named)))" } ?? "On. Your jungle backs up automatically."
        case .noAccount: "Sign in to iCloud in the Settings app to back up."
        case .off: pendingRestart ? "Off after you reopen the app." : "Off. Your jungle stays on this iPhone."
        case .unavailable: pendingRestart ? "On after you reopen the app." : "Sign in to iCloud on this iPhone to keep your jungle safe."
        }
    }
}
