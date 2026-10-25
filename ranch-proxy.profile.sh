# Ranch Choir per-chain Squid. Login shells only export proxy variables
# when the chain proxy accepts a connection. A dead proxy leaves the shell direct.
# This file is sourced by /bin/sh (dash) from /etc/profile. Keep it POSIX.
# shellcheck shell=sh

_ranch_np="localhost,127.0.0.1,.ts.net,10.0.0.0/8,100.64.0.0/10"
if [ -r /etc/ranch-squid/client.env ]; then
  # shellcheck disable=SC1091
  . /etc/ranch-squid/client.env
  if [ -n "${NO_PROXY_LIST:-}" ]; then
    _ranch_np="$NO_PROXY_LIST"
  fi
fi

_ranch_http=""
_ranch_https=""
if [ -x /usr/local/bin/ranch-proxy-autodetect ]; then
  _ranch_http="$(/usr/local/bin/ranch-proxy-autodetect http 2>/dev/null || true)"
  _ranch_https="$(/usr/local/bin/ranch-proxy-autodetect https 2>/dev/null || true)"
fi

if [ -n "$_ranch_http" ] && [ "$_ranch_http" != "DIRECT" ]; then
  export http_proxy="$_ranch_http" HTTP_PROXY="$_ranch_http"
else
  unset http_proxy HTTP_PROXY
fi

if [ -n "$_ranch_https" ] && [ "$_ranch_https" != "DIRECT" ]; then
  export https_proxy="$_ranch_https" HTTPS_PROXY="$_ranch_https"
else
  unset https_proxy HTTPS_PROXY
fi

if [ -n "${http_proxy:-}" ] || [ -n "${https_proxy:-}" ]; then
  export no_proxy="$_ranch_np" NO_PROXY="$_ranch_np"
fi

if [ -r /usr/local/share/ca-certificates/ranch-choir-squid-ca.crt ]; then
  export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/ranch-choir-squid-ca.crt
fi

unset _ranch_np _ranch_http _ranch_https
