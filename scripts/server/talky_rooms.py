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
#   - le stanze vuote da piu' di 24 ore le cancella.
# Il token arriva solo a lui (messaggio a una sessione), mai in un canale.
#
# Solo libreria standard. La password di SuperUser arriva dall'ambiente
# (TALKY_MUMBLE_SUPERUSER_PASSWORD), mai da questo file: il repo e' pubblico.

import json
import os
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
        self.users = {}      # session -> channel id
        self.home = None
        self.last_seen = self.load()
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
            json.dump(self.last_seen, fh)
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
                self.last_seen[c["name"]] = time.time()
                self.save()
                log("stanza creata", c["name"])
        elif kind == CH_REMOVE:
            self.channels.pop(first(m, 1), None)
        elif kind == USER_STATE:
            s = first(m, 1)
            if s is not None and 5 in m:
                self.users[s] = first(m, 5)
            elif s is not None:
                self.users.setdefault(s, 0)
        elif kind == USER_REMOVE:
            self.users.pop(first(m, 1), None)
        elif kind == TEXT_MSG:
            self.on_text(first(m, 1), first(m, 5, b"").decode(errors="replace"))

    def enter_home(self):
        self.write_home_rules(self.home)
        self.send(USER_STATE, f_int(1, self.session) + f_int(5, self.home))

    def on_text(self, actor, text):
        parts = re.sub(r"<[^>]+>", "", text).strip().split()
        if len(parts) != 3 or parts[0] != "room" or not ROOM_NAME.match(parts[1]) or not TOKEN.match(parts[2]):
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

    def sweep(self):
        now = time.time()
        occupied = set(self.users.values())
        changed = False
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
