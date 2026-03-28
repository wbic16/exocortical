#!/bin/bash
sudo visudo
sudo mkdir /source
sudo chown $USER:$USER /source
cd /source
if [ ! -d exocortical ]; then
  git clone git@github.com:wbic16/exocortical.git
fi
cd exocortical
./enable-virtual-memory.sh
g/setup.sh
