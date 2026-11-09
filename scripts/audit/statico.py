#!/usr/bin/env python3
"""Controlli statici di Talky prima di un invio allo Store.

Non compila e non avvia niente: legge sorgenti, cataloghi e progetto e dice
cosa non torna. Ogni controllo nasce da un difetto vero gia' successo (vedi
CLAUDE.md del progetto): traduzioni rotte, pubblicita' che resta ai Pro,
versioni chiuse, elenchi radio che divergono fra iPhone, Mac e Android.

Uso:  python3 scripts/audit/statico.py            (dalla radice del repo)
      python3 scripts/audit/statico.py --radio    (prova anche i 343 flussi)
Esce con 1 se c'e' almeno un ERRORE, 0 se ci sono solo avvisi.
"""
import concurrent.futures as cf
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errori, avvisi = [], []


def err(msg):
    errori.append(msg)


def warn(msg):
    avvisi.append(msg)


# ---------------------------------------------------------------- .strings

STRINGS_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)
FMT_RE = re.compile(r'%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDiuUxXoOfeEgGcCsSpaA%]')


def leggi_strings(path):
    testo = path.read_text(encoding="utf-8")
    coppie = STRINGS_RE.findall(testo)
    chiavi = [k for k, _ in coppie]
    doppie = [k for k, n in Counter(chiavi).items() if n > 1]
    # Una riga con virgolette che la regex non riconosce e' quasi sempre un
    # punto e virgola mancante: il file intero smette di caricarsi.
    righe_sospette = [
        i + 1 for i, r in enumerate(testo.splitlines())
        if r.strip().startswith('"') and not STRINGS_RE.match(r)
    ]
    return dict(coppie), doppie, righe_sospette


def formati(valore):
    return sorted(f for f in FMT_RE.findall(valore) if f != "%%")


def controlla_tabella(cartella, nome_file):
    lproj = sorted(cartella.glob("*.lproj"))
    base = cartella / "en.lproj" / nome_file
    if not base.exists():
        return {}
    en, doppie, sospette = leggi_strings(base)
    rel = base.relative_to(ROOT)
    for k in doppie:
        err(f"{rel}: chiave doppia {k!r}")
    for r in sospette:
        err(f"{rel}:{r}: riga non valida (punto e virgola o virgolette)")
    for d in lproj:
        f = d / nome_file
        lingua = d.stem
        if lingua == "en":
            continue
        if not f.exists():
            err(f"{f.relative_to(ROOT)}: file mancante")
            continue
        tab, doppie, sospette = leggi_strings(f)
        relf = f.relative_to(ROOT)
        for k in doppie:
            err(f"{relf}: chiave doppia {k!r}")
        for r in sospette:
            err(f"{relf}:{r}: riga non valida (punto e virgola o virgolette)")
        mancanti = sorted(set(en) - set(tab))
        if mancanti:
            err(f"{relf}: {len(mancanti)} chiavi mancanti, es. {mancanti[:5]}")
        extra = sorted(set(tab) - set(en))
        if extra:
            warn(f"{relf}: {len(extra)} chiavi che l'inglese non ha, es. {extra[:5]}")
        for k in set(en) & set(tab):
            if formati(en[k]) != formati(tab[k]):
                err(f"{relf}: {k!r} segnaposto {formati(tab[k])} contro {formati(en[k])} in inglese")
            if not tab[k].strip() and en[k].strip():
                err(f"{relf}: {k!r} vuota")
    return en


def controlla_traduzioni():
    en_app = controlla_tabella(ROOT / "WalkieTalkie", "Localizable.strings")
    controlla_tabella(ROOT / "WalkieTalkie", "InfoPlist.strings")
    controlla_tabella(ROOT / "TalkyWidgets", "Localizable.strings")
    controlla_tabella(ROOT / "Shared" / "Tour", "Tour.strings")

    # Chiavi usate nel codice ma assenti dal catalogo: a schermo esce la chiave.
    usate = {}
    for f in (ROOT / "WalkieTalkie").rglob("*.swift"):
        for m in re.finditer(r'"([A-Za-z0-9_.]+)"\.localized', f.read_text(encoding="utf-8")):
            usate.setdefault(m.group(1), f.relative_to(ROOT))
    for k, f in sorted(usate.items()):
        if k not in en_app:
            err(f"{f}: usa la chiave {k!r} che non esiste in en.lproj/Localizable.strings")


# ---------------------------------------------------------------- testi visibili

