package com.immaginet.talky.ads

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView

@Composable
fun AdBanner(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    // Doppia guardia voluta: `AdManager` non alza mai `canRequestAds` senza ID
    // reali, ma il banner è la sola pubblicità che l'utente vede sempre a
    // schermo, e un giorno che qualcuno tocchi quel percorso qui non deve
    // ricomparire la striscia "Test Ad".
    if (!AdConfig.isConfigured) return
    val canRequestAds = AdManager.canRequestAds
    val privacyOptionsRequired = AdManager.privacyOptionsRequired

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (canRequestAds) {
            val adView = remember(context) {
                AdView(context).apply {
                    setAdSize(AdSize.BANNER)
                    adUnitId = AdConfig.bannerId
                    loadAd(AdRequest.Builder().build())
                }
            }
            DisposableEffect(adView) {
                onDispose { adView.destroy() }
            }
            AndroidView(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                factory = { adView }
            )
        }

        if (privacyOptionsRequired) {
            TextButton(
                onClick = {
                    context.findActivity()?.let(AdManager::showPrivacyOptions)
                }
            ) {
                Text("Scelte privacy")
            }
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
