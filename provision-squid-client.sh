#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Squid Caching Proxy - Client Provisioning
# ============================================================================
# Configures an Ubuntu node to route apt, ollama, pip, and general HTTP(S)
# traffic through the Ranch Choir Squid cache server.
#
# Usage: sudo bash provision-squid-client.sh <SQUID_SERVER_IP>
#
# What this does:
#   1. Downloads and trusts the Squid CA certificate (for SSL bump)
#   2. Configures apt to use the proxy
#   3. Configures Ollama to use the proxy
#   4. Sets system-wide proxy environment variables
#   5. Configures pip and npm to use the proxy
# ============================================================================
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: sudo $0 <SQUID_SERVER_IP>"
    echo "  Example: sudo $0 192.168.1.10"
    exit 1
fi

SQUID_IP="$1"
SQUID_HTTP_PORT=3128
SQUID_SSL_PORT=3129
PROXY_HTTP="http://${SQUID_IP}:${SQUID_HTTP_PORT}"
PROXY_SSL="http://${SQUID_IP}:${SQUID_SSL_PORT}"

echo "============================================"
echo "  Ranch Choir Client Proxy Setup"
echo "============================================"
echo "  Squid Server: ${SQUID_IP}"
echo "  HTTP Proxy:   ${PROXY_HTTP}"
echo "  SSL Proxy:    ${PROXY_SSL}"
echo "============================================"
echo ""

# -----------------------------------------------------------
# 1. Install and trust the Squid CA certificate
# -----------------------------------------------------------
echo "[1/6] Installing Squid CA certificate..."
CA_URL="http://${SQUID_IP}/squid-ca-cert.crt"
CA_LOCAL="/usr/local/share/ca-certificates/ranch-choir-squid-ca.crt"

if ! curl -sf "${CA_URL}" -o "${CA_LOCAL}"; then
    echo "  ERROR: Could not download CA cert from ${CA_URL}"
    echo "  Make sure the Squid server is provisioned and nginx is running."
    exit 1
fi

update-ca-certificates
echo "  -> CA certificate trusted."

# -----------------------------------------------------------
# 2. Configure apt to use proxy
# -----------------------------------------------------------
echo "[2/6] Configuring apt proxy..."
cat > /etc/apt/apt.conf.d/02ranch-proxy << EOF
// Ranch Choir Squid Cache Proxy
Acquire::http::Proxy "${PROXY_HTTP}";
Acquire::https::Proxy "${PROXY_SSL}";
EOF
echo "  -> apt proxy configured."

# -----------------------------------------------------------
# 3. Configure Ollama to use proxy
# -----------------------------------------------------------
echo "[3/6] Configuring Ollama proxy..."

# Method A: systemd override (for Ollama installed as a service)
OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
mkdir -p "${OLLAMA_OVERRIDE_DIR}"
cat > "${OLLAMA_OVERRIDE_DIR}/proxy.conf" << EOF
[Service]
Environment="HTTP_PROXY=${PROXY_HTTP}"
Environment="HTTPS_PROXY=${PROXY_SSL}"
Environment="http_proxy=${PROXY_HTTP}"
Environment="https_proxy=${PROXY_SSL}"
Environment="NO_PROXY=localhost,127.0.0.1,${SQUID_IP}"
Environment="OLLAMA_NOPRUNE=1"
EOF

# Reload and restart Ollama if it's running
if systemctl is-active --quiet ollama 2>/dev/null; then
    systemctl daemon-reload
    systemctl restart ollama
    echo "  -> Ollama service restarted with proxy."
else
    systemctl daemon-reload
    echo "  -> Ollama systemd override written (service not currently running)."
fi

# -----------------------------------------------------------
# 4. System-wide proxy environment
# -----------------------------------------------------------
echo "[4/6] Setting system-wide proxy environment..."
cat > /etc/profile.d/ranch-proxy.sh << EOF
# Ranch Choir Squid Cache Proxy
export http_proxy="${PROXY_HTTP}"
export https_proxy="${PROXY_SSL}"
export HTTP_PROXY="${PROXY_HTTP}"
export HTTPS_PROXY="${PROXY_SSL}"
export no_proxy="localhost,127.0.0.1,${SQUID_IP}"
export NO_PROXY="localhost,127.0.0.1,${SQUID_IP}"
EOF
chmod 644 /etc/profile.d/ranch-proxy.sh

