#!/bin/bash
sudo chown $USER:$USER tailscale*.sh
curl -fsSL https://tailscale.com/install.sh >tailscale_install.sh
git diff
git status
GO="n"
echo "Review the upstream changes, press Y to proceed"
read GO
if [ "x$GO" = "xY" ]
then
  chmod +x tailscale_install.sh
  sudo ./tailscale_install.sh
fi
git add tailscale_install.sh
git status
