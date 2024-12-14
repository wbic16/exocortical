#!/bin/bash
# opinionated system config
git config --global init.defaultBranch exo
git config pull.rebase true

git pull
ARG=$1
if [ "x$ARG" = "xexec" ]; then
  echo "Ready to update."
else
  $0 exec
  exit $?
fi

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

# rust development
sudo apt install rustup -y

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
fi

sudo apt upgrade -y
cd /opt/exo-explore
/opt/exopy/bin/pip install -e .

if [ ! -d /source ]; then
  echo "Fetching Exocortex source trees..."
  sudo mkdir /source
  sudo chown $USER:$USER /source
  cd /source
  
  # The Exocortex
  git clone git@github.com:wbic16/exocortical.git
  git clone git@github.com:wbic16/wishnode.git
  git clone git@github.com:wbic16/exocortex.git
  git clone git@github.com:wbic16/human.git
  git clone git@github.com:wbic16/nexura.git
  git clone git@github.com:wbic16/thebook.git

  # Phext Core
  git clone git@github.com:wbic16/libphext-rs.git
  git clone git@github.com:wbic16/SQ.git
  git clone git@github.com:wbic16/phext-notepad.git
  git clone git@github.com:wbic16/phext-shell.git
  git clone git@github.com:wbic16/phext-explorer.git

  # Phext Implementations (JS, C, C++)
  git clone git@github.com:wbic16/libphext-node.git
  git clone git@github.com:wbic16/libphext.git
  git clone git@github.com:wbic16/libphext-cpp.git

  # Phext Tools
  git clone git@github.com:wbic16/phcc.git

  # Phext Applications
  git clone git@github.com:wbic16/dna-viewer.git
  git clone git@github.com:wbic16/phorge.git
  
  # Games
  git clone git@github.com:wbic16/mini64k.git
  git clone git@github.com:wbic16/javascript-tetris.git
  git clone git@github.com:wbic16/multiversal-go.git

  # APIs
  git clone git@github.com:wbic16/hello-phext.git
  git clone git@github.com:wbic16/phext-wiki.git
  git clone git@github.com:wbic16/robospeak.git
  git clone git@github.com:wbic16/subspace-repeater.git

  # Web Sites
  git clone git@github.com:wbic16/singularity-watch.git
  git clone git@github.com:wbic16/wbic16.git
  git clone git@github.com:wbic16/phextio.git
  git clone git@github.com:wbic16/sotafomo.git

  # Teaching
  git clone git@github.com:wbic16/teach-web-dev.git

  # Web/Social
  git clone git@github.com:wbic16/twitter-analysis.git
  git clone git@github.com:wbic16/ContactStrengthMeter.git
fi

echo "Setup Complete."
