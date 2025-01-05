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

sudo apt update -y

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
sudo apt install neovim -y

# LLM agents
curl -fsSL https://ollama.com/install.sh >install_ollama.sh
chmod +x install_ollama.sh
LLM_AGENT="ollama"
ollama --version
if [ $? -ne 0 ]; then
  ./install_ollama.sh
fi
echo "[ollama] llama3.2 test:"
ollama run llama3.2 --verbose "hello, from llama 3.2"
echo "[ollama] mistral test:"
ollama run mistral --verbose "hello, from mistral"
echo "[ollama] qwen2:7b test:"
ollama run qwen2:7b --verbose "hello, from qwen2"
echo "[ollama] gemma:7b test:"
ollama run gemma:7b --verbose "hello, from gemma"
# Set LLM_AGENT=exollama to enable basic LLM functionality
# Set LLM_AGENT=micro to enable the npm-based micro-agent
if [ $LLM_AGENT -eq "micro" ]; then
  sudo apt install npm -y
  sudo npm install -g @builder.io/micro-agent
fi

# rust development
sudo apt install rustup -y
sudo rustup default stable
rustup default stable

# phext tools
cargo install phext-shell
cargo install hello-phext
cargo install quickfork
cargo install sq

IN_PATH=`grep '\.cargo\/bin' ~/.bashrc -c`
if [ $IN_PATH = 0 ]; then
  echo "Adding Rust programs to PATH - login again to activate"
  echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" >>$HOME/.bashrc
fi

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
#if [ ! -d /opt/exo-explore ]; then
#  sudo mkdir /opt/exo-explore
#  sudo chown $USER:$USER /opt/exo-explore
#  cd /opt/exo-explore
#  git clone git@github.com:exo-explore/exo.git .
#fi

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
#cd /opt/exo-explore
#/opt/exopy/bin/pip install -e .

if [ ! -d /source ]; then
  echo "Fetching Exocortex source trees..."
  sudo mkdir /source
  sudo chown $USER:$USER /source
fi

cd /source
# The Exocortex
if [ ! -d /source/exocortical ]; then
  git clone git@github.com:wbic16/exocortical.git
fi
if [ ! -d /source/wishnode ]; then
  git clone git@github.com:wbic16/wishnode.git
fi
if [ ! -d /source/exocortex ]; then
  git clone git@github.com:wbic16/exocortex.git
fi
if [ ! -d /source/human ]; then
  git clone git@github.com:wbic16/human.git
fi
if [ ! -d /source/nexura ]; then
  git clone git@github.com:wbic16/nexura.git
fi
if [ ! -d /source/thebook ]; then
  git clone git@github.com:wbic16/thebook.git
fi

# Phext Core
if [ ! -d /source/libphext-rs ]; then
  git clone git@github.com:wbic16/libphext-rs.git
fi
if [ ! -d /source/SQ ]; then
  git clone git@github.com:wbic16/SQ.git
fi
if [ ! -d /source/phext-notepad ]; then
  git clone git@github.com:wbic16/phext-notepad.git
fi
if [ ! -d /source/phext-shell ]; then
  git clone git@github.com:wbic16/phext-shell.git
fi
if [ ! -d /source/phext-explorer ]; then
  git clone git@github.com:wbic16/phext-explorer.git
fi

  # Phext Implementations (JS, C, C++)
if [ ! -d /source/libphext-node ]; then
  git clone git@github.com:wbic16/libphext-node.git
fi
if [ ! -d /source/libphext ]; then
  git clone git@github.com:wbic16/libphext.git
fi
if [ ! -d /source/libphext-cpp ]; then
  git clone git@github.com:wbic16/libphext-cpp.git
fi

  # Phext Tools
if [ ! -d /source/phcc ]; then
  git clone git@github.com:wbic16/phcc.git
fi

  # Phext Applications
if [ ! -d /source/dna-viewer ]; then
  git clone git@github.com:wbic16/dna-viewer.git
fi
if [ ! -d /source/phorge ]; then
  git clone git@github.com:wbic16/phorge.git
fi
  
  # Games
if [ ! -d /source/mini64k ]; then
  git clone git@github.com:wbic16/mini64k.git
fi
if [ ! -d /source/javascript-tetris ]; then
  git clone git@github.com:wbic16/javascript-tetris.git
fi
if [ ! -d /source/multiversal-go ]; then
  git clone git@github.com:wbic16/multiversal-go.git
fi

  # APIs
if [ ! -d /source/hello-phext ]; then
  git clone git@github.com:wbic16/hello-phext.git
fi
if [ ! -d /source/phext-wiki ]; then
  git clone git@github.com:wbic16/phext-wiki.git
fi
if [ ! -d /source/robospeak ]; then
  git clone git@github.com:wbic16/robospeak.git
fi
if [ ! -d /source/subspace-repeater ]; then
  git clone git@github.com:wbic16/subspace-repeater.git
fi

  # Web Sites
if [ ! -d /source/singularity-watch ]; then
  git clone git@github.com:wbic16/singularity-watch.git
fi
if [ ! -d /source/wbic16 ]; then
  git clone git@github.com:wbic16/wbic16.git
fi
if [ ! -d /source/phextio ]; then
  git clone git@github.com:wbic16/phextio.git
fi
if [ ! -d /source/sotafomo ]; then
  git clone git@github.com:wbic16/sotafomo.git
fi

  # Teaching
if [ ! -d /source/teach-web-dev ]; then
  git clone git@github.com:wbic16/teach-web-dev.git
fi

  # Web/Social
if [ ! -d /source/x-analysis ]; then
  git clone git@github.com:wbic16/x-analysis.git
fi
if [ ! -d /source/node-visualizer ]; then
  git clone git@github.com:wbic16/node-visualizer.git
fi

if [ ! -d /source/the-book-of-secret-knowledge ]; then
  git clone https://github.com/wbic16/the-book-of-secret-knowledge.git
fi

if [ "x$LLM_AGENT" = "xmicro" ]; then
  if [ ! -d /opt/micro-agent ]; then
    cd /opt
    sudo mkdir micro-agent
    sudo chown $USER:$USER micro-agent
    cd micro-agent
    micro-agent
  fi
fi

echo "Setup Complete."
