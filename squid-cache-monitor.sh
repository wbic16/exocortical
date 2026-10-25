#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Cache Monitor
# ============================================================================
# Shows the client fail-open pieces and, when this host is a proxy, cache
# hit rate and disk use.
# Usage: bash squid-cache-monitor.sh
# ============================================================================

echo "============================================"
echo "  Ranch Choir Cache Status"
echo "  $(date)"
echo "============================================"
echo ""

echo "--- Client failover ---"
if [[ -r /etc/ranch-squid/client.env ]]; then
  # shellcheck disable=SC1091
  source /etc/ranch-squid/client.env
  echo "  chain: ${SQUID_CHAIN:-?}  proxy: ${SQUID_IP:-?}:${SQUID_HTTP_PORT:-3128} / ssl ${SQUID_SSL_PORT:-3129}"
  if [[ -x /usr/local/bin/ranch-proxy-autodetect ]]; then
    echo "  http probe:  $(/usr/local/bin/ranch-proxy-autodetect http 2>/dev/null || echo failed)"
    echo "  https probe: $(/usr/local/bin/ranch-proxy-autodetect https 2>/dev/null || echo failed)"
  fi
else
  echo "  no /etc/ranch-squid/client.env (not provisioned, or this chain stays direct)"
fi

client_files=(
  /usr/local/bin/ranch-proxy-autodetect
  /usr/local/bin/ranch-proxy-ollama-env
  /etc/apt/apt.conf.d/02ranch-proxy
  /etc/profile.d/ranch-proxy.sh
  /etc/systemd/system/ollama.service.d/proxy.conf
  /usr/local/share/ca-certificates/ranch-choir-squid-ca.crt
  /etc/pip/pip.conf
  /etc/ranch-squid/client.env
  /run/ranch-proxy.env
)
for f in "${client_files[@]}"; do
  if [[ -e "${f}" ]]; then
    echo "  present  ${f}"
  else
    echo "  absent   ${f}"
  fi
done
if [[ -r /run/ranch-proxy.env ]]; then
  echo "  /run/ranch-proxy.env:"
  sed 's/^/    /' /run/ranch-proxy.env
fi
echo ""

echo "--- Cache Hit Ratio (manager) ---"
if command -v squidclient >/dev/null 2>&1; then
  if ! squidclient -h 127.0.0.1 mgr:info 2>/dev/null | grep -i "Hit Ratio"; then
    echo "  (squidclient could not read mgr:info)"
  fi
  echo "  5 min counters:"
  squidclient -h 127.0.0.1 mgr:5min 2>/dev/null | grep -E "client_http\.(hits|requests|kbytes)" || true
else
  echo "  (squidclient not available)"
fi
echo ""

echo "--- Disk Cache Usage ---"
CACHE_DIR="/var/spool/squid"
if [[ -d "${CACHE_DIR}" ]]; then
  USED="$(du -sh "${CACHE_DIR}" 2>/dev/null | awk '{print $1}')"
  echo "  Cache directory: ${USED:-?} used"
else
  echo "  (no ${CACHE_DIR} — this host is not a cache server)"
fi
echo ""

echo "--- Recent Large Objects Cached ---"
if [[ -f /var/log/squid/store.log ]]; then
  awk '$5 > 104857600 {printf "  %s  %.0f MB  %s\n", $1, $5/1048576, $13}' \
    /var/log/squid/store.log | tail -10
  COUNT="$(awk '$5 > 104857600' /var/log/squid/store.log 2>/dev/null | wc -l)"
  echo "  (${COUNT} objects > 100 MB in store log)"
else
  echo "  (store.log not found)"
fi
echo ""

echo "--- Active Connections ---"
if command -v squidclient >/dev/null 2>&1; then
  squidclient -h 127.0.0.1 mgr:active_requests 2>/dev/null | head -5 || echo "  (unavailable)"
else
  echo "  (unavailable)"
fi
echo ""

echo "--- Memory Usage ---"
if command -v squidclient >/dev/null 2>&1; then
  squidclient -h 127.0.0.1 mgr:mem 2>/dev/null | grep -E "Total|Free|Cached" | head -5 || echo "  (unavailable)"
else
  echo "  (unavailable)"
fi
echo ""

if [[ -r /var/log/squid/access.log ]]; then
  echo "============================================"
  echo "  Live access log (Ctrl+C to stop):"
  echo "============================================"
  echo ""
  tail -f /var/log/squid/access.log | \
    sed -e 's/TCP_HIT/\x1b[32mTCP_HIT\x1b[0m/g' \
        -e 's/TCP_MEM_HIT/\x1b[32;1mTCP_MEM_HIT\x1b[0m/g' \
        -e 's/TCP_MISS/\x1b[31mTCP_MISS\x1b[0m/g' \
        -e 's/TCP_TUNNEL/\x1b[33mTCP_TUNNEL\x1b[0m/g'
else
  echo "(no access log; nothing to follow)"
fi
