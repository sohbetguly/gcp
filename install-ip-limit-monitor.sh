#!/usr/bin/env bash
# install-ip-limit-monitor.sh
# One-shot installer for ip_limit_monitor.py — safe to re-run on the same node.
set -euo pipefail

SCRIPT_PATH="/opt/ip_limit_monitor.py"
SERVICE_NAME="ip-limit-monitor"
IPSET_NAME="blocked_ips"
BAN_SECONDS=600

echo "== Installing ${SCRIPT_PATH} =="
cat > "$SCRIPT_PATH" << 'PYEOF'
#!/usr/bin/env python3
"""
ip_limit_monitor.py
Watches Xray/remnanode access.log, enforces a max concurrent-IP limit
per user (email tag), and bans excess IPs via ipset for BAN_SECONDS.
"""
import re
import subprocess
import time
from collections import defaultdict

LOGFILE = "/var/log/remnanode/access.log"
MAX_IPS_PER_USER = 1
WINDOW_SECONDS = 45      # how long an IP counts as "currently connected"
BAN_SECONDS = 600        # 10 minutes
IPSET_NAME = "blocked_ips"

LINE_RE = re.compile(
    r'from (?:udp:)?(?P<ip>\d+\.\d+\.\d+\.\d+):\d+ .*email: (?P<email>\S+)'
)

active = defaultdict(dict)
banned = {}


def ensure_ipset():
    result = subprocess.run(
        ["ipset", "list", "-name", IPSET_NAME],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        subprocess.run(
            ["ipset", "create", IPSET_NAME, "hash:ip", "timeout", str(BAN_SECONDS)],
            check=False,
        )
        print(f"[INIT] created ipset {IPSET_NAME} with timeout support")


def ban_ip(ip):
    now = time.time()
    if ip in banned and banned[ip] > now:
        return
    result = subprocess.run(
        ["ipset", "add", IPSET_NAME, ip, "timeout", str(BAN_SECONDS), "-exist"],
        check=False,
    )
    if result.returncode != 0:
        print(f"[ERROR] failed to ban {ip} via ipset (rc={result.returncode})")
        return
    banned[ip] = now + BAN_SECONDS
    print(f"[BAN] {ip} for {BAN_SECONDS}s (until {time.strftime('%H:%M:%S', time.localtime(banned[ip]))})")


def prune_bans():
    now = time.time()
    expired = [ip for ip, until in banned.items() if until <= now]
    for ip in expired:
        del banned[ip]
        print(f"[UNBAN-TRACK] {ip} ban window elapsed")


def prune(email):
    now = time.time()
    stale = [ip for ip, ts in active[email].items() if now - ts > WINDOW_SECONDS]
    for ip in stale:
        del active[email][ip]


def enforce(email):
    ips_sorted = sorted(active[email].items(), key=lambda kv: kv[1])
    if len(ips_sorted) > MAX_IPS_PER_USER:
        excess = ips_sorted[:-MAX_IPS_PER_USER]
        for ip, _ in excess:
            ban_ip(ip)
            del active[email][ip]


def tail_f(path):
    with open(path, "r") as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.2)
                continue
            yield line


def main():
    ensure_ipset()
    print("Monitoring", LOGFILE)
    last_prune_bans = time.time()
    for line in tail_f(LOGFILE):
        m = LINE_RE.search(line)
        if not m:
            continue
        ip, email = m.group("ip"), m.group("email")

        now = time.time()
        if now - last_prune_bans > 5:
            prune_bans()
            last_prune_bans = now

        if ip in banned and banned[ip] > now:
            continue

        active[email][ip] = now
        prune(email)
        enforce(email)


if __name__ == "__main__":
    main()
PYEOF
chmod +x "$SCRIPT_PATH"

echo "== Setting up ipset (${IPSET_NAME}) =="
if ! ipset list -name "$IPSET_NAME" >/dev/null 2>&1; then
    ipset create "$IPSET_NAME" hash:ip timeout "$BAN_SECONDS"
    echo "created ipset $IPSET_NAME"
else
    if ! ipset list "$IPSET_NAME" | grep -q "timeout"; then
        echo "!! existing ipset '$IPSET_NAME' has no timeout support — recreating"
        if iptables-save | grep -q "match-set $IPSET_NAME"; then
            iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j DROP || true
        fi
        ipset destroy "$IPSET_NAME"
        ipset create "$IPSET_NAME" hash:ip timeout "$BAN_SECONDS"
    else
        echo "ipset $IPSET_NAME already OK"
    fi
fi

echo "== Ensuring iptables DROP rule (INPUT) =="
if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
    iptables -A INPUT -m set --match-set "$IPSET_NAME" src -j DROP
    echo "added iptables INPUT rule"
else
    echo "iptables INPUT rule already present"
fi

# If the target service runs inside Docker (e.g. remnanode), traffic to its
# published ports is routed through Docker's own forwarding rules and never
# touches INPUT. Docker guarantees DOCKER-USER is always evaluated first, so
# the ban rule must also live there or bans will silently do nothing.
echo "== Ensuring iptables DROP rule (DOCKER-USER) =="
if command -v docker >/dev/null 2>&1 && iptables -L DOCKER-USER -n >/dev/null 2>&1; then
    if ! iptables -C DOCKER-USER -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
        iptables -I DOCKER-USER -m set --match-set "$IPSET_NAME" src -j DROP
        echo "added iptables DOCKER-USER rule"
    else
        echo "iptables DOCKER-USER rule already present"
    fi
else
    echo "Docker / DOCKER-USER chain not found — skipping (host-only setup)"
fi

# Persist iptables rules across reboot if netfilter-persistent is available
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
    echo "saved iptables rules via netfilter-persistent"
elif [ -d /etc/iptables ]; then
    iptables-save > /etc/iptables/rules.v4
    echo "saved iptables rules to /etc/iptables/rules.v4"
else
    echo "!! no persistence tool found (netfilter-persistent / /etc/iptables) — iptables rule will NOT survive reboot unless you set one up"
fi

echo "== Installing systemd service (${SERVICE_NAME}) =="
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=IP limit monitor for remnanode
After=network.target

[Service]
ExecStart=/usr/bin/python3 ${SCRIPT_PATH}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo "== Done =="
systemctl status "$SERVICE_NAME" --no-pager -l | head -10
echo
echo "View live logs with: journalctl -u ${SERVICE_NAME} -f"
