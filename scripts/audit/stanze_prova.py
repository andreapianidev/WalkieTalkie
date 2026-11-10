#!/usr/bin/env python3
"""Prova il server delle stanze private di Talky (Mumble sulla VM2 e custode).

Si collega come farebbero tre telefoni: A apre una stanza col token, B entra
con lo stesso codice, X senza codice prova a entrare e ad ascoltare da fuori.
Controlla che il custode risponda con un nome a caso (non ricavabile dal
codice), che solo chi ha il token entri, parli e senta, che X non riceva
nemmeno un pacchetto di voce, il limite di 10 richieste al minuto e i nomi
Unicode. Nato il 9/11/2026 dalla caccia ai bug, quando un client senza codice
nella radice riceveva la voce delle stanze.

Uso:  python3 scripts/audit/stanze_prova.py      (dalla radice del repo)
Non serve la password del custode. Esce con 1 se una prova fallisce.
"""
import hashlib, os, secrets, socket, ssl, struct, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
# talky_rooms vuole la password del custode all'import; la prova non la usa.
os.environ.setdefault("TALKY_MUMBLE_SUPERUSER_PASSWORD", "-")
from talky_rooms import f_int, f_str, f_bytes, parse, first

HOST, PORT = "92.5.15.244", 22
code = "".join(secrets.choice("23456789ABCDEFGHJKMNPQRSTUVWXYZ") for _ in range(8))
token = hashlib.sha256(("talky-room-token:" + code).encode()).hexdigest()[:32]
LISTEN, SPEAK, ENTER = 0x800, 0x8, 0x4
results = []


def check(what, ok, detail=""):
    results.append(ok)
    print(("OK   " if ok else "NO   ") + what + (("  [" + detail + "]") if detail else ""))


class C:
    def __init__(s, user, tokens):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
        s.k = ctx.wrap_socket(socket.create_connection((HOST, PORT), timeout=8)); s.k.settimeout(0.2); s.buf = b""
        s.chan = {}; s.users = {}; s.me = None; s.perm = {}; s.denied = []; s.texts = []; s.voice = 0; s.rejected = None
        s.send(0, f_int(1, (1 << 16) | (5 << 8)) + f_str(2, "probe") + f_int(5, (1 << 48) | (5 << 32)))
        a = f_str(1, user) + f_int(5, 1)
        for t in tokens:
            a += f_str(3, t)
        s.send(2, a)

    def send(s, k, b): s.k.sendall(struct.pack(">HI", k, len(b)) + b)

    def pump(s, secs):
        end = time.time() + secs
        while time.time() < end:
            try:
                c = s.k.recv(65536)
            except socket.timeout:
                continue
            if not c:
                return
            s.buf += c
            while len(s.buf) >= 6:
                k, n = struct.unpack(">HI", s.buf[:6])
                if len(s.buf) < 6 + n:
                    break
                b = s.buf[6:6 + n]; s.buf = s.buf[6 + n:]
                if k == 1:
                    s.voice += 1
                    continue
                if k == 3:
                    continue
                m = parse(b)
                if k == 5: s.me = first(m, 1)
                elif k == 7:
                    c2 = s.chan.setdefault(first(m, 1), {})
                    if 3 in m: c2["name"] = first(m, 3).decode()
                elif k == 9:
                    u = s.users.setdefault(first(m, 1), {})
                    if 3 in m: u["name"] = first(m, 3).decode()
                    if 5 in m: u["ch"] = first(m, 5)
                elif k == 12: s.denied.append({"perm": first(m, 1), "ch": first(m, 2), "type": first(m, 5)})
                elif k == 20: s.perm[first(m, 1)] = first(m, 2)
                elif k == 11: s.texts.append((first(m, 1), first(m, 5, b"").decode()))
                elif k == 4:
                    s.rejected = (first(m, 1), first(m, 2, b"").decode())
                    return

    def cid(s, n): return next((c for c, v in s.chan.items() if v.get("name") == n), None)
    def session_of(s, n): return next((u for u, v in s.users.items() if v.get("name") == n), None)
    def query(s, c): s.send(20, f_int(1, c)); s.pump(1.5); return s.perm.get(c, 0)
    def keeper(s): return s.session_of("SuperUser")
    def ask_room(s, tok):
        before = len(s.texts)
        s.send(11, f_int(2, s.keeper()) + f_str(5, "room " + tok))
        for _ in range(40):
            s.pump(0.25)
            if len(s.texts) > before:
                return s.texts[-1][1]
        return None
    def talk(s, packets):
        s.send(9, f_int(1, s.me) + f_int(9, 0))   # muto tolto
        s.pump(0.3)
        for i in range(packets):
            audio = f_int(1, 0) + f_int(4, 2 * (i + 1)) + f_bytes(5, bytes([0x78]) + secrets.token_bytes(60))
            s.send(1, b"\x00" + audio)
            time.sleep(0.02)
        s.send(1, b"\x00" + f_int(1, 0) + f_int(4, 2 * (packets + 1)) + f_bytes(5, b"") + f_int(16, 1))


