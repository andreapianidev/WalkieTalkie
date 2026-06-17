//  AdConfig.swift
//  WalkieTalkie - Talky
//
//  Created by Andrea Piani - Immaginet Srl

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
    static let bannerAdUnitID        = "ca-app-pub-1193280742171051/3958227741" // placeholder – creare in console AdMob
    #endif

    enum FrequencyCap {
        static let appOpenMaxAge: TimeInterval = 4 * 3600
        static let appOpenResumeDelay: TimeInterval = 1.2
        static let interstitialIdleDelay: TimeInterval = 2.5
        static let interstitialMinInterval: TimeInterval = 180
        static let interstitialDailyMax: Int = 5
        static let removeAdsRewardDuration: TimeInterval = 3600
    }
}
