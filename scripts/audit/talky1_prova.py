#!/usr/bin/env python3
"""Un finto dispositivo Talky che parla TALKY1, per provare dal Mac l'app vera.

Fa le tre cose che fa un Android o un Mac con l'iPhone (l'audio parte sia nel
formato vecchio sia con i campi del ponte A-B-C, e una volta come doppione):
  1. guarda chi si annuncia su `_walkie-talkie._tcp` (Multipeer e TALKY1);
  2. si annuncia come "Talky Prova" e aspetta che l'app lo chiami da sola;
  3. chiama lui ogni Talky TALKY1 trovato, scambia HELLO e manda audio.

Per l'iPhone serve l'app nel simulatore (condivide la rete del Mac), per il
Mac basta l'app aperta. Non tocca l'app: legge solo quello che passa in rete.

Uso:  python3 scripts/audit/talky1_prova.py [--attesa 25] [--canale public]
Esce con 1 se una delle prove fallisce.
"""
import argparse
import re
import socket
import struct
import subprocess
import sys
import threading
import time
import uuid
from urllib.parse import quote, unquote

TIPO = "_walkie-talkie._tcp"
UID = "prova-" + uuid.uuid4().hex[:8]
esiti = []


def esito(ok, msg):
    esiti.append((ok, msg))
    print(("OK     " if ok else "FALLITO"), msg, flush=True)


def riga(tipo, **campi):
    corpo = "|".join(f"{quote(k, safe='-._~')}={quote(v, safe='-._~')}" for k, v in campi.items())
    return f"TALKY1|{tipo}|{corpo}\n".encode()


def manda(sock, payload):
    sock.sendall(struct.pack(">I", len(payload)) + payload)


def ricevi(sock, timeout):
    sock.settimeout(timeout)
    testa = b""
    while len(testa) < 4:
        pezzo = sock.recv(4 - len(testa))
        if not pezzo:
            raise ConnectionError("chiusa prima dell'intestazione")
        testa += pezzo
    (n,) = struct.unpack(">I", testa)
    dati = b""
    while len(dati) < n:
        pezzo = sock.recv(n - len(dati))
        if not pezzo:
            raise ConnectionError("chiusa a meta' del messaggio")
        dati += pezzo
    return dati


def decodifica(payload):
    try:
        testo = payload.decode().strip()
    except UnicodeDecodeError:
        return None
    parti = testo.split("|")
    if len(parti) < 2 or parti[0] != "TALKY1":
        return None
    campi = {}
    for p in parti[2:]:
        if "=" in p:
            k, v = p.split("=", 1)
            campi[unquote(k)] = unquote(v)
    return parti[1], campi


def audio_prova():
    # 100 ms di un La a 440 Hz, PCM16LE mono 48 kHz, come lo manda l'app.
    import math
    campioni = [int(8000 * math.sin(2 * math.pi * 440 * i / 48000)) for i in range(4800)]
    return struct.pack("<%dh" % len(campioni), *campioni)


def scambio(sock, chi, canale, uid=UID):
    """HELLO in entrambe le direzioni e un pacchetto audio. Vale per tutte e due le prove."""
    manda(sock, riga("HELLO", uid=uid, name="Talky Prova", channel=canale))
    msg = decodifica(ricevi(sock, 10))
    if not msg or msg[0] != "HELLO":
        esito(False, f"{chi}: il primo messaggio non e' un HELLO ({msg})")
        return
    esito(True, f"{chi}: HELLO ricevuto da {msg[1].get('name')!r} canale {msg[1].get('channel')!r}")
    pcm = audio_prova()
    # Prima come una versione vecchia, poi con i campi del ponte. ttl=1: l'app
    # deve suonarlo ma non ritrasmetterlo. Lo stesso msgId mandato di nuovo e'
    # un doppione: l'app non deve suonarlo una seconda volta (si sente un La solo
    # per i due messaggi del ponte) e la connessione deve restare aperta.
    manda(sock, riga("AUDIO_META", byteCount=str(len(pcm)), sampleRate="48000", channels="1", encoding="pcm_s16le"))
    manda(sock, pcm)
    ponte = dict(msgId=str(uuid.uuid4()), origin=uid, originName="Talky Prova", ttl="1",
                 reached=uid[:8].lower())
    for _ in range(2):
        manda(sock, riga("AUDIO_META", byteCount=str(len(pcm)), sampleRate="48000", channels="1",
                         encoding="pcm_s16le", **ponte))
        manda(sock, pcm)
    manda(sock, riga("HEARTBEAT"))
    # Dopo l'audio la connessione deve restare viva: se l'app la chiude o
    # smette di leggere, il secondo messaggio non passa.
    time.sleep(1.5)
    try:
        manda(sock, riga("HEARTBEAT"))
        sock.settimeout(0.5)
        try:
            if sock.recv(1, socket.MSG_PEEK) == b"":
                esito(False, f"{chi}: l'app ha chiuso la connessione dopo l'audio")
                return
        except socket.timeout:
            pass
        esito(True, f"{chi}: audio inviato ({len(pcm)} byte) e connessione ancora aperta")
    except OSError as e:
        esito(False, f"{chi}: connessione caduta dopo l'audio ({e})")


