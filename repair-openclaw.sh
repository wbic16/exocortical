#!/bin/bash
if [ -d ~/.openclaw ]
then
  mv ~/.openclaw ~/.openclaw-historic-snapshot
fi
sudo mkdir -p /opt/openclaw
sudo chown -R $USER:$USER /opt/openclaw
cd /opt/openclaw
LATEST="OpenClaw-2026.10.7-amd64.deb"
if [ ! -f $LATEST ]
then
  wget "https://github.com/openclaw/openclaw/releases/download/v2026.10.7/$LATEST"
fi
sudo apt install ./$LATEST
curl -fsSL https://openclaw.ai/install.sh | bash
