import Foundation

/// The one place for AdMob IDs. The app ID lives in the GAD_APP_ID build setting (Info.plist).
/// Real IDs: replace `release*` once the AdMob account is verified. Until then Release serves Google's test ads.
enum AdsConfig {
    static let testNative = "ca-app-pub-3940256099942544/3986624511"
    static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    static let releaseNative = testNative
    static let releaseBanner = testBanner

    #if DEBUG
    static let nativeUnit = testNative
    static let bannerUnit = testBanner
    #else
    static let nativeUnit = releaseNative
    static let bannerUnit = releaseBanner
    #endif

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
