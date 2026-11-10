// creato da Andrea Piani - 10/11/26 - https://www.andreapiani.com - ReviewPrompt.kt
package com.immaginet.talky.review

import android.app.Activity
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.lifecycle.Lifecycle
import com.google.android.play.core.review.ReviewManagerFactory
import com.immaginet.talky.BuildConfig
import com.immaginet.talky.firebase.FirebaseManager
import java.time.LocalDate

/**
 * Quando chiedere la recensione su Google Play: le stesse regole di
 * ReviewPromptManager su iPhone. Solo dopo che Talky ha funzionato davvero,
 * cioe' tre trasmissioni chiuse con qualcuno collegato, oppure tre ascolti
 * della radio di almeno [RADIO_LISTEN_MS] in due giorni diversi. Chi non e'
 * mai riuscito a parlare con nessuno non deve trovarsi davanti la richiesta
 * di una stella. Una volta per versione e non piu' spesso di ogni 120 giorni;
 * Google ha poi la sua quota, e puo' non mostrare niente.
 */
object ReviewPrompt {
    const val RADIO_LISTEN_MS = 90_000L

    private const val MIN_TRANSMISSIONS = 3
    private const val MIN_RADIO_LISTENS = 3
    private const val MIN_RADIO_DAYS = 2
    private const val MIN_INTERVAL_MS = 120L * 24 * 60 * 60 * 1000

    private const val PREFS = "review_prompt"
    private const val TRANSMISSIONS = "successful_transmissions"
    private const val RADIO_LISTENS = "radio_listens"
    private const val RADIO_DAYS = "radio_listen_days"
    private const val LAST_DATE = "last_prompt_ms"
    private const val LAST_VERSION = "last_prompt_version"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Una trasmissione chiusa mentre almeno un altro Talky era collegato. */
    fun recordTransmission(activity: Activity) {
        val p = prefs(activity)
        p.edit().putInt(TRANSMISSIONS, p.getInt(TRANSMISSIONS, 0) + 1).apply()
        askIfAppropriate(activity)
    }

    /** Una stazione che ha suonato [RADIO_LISTEN_MS] di fila. */
    fun recordRadioListen(activity: Activity) {
        val p = prefs(activity)
        val days = (p.getStringSet(RADIO_DAYS, emptySet()) ?: emptySet()) + LocalDate.now().toString()
        p.edit()
            .putInt(RADIO_LISTENS, p.getInt(RADIO_LISTENS, 0) + 1)
            .putStringSet(RADIO_DAYS, days)
            .apply()
        askIfAppropriate(activity)
    }

    private fun askIfAppropriate(activity: Activity) {
        val p = prefs(activity)
        val walkieWorked = p.getInt(TRANSMISSIONS, 0) >= MIN_TRANSMISSIONS
        val radioWorked = p.getInt(RADIO_LISTENS, 0) >= MIN_RADIO_LISTENS &&
            (p.getStringSet(RADIO_DAYS, emptySet())?.size ?: 0) >= MIN_RADIO_DAYS
        if (!walkieWorked && !radioWorked) return
        if (p.getString(LAST_VERSION, null) == BuildConfig.VERSION_NAME) return
        if (System.currentTimeMillis() - p.getLong(LAST_DATE, 0L) < MIN_INTERVAL_MS) return
        // Con l'app in secondo piano Google non mostra niente: meglio
        // aspettare il prossimo evento che bruciare la versione.
        val resumed = (activity as? ComponentActivity)?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED) ?: false
        if (!resumed) return

        // Segnato prima di chiedere: se Google decide di non mostrare nulla
        // non si riprova a ogni trasmissione.
        p.edit()
            .putLong(LAST_DATE, System.currentTimeMillis())
            .putString(LAST_VERSION, BuildConfig.VERSION_NAME)
            .apply()

        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful) return@addOnCompleteListener
            manager.launchReviewFlow(activity, request.result)
            FirebaseManager.trackEvent(
                "review_prompt_shown",
                mapOf(
                    "successful_transmissions" to p.getInt(TRANSMISSIONS, 0).toString(),
                    "radio_listens" to p.getInt(RADIO_LISTENS, 0).toString()
                )
            )
        }
    }
}
