#!/bin/bash
ACCOUNT="wbic16"
ready=1
if [ -z $1 ]; then
  ready=0
else
  directory=$1
fi
if [ -z $2 ]; then
  ready=0
else
  other=$2
fi
if [ ! -z $3 ]; then
  ACCOUNT=$3
fi
if [ $ready -eq 1 ]; then
  rsync -varzP $directory $ACCOUNT@$other:$directory/
else
  echo "Usage: $0 <dir> <server> (<account>)"
  exit 1
fi
