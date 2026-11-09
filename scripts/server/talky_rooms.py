#!/usr/bin/env python3
# creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - talky_rooms.py
#
# Custode delle stanze private di Talky sul mumble-server della VM2.
#
# Chi entra in Mumble senza registrarsi non puo' mettere un codice a un canale,
# quindi lo fa questo processo, collegato come SuperUser:
#   - all'avvio scrive le regole del canale radice (si entra, non si parla,
#     non si scrive, non si ascolta a distanza, non si creano canali) e del
#     canale "Talky" dove sta lui; le stanze che non conosce o con regole
#     diverse da quelle di adesso le cancella;
#   - Talky gli manda in privato "room <token>": il custode sceglie lui un nome
#     a caso per il canale, ci mette @all fuori e il gruppo #<token> dentro,
#     controlla che il server le abbia davvero applicate e solo allora risponde
#     "ok <nome>". Il nome non si ricava dal codice, quindi chi vede l'albero
#     dei canali non ha niente da provare a indovinare;
#   - le stanze vuote da piu' di 24 ore le toglie dal server, ma ne tiene
#     l'impronta: chi torna con lo stesso codice ritrova lo stesso nome e le
#     notifiche Push to Talk gia' registrate;
#   - Push to Talk: un iPhone Pro gli lascia il gettone APNs della stanza
#     ("ptt ..."), e quando qualcuno comincia a parlare ("talk ...") manda
#     la notifica pushtotalk a chi della stanza non e' collegato adesso,
#     cosi' iOS sveglia Talky anche chiusa e mostra chi parla.
# Il token arriva solo a lui (messaggio a una sessione), mai in un canale, e
# nello stato si salva solo la sua impronta.
#
# Solo libreria standard. La password di SuperUser arriva dall'ambiente
# (TALKY_MUMBLE_SUPERUSER_PASSWORD), mai da questo file: il repo e' pubblico.

import collections
import hashlib
import json
import os
import re
import secrets
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time

HOST = os.environ.get("TALKY_MUMBLE_LOCAL_HOST", "127.0.0.1")
PORT = int(os.environ.get("TALKY_MUMBLE_INTERNAL_PORT", "64738"))
PASSWORD = os.environ["TALKY_MUMBLE_SUPERUSER_PASSWORD"]
STATE = os.environ.get("TALKY_ROOMS_STATE", "/var/lib/talky-rooms/rooms.json")
STATE_VERSION = 2
IDLE_SECONDS = 24 * 3600
FORGET_SECONDS = 30 * 24 * 3600
HOME = "Talky"
ROOM_NAME = re.compile(r"^room-[0-9a-f]{16}$")
TOKEN = re.compile(r"^[0-9a-f]{32}$")
PUSH_TOKEN = re.compile(r"^[0-9a-f]{32,200}$")
# Nomi Unicode come li accetta il server (deploy_rooms.sh): niente spazi, niente < >.
NICK = re.compile(r"^[^\s<>]{1,64}$")
PTT_PER_ROOM = 30
PTT_TTL = 7 * 24 * 3600
PTT_GAP = 15
PENDING_SECONDS = 15
MAX_ROOMS = 1000
# Per sessione: chi prova codici a raffica si ferma qui, e un nuovo
# collegamento costa all'autoban del server.
ROOM_ASKS_PER_MINUTE = 10
NEW_ROOMS_PER_HOUR = 5
OTHER_PER_MINUTE = 40
# Il server scarta in silenzio i messaggi oltre messagelimit/messageburst
# (deploy_rooms.sh li mette a 10 e 40): il custode resta sotto.
SEND_PER_SECOND = 6
SEND_BURST = 20

# APNs: la chiave del team (RF29RR7SKM, in ~/.secrets), passata da systemd
# con LoadCredential. Senza chiave le stanze funzionano lo stesso, senza notifiche.
APNS_KEY = os.environ.get("APNS_KEY_PATH", "")
APNS_KEY_ID = os.environ.get("APNS_KEY_ID", "")
APNS_TEAM = os.environ.get("APNS_TEAM_ID", "")
APNS_TOPIC = "com.Andrea-Piani.WalkieTalkie.voip-ptt"
# Solo queste risposte vogliono dire "gettone da buttare"; un 400 per un
# errore di configurazione (BadTopic, InvalidPushType) non cancella niente.
APNS_DEAD = {"BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered", "ExpiredToken"}


