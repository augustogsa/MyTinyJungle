import SwiftUI
import UIKit
import GoogleMobileAds

enum AdStyle { case card, row, tile }

/// Keeps a few native ads ready so slots appear filled or not at all (never an empty gap).
@MainActor @Observable
final class AdPool {
    static let shared = AdPool()
    /// Ready ads per placement (each placement has its own AdMob unit).
    private(set) var ads: [String: [NativeAd]] = [:]
    private var bySlot: [String: Int] = [:]
    private var fetchers: [String: [NativeAdFetcher]] = [:]
    private var started = false
    /// Grid tiles can repeat on screen, so that placement keeps two.
    private func target(_ placement: String) -> Int { placement == "plants-grid" ? 2 : 1 }

    func start() {
        let m = AdsManager.shared
        guard m.shouldShowAds else { return }
        m.prepare()
        guard m.ready, !started else { return }
        started = true
        for p in ["today", "plants-grid"] { fill(p) }
    }

    private func fill(_ placement: String) {
        guard started, AdsManager.shared.shouldShowAds else { return }
        let have = fetchers[placement, default: []].count
        guard have < target(placement) else { return }
        for _ in have..<target(placement) {
            let f = NativeAdFetcher(); fetchers[placement, default: []].append(f)
            f.load(unit: AdsConfig.nativeUnit(for: placement)) { [weak self] ad in self?.ads[placement, default: []].append(ad) }
        }
    }

    func ad(for slot: String) -> NativeAd? {
        guard AdsManager.shared.shouldShowAds else { return nil }
        let placement = AdsConfig.placement(for: slot)
        let list = ads[placement] ?? []
        guard !list.isEmpty else { Task { @MainActor in self.fill(placement) }; return nil }
        if let i = bySlot[slot] { return list[i % list.count] }
        let i = bySlot.count % list.count
        bySlot[slot] = i
        return list[i]
    }
}

/// Native ad dressed as a My Tiny Jungle card, row or grid tile, always marked "Sponsored".
/// Renders nothing (no gap) for Plus, before consent, or until an ad is ready.
struct NativeAdCard: View {
    var slot: String = "default"
    var style: AdStyle = .card
    private var pool: AdPool { .shared }

