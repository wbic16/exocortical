#!/bin/bash
# inspired by: https://askubuntu.com/questions/33697/how-do-i-add-swap-after-system-installation
SETUP_FILE="/etc/exocortical-virtual-memory.done"
if [ -f $SETUP_FILE ]; then
  echo "Virtual memory already enabled"
  top -bn1 | grep -i swap
  exit 0
fi
if [ ! -d /var/cache/swap ]; then
  sudo mkdir -v /var/cache/swap
fi
cd /var/cache/swap
# 80GB swap
if [ ! -f swapfile ]; then
  sudo dd if=/dev/zero of=swapfile bs=4K count=20M
  sudo chmod 600 swapfile
  sudo mkswap swapfile
fi
sudo swapon swapfile
sudo swaplabel swapfile
ENABLED_ON_STARTUP=`grep -c '\/var\/cache\/swap\/swapfile' /etc/fstab`
if [ $ENABLED_ON_STARTUP -eq 0 ]; then
  echo "/var/cache/swap/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
  echo "Added swapfile to fstab"
fi
echo "Done" |sudo tee /etc/exocortical-virtual-memory.done
