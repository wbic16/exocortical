#!/bin/bash
git pull
sudo apt update

# general dev ux
sudo apt install git -y
sudo apt install git-lfs -y
sudo apt install zram-config -y
sudo apt install net-tools -y
sudo apt install build-essential -y
sudo apt install clang -y
sudo apt install vim -y
sudo apt install htop -y
sudo apt install openssh-server -y
sudo apt install apt-file -y
sudo apt install lm-sensors -y
sudo apt install libfuse2t64 -y

# exo / tinygrad
sudo apt install python3.12-venv -y
sudo apt install linux-libc-dev -y
sudo apt install python3-dev -y
sudo apt install python3-pip -y

# for phoronix
sudo apt install php -y
sudo apt install gparted -y
sudo apt install screen -y

# for beebjit
sudo apt install libasound2-dev -y
sudo apt install libpulse-dev -y
sudo apt install libxext-dev -y

if [ ! -d /opt/phoronix ]; then
  sudo mkdir /opt/phoronix
  sudo chown $USER:$USER /opt/phoronix
  cd /opt/phoronix
  wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite_10.8.4_all.deb
  sudo apt install ./phoronix-test-suite_10.8.4_all.deb -y
fi

# python virtual environment
if [ ! -d /opt/exopy ]; then
  sudo mkdir /opt/exopy
  sudo chown $USER:$USER /opt/exopy
  python3 -m venv /opt/exopy
fi
if [ -d /opt/exopy ]; then
  /opt/exopy/bin/pip3 install llvmlite
  /opt/exopy/bin/pip3 install numba
  /opt/exopy/bin/pip3 install torch
  /opt/exopy/bin/pip3 install tensorflow
fi

# opinionated system config
git config --global init.defaultBranch exo
git config pull.rebase true

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
  git clone git@github.com:wbic16/exo.git .
  git checkout fix-issue-458
fi

if [ ! -d /opt/ROCm ]; then
  sudo mkdir /opt/ROCm
  sudo chown $USER:$USER /opt/ROCm
  cd /opt/ROCm
  git clone git@github.com:ROCm/ROCm.git .
  git checkout roc-6.3.x
  git pull
fi

if [ ! -d /opt/beebjit ]; then
  sudo mkdir /opt/beebjit
  sudo chown $USER:$USER /opt/beebjit
  cd /opt/beebjit
  git clone git@github.com:wbic16/beebjit.git .
  ./build.sh
  ./benchmark.sh
fi

sudo apt upgrade