# Also write to /etc/environment for non-login shells
grep -q "http_proxy=" /etc/environment 2>/dev/null && \
    sed -i '/.*_proxy=/Id' /etc/environment

cat >> /etc/environment << EOF
http_proxy="${PROXY_HTTP}"
https_proxy="${PROXY_SSL}"
HTTP_PROXY="${PROXY_HTTP}"
HTTPS_PROXY="${PROXY_SSL}"
no_proxy="localhost,127.0.0.1,${SQUID_IP}"
NO_PROXY="localhost,127.0.0.1,${SQUID_IP}"
EOF
echo "  -> System environment configured."

# -----------------------------------------------------------
# 5. Configure pip and npm
# -----------------------------------------------------------
echo "[5/6] Configuring pip and npm..."

# pip - global config
PIP_CONF_DIR="/etc/pip"
mkdir -p "${PIP_CONF_DIR}"
cat > "${PIP_CONF_DIR}/pip.conf" << EOF
[global]
proxy = ${PROXY_SSL}
trusted-host = pypi.org
               files.pythonhosted.org
EOF
echo "  -> pip configured."

# npm - global config (if npm is installed)
if command -v npm &>/dev/null; then
    npm config set proxy "${PROXY_HTTP}" --global 2>/dev/null || true
    npm config set https-proxy "${PROXY_SSL}" --global 2>/dev/null || true
    echo "  -> npm configured."
else
    echo "  -> npm not found, skipping."
fi

# -----------------------------------------------------------
# 6. Verify connectivity through proxy
# -----------------------------------------------------------
echo "[6/6] Verifying proxy connectivity..."

# Source the env vars for this session
export http_proxy="${PROXY_HTTP}"
export https_proxy="${PROXY_SSL}"

VERIFY_OK=true

# Test HTTP through proxy
if curl -sf --proxy "${PROXY_HTTP}" -o /dev/null http://archive.ubuntu.com/ubuntu/dists/noble/Release 2>/dev/null; then
    echo "  -> apt repos (HTTP): OK"
else
    echo "  -> apt repos (HTTP): FAILED (non-fatal, may need different Ubuntu version)"
fi

# Test HTTPS through SSL bump proxy
if curl -sf --proxy "${PROXY_SSL}" -o /dev/null https://registry.ollama.ai/v2/library/qwen3/manifests/latest 2>/dev/null; then
    echo "  -> Ollama registry (HTTPS): OK"
else
    echo "  -> Ollama registry (HTTPS): FAILED"
    echo "     Check CA cert trust and Squid SSL bump config."
    VERIFY_OK=false
fi

if curl -sf --proxy "${PROXY_SSL}" -o /dev/null https://pypi.org/simple/ 2>/dev/null; then
    echo "  -> PyPI (HTTPS): OK"
else
    echo "  -> PyPI (HTTPS): SKIPPED"
fi

# -----------------------------------------------------------
# Done
# -----------------------------------------------------------
echo ""
echo "============================================"
echo "  Client Provisioned Successfully"
echo "============================================"
echo ""
echo "  This node now routes through the cache:"
echo "    apt install  -> cached .deb packages"
echo "    ollama pull  -> cached model blobs"
echo "    pip install  -> cached wheels"
echo "    npm install  -> cached tarballs"
echo ""
echo "  To verify cache hits, on the server run:"
echo "    tail -f /var/log/squid/access.log | grep HIT"
echo ""
if [[ "${VERIFY_OK}" == false ]]; then
    echo "  WARNING: Some connectivity checks failed."
    echo "  You may need to reboot or re-source your shell."
fi
echo "  Tip: log out and back in (or reboot) to pick"
echo "  up the proxy environment variables everywhere."
echo "============================================"
