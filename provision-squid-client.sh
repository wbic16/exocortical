#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Squid — client for this node's USB4 chain
# ============================================================================
# Usage:
#   sudo bash provision-squid-client.sh auto      # default
#   sudo bash provision-squid-client.sh           # same as auto
#   sudo bash provision-squid-client.sh <IP>      # explicit proxy
#
# auto selects http://10.53.R.1 for the chain derived from tbfab (or, if the
# bridge is down, from this hostname's TB_MAP line in tb-setup.sh). A proxy
# host provisioning itself uses its own tbfab address, which is 10.53.R.1.
#
# Chain 7 has no proxy. Those nodes are left direct and this script exits 0.
#
# A dead chain proxy must not wedge the node:
#   apt    Acquire::{http,https}::Proxy-Auto-Detect (DIRECT if the port is down)
#   shells /etc/profile.d exports proxy vars only after a successful probe
#   ollama ExecStartPre rewrites /run/ranch-proxy.env; empty file => direct
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=squid-chains.conf
source "${SCRIPT_DIR}/squid-chains.conf"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 auto" >&2
  exit 1
fi

# A previous /etc/environment pin is already in this process (sudo/pam_env).
# Drop it before any fetch. The CA is downloaded directly, not via the proxy.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY || true

TARGET="${1:-auto}"
CA_LOCAL="/usr/local/share/ca-certificates/ranch-choir-squid-ca.crt"
CLIENT_ENV="/etc/ranch-squid/client.env"

strip_static_environment() {
  if [[ -f /etc/environment ]]; then
    sed -i -E '/^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|no_proxy|NO_PROXY)=/d' /etc/environment
  fi
}

install_helpers() {
  install -d -m 755 /usr/local/bin /etc/ranch-squid
  install -m 755 "${SCRIPT_DIR}/ranch-proxy-autodetect" /usr/local/bin/ranch-proxy-autodetect
  install -m 755 "${SCRIPT_DIR}/ranch-proxy-ollama-env" /usr/local/bin/ranch-proxy-ollama-env
  install -m 644 "${SCRIPT_DIR}/ranch-proxy.profile.sh" /etc/profile.d/ranch-proxy.sh
}

write_client_env() {
  local ip="$1" chain="$2"
  cat > "${CLIENT_ENV}" << EOF
SQUID_IP=${ip}
SQUID_HTTP_PORT=${SQUID_HTTP_PORT}
SQUID_SSL_PORT=${SQUID_SSL_PORT}
SQUID_CHAIN=${chain}
NO_PROXY_LIST=${SQUID_NO_PROXY_LIST}
EOF
  chmod 644 "${CLIENT_ENV}"
}

write_apt_autodetect() {
  cat > /etc/apt/apt.conf.d/02ranch-proxy << 'EOF'
// Ranch Choir per-chain Squid. The helper prints DIRECT when the port is down.
Acquire::http::Proxy-Auto-Detect "/usr/local/bin/ranch-proxy-autodetect";
Acquire::https::Proxy-Auto-Detect "/usr/local/bin/ranch-proxy-autodetect";
EOF
}

write_ollama_dropin() {
  local dir="/etc/systemd/system/ollama.service.d"
  mkdir -p "${dir}"
  cat > "${dir}/proxy.conf" << 'EOF'
[Service]
ExecStartPre=-+/usr/local/bin/ranch-proxy-ollama-env
EnvironmentFile=-/run/ranch-proxy.env
Environment=OLLAMA_NOPRUNE=1
EOF
  if squid_have_systemd; then
    systemctl daemon-reload
    if systemctl is-active --quiet ollama 2>/dev/null; then
      systemctl restart ollama || true
      echo "  -> Ollama restarted; proxy env is probed at start."
    else
      echo "  -> Ollama drop-in written (service not running)."
    fi
  else
    echo "  -> systemd is not running; Ollama drop-in is installed but not reloaded."
  fi
}

write_pip() {
  # No static proxy= line. pip follows the shell environment, which is empty
  # when the probe fails. trusted-host is required because pip uses certifi
  # and will not trust a bumped PyPI certificate otherwise.
  mkdir -p /etc/pip
  cat > /etc/pip/pip.conf << 'EOF'
# ranch-choir-squid
# Proxy comes from http_proxy/https_proxy (set only while the chain proxy answers).
[global]
trusted-host = pypi.org
               files.pythonhosted.org
EOF
}

clear_npm_pin() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "  -> npm not installed, skipping."
    return 0
  fi
  # A static proxy or cafile would override the shell probe and break npm
  # (cafile replaces the public CA bundle) when the proxy is down or direct.
  npm config delete proxy --global 2>/dev/null || true
  npm config delete https-proxy --global 2>/dev/null || true
  npm config delete cafile --global 2>/dev/null || true
  npm config set noproxy "${SQUID_NO_PROXY_LIST}" --global 2>/dev/null || true
  echo "  -> npm left to the shell probe (no static proxy pin)."
}