def log(*a):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *a, flush=True)


class Pusher:
    """Notifiche pushtotalk, una richiesta HTTP/2 per gettone con curl."""

    def __init__(self):
        self.jwt = None
        self.minted = 0
        self.dead = collections.deque()   # gettoni che APNs dice non validi, li toglie il ciclo principale
        try:
            import jwt  # python3-jwt
            self.lib = jwt
            self.key = open(APNS_KEY).read() if APNS_KEY else None
        except (ImportError, OSError):
            self.lib = None
            self.key = None

    @property
    def ready(self):
        return bool(self.lib and self.key and APNS_KEY_ID and APNS_TEAM)

    def bearer(self):
        # APNs vuole un gettone fra 20 e 60 minuti di vita: si rifa' ogni 40.
        if not self.jwt or time.time() - self.minted > 2400:
            self.minted = int(time.time())
            self.jwt = self.lib.encode({"iss": APNS_TEAM, "iat": self.minted}, self.key,
                                       algorithm="ES256", headers={"kid": APNS_KEY_ID})
        return self.jwt

    def send(self, token, env, speaker):
        if not self.ready:
            return
        host = "api.sandbox.push.apple.com" if env == "sandbox" else "api.push.apple.com"
        body = json.dumps({"aps": {}, "activeSpeaker": speaker})
        cmd = ["curl", "-s", "-o", "-", "-w", "\n%{http_code}", "--http2", "-m", "10",
               "-H", "authorization: bearer " + self.bearer(),
               "-H", "apns-topic: " + APNS_TOPIC, "-H", "apns-push-type: pushtotalk",
               "-H", "apns-priority: 10", "-H", "apns-expiration: 0",
               "-d", body, "https://%s/3/device/%s" % (host, token)]

        def run():
            try:
                out = subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout
            except (OSError, subprocess.SubprocessError):
                return
            text, _, code = out.rpartition("\n")
            if code == "200":
                return
            try:
                reason = json.loads(text).get("reason", "") if text.strip() else ""
            except ValueError:
                reason = ""
            if code == "410" or reason in APNS_DEAD:
                self.dead.append(token)
            log("apns", code, reason, token[:8])

        threading.Thread(target=run, daemon=True).start()


# src/ACL.h
WRITE, TRAVERSE, ENTER, SPEAK = 0x1, 0x2, 0x4, 0x8
MAKE_CHANNEL, WHISPER, TEXT, MAKE_TEMP, LISTEN = 0x40, 0x100, 0x200, 0x400, 0x800
REGISTER, SELF_REGISTER = 0x40000, 0x80000
ROOM_INSIDE = TRAVERSE | ENTER | SPEAK | WHISPER | TEXT | LISTEN
ROOM_SHUT = ENTER | SPEAK | WHISPER | TEXT | LISTEN | MAKE_CHANNEL | MAKE_TEMP

VERSION, UDP_TUNNEL, AUTH, PING, REJECT, SYNC = 0, 1, 2, 3, 4, 5
CH_REMOVE, CH_STATE, USER_REMOVE, USER_STATE, TEXT_MSG, ACL = 6, 7, 8, 9, 11, 13
# Messaggi che il server conta nel suo limite (RATELIMIT in Messages.cpp).
LIMITED = {CH_STATE, USER_STATE, TEXT_MSG, ACL}


# --- protobuf a mano, solo quello che serve ---

def varint(v):
    out = bytearray()
    while v >= 0x80:
        out.append((v & 0x7F) | 0x80)
        v >>= 7
    out.append(v)
    return bytes(out)


def f_int(n, v):
    return varint(n << 3) + varint(v)


def f_bytes(n, b):
    return varint(n << 3 | 2) + varint(len(b)) + b


def f_str(n, s):
    return f_bytes(n, s.encode())


