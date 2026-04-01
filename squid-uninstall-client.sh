#!/usr/bin/env bash
# Undo all client proxy config
set -euo pipefail

echo "Removing Ranch Choir proxy config..."

# CA cert
sudo rm -f /usr/local/share/ca-certificates/ranch-choir-squid-ca.crt
sudo update-ca-certificates

# apt proxy
sudo rm -f /etc/apt/apt.conf.d/02ranch-proxy

# Ollama systemd override
sudo rm -f /etc/systemd/system/ollama.service.d/proxy.conf
sudo rmdir /etc/systemd/system/ollama.service.d 2>/dev/null || true
sudo systemctl daemon-reload
systemctl is-active --quiet ollama 2>/dev/null && sudo systemctl restart ollama

# System environment
sudo rm -f /etc/profile.d/ranch-proxy.sh
sudo sed -i '/.*_[Pp][Rr][Oo][Xx][Yy]=/d' /etc/environment

# pip
sudo rm -f /etc/pip/pip.conf

# npm
if command -v npm &>/dev/null; then
    npm config delete proxy --global 2>/dev/null || true
    npm config delete https-proxy --global 2>/dev/null || true
fi

echo "Done. Log out and back in to clear env vars from this session."
