import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Consent (UMP, then ATT) and SDK start, lazily on the first screen that shows an ad.
/// Never for Plus subscribers: no SDK request at all.
@Observable
final class AdsManager {
    static let shared = AdsManager()
    private(set) var ready = false
    private(set) var privacyOptionsRequired = false
    private var preparing = false

    /// Ads show only for free users, after onboarding, when the SDK may request ads.
    var shouldShowAds: Bool { !Store.shared.isPlus && !AdsConfig.disabledByLaunch }

    func prepare() {
        guard shouldShowAds, !ready, !preparing else { return }
        preparing = true
        let params = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let root = Self.rootController() {
                    try? await ConsentForm.loadAndPresentIfRequired(from: root)
                }
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                }
                guard ConsentInformation.shared.canRequestAds, !Store.shared.isPlus else { self.preparing = false; return }
                await MobileAds.shared.start()
                self.ready = true
                self.preparing = false
            }
        }
    }

    /// Settings: reopen the consent choices.
    func presentPrivacyOptions() {
        guard let root = Self.rootController() else { return }
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: root) }
    }

    /// Non-personalised unless the person allowed tracking.
    func request() -> Request {
        let r = Request()
        if ATTrackingManager.trackingAuthorizationStatus != .authorized {
            let extras = Extras(); extras.additionalParameters = ["npa": "1"]; r.register(extras)
        }
        return r
    }

    static func rootController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.keyWindow?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}
