import SwiftUI
import GoogleMobileAds

struct AdaptiveBannerView: View {
    @EnvironmentObject private var adManager: AdManager

    var body: some View {
        if !IAPManager.shared.isProUser, !adManager.adsRemoved, adManager.isInitialized {
            AdaptiveBannerRepresentable(adUnitID: AdConfig.bannerAdUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width))
        banner.adUnitID = adUnitID
        banner.rootViewController = AdRootViewController.current()
        banner.load(Request())
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
