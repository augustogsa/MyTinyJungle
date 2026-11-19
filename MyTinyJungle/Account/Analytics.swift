import Foundation
import UIKit

/// Privacy-first analytics: counts of named events per day, sent as {name: count} with platform and app
/// version only. No user, device or session identifier ever leaves the phone.
nonisolated enum Analytics {
    private static let key = "analytics.pending"
    private static let lock = NSLock()

    static func track(_ name: String) {
        lock.withLock {
            var c = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
            c[name, default: 0] += 1
            UserDefaults.standard.set(c, forKey: key)
        }
    }

    /// Sends what's pending (at launch and when going to background).
    static func flush() async {
        let counts: [String: Int] = lock.withLock {
            let c = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
            UserDefaults.standard.removeObject(forKey: key)
            return c
        }
        guard !counts.isEmpty else { return }
        var req = URLRequest(url: JungleAPI.base.appending(path: "/v1/events"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["platform": "ios", "appVersion": version, "counts": counts])
        guard let (_, res) = try? await URLSession.shared.data(for: req), (res as? HTTPURLResponse)?.statusCode == 200 else {
            lock.withLock {   // keep for next time
                var c = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
                c.merge(counts, uniquingKeysWith: +)
                UserDefaults.standard.set(c, forKey: key)
            }
            return
        }
    }
}
