import SwiftUI
import UIKit
import GoogleMobileAds

/// Native ad as a Tiny Jungle card, with an "Ad" label. Renders nothing for Plus, before consent, or on load failure.
struct NativeAdCard: View {
    @State private var ad: NativeAd?
    @State private var loader = NativeAdFetcher()
    private var ads: AdsManager { .shared }

    var body: some View {
        Group {
            if ads.shouldShowAds, let ad {
                NativeAdCardView(ad: ad).frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
                    .accessibilityLabel("Advertisement")
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .onAppear { ads.prepare(); load() }
        .onChange(of: ads.ready) { _, _ in load() }
    }

    private func load() {
        guard ads.shouldShowAds, ads.ready, ad == nil else { return }
        loader.load { ad = $0 }
    }
}

@MainActor
final class NativeAdFetcher: NSObject, NativeAdLoaderDelegate {
    private var loader: AdLoader?
    private var done: ((NativeAd) -> Void)?
    func load(_ done: @escaping (NativeAd) -> Void) {
        guard loader == nil else { return }
        self.done = done
        let l = AdLoader(adUnitID: AdsConfig.nativeUnit, rootViewController: AdsManager.rootController(), adTypes: [.native], options: nil)
        l.delegate = self
        loader = l
        l.load(AdsManager.shared.request())
    }
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) { MainActor.assumeIsolated { done?(nativeAd) } }
    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {}
}

private struct NativeAdCardView: UIViewRepresentable {
    let ad: NativeAd
    func makeUIView(context: Context) -> NativeAdView {
        let v = NativeAdView()
        v.backgroundColor = UIColor(Jungle.surface)
        let icon = UIImageView(); icon.layer.cornerRadius = 12; icon.layer.cornerCurve = .continuous; icon.clipsToBounds = true; icon.contentMode = .scaleAspectFill
        let badge = UILabel(); badge.text = " Sponsored "; badge.font = .systemFont(ofSize: 10, weight: .semibold)
        badge.textColor = UIColor(Jungle.subtle); badge.backgroundColor = UIColor(Jungle.subtle).withAlphaComponent(0.12)
        badge.layer.cornerRadius = 4; badge.clipsToBounds = true
        let headline = UILabel(); headline.font = Self.rounded(.subheadline); headline.textColor = UIColor(Jungle.text); headline.numberOfLines = 1
        let body = UILabel(); body.font = .preferredFont(forTextStyle: .caption1); body.textColor = UIColor(Jungle.subtle); body.numberOfLines = 1
        var cfg = UIButton.Configuration.tinted(); cfg.cornerStyle = .capsule; cfg.baseForegroundColor = UIColor(Jungle.forest); cfg.baseBackgroundColor = UIColor(Jungle.forest)
        cfg.buttonSize = .small
        let cta = UIButton(configuration: cfg); cta.isUserInteractionEnabled = false
        for l in [badge, cta] as [UIView] { l.setContentHuggingPriority(.required, for: .horizontal); l.setContentCompressionResistancePriority(.required, for: .horizontal) }
        headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for s in [icon, badge, headline, body, cta] as [UIView] { s.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(s) }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12), icon.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48), icon.heightAnchor.constraint(equalToConstant: 48),
            headline.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12), headline.bottomAnchor.constraint(equalTo: v.centerYAnchor, constant: -1),
            headline.trailingAnchor.constraint(lessThanOrEqualTo: cta.leadingAnchor, constant: -10),
            badge.leadingAnchor.constraint(equalTo: headline.leadingAnchor), badge.topAnchor.constraint(equalTo: v.centerYAnchor, constant: 3),
            body.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 6), body.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            body.trailingAnchor.constraint(lessThanOrEqualTo: cta.leadingAnchor, constant: -10),
            cta.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12), cta.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        v.iconView = icon; v.headlineView = headline; v.bodyView = body; v.callToActionView = cta
        return v
    }
    func updateUIView(_ v: NativeAdView, context: Context) {
        (v.headlineView as? UILabel)?.text = ad.headline
        (v.bodyView as? UILabel)?.text = ad.body
        (v.iconView as? UIImageView)?.image = ad.icon?.image
        v.iconView?.isHidden = ad.icon == nil
        (v.callToActionView as? UIButton)?.configuration?.title = ad.callToAction ?? "Open"
        v.nativeAd = ad
    }
    static func rounded(_ s: UIFont.TextStyle) -> UIFont {
        let b = UIFont.preferredFont(forTextStyle: s)
        return UIFont(descriptor: b.fontDescriptor.withDesign(.rounded)?.withSymbolicTraits(.traitBold) ?? b.fontDescriptor, size: 0)
    }
}

/// Bottom-of-page ad: the same compact native row, so it reads like part of the page.
struct BottomBannerAd: View {
    var body: some View { NativeAdCard().padding(.horizontal, 16).padding(.vertical, 6) }
}
