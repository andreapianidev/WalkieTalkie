package com.immaginet.talky.radio

/**
 * Stazione radio. Modello allineato alla controparte iOS (RadioManager.swift):
 * id/name/country/frequency/streamUrl/genre + flag Pro.
 *
 * `isPro` segue la regola storica `id > 30` (le prime 30 stazioni sono Free),
 * ma può essere forzato esplicitamente per aggiungere stazioni Free con id > 30
 * senza dover rinumerare la lista (i preferiti sono salvati per id).
 */
data class RadioStation(
    val id: Int,
    val name: String,
    val country: String,
    val frequency: String,
    val streamUrl: String,
    val genre: String,
    val isPro: Boolean = id > 30
) {
    /** Etichetta da mostrare quando la frequenza è "—" (stream internet senza FM reale). */
    val displayLabel: String
        get() = if (frequency == "—" || frequency.isEmpty()) genre.uppercase() else frequency
}
