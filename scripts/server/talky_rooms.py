#!/usr/bin/env python3
# creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - talky_rooms.py
#
# Custode delle stanze private di Talky sul mumble-server della VM2.
#
# Chi entra in Mumble senza registrarsi non puo' mettere un codice a un canale,
# quindi lo fa questo processo, collegato come SuperUser:
#   - all'avvio scrive le regole del canale radice (si entra, non si parla,
#     non si scrive, non si creano canali) e del canale "Talky" dove sta lui;
#   - Talky gli manda in privato "room <nome> <token>": se la stanza non c'e'
#     la crea, con @all fuori e il gruppo #<token> dentro;
#   - le stanze vuote da piu' di 24 ore le cancella;
#   - Push to Talk: un iPhone Pro gli lascia il gettone APNs della stanza
#     ("ptt ..."), e quando qualcuno comincia a parlare ("talk ...") manda
#     la notifica pushtotalk a chi della stanza non e' collegato adesso,
#     cosi' iOS sveglia Talky anche chiusa e mostra chi parla.
# Il token arriva solo a lui (messaggio a una sessione), mai in un canale.
#
# Solo libreria standard. La password di SuperUser arriva dall'ambiente
# (TALKY_MUMBLE_SUPERUSER_PASSWORD), mai da questo file: il repo e' pubblico.

import hashlib
import json
import os
import subprocess
import threading
import re
import socket
import ssl
import struct
import sys
import time

HOST = os.environ.get("TALKY_MUMBLE_LOCAL_HOST", "127.0.0.1")
PORT = int(os.environ.get("TALKY_MUMBLE_INTERNAL_PORT", "64738"))
PASSWORD = os.environ["TALKY_MUMBLE_SUPERUSER_PASSWORD"]
STATE = os.environ.get("TALKY_ROOMS_STATE", "/var/lib/talky-rooms/rooms.json")
IDLE_SECONDS = 24 * 3600
HOME = "Talky"
ROOM_NAME = re.compile(r"^room-[0-9a-f]{16}$")
TOKEN = re.compile(r"^[0-9a-f]{32}$")
PUSH_TOKEN = re.compile(r"^[0-9a-f]{32,200}$")
NICK = re.compile(r"^[\w-]{1,24}$")
PTT_PER_ROOM = 30
PTT_TTL = 7 * 24 * 3600
PTT_GAP = 15

# APNs: la chiave del team (RF29RR7SKM, in ~/.secrets), passata da systemd
# con LoadCredential. Senza chiave le stanze funzionano lo stesso, senza notifiche.
APNS_KEY = os.environ.get("APNS_KEY_PATH", "")
APNS_KEY_ID = os.environ.get("APNS_KEY_ID", "")
APNS_TEAM = os.environ.get("APNS_TEAM_ID", "")
APNS_TOPIC = "com.Andrea-Piani.WalkieTalkie.voip-ptt"


class Pusher:
    """Notifiche pushtotalk, una richiesta HTTP/2 per gettone con curl."""

    def __init__(self):
        self.jwt = None
        self.minted = 0
        self.dead = []   # gettoni che APNs dice non validi, li toglie il ciclo principale
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
        cmd = ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--http2", "-m", "10",
               "-H", "authorization: bearer " + self.bearer(),
               "-H", "apns-topic: " + APNS_TOPIC, "-H", "apns-push-type: pushtotalk",
               "-H", "apns-priority: 10", "-H", "apns-expiration: 0",
               "-d", body, "https://%s/3/device/%s" % (host, token)]

        def run():
            try:
                code = subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout.strip()
            except (OSError, subprocess.SubprocessError):
                return
            if code in ("400", "410"):
                self.dead.append(token)
            if code != "200":
                log("apns", code, token[:8])

        threading.Thread(target=run, daemon=True).start()

# src/ACL.h
WRITE, TRAVERSE, ENTER, SPEAK = 0x1, 0x2, 0x4, 0x8
MAKE_CHANNEL, WHISPER, TEXT, MAKE_TEMP = 0x40, 0x100, 0x200, 0x400
REGISTER, SELF_REGISTER = 0x40000, 0x80000

