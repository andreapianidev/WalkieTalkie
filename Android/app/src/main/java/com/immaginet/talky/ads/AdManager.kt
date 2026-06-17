package com.immaginet.talky.ads

import android.content.Context
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentForm
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import java.util.concurrent.atomic.AtomicBoolean

object AdManager {

    private var isInitialized = AtomicBoolean(false)
    private var consentInformation: ConsentInformation? = null
    private var interstitialAd: InterstitialAd? = null
    private var rewardedAd: RewardedAd? = null
    private var interstitialCallback: (() -> Unit)? = null
    private var rewardedCallback: ((Boolean) -> Unit)? = null

    fun initialize(context: Context) {
        if (isInitialized.getAndSet(true)) return

        MobileAds.initialize(context) {
            loadInterstitial(context)
            loadRewarded(context)
        }
    }

    fun requestConsent(activity: android.app.Activity) {
        val params = ConsentRequestParameters.Builder()
            .setTagForUnderAgeOfConsent(false)
            .build()

        consentInformation = UserMessagingPlatform.getConsentInformation(activity)
        consentInformation?.requestConsentInfoUpdate(activity, params, {
            if (consentInformation?.isConsentFormAvailable == true) {
                activity.runOnUiThread {
                    loadConsentForm(activity)
                }
            }
        }, { error ->
            android.util.Log.e("AdManager", "Consent error: ${error.message}")
        })
    }

    private fun loadConsentForm(activity: android.app.Activity) {
        UserMessagingPlatform.loadConsentForm(activity, { form ->
            form.show(activity) { error ->
                if (error == null) {
                    android.util.Log.d("AdManager", "Consent obtained")
                }
            }
        }, { error ->
            android.util.Log.e("AdManager", "Form load error: ${error.message}")
        })
    }

    fun loadInterstitial(context: Context) {
        InterstitialAd.load(context, AdConfig.interstitialId, AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitialAd = ad
                    interstitialAd?.fullScreenContentCallback = object : FullScreenContentCallback() {
                        override fun onAdDismissedFullScreenContent() {
                            interstitialCallback?.invoke()
                            interstitialCallback = null
                            loadInterstitial(context)
                        }
                        override fun onAdFailedToShowFullScreenContent(error: AdError) {
                            interstitialCallback?.invoke()
                            interstitialCallback = null
                        }
                    }
                }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitialAd = null
                }
            })
    }

    fun showInterstitial(onDismissed: () -> Unit) {
        if (interstitialAd != null) {
            interstitialCallback = onDismissed
            interstitialAd?.show(null as? android.app.Activity ?: return)
        } else {
            onDismissed()
        }
    }

    fun loadRewarded(context: Context) {
        RewardedAd.load(context, AdConfig.rewardedId, AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewardedAd = ad
                }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewardedAd = null
                }
            })
    }

    fun showRewarded(activity: android.app.Activity, onComplete: (Boolean) -> Unit) {
        if (rewardedAd != null) {
            rewardedCallback = onComplete
            rewardedAd?.show(activity) { rewardItem ->
                rewardedCallback?.invoke(true)
                rewardedCallback = null
                loadRewarded(activity)
            }
        } else {
            onComplete(false)
        }
    }
}
