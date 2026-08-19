//  AdConfig.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani

import Foundation

enum AdConfig {

    #if DEBUG
    // Google test ad units - safe to use during development.
    static let appOpenAdUnitID      = "ca-app-pub-3940256099942544/5575463023"
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedAdUnitID     = "ca-app-pub-3940256099942544/1712485313"
        static let nativeStationAdUnitID = "ca-app-pub-3940256099942544/3986624511"
        static let bannerAdUnitID        = "ca-app-pub-3940256099942544/2934735716"
    #else
    // Talky production ad units (account ca-app-pub-1193280742171051).
    static let appOpenAdUnitID      = "ca-app-pub-1193280742171051/4903244407"
    static let interstitialAdUnitID = "ca-app-pub-1193280742171051/1317702703"
    static let rewardedAdUnitID     = "ca-app-pub-1193280742171051/3696454034"
    static let nativeStationAdUnitID = "ca-app-pub-1193280742171051/4859462082"
    /// Ad unit `bannertalky`, creata il 19/08/26 e verificata via API AdMob:
    /// adFormat BANNER sull'app `ca-app-pub-1193280742171051~5179465988`.
    ///
    /// Fino a quel giorno qui c'era `.../3958227741`, un ID scritto a mano che
    /// su AdMob non è mai esistito. Le due schermate che montano
    /// `AdaptiveBannerView` (Explore e Connections) chiedevano quindi un
    /// annuncio che veniva rifiutato ogni volta, e le richieste con ad unit ID
    /// invalido non compaiono in nessun report: il buco è rimasto invisibile
    /// per mesi. In DEBUG si usa l'ID di test di Google, che funziona
    /// benissimo, quindi non si vedeva nemmeno provando l'app.
    ///
    /// Se un giorno serve di nuovo un segnaposto, va aggiunto a
    /// `unconfiguredAdUnitIDs` così `isBannerConfigured` lo spegne invece di
    /// bruciare richieste.
    static let bannerAdUnitID        = "ca-app-pub-1193280742171051/9000188893"

    /// Segnaposto noti: ID scritti a mano che non esistono lato AdMob.
    private static let unconfiguredAdUnitIDs: Set<String> = [
        "ca-app-pub-1193280742171051/3958227741"
    ]
    #endif

    /// False finché `bannerAdUnitID` è un segnaposto. Chiedere un banner con un
    /// ID inesistente non è gratis: è una richiesta di rete a ogni comparsa
    /// della view che non potrà mai riempirsi.
    static var isBannerConfigured: Bool {
        #if DEBUG
        return true
        #else
        return !unconfiguredAdUnitIDs.contains(bannerAdUnitID)
        #endif
    }

    enum FrequencyCap {
        static let appOpenMaxAge: TimeInterval = 4 * 3600
        static let appOpenResumeDelay: TimeInterval = 1.2
        /// Minimo tra due app-open: l'app vive di background/foreground continui
        /// (walkie in uso), senza cooldown l'annuncio partiva a OGNI rientro
        /// ("penetrantester Werbung" — recensioni 1★).
        static let appOpenMinInterval: TimeInterval = 240
        static let interstitialIdleDelay: TimeInterval = 2.5
        static let interstitialMinInterval: TimeInterval = 180
        static let interstitialDailyMax: Int = 5
        static let removeAdsRewardDuration: TimeInterval = 3600
    }
}