def parse(b):
    out, i = {}, 0

    def rv():
        nonlocal i
        v = shift = 0
        while True:
            x = b[i]
            i += 1
            v |= (x & 0x7F) << shift
            if not x & 0x80:
                return v
            shift += 7

    while i < len(b):
        key = rv()
        f, w = key >> 3, key & 7
        if w == 0:
            out.setdefault(f, []).append(rv())
        elif w == 2:
            n = rv()
            if i + n > len(b):
                raise ValueError("campo troncato")
            out.setdefault(f, []).append(b[i:i + n])
            i += n
        elif w == 1:
            out.setdefault(f, []).append(b[i:i + 8])
            i += 8
        elif w == 5:
            out.setdefault(f, []).append(b[i:i + 4])
            i += 4
        else:
            raise ValueError("wire type")
    return out


def first(m, f, default=None):
    v = m.get(f)
    return v[-1] if v else default


def chan_acl(group, grant, deny, here=True, subs=True):
    # inherited (campo 3) a 0 esplicito: il server oggi non lo legge, ma il
    # .proto lo vuole vero per default e un server futuro potrebbe scartarle.
    return (f_int(1, int(here)) + f_int(2, int(subs)) + f_int(3, 0) + f_str(5, group)
            + f_int(6, grant) + f_int(7, deny))


def sha(token):
    return hashlib.sha256(token.encode()).hexdigest()


def room_rules_ok(m, fingerprint):
    """Risposta a una richiesta ACL: le regole della stanza ci sono tutte?"""
    if first(m, 2, 1) != 0:          # inherit_acls: deve essere spento
        return False
    shut = inside = False
    for raw in m.get(4, []):
        a = parse(raw)
        if first(a, 3, 1):           # ereditata da un genitore
            continue
        group = first(a, 5, b"").decode(errors="replace")
        grant, deny = first(a, 6, 0), first(a, 7, 0)
        if group == "all" and deny & ROOM_SHUT == ROOM_SHUT and not grant & ROOM_SHUT:
            shut = True
        elif group.startswith("#") and sha(group[1:]) == fingerprint and grant & ROOM_INSIDE == ROOM_INSIDE:
            inside = shut   # vale solo se viene dopo la chiusura
    return shut and inside


