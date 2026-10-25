#!/usr/bin/env bash
# Drive the six chain proxies. One unreachable node does not stop the rest.
#
# Usage:
#   bash squid-chains.sh [--dry-run] [--only HOST] status
#   bash squid-chains.sh [--dry-run] [--only HOST] servers
#   bash squid-chains.sh [--dry-run] [--only HOST] clients
#
# status   each proxy host: ssh reachable, squid active, port 3128, hit ratio
# servers  ssh to each proxy host and run provision-squid-server.sh
# clients  ssh to every TB_MAP node and run provision-squid-client.sh auto
#
# Remote scripts are read from SQUID_REMOTE_DIR (default /source/exocortical),
# the same tree tb-fabric.service uses. SSH is BatchMode with a short connect
# timeout and sudo -n.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=squid-chains.conf
source "${SCRIPT_DIR}/squid-chains.conf"

REMOTE_DIR="${SQUID_REMOTE_DIR:-/source/exocortical}"
DRY=0
ONLY=""
CMD=""

usage() {
  cat << EOF
Usage: $0 [--dry-run] [--only HOST] status|servers|clients

  status    reachability, squid, port 3128, hit ratio for the six proxies
  servers   provision the six chain proxies
  clients   provision every TB_MAP node with 'auto' (chain 7 stays direct)

Environment:
  SQUID_REMOTE_DIR   remote checkout (default /source/exocortical)
  SQUID_SIBLINGS     passed through to server provisioning when set
  CACHE_DISK_MB      passed through to server provisioning when set
  CACHE_MEM_MB       passed through to server provisioning when set
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY=1
      shift
      ;;
    --only)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "ERROR: --only needs a hostname" >&2
        exit 2
      fi
      ONLY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    status|servers|clients)
      if [[ -n "${CMD}" ]]; then
        echo "ERROR: only one subcommand" >&2
        exit 2
      fi
      CMD="$1"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${CMD}" ]]; then
  usage >&2
  exit 2
fi

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o ConnectionAttempts=1
  -o StrictHostKeyChecking=accept-new
  -o ServerAliveInterval=5
  -o ServerAliveCountMax=1
)

FAILED=0

note_fail() {
  FAILED=1
  echo "FAIL  $*"
}

note_ok() {
  echo "OK    $*"
}

run_ssh() {
  # $1 host, $2 timeout seconds, $3 remote command
  local host="$1" tmo="$2" remote="$3"
  if [[ "${DRY}" -eq 1 ]]; then
    printf 'DRY-RUN ssh %s %s\n' "${host}" "${remote}"
    return 0
  fi
  timeout "${tmo}" ssh "${SSH_OPTS[@]}" "${host}" "${remote}"
}

server_env() {
  local env_cmd=""
  if [[ -n "${SQUID_SIBLINGS:-}" ]]; then
    env_cmd+=" SQUID_SIBLINGS=$(printf '%q' "${SQUID_SIBLINGS}")"
  fi
  if [[ -n "${CACHE_DISK_MB:-}" ]]; then
    env_cmd+=" CACHE_DISK_MB=$(printf '%q' "${CACHE_DISK_MB}")"
  fi
  if [[ -n "${CACHE_MEM_MB:-}" ]]; then
    env_cmd+=" CACHE_MEM_MB=$(printf '%q' "${CACHE_MEM_MB}")"
  fi
  printf '%s' "${env_cmd}"
}

selected_proxy() {
  local chain="$1" host
  host="$(squid_proxy_host_for_chain "${chain}")"
  if [[ -n "${ONLY}" && "${ONLY}" != "${host}" ]]; then
    return 1
  fi
  return 0
}

do_status() {
  local chain host ip remote rc
  local matched=0
  for chain in "${SQUID_CHAINS[@]}"; do
    if ! selected_proxy "${chain}"; then
      continue
    fi
    matched=1
    host="$(squid_proxy_host_for_chain "${chain}")"
    ip="$(squid_proxy_ip_for_chain "${chain}")"
    echo "---- ${host} chain ${chain} ${ip} ----"
    if [[ "${DRY}" -eq 1 ]]; then
      echo "DRY-RUN status ${host}"
      continue
    fi
    if timeout 1 bash -c "echo >/dev/tcp/${ip}/${SQUID_HTTP_PORT}" 2>/dev/null; then
      echo "  fabric port ${SQUID_HTTP_PORT}: answering"
    else
      echo "  fabric port ${SQUID_HTTP_PORT}: not answering from here"
    fi
    remote="systemctl is-active squid 2>/dev/null || echo inactive; if timeout 1 bash -c 'echo >/dev/tcp/${ip}/${SQUID_HTTP_PORT}' 2>/dev/null; then echo port_local=answering; else echo port_local=down; fi; if command -v squidclient >/dev/null 2>&1; then squidclient -h 127.0.0.1 mgr:info 2>/dev/null | grep -i 'Hit Ratio' || echo 'hit_ratio=unavailable'; else echo 'squidclient=missing'; fi"
    if run_ssh "${host}" 20 "${remote}"; then
      note_ok "${host} status"
    else
      rc=$?
      note_fail "${host} status (ssh exit ${rc})"
    fi
  done
  if [[ "${matched}" -eq 0 ]]; then
    note_fail "--only ${ONLY} is not one of the six proxy hosts"
  fi
}

do_servers() {
  local chain host remote rc env_prefix
  local matched=0
  env_prefix="$(server_env)"
  for chain in "${SQUID_CHAINS[@]}"; do
    if ! selected_proxy "${chain}"; then
      continue
    fi
    matched=1
    host="$(squid_proxy_host_for_chain "${chain}")"
    remote="sudo -n env${env_prefix} bash $(printf '%q' "${REMOTE_DIR}/provision-squid-server.sh")"
    echo "---- server ${host} ----"
    if run_ssh "${host}" 900 "${remote}"; then
      note_ok "${host} server"
    else
      rc=$?
      note_fail "${host} server (exit ${rc})"
    fi
  done
  if [[ "${matched}" -eq 0 ]]; then
    note_fail "--only ${ONLY} is not one of the six proxy hosts"
  fi
}

do_clients() {
  local line host ip remote rc
  local matched=0
  while read -r host ip; do
    [[ -z "${host}" ]] && continue
    if [[ -n "${ONLY}" && "${ONLY}" != "${host}" ]]; then
      continue
    fi
    matched=1
    remote="sudo -n bash $(printf '%q' "${REMOTE_DIR}/provision-squid-client.sh") auto"
    echo "---- client ${host} ${ip} ----"
    if run_ssh "${host}" 300 "${remote}"; then
      note_ok "${host} client"
    else
      rc=$?
      note_fail "${host} client (exit ${rc})"
    fi
  done < <(squid_tb_map_entries || true)
  if [[ "${matched}" -eq 0 ]]; then
    if [[ -n "${ONLY}" ]]; then
      note_fail "--only ${ONLY} is not in tb-setup.sh TB_MAP"
    else
      note_fail "no TB_MAP entries found"
    fi
  fi
}

case "${CMD}" in
  status) do_status ;;
  servers) do_servers ;;
  clients) do_clients ;;
esac

if [[ "${DRY}" -eq 1 && "${FAILED}" -eq 0 ]]; then
  exit 0
fi
exit "${FAILED}"
