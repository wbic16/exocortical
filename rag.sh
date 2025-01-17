#!/bin/bash
QUERY=$1
RAG_SOURCE="/usr/local/exollama"
#MODEL="tinyllama" #speed
MODEL="llama3.2" #accuracy
if [ "x$2" != "x" ]; then RAG_SOURCE=$2; fi
if [ "x$3" != "x" ]; then MODEL=$3; fi
if [ "x$1" = "x" ]; then
  echo "Usage: $0 <query> (optional: <directory>)"
  exit 1
fi
/opt/exopy/bin/python rag.py "$RAG_SOURCE" "$MODEL" "$QUERY" 2>/dev/null
