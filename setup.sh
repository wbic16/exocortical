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
# (ninja-build/gettext/cmake/unzip + lua5.1/liblua5.1-0-dev below are the
# exovim build/test dependencies from wbic16/neovim BUILD.md + PHEXT.md —
# the exovim build itself is Phase 12)
sudo apt install -y --no-install-recommends \
  git git-lfs gh \
  zram-config net-tools \
  build-essential clang pkg-config libssl-dev \
  ninja-build gettext cmake unzip lua5.1 liblua5.1-0-dev \
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
  libasound2-dev libpulse-dev libxext-dev \
  wireless-tools

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

# ============================================================
# Phase 11: Formal verification tools (Charon / Aeneas / Lean)
# ============================================================
# The toolchain that proves libphext-rs correct is installed by that
# repo's own script (single source of truth for the recipe); Phase 8
# already cloned it into /source. Everything lands in ~/.proof-tools.
echo "[phase 11] Proof tools (Charon/Aeneas/Lean)..."
if [ -x /source/libphext-rs/scripts/install-proof-tools.sh ]; then
  /source/libphext-rs/scripts/install-proof-tools.sh
else
  echo "[phase 11] /source/libphext-rs not present - skipping proof tools."
fi

# ============================================================
# Phase 12: exovim — phext-support Neovim (wbic16/neovim)
# ============================================================
# exovim is the phext-support fork of Neovim: a pure-Lua runtime plugin
# (scroll-as-buffer navigation over .phext files) carried on upstream
# master. Its build/test dependencies (ninja-build gettext cmake curl
# build-essential git unzip pkg-config lua5.1 liblua5.1-0-dev, per the
# repo's BUILD.md + PHEXT.md) are installed in Phase 1's apt batch.
#
# Install layout: source lives in /source/neovim (clone-or-update,
# like Phase 8's trees) and installs into its own prefix, /opt/exovim,
# so the apt `nvim` from Phase 1 is untouched. The user-facing command
# is /usr/local/bin/exovim, a symlink to /opt/exovim/bin/nvim —
# Neovim locates its runtime relative to the real binary's path, so
# the prefix tree (including the phext runtime) stays intact.
#
# Idempotency: /opt/exovim/.exovim-commit stamps the built commit;
# a re-run rebuilds only when upstream master has moved (or the
# binary is missing).
echo "[phase 12] exovim (phext Neovim)..."
EXOVIM_SRC=/source/neovim
EXOVIM_PREFIX=/opt/exovim
if [ ! -d "$EXOVIM_SRC" ]; then
  git clone git@github.com:wbic16/neovim.git "$EXOVIM_SRC" || true
fi
if [ -d "$EXOVIM_SRC" ]; then
  git -C "$EXOVIM_SRC" pull --ff-only || \
    echo "[phase 12] exovim source pull failed - building the checkout as-is."
  EXOVIM_WANT=$(git -C "$EXOVIM_SRC" rev-parse HEAD)
  EXOVIM_HAVE=""
  if [ -f "$EXOVIM_PREFIX/.exovim-commit" ]; then
    EXOVIM_HAVE=$(cat "$EXOVIM_PREFIX/.exovim-commit")
  fi
  if [ "$EXOVIM_WANT" != "$EXOVIM_HAVE" ] || [ ! -x "$EXOVIM_PREFIX/bin/nvim" ]; then
    sudo mkdir -p "$EXOVIM_PREFIX"
    sudo chown "$USER:$USER" "$EXOVIM_PREFIX"
    (
      cd "$EXOVIM_SRC"
      make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$EXOVIM_PREFIX"
      make CMAKE_INSTALL_PREFIX="$EXOVIM_PREFIX" install
    )
    echo "$EXOVIM_WANT" > "$EXOVIM_PREFIX/.exovim-commit"
    echo "[phase 12] exovim built at $EXOVIM_WANT"
  else
    echo "[phase 12] exovim already up to date ($EXOVIM_HAVE) - skipping build."
  fi
  sudo ln -sf "$EXOVIM_PREFIX/bin/nvim" /usr/local/bin/exovim
else
  echo "[phase 12] /source/neovim not present - skipping exovim."
fi

# phcc variant (documented, NOT the default path): to compile exovim
# with phcc (the phext TinyCC fork) instead of the system compiler,
# build the bundled deps once with the system compiler, then nvim
# itself with phcc. Verified recipe from wbic16/neovim PHEXT.md:
# PREFER_LUA=ON selects the bundled Lua 5.1.5 (LuaJIT is not a phcc
# target), and the LUA_MATH_LIBRARY pre-seed is required because
# CMake's FindLua resolves libm only via CMAKE_LIBRARY_ARCHITECTURE,
# which the TinyCC compiler-ABI probe leaves empty:
#   cmake -S cmake.deps -B .deps -G Ninja -DCMAKE_BUILD_TYPE=Release -DUSE_BUNDLED_LUA=ON
#   cmake --build .deps
#   CC="<path-to-phcc>/phcc -B<path-to-phcc>" \
#   cmake -B build-phcc -G Ninja -DCMAKE_BUILD_TYPE=Release -DPREFER_LUA=ON \
#         -DLUA_MATH_LIBRARY=/usr/lib/x86_64-linux-gnu/libm.so
#   cmake --build build-phcc

echo "Setup Complete."
