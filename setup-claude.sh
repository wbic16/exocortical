#!/bin/bash
# setup-claude.sh — install the Claude CLI from the fleet NFS stage.
#
# Provenance: the payload was installed once (on aletheia-core,
# 2026-11-21) by Will's original download installer, gated on his
# SHA-256 pin for https://claude.ai/install.sh:
#   2c5506d110560bf618bbe88f678f2c2a0047c86a9c6585fc84976120b1de0b44
# The installed objects (the versioned binary under
# ~/.local/share/claude/versions/) were then staged to NFS. Nodes pull
# from NFS and verify against the staged manifest — no per-node
# download, and the same hash discipline as the original script.
set -e
NFS_CLAUDE=/mnt/mirrorborn/shared/claude-cli
VER=$(basename "$(ls -d "$NFS_CLAUDE"/*/ | sort -V | tail -1)")
SRC="$NFS_CLAUDE/$VER/$VER"
if [ ! -f "$SRC" ]; then
  echo "staged Claude payload not found: $SRC (is the fleet NFS mounted?)"
  exit 1
fi
DEST_DIR="$HOME/.local/share/claude/versions"
DEST="$DEST_DIR/$VER"
mkdir -p "$DEST_DIR" "$HOME/.local/bin"
cp -a "$SRC" "$DEST"
chmod +x "$DEST"
EXPECTED=$(grep "  ./$VER\$" "$NFS_CLAUDE/$VER/MANIFEST.sha256" | awk '{print $1}')
ACTUAL=$(sha256sum "$DEST" | awk '{print $1}')
if [ "x$EXPECTED" != "x$ACTUAL" ]; then
  echo "Hash mismatch on $DEST: got $ACTUAL, staged manifest says $EXPECTED"
  exit 1
fi
ln -sf "$DEST" "$HOME/.local/bin/claude"
echo "Installed Claude $VER from NFS (hash verified)."
"$HOME/.local/bin/claude" --version
