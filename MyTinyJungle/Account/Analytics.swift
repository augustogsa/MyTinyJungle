import Foundation
import UIKit
import SwiftUI
import StoreKit
import FirebaseCore
import FirebaseAnalytics

/// App analytics. Each event goes two ways: a daily {name: count} tally to our own server (no identifiers),
/// and Google Analytics for Firebase (anonymous app-instance ID; no ad ID, no ad personalisation, no names,
/// emails or photos). Screens are reported with `.screen("name")`.
nonisolated enum Analytics {
    /// Called once at launch, before any event.
    static func start() {
        guard FirebaseApp.app() == nil, Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        FirebaseAnalytics.Analytics.setConsent([.analyticsStorage: .granted, .adStorage: .denied, .adUserData: .denied, .adPersonalization: .denied])
        FirebaseAnalytics.Analytics.setAnalyticsCollectionEnabled(true)
        FirebaseAnalytics.Analytics.setUserProperty(Locale.current.language.languageCode?.identifier, forName: "app_language")
    }

    /// Google Analytics only, with parameters (screen views, purchases, choices).
    static func log(_ name: String, _ params: [String: Any] = [:]) {
        guard FirebaseApp.app() != nil else { return }
        FirebaseAnalytics.Analytics.logEvent(name, parameters: params.isEmpty ? nil : params)
    }

    /// StoreKit 2 purchases and renewals (Firebase only sees StoreKit 1 on its own).
    static func purchase(_ t: StoreKit.Transaction) { guard FirebaseApp.app() != nil else { return }; FirebaseAnalytics.Analytics.logTransaction(t) }

    static func screen(_ name: String) { log(AnalyticsEventScreenView, [AnalyticsParameterScreenName: name, AnalyticsParameterScreenClass: name]) }

    private static let key = "analytics.pending"
    private static let lock = NSLock()

    static func track(_ name: String, _ params: [String: Any] = [:]) {
        log(name, params)
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

extension View {
    /// Reports this view as a screen to Google Analytics each time it appears.
    func screen(_ name: String) -> some View { onAppear { Analytics.screen(name) } }
}
