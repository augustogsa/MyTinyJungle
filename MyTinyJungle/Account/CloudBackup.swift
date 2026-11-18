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
        case .checking: String(localized: "Checking iCloud…", comment: "Backup status in Settings; max 30 chars")
        case .on: syncing ? String(localized: "Backing up…", comment: "Backup status; max 30 chars") : lastSync.map { String(localized: "Last backup \($0.formatted(.relative(presentation: .named)))", comment: "Backup status; %@ relative date like 'yesterday' or '5 minutes ago'") } ?? String(localized: "On. Your jungle backs up automatically.", comment: "Backup status, on")
        case .noAccount: String(localized: "Sign in to iCloud in the Settings app to back up.", comment: "Backup status, no iCloud account")
        case .off: pendingRestart ? String(localized: "Off after you reopen the app.", comment: "Backup status after turning off") : String(localized: "Off. Your jungle stays on this iPhone.", comment: "Backup status, off")
        case .unavailable: pendingRestart ? String(localized: "On after you reopen the app.", comment: "Backup status after turning on") : String(localized: "Sign in to iCloud on this iPhone to keep your jungle safe.", comment: "Backup status, iCloud unavailable")
        }
    }
}
