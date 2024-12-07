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

if [ ! -f /etc/exo-ready ]; then
  echo ""
  echo "You need to touch /etc/exo-ready after uploading your public key to GitHub."
  echo ""
  cat ~/.ssh/id_ed25519.pub
  echo ""
  exit 1
fi

# external services
if [ ! -d /opt/exo-explore ]; then
  sudo mkdir /opt/exo-explore
  sudo chown $USER:$USER /opt/exo-explore
  cd /opt/exo-explore
  git clone git@github.com:exo-explore/exo.git .
fi
