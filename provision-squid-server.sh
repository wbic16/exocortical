#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Squid Caching Proxy - Server Provisioning
# ============================================================================
# Aggressively caches:
#   - Ollama model registry pulls (HTTPS, multi-GB blobs)
#   - apt/deb packages
#   - pip packages, npm packages, general HTTP(S)
#
# After the first node downloads a resource, all subsequent nodes pull
# from local cache at LAN speed.
#
# Usage: sudo bash provision-squid-server.sh [LISTEN_IP]
#   LISTEN_IP defaults to 0.0.0.0 (all interfaces)
# ============================================================================
set -euo pipefail

LISTEN_IP="${1:-0.0.0.0}"
SQUID_PORT=3128
SQUID_SSL_PORT=3129
CACHE_DIR="/var/spool/squid"
CACHE_DISK_MB=2097152      # 2 TB disk cache -- tune to your drive
CACHE_MEM_MB=2048          # 2 GB RAM cache
MAX_OBJ_SIZE_MB=102400     # 100 GB max single object (large models)
MAX_OBJ_MEM_MB=256         # 256 MB max object kept in RAM
SSL_DB="/var/lib/squid/ssl_db"
CA_DIR="/etc/squid/ssl"
CA_CERT="${CA_DIR}/squid-ca-cert.pem"
CA_KEY="${CA_DIR}/squid-ca-key.pem"
CA_DER="${CA_DIR}/squid-ca-cert.der"
EXPORT_CERT="/var/www/html/squid-ca-cert.crt"

echo "============================================"
echo "  Ranch Choir Squid Cache Server Setup"
echo "============================================"
echo "Listen IP:       ${LISTEN_IP}"
echo "HTTP Port:       ${SQUID_PORT}"
echo "SSL Bump Port:   ${SQUID_SSL_PORT}"
echo "Disk Cache:      ${CACHE_DISK_MB} MB"
echo "RAM Cache:       ${CACHE_MEM_MB} MB"
echo "Max Object Size: ${MAX_OBJ_SIZE_MB} MB"
echo "============================================"

# -----------------------------------------------------------
# 1. Install packages
# -----------------------------------------------------------
echo "[1/7] Installing squid and dependencies..."
apt-get update -qq
apt-get install -y squid-openssl openssl nginx-light

# -----------------------------------------------------------
# 2. Generate CA certificate for SSL bumping
# -----------------------------------------------------------
echo "[2/7] Generating CA certificate for SSL interception..."
mkdir -p "${CA_DIR}"

if [[ ! -f "${CA_KEY}" ]]; then
    openssl req -new -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -x509 -extensions v3_ca \
        -keyout "${CA_KEY}" \
        -out "${CA_CERT}" \
        -subj "/C=US/ST=Nebraska/L=Ranch/O=RanchChoir/OU=ExocortexCache/CN=Ranch Choir Squid CA"

    # DER format for easy client import
    openssl x509 -in "${CA_CERT}" -outform DER -out "${CA_DER}"
    echo "  -> New CA generated."
else
    echo "  -> Existing CA found, reusing."
fi

# Make cert downloadable via HTTP for client provisioning
mkdir -p /var/www/html
cp "${CA_CERT}" "${EXPORT_CERT}"
chmod 644 "${EXPORT_CERT}"

# -----------------------------------------------------------
# 3. Initialize SSL certificate database
# -----------------------------------------------------------
echo "[3/7] Initializing SSL certificate database..."
rm -rf "${SSL_DB}"
mkdir -p "${SSL_DB}"
/usr/lib/squid/security_file_certgen -c -s "${SSL_DB}" -M 64MB
chown -R proxy:proxy "${SSL_DB}"

# -----------------------------------------------------------
# 4. Prepare cache directory
# -----------------------------------------------------------
echo "[4/7] Preparing cache directory..."
mkdir -p "${CACHE_DIR}"
chown -R proxy:proxy "${CACHE_DIR}"

# -----------------------------------------------------------
# 5. Write squid.conf
# -----------------------------------------------------------
echo "[5/7] Writing squid.conf..."

cat > /etc/squid/squid.conf << SQUIDEOF
# ============================================================================
# Ranch Choir Aggressive Caching Proxy
# ============================================================================

# -- Ports ------------------------------------------------------------------
http_port ${LISTEN_IP}:${SQUID_PORT}
http_port ${LISTEN_IP}:${SQUID_SSL_PORT} ssl-bump \
    cert=${CA_CERT} \
    key=${CA_KEY} \
    generate-host-certificates=on \
    dynamic_cert_mem_cache_size=16MB \
    tls-default-ca=off

sslcrtd_program /usr/lib/squid/security_file_certgen -s ${SSL_DB} -M 64MB
sslcrtd_children 8 startup=2 idle=2

# -- ACLs -------------------------------------------------------------------
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 11434        # Ollama API
acl CONNECT method CONNECT

# Domains we care about caching
acl ollama_registry dstdomain registry.ollama.ai
acl ollama_cdn dstdomain .ollama.ai .amazonaws.com .cloudfront.net
acl apt_repos dstdomain .ubuntu.com .debian.org .launchpad.net
acl pypi_repos dstdomain pypi.org files.pythonhosted.org
acl npm_repos dstdomain registry.npmjs.org
acl crates_repos dstdomain crates.io static.crates.io index.crates.io

