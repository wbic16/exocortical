#!/bin/sh
if [ -d /opt/beebjit ]; then
  cd /opt/beebjit
  ./build.sh
  ./benchmark.sh
fi
