import SwiftUI
import GoogleMobileAds

struct AdaptiveBannerView: View {
    @EnvironmentObject private var adManager: AdManager

    var body: some View {
        if AdConfig.isBannerConfigured, !IAPManager.shared.isProUser, !adManager.adsRemoved, adManager.isInitialized {
            // La larghezza e' quella del contenitore, non dello schermo: sul Duo
            // cambia aprendo e chiudendo, su iPad la colonna e' piu' stretta.
            // Cambiata la larghezza, il banner si ricrea con la misura giusta.
            GeometryReader { proxy in
                if proxy.size.width > 0 {
                    AdaptiveBannerRepresentable(adUnitID: AdConfig.bannerAdUnitID, width: proxy.size.width)
                        .id(Int(proxy.size.width))
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = AdRootViewController.current()
        banner.load(Request())
        banner.translatesAutoresizingMaskIntoConstraints = false
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