# -- SSL Bump ---------------------------------------------------------------
# Bump (intercept) traffic to cacheable domains; splice everything else
acl bump_targets dstdomain registry.ollama.ai
acl bump_targets dstdomain .ollama.ai
acl bump_targets dstdomain .amazonaws.com
acl bump_targets dstdomain .cloudfront.net
acl bump_targets dstdomain files.pythonhosted.org
acl bump_targets dstdomain registry.npmjs.org
acl bump_targets dstdomain static.crates.io

ssl_bump bump bump_targets
ssl_bump splice all

# -- Access Control ---------------------------------------------------------
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access allow localhost
http_access deny all

# -- Cache Storage ----------------------------------------------------------
cache_dir aufs ${CACHE_DIR} ${CACHE_DISK_MB} 16 256
cache_mem ${CACHE_MEM_MB} MB
maximum_object_size ${MAX_OBJ_SIZE_MB} MB
maximum_object_size_in_memory ${MAX_OBJ_MEM_MB} MB

# -- Cache Behavior ---------------------------------------------------------
# Be aggressive: ignore origin server cache-control for known-good domains
cache allow all
send_hit deny none

# Strip/ignore headers that prevent caching
ignore_no_cache allow all
ignore_private  allow all
ignore_no_store allow all

# Aggressively override freshness for specific content types

# Ollama model blobs - cache for 90 days, always serve from cache
# Model digests are content-addressed (sha256), so they never change
refresh_pattern -i registry\.ollama\.ai       129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-no-store ignore-private
refresh_pattern -i \.ollama\.ai               129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-no-store ignore-private
refresh_pattern -i /v2/.*/blobs/sha256        129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-no-store ignore-private
refresh_pattern -i /v2/.*/manifests/          1440    90%   10080   override-expire reload-into-ims ignore-no-cache ignore-no-store

# apt/deb packages - cache aggressively
refresh_pattern -i \.deb$                     129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-private
refresh_pattern -i \.udeb$                    129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-private
refresh_pattern -i Packages\.(bz2|gz|xz|zst)$ 0      20%   2880
refresh_pattern -i Sources\.(bz2|gz|xz|zst)$  0      20%   2880
refresh_pattern -i Release(\.gpg)?$            0      20%   2880
refresh_pattern -i InRelease$                  0      20%   2880
refresh_pattern -i Translation-.*\.(bz2|gz|xz)$ 0    20%   2880

# pip wheels and tarballs
refresh_pattern -i \.(whl|tar\.gz|zip)$       129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-private

# npm tarballs
refresh_pattern -i \.tgz$                     129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-private

# Crates
refresh_pattern -i \.crate$                   129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-cache ignore-private

# General fallback
refresh_pattern .                             0       20%   4320

# -- Performance Tuning -----------------------------------------------------
# Range request handling (important for large model downloads)
range_offset_limit -1           # Always fetch full object (enables caching of partial requests)
quick_abort_min -1              # Never abort a download in progress

# Connection settings
connect_timeout 60 seconds
read_timeout 600 seconds        # Long timeout for large model pulls
client_lifetime 24 hours
pconn_timeout 300 seconds

# Workers (tune to CPU cores)
workers 4

# -- Logging ----------------------------------------------------------------
access_log daemon:/var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log daemon:/var/log/squid/store.log

# Log cache hits/misses clearly
logformat combined %>a %[ui %[un [%tl] "%rm %ru HTTP/%rv" %>Hs %<st "%{Referer}>h" "%{User-Agent}>h" %Ss:%Sh

# -- Misc -------------------------------------------------------------------
visible_hostname ranch-choir-cache
cache_mgr exocortex@ranch.local
dns_nameservers 1.1.1.1 8.8.8.8
coredump_dir /var/spool/squid
SQUIDEOF

# -----------------------------------------------------------
# 6. Initialize and start squid
# -----------------------------------------------------------
echo "[6/7] Initializing squid cache and starting service..."
squid -z --foreground 2>/dev/null || true
systemctl restart squid
systemctl enable squid

# Start nginx for serving the CA cert
systemctl restart nginx
systemctl enable nginx

# -----------------------------------------------------------
# 7. Firewall rules (if ufw is active)
# -----------------------------------------------------------
echo "[7/7] Configuring firewall..."
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    ufw allow ${SQUID_PORT}/tcp comment "Squid HTTP proxy"
    ufw allow ${SQUID_SSL_PORT}/tcp comment "Squid SSL bump proxy"
    ufw allow 80/tcp comment "Nginx CA cert download"
    echo "  -> UFW rules added."
else
    echo "  -> UFW not active, skipping."
fi

# -----------------------------------------------------------
# Done
# -----------------------------------------------------------
SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo "  Squid Cache Server is LIVE"
echo "============================================"
echo ""
echo "  Server IP:    ${SERVER_IP}"
echo "  HTTP Proxy:   http://${SERVER_IP}:${SQUID_PORT}"
echo "  SSL Proxy:    http://${SERVER_IP}:${SQUID_SSL_PORT}"
echo "  CA Cert URL:  http://${SERVER_IP}/squid-ca-cert.crt"
echo ""
echo "  Cache stats:  squidclient -h localhost mgr:info"
echo "  Hit ratio:    squidclient -h localhost mgr:utilization"
echo ""
echo "  Next: run provision-squid-client.sh on each node."
echo "============================================"
