#!/usr/bin/env bash
# ============================================================================
# Ranch Choir Squid Caching Proxy — one server per USB4 chain
# ============================================================================
# Run this on the C=1 node of a chain (see squid-chains.conf):
#   chain 1 ni-knight         10.53.1.1
#   chain 2 orchid-flow       10.53.2.1
#   chain 3 plain-view        10.53.3.1
#   chain 4 aletheia-core     10.53.4.1
#   chain 5 aurora-continuum  10.53.5.1
#   chain 6 yeet-max          10.53.6.1
#
# Each host generates its own CA. The private key stays on that host.
# Clients trust only the CA of their own chain proxy.
#
# Usage:
#   sudo bash provision-squid-server.sh [LISTEN_IP]
# LISTEN_IP defaults to this node's tbfab address (not 0.0.0.0).
#
# Environment:
#   FORCE=1           run even if this hostname is not one of the six proxies
#   CACHE_DISK_MB     override disk cache size (default: 80% of free space,
#                     capped at 2 TB)
#   CACHE_MEM_MB      override cache_mem (default: 1/16 of RAM, min 1 GB,
#                     max 4 GB)
#   SQUID_SIBLINGS=1  opt-in ICP peering with the other chain proxies
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=squid-chains.conf
source "${SCRIPT_DIR}/squid-chains.conf"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 [LISTEN_IP]" >&2
  exit 1
fi

HOSTNAME_S="$(hostname -s)"
if ! squid_is_proxy_host "$HOSTNAME_S" && [[ "${FORCE:-0}" != "1" ]]; then
  echo "ERROR: ${HOSTNAME_S} is not a chain proxy host." >&2
  echo "Proxy hosts: ${SQUID_CHAIN_HOST[1]} ${SQUID_CHAIN_HOST[2]} ${SQUID_CHAIN_HOST[3]} ${SQUID_CHAIN_HOST[4]} ${SQUID_CHAIN_HOST[5]} ${SQUID_CHAIN_HOST[6]}" >&2
  echo "Set FORCE=1 to override (a lab or a renamed node)." >&2
  exit 1
fi

if [[ -n "${1:-}" ]]; then
  LISTEN_IP="$1"
else
  LISTEN_IP="$(squid_tbfab_ipv4 || true)"
  if [[ -z "$LISTEN_IP" ]]; then
    echo "ERROR: tbfab has no IPv4 address. Pass LISTEN_IP or bring the fabric up." >&2
    exit 1
  fi
fi

SQUID_PORT="${SQUID_HTTP_PORT}"
CACHE_DIR="/var/spool/squid"
MAX_OBJ_SIZE_MB=102400
MAX_OBJ_MEM_MB=256
SSL_DB="/var/lib/squid/ssl_db"
CA_DIR="/etc/squid/ssl"
CA_CERT="${CA_DIR}/squid-ca-cert.pem"
CA_KEY="${CA_DIR}/squid-ca-key.pem"
CA_DER="${CA_DIR}/squid-ca-cert.der"
EXPORT_CERT="/var/www/html/squid-ca-cert.crt"
DISK_CAP_MB=$((2 * 1024 * 1024)) # 2 TiB, same unit squid's cache_dir uses

mkdir -p "${CACHE_DIR}"
if [[ -n "${CACHE_DISK_MB:-}" ]]; then
  if [[ ! "${CACHE_DISK_MB}" =~ ^[0-9]+$ ]] || [[ "${CACHE_DISK_MB}" -lt 1 ]]; then
    echo "ERROR: CACHE_DISK_MB must be a positive number of megabytes" >&2
    exit 1
  fi
  DISK_MB="${CACHE_DISK_MB}"
else
  avail_mb="$(df -BM --output=avail "${CACHE_DIR}" | awk 'NR==2 {gsub(/[^0-9]/, "", $1); print $1}')"
  used_mb="$(du -sm "${CACHE_DIR}" 2>/dev/null | awk '{print $1}')"
  used_mb="${used_mb:-0}"
  DISK_MB=$((avail_mb * 80 / 100))
  # A re-run must not shrink the cache below what is already stored.
  if [[ "${used_mb}" -gt "${DISK_MB}" ]]; then
    DISK_MB="${used_mb}"
  fi
  if [[ "${DISK_MB}" -gt "${DISK_CAP_MB}" ]]; then
    DISK_MB="${DISK_CAP_MB}"
  fi
  if [[ "${DISK_MB}" -lt 64 ]]; then
    echo "ERROR: not enough free space for a Squid cache (${avail_mb} MB free on ${CACHE_DIR})." >&2
    echo "Free space or set CACHE_DISK_MB." >&2
    exit 1
  fi
