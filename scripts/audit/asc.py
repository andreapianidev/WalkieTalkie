"""Lettura minima da App Store Connect per l'audit: quali versioni sono in vendita.

Le chiavi non stanno nel repo. Si leggono dalle variabili ASC_KEY_ID,
ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH, oppure dal file indicato da ASC_ENV_FILE
(predefinito ~/.secrets/appstoreconnect-api.env). Serve PyJWT con cryptography.
"""
import json
import os
import time
import urllib.request
from pathlib import Path

import jwt

APP_ID = "6748584483"


def _config():
    cfg = {k: os.environ[k] for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_PATH") if k in os.environ}
    if len(cfg) < 3:
        env = Path(os.environ.get("ASC_ENV_FILE", "~/.secrets/appstoreconnect-api.env")).expanduser()
        for riga in env.read_text().splitlines():
            if "=" in riga and not riga.lstrip().startswith("#"):
                k, v = riga.split("=", 1)
                cfg.setdefault(k.strip(), v.strip().strip("'\""))
    return cfg


def _get(path):
    cfg = _config()
    key = Path(cfg["ASC_PRIVATE_KEY_PATH"]).expanduser().read_text()
    now = int(time.time())
    tok = jwt.encode({"iss": cfg["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                     key, algorithm="ES256", headers={"kid": cfg["ASC_KEY_ID"], "typ": "JWT"})
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
                                 headers={"Authorization": "Bearer " + tok})
    return json.load(urllib.request.urlopen(req, timeout=30))


def versioni_in_vendita():
    dati = _get(f"/v1/apps/{APP_ID}/appStoreVersions?limit=200&fields[appStoreVersions]=versionString,platform,appStoreState")
    out = {}
    for v in dati["data"]:
        a = v["attributes"]
        if a["appStoreState"] in ("READY_FOR_SALE", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE",
                                  "DEVELOPER_REMOVED_FROM_SALE"):
            out.setdefault(a["platform"], set()).add(a["versionString"])
    return out
