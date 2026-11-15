#!/usr/bin/env bash
# sccache-setup.sh -- Run on each node
# Installs sccache and points it at the fleet-shared compiler cache
# on the orchid-flow NFS share, so a compile done anywhere warms the
# cache for every node. Falls back to a local cache dir when the NFS
# share is not mounted.
# Usage: ./sccache-setup.sh
# ============================================================
set -euo pipefail

# --- Configuration ---
SHARED_CACHE_DIR="/mnt/mirrorborn/shared/sccache"
LOCAL_CACHE_DIR="${HOME}/.cache/sccache"
CACHE_SIZE="50G"

echo "=== sccache Setup: $(hostname) ==="
echo ""

# --- Install sccache ---
echo "[1/4] Installing sccache..."
if command -v sccache &>/dev/null; then
  echo "  sccache already installed: $(sccache --version)"
else
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sccache
  echo "  installed: $(sccache --version)"
fi
echo ""

# --- Pick the cache location ---
echo "[2/4] Selecting cache location..."
if mountpoint -q /mnt/mirrorborn/shared; then
  CACHE_DIR="${SHARED_CACHE_DIR}"
  echo "  NFS shared share mounted - using fleet-shared cache: ${CACHE_DIR}"
else
  CACHE_DIR="${LOCAL_CACHE_DIR}"
  echo "  WARNING: /mnt/mirrorborn/shared is not mounted."
  echo "  Using local cache instead: ${CACHE_DIR}"
  echo "  Run nfs-provision-client.sh and re-run this script to share the cache."
fi
mkdir -p "${CACHE_DIR}"
echo ""

# --- Environment for login shells ---
echo "[3/4] Writing /etc/profile.d/sccache.sh..."
sudo tee /etc/profile.d/sccache.sh >/dev/null <<EOF
# sccache - fleet-shared compiler cache (sccache-setup.sh)
export SCCACHE_DIR="${CACHE_DIR}"
export SCCACHE_CACHE_SIZE="${CACHE_SIZE}"
EOF
echo "  SCCACHE_DIR=${CACHE_DIR}"
echo "  SCCACHE_CACHE_SIZE=${CACHE_SIZE}"
echo ""

# --- (Re)start the cache server against the chosen dir ---
echo "[4/4] Starting sccache server..."
export SCCACHE_DIR="${CACHE_DIR}"
export SCCACHE_CACHE_SIZE="${CACHE_SIZE}"
if sccache --show-stats 2>/dev/null | grep -q "${CACHE_DIR}"; then
  echo "  server already running with this cache location"
else
  sccache --stop-server &>/dev/null || true
  sccache --start-server
  echo "  server started"
fi
sccache --show-stats | head -8
echo ""
echo "=== sccache setup complete on $(hostname) ==="
