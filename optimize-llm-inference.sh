#!/bin/bash
# optimize-llm-inference.sh — Exocortical LLM node tuning
# Tunes swap, iGPU, Ollama, and I/O for MoE inference on AMD 780M
# Depends on: enable-virtual-memory.sh (run first)
set -euo pipefail

SETUP_FILE="/etc/exocortical-llm-optimized.done"
if [ -f "$SETUP_FILE" ]; then
  echo "LLM inference already optimized."
  echo "--- current config ---"
  cat /proc/sys/vm/swappiness
  ollama list 2>/dev/null || true
  exit 0
fi

# ============================================================
# Detect RAM tier
# ============================================================
TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$TOTAL_RAM_MB" -ge 80000 ]; then
  RAM_TIER="96"
elif [ "$TOTAL_RAM_MB" -ge 24000 ]; then
  RAM_TIER="32"
else
  RAM_TIER="16"
fi
echo "[detect] ${TOTAL_RAM_MB} MB RAM -> tier ${RAM_TIER} GB"

# Shell assignment: override with EXOCORTEX_SHELL=1 or =2
# Default: unassigned (script will skip model pulls)
EXOCORTEX_SHELL="${EXOCORTEX_SHELL:-0}"
echo "[detect] Shell assignment: ${EXOCORTEX_SHELL}"

# ============================================================
# Phase 1: Swap tuning for MoE inference
# ============================================================
echo "[phase 1] Swap parameters..."

# swappiness=60 is good for MoE: inactive experts page out gracefully
# vfs_cache_pressure=50 keeps filesystem cache balanced
SYSCTL_CONF="/etc/sysctl.d/90-exocortical-llm.conf"
if [ ! -f "$SYSCTL_CONF" ]; then
  sudo tee "$SYSCTL_CONF" << 'EOF'
# Exocortical LLM inference tuning
# MoE models benefit from moderate swap: inactive experts page gracefully
vm.swappiness=60

# keep filesystem cache reasonable - don't starve model weights
vm.vfs_cache_pressure=50

# dirty page tuning: reduce write-back latency spikes during inference
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# transparent hugepages: useful for large contiguous model weight allocations
# (already default on Ubuntu 24.04, but pin it)
EOF
  sudo sysctl --system --quiet
  echo "[phase 1] Sysctl tuned."
else
  echo "[phase 1] Sysctl already configured."
fi

# ============================================================
# Phase 2: NVMe I/O scheduler
# ============================================================
echo "[phase 2] NVMe I/O scheduler..."

# mq-deadline is better than kyber for swap-heavy LLM workloads:
# it prevents write starvation during model weight page-ins
UDEV_RULE="/etc/udev/rules.d/60-exocortical-iosched.rules"
if [ ! -f "$UDEV_RULE" ]; then
  sudo tee "$UDEV_RULE" << 'EOF'
# prefer mq-deadline for NVMe: reduces latency spikes during swap-backed inference
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF
  # apply immediately to any existing nvme devices
  for dev in /sys/block/nvme*; do
    if [ -d "$dev" ]; then
      echo mq-deadline | sudo tee "$dev/queue/scheduler" >/dev/null 2>&1 || true
    fi
  done
  echo "[phase 2] NVMe scheduler set to mq-deadline."
else
  echo "[phase 2] NVMe scheduler already configured."
fi

# ============================================================
# Phase 3: AMD 780M iGPU / amdgpu tuning
# ============================================================
echo "[phase 3] AMD 780M iGPU tuning..."

GRUB_UPDATED=0
GRUB_FILE="/etc/default/grub"

# GTT size: expand GPU-addressable memory window
# 16GB nodes: 8GB GTT  |  32GB nodes: 16GB GTT  |  96GB nodes: 32GB GTT
case "$RAM_TIER" in
  96) GTT_MB=32768 ;;
  32) GTT_MB=16384 ;;
  *)  GTT_MB=8192  ;;
esac

# check if amdgpu.gttsize is already in grub
if ! grep -q "amdgpu.gttsize=" "$GRUB_FILE"; then
  echo "[phase 3] Adding amdgpu.gttsize=${GTT_MB} to GRUB..."
  sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"amdgpu.gttsize=${GTT_MB} /" "$GRUB_FILE"
  GRUB_UPDATED=1
fi

# also set iommu=pt for better DMA performance with large memory
if ! grep -q "iommu=pt" "$GRUB_FILE"; then
  echo "[phase 3] Adding iommu=pt to GRUB..."
  sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"iommu=pt /" "$GRUB_FILE"
  GRUB_UPDATED=1
fi

if [ "$GRUB_UPDATED" -eq 1 ]; then
  sudo update-grub
  echo "[phase 3] GRUB updated. Reboot required for GPU changes."