fi

if [[ -n "${CACHE_MEM_MB:-}" ]]; then
  if [[ ! "${CACHE_MEM_MB}" =~ ^[0-9]+$ ]] || [[ "${CACHE_MEM_MB}" -lt 1 ]]; then
    echo "ERROR: CACHE_MEM_MB must be a positive number of megabytes" >&2
    exit 1
  fi
  MEM_MB="${CACHE_MEM_MB}"
else
  total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  MEM_MB=$((total_kb / 1024 / 16))
  if [[ "${MEM_MB}" -lt 1024 ]]; then
    MEM_MB=1024
  fi
  if [[ "${MEM_MB}" -gt 4096 ]]; then
    MEM_MB=4096
  fi
fi

if [[ "${MAX_OBJ_SIZE_MB}" -gt "${DISK_MB}" ]]; then
  MAX_OBJ_SIZE_MB="${DISK_MB}"
fi
if [[ "${MAX_OBJ_MEM_MB}" -ge "${MEM_MB}" ]]; then
  MAX_OBJ_MEM_MB=$((MEM_MB / 4))
  if [[ "${MAX_OBJ_MEM_MB}" -lt 1 ]]; then
    MAX_OBJ_MEM_MB=1
  fi
fi

SIBLINGS_ON=0
if [[ "${SQUID_SIBLINGS:-0}" == "1" ]]; then
  SIBLINGS_ON=1
fi

echo "============================================"
echo "  Ranch Choir Squid Cache Server Setup"
echo "============================================"
echo "Host:            ${HOSTNAME_S}"
echo "Listen IP:       ${LISTEN_IP}"
echo "HTTP Port:       ${SQUID_PORT}"
echo "SSL Bump Port:   ${SQUID_SSL_PORT}"
echo "Disk Cache:      ${DISK_MB} MB"
echo "RAM Cache:       ${MEM_MB} MB"
echo "Max Object Size: ${MAX_OBJ_SIZE_MB} MB"
echo "Siblings:        $([[ "${SIBLINGS_ON}" -eq 1 ]] && echo on || echo off)"
echo "============================================"

# -----------------------------------------------------------
# 1. Install packages
# -----------------------------------------------------------
echo "[1/7] Installing squid and dependencies..."
apt-get update -qq
apt-get install -y squid-openssl openssl nginx-light apparmor-utils

if [[ -f /etc/apparmor.d/usr.sbin.squid ]]; then
  aa-complain /etc/apparmor.d/usr.sbin.squid || true
else
  echo "  -> No squid AppArmor profile; continuing."
fi

# Apache is not part of this proxy. Missing units must not abort the run.
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
apt-mark hold apache2 2>/dev/null || true

# -----------------------------------------------------------
# 2. Per-host CA. Never copy this key to another proxy.
# -----------------------------------------------------------
echo "[2/7] Generating CA certificate for SSL interception..."
mkdir -p "${CA_DIR}"

if [[ ! -f "${CA_KEY}" ]]; then
  openssl req -new -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -x509 -extensions v3_ca \
    -keyout "${CA_KEY}" \
    -out "${CA_CERT}" \
    -subj "/C=US/ST=Nebraska/L=Ranch/O=RanchChoir/OU=ExocortexCache/CN=Ranch Choir Squid CA ${HOSTNAME_S}"
  openssl x509 -in "${CA_CERT}" -outform DER -out "${CA_DER}"
  echo "  -> New CA generated for ${HOSTNAME_S}."
else
  echo "  -> Existing CA found, reusing (private key stays on this host)."
fi

chown root:proxy "${CA_KEY}" "${CA_CERT}"
chmod 640 "${CA_KEY}"
chmod 644 "${CA_CERT}" "${CA_DER}" 2>/dev/null || true

# Public cert only. The key never lands in the web root.
mkdir -p /var/www/html
cp "${CA_CERT}" "${EXPORT_CERT}"
chmod 644 "${EXPORT_CERT}"

# -----------------------------------------------------------
# 3. SSL certificate database
# -----------------------------------------------------------
echo "[3/7] Initializing SSL certificate database (${SSL_DB})..."
rm -rf "${SSL_DB}"
mkdir -p "$(dirname "${SSL_DB}")"
# security_file_certgen creates the directory itself and must be able to.
chown proxy:proxy "$(dirname "${SSL_DB}")"
sudo -u proxy /usr/lib/squid/security_file_certgen -c -s "${SSL_DB}" -M 64MB
chown -R proxy:proxy "${SSL_DB}"

