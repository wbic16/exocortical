#!/bin/bash
ID=$1
if [ -z $ID ]; then ID=1; fi
sudo nmcli connection delete tb0
sudo nmcli connection delete tb1
TB_FIRST="tb0"
TB_SECOND="tb1"
if [ -f .tb-switch ]; then
  TB_FIRST="tb1"
  TB_SECOND="tb0"
fi
FIRST_NETWORK=43
SECOND_NETWORK=44
if [ -f .tb0-network ]; then
  FIRST_NETWORK=`cat .tb0-network`
fi
if [ -f .tb1-network ]; then
  SECOND_NETWORK=`cat .tb1-network`
fi
sudo nmcli connection add type ethernet ifname thunderbolt0 con-name $TB_FIRST ipv4.method manual ipv4.addresses 10.42.$FIRST_NETWORK.$ID/24 ipv4.gateway 10.42.$FIRST_NETWORK.$ID
ID=$(($ID + 1))
sudo nmcli connection add type ethernet ifname thunderbolt1 con-name $TB_SECOND ipv4.method manual ipv4.addresses 10.42.$SECOND_NETWORK.$ID/24 ipv4.gateway 10.42.$SECOND_NETWORK.$ID
sudo netplan apply
