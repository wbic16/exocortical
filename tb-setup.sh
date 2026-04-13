#!/bin/bash
# tb-setup.sh - Configure tb0 interface based on hostname
# Ranch Choir USB4/Thunderbolt Network

set -euo pipefail

declare -A TB_MAP=(
  [aletheia-core]=10.53.4.1
  [ashfall-haven]=10.53.1.2
  [aurora-continuum]=10.53.5.1
  [best-willow]=10.53.2.4
  [chrysalis-hub]=10.53.7.2
  [delta-wood]=10.53.2.3
  [elven-path]=10.53.1.4
  [free-fall]=10.53.3.4
  [great-white]=10.53.5.3
  [halcyon-vector]=10.53.2.2
  [jacked-kite]=10.53.5.2
  [kaleidoscope-one]=10.53.6.2
  [lighthouse-omen]=10.53.3.3
  [logos-prime]=10.53.1.3
  [moon-beam]=10.53.6.3
  [ni-knight]=10.53.1.1
  [orchid-flow]=10.53.2.1
  [plain-view]=10.53.3.1
  [quacked-hill]=10.53.5.4
  [rock-mountain]=10.53.4.4
  [scroll-central]=10.53.6.4
  [trust-fall]=10.53.3.2
  [uncanny-valley]=10.53.7.1
  [victory-galleon]=10.53.4.2
  [west-lincoln]=10.53.4.3
  [yeet-max]=10.53.6.1
)

HOSTNAME=$(hostname -s)
IFACE=tb0
PREFIX=24

if [[ -z "${TB_MAP[$HOSTNAME]+x}" ]]; then
  echo "ERROR: hostname '$HOSTNAME' not found in TB map"
  exit 1
fi

ADDR="${TB_MAP[$HOSTNAME]}"

# Load thunderbolt module if needed
modprobe thunderbolt 2>/dev/null || true
modprobe thunderbolt_net 2>/dev/null || true

nmcli connection add type ethernet con-name tb0 ifname tb0 ipv4.method manual ipv4.addresses "$ADDR/24" autoconnect yes

# Wait briefly for tb0 to appear
for i in {1..5}; do
  ip link show "$IFACE" &>/dev/null && break
  echo "Waiting for $IFACE... ($i/5)"
  sleep 2
done

if ! ip link show "$IFACE" &>/dev/null; then
  echo "ERROR: $IFACE not found"
  exit 1
fi

# Flush existing addresses and apply
ip addr flush dev "$IFACE"
ip addr add "${ADDR}/${PREFIX}" dev "$IFACE"
ip link set "$IFACE" up

echo "OK: $HOSTNAME -> $IFACE @ $ADDR/$PREFIX"
