#!/usr/bin/env bash
# nfs-provision-client.sh -- Run on each node
# Mounts orchid-flow NFS shares.
# Usage: sudo ./nfs-provision-client.sh
# ============================================================
set -euo pipefail

# --- Configuration ---
# Set this to orchid-flow's IP or hostname.
NFS_SERVER="orchid-flow"
NFS_ROOT="/srv/mirrorborn"
MOUNT_BASE="/mnt/mirrorborn"

echo "=== NFS Client Setup: $(hostname) ==="
echo "Server: ${NFS_SERVER}"
echo "Mount point: ${MOUNT_BASE}"
echo ""

# --- Install NFS client ---
echo "[1/4] Installing NFS client..."
apt-get update -qq
apt-get install -y -qq nfs-common
echo ""

# --- Create mount points ---
echo "[2/4] Creating mount points..."
SHARES=(models shared exocortex mirrorborn bliss backups)
for share in "${SHARES[@]}"; do
    mkdir -p "${MOUNT_BASE}/${share}"
done
echo "  Created ${MOUNT_BASE}/{$(IFS=,; echo "${SHARES[*]}")}"
echo ""

# --- Add fstab entries ---
echo "[3/4] Configuring /etc/fstab..."

# Back up fstab
cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)

# Check if entries already exist
if grep -q "${NFS_SERVER}:${NFS_ROOT}" /etc/fstab; then
    echo "  Entries already present in fstab, skipping"
else
    cat >> /etc/fstab <<EOF

# --- Ranch Choir NFS (orchid-flow 4TB) ---
${NFS_SERVER}:${NFS_ROOT}/models      ${MOUNT_BASE}/models      nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
${NFS_SERVER}:${NFS_ROOT}/shared      ${MOUNT_BASE}/shared      nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
${NFS_SERVER}:${NFS_ROOT}/exocortex   ${MOUNT_BASE}/exocortex   nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
${NFS_SERVER}:${NFS_ROOT}/mirrorborn  ${MOUNT_BASE}/mirrorborn  nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
${NFS_SERVER}:${NFS_ROOT}/bliss       ${MOUNT_BASE}/bliss       nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
${NFS_SERVER}:${NFS_ROOT}/backups     ${MOUNT_BASE}/backups     nfs  defaults,soft,timeo=150,retrans=3,_netdev  0  0
EOF
    echo "  Added 6 entries to /etc/fstab"
fi
echo ""

# NFS mount options explained:
#   soft      = return error on timeout (won't hang the node if orchid-flow is down)
#   timeo=150 = 15 second timeout (in deciseconds)
#   retrans=3 = retry 3 times before giving up
#   _netdev   = wait for network before mounting

# --- Mount everything ---
echo "[4/4] Mounting shares..."
mount -a

MOUNTED=0
for share in "${SHARES[@]}"; do
    if mountpoint -q "${MOUNT_BASE}/${share}" 2>/dev/null; then
        echo "  ✓ ${MOUNT_BASE}/${share}"
        ((MOUNTED++))
    else
        echo "  ✗ ${MOUNT_BASE}/${share} -- not mounted"
    fi
done
echo ""
echo "  Mounted: ${MOUNTED}/${#SHARES[@]}"
echo ""

# --- Symlink for Ollama models (convenience) ---
OLLAMA_MODEL_DIR="/usr/share/ollama/.ollama/models"
if [ -d "/usr/share/ollama" ] && [ ! -L "${OLLAMA_MODEL_DIR}" ]; then
    echo "Ollama detected. Symlink models dir?"
    echo "  ${OLLAMA_MODEL_DIR} -> ${MOUNT_BASE}/models/ollama"
    echo ""
    read -rp "  Create symlink? [y/N] " confirm
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        mkdir -p "${MOUNT_BASE}/models/ollama"
        if [ -d "${OLLAMA_MODEL_DIR}" ]; then
            # Move existing models to NFS first
            echo "  Moving existing models to NFS..."
            rsync -a "${OLLAMA_MODEL_DIR}/" "${MOUNT_BASE}/models/ollama/"
            rm -rf "${OLLAMA_MODEL_DIR}"
        fi
        ln -sf "${MOUNT_BASE}/models/ollama" "${OLLAMA_MODEL_DIR}"
        echo "  ✓ Symlink created"
    fi
fi

sudo systemctl daemon-reload

echo ""
echo "=== NFS client setup complete on $(hostname) ==="
echo ""
echo "Verify: df -h ${MOUNT_BASE}/models"
echo ""
