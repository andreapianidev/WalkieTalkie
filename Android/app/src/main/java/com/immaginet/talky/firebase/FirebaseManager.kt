package com.immaginet.talky.firebase

import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics

object FirebaseManager {

    private var analytics: FirebaseAnalytics? = null

    fun init(app: FirebaseApp) {
        analytics = FirebaseAnalytics.getInstance(app.applicationContext)
        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(true)
    }

    fun trackEvent(eventName: String, params: Map<String, String> = emptyMap()) {
        val bundle = Bundle().apply {
            params.forEach { (key, value) -> putString(key, value) }
        }
        analytics?.logEvent(eventName, bundle)
    }

    fun trackRadioUsage(stationName: String, country: String) {
        trackEvent("radio_station_played", mapOf(
            "station_name" to stationName,
            "country" to country
        ))
    }

    fun trackPTTUsed(channel: String) {
        trackEvent("ptt_transmission", mapOf(
            "channel" to channel
        ))
    }

    fun trackPeerDiscovered(peerName: String) {
        trackEvent("peer_discovered", mapOf(
            "peer_name" to peerName
        ))
    }

    fun trackConnectionEstablished(peerName: String) {
        trackEvent("connection_established", mapOf(
            "peer_name" to peerName
        ))
    }

    fun recordNonFatal(error: Throwable) {
        FirebaseCrashlytics.getInstance().recordException(error)
    }

    fun setUserId(userId: String) {
        FirebaseCrashlytics.getInstance().setUserId(userId)
        analytics?.setUserId(userId)
    }
}
