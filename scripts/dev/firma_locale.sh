#!/bin/bash
# creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - firma_locale.sh
#
# Firma a mano una build Debug compilata con CODE_SIGNING_ALLOWED=NO, per
# installarla sull'iPhone o sul Mac di Andrea. Serve perche' su questo Mac
# Xcode non ha un account Apple: la firma automatica non sa aggiungere ai
# profili App Group e Push to Talk, e forzare un profilo da riga di comando
# lo applica anche ai pacchetti Firebase, che lo rifiutano.
# I profili "Talky iOS Dev <bundle>" e "Talky Mac Dev <bundle>" li crea
# l'API di App Store Connect (vedi CLAUDE.md del progetto, Firma locale).
#   scripts/dev/firma_locale.sh ios /percorso/Talky.app
#   scripts/dev/firma_locale.sh mac /percorso/Talky.app
set -euo pipefail
KIND=$1
APP=$2
IDENTITY=${TALKY_SIGN_IDENTITY:-"Apple Development: Andrea Piani"}
PROFILES=~/Library/Developer/Xcode/UserData/Provisioning\ Profiles
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ "$KIND" = ios ]; then PREFIX="Talky iOS Dev"; EXT=mobileprovision; else PREFIX="Talky Mac Dev"; EXT=provisionprofile; fi

# Il profilo piu' recente con quel nome, per bundle id.
profile_for() {
  local want="$PREFIX $1"
  while IFS= read -r p; do
    security cms -D -i "$p" > "$WORK/p.plist" 2>/dev/null || continue
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :Name' "$WORK/p.plist")" = "$want" ]; then echo "$p"; return; fi
  done < <(ls -t "$PROFILES"/*.$EXT)
  echo "manca il profilo \"$want\"" >&2
  exit 1
}

# Entitlement di firma: quelli che il target chiede, piu' quelli d'identita'
# che solo il profilo conosce (application-identifier, team, get-task-allow).
entitlements_for() {
  local bundle=$1 requested=$2 out=$3 profile
  profile=$(profile_for "$bundle")
  security cms -D -i "$profile" > "$WORK/prof.plist"
  /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' "$WORK/prof.plist" > "$WORK/pe.plist"
  python3 - "$WORK/pe.plist" "$requested" "$out" "$KIND" <<'PY'
import plistlib, sys
prof = plistlib.load(open(sys.argv[1], "rb"))
req = plistlib.load(open(sys.argv[2], "rb")) if sys.argv[2] != "-" else {}
kind = sys.argv[4]
keep = ["application-identifier", "com.apple.application-identifier", "com.apple.developer.team-identifier",
        "get-task-allow", "com.apple.security.get-task-allow"]
out = {k: prof[k] for k in keep if k in prof}
for k, v in req.items():
    if k == "aps-environment" and kind == "mac":
        out["com.apple.developer.aps-environment"] = v
    else:
        out[k] = v
plistlib.dump(out, open(sys.argv[3], "wb"))
PY
  cp "$profile" "$4"
}

sign() {
  if [ "$KIND" = mac ]; then
    codesign --force --timestamp=none --options runtime --generate-entitlement-der --sign "$IDENTITY" "$@"
  else
    codesign --force --timestamp=none --generate-entitlement-der --sign "$IDENTITY" "$@"
  fi
}

if [ "$KIND" = ios ]; then
  ROOT="$APP"; PLUG="$APP/PlugIns"; FW="$APP/Frameworks"; EMB=embedded.mobileprovision
  ROOT_ENT=Talky-iOS.entitlements
else
  ROOT="$APP/Contents"; PLUG="$APP/Contents/PlugIns"; FW="$APP/Contents/Frameworks"; EMB=embedded.provisionprofile
  ROOT_ENT=Talky-Mac.entitlements
fi
REPO=$(cd "$(dirname "$0")/../.." && pwd)

# Prima le librerie, poi le estensioni, per ultima l'app: si firma dall'interno.
find "$APP" -maxdepth 4 \( -name "*.dylib" -o -name "*.framework" \) | while read -r lib; do sign "$lib"; done
if [ -d "$PLUG" ]; then
  for appex in "$PLUG"/*.appex; do
    plist="$appex/Info.plist"; [ "$KIND" = mac ] && plist="$appex/Contents/Info.plist"
    b=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
    case "$b" in
      *.LiveActivities) req="$REPO/TalkyLiveActivities.entitlements" ;;
      *.MacWidgets) req="$REPO/TalkyMacWidgets.entitlements" ;;
      *) req="-" ;;
    esac
    dest="$appex/$EMB"; [ "$KIND" = mac ] && dest="$appex/Contents/$EMB"
    entitlements_for "$b" "$req" "$WORK/appex.plist" "$dest"
    if [ "$KIND" = mac ]; then
      # Sul Mac la sandbox e le reti vengono dalle impostazioni del target, non dal file.
      /usr/libexec/PlistBuddy -c 'Add :com.apple.security.app-sandbox bool true' "$WORK/appex.plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c 'Add :com.apple.security.network.client bool true' "$WORK/appex.plist" 2>/dev/null || true
    fi
    sign --entitlements "$WORK/appex.plist" "$appex"
  done
fi
b=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/Info.plist")
entitlements_for "$b" "$REPO/$ROOT_ENT" "$WORK/app.plist" "$ROOT/$EMB"
if [ "$KIND" = mac ]; then
  for k in app-sandbox network.client network.server device.audio-input; do
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.$k bool true" "$WORK/app.plist" 2>/dev/null || true
  done
fi
sign --entitlements "$WORK/app.plist" "$APP"
codesign --verify --deep --strict "$APP" && echo "firmata: $APP"
