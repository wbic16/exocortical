#!/bin/bash

# packages
sudo apt install git -y
sudo apt install zram-config -y
sudo apt install build-essential -y
sudo apt install vim -y
sudo apt install htop -y
sudo apt install openssh-server -y

# system config
git config --global init.defaultBranch exo

# security
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
  echo "No SSH Identity found...generating one."
  ssh-keygen -t ed25519
fi
