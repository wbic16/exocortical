#!/bin/bash
# opinionated system config - optimized for speed
# Exocortex Setup v2 - parallelized edition
set -euo pipefail

git config --global init.defaultBranch exo
git config pull.rebase true

git pull
ARG=${1:-}
if [ "x$ARG" = "xexec" ]; then
  echo "Ready to update."
else
  $0 exec
  exit $?
fi

export DEBIAN_FRONTEND=noninteractive
MAX_PARALLEL=${MAX_PARALLEL:-8}  # tunable: git clone concurrency

# ============================================================
# Phase 1: System packages (single apt call)
# ============================================================
echo "[phase 1] System packages..."
sudo apt update -y

# batch all apt packages into one transaction
sudo apt install -y --no-install-recommends \
  git git-lfs gh \
  zram-config net-tools \
  build-essential clang pkg-config libssl-dev \
  vim neovim \
  htop \
  openssh-server \
  apt-file \
  lm-sensors \
  libfuse2t64 \
  curl \
  avahi-utils \
  bridge-utils \
  elinks \
  libgmp-dev \
  sysbench \
  rustup \
  python3.12-venv linux-libc-dev python3-dev python3-pip \
  php gparted screen \
  libasound2-dev libpulse-dev libxext-dev

# snap packages (docker only - avahi snap is conditional below)
if ! snap list docker &>/dev/null; then
  sudo snap install docker
fi

# libuv patch (idempotent gate)
if [ ! -f /etc/exo-uv-ready ]; then
  ./patch-libuv.sh
fi

# ============================================================
# Phase 2: Avahi exocortical advertisement
# ============================================================
if [ ! -f /etc/avahi/services/exocortex.service ]; then
  echo "[phase 2] Avahi advertisement..."
  if ! snap list avahi &>/dev/null; then
    sudo snap install avahi
  fi
  sudo cp exocortex.service /etc/avahi/services/
  sudo service avahi-daemon restart
fi

# ============================================================
# Phase 3: Ollama
# ============================================================
echo "[phase 3] Ollama..."
LLM_AGENT="ollama"
if ! command -v ollama &>/dev/null; then
  curl -fsSL https://ollama.com/install.sh | sudo bash
fi

if [ "x$LLM_AGENT" = "xmicro" ]; then
  sudo apt install -y npm
  sudo npm install -g @builder.io/micro-agent
fi

# ============================================================
# Phase 4: Rust toolchain + cargo installs (parallel)
# ============================================================
echo "[phase 4] Rust toolchain..."
sudo rustup default stable 2>/dev/null || true
rustup default stable 2>/dev/null || true

IN_PATH=$(grep '\.cargo\/bin' ~/.bashrc -c || true)
if [ "$IN_PATH" = "0" ]; then
  echo "Adding Rust programs to PATH - login again to activate"
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.cargo/bin:$PATH"

echo "[phase 4] Cargo installs (parallel)..."
cargo_crates=(phext-shell hello-phext quickfork sq phext-lattice)
for crate in "${cargo_crates[@]}"; do
  cargo install "$crate" &
done
wait
echo "[phase 4] Cargo installs complete."

# ============================================================
# Phase 5: Python virtual environment + pip installs (batched)
# ============================================================
echo "[phase 5] Python environment..."
if [ ! -d /opt/exopy ]; then
  sudo mkdir -p /opt/exopy
  sudo chown "$USER:$USER" /opt/exopy
  python3 -m venv /opt/exopy
fi

# batch all pip installs into one call
/opt/exopy/bin/pip3 install --quiet \
  llvmlite numba torch tensorflow shap \
  llama-index openai tf-keras \
  llama-index-embeddings-huggingface \
  llama-index-llms-ollama \
  "tensorflow[and-cuda]"

/opt/exopy/bin/pip install --quiet -U openai-whisper

pip install --quiet agentmail python-dotenv 2>/dev/null || true

# ============================================================
# Phase 6: SSH key
# ============================================================
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
  echo "No SSH Identity found...generating one."
  ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi

if [ ! -f /etc/exo-ready ]; then
  echo ""
  echo "You need to touch /etc/exo-ready after uploading your public key to GitHub."
  echo ""
  cat ~/.ssh/id_ed25519.pub
  echo ""
  exit 1
fi

# ============================================================
# Phase 7: External repos (ROCm, beebjit, phoronix)
# ============================================================
echo "[phase 7] External repos..."

