#!/bin/bash
if [ ! -f /etc/sysctl.d/99-minimize-disk-io.conf ]
then
  cat << 'EOF' | sudo tee /etc/sysctl.d/99-minimize-disk-io.conf
# keep everything in memory
vm.swappiness = 1
vm.dirty_ratio = 80
vm.dirty_background_ratio = 50
vm.dirty_expire_centisecs = 6000
vm.dirty_writeback_centisecs = 6000
vm.vfs_cache_pressure = 10
EOF
  sudo sysctl --system
fi

sudo systemctl disable --now snapd snapd.socket snapd.seeded.service snapd.apparmor.service
sudo systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer
echo none | sudo tee /sys/block/sda/queue/scheduler

if [ ! -f /etc/systemd/journald.conf.d/volatile.conf ]
then
  sudo mkdir -p /etc/systemd/journald.conf.d
  cat << 'EOF' | sudo tee /etc/systemd/journald.conf.d/volatile.conf
[Journal]
Storage=volatile
RuntimeMaxUse=512M
EOF
  sudo systemctl restart systemd-journald
fi