else
  echo "[phase 3] GRUB already configured."
fi

# ============================================================
# Phase 4: Ollama environment + systemd override
# ============================================================
echo "[phase 4] Ollama service tuning..."

OLLAMA_OVERRIDE="/etc/systemd/system/ollama.service.d"
if [ ! -d "$OLLAMA_OVERRIDE" ]; then
  sudo mkdir -p "$OLLAMA_OVERRIDE"
fi

# max loaded models: 1 on 16GB (conserve RAM), 2 on 32GB, 3 on 96GB
case "$RAM_TIER" in
  96) MAX_MODELS=3 ;;
  32) MAX_MODELS=2 ;;
  *)  MAX_MODELS=1 ;;
esac

# context window defaults by tier (tokens)
# shell 1 needs reasoning depth; shell 2 needs throughput
case "${RAM_TIER}-${EXOCORTEX_SHELL}" in
  96-1) NUM_CTX=65536  ;;  # anchor: deep thought
  96-2) NUM_CTX=8192   ;;  # oracle: save RAM for 122B weights
  32-1) NUM_CTX=16384  ;;  # core mesh: good balance
  32-2) NUM_CTX=16384  ;;  # mid tier: room for 27B + context
  16-1) NUM_CTX=4096   ;;  # edge: tight, swap-backed
  16-2) NUM_CTX=32768  ;;  # fleet: 9B model is small, spend on context
  *)    NUM_CTX=8192   ;;  # unassigned default
esac

# listen on all interfaces so PromptRouter can reach any node
sudo tee "${OLLAMA_OVERRIDE}/exocortical.conf" << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_VULKAN=1"
Environment="OLLAMA_MAX_LOADED_MODELS=${MAX_MODELS}"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KEEP_ALIVE=24h"
Environment="OLLAMA_NUM_CTX=${NUM_CTX}"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama 2>/dev/null || true
echo "[phase 4] Ollama configured: max_models=${MAX_MODELS} ctx=${NUM_CTX} vulkan=1"

# ============================================================
# Phase 5: Model pulls (by shell + tier)
# ============================================================
echo "[phase 5] Model pulls..."

pull_model() {
  local model="$1"
  echo "[phase 5] Pulling ${model}..."
  ollama pull "$model"
}

if [ "$EXOCORTEX_SHELL" -eq 1 ]; then
  # Shell 1: all nodes run Nemotron Cascade 2
  pull_model "nemotron-cascade-2:30b"

elif [ "$EXOCORTEX_SHELL" -eq 2 ]; then
  case "$RAM_TIER" in
    96)
      # Oracle node: heaviest local model
      pull_model "qwen3.5:122b"
      ;;
    32)
      # Mid tier: dense 27B for coding + general work
      pull_model "qwen3.5:27b"
      ;;
    16|*)
      # Fleet: fast 9B for routing and simple tasks
      pull_model "qwen3.5:9b"
      ;;
  esac

else
  echo "[phase 5] No shell assigned (EXOCORTEX_SHELL=0). Skipping model pulls."
  echo "  Re-run with: EXOCORTEX_SHELL=1 $0  (mirrorborn)"
  echo "           or: EXOCORTEX_SHELL=2 $0  (utility fleet)"
fi

# ============================================================
# Phase 6: Firewall - allow Ollama on LAN only
# ============================================================
echo "[phase 6] Firewall rules..."

if command -v ufw &>/dev/null; then
  # allow Ollama API from LAN (adjust subnet as needed)
  sudo ufw allow from 192.168.0.0/16 to any port 11434 proto tcp 2>/dev/null || true
  # allow SQ phext cache from LAN
  sudo ufw allow from 192.168.0.0/16 to any port 1337 proto tcp 2>/dev/null || true
  echo "[phase 6] Firewall rules applied."
else
  echo "[phase 6] ufw not found, skipping."
fi

# ============================================================
# Done
# ============================================================
echo ""
echo "=== Exocortical LLM Optimization Complete ==="
echo "  RAM tier:    ${RAM_TIER} GB"
echo "  Shell:       ${EXOCORTEX_SHELL}"
echo "  Ollama:      vulkan=1 flash_attn=1 ctx=${NUM_CTX}"
echo "  Max models:  ${MAX_MODELS}"
echo "  GTT size:    ${GTT_MB} MB (reboot to apply)"
echo "  Swap:        $(swapon --show --noheadings --bytes | awk '{s+=$3}END{printf "%.0f GB", s/1073741824}')"
echo ""

if [ "$GRUB_UPDATED" -eq 1 ]; then
  echo "*** REBOOT REQUIRED for amdgpu.gttsize and iommu changes ***"
fi

echo "Done" | sudo tee "$SETUP_FILE"