# -----------------------------------------------------------
# 4. Cache directory
# -----------------------------------------------------------
echo "[4/7] Preparing cache directory..."
mkdir -p "${CACHE_DIR}"
chown -R proxy:proxy "${CACHE_DIR}"

# -----------------------------------------------------------
# 5. squid.conf
# -----------------------------------------------------------
echo "[5/7] Writing squid.conf..."

LOOPBACK_PORT=""
if [[ "${LISTEN_IP}" != "127.0.0.1" ]]; then
  LOOPBACK_PORT="http_port 127.0.0.1:${SQUID_PORT}"
fi

SELF_IP=""
if self_chain="$(squid_detect_chain 2>/dev/null || true)"; then
  SELF_IP="$(squid_proxy_ip_for_chain "${self_chain}" 2>/dev/null || true)"
fi

SIBLING_BLOCK=""
if [[ "${SIBLINGS_ON}" -eq 1 ]]; then
  SIBLING_BLOCK=$(cat <<EOF
# Opt-in ICP siblings (SQUID_SIBLINGS=1). A miss can be filled from another
# chain's cache before the WAN. Bumped HTTPS is not expected to use ICP;
# that path is untested at cluster scale.
icp_port 3130
icp_access allow usb4fabric
icp_access allow localnet
icp_access deny all
EOF
)
  # Do not set udp_incoming_address / udp_outgoing_address. Squid uses
  # those sockets for DNS as well as ICP, and the two directives cannot
  # share an address. Pinning them to the fabric IP makes DNS leave via
  # tbfab and fail (ERR_DNS_FAIL). ICP to 10.53.0.0/16 is routed on the
  # fabric by the kernel without pinning the socket.
  for peer_chain in "${SQUID_CHAINS[@]}"; do
    peer_ip="$(squid_proxy_ip_for_chain "${peer_chain}")"
    if [[ "${peer_ip}" == "${LISTEN_IP}" || ( -n "${SELF_IP}" && "${peer_ip}" == "${SELF_IP}" ) ]]; then
      continue
    fi
    SIBLING_BLOCK+=$'\n'"cache_peer ${peer_ip} sibling ${SQUID_PORT} 3130 proxy-only"
  done
fi

cat > /etc/squid/squid.conf << SQUIDEOF
# ============================================================================
# Ranch Choir per-chain caching proxy (${HOSTNAME_S})
# ============================================================================
# workers is 1 on purpose. Squid 6.14 aufs is not SMP-safe: workers 4 and a
# single cache_dir aufs made several kids FATAL with "Failed to make swap
# directory ... File exists" and the proxy never listened.
# store_miss is intentionally unset. "store_miss deny all" still fetches the
# object and then refuses to store it, so the next request is another TCP_MISS.
# ============================================================================

cache_effective_user proxy
cache_effective_group proxy

# Fabric address, plus loopback so squidclient on this host can reach
# the cache manager without exposing it on the bridge.
${LOOPBACK_PORT}
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
# 10.53.0.0/16 is the USB4 fabric. It is its own ACL: Squid 6.14 drops a
# supernet when a subnet of it is added to the same ACL (it ignores
# 10.0.0.0/8 if 10.53.0.0/16 is also in localnet).
acl usb4fabric src 10.53.0.0/16
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 11434
acl CONNECT method CONNECT

acl bump_targets dstdomain .ollama.ai
acl bump_targets dstdomain .amazonaws.com
acl bump_targets dstdomain .cloudfront.net
acl bump_targets dstdomain files.pythonhosted.org
acl bump_targets dstdomain registry.npmjs.org
acl bump_targets dstdomain static.crates.io

# Bump cacheable registries; splice everything else (verified on Squid 6.14:
# CONNECT to a .ollama.ai name is decrypted, other names are TCP_TUNNEL).
ssl_bump bump bump_targets
ssl_bump splice all

acl manager url_regex -i ^cache_object:// /squid-internal-mgr/
http_access allow localhost manager
http_access deny manager

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow usb4fabric
http_access allow localnet
http_access allow localhost
http_access deny all

${SIBLING_BLOCK}

# -- Cache storage ----------------------------------------------------------
cache_dir aufs ${CACHE_DIR} ${DISK_MB} 16 256
cache_mem ${MEM_MB} MB
maximum_object_size ${MAX_OBJ_SIZE_MB} MB
maximum_object_size_in_memory ${MAX_OBJ_MEM_MB} MB

cache allow all

