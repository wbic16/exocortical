#!/bin/bash
# little-mac.sh — power settings for little-mac (Will's Mac mini),
# rolled up as a headless server profile: never sleep, wake on LAN,
# and come back on its own after a power outage.
#
# Run it on the mini itself (SSH in first); sudo will prompt for the
# admin password. Settings take effect immediately, no reboot.
# `pmset -a` applies to all power sources — on a mini that is AC in
# practice.
set -e
echo "== before =="
pmset -g
pmset -g custom
echo "== applying headless server profile =="
sudo pmset -a sleep 0
sudo pmset -a displaysleep 5
sudo pmset -a disksleep 0
sudo pmset -a womp 1
sudo pmset -a autorestart 1
sudo pmset -a powernap 0
# Optional: scheduled daily wake at 06:00 — uncomment to enable.
# sudo pmset repeat wake MTWRFSU 06:00:00
# Harder never-sleep lock, if `sleep 0` proves not to be enough:
# sudo pmset -a disablesleep 1
echo "== after =="
pmset -g