def sfoglia(secondi):
    p = subprocess.Popen(["dns-sd", "-B", TIPO, "local."], stdout=subprocess.PIPE, text=True)
    time.sleep(secondi)
    p.terminate()
    out = p.communicate()[0]
    nomi = set()
    for r in out.splitlines():
        m = re.match(r"\s*\S+\s+Add\s+\d+\s+\d+\s+\S+\s+_walkie-talkie\._tcp\.\s+(.+)$", r)
        if m:
            nomi.add(m.group(1).strip())
    return nomi


def risolvi(nome):
    p = subprocess.Popen(["dns-sd", "-L", nome, TIPO, "local."], stdout=subprocess.PIPE, text=True)
    time.sleep(3)
    p.terminate()
    out = p.communicate()[0]
    m = re.search(r"can be reached at (\S+?)\.?:(\d+)", out)
    txt = dict(re.findall(r"(\w+)=(\S+)", out.split("can be reached at", 1)[-1])) if m else {}
    return (m.group(1), int(m.group(2)), txt) if m else (None, None, {})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--attesa", type=int, default=25, help="secondi per farsi chiamare dall'app")
    ap.add_argument("--canale", default="public")
    a = ap.parse_args()

    print("1) chi si annuncia su", TIPO)
    nomi = sfoglia(6)
    for n in sorted(nomi):
        print("   -", n)
    talky1 = []
    for n in sorted(nomi):
        host, porta, txt = risolvi(n)
        if txt.get("proto") == "talky1":
            talky1.append((n, host, porta, txt))
    esito(bool(talky1), f"servizi TALKY1 visibili: {[n for n, *_ in talky1]}")
    altri = sorted(nomi - {n for n, *_ in talky1})
    if altri:
        print("   annunci non TALKY1 sullo stesso tipo (Multipeer):", altri)

    print(f"2) mi annuncio come 'Talky Prova' e aspetto {a.attesa}s che l'app mi chiami")
    srv = socket.socket()
    srv.bind(("0.0.0.0", 0))
    srv.listen(4)
    porta = srv.getsockname()[1]
    reg = subprocess.Popen(["dns-sd", "-R", "Talky Prova", TIPO, "local.", str(porta),
                            "proto=talky1", f"uid={UID}", "name=Talky Prova", f"channel={a.canale}"],
                           stdout=subprocess.DEVNULL)
    srv.settimeout(a.attesa)
    arrivate = []
    try:
        while True:
            c, ind = srv.accept()
            arrivate.append(ind)
            threading.Thread(target=scambio, args=(c, f"chiamata in arrivo da {ind[0]}", a.canale), daemon=True).start()
            srv.settimeout(3)
    except socket.timeout:
        pass
    time.sleep(4)
    esito(bool(arrivate), f"l'app mi ha chiamato da sola: {len(arrivate)} connessioni")
    reg.terminate()

    print("3) chiamo io ogni Talky TALKY1 trovato")
    for n, host, porta, txt in talky1:
        try:
            s = socket.create_connection((host, porta), timeout=5)
            # Identificativo diverso dalla prova 2: tolto l'annuncio "Talky Prova",
            # l'app chiude giustamente le connessioni di quel dispositivo.
            scambio(s, f"chiamata verso {n!r}", a.canale, uid=UID + "-b")
            s.close()
        except OSError as e:
            esito(False, f"chiamata verso {n!r} ({host}:{porta}): {e}")

    falliti = [m for ok, m in esiti if not ok]
    print(f"\n{len(esiti) - len(falliti)} prove passate, {len(falliti)} fallite")
    sys.exit(1 if falliti else 0)


if __name__ == "__main__":
    main()
