#!/bin/bash
# creato da Andrea Piani - 09/11/26 - https://www.andreapiani.com - deploy_rooms.sh
#
# Installa (o reinstalla) sulla VM2 il server Mumble delle stanze private di
# Talky e il loro custode. Si lancia dal Mac: legge le password dal vault e
# non le scrive mai nel repo, che e' pubblico.
#   scripts/server/deploy_rooms.sh [host]
set -euo pipefail
HOST=${1:-ubuntu@oracle-vm-2.tail28fc24.ts.net}
set -a; source ~/.secrets/talky-mumble.env; set +a
DIR=$(cd "$(dirname "$0")" && pwd)

scp -q "$DIR/talky_rooms.py" "$HOST:/tmp/talky_rooms.py"
# Chiave APNs del team per le notifiche Push to Talk (vault: ~/.secrets/apns-AuthKey_RF29RR7SKM.p8).
scp -q ~/.secrets/apns-AuthKey_RF29RR7SKM.p8 "$HOST:/tmp/talky-apns.p8"
ssh "$HOST" "sudo bash -s" <<REMOTE
set -e
DEBIAN_FRONTEND=noninteractive apt-get install -y -q mumble-server python3-jwt python3-cryptography curl >/dev/null
ini=/etc/mumble/mumble-server.ini
# Una chiave che manca va prima di [Ice]: in coda al file finirebbe nella
# sezione di Ice e il server non la leggerebbe.
setkv() { if grep -qE "^;?\\s*\$1=" \$ini; then sed -i -E "s|^;?\\s*\$1=.*|\$1=\$2|" \$ini; else sed -i "/^\\[Ice\\]/i \$1=\$2" \$ini; fi; }
setkv port 64738
setkv serverpassword ""
setkv users 200
setkv usersperchannel 30
setkv bandwidth 72000
setkv registerName ""
setkv welcometext '""'
setkv allowhtml false
setkv certrequired false
setkv rememberchannel false
setkv logdays 1
setkv obfuscate true
setkv sendversion false
setkv opusthreshold 0
# Il server scarta in silenzio i messaggi oltre questo limite (per utente,
# al secondo e di scorta): con 1 e 5, i valori di serie, un custode che crea
# due stanze insieme perdeva le regole, e un passaggio subito dopo l'ingresso
# perdeva il muto tolto. Il custode resta sotto (6 al secondo, 20 di scorta).
setkv messagelimit 10
setkv messageburst 40
# Una stanza in piu' del limite del custode (1000), piu' "Talky".
setkv channelcountlimit 1100
# Nomi in ogni alfabeto (thai, hindi, cinese...), senza spazi e senza < >.
# E' un QRegExp di Qt 5 (Server::readParams), che le classi POSIX come
# [:space:] non le conosce; niente barre rovesciate, che QSettings leggerebbe
# come escape. Spazi in testa e in coda li scarta gia' validateUserName.
setkv username '[^ <>]+'
mkdir -p /etc/systemd/system/mumble-server.service.d
printf '[Service]\nMemoryMax=150M\nCPUQuota=50%%\n' > /etc/systemd/system/mumble-server.service.d/talky-limits.conf
systemctl daemon-reload
systemctl restart mumble-server
sleep 2
mumble-server -ini \$ini -supw "$TALKY_MUMBLE_SUPERUSER_PASSWORD" >/dev/null 2>&1 || true
systemctl restart mumble-server

# La lista di sicurezza Oracle lascia passare solo la 22, e l'SSH pubblico e'
# spento (si entra da Tailscale): la 22 pubblica va al server Mumble.
for p in tcp udp; do
  iptables -C INPUT -p \$p --dport 64738 -j ACCEPT 2>/dev/null || iptables -I INPUT 6 -p \$p -m state --state NEW -m \$p --dport 64738 -j ACCEPT
done
iptables -t nat -C PREROUTING -i ens3 -p tcp --dport 22 -j REDIRECT --to-ports 64738 2>/dev/null || iptables -t nat -A PREROUTING -i ens3 -p tcp --dport 22 -j REDIRECT --to-ports 64738
iptables-save > /etc/iptables/rules.v4

install -d -m 755 /opt/talky-rooms
install -m 644 /tmp/talky_rooms.py /opt/talky-rooms/talky_rooms.py
install -d -m 700 /etc/talky-rooms
install -m 600 /tmp/talky-apns.p8 /etc/talky-rooms/apns.p8
rm -f /tmp/talky-apns.p8
umask 077
printf 'TALKY_MUMBLE_SUPERUSER_PASSWORD=%s\n' "$TALKY_MUMBLE_SUPERUSER_PASSWORD" > /etc/talky-rooms.env
cat > /etc/systemd/system/talky-rooms.service <<UNIT
[Unit]
Description=Talky, custode delle stanze private su mumble-server
After=mumble-server.service
Requires=mumble-server.service

[Service]
EnvironmentFile=/etc/talky-rooms.env
LoadCredential=apns.p8:/etc/talky-rooms/apns.p8
Environment=APNS_KEY_PATH=%d/apns.p8
Environment=APNS_KEY_ID=RF29RR7SKM
Environment=APNS_TEAM_ID=ERAK83QBBM
ExecStart=/usr/bin/python3 /opt/talky-rooms/talky_rooms.py
DynamicUser=yes
StateDirectory=talky-rooms
Environment=TALKY_ROOMS_STATE=/var/lib/talky-rooms/rooms.json
Restart=always
RestartSec=5
MemoryMax=60M
CPUQuota=20%

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now talky-rooms >/dev/null 2>&1
systemctl restart talky-rooms
sleep 3
systemctl is-active mumble-server talky-rooms
journalctl -u talky-rooms -n 5 --no-pager -o cat
REMOTE
