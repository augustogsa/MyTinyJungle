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
                NativeAdCardView(ad: ad).frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
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
        let media = MediaView(); media.contentMode = .scaleAspectFill; media.clipsToBounds = true
        let icon = UIImageView(); icon.layer.cornerRadius = 10; icon.clipsToBounds = true; icon.contentMode = .scaleAspectFill
        let badge = UILabel(); badge.text = " Ad "; badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(Jungle.warmText); badge.backgroundColor = UIColor(Jungle.peach).withAlphaComponent(0.5)
        badge.layer.cornerRadius = 4; badge.clipsToBounds = true
        let headline = UILabel(); headline.font = Self.rounded(.headline); headline.textColor = UIColor(Jungle.text); headline.numberOfLines = 1
        let body = UILabel(); body.font = .preferredFont(forTextStyle: .subheadline); body.textColor = UIColor(Jungle.subtle); body.numberOfLines = 2
        var cfg = UIButton.Configuration.filled(); cfg.cornerStyle = .capsule; cfg.baseBackgroundColor = UIColor(Jungle.forest)
        let cta = UIButton(configuration: cfg); cta.isUserInteractionEnabled = false
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for s in [media, icon, badge, headline, body, cta] as [UIView] { s.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(s) }
        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: v.topAnchor), media.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: v.trailingAnchor), media.heightAnchor.constraint(equalToConstant: 160),
            icon.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 12), icon.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 40), icon.heightAnchor.constraint(equalToConstant: 40),
            badge.centerYAnchor.constraint(equalTo: headline.centerYAnchor), badge.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            headline.topAnchor.constraint(equalTo: icon.topAnchor), headline.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 6),
            headline.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 2), body.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            body.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            cta.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14), cta.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            cta.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),
        ])
        v.mediaView = media; v.iconView = icon; v.headlineView = headline; v.bodyView = body; v.callToActionView = cta
        return v
    }
    func updateUIView(_ v: NativeAdView, context: Context) {
        (v.headlineView as? UILabel)?.text = ad.headline
        (v.bodyView as? UILabel)?.text = ad.body
        (v.iconView as? UIImageView)?.image = ad.icon?.image
        v.iconView?.isHidden = ad.icon == nil
        (v.callToActionView as? UIButton)?.configuration?.title = ad.callToAction ?? "Learn more"
        v.mediaView?.mediaContent = ad.mediaContent
        v.nativeAd = ad
    }
    static func rounded(_ s: UIFont.TextStyle) -> UIFont {
        let b = UIFont.preferredFont(forTextStyle: s)
        return UIFont(descriptor: b.fontDescriptor.withDesign(.rounded)?.withSymbolicTraits(.traitBold) ?? b.fontDescriptor, size: 0)
    }
}

/// Adaptive banner for the bottom of long read-only pages.
struct BottomBannerAd: View {
    private var ads: AdsManager { .shared }
    var body: some View {
        GeometryReader { geo in
            if ads.shouldShowAds, ads.ready {
                BannerRepresentable(width: geo.size.width).frame(height: 60)
            } else { Color.clear }
        }
        .frame(height: ads.shouldShowAds && ads.ready ? 60 : 0)
        .onAppear { ads.prepare() }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    func makeUIView(context: Context) -> BannerView {
        let b = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)))
        b.adUnitID = AdsConfig.bannerUnit
        b.rootViewController = AdsManager.rootController()
        b.load(AdsManager.shared.request())
        return b
    }
    func updateUIView(_ uiView: BannerView, context: Context) {}
}