    var body: some View {
        Group {
            if RemoteConfig.flag("ads"), let ad = pool.ad(for: slot) {
                switch style {
                case .card:
                    NativeAdCardView(ad: ad, style: .card).frame(height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                case .row:
                    NativeAdCardView(ad: ad, style: .row).frame(height: 76)
                case .tile:
                    NativeAdCardView(ad: ad, style: .tile).frame(minHeight: 218, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                }
            }
        }
        .accessibilityLabel(Grammar.pt(String(localized: "Sponsored", comment: "Ad badge label; pt-BR Patrocinado")))
    }
}

@MainActor
final class NativeAdFetcher: NSObject, NativeAdLoaderDelegate {
    private var loader: AdLoader?
    private var done: ((NativeAd) -> Void)?
    func load(unit: String, _ done: @escaping (NativeAd) -> Void) {
        guard loader == nil else { return }
        self.done = done
        let l = AdLoader(adUnitID: unit, rootViewController: AdsManager.rootController(), adTypes: [.native], options: nil)
        l.delegate = self
        loader = l
        l.load(AdsManager.shared.request())
    }
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) { MainActor.assumeIsolated { done?(nativeAd) } }
    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {}
}

private struct NativeAdCardView: UIViewRepresentable {
    let ad: NativeAd
    var style: AdStyle = .card
    func makeUIView(context: Context) -> NativeAdView {
        style == .tile ? makeTile() : makeRow()
    }
    /// Grid tile: whole media (fit, never cropped), then the "Sponsored" badge on its own line, a two-line headline and the button.
    private func makeTile() -> NativeAdView {
        let v = NativeAdView()
        v.backgroundColor = UIColor(Jungle.surface)
        let media = MediaView(); media.contentMode = .scaleAspectFit; media.clipsToBounds = true; media.backgroundColor = UIColor(Jungle.mist)
        let badge = Self.badge()
        badge.backgroundColor = UIColor(Jungle.mint)
        let headline = UILabel(); headline.font = Self.rounded(.subheadline); headline.textColor = UIColor(Jungle.text); headline.numberOfLines = 2
        headline.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        var cfg = UIButton.Configuration.tinted(); cfg.cornerStyle = .capsule; cfg.baseForegroundColor = UIColor(Jungle.accentText); cfg.baseBackgroundColor = UIColor(Jungle.forest); cfg.buttonSize = .mini
        let cta = UIButton(configuration: cfg); cta.isUserInteractionEnabled = false
        cta.setContentCompressionResistancePriority(.required, for: .vertical)
        for s in [media, badge, headline, cta] as [UIView] { s.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(s) }
        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: v.topAnchor), media.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: v.trailingAnchor), media.heightAnchor.constraint(equalToConstant: 104),
            badge.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 10), badge.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            badge.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -12),
            headline.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),
            headline.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12), headline.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            headline.bottomAnchor.constraint(lessThanOrEqualTo: cta.topAnchor, constant: -6),
            cta.leadingAnchor.constraint(equalTo: headline.leadingAnchor), cta.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -12),
            cta.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),
        ])
        v.mediaView = media; v.headlineView = headline; v.callToActionView = cta
        return v
    }
    private static func badge() -> UILabel {
        let b = UILabel(); b.text = "  \(Grammar.pt(String(localized: "Sponsored", comment: "Ad badge label; pt-BR Patrocinado")))  "; b.font = .systemFont(ofSize: 11, weight: .semibold)
        b.textColor = UIColor(Jungle.text); b.backgroundColor = UIColor(Jungle.surface).withAlphaComponent(0.92)
        b.layer.cornerRadius = 9; b.clipsToBounds = true
        b.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return b
    }
    private func makeRow() -> NativeAdView {
        let v = NativeAdView()
        v.backgroundColor = style == .row ? .clear : UIColor(Jungle.surface)
        let icon = UIImageView(); icon.layer.cornerRadius = 12; icon.layer.cornerCurve = .continuous; icon.clipsToBounds = true; icon.contentMode = .scaleAspectFill
        let badge = UILabel(); badge.text = " \(Grammar.pt(String(localized: "Sponsored", comment: "Ad badge label; pt-BR Patrocinado"))) "; badge.font = .systemFont(ofSize: 10, weight: .semibold)
        badge.textColor = UIColor(Jungle.subtle); badge.backgroundColor = UIColor(Jungle.subtle).withAlphaComponent(0.12)
        badge.layer.cornerRadius = 4; badge.clipsToBounds = true
        let headline = UILabel(); headline.font = Self.rounded(.subheadline); headline.textColor = UIColor(Jungle.text); headline.numberOfLines = 1
        let body = UILabel(); body.font = .preferredFont(forTextStyle: .caption1); body.textColor = UIColor(Jungle.subtle); body.numberOfLines = 1
        var cfg = UIButton.Configuration.tinted(); cfg.cornerStyle = .capsule; cfg.baseForegroundColor = UIColor(Jungle.accentText); cfg.baseBackgroundColor = UIColor(Jungle.forest)
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
        v.mediaView?.mediaContent = ad.mediaContent
        v.mediaView?.contentMode = .scaleAspectFit
        (v.callToActionView as? UIButton)?.configuration?.title = ad.callToAction ?? Grammar.pt(String(localized: "Open", comment: "Ad call-to-action fallback button"))
        v.nativeAd = ad
    }
    static func rounded(_ s: UIFont.TextStyle) -> UIFont {
        let b = UIFont.preferredFont(forTextStyle: s)
        return UIFont(descriptor: b.fontDescriptor.withDesign(.rounded)?.withSymbolicTraits(.traitBold) ?? b.fontDescriptor, size: 0)
    }
}

/// Bottom-of-page ad: the same compact native row, so it reads like part of the page.
struct BottomBannerAd: View {
    var slot = "bottom"
    var body: some View { NativeAdCard(slot: slot).padding(.horizontal, 16).padding(.vertical, 6) }
}
