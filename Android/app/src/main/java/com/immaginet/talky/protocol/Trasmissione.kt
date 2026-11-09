package com.immaginet.talky.protocol

import java.util.UUID

/**
 * Il ponte A-B-C: ogni telefono suona quello che riceve e lo ritrasmette ai
 * propri peer con una tratta in meno, cosi' A parla con C passando da B.
 * Gemella di WalkieTalkie/Ponte.swift (iOS) e macTalky/Core/Ponte.swift (Mac).
 *
 * Viaggia come campi in piu' di AUDIO_META: le versioni vecchie li ignorano e
 * suonano il messaggio come sempre.
 */
data class Trasmissione(
    val id: String,
    /** uid di chi ha parlato, e il nome da mostrare a chi ascolta. */
    val origine: String,
    val nomeOrigine: String,
    val ttl: Int,
    /**
     * id corti di chi l'ha gia' ricevuta direttamente: il ponte non gliela
     * rimanda. In un gruppo tutti collegati con tutti, senza questo elenco
     * ogni messaggio verrebbe ricopiato da ognuno a ognuno.
     */
    val raggiunti: Set<String>
) {
    val campi: Map<String, String>
        get() = mapOf(
            TalkyProtocol.Keys.MSG_ID to id,
            TalkyProtocol.Keys.ORIGIN to origine,
            TalkyProtocol.Keys.ORIGIN_NAME to nomeOrigine,
            TalkyProtocol.Keys.TTL to ttl.toString(),
            TalkyProtocol.Keys.REACHED to raggiunti.sorted().joinToString(",")
        )

    /** La copia da ritrasmettere: una tratta in meno, e chi l'ha gia'. */
    fun perIlPonte(locale: String, arrivataDa: String?, destinatari: Collection<String>): Trasmissione {
        val gia = listOfNotNull(locale, origine, arrivataDa) + destinatari
        return copy(ttl = ttl - 1, raggiunti = raggiunti + gia.map(::idCorto))
    }

    companion object {
        /** Due tratte: A -> B -> C. Di piu' moltiplica il traffico in una folla. */
        const val TTL_INIZIALE = 2

        fun nuova(origine: String, nome: String, destinatari: Collection<String>): Trasmissione =
            Trasmissione(
                id = UUID.randomUUID().toString(),
                origine = origine,
                nomeOrigine = nome,
                ttl = TTL_INIZIALE,
                raggiunti = (listOf(origine) + destinatari).map(::idCorto).toSet()
            )

        /** null se il messaggio viene da una versione senza ponte. */
        fun daCampi(campi: Map<String, String>): Trasmissione? {
            val id = campi[TalkyProtocol.Keys.MSG_ID]?.takeIf { it.isNotEmpty() } ?: return null
            val ttl = campi[TalkyProtocol.Keys.TTL]?.toIntOrNull() ?: return null
            return Trasmissione(
                id = id,
                origine = campi[TalkyProtocol.Keys.ORIGIN].orEmpty(),
                nomeOrigine = campi[TalkyProtocol.Keys.ORIGIN_NAME].orEmpty(),
                ttl = ttl,
                raggiunti = campi[TalkyProtocol.Keys.REACHED].orEmpty()
                    .split(',').filter { it.isNotEmpty() }.toSet()
            )
        }

        fun idCorto(uid: String): String = uid.lowercase().take(8)
    }
}

/**
 * Gli ultimi id visti, per scartare i doppioni: lo stesso messaggio arriva
 * diretto e passando da un ponte, a pochi secondi di distanza.
 */
class MemoriaPonte(private val capienza: Int = 256) {
    private val visti = LinkedHashSet<String>()

    @Synchronized
    fun primaVolta(id: String): Boolean {
        if (!visti.add(id)) return false
        if (visti.size > capienza) visti.remove(visti.first())
        return true
    }
}