# Ollama blobs are content-addressed. The override-* options warn at startup;
# they are what makes a multi-GB pull stay a hit for the rest of the chain.
refresh_pattern -i registry\\.ollama\\.ai       129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-store ignore-private
refresh_pattern -i \\.ollama\\.ai               129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-store ignore-private
refresh_pattern -i /v2/.*/blobs/sha256        129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-no-store ignore-private
refresh_pattern -i /v2/.*/manifests/          1440    90%   10080   override-expire reload-into-ims ignore-no-store

refresh_pattern -i \\.deb\$                     129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-private
refresh_pattern -i \\.udeb\$                    129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-private
refresh_pattern -i Packages\\.(bz2|gz|xz|zst)\$ 0      20%   2880
refresh_pattern -i Sources\\.(bz2|gz|xz|zst)\$  0      20%   2880
refresh_pattern -i Release(\\.gpg)?\$            0      20%   2880
refresh_pattern -i InRelease\$                  0      20%   2880
refresh_pattern -i Translation-.*\\.(bz2|gz|xz)\$ 0    20%   2880

refresh_pattern -i \\.(whl|tar\\.gz|zip)\$       129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-private
refresh_pattern -i \\.tgz\$                     129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-private
refresh_pattern -i \\.crate\$                   129600  100%  129600  override-expire override-lastmod reload-into-ims ignore-private

refresh_pattern .                             0       20%   4320

range_offset_limit -1
quick_abort_min -1

connect_timeout 60 seconds
read_timeout 600 seconds
client_lifetime 24 hours
pconn_timeout 300 seconds

# One worker. aufs is not shared across SMP workers in Squid 6.
workers 1

access_log daemon:/var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log daemon:/var/log/squid/store.log

visible_hostname ${HOSTNAME_S}
cache_mgr exocortex@ranch.local
dns_nameservers 1.1.1.1 8.8.8.8
coredump_dir /var/spool/squid
SQUIDEOF

echo "  -> squid -k parse"
if ! squid -k parse; then
  echo "ERROR: squid rejected /etc/squid/squid.conf" >&2
  exit 1
fi

# -----------------------------------------------------------
# 6. Start after the fabric address exists
# -----------------------------------------------------------
echo "[6/7] Enabling squid (after tb-fabric and network-online)..."
mkdir -p /etc/systemd/system/squid.service.d
cat > /etc/systemd/system/squid.service.d/tb-fabric.conf << 'EOF'
[Unit]
After=tb-fabric.service network-online.target
Wants=network-online.target tb-fabric.service
EOF

if squid_have_systemd; then
  systemctl daemon-reload
  systemctl enable squid
  systemctl restart squid
else
  echo "  -> systemd is not running; config is installed, service was not started."
  squid -z --foreground 2>/dev/null || true
fi

if squid_have_systemd; then
  systemctl enable nginx
  systemctl restart nginx
  systemctl status nginx --no-pager || true
else
  echo "  -> systemd is not running; nginx was not restarted."
fi

# -----------------------------------------------------------
# 7. Firewall
# -----------------------------------------------------------
echo "[7/7] Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
  ufw_status="$(ufw status 2>/dev/null || true)"
  if grep -q "Status: active" <<<"${ufw_status}"; then
    ufw allow "${SQUID_PORT}/tcp" comment "Squid HTTP proxy"
    ufw allow "${SQUID_SSL_PORT}/tcp" comment "Squid SSL bump proxy"
    ufw allow 80/tcp comment "Nginx CA cert download"
    if [[ "${SIBLINGS_ON}" -eq 1 ]]; then
      ufw allow 3130/udp comment "Squid ICP siblings"
    else
      ufw --force delete allow 3130/udp >/dev/null 2>&1 || true
    fi
    echo "  -> UFW rules updated."
  else
    echo "  -> UFW not active, skipping."
  fi
else
  echo "  -> UFW not installed, skipping."
fi

echo ""
echo "============================================"
echo "  Squid cache server is configured"
echo "============================================"
echo ""
echo "  Host:         ${HOSTNAME_S}"
echo "  HTTP Proxy:   http://${LISTEN_IP}:${SQUID_PORT}"
echo "  SSL Proxy:    http://${LISTEN_IP}:${SQUID_SSL_PORT}"
echo "  CA Cert URL:  http://${LISTEN_IP}/squid-ca-cert.crt"
echo ""
echo "  Cache stats:  squidclient -h 127.0.0.1 mgr:info"
echo "  Hit ratio:    squidclient -h 127.0.0.1 mgr:info | grep -i 'Hit Ratio'"
echo ""
echo "  Next: sudo bash provision-squid-client.sh auto"
echo "============================================"
