package com.immaginet.talky.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

object AdManager {
    private const val TAG = "AdManager"

    private val requestGate = AdsRequestGate()
    private var consentInformationRequested = false
    private var mobileAdsInitialized = false
    private var consentInformation: ConsentInformation? = null
    private var interstitialAd: InterstitialAd? = null
    private var rewardedAd: RewardedAd? = null
    private var interstitialLoading = false
    private var rewardedLoading = false

    var canRequestAds by mutableStateOf(false)
        private set

    var privacyOptionsRequired by mutableStateOf(false)
        private set

    fun gatherConsentAndInitialize(activity: Activity) {
        val params = ConsentRequestParameters.Builder()
            .setTagForUnderAgeOfConsent(false)
            .build()

        val information = UserMessagingPlatform.getConsentInformation(activity)
        consentInformation = information
        information.requestConsentInfoUpdate(
            activity,
            params,
            {
                consentInformationRequested = true
                refreshPrivacyState()
                refreshAdEligibility(activity.applicationContext)
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                    if (error != null) {
                        Log.e(TAG, "Consent form error: ${error.message}")
                    }
                    refreshPrivacyState()
                    refreshAdEligibility(activity.applicationContext)
                }
            },
            { error ->
                consentInformationRequested = true
                Log.e(TAG, "Consent update error: ${error.message}")
                refreshPrivacyState()
                refreshAdEligibility(activity.applicationContext)
            }
        )
    }

    fun showPrivacyOptions(activity: Activity) {
        if (!privacyOptionsRequired) return
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
            if (error != null) {
                Log.e(TAG, "Privacy options error: ${error.message}")
            }
            refreshPrivacyState()
            refreshAdEligibility(activity.applicationContext)
        }
    }

    private fun refreshPrivacyState() {
        privacyOptionsRequired = consentInformation?.privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
    }

    private fun refreshAdEligibility(context: Context) {
        val allowed = consentInformation?.canRequestAds() == true
        canRequestAds = allowed
        if (!allowed) {
            interstitialAd = null
            rewardedAd = null
            return
        }

        if (requestGate.tryOpen(consentInformationRequested, canRequestAds)) {
            MobileAds.initialize(context) {
                mobileAdsInitialized = true
                loadInterstitial(context)
                loadRewarded(context)
            }
        } else if (mobileAdsInitialized) {
            if (interstitialAd == null) loadInterstitial(context)
            if (rewardedAd == null) loadRewarded(context)
        }
    }

    fun loadInterstitial(context: Context) {
        if (!canRequestAds || interstitialLoading || interstitialAd != null) return
        interstitialLoading = true
        InterstitialAd.load(
            context,
            AdConfig.interstitialId,
            AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitialLoading = false
                    if (canRequestAds) interstitialAd = ad
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitialLoading = false
                    interstitialAd = null
                    Log.w(TAG, "Interstitial load failed: ${error.message}")
                }
            }
        )
    }

    fun showInterstitial(activity: Activity, onDismissed: () -> Unit) {
        val ad = interstitialAd
        if (!canRequestAds || ad == null) {
            onDismissed()
            return
        }

        interstitialAd = null
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                onDismissed()
                loadInterstitial(activity.applicationContext)
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                Log.w(TAG, "Interstitial show failed: ${error.message}")
                onDismissed()
                loadInterstitial(activity.applicationContext)
            }
        }
        ad.show(activity)
    }

    fun loadRewarded(context: Context) {
        if (!canRequestAds || rewardedLoading || rewardedAd != null) return
        rewardedLoading = true
        RewardedAd.load(
            context,
            AdConfig.rewardedId,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewardedLoading = false
                    if (canRequestAds) rewardedAd = ad
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewardedLoading = false
                    rewardedAd = null
                    Log.w(TAG, "Rewarded load failed: ${error.message}")
                }
            }
        )
    }

    fun showRewarded(activity: Activity, onComplete: (Boolean) -> Unit) {
        val ad = rewardedAd
        if (!canRequestAds || ad == null) {
            onComplete(false)
            return
        }

        rewardedAd = null
        var completionDelivered = false
        fun complete(earned: Boolean) {
            if (!completionDelivered) {
                completionDelivered = true
                onComplete(earned)
            }
        }

        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                complete(false)
                loadRewarded(activity.applicationContext)
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                Log.w(TAG, "Rewarded show failed: ${error.message}")
                complete(false)
                loadRewarded(activity.applicationContext)
            }
        }
        ad.show(activity) {
            complete(true)
        }
    }
}
