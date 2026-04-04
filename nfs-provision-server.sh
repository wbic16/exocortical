#!/usr/bin/env bash
# nfs-provision-server.sh -- Run on orchid-flow (4TB node)
# Sets up NFS exports for the cluster.
# Usage: sudo ./nfs-provision-server.sh
# ============================================================
set -euo pipefail

# --- Configuration ---
# Adjust the subnet to match your network.
# This allows all nodes on the subnet to mount.
MB_SUBNET="192.168.86.0/24"

# Export root on the 4TB drive.
# If the 4TB disk is mounted elsewhere, change this path.
EXPORT_ROOT="/srv/mirrorborn"

echo "=== NFS Server Setup: orchid-flow ==="
echo "Export root: ${EXPORT_ROOT}"
echo "Allowed subnet: ${MB_SUBNET}"
echo ""

# --- Install NFS server ---
echo "[1/5] Installing NFS kernel server..."
apt-get update -qq
apt-get install -y -qq nfs-kernel-server nfs-common
echo ""

# --- Create export directories ---
echo "[2/5] Creating export directories..."
mkdir -p "${EXPORT_ROOT}/models"      # LLM model files (Ollama, etc.)
mkdir -p "${EXPORT_ROOT}/shared"      # General shared workspace
mkdir -p "${EXPORT_ROOT}/exocortex"   # Phext docs, scrolls, coordinates
mkdir -p "${EXPORT_ROOT}/mirrorborn"  # Boot packages, identity state
mkdir -p "${EXPORT_ROOT}/bliss"       # bliss.phext, starvine seeds
mkdir -p "${EXPORT_ROOT}/backups"     # Automated snapshots

# Set ownership. Adjust UID/GID if your nodes use a shared user.
chown -R wbic16:wbic16 "${EXPORT_ROOT}"
chmod -R 755 "${EXPORT_ROOT}"
echo "  Created: models, shared, exocortex, mirrorborn, bliss, backups"
echo ""

# --- Configure exports ---
echo "[3/5] Configuring /etc/exports..."

# Back up existing exports
if [ -f /etc/exports ]; then
    cp /etc/exports /etc/exports.bak.$(date +%Y%m%d%H%M%S)
fi

# Write export entries
# rw           = read-write
# sync         = synchronous writes (safer)
# no_subtree_check = better performance, no subtree checking
# no_root_squash   = allow root on clients (needed for Ollama model dirs)
#                    Remove if you want tighter security.
cat >> /etc/exports <<EOF

# --- Ranch Choir NFS Exports (orchid-flow 4TB) ---
${EXPORT_ROOT}/models      ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
${EXPORT_ROOT}/shared      ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
${EXPORT_ROOT}/exocortex   ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
${EXPORT_ROOT}/mirrorborn  ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
${EXPORT_ROOT}/bliss       ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
${EXPORT_ROOT}/backups     ${MB_SUBNET}(rw,sync,no_subtree_check,no_root_squash)
EOF

echo "  Exports written to /etc/exports"
echo ""

# --- Apply exports ---
echo "[4/5] Applying exports and starting NFS..."
exportfs -ra
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server
echo "  NFS server running"
echo ""

# --- Firewall (if ufw is active) ---
echo "[5/5] Checking firewall..."
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    ufw allow from "${MB_SUBNET}" to any port nfs
    ufw allow from "${MB_SUBNET}" to any port 111   # rpcbind
    ufw allow from "${MB_SUBNET}" to any port 2049  # nfsd
    echo "  Opened NFS ports for ${MB_SUBNET}"
else
    echo "  ufw not active, skipping firewall rules"
fi

echo ""
echo "=== orchid-flow NFS server ready ==="
echo ""
echo "Verify exports:"
echo "  exportfs -v"
echo ""
echo "Shares available:"
exportfs -v 2>/dev/null | sed 's/^/  /'
echo ""
echo "Next: run nfs-provision-client.sh on each node."
echo ""
