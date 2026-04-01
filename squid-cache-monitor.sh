#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Cache Monitor
# ============================================================================
# Quick dashboard for Squid cache health and hit rates.
# Usage: bash cache-monitor.sh
# ============================================================================

echo "============================================"
echo "  Ranch Choir Cache Status"
echo "  $(date)"
echo "============================================"
echo ""

# Hit ratio
echo "--- Cache Hit Ratio (5 min / 60 min) ---"
squidclient -h localhost mgr:5min 2>/dev/null | grep -E "client_http\.(hits|requests|kbytes)" || echo "  (squidclient not available)"
echo ""

# Disk usage
echo "--- Disk Cache Usage ---"
CACHE_DIR="/var/spool/squid"
if [[ -d "${CACHE_DIR}" ]]; then
    USED=$(du -sh "${CACHE_DIR}" 2>/dev/null | awk '{print $1}')
    echo "  Cache directory: ${USED} used"
fi
echo ""

# Largest cached objects (useful for confirming model caching)
echo "--- Recent Large Objects Cached ---"
if [[ -f /var/log/squid/store.log ]]; then
    # Show objects > 100MB cached recently
    awk '$5 > 104857600 {printf "  %s  %.0f MB  %s\n", $1, $5/1048576, $13}' \
        /var/log/squid/store.log | tail -10
    COUNT=$(awk '$5 > 104857600' /var/log/squid/store.log 2>/dev/null | wc -l)
    echo "  (${COUNT} objects > 100 MB in store log)"
else
    echo "  (store.log not found)"
fi
echo ""

# Live connections
echo "--- Active Connections ---"
squidclient -h localhost mgr:active_requests 2>/dev/null | head -5 || echo "  (unavailable)"
echo ""

# Memory usage
echo "--- Memory Usage ---"
squidclient -h localhost mgr:mem 2>/dev/null | grep -E "Total|Free|Cached" | head -5 || echo "  (unavailable)"
echo ""

echo "============================================"
echo "  Live access log (Ctrl+C to stop):"
echo "============================================"
echo ""
# Color-coded: green for HIT, red for MISS
tail -f /var/log/squid/access.log 2>/dev/null | \
    sed -e 's/TCP_HIT/\x1b[32mTCP_HIT\x1b[0m/g' \
        -e 's/TCP_MEM_HIT/\x1b[32;1mTCP_MEM_HIT\x1b[0m/g' \
        -e 's/TCP_MISS/\x1b[31mTCP_MISS\x1b[0m/g' \
        -e 's/TCP_TUNNEL/\x1b[33mTCP_TUNNEL\x1b[0m/g'
