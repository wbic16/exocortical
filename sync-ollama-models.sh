#!/bin/bash
# ollama-sync.sh - Bidirectional model sync between two nodes
# Usage: ollama-sync.sh <remote-host>

REMOTE="${1:?Usage: ollama-sync.sh <remote-host>}"
OLLAMA_HOME="/usr/share/ollama"
MODELS="$OLLAMA_HOME/.ollama/models/"

echo "=== Terminating ollama instances ==="
sudo killall ollama
ssh ${REMOTE} "sudo killall ollama"

# allow the current user to do work
ssh ${REMOTE} "sudo chown -R $USER:$USER ${OLLAMA_HOME}"
chown -R $USER:$USER ${OLLAMA_HOME}

echo "=== Pulling from ${REMOTE} ==="
rsync -av --progress ${REMOTE}:${MODELS} ${MODELS}

echo "=== Pushing to ${REMOTE} ==="
rsync -av --progress ${MODELS} ${REMOTE}:${MODELS}

echo "=== Fixing ownership ==="
sudo chown -R ollama:ollama ${OLLAMA_HOME}
ssh ${REMOTE} "sudo chown -R ollama:ollama ${OLLAMA_HOME}"

echo "Done."
