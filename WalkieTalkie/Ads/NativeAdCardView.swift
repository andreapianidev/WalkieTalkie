//  NativeAdCardView.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

import SwiftUI
import GoogleMobileAds

/// SwiftUI card that renders a Google AdMob Native Advanced ad
/// styled to match the StationBrowserSheet rows.
struct NativeAdCardView: View {
    let nativeAd: NativeAd

    var body: some View {
        NativeAdRepresentable(nativeAd: nativeAd)
            .frame(minHeight: 96)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = UIColor(named: "SurfaceColor") ?? .secondarySystemBackground
        adView.layer.cornerRadius = 14
        adView.layer.masksToBounds = true
        Self.installLayout(into: adView)
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        // Idempotency guard: avoid re-binding the same NativeAd on every SwiftUI invalidation
        // (re-binding re-arms impression bookkeeping inside the SDK).
        if adView.nativeAd !== nativeAd {
            adView.nativeAd = nativeAd
        }

        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.bodyView as? UILabel)?.isHidden = (nativeAd.body ?? "").isEmpty
        (adView.callToActionView as? UILabel)?.text = nativeAd.callToAction
        (adView.callToActionView as? UILabel)?.isHidden = (nativeAd.callToAction ?? "").isEmpty

        if let iconImageView = adView.iconView as? UIImageView {
            iconImageView.image = nativeAd.icon?.image
            iconImageView.isHidden = nativeAd.icon?.image == nil
        }

        if let advertiserLabel = adView.advertiserView as? UILabel {
            advertiserLabel.text = nativeAd.advertiser
            advertiserLabel.isHidden = (nativeAd.advertiser ?? "").isEmpty
        }
    }

    /// Builds the persistent UIKit layout (executed once in makeUIView).
    private static func installLayout(into adView: NativeAdView) {
        // Ad badge (required by AdMob policy — use canonical "Ad" wording)
        let adBadge = UILabel()
        adBadge.text = " Ad "
        adBadge.font = .systemFont(ofSize: 10, weight: .bold)
        adBadge.textColor = .black
        adBadge.backgroundColor = .systemYellow
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 4
        adBadge.clipsToBounds = true
        adBadge.setContentHuggingPriority(.required, for: .horizontal)

        // Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.iconView = iconView

        // Headline
        let headline = UILabel()
        headline.font = .systemFont(ofSize: 17, weight: .semibold)
        headline.textColor = UIColor(named: "PrimaryTextColor") ?? .label
        headline.numberOfLines = 2
        adView.headlineView = headline

        // Advertiser line
        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 12)
        advertiser.textColor = .secondaryLabel
        advertiser.numberOfLines = 1
        adView.advertiserView = advertiser

        // Body
        let body = UILabel()
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabel
        body.numberOfLines = 2
        adView.bodyView = body

        // CTA as a pill label (SDK handles taps via NativeAdView)
        let cta = UILabel()
        cta.font = .systemFont(ofSize: 13, weight: .semibold)
        cta.textColor = .black
        cta.backgroundColor = .systemYellow
        cta.textAlignment = .center
        cta.layer.cornerRadius = 12
        cta.clipsToBounds = true
        cta.setContentHuggingPriority(.required, for: .horizontal)
        adView.callToActionView = cta

        // Header line: AD badge + advertiser + spacer
        let headerStack = UIStackView(arrangedSubviews: [adBadge, advertiser])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 6

        // Text column (header + headline + body)
        let textStack = UIStackView(arrangedSubviews: [headerStack, headline, body])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading

        // Row: icon + text column + CTA — top-aligned so 1-line and 2-line headlines look balanced on SE.
        let row = UIStackView(arrangedSubviews: [iconView, textStack, cta])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            adBadge.heightAnchor.constraint(equalToConstant: 14),
            adBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
            cta.heightAnchor.constraint(equalToConstant: 30),
            cta.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            row.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
        ])

        // Side padding for the CTA label text
        cta.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }
}