class Rooms:
    def __init__(self):
        self.sock = None
        self.buf = b""
        self.session = None
        self.channels = {}   # id -> {"name", "parent"}
        self.users = {}      # session -> {"ch": canale, "name": nome}
        self.home = None
        self.rooms = {}      # impronta del token -> {"name", "seen", "ptt"}
        data = self.load()
        if data.get("v") == STATE_VERSION:
            self.rooms = data.get("rooms", {})
        else:
            # Stato di prima del 9/11 sera: stanze col nome ricavato dal codice
            # e senza Listen negato. Si ripartono da zero, quelle sul server
            # le toglie il primo collegamento.
            log("stato vecchio, stanze dimenticate:", len(data.get("seen", data)))
            if data:
                self.save()
        self.pusher = Pusher()
        self.pushed = {}     # gettone -> ultima notifica
        self.pending = {}    # impronta -> {"name", "token", "waiters", "ts", "cid", "checks"}
        self.asks = collections.defaultdict(collections.deque)   # (sessione, tipo) -> istanti
        self.outq = collections.deque()
        self.allowance = SEND_BURST
        self.last_fill = time.time()
        self.checking = {}   # canale -> impronta, controlli delle stanze gia' note
        self.synced = False
        self.dirty = False

    def load(self):
        try:
            with open(STATE) as fh:
                return json.load(fh)
        except (OSError, ValueError):
            return {}

    def save(self):
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        tmp = STATE + ".tmp"
        with open(tmp, "w") as fh:
            json.dump({"v": STATE_VERSION, "rooms": self.rooms}, fh)
        os.replace(tmp, STATE)
        self.dirty = False

    # --- invio ---

    def send_now(self, kind, body):
        self.sock.sendall(struct.pack(">HI", kind, len(body)) + body)

    def send(self, kind, body):
        if kind in LIMITED:
            self.outq.append((kind, body))
            self.flush()
        else:
            self.send_now(kind, body)

    def flush(self):
        now = time.time()
        self.allowance = min(SEND_BURST, self.allowance + (now - self.last_fill) * SEND_PER_SECOND)
        self.last_fill = now
        while self.outq and self.allowance >= 1:
            self.allowance -= 1
            self.send_now(*self.outq.popleft())

    def tell(self, session, text):
        self.send(TEXT_MSG, f_int(2, session) + f_str(5, text))

    def connect(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection((HOST, PORT), timeout=10)
        self.sock = ctx.wrap_socket(raw)
        self.sock.settimeout(0.2)
        v = (1 << 16) | (5 << 8)
        self.send_now(VERSION, f_int(1, v) + f_str(2, "talky-rooms") + f_str(3, "Linux") + f_int(5, (1 << 48) | (5 << 32)))
        self.send_now(AUTH, f_str(1, "SuperUser") + f_str(2, PASSWORD) + f_int(5, 1))

    def frames(self):
        try:
            chunk = self.sock.recv(65536)
        except socket.timeout:
            return []
        if not chunk:
            raise ConnectionError("chiuso")
        self.buf += chunk
        out = []
        while len(self.buf) >= 6:
            kind, n = struct.unpack(">HI", self.buf[:6])
            if len(self.buf) < 6 + n:
                break
            out.append((kind, self.buf[6:6 + n]))
            self.buf = self.buf[6 + n:]
        return out

    # --- regole ---

    def write_root_rules(self):
        # Nel canale radice si entra e si passa, ma non si parla, non si
        # scrive, non si ascolta a distanza e non si creano canali.
        acls = chan_acl("all", TRAVERSE | ENTER,
                        SPEAK | WHISPER | TEXT | LISTEN | MAKE_CHANNEL | MAKE_TEMP | REGISTER | SELF_REGISTER)
        self.send(ACL, f_int(1, 0) + f_int(2, 0) + f_bytes(4, acls))

    def write_home_rules(self, cid):
        # Il canale del custode: gli si puo' scrivere in privato, non ci si entra.
        acls = chan_acl("all", TRAVERSE | TEXT, ENTER | SPEAK | WHISPER | LISTEN)
        self.send(ACL, f_int(1, cid) + f_int(2, 0) + f_bytes(4, acls))

    def write_room_rules(self, cid, token):
        closed = chan_acl("all", TRAVERSE, ROOM_SHUT)
        inside = chan_acl("#" + token, ROOM_INSIDE, 0)
        self.send(ACL, f_int(1, cid) + f_int(2, 0) + f_bytes(4, closed) + f_bytes(4, inside))

    def ask_rules(self, cid):
        self.send(ACL, f_int(1, cid) + f_int(5, 1))

    def by_name(self, name):
        for cid, c in self.channels.items():
            if c["name"] == name and c["parent"] == 0:
                return cid
        return None

    def room_of_name(self, name):
        for fp, r in self.rooms.items():
            if r["name"] == name:
                return fp
        return None

    def create(self, name):
        # ChannelState: parent 2, name 3; senza channel_id vuol dire "crea".
        self.send(CH_STATE, f_int(2, 0) + f_str(3, name))

    def remove(self, cid):
        self.send_now(CH_REMOVE, f_int(1, cid))

    # --- messaggi ---

    def on_frame(self, kind, body):
        if kind in (PING, UDP_TUNNEL):
            return
        m = parse(body)
        if kind == REJECT:
            raise ConnectionError("rifiutato: %s" % first(m, 2, b"").decode(errors="replace"))
        if kind == SYNC:
            self.session = first(m, 1)
            self.synced = True
            self.write_root_rules()
            self.home = self.by_name(HOME)
            if self.home is None:
                self.create(HOME)
            else:
                self.enter_home()
            self.audit_rooms()
            log("collegato, sessione", self.session, "canali", len(self.channels), "stanze", len(self.rooms))
        elif kind == CH_STATE:
            cid = first(m, 1)
            if cid is None:
                return
            c = self.channels.setdefault(cid, {"name": "", "parent": None})
            if 2 in m:
                c["parent"] = first(m, 2)
            if 3 in m:
                c["name"] = first(m, 3).decode(errors="replace")
            if self.synced and c["name"] == HOME and self.home is None:
                self.home = cid
                self.enter_home()
            for fp, p in self.pending.items():
                if p["cid"] is None and p["name"] == c["name"] and c["parent"] == 0:
                    p["cid"] = cid
                    self.write_room_rules(cid, p["token"])
                    self.ask_rules(cid)
                    break
        elif kind == CH_REMOVE:
            self.channels.pop(first(m, 1), None)
        elif kind == USER_STATE:
            s = first(m, 1)
            if s is not None:
                u = self.users.setdefault(s, {"ch": 0, "name": ""})
                if 3 in m:
                    u["name"] = first(m, 3).decode(errors="replace")
                if 5 in m:
                    u["ch"] = first(m, 5)
                    self.touch_channel(u["ch"])
        elif kind == USER_REMOVE:
            s = first(m, 1)
            self.users.pop(s, None)
            for key in [k for k in self.asks if k[0] == s]:
                self.asks.pop(key, None)
        elif kind == TEXT_MSG:
            self.on_text(first(m, 1), first(m, 5, b"").decode(errors="replace"))
        elif kind == ACL:
            self.on_rules(first(m, 1), m)

    def enter_home(self):
        self.write_home_rules(self.home)
        self.send(USER_STATE, f_int(1, self.session) + f_int(5, self.home))

    def touch_channel(self, cid):
        name = self.channels.get(cid, {}).get("name", "")
        fp = self.room_of_name(name) if ROOM_NAME.match(name) else None
        if fp:
            self.rooms[fp]["seen"] = time.time()
            self.dirty = True

    def audit_rooms(self):
        # Stanze sul server che lo stato non conosce: nate col protocollo di
        # prima (nome dal codice, Listen aperto) o da altri. Si tolgono. Le
        # altre si ricontrollano: se le regole non sono quelle di adesso, via.
        known = {r["name"]: fp for fp, r in self.rooms.items()}
        for cid, c in list(self.channels.items()):
            if c["parent"] != 0 or not ROOM_NAME.match(c["name"]):
                continue
            fp = known.get(c["name"])
            if fp is None:
                self.remove(cid)
                log("stanza sconosciuta tolta", c["name"])
            else:
                self.checking[cid] = fp
                self.ask_rules(cid)

    def on_rules(self, cid, m):
        for fp, p in list(self.pending.items()):
            if p["cid"] != cid:
                continue
            if room_rules_ok(m, fp):
                old = self.rooms.get(fp, {})
                self.rooms[fp] = {"name": p["name"], "seen": time.time(), "ptt": old.get("ptt", {})}
                self.save()
                for w in p["waiters"]:
                    self.tell(w, "ok " + p["name"])
                del self.pending[fp]
                log("stanza pronta", p["name"])
            elif p["checks"] < 2:
                p["checks"] += 1
                self.write_room_rules(cid, p["token"])
                self.ask_rules(cid)
            else:
                self.remove(cid)
                for w in p["waiters"]:
                    self.tell(w, "no")
                del self.pending[fp]
                log("regole non applicate, stanza tolta", p["name"])
            return
        fp = self.checking.pop(cid, None)
        if fp and not room_rules_ok(m, fp):
            name = self.rooms.pop(fp, {}).get("name")
            self.remove(cid)
            self.save()
            log("stanza con regole vecchie tolta", name)

    def allowed(self, actor, kind, limit, window):
        q = self.asks[(actor, kind)]
        now = time.time()
        while q and now - q[0] > window:
            q.popleft()
        if len(q) >= limit:
            return False
        q.append(now)
        return True

    def on_text(self, actor, text):
        if actor is None:
            return
        parts = re.sub(r"<[^>]+>", "", text).strip().split()
        if len(parts) < 2 or not TOKEN.match(parts[1]):
            return
        verb = parts[0]
        if verb == "room" and len(parts) == 2:
            if not self.allowed(actor, "room", ROOM_ASKS_PER_MINUTE, 60):
                self.tell(actor, "slow")
                return
            self.on_room(actor, parts[1])
            return
        if not self.allowed(actor, "other", OTHER_PER_MINUTE, 60):
            return
        if verb == "ptt" and len(parts) == 5:
            self.on_ptt(*parts[1:])
        elif verb == "talk" and len(parts) == 3:
            self.on_talk(*parts[1:])

    def on_room(self, actor, token):
        fp = sha(token)
        if fp in self.pending:
            self.pending[fp]["waiters"].add(actor)
            return
        room = self.rooms.get(fp)
        if room and self.by_name(room["name"]) is not None:
            room["seen"] = time.time()
            self.dirty = True
            self.tell(actor, "ok " + room["name"])
            return
        if room is None:
            if len(self.rooms) + len(self.pending) >= MAX_ROOMS or \
                    not self.allowed(actor, "new", NEW_ROOMS_PER_HOUR, 3600):
                self.tell(actor, "no")
                return
            name = "room-" + secrets.token_hex(8)
            while self.by_name(name) is not None or self.room_of_name(name):
                name = "room-" + secrets.token_hex(8)
        else:
            name = room["name"]   # tolta dallo sweep: torna con lo stesso nome
        self.pending[fp] = {"name": name, "token": token, "waiters": {actor},
                            "ts": time.time(), "cid": None, "checks": 0}
        self.create(name)

    def on_ptt(self, token, push, env, nick):
        if not (PUSH_TOKEN.match(push) and env in ("sandbox", "production") and NICK.match(nick)):
            return
        room = self.rooms.get(sha(token))
        if room is None:
            return
        ptt = room.setdefault("ptt", {})
        ptt[push] = {"env": env, "nick": nick, "ts": time.time()}
        if len(ptt) > PTT_PER_ROOM:
            for old in sorted(ptt, key=lambda k: ptt[k]["ts"])[:len(ptt) - PTT_PER_ROOM]:
                ptt.pop(old)
        room["seen"] = time.time()
        self.save()

    def on_talk(self, token, nick):
        room = self.rooms.get(sha(token))
        if room is None or not NICK.match(nick):
            return
        cid = self.by_name(room["name"])
        if cid is None:
            return
        room["seen"] = time.time()
        self.dirty = True
        here = {u["name"] for u in self.users.values() if u["ch"] == cid}
        now = time.time()
        for push, info in list(room.get("ptt", {}).items()):
            # A chi e' gia' nella stanza la voce arriva da Mumble.
            if info["nick"] == nick or info["nick"] in here:
                continue
            if now - self.pushed.get(push, 0) < PTT_GAP:
                continue
            self.pushed[push] = now
            self.pusher.send(push, info["env"], nick)

    def expire_pending(self):
        now = time.time()
        for fp, p in list(self.pending.items()):
            if now - p["ts"] < PENDING_SECONDS:
                continue
            if p["cid"] is not None:
                self.remove(p["cid"])
            for w in p["waiters"]:
                self.tell(w, "no")
            del self.pending[fp]
            log("stanza non nata in tempo", p["name"])

    def sweep(self):
        now = time.time()
        dead = set()
        while self.pusher.dead:
            dead.add(self.pusher.dead.popleft())
        occupied = {u["ch"] for u in self.users.values()}
        on_server = {c["name"]: cid for cid, c in self.channels.items() if c["parent"] == 0}
        for fp, room in list(self.rooms.items()):
            ptt = room.setdefault("ptt", {})
            for push in [k for k, v in ptt.items() if now - v["ts"] > PTT_TTL or k in dead]:
                ptt.pop(push)
                self.dirty = True
            cid = on_server.get(room["name"])
            if cid is not None and cid in occupied:
                room["seen"] = now
                self.dirty = True
            elif cid is not None and now - room["seen"] > IDLE_SECONDS:
                # Via dal server, ma l'impronta resta: lo stesso codice
                # ritrova lo stesso nome e le stesse notifiche.
                self.remove(cid)
                self.dirty = True
                log("stanza vuota tolta dal server", room["name"])
            elif cid is None and now - room["seen"] > FORGET_SECONDS:
                del self.rooms[fp]
                self.dirty = True
                log("stanza dimenticata", room["name"])
        self.pushed = {k: v for k, v in self.pushed.items() if now - v < PTT_GAP}
        if self.dirty:
            self.save()

    def run(self):
        self.connect()
        last_ping = last_sweep = time.time()
        while True:
            for kind, body in self.frames():
                try:
                    self.on_frame(kind, body)
                except ConnectionError:
                    raise
                except Exception as e:  # un messaggio storto non fa cadere il custode
                    log("messaggio %d scartato: %s" % (kind, e))
            self.flush()
            now = time.time()
            if now - last_ping > 15:
                self.send_now(PING, f_int(1, int(now * 1000)))
                last_ping = now
            if self.synced:
                self.expire_pending()
                if now - last_sweep > 600:
                    self.sweep()
                    last_sweep = now


if __name__ == "__main__":
    while True:
        try:
            Rooms().run()
        except Exception as e:  # il server riparte, il custode lo segue
            log("errore:", e)
            time.sleep(5)
    sys.exit(0)
