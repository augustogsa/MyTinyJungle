import Foundation
import MetricKit
import UIKit

/// Crash and hang reports from MetricKit, sent to our own API (POST /v1/diagnostics) with no user link
/// and no third-party SDK. MetricKit delivers them at most once a day; unsent ones wait on disk.
final class Diagnostics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = Diagnostics()
    private let queue = DispatchQueue(label: "diagnostics")
    private var pendingURL: URL { URL.applicationSupportDirectory.appending(path: "diagnostics-pending.json") }

    func start() {
        MXMetricManager.shared.add(self)
        Task { await flush() }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var reports: [[String: Any]] = []
        for p in payloads {
            func add(_ kind: String, _ items: [MXDiagnostic]?) {
                for d in items ?? [] {
                    if let o = try? JSONSerialization.jsonObject(with: d.jsonRepresentation()) as? [String: Any] { reports.append(["kind": kind, "payload": o]) }
                }
            }
            add("crash", p.crashDiagnostics)
            add("hang", p.hangDiagnostics)
            add("cpu", p.cpuExceptionDiagnostics)
            add("disk", p.diskWriteExceptionDiagnostics)
            add("launch", p.appLaunchDiagnostics)
        }
        guard !reports.isEmpty else { return }
        queue.sync {
            var all = (try? Data(contentsOf: pendingURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
            all = Array((all + reports).suffix(40))
            if let d = try? JSONSerialization.data(withJSONObject: all) { try? d.write(to: pendingURL, options: .atomic) }
        }
        Task { await flush() }
    }

    func flush() async {
        guard JungleAPI.shared.hasSession else { return }
        let all: [[String: Any]] = queue.sync { (try? Data(contentsOf: pendingURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? [] }
        guard !all.isEmpty else { return }
        let os = await UIDevice.current.systemVersion
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        for chunk in stride(from: 0, to: all.count, by: 20).map({ Array(all[$0..<min($0 + 20, all.count)]) }) {
            let body: [String: Any] = ["platform": "ios", "appVersion": version, "osVersion": os, "reports": chunk]
            guard let data = try? JSONSerialization.data(withJSONObject: body),
                  (try? await JungleAPI.shared.postRaw("/v1/diagnostics", data)) != nil else { return }
        }
        queue.sync { try? FileManager.default.removeItem(at: pendingURL) }
    }
}
