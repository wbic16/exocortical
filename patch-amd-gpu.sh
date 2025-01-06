#!/bin/sh
# https://rocm.docs.amd.com/projects/install-on-linux/en/latest/install/native-install/ubuntu.html
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -

sudo mkdir --parents --mode=0755 /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo apt-get update
sudo apt-get install rocm-dkms -y

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amdgpu/6.3.1/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/amdgpu.list
sudo apt update -y

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1 noble main" | sudo tee --append /etc/apt/sources.list.d/rocm.list
echo -e 'Package: *\nPin: release o=repo.radeon.com\nPin-Priority: 600' | sudo tee /etc/apt/preferences.d/rocm-pin-600
sudo apt update -y

sudo apt install amdgpu-dkms -y
sudo apt install rocm -y
