#!/usr/bin/env python3
"""Controllo delle schede App Store di Talky (iPhone e Mac) prima di un invio.

Ripete la lista dell'audit del 9 agosto 2026 (CLAUDE.md) piu' le regole del
3 novembre: ogni campo compilato, anche il facoltativo, schermate per ogni
formato e lingua, link legali sul dominio nostro. Legge la versione in
lavorazione se c'e', altrimenti quella in vendita, che la nuova eredita.

Uso:  python3 scripts/audit/scheda.py      (serve PyJWT, vedi asc.py)
"""
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asc import APP_ID, _get  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
errori, avvisi = [], []
MODIFICABILI = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}

# Parole tipiche di ogni lingua: se una descrizione non ne contiene nessuna,
# e' quasi certamente rimasta in un'altra lingua (zh-Hans in inglese, 9 ago).
SPIA = {
    "it": [" il ", " per ", " che "], "de-DE": [" und ", " der ", " die "], "es-ES": [" el ", " para ", " que "],
    "es-MX": [" el ", " para ", " que "], "fr-FR": [" le ", " pour ", " les "], "pt-BR": [" para ", " com ", " que "],
    "en-US": [" the ", " and ", " your "], "en-GB": [" the ", " and ", " your "], "tr": [" ve ", " bir ", " ile "],
    "ms": [" dan ", " anda ", " untuk "], "vi": [" và ", " của ", " cho "],
}
CJK = {"ja": r"[぀-ヿ]", "ko": r"[가-힯]", "zh-Hans": r"[一-鿿]",
       "zh-Hant": r"[一-鿿]", "th": r"[฀-๿]"}


def versione(piattaforma):
    vs = _get(f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]={piattaforma}&limit=20")["data"]
    for v in vs:
        if v["attributes"]["appStoreState"] in MODIFICABILI:
            return v
    for v in vs:
        if v["attributes"]["appStoreState"] == "READY_FOR_SALE":
            return v
    return None


def vivo(url):
    r = subprocess.run(["curl", "-s", "-o", "/dev/null", "-L", "-m", "15", "-w", "%{http_code}", url],
                       capture_output=True, text=True)
    return r.stdout.strip()


def stazioni_vere():
    testo = (ROOT / "WalkieTalkie/RadioManager.swift").read_text()
    return sum(1 for r in testo.splitlines() if "RadioStation(id:" in r and "??" not in r)


def controlla(piattaforma):
    v = versione(piattaforma)
    if not v:
        err(f"{piattaforma}: nessuna versione trovata")
        return
    a = v["attributes"]
    tag = f"{piattaforma} {a['versionString']} ({a['appStoreState']})"
    print("scheda", tag)
    if a.get("releaseType") != "AFTER_APPROVAL" and a["appStoreState"] in MODIFICABILI:
        err(f"{tag}: rilascio {a.get('releaseType')}, deve essere AFTER_APPROVAL")
    locs = _get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=50")["data"]
    n_vere = stazioni_vere()
    link_visti = {}
    formati_per_lingua = {}
    for l in locs:
        la = l["attributes"]
        loc = la["locale"]
        desc = la.get("description") or ""
        etichetta = f"{tag} {loc}"
        for campo in ("description", "keywords", "promotionalText", "supportUrl", "marketingUrl"):
            if not (la.get(campo) or "").strip():
                err(f"{etichetta}: campo {campo} vuoto")
        if a["appStoreState"] in MODIFICABILI and not (la.get("whatsNew") or "").strip():
            err(f"{etichetta}: manca il What's New")
        if "/terms" not in desc and "eula" not in desc.lower() and "stdeula" not in desc:
            err(f"{etichetta}: la descrizione non ha il link ai Termini (rifiuto 3.1.2)")
        if "privacy" not in desc.lower():
            err(f"{etichetta}: la descrizione non ha il link alla privacy")
        testo = " " + " ".join(filter(None, [desc, la.get("whatsNew"), la.get("keywords"), la.get("promotionalText")])).lower() + " "
        if re.search(r"android|google play|windows|linux", testo):
            err(f"{etichetta}: cita un'altra piattaforma (2.3.10): {re.findall(r'android|google play|windows|linux', testo)[:3]}")
        for n, piu in re.findall(r"(\d{3})\s*(\+?)\s*(?:live |internet |web )?(?:radio|station|stazion|emisora|sender|estaç|電台|电台|ラジオ|라디오|สถานี|istasyon|stesen|đài)", testo):
            # "Oltre 300", "300+", "more than 300" sono veri finche' le stazioni
            # sono almeno quelle: si segnala solo un numero piu' alto del vero.
            if int(n) > n_vere:
                err(f"{etichetta}: promette {n} stazioni, nell'app sono {n_vere}")
        if "—" in testo or "–" in testo:
            err(f"{etichetta}: lineetta lunga o media nel testo")
        if "immaginet s" in testo:
            err(f"{etichetta}: 'Immaginet Srl' nel testo")
        if loc in SPIA and not any(p in testo for p in SPIA[loc]):
            err(f"{etichetta}: la descrizione non sembra scritta in {loc}: {desc[:80]!r}")
        if loc in CJK and len(re.findall(CJK[loc], desc)) < 30:
            err(f"{etichetta}: la descrizione non sembra scritta in {loc}: {desc[:80]!r}")
        for campo in ("supportUrl", "marketingUrl"):
            u = la.get(campo) or ""
            if "vercel.app" in u or "github.io" in u:
                err(f"{etichetta}: {campo} su un dominio non nostro ({u})")
            if u and campo == "marketingUrl" and "andreapiani.com" not in u:
                err(f"{etichetta}: URL di marketing {u}, deve essere andreapiani.com (app-ads.txt)")
        for u in set(re.findall(r"https?://[^\s)\"'>]+", desc)) | {la.get("supportUrl") or "", la.get("marketingUrl") or ""}:
            if u:
                link_visti.setdefault(u.rstrip(".,;"), []).append(loc)
        sets = _get(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets?limit=50"
                    "&include=appScreenshots&fields[appScreenshots]=assetDeliveryState")
        formati = {}
        for s in sets["data"]:
            n = len(s["relationships"]["appScreenshots"]["data"])
            formati[s["attributes"]["screenshotDisplayType"]] = n
        formati_per_lingua[loc] = formati
        if not formati:
            err(f"{etichetta}: nessuna schermata")
        for f, n in formati.items():
            if n == 0:
                err(f"{etichetta}: formato {f} senza schermate")
    # Ogni lingua deve avere gli stessi formati delle altre (iPad mancante, ecc.).
    tutti = set().union(*formati_per_lingua.values()) if formati_per_lingua else set()
    for loc, formati in sorted(formati_per_lingua.items()):
        mancano = tutti - set(formati)
        if mancano:
            err(f"{tag} {loc}: mancano schermate {sorted(mancano)} che altre lingue hanno")
    print(f"  formati schermate: {sorted(tutti)}")
    if piattaforma == "IOS" and not any("IPAD" in f for f in tutti):
        err(f"{tag}: nessuna schermata iPad, l'app gira su iPad")
    for u, dove in sorted(link_visti.items()):
        c = vivo(u)
        if c != "200":
            err(f"{tag}: link {u} risponde {c} (in {len(dove)} lingue)")
        elif "vercel.app" in u:
            warn(f"{tag}: link {u} su vercel.app nella descrizione (in {len(dove)} lingue), meglio andreapiani.com")


