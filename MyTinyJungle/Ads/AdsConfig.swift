import Foundation

/// The one place for AdMob IDs. The app ID lives in the GAD_APP_ID build setting (Info.plist).
/// One native unit per placement (AdMob app "My Tiny Jungle", iOS) so each placement reports and caps on its own.
/// Debug builds and `-demoAds` always use Google's test unit; never tap live ads while testing.
enum AdsConfig {
    static let testNative = "ca-app-pub-3940256099942544/3986624511"
    static let releaseUnits: [String: String] = [
        "today": "ca-app-pub-5572285766965735/5025106592",
        "plants-grid": "ca-app-pub-5572285766965735/8479593881",
        "plants-row": "ca-app-pub-5572285766965735/6449548105",
        "plant-page": "ca-app-pub-5572285766965735/5853430547",
        "guides": "ca-app-pub-5572285766965735/5136466430",
        "care-agenda": "ca-app-pub-5572285766965735/9900486760",
        "season": "ca-app-pub-5572285766965735/2071319399",
        "scan": "ca-app-pub-5572285766965735/7459698245",
    ]

    /// Placement for a view slot: "plant-<id>" → plant-page, "agenda" → care-agenda.
    static func placement(for slot: String) -> String {
        if slot.hasPrefix("plant-") && slot != "plants-grid" && slot != "plants-row" { return "plant-page" }
        if slot == "agenda" { return "care-agenda" }
        return releaseUnits[slot] != nil ? slot : "today"
    }

    static var useTestUnits: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-demoAds")
        #endif
    }

    static func nativeUnit(for placement: String) -> String {
        useTestUnits ? testNative : (releaseUnits[placement] ?? releaseUnits["today"]!)
    }

    /// Collection grid: first ad after this many rows, then every `gridEvery` rows.
    static let gridFirstRow = 2
    static let gridEvery = 6
    /// Ads off for UI tests and website demo screenshots.
    static var disabledByLaunch: Bool {
        let a = ProcessInfo.processInfo.arguments
        if a.contains("-demoAds") { return false }
        return a.contains("-uiTesting") || a.contains("-noAds") || a.contains("-demoPhotos")
    }
}

/// Where ads may go: always between content, never first.
enum AdSlots {
    /// Splits a grid of `count` items into row ranges, breaking after row 4 then every 8 rows.
    static func chunks(_ count: Int, perRow: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        var out: [Range<Int>] = []; var start = 0; var rows = AdsConfig.gridFirstRow
        while start < count {
            let end = min(count, start + rows * perRow)
            out.append(start..<end); start = end; rows = AdsConfig.gridEvery
        }
        return out
    }
    /// Care agenda: an ad before the 3rd day group, then every 5 days.
    static func agendaAd(before index: Int) -> Bool { index >= 2 && (index - 2) % 5 == 0 }
}
