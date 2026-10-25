#!/usr/bin/env bash
# Enable npm to use this node's chain Squid without pinning a dead proxy.
#
# Usage: bash enable-npm-proxy.sh [auto|IP]
#   auto (default) selects 10.53.<chain>.1
#
# npm has no per-request auto-detect. A static npmrc proxy breaks installs
# when the chain proxy is down, and npm's cafile replaces the public CA set.
# This script removes those pins. Login shells export the proxy only when
# provision-squid-client.sh's probe succeeds, and NODE_EXTRA_CA_CERTS adds
# the chain CA without dropping public CAs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=squid-chains.conf
source "${SCRIPT_DIR}/squid-chains.conf"

TARGET="${1:-auto}"
CA_LOCAL="/usr/local/share/ca-certificates/ranch-choir-squid-ca.crt"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is not installed." >&2
  exit 1
fi

clear_pins() {
  npm config delete proxy --global 2>/dev/null || true
  npm config delete https-proxy --global 2>/dev/null || true
  npm config delete cafile --global 2>/dev/null || true
  npm config set noproxy "${SQUID_NO_PROXY_LIST}" --global
}

SQUID_IP=""
if [[ "${TARGET}" == "auto" ]]; then
  chain="$(squid_detect_chain || true)"
  if [[ -z "${chain}" ]]; then
    echo "ERROR: cannot determine this node's USB4 chain." >&2
    exit 1
  fi
  if ! SQUID_IP="$(squid_proxy_ip_for_chain "${chain}")"; then
    echo "Chain ${chain} has no caching proxy. npm stays direct."
    clear_pins
    exit 0
  fi
elif [[ "${TARGET}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  SQUID_IP="${TARGET}"
else
  echo "Usage: $0 [auto|IP]" >&2
  exit 1
fi

clear_pins

if [[ ! -r "${CA_LOCAL}" ]]; then
  echo "Squid CA is not installed at ${CA_LOCAL}." >&2
  echo "Run: sudo bash provision-squid-client.sh auto" >&2
  exit 1
fi

export NODE_EXTRA_CA_CERTS="${CA_LOCAL}"
http_url=""
https_url=""
if timeout 1 bash -c "echo >/dev/tcp/${SQUID_IP}/${SQUID_HTTP_PORT}" 2>/dev/null; then
  http_url="http://${SQUID_IP}:${SQUID_HTTP_PORT}"
fi
if timeout 1 bash -c "echo >/dev/tcp/${SQUID_IP}/${SQUID_SSL_PORT}" 2>/dev/null; then
  https_url="http://${SQUID_IP}:${SQUID_SSL_PORT}"
fi

if [[ -z "${https_url}" ]]; then
  echo "Chain proxy ${SQUID_IP}:${SQUID_SSL_PORT} is not answering. npm stays direct."
  exit 0
fi

export http_proxy="${http_url:-${https_url}}"
export HTTP_PROXY="${http_proxy}"
export https_proxy="${https_url}"
export HTTPS_PROXY="${https_url}"
export no_proxy="${SQUID_NO_PROXY_LIST}"
export NO_PROXY="${SQUID_NO_PROXY_LIST}"

echo "npm will use ${https_url} via the environment when the proxy answers."
echo "noproxy=${SQUID_NO_PROXY_LIST}"
npm config get noproxy
if ! npm view openclaw version; then
  echo "npm view through the proxy failed (non-fatal). Direct npm still works in a new shell if the proxy is down." >&2
fi
