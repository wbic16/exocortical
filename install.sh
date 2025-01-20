#!/bin/bash
if [ ! -d /usr/local/exocortical ]; then
  sudo mkdir /usr/local/exocortical
  sudo chown $USER:$USER /usr/local/exocortical
fi
cp rag.* /usr/local/exocortical
