import Foundation
import CloudKit
import UIKit

/// CloudKit plumbing for the shared jungle. The owner keeps one record in a custom zone of their
/// private database and shares the whole zone (CKShare); members read and write it through their
/// shared database. Apple handles identity, invitations and access, so no account server is needed.
enum HouseholdCloud {
    static let container = CKContainer(identifier: CloudBackup.containerID)
    static let zoneName = "SharedJungle"
    static let recordType = "Household"
    static let recordName = "house"

    /// Where the household lives, remembered after create or join.
    struct Location: Codable, Equatable { var zoneOwner: String; var shared: Bool }

    static func zoneID(_ loc: Location) -> CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName, ownerName: loc.zoneOwner) }
    static func db(_ loc: Location) -> CKDatabase { loc.shared ? container.sharedCloudDatabase : container.privateCloudDatabase }

    static func available() async -> Bool { (try? await container.accountStatus()) == .available }
    static func myID() async -> String? { try? await container.userRecordID().recordName }

    /// Creates the zone and record (owner only) and returns the zone-wide share.
    static func createShare(state: HouseState, title: String) async throws -> CKShare {
        let zone = CKRecordZone(zoneName: zoneName)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
        let loc = Location(zoneOwner: CKCurrentUserDefaultName, shared: false)
        try await save(state, at: loc)
        if let existing = try? await container.privateCloudDatabase.record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)) as? CKShare {
            return existing
        }
        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        share[CKShare.SystemFieldKey.thumbnailImageData] = UIImage(named: "AppMark")?.pngData() as CKRecordValue?
        share.publicPermission = .readWrite   // anyone with the link can join; owner can remove later
        _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        return share
    }

    static func fetch(at loc: Location) async throws -> HouseState? {
        let id = CKRecord.ID(recordName: recordName, zoneID: zoneID(loc))
        guard let rec = try? await db(loc).record(for: id), let data = rec["state"] as? Data else { return nil }
        return try? JSONDecoder().decode(HouseState.self, from: data)
    }

    /// Read-merge-write so two phones saving at once never lose each other's changes.
    @discardableResult
    static func save(_ state: HouseState, at loc: Location) async throws -> HouseState {
        let id = CKRecord.ID(recordName: recordName, zoneID: zoneID(loc))
        var merged = state
        for _ in 0..<3 {
            let rec = (try? await db(loc).record(for: id)) ?? CKRecord(recordType: recordType, recordID: id)
            if let data = rec["state"] as? Data, let remote = try? JSONDecoder().decode(HouseState.self, from: data) { merged.merge(remote) }
            rec["state"] = try JSONEncoder().encode(merged) as CKRecordValue
            do {
                _ = try await db(loc).modifyRecords(saving: [rec], deleting: [], savePolicy: .ifServerRecordUnchanged)
                return merged
            } catch let e as CKError where e.code == .serverRecordChanged { continue }
        }
        return merged
    }

    static func accept(_ metadata: CKShare.Metadata) async throws -> Location {
        _ = try await container.accept(metadata)
        return Location(zoneOwner: metadata.share.recordID.zoneID.ownerName, shared: true)
    }

    static func share(at loc: Location) async -> CKShare? {
        try? await db(loc).record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID(loc))) as? CKShare
    }

    /// Owner removes someone: drop them from the share so their access ends.
    static func removeParticipant(_ userID: String, at loc: Location) async {
        guard !loc.shared, let share = await share(at: loc),
              let p = share.participants.first(where: { $0.userIdentity.userRecordID?.recordName == userID }) else { return }
        share.removeParticipant(p)
        _ = try? await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
    }

    /// Member leaves: delete the shared zone from their side. Owner ends it: delete the zone.
    static func leave(at loc: Location) async {
        if loc.shared {
            if let share = await share(at: loc) { _ = try? await container.sharedCloudDatabase.modifyRecords(saving: [], deleting: [share.recordID]) }
            _ = try? await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID(loc)])
        } else {
            _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID(loc)])
        }
    }

    /// Silent pushes when anyone changes the jungle, so "Ana just watered Goldie" arrives quickly.
    static func subscribe(_ loc: Location) async {
        let sub = CKDatabaseSubscription(subscriptionID: "shared-jungle-\(loc.shared ? "in" : "own")")
        let info = CKSubscription.NotificationInfo(); info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        _ = try? await db(loc).modifySubscriptions(saving: [sub], deleting: [])
    }
}
