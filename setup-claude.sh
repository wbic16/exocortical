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
#
# Notes: plain `cp`, never `cp -a` — the NFS mount cannot preserve
# ownership/permissions ("Operation not supported"), which killed the
# first fleet pass under `set -e`. The copy lands on a temp file and
# is hash-verified before it moves into place, and a node that already
# holds the exact payload skips the copy entirely.
set -e
NFS_CLAUDE=/mnt/mirrorborn/shared/claude-cli
VER=$(basename "$(ls -d "$NFS_CLAUDE"/*/ | sort -V | tail -1)")
SRC="$NFS_CLAUDE/$VER/$VER"
if [ ! -f "$SRC" ]; then
  echo "staged Claude payload not found: $SRC (is the fleet NFS mounted?)"
  exit 1
fi
EXPECTED=$(grep "  ./$VER\$" "$NFS_CLAUDE/$VER/MANIFEST.sha256" | awk '{print $1}')
DEST_DIR="$HOME/.local/share/claude/versions"
DEST="$DEST_DIR/$VER"
mkdir -p "$DEST_DIR" "$HOME/.local/bin"
if [ -f "$DEST" ] && [ "x$(sha256sum "$DEST" | awk '{print $1}')" = "x$EXPECTED" ]; then
  echo "Payload already present and hash-verified, skipping copy."
else
  TMP="$DEST.tmp"
  rm -f "$TMP"
  cp "$SRC" "$TMP"
  chmod +x "$TMP"
  ACTUAL=$(sha256sum "$TMP" | awk '{print $1}')
  if [ "x$EXPECTED" != "x$ACTUAL" ]; then
    echo "Hash mismatch on staged payload: got $ACTUAL, staged manifest says $EXPECTED"
    rm -f "$TMP"
    exit 1
  fi
  mv "$TMP" "$DEST"
fi
ln -sf "$DEST" "$HOME/.local/bin/claude"
echo "Installed Claude $VER from NFS (hash verified)."
"$HOME/.local/bin/claude" --version