def controlla_app_info():
    infos = _get(f"/v1/apps/{APP_ID}/appInfos")["data"]
    for info in infos:
        stato = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        locs = _get(f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50")["data"]
        for l in locs:
            la = l["attributes"]
            p = la.get("privacyPolicyUrl") or ""
            if not p:
                err(f"appInfo {stato} {la['locale']}: manca l'URL della privacy")
            elif "andreapiani.com" not in p:
                err(f"appInfo {stato} {la['locale']}: privacy su {p}, deve stare su andreapiani.com")
            if not (la.get("subtitle") or "").strip():
                err(f"appInfo {stato} {la['locale']}: sottotitolo vuoto")
        try:
            ar = _get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]["attributes"]
            if not ar.get("advertising"):
                err(f"appInfo {stato}: descrittore eta' 'advertising' non attivo, l'app ha AdMob")
            # Facoltative: fascia Kids, numero GRAC coreano, URL informativo.
            facoltative = {"kidsAgeBand", "gracRatingClassificationNumber", "developerAgeRatingInfoUrl",
                           "koreaAgeRatingOverride", "ageRatingOverride", "ageRatingOverrideV2"}
            vuoti = [k for k, v in ar.items() if v is None]
            obbl = [k for k in vuoti if k not in facoltative]
            if obbl:
                warn(f"appInfo {stato}: domande del questionario eta' senza risposta {obbl}, "
                     "se Apple le rende obbligatorie l'invio si ferma con 409 (successo con socialMedia il 2/11)")
        except Exception as e:
            warn(f"appInfo {stato}: questionario eta' non letto ({e})")


def controlla_app_ads():
    import hashlib
    hashes = {}
    for h in ("www.andreapiani.com", "privacypolicyhub.vercel.app", "walkie-talky.vercel.app"):
        r = subprocess.run(["curl", "-sfL", "-m", "15", f"https://{h}/app-ads.txt"], capture_output=True)
        hashes[h] = hashlib.md5(r.stdout).hexdigest() if r.returncode == 0 else "assente"
    if len(set(hashes.values())) != 1:
        err(f"app-ads.txt non identico sui tre domini: {hashes}")


def err(m):
    errori.append(m)


def warn(m):
    avvisi.append(m)


if __name__ == "__main__":
    for p in ("IOS", "MAC_OS"):
        controlla(p)
    controlla_app_info()
    controlla_app_ads()
    for a in avvisi:
        print("AVVISO ", a)
    for e in errori:
        print("ERRORE ", e)
    print(f"\n{len(errori)} errori, {len(avvisi)} avvisi")
    sys.exit(1 if errori else 0)
