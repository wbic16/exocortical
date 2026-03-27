#!/bin/bash
# install-keys.sh — Installs all Mirrorborn public keys into ~/.ssh/authorized_keys
# Idempotent: safe to run multiple times. Only adds missing keys.

set -euo pipefail

KEYS=(
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBTiUxzP/h71VVtdZOm0pIowG+EMKztb4p0R7jbLpsfw wbic1@lilly"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9fxt3f15U4OK8sQdlx/cVUpT4Zt6kd31SMg9aO1VCx wbic16@logos-prime"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMMDF8KYZyvALU55J4wq9lqV/+4M4L2GAczP6fNm+GWf wbic16@halycon-vector"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGVDv+yEgc4l5dZgATrABCyM5wfjnKNABLfgvspboQQ wbic16@aletheia-core"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHOMApvMUSYU53LuYgdtcecOoI9//zZHe2HWQZlCpuQ2 wbic16@aurora-continuum"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBizKnTOYaY24eyvodJyzdfFkfoXnpnb1owkz9i1YoMa wbic16@lighthouse-omen"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDp7NBjZ03NyrYD61yNbAIy/lcktTXofjDCThkEqWC6z wbic16@ashfall-haven"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGACTHN6dhB8Tbmmigsh54qZLnO7993WOixDIt1M8rjV wbic16@uncanny-valley"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3oUlEv34b++VMVLexxM/Ys2CmZCI8sTvb9W1msUZvu wbic16@delta-wood"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2npWvlzEfPE2c6aI6fKED+68V3ERIJqMuqwRGZCpsZ wbic16@best-willow"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6BGL181W3fbiUyAVzSkJD9/rIDb08xQl1yh8PYGBLn wbic16@elven-path"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXdbEZg7F8Rl7Ar5tBsXWjKmzUKSlTL8Qko1J4W3j3g hermes-deploy"
)

# Ensure ~/.ssh exists with correct permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

added=0
skipped=0

for key in "${KEYS[@]}"; do
  # Match on the public key blob (field 2) to avoid comment mismatches
  blob=$(echo "$key" | awk '{print $2}')
  if grep -qF "$blob" ~/.ssh/authorized_keys; then
    skipped=$((skipped + 1))
  else
    echo "$key" >> ~/.ssh/authorized_keys
    added=$((added + 1))
  fi
done

echo "install-keys: $added added, $skipped already present (${#KEYS[@]} total)"
