#!/usr/bin/env bash
# ============================================================================
# Fleet Ollama install that can survive a chain Squid
# ============================================================================
# Replacement for the official installer on these nodes:
#   curl -fsSL https://ollama.com/install.sh | sudo bash
# That installer streams `curl | zstd -d | tar` with no retry. A worker crash
# or a cut tunnel then leaves a truncated archive and "unexpected EOF".
#
# This script downloads ollama-linux-<arch>.tar.zst (and the -rocm archive
# when an AMD GPU is present) to a file, retries, checks `zstd -t` before
# extracting, then creates the ollama user and a systemd unit if needed.
# It does not install NVIDIA CUDA drivers. Pin OLLAMA_VERSION so a re-run
# skips the download.
#
# Usage:
#   sudo bash install-ollama-cached.sh
#
# Environment:
#   OLLAMA_VERSION          e.g. 0.40.11 (same ?version= the official script uses)
#   OLLAMA_INSTALL_JITTER   seconds to sleep before downloading.
#                           Unset = random 0-60. 0 = start immediately.
#   OLLAMA_DOWNLOAD_BASE    default https://ollama.com/download
# ============================================================================
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

status() { echo ">>> $*" >&2; }
error() { echo "ERROR: $*" >&2; exit 1; }

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) error "Unsupported architecture: ${ARCH}" ;;
esac

DOWNLOAD_BASE="${OLLAMA_DOWNLOAD_BASE:-https://ollama.com/download}"
DOWNLOAD_BASE="${DOWNLOAD_BASE%/}"
INSTALL_DIR="/usr/local"
BIN="${INSTALL_DIR}/bin/ollama"

ver_param() {
  if [[ -n "${OLLAMA_VERSION:-}" ]]; then
    printf '?version=%s' "${OLLAMA_VERSION#v}"
  fi
}

installed_version() {
  local line
  if [[ ! -x "${BIN}" ]]; then
    return 0
  fi
  line="$("${BIN}" --version 2>/dev/null | head -n 1 || true)"
  line="${line#ollama version is }"
  line="${line#ollama version }"
  line="${line#v}"
  printf '%s' "${line}" | awk '{print $1}'
}

if [[ -n "${OLLAMA_VERSION:-}" ]]; then
  want="${OLLAMA_VERSION#v}"
  have="$(installed_version)"
  if [[ -n "${have}" && "${have}" == "${want}" ]]; then
    status "Ollama ${want} is already installed. Skipping."
    exit 0
  fi
fi

apply_jitter() {
  local delay
  if [[ -n "${OLLAMA_INSTALL_JITTER:-}" ]]; then
    if [[ ! "${OLLAMA_INSTALL_JITTER}" =~ ^[0-9]+$ ]]; then
      error "OLLAMA_INSTALL_JITTER must be a whole number of seconds"
    fi
    delay="${OLLAMA_INSTALL_JITTER}"
  else
    delay=$((RANDOM % 61))
  fi
  if [[ "${delay}" -gt 0 ]]; then
    status "Waiting ${delay}s so fleet installs do not all start at once."
    sleep "${delay}"
  fi
}

# sudo does not source /etc/profile.d, and the client no longer pins a proxy
# in /etc/environment (a dead proxy must not wedge the node). Probe the chain
# proxy the same way apt does, and stay direct when it does not answer.
adopt_chain_proxy() {
  local detect="/usr/local/bin/ranch-proxy-autodetect" url
  if [[ -n "${https_proxy:-${HTTPS_PROXY:-}}" ]]; then
    return 0
  fi
  if [[ ! -x "${detect}" ]]; then
    status "No chain-proxy probe installed. Downloading direct."
    return 0
  fi
  url="$("${detect}" https)"
  if [[ "${url}" == "DIRECT" || -z "${url}" ]]; then
    status "Chain proxy is not answering. Downloading direct."
    return 0
  fi
  export https_proxy="${url}" HTTPS_PROXY="${url}"
  export http_proxy="${url}" HTTP_PROXY="${url}"
  if [[ -r /etc/ranch-squid/client.env ]]; then
    # shellcheck disable=SC1091
    source /etc/ranch-squid/client.env
    if [[ -n "${NO_PROXY_LIST:-}" ]]; then
      export no_proxy="${NO_PROXY_LIST}" NO_PROXY="${NO_PROXY_LIST}"
    fi
  fi
  status "Downloading through ${url}"
}

have_amd_gpu() {
  # Same vendor check as the official installer (lspci -d 1002, then lshw).
  if command -v lspci >/dev/null 2>&1 && lspci -d '1002:' 2>/dev/null | grep -q 'AMD'; then
    return 0
  fi
  if command -v lshw >/dev/null 2>&1 && lshw -c display -numeric -disable network 2>/dev/null | grep -q 'vendor: .* \[1002\]'; then
    return 0
  fi
  return 1
}

