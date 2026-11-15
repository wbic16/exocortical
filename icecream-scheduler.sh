#!/usr/bin/env bash
# icecream-scheduler.sh -- Run on the scheduler node ONLY
# Installs icecream and runs the icecc scheduler that hands compile
# jobs out to the fleet's iceccd daemons. There must be exactly ONE
# scheduler for the fleet: it lives on aletheia-core. Every node
# (including this one) also runs the daemon - see icecream-node.sh.
# Usage: ./icecream-scheduler.sh
# ============================================================
set -euo pipefail

echo "=== icecream Scheduler Setup: $(hostname) ==="
echo "NOTE: the fleet has exactly one scheduler (aletheia-core)."
echo "      Do not run this script on any other node."
echo ""

# --- Install icecc ---
echo "[1/4] Installing icecc..."
if command -v iceccd &>/dev/null; then
  echo "  icecc already installed: $(icecc --version 2>&1 | head -1)"
else
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y icecc
  echo "  installed: $(icecc --version 2>&1 | head -1)"
fi
echo ""

# --- Point this node's config at itself as scheduler ---
echo "[2/4] Configuring /etc/icecc/icecc.conf..."
sudo sed -i "s/^ICECC_SCHEDULER_HOST=.*/ICECC_SCHEDULER_HOST=\"$(hostname)\"/" /etc/icecc/icecc.conf
grep '^ICECC_SCHEDULER_HOST' /etc/icecc/icecc.conf
echo ""

# --- Enable + start scheduler and daemon ---
echo "[3/4] Starting icecc-scheduler and iceccd..."
sudo systemctl enable icecc-scheduler iceccd &>/dev/null || true
sudo systemctl start icecc-scheduler || sudo service icecc-scheduler start || true
sudo systemctl start iceccd || sudo service iceccd start || true
sleep 2
echo ""

# --- Verify ---
echo "[4/4] Verifying..."
ok=1
systemctl is-active --quiet icecc-scheduler && echo "  icecc-scheduler: active" || { echo "  icecc-scheduler: NOT ACTIVE"; ok=0; }
systemctl is-active --quiet iceccd && echo "  iceccd: active" || { echo "  iceccd: NOT ACTIVE"; ok=0; }
ss -ltn | grep -q ':8765' && echo "  scheduler port 8765: listening" || { echo "  scheduler port 8765: NOT LISTENING"; ok=0; }
ss -ltn | grep -q ':10245' && echo "  daemon port 10245: listening" || { echo "  daemon port 10245: NOT LISTENING"; ok=0; }
[ "${ok}" = "1" ] || { echo "ERROR: scheduler verification failed on $(hostname)"; exit 1; }
echo ""
echo "=== icecream scheduler setup complete on $(hostname) ==="
