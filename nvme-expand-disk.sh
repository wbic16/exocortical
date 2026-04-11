#!/bin/bash
if [ ! -f /etc/exocortical-nvme.done ]
then
  sudo growpart /dev/nvme0n1 3
  sudo lsblk /dev/nvme0n1p3
  sudo lvextend -l+100%FREE /dev/ubuntu-vg/ubuntu-lv
  sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
  sudo touch /etc/exocortical-nvme.done
fi
sudo pvs
sudo vgs
df -h