VERSION, AUTH, PING, REJECT, SYNC = 0, 2, 3, 4, 5
CH_REMOVE, CH_STATE, USER_REMOVE, USER_STATE, TEXT_MSG, ACL = 6, 7, 8, 9, 11, 13


def log(*a):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *a, flush=True)


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
    return f_int(1, int(here)) + f_int(2, int(subs)) + f_str(5, group) + f_int(6, grant) + f_int(7, deny)


class Rooms:
    def __init__(self):
        self.sock = None
        self.buf = b""
        self.session = None
        self.channels = {}   # id -> {"name", "parent"}
        self.users = {}      # session -> {"ch": canale, "name": nome}
        self.home = None
        data = self.load()
        # Prima del 9/11 sera il file era solo {nome: ultimo uso}.
        if "seen" in data:
            self.last_seen = data.get("seen", {})
            self.tokens = data.get("tok", {})
            self.ptt = data.get("ptt", {})
        else:
            self.last_seen, self.tokens, self.ptt = data, {}, {}
        self.pusher = Pusher()
        self.pushed = {}     # gettone -> ultima notifica
        self.pending = {}    # nome -> token, in attesa del ChannelState
        self.synced = False

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
            json.dump({"seen": self.last_seen, "tok": self.tokens, "ptt": self.ptt}, fh)
        os.replace(tmp, STATE)

    def send(self, kind, body):
        self.sock.sendall(struct.pack(">HI", kind, len(body)) + body)

    def connect(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection((HOST, PORT), timeout=10)
        self.sock = ctx.wrap_socket(raw)
        self.sock.settimeout(1.0)
        v = (1 << 16) | (5 << 8)
        self.send(VERSION, f_int(1, v) + f_str(2, "talky-rooms") + f_str(3, "Linux") + f_int(5, (1 << 48) | (5 << 32)))
        self.send(AUTH, f_str(1, "SuperUser") + f_str(2, PASSWORD) + f_int(5, 1))

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
        # scrive e non si creano canali: niente di pubblico da moderare.
        acls = chan_acl("all", TRAVERSE | ENTER,
                        SPEAK | WHISPER | TEXT | MAKE_CHANNEL | MAKE_TEMP | REGISTER | SELF_REGISTER)
        self.send(ACL, f_int(1, 0) + f_int(2, 0) + f_bytes(4, acls))

    def write_home_rules(self, cid):
        # Il canale del custode: gli si puo' scrivere in privato, non ci si entra.
        acls = chan_acl("all", TRAVERSE | TEXT, ENTER | SPEAK | WHISPER)
        self.send(ACL, f_int(1, cid) + f_int(2, 0) + f_bytes(4, acls))

    def write_room_rules(self, cid, token):
        closed = chan_acl("all", TRAVERSE, ENTER | SPEAK | WHISPER | TEXT | MAKE_CHANNEL | MAKE_TEMP)
        inside = chan_acl("#" + token, TRAVERSE | ENTER | SPEAK | WHISPER | TEXT, 0)
        self.send(ACL, f_int(1, cid) + f_int(2, 0) + f_bytes(4, closed) + f_bytes(4, inside))

    def by_name(self, name):
        for cid, c in self.channels.items():
            if c["name"] == name and c["parent"] == 0:
                return cid
        return None

    def create(self, name):
        # ChannelState: parent 2, name 3; senza channel_id vuol dire "crea".
        self.send(CH_STATE, f_int(2, 0) + f_str(3, name))

    # --- messaggi ---

    def on_frame(self, kind, body):
        if kind == PING:
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
            log("collegato, sessione", self.session, "canali", len(self.channels))
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
            token = self.pending.pop(c["name"], None)
            if token:
                self.write_room_rules(cid, token)
                self.tokens[c["name"]] = hashlib.sha256(token.encode()).hexdigest()
                self.last_seen[c["name"]] = time.time()
                self.save()
                log("stanza creata", c["name"])
        elif kind == CH_REMOVE:
            self.channels.pop(first(m, 1), None)
        elif kind == USER_STATE:
            s = first(m, 1)
            if s is not None:
                u = self.users.setdefault(s, {"ch": 0, "name": ""})
                if 5 in m:
                    u["ch"] = first(m, 5)
                if 3 in m:
                    u["name"] = first(m, 3).decode(errors="replace")
        elif kind == USER_REMOVE:
            self.users.pop(first(m, 1), None)
        elif kind == TEXT_MSG:
            self.on_text(first(m, 1), first(m, 5, b"").decode(errors="replace"))

    def enter_home(self):
        self.write_home_rules(self.home)
        self.send(USER_STATE, f_int(1, self.session) + f_int(5, self.home))

    def on_text(self, actor, text):
        parts = re.sub(r"<[^>]+>", "", text).strip().split()
        if len(parts) < 3 or not ROOM_NAME.match(parts[1]) or not TOKEN.match(parts[2]):
            return
        if parts[0] == "ptt" and len(parts) == 6:
            self.on_ptt(*parts[1:])
            return
        if parts[0] == "talk" and len(parts) == 4:
            self.on_talk(*parts[1:])
            return
        if parts[0] != "room" or len(parts) != 3:
            return
        name, token = parts[1], parts[2]
        cid = self.by_name(name)
        # Se esiste gia' non si tocca: vale il token con cui e' nata, e chi
        # ne manda uno diverso semplicemente non entra.
        if cid is None and name not in self.pending:
            self.pending[name] = token
            self.create(name)
        if actor is not None:
            self.send(TEXT_MSG, f_int(2, actor) + f_str(5, "ok " + name))

    def token_ok(self, name, token):
        if self.by_name(name) is None:
            return False
        sha = hashlib.sha256(token.encode()).hexdigest()
        # Stanze nate prima che il custode tenesse l'impronta: vale la prima.
        return self.tokens.setdefault(name, sha) == sha

    def on_ptt(self, name, token, push, env, nick):
        if not (PUSH_TOKEN.match(push) and env in ("sandbox", "production") and NICK.match(nick)):
            return
        if not self.token_ok(name, token):
            return
        room = self.ptt.setdefault(name, {})
        room[push] = {"env": env, "nick": nick, "ts": time.time()}
        if len(room) > PTT_PER_ROOM:
            for old in sorted(room, key=lambda k: room[k]["ts"])[:len(room) - PTT_PER_ROOM]:
                room.pop(old)
        self.save()

    def on_talk(self, name, token, nick):
        if not NICK.match(nick) or not self.token_ok(name, token):
            return
        cid = self.by_name(name)
        here = {u["name"] for u in self.users.values() if u["ch"] == cid}
        now = time.time()
        for push, info in list(self.ptt.get(name, {}).items()):
            # A chi e' gia' nella stanza la voce arriva da Mumble.
            if info["nick"] == nick or info["nick"] in here:
                continue
            if now - self.pushed.get(push, 0) < PTT_GAP:
                continue
            self.pushed[push] = now
            self.pusher.send(push, info["env"], nick)

    def sweep(self):
        now = time.time()
        changed = False
        occupied = {u["ch"] for u in self.users.values()}
        for room in self.ptt.values():
            for push in [k for k, v in room.items() if now - v["ts"] > PTT_TTL or k in self.pusher.dead]:
                room.pop(push)
                changed = True
        self.pusher.dead.clear()
        for cid, c in list(self.channels.items()):
            name = c["name"]
            if not ROOM_NAME.match(name) or c["parent"] != 0:
                continue
            if cid in occupied:
                self.last_seen[name] = now
                changed = True
            elif now - self.last_seen.setdefault(name, now) > IDLE_SECONDS:
                self.send(CH_REMOVE, f_int(1, cid))
                self.last_seen.pop(name, None)
                self.tokens.pop(name, None)
                self.ptt.pop(name, None)
                changed = True
                log("stanza tolta", name)
        if changed:
            self.save()

    def run(self):
        self.connect()
        last_ping = last_sweep = time.time()
        while True:
            for kind, body in self.frames():
                self.on_frame(kind, body)
            now = time.time()
            if now - last_ping > 15:
                self.send(PING, f_int(1, int(now * 1000)))
                last_ping = now
            if self.synced and now - last_sweep > 600:
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
