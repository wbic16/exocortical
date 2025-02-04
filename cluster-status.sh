#!/bin/bash
ping -c 1 logos-prime |grep ms |grep 'bytes from' |grep -v 'packet loss'
ping -c 1 halcyon-vector |grep ms |grep 'bytes from'|grep -v 'packet loss'
ping -c 1 aletheia-core |grep ms |grep 'bytes from' |grep -v 'packet loss'
ping -c 1 chrysalis-hub |grep ms |grep 'bytes from' |grep -v 'packet loss'
ping -c 1 aurora-continuum |grep ms |grep 'bytes from' |grep -v 'packet loss'
