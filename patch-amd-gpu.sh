#!/bin/sh
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.5 jammy main' |sudo tee /etc/apt/sources.list.d/rocm.list
sudo apt-get update
sudo apt-get install rocm-dkms
sudo add-apt-repository -y -s deb http://security.ubuntu.com/ubuntu jammy main universe