def controlla_testi_visibili():
    file_testo = [p for p in ROOT.rglob("*.strings") if "build" not in p.parts]
    file_testo += [p for p in (ROOT / "Android").rglob("strings.xml") if "build" not in p.parts]
    for p in file_testo:
        testo = p.read_text(encoding="utf-8")
        # I commenti non li legge nessun utente: si svuotano tenendo le righe.
        testo = re.sub(r"<!--.*?-->|/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), testo, flags=re.S)
        for n, riga in enumerate(testo.splitlines(), 1):
            if riga.lstrip().startswith(("//", "/*", "<!--")):
                continue
            if "—" in riga or "–" in riga:
                err(f"{p.relative_to(ROOT)}:{n}: lineetta lunga o media in un testo visibile")
            if re.search(r"immaginet\s*s\.?r\.?l", riga, re.I):
                err(f"{p.relative_to(ROOT)}:{n}: 'Immaginet Srl' in un testo visibile")


# ---------------------------------------------------------------- pubblicita'

def controlla_pubblicita():
    """Ogni superficie che mostra un annuncio deve tacere per i Pro e
    durante l'ora premio, e deve leggere lo stato in modo osservato."""
    banner = (ROOT / "WalkieTalkie/Ads/AdaptiveBannerView.swift").read_text()
    if "@ObservedObject private var iapManager" not in banner or "!iapManager.isProUser" not in banner:
        err("AdaptiveBannerView: lo stato Pro non e' osservato, il banner resta dopo l'acquisto")
    if "!adManager.adsRemoved" not in banner:
        err("AdaptiveBannerView: non controlla l'ora senza annunci")

    content = (ROOT / "WalkieTalkie/ContentView.swift").read_text()
    m = re.search(r"if (.*?)\{\s*\n\s*peakAppPromotionBanner", content, re.S)
    if not m or "isProUser" not in m.group(1) or "adsRemoved" not in m.group(1):
        err("ContentView: la promozione di Peak non tace per i Pro o nell'ora senza annunci")

    # Le funzioni di AdManager che mostrano interstitial e app-open.
    am = (ROOT / "WalkieTalkie/Ads/AdManager.swift").read_text()
    for nome in re.findall(r"func ((?:show|present)\w*)\(", am):
        if "Rewarded" in nome:
            continue  # il video premio lo chiede l'utente, Pro esclusi a monte
        corpo = am[am.index(f"func {nome}("):][:1500]
        corpo = corpo[: corpo.find("\n    func ", 10) if "\n    func " in corpo[10:] else len(corpo)]
        if "isProUser" not in corpo and "canShow" not in corpo and "shouldShow" not in corpo:
            warn(f"AdManager.{nome}: non vedo il controllo Pro nel corpo, verificare a mano")

    # Letture secche del flag Pro dentro una View: non si ridisegnano.
    for f in (ROOT / "WalkieTalkie").rglob("*.swift"):
        t = f.read_text(encoding="utf-8")
        if ": View" not in t:
            continue
        for n, riga in enumerate(t.splitlines(), 1):
            if re.search(r"UserDefaults\.standard\.bool\(forKey: \"fastboot_isProUser\"\)", riga) or \
               re.search(r"IAPManager\.shared\.isProUser", riga):
                warn(f"{f.relative_to(ROOT)}:{n}: stato Pro letto senza osservarlo dentro un file con View")


# ---------------------------------------------------------------- versioni

def controlla_versioni():
    pbx = (ROOT / "WalkieTalkie.xcodeproj/project.pbxproj").read_text()
    build = set(re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", pbx))
    if len(build) != 1:
        err(f"pbxproj: numeri di build diversi fra i target {sorted(build)}")
    blocchi = re.findall(r"buildSettings = \{(.*?)\n\t\t\t\};", pbx, re.S)
    ios, mac = set(), set()
    for b in blocchi:
        v = re.search(r"MARKETING_VERSION = ([^;]+);", b)
        if not v:
            continue
        if "SDKROOT = macosx" in b or "macTalky" in b or "TalkyMacWidgets" in b:
            mac.add(v.group(1))
        else:
            ios.add(v.group(1))
    if len(ios) != 1:
        err(f"pbxproj: versioni iOS diverse fra app ed estensioni {sorted(ios)}")
    if len(mac) != 1:
        err(f"pbxproj: versioni Mac diverse fra app e widget {sorted(mac)}")
    return (ios.pop() if len(ios) == 1 else None), (mac.pop() if len(mac) == 1 else None)


def controlla_versioni_store(ios, mac):
    """Se la versione nel progetto e' gia' in vendita, Xcode Cloud fallisce."""
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from asc import versioni_in_vendita
    except Exception as e:  # senza chiavi si salta, non si inventa
        warn(f"versioni sullo Store non controllate ({e})")
        return
    vendita = versioni_in_vendita()
    if ios in vendita.get("IOS", set()):
        err(f"iOS {ios} e' gia' in vendita: la prossima build verra' rifiutata, alzare MARKETING_VERSION")
    if mac in vendita.get("MAC_OS", set()):
        err(f"macOS {mac} e' gia' in vendita: la prossima build Mac verra' rifiutata, alzare MARKETING_VERSION")


# ---------------------------------------------------------------- permessi

def controlla_permessi():
    import plistlib
    info = plistlib.loads((ROOT / "WalkieTalkie/Info.plist").read_bytes())
    pbx = (ROOT / "WalkieTalkie.xcodeproj/project.pbxproj").read_text()
    bonjour = set(info.get("NSBonjourServices", []))
    for s in ("_walkie-talkie._tcp", "_walkie-talkie._udp"):
        if s not in bonjour:
            err(f"Info.plist iOS: manca {s} in NSBonjourServices, Multipeer non trova nessuno")
    for chiave in ("NSMicrophoneUsageDescription", "NSLocalNetworkUsageDescription"):
        if chiave not in info and f"INFOPLIST_KEY_{chiave}" not in pbx:
            err(f"iOS: manca {chiave}")
    mac_info = ROOT / "macTalky-Info.plist"
    if mac_info.exists():
        m = plistlib.loads(mac_info.read_bytes())
        if "_walkie-talkie._tcp" not in m.get("NSBonjourServices", []) and \
           "_walkie-talkie._tcp" not in pbx.split("macTalky-Info.plist")[-1][:4000]:
            warn("macTalky: NSBonjourServices senza _walkie-talkie._tcp")
    # Ogni descrizione di permesso deve esistere in tutte le lingue (guideline 4).
    chiavi_perm = [k for k in info if k.startswith("NS") and k.endswith("UsageDescription")]
    chiavi_perm += re.findall(r"INFOPLIST_KEY_(NS\w+UsageDescription)", pbx)
    for d in sorted((ROOT / "WalkieTalkie").glob("*.lproj")):
        f = d / "InfoPlist.strings"
        tab = leggi_strings(f)[0] if f.exists() else {}
        for k in set(chiavi_perm):
            if k in ("NSCameraUsageDescription",):
                continue
            if k not in tab:
                warn(f"{d.name}/InfoPlist.strings: manca {k}")


# ---------------------------------------------------------------- protocollo

def controlla_protocollo():
    ios = (ROOT / "WalkieTalkie/TalkyCrossPlatformManager.swift").read_text()
    mac = (ROOT / "macTalky/Core/WalkieEngine.swift").read_text()
    kt = ROOT / "Android/app/src/main/java/com/immaginet/talky"
    andr = "".join(f.read_text() for f in [kt / "net/CrossPlatformWalkieManager.kt", *sorted((kt / "protocol").glob("*.kt"))])
    for nome, t in (("iOS", ios), ("Mac", mac), ("Android", andr)):
        for atteso in ("TALKY1", "_walkie-talkie._tcp", "talky1", "HELLO", "AUDIO_META", "48000"):
            if atteso not in t:
                err(f"protocollo {nome}: manca {atteso!r}")
    # NetService e NetServiceBrowser vivono sul run loop: creati su una coda
    # GCD senza run loop non pubblicano ne' trovano niente.
    for nome, t in (("iOS", ios), ("Mac", mac)):
        if "NetServiceBrowser()" in t and "schedule(in:" not in t:
            err(f"protocollo {nome}: NetService/NetServiceBrowser senza schedule(in: .main), "
                "su una coda GCD non arrivano mai le risposte")


# ---------------------------------------------------------------- radio

ST_SWIFT = re.compile(r'RadioStation\(id: (\d+), name: "((?:[^"\\]|\\.)*)", country: "[^"]*", '
                      r'frequency: "[^"]*", streamURL: "([^"]+)"')
ST_KT = re.compile(r'RadioStation\((\d+), "((?:[^"\\]|\\.)*)", "[^"]*", "[^"]*", "([^"]+)"')


def _senza_ripiego(testo):
    # La stazione di ripiego (`?? RadioStation(...)`) non e' una voce dell'elenco.
    return "\n".join(r for r in testo.splitlines() if "?? RadioStation(" not in r)


def stazioni():
    ios = ST_SWIFT.findall(_senza_ripiego((ROOT / "WalkieTalkie/RadioManager.swift").read_text()))
    mac = ST_SWIFT.findall(_senza_ripiego((ROOT / "macTalky/Core/RadioManager.swift").read_text()))
    andr = ST_KT.findall((ROOT / "Android/app/src/main/java/com/immaginet/talky/radio/RadioManager.kt").read_text())
    return ios, mac, andr


def controlla_radio(prova_flussi):
    ios, mac, andr = stazioni()
    for nome, lista in (("iOS", ios), ("Mac", mac), ("Android", andr)):
        ids = [i for i, _, _ in lista]
        doppi = [i for i, n in Counter(ids).items() if n > 1]
        if doppi:
            err(f"radio {nome}: id doppi {doppi[:10]}")
        urls = [u for _, _, u in lista]
        doppi = [u for u, n in Counter(urls).items() if n > 1]
        if doppi:
            warn(f"radio {nome}: stesso flusso per piu' stazioni {doppi[:5]}")
        http = [n for _, n, u in lista if u.startswith("http://")]
        if http:
            warn(f"radio {nome}: {len(http)} flussi in http senza s, es. {http[:3]}")
    base = {(i, u) for i, _, u in ios}
    for nome, lista in (("Mac", mac), ("Android", andr)):
        altro = {(i, u) for i, _, u in lista}
        if base != altro:
            solo_ios = sorted(base - altro)[:5]
            solo_altro = sorted(altro - base)[:5]
            err(f"radio: elenco {nome} diverso da iOS ({len(lista)} contro {len(ios)}), "
                f"solo iOS {solo_ios}, solo {nome} {solo_altro}")
    if prova_flussi:
        prova_radio(ios)
    return len(ios)


def apre(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Talky/3.2 (audit)", "Icy-MetaData": "1"})
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            dati = r.read(2048)
            tipo = r.headers.get("Content-Type", "")
            return r.status, tipo, len(dati)
    except Exception as e:
        return None, type(e).__name__ + ": " + str(e)[:80], 0


def apre_curl(url):
    """Seconda prova con curl e lo user agent di AVPlayer: Python fallisce su
    alcuni TLS vecchi e su server lenti che il telefono apre senza problemi."""
    import subprocess
    r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-m", "15", "-r", "0-2047", "-A",
                        "AppleCoreMedia/1.0.0.22A3354 (iPhone; U; CPU OS 18_0 like Mac OS X)",
                        "-w", "%{http_code} %{content_type}", url], capture_output=True, text=True)
    codice, _, tipo = r.stdout.partition(" ")
    return (int(codice) if codice.isdigit() and codice != "000" else None), tipo, 1


def prova_radio(lista):
    morte = []

    def prova(s):
        esito = apre(s[2])
        if esito[0] is None or esito[0] >= 400 or esito[2] == 0:
            esito = apre_curl(s[2])
        return esito

    with cf.ThreadPoolExecutor(24) as pool:
        for (i, nome, url), (stato, tipo, n) in zip(lista, pool.map(prova, lista)):
            if stato is None or stato >= 400 or n == 0:
                morte.append((i, nome, url, stato, tipo))
            elif "text/html" in tipo:
                morte.append((i, nome, url, stato, "risponde una pagina web, non audio"))
    for i, nome, url, stato, tipo in morte:
        # Un 403 da qui puo' essere un blocco per paese (le ABC australiane):
        # StationHealth la nasconde da sola a chi non la sente, quindi e' un avviso.
        (warn if stato == 403 else err)(f"radio id {i} {nome!r}: non suona da qui ({stato} {tipo}) {url}")
    print(f"flussi radio provati: {len(lista)}, non funzionanti: {len(morte)}")


# ---------------------------------------------------------------- main

def main():
    controlla_traduzioni()
    controlla_testi_visibili()
    controlla_pubblicita()
    ios, mac = controlla_versioni()
    controlla_versioni_store(ios, mac)
    controlla_permessi()
    controlla_protocollo()
    n = controlla_radio("--radio" in sys.argv)
    print(f"versione iOS {ios}, Mac {mac}, stazioni {n}")
    for a in avvisi:
        print("AVVISO ", a)
    for e in errori:
        print("ERRORE ", e)
    print(f"\n{len(errori)} errori, {len(avvisi)} avvisi")
    sys.exit(1 if errori else 0)


if __name__ == "__main__":
    main()