if [ ! -d /opt/phoronix ]; then
  sudo mkdir -p /opt/phoronix
  sudo chown "$USER:$USER" /opt/phoronix
  (
    cd /opt/phoronix
    wget -q https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite_10.8.4_all.deb
    sudo apt install -y ./phoronix-test-suite_10.8.4_all.deb
  ) &
fi

if [ ! -d /opt/ROCm ]; then
  sudo mkdir -p /opt/ROCm
  sudo chown "$USER:$USER" /opt/ROCm
  (
    cd /opt/ROCm
    git clone git@github.com:ROCm/ROCm.git .
    git checkout roc-6.3.x
    git pull
  ) &
fi

if [ ! -d /opt/beebjit ]; then
  sudo mkdir -p /opt/beebjit
  sudo chown "$USER:$USER" /opt/beebjit
  git clone git@github.com:wbic16/beebjit.git /opt/beebjit &
fi

wait
echo "[phase 7] External repos complete."

# ============================================================
# Phase 8: Exocortex source trees (throttled parallel clones)
# ============================================================
echo "[phase 8] Exocortex source trees..."
if [ ! -d /source ]; then
  sudo mkdir -p /source
  sudo chown "$USER:$USER" /source
fi

# helper: clone into /source if not already present
# uses a semaphore to cap concurrency at MAX_PARALLEL
RUNNING=0
clone_repo() {
  local repo="$1"
  local dir="/source/$(basename "$repo" .git)"
  if [ ! -d "$dir" ]; then
    git clone "git@github.com:wbic16/${repo}.git" "$dir" &
    RUNNING=$((RUNNING + 1))
    if [ "$RUNNING" -ge "$MAX_PARALLEL" ]; then
      wait
      RUNNING=0
    fi
  fi
}

# --- The Exocortex ---
clone_repo exocortical
clone_repo wishnode
clone_repo exocortex
clone_repo human
clone_repo nexura
clone_repo thebook

# --- Tessera ---
clone_repo llama2.c
clone_repo exollama
clone_repo mirrorborn
clone_repo exo-plan
clone_repo compost
clone_repo site-mirrorborn-us
clone_repo vtpu
clone_repo SBOR
clone_repo federation
clone_repo orin

# --- Phext Core ---
clone_repo libphext-rs
clone_repo SQ
clone_repo phext-notepad
clone_repo phext-shell
clone_repo phext-explorer
clone_repo phext-lattice

# --- Phext Implementations ---
clone_repo libphext-node
clone_repo libphext
clone_repo libphext-cpp
clone_repo libphext-py
clone_repo libphext-cs

# --- Phext Tools ---
clone_repo phcc

# --- Phext Applications ---
clone_repo dna-viewer
clone_repo phorge

# --- Games ---
clone_repo mini64k
clone_repo javascript-tetris
clone_repo multiversal-go

# --- APIs ---
clone_repo hello-phext
clone_repo phext-wiki
clone_repo robospeak
clone_repo subspace-repeater

# --- Web Sites ---
clone_repo singularity-watch
clone_repo wbic16
clone_repo phextio
clone_repo sotafomo

# --- Teaching ---
clone_repo teach-web-dev

# --- Web/Social ---
clone_repo x-analysis
clone_repo node-visualizer

wait
echo "[phase 8] Source trees complete."

# the-book-of-secret-knowledge uses https, not ssh
if [ ! -d /source/the-book-of-secret-knowledge ]; then
  git clone https://github.com/wbic16/the-book-of-secret-knowledge.git /source/the-book-of-secret-knowledge
fi

# ============================================================
# Phase 9: Micro-agent (conditional)
# ============================================================
if [ "x$LLM_AGENT" = "xmicro" ]; then
  if [ ! -d /opt/micro-agent ]; then
    sudo mkdir -p /opt/micro-agent
    sudo chown "$USER:$USER" /opt/micro-agent
    cd /opt/micro-agent
    micro-agent
  fi
fi

# ============================================================
# Phase 10: DNS fallback + final upgrade
# ============================================================
if [ ! -f /etc/systemd/resolved.conf.d/fallback.conf ]; then
  echo "Installing fallback DNS..."
  sudo mkdir -p /etc/systemd/resolved.conf.d
  sudo tee /etc/systemd/resolved.conf.d/fallback.conf << 'EOF'
[Resolve]
FallbackDNS=1.1.1.1 8.8.8.8
DNS=1.1.1.1 8.8.8.8
EOF
  sudo systemctl restart systemd-resolved
fi

sudo apt upgrade -y

echo "Setup Complete."
