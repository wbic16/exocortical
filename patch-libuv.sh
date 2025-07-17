#!/bin/bash
cd /source
if [ ! -d ./libuv ]; then
  git clone https://github.com/libuv/libuv.git --depth 1
fi
cd libuv
git pull --depth 100
git checkout v1.51.0
sudo apt install automake libtool -y
./autogen.sh
./configure
make && sudo make install
