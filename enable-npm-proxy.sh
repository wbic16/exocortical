#!/bin/bash
SQUID_IP="$1"
if [ -z $SQUID_IP ]
then
  echo "Usage: $0 <squid-ip>"
  exit 1
fi
SQUID_HTTP_PORT=3128
SQUID_SSL_PORT=3129
PROXY_HTTP="http://${SQUID_IP}:${SQUID_HTTP_PORT}"
PROXY_SSL="http://${SQUID_IP}:${SQUID_SSL_PORT}"
CA_LOCAL="/usr/local/share/ca-certificates/ranch-choir-squid-ca.crt"
if [ ! -f $CA_LOCAL ]
then
  echo "ERROR: Install the Squid CA first."
  exit 1
fi

npm config set proxy "${PROXY_HTTP}" --global
npm config set proxy "${PROXY_HTTP}"
npm config set https-proxy "${PROXY_SSL}" --global
npm config set https-proxy "${PROXY_SSL}"
npm config set cafile "$CA_LOCAL"
npm config get proxy
npm config get https-proxy
sudo update-ca-certificates
npm view openclaw version