port_open() {
  local ip="$1" port="$2"
  timeout 1 bash -c "echo >/dev/tcp/${ip}/${port}" 2>/dev/null
}

SQUID_IP=""
SQUID_CHAIN=""

if [[ "${TARGET}" == "auto" ]]; then
  if ! SQUID_CHAIN="$(squid_detect_chain)"; then
    echo "ERROR: cannot determine this node's USB4 chain." >&2
    echo "tbfab has no 10.53.R.C address and $(hostname -s) is not in tb-setup.sh TB_MAP." >&2
    exit 1
  fi
  if ! SQUID_IP="$(squid_proxy_ip_for_chain "${SQUID_CHAIN}")"; then
    echo "Chain ${SQUID_CHAIN} has no caching proxy."
    echo "Chains 1-6 each use 10.53.R.1. Chain 7 (chrysalis-hub, uncanny-valley) stays direct."
    echo "Leaving this node DIRECT."
    bash "${SCRIPT_DIR}/squid-uninstall-client.sh"
    exit 0
  fi
elif [[ "${TARGET}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  SQUID_IP="${TARGET}"
  SQUID_CHAIN="$(squid_chain_from_ip "${SQUID_IP}" || true)"
  SQUID_CHAIN="${SQUID_CHAIN:-explicit}"
else
  echo "Usage: sudo bash $0 [auto|IP]" >&2
  echo "  auto is the default and selects 10.53.<chain>.1 for this node." >&2
  exit 1
fi

PROXY_HTTP="http://${SQUID_IP}:${SQUID_HTTP_PORT}"
PROXY_SSL="http://${SQUID_IP}:${SQUID_SSL_PORT}"

echo "============================================"
echo "  Ranch Choir Client Proxy Setup"
echo "============================================"
echo "  Mode:         ${TARGET}"
echo "  Chain:        ${SQUID_CHAIN}"
echo "  HTTP Proxy:   ${PROXY_HTTP}"
echo "  SSL Proxy:    ${PROXY_SSL}"
echo "============================================"
echo ""

strip_static_environment
install_helpers
write_client_env "${SQUID_IP}" "${SQUID_CHAIN}"
write_apt_autodetect
write_pip
clear_npm_pin
write_ollama_dropin

# Generate the runtime file once so a start before the next boot is coherent.
/usr/local/bin/ranch-proxy-ollama-env || true

echo "[1/3] Chain proxy reachability..."
if ! port_open "${SQUID_IP}" "${SQUID_HTTP_PORT}"; then
  echo "  Proxy ${SQUID_IP}:${SQUID_HTTP_PORT} did not answer within 1s."
  echo "  Fail-open config is installed: apt, shells, and Ollama stay direct"
  echo "  until the proxy answers. The CA is not trusted yet."
  echo "  Re-run this script when the chain proxy is up."
  echo "============================================"
  exit 0
fi
echo "  -> ${SQUID_IP}:${SQUID_HTTP_PORT} is answering."

echo "[2/3] Installing this chain's Squid CA..."
CA_URL="http://${SQUID_IP}/squid-ca-cert.crt"
if ! curl --noproxy '*' -fsS --max-time 10 "${CA_URL}" -o "${CA_LOCAL}"; then
  echo "  ERROR: proxy is up but the CA cert could not be downloaded from ${CA_URL}" >&2
  echo "  HTTPS bump will fail until the cert is installed. Re-run when nginx is serving it." >&2
  exit 1
fi
update-ca-certificates
echo "  -> CA certificate trusted."

echo "[3/3] Probing through the proxy (non-fatal)..."
if curl -fsS --max-time 20 --proxy "${PROXY_HTTP}" -o /dev/null http://archive.ubuntu.com/ubuntu/dists/noble/Release; then
  echo "  -> apt archive (HTTP): OK"
else
  echo "  -> apt archive (HTTP): skipped or failed (non-fatal)"
fi
if curl -fsS --max-time 20 --proxy "${PROXY_SSL}" --cacert "${CA_LOCAL}" -o /dev/null https://registry.ollama.ai/v2/; then
  echo "  -> Ollama registry (HTTPS bump): OK"
else
  echo "  -> Ollama registry (HTTPS bump): skipped or failed (non-fatal)"
fi

echo ""
echo "============================================"
echo "  Client provisioned"
echo "============================================"
echo "  apt and new login shells use ${SQUID_IP} only while it answers."
echo "  NO_PROXY=${SQUID_NO_PROXY_LIST}"
echo "  Ollama reads /run/ranch-proxy.env, rewritten every start."
echo "============================================"
