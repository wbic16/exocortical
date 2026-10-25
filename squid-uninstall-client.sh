#!/usr/bin/env bash
# Remove everything provision-squid-client.sh installs, including the
# fail-open probes. Safe to run more than once.
set -euo pipefail

echo "Removing Ranch Choir proxy config..."

sudo rm -f /usr/local/share/ca-certificates/ranch-choir-squid-ca.crt
sudo update-ca-certificates || true

sudo rm -f /etc/apt/apt.conf.d/02ranch-proxy
sudo rm -f /usr/local/bin/ranch-proxy-autodetect
sudo rm -f /usr/local/bin/ranch-proxy-ollama-env
sudo rm -f /etc/ranch-squid/client.env
sudo rmdir /etc/ranch-squid 2>/dev/null || true

sudo rm -f /etc/systemd/system/ollama.service.d/proxy.conf
sudo rmdir /etc/systemd/system/ollama.service.d 2>/dev/null || true
sudo rm -f /run/ranch-proxy.env
if [[ -S /run/systemd/private ]]; then
  sudo systemctl daemon-reload || true
  if systemctl is-active --quiet ollama 2>/dev/null; then
    sudo systemctl restart ollama || true
  fi
fi

sudo rm -f /etc/profile.d/ranch-proxy.sh
if [[ -f /etc/environment ]]; then
  sudo sed -i -E '/^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|no_proxy|NO_PROXY)=/d' /etc/environment
fi

if [[ -f /etc/pip/pip.conf ]] && grep -q 'ranch-choir-squid' /etc/pip/pip.conf 2>/dev/null; then
  sudo rm -f /etc/pip/pip.conf
fi
# Older client revisions wrote /etc/pip/pip.conf with a static proxy and no marker.
if [[ -f /etc/pip/pip.conf ]] && grep -q 'files.pythonhosted.org' /etc/pip/pip.conf 2>/dev/null; then
  sudo rm -f /etc/pip/pip.conf
fi

if command -v npm >/dev/null 2>&1; then
  npm config delete proxy --global 2>/dev/null || true
  npm config delete https-proxy --global 2>/dev/null || true
  npm config delete cafile --global 2>/dev/null || true
  npm config delete noproxy --global 2>/dev/null || true
fi

echo "Done. This node is direct. Open a new login shell to drop proxy variables."
