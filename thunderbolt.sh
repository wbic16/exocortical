#!/bin/bash
ID=$1
if [ -z $ID ]; then ID=1; fi
sudo nmcli connection delete tb0
sudo nmcli connection delete tb1
sudo nmcli connection add type ethernet ifname thunderbolt0 con-name tb0 ipv4.method manual ipv4.addresses 10.42.43.$ID/24 ipv4.gateway 10.42.43.$ID
ID=$(($ID + 1))
sudo nmcli connection add type ethernet ifname thunderbolt1 con-name tb1 ipv4.method manual ipv4.addresses 10.42.43.$ID/24 ipv4.gateway 10.42.43.$ID
sudo netplan apply
