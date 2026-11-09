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
            TalkyProtocol.Keys.REACHED to raggiunti.sorted().take(LIMITE_RAGGIUNTI).joinToString(",")
        )

    /** La copia da ritrasmettere: una tratta in meno, e chi l'ha gia'. */
    fun perIlPonte(locale: String, arrivataDa: String?, destinatari: Collection<String>): Trasmissione {
        val gia = listOfNotNull(locale, origine, arrivataDa) + destinatari
        return copy(ttl = ttl - 1, raggiunti = raggiunti + gia.map(::idCorto))
    }

    companion object {
        /** Due tratte: A -> B -> C. Di piu' moltiplica il traffico in una folla.
         *  E' anche il massimo accettato: un ttl piu' alto in arrivo si abbassa. */
        const val TTL_INIZIALE = 2

        // Quello che arriva da un altro dispositivo si taglia qui: un peer
        // difettoso o modificato non deve far crescere i campi senza limite.
        private const val LIMITE_ID = 64
        private const val LIMITE_ORIGINE = 64
        private const val LIMITE_NOME = 64
        private const val LIMITE_RAGGIUNTI = 64

        fun nuova(origine: String, nome: String, destinatari: Collection<String>): Trasmissione =
            Trasmissione(
                id = UUID.randomUUID().toString(),
                origine = origine,
                nomeOrigine = nome.take(LIMITE_NOME),
                ttl = TTL_INIZIALE,
                raggiunti = (listOf(origine) + destinatari).take(LIMITE_RAGGIUNTI).map(::idCorto).toSet()
            )

        /** null se il messaggio viene da una versione senza ponte o se l'id e' fuori misura. */
        fun daCampi(campi: Map<String, String>): Trasmissione? {
            val id = campi[TalkyProtocol.Keys.MSG_ID]
                ?.takeIf { it.isNotEmpty() && it.length <= LIMITE_ID } ?: return null
            val ttl = campi[TalkyProtocol.Keys.TTL]?.toIntOrNull() ?: return null
            return Trasmissione(
                id = id,
                origine = campi[TalkyProtocol.Keys.ORIGIN].orEmpty().take(LIMITE_ORIGINE),
                nomeOrigine = campi[TalkyProtocol.Keys.ORIGIN_NAME].orEmpty().take(LIMITE_NOME),
                ttl = minOf(ttl, TTL_INIZIALE),
                raggiunti = campi[TalkyProtocol.Keys.REACHED].orEmpty()
                    .split(',').filter { it.isNotEmpty() }
                    .take(LIMITE_RAGGIUNTI).map(::idCorto).toSet()
            )
        }

        fun idCorto(uid: String): String = uid.lowercase().take(8)
    }
}

/**
 * Gli ultimi id visti, per scartare i doppioni: lo stesso messaggio arriva
 * diretto e passando da un ponte, a pochi secondi di distanza. Un id conta come
 * visto solo quando il messaggio e' arrivato tutto: se una connessione cade a
 * meta', la copia intera da un altro ponte deve ancora passare.
 */
class MemoriaPonte(private val capienza: Int = 256) {
    private val visti = LinkedHashSet<String>()
    private val inCorso = HashSet<String>()

    /** Un messaggio partito da qui: se torna indietro da un ponte non si suona. */
    @Synchronized
    fun segna(id: String) = ricorda(id)

    /** Comincia ad arrivare un messaggio: false se e' un doppione o se un'altra copia sta gia' arrivando. */
    @Synchronized
    fun inizia(id: String): Boolean {
        if (id in visti || id in inCorso) return false
        if (inCorso.size >= capienza) inCorso.clear()
        inCorso.add(id)
        return true
    }

    @Synchronized
    fun completa(id: String) {
        inCorso.remove(id)
        ricorda(id)
    }

    @Synchronized
    fun abbandona(id: String) {
        inCorso.remove(id)
    }

    private fun ricorda(id: String) {
        if (!visti.add(id)) return
        if (visti.size > capienza) visti.remove(visti.first())
    }
}