print("codice di prova", code)
a = C("probeA-%d" % secrets.randbelow(1000), [token]); a.pump(2)
check("A collegato al server delle stanze", a.me is not None, "sessione %s" % a.me)
check("custode presente", a.keeper() is not None)
check("nella radice non si parla", not (a.query(0) & SPEAK), hex(a.perm.get(0, 0)))

reply = a.ask_room(token)
name = reply.split()[1] if reply and reply.startswith("ok ") else None
check("il custode risponde ok <nome>", name is not None, str(reply))
legacy = "room-" + hashlib.sha256(("talky-room-name:" + code).encode()).hexdigest()[:16]
check("il nome non e' quello ricavabile dal codice", name != legacy, "%s / %s" % (name, legacy))
rc = a.cid(name)
check("il canale esiste gia' quando arriva ok", rc is not None, "id %s" % rc)
a.send(9, f_int(1, a.me) + f_int(5, rc)); a.pump(2)
check("A col codice entra", a.users[a.me].get("ch") == rc)
p = a.query(rc)
check("A col codice puo' parlare e ascoltare", bool(p & SPEAK) and bool(p & LISTEN), hex(p))

again = a.ask_room(token)
check("stessa stanza per lo stesso token", again == "ok " + str(name), str(again))

b = C("probeB-%d" % secrets.randbelow(1000), [token]); b.pump(2)
reply_b = b.ask_room(token)
rc_b = b.cid(name)
b.send(9, f_int(1, b.me) + f_int(5, rc_b)); b.pump(2)
check("B col codice entra nella stessa stanza", reply_b == "ok " + str(name) and b.users[b.me].get("ch") == rc_b)

x = C("intruso-%d" % secrets.randbelow(1000), []); x.pump(2)
rc_x = x.cid(name)
x.send(9, f_int(1, x.me) + f_int(5, rc_x)); x.pump(2)
check("X senza codice non entra", x.users.get(x.me, {}).get("ch") != rc_x, str(x.denied[-1:] if x.denied else ""))
x.denied.clear()
x.send(9, f_int(1, x.me) + f_int(21, rc_x)); x.pump(2)
listen_denied = any(d["perm"] == LISTEN for d in x.denied)
check("X senza codice: ascolto a distanza negato dal server", listen_denied, str(x.denied))
pq = x.query(rc_x)
check("X senza codice: niente Listen nei permessi della stanza", not (pq & LISTEN), hex(pq))

# A parla 2 secondi: B (dentro) deve sentire, X (radice, ha chiesto di ascoltare) no.
b.voice = x.voice = 0
a.talk(100)
b.pump(1.5); x.pump(1.5)
check("B col codice sente la voce di A", b.voice >= 90, "%d pacchetti" % b.voice)
check("X senza codice non sente niente", x.voice == 0, "%d pacchetti" % x.voice)

# Limite di richieste: 10 al minuto per sessione, l'undicesima "slow".
r = C("raffica-%d" % secrets.randbelow(1000), [token]); r.pump(2)
answers = [r.ask_room(token) for _ in range(11)]
check("10 richieste ok, l'undicesima rallentata", answers[:10] == ["ok " + str(name)] * 10 and answers[10] == "slow",
      ", ".join(str(v) for v in answers[-2:]))

# Nomi Unicode accettati dal server, < > no.
th = C("วิชัย%d" % secrets.randbelow(100), []); th.pump(2)
check("nome thai accettato dal server", th.me is not None and th.rejected is None, str(th.rejected))
bad = C("<b>x%d" % secrets.randbelow(100), []); bad.pump(2)
check("nome con < > rifiutato", bad.rejected is not None and bad.rejected[0] == 2, str(bad.rejected))

print("\n%d prove su %d riuscite" % (sum(results), len(results)))
print("TOKEN", token, "NOME", name)
sys.exit(0 if all(results) else 1)
