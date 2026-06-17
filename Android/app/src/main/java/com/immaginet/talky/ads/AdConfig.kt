package com.immaginet.talky.ads

import com.immaginet.talky.BuildConfig

/**
 * Configurazione AdMob.
 *
 * Strategia (allineata alla controparte iOS):
 *  - Build DEBUG  → sempre ID di test ufficiali Google (nessun rischio di strike policy).
 *  - Build RELEASE → ID LIVE, MA solo se sono stati inseriti ID reali. Finché i `LIVE_*`
 *    restano placeholder (`0000…`) si continua a usare gli ID di test: in questo modo
 *    l'APK pubblicato come release sorgente/sideload su GitHub è conforme alle policy
 *    AdMob (gli annunci live vanno richiesti solo dall'app pubblicata sullo store).
 *
 * Per andare in produzione su Play Store: sostituire i valori `LIVE_*` con gli ID reali
 * dell'account AdMob e l'App ID di test nel manifest con quello reale.
 */
object AdConfig {
    const val TEST_APP_ID = "ca-app-pub-3940256099942544~3347511713"
    const val LIVE_APP_ID = "ca-app-pub-0000000000000000~0000000000"

    const val TEST_BANNER = "ca-app-pub-3940256099942544/6300978111"
    const val LIVE_BANNER = "ca-app-pub-0000000000000000/0000000001"

    const val TEST_INTERSTITIAL = "ca-app-pub-3940256099942544/1033173712"
    const val LIVE_INTERSTITIAL = "ca-app-pub-0000000000000000/0000000002"

    const val TEST_REWARDED = "ca-app-pub-3940256099942544/5224354917"
    const val LIVE_REWARDED = "ca-app-pub-0000000000000000/0000000003"

    const val TEST_APP_OPEN = "ca-app-pub-3940256099942544/9257395921"
    const val LIVE_APP_OPEN = "ca-app-pub-0000000000000000/0000000004"

    /** `true` se l'ID live è ancora un placeholder non configurato. */
    private fun isPlaceholder(id: String) = id.contains("0000000000000000")

    /** Sceglie l'ID live solo in release e solo se realmente configurato, altrimenti test. */
    private fun resolve(live: String, test: String): String =
        if (!BuildConfig.DEBUG && !isPlaceholder(live)) live else test

    val bannerId: String get() = resolve(LIVE_BANNER, TEST_BANNER)
    val interstitialId: String get() = resolve(LIVE_INTERSTITIAL, TEST_INTERSTITIAL)
    val rewardedId: String get() = resolve(LIVE_REWARDED, TEST_REWARDED)
    val appOpenId: String get() = resolve(LIVE_APP_OPEN, TEST_APP_OPEN)
}