need_zstd() {
  if command -v zstd >/dev/null 2>&1; then
    return 0
  fi
  status "Installing zstd (required to verify the archive before extract)."
  apt-get update -qq
  apt-get install -y zstd
}

archive_url() {
  local name="$1" ext="$2"
  printf '%s/%s.%s%s' "${DOWNLOAD_BASE}" "${name}" "${ext}" "$(ver_param)"
}

# Prefer .tar.zst. Older pinned versions are published as .tgz only.
choose_ext() {
  local name="$1" zst_url
  zst_url="$(archive_url "${name}" "tar.zst")"
  if curl --fail --silent --head --location --retry 2 --retry-delay 2 "${zst_url}" >/dev/null 2>&1; then
    printf 'tar.zst'
    return 0
  fi
  printf 'tgz'
}

download_archive() {
  local url="$1" dest="$2"
  rm -f "${dest}"
  status "Downloading ${url}"
  curl --fail --location --retry 8 --retry-delay 5 --retry-all-errors -C - \
    --output "${dest}" "${url}"
}

verify_archive() {
  local dest="$1" ext="$2"
  case "${ext}" in
    tar.zst)
      zstd -t "${dest}"
      ;;
    tgz)
      tar -tzf "${dest}" >/dev/null
      ;;
    *)
      error "Unknown archive type ${ext}"
      ;;
  esac
}

extract_archive() {
  local dest="$1" ext="$2"
  case "${ext}" in
    tar.zst)
      zstd -d -c -- "${dest}" | tar -xf - -C "${INSTALL_DIR}"
      ;;
    tgz)
      tar -xzf "${dest}" -C "${INSTALL_DIR}"
      ;;
    *)
      error "Unknown archive type ${ext}"
      ;;
  esac
}

# Sets FETCH_PATH and FETCH_EXT. Must run in the current shell so a bad
# archive's exit is not swallowed by a command substitution.
fetch_named() {
  local name="$1" ext dest
  ext="$(choose_ext "${name}")"
  dest="${WORKDIR}/${name}.${ext}"
  if [[ "${ext}" == "tar.zst" ]]; then
    need_zstd
  fi
  download_archive "$(archive_url "${name}" "${ext}")" "${dest}"
  status "Verifying ${dest} before extract."
  if ! verify_archive "${dest}" "${ext}"; then
    rm -f "${dest}"
    error "${name}.${ext} failed verification (incomplete or corrupt). Not extracting."
  fi
  FETCH_PATH="${dest}"
  FETCH_EXT="${ext}"
}

ensure_user() {
  local login
  if ! id ollama >/dev/null 2>&1; then
    status "Creating ollama user."
    useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama
  fi
  if getent group render >/dev/null 2>&1; then
    usermod -a -G render ollama
  fi
  if getent group video >/dev/null 2>&1; then
    usermod -a -G video ollama
  fi
  login="${SUDO_USER:-}"
  if [[ -z "${login}" || "${login}" == "root" ]]; then
    login="$(whoami)"
  fi
  if id "${login}" >/dev/null 2>&1; then
    usermod -a -G ollama "${login}" || true
  fi
}

ensure_unit() {
  local unit="/etc/systemd/system/ollama.service"
  if [[ ! -f "${unit}" ]]; then
    status "Writing ${unit}"
    cat > "${unit}" << EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=${BIN} serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=${PATH}"

[Install]
WantedBy=default.target
EOF
  else
    status "Leaving existing ${unit} in place."
  fi
  if [[ -S /run/systemd/private ]]; then
    systemctl daemon-reload
    systemctl enable ollama
    systemctl restart ollama
  else
    status "systemd is not running. Unit is installed; start Ollama on the node."
  fi
}

apply_jitter
adopt_chain_proxy

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

base_name="ollama-linux-${ARCH}"
fetch_named "${base_name}"
base_file="${FETCH_PATH}"
base_ext="${FETCH_EXT}"

rocm_file=""
rocm_ext=""
if have_amd_gpu; then
  status "AMD GPU detected. Fetching the ROCm archive."
  fetch_named "${base_name}-rocm"
  rocm_file="${FETCH_PATH}"
  rocm_ext="${FETCH_EXT}"
else
  status "No AMD GPU detected. Skipping the ROCm archive."
fi

status "Extracting to ${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}/lib/ollama"
install -o 0 -g 0 -m 755 -d "${INSTALL_DIR}/bin" "${INSTALL_DIR}/lib/ollama"
extract_archive "${base_file}" "${base_ext}"
if [[ -n "${rocm_file}" ]]; then
  extract_archive "${rocm_file}" "${rocm_ext}"
fi

if [[ ! -x "${BIN}" ]]; then
  error "Extract finished but ${BIN} is missing."
fi
chmod 755 "${BIN}" || true

ensure_user
ensure_unit
status "Ollama install complete (${BIN})."
