#!/bin/bash
HAVE_ZRAM=`lsmod |grep zram |wc -l`
if [ ! $HAVE_ZRAM -eq 0 ]; then
  swapoff /dev/zram0
  rmmod zram
fi
modprobe zram

# 1.5x RAM
RAM_KB=`cat /proc/meminfo |grep MemTotal |awk '{print $2}'`
RAM_BYTES=$(($RAM_KB * 1024))
RAM_GB=$(($RAM_KB / 1024 / 1024))
mem=$(($RAM_BYTES * 15 / 10))
echo "Allocated $RAM_GB GB"

# initialize the devices
echo $mem > /sys/block/zram0/disksize
mkswap -fq /dev/zram0
swapon -p 5 /dev/zram0

zramctl
