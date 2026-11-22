#!/bin/bash
if [ ! -f /tmp/install-claude.sh ]; then
  curl -fsSL https://claude.ai/install.sh >/tmp/install-claude.sh
fi
EXPECTED_HASH="2c5506d110560bf618bbe88f678f2c2a0047c86a9c6585fc84976120b1de0b44"
HASH=$(sha256sum /tmp/install-claude.sh |awk '{print $1}')
if [ "x$HASH" = "x$EXPECTED_HASH" ]; then
  echo "Install Image Verified, Proceeding..."
  chmod +x /tmp/install-claude.sh
  /tmp/install-claude.sh
else
  echo "New installer: update EXPECTED_HASH to $HASH"
  exit 1
fi
