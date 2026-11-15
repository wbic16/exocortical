#!/usr/bin/env bash
# icecream-node.sh -- Run on each build node
# Installs icecream and runs the iceccd daemon as a member of the
# fleet's compile cluster, registered with the scheduler on
# aletheia-core. Compiles submitted through /usr/lib/icecc/bin (or
# with ICECC_SCHEDULER_HOST set) are spread across the fleet.
# Usage: ./icecream-node.sh [scheduler-host]   (default: aletheia-core)
# ============================================================
set -euo pipefail

# --- Configuration ---
SCHEDULER_HOST="${1:-aletheia-core}"
SCHEDULER_PORT="8765"

echo "=== icecream Node Setup: $(hostname) ==="
echo "Scheduler: ${SCHEDULER_HOST}"
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

# --- Configure the daemon's scheduler ---
echo "[2/4] Configuring /etc/icecc/icecc.conf..."
sudo sed -i "s/^ICECC_SCHEDULER_HOST=.*/ICECC_SCHEDULER_HOST=\"${SCHEDULER_HOST}\"/" /etc/icecc/icecc.conf
grep '^ICECC_SCHEDULER_HOST' /etc/icecc/icecc.conf
sudo tee /etc/profile.d/icecream.sh >/dev/null <<EOF
# icecream - distributed builds (icecream-node.sh)
export ICECC_SCHEDULER_HOST="${SCHEDULER_HOST}"
EOF
echo "  /etc/profile.d/icecream.sh written for client compiles"
echo ""

# --- Enable + start the daemon ---
echo "[3/4] Starting iceccd..."
sudo systemctl enable iceccd &>/dev/null || true
sudo systemctl start iceccd || sudo service iceccd start || true
sleep 2
echo ""

# --- Verify ---
echo "[4/4] Verifying..."
ok=1
systemctl is-active --quiet iceccd && echo "  iceccd: active" || { echo "  iceccd: NOT ACTIVE"; ok=0; }
ss -ltn | grep -q ':10245' && echo "  daemon port 10245: listening" || { echo "  daemon port 10245: NOT LISTENING"; ok=0; }
if (exec 3<>"/dev/tcp/${SCHEDULER_HOST}/${SCHEDULER_PORT}") 2>/dev/null; then
  echo "  scheduler ${SCHEDULER_HOST}:${SCHEDULER_PORT}: reachable"
else
  echo "  scheduler ${SCHEDULER_HOST}:${SCHEDULER_PORT}: UNREACHABLE"
  ok=0
fi
[ "${ok}" = "1" ] || { echo "ERROR: node verification failed on $(hostname)"; exit 1; }
echo ""
echo "=== icecream node setup complete on $(hostname) ==="
