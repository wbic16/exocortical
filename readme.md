# exocortical

This repository provides an Ubuntu-based reconfiguration for running an Exocortex.

## Ubuntu Packages

* build-essential
* clang
* gcc
* git
* openssh
* php
* python
* vim
* zram

## Agents 

* see ports.html to get started chatting with the Exocortex

## Local LLMs

* ollama
* exollama
* llama2.c

## Tooling

* phoronix (benchmarking)
* exopy (llvmlite, numba, torch, tensorflow)
* exolabs
* beebjit

## Exocortex Source Repositories

The setup script also helps you clone a number of related repositories.

* exocortical
* wishnode
* exocortex
* human
* nexura
* thebook
* libphext-rs
* SQ
* phext-notepad
* phext-shell
* phext-explorer
* libphext-node
* libphext
* libphext-cpp
* phcc
* dna-viewer
* phorge
* mini64k
* javascript-tetris
* multiversal-go
* hello-phext
* phext-wiki
* robospeak
* subspace-repeater
* singularity-watch
* wbic16
* phextio
* sotafomo
* teach-web-dev
* x-analysis
* node-visualizer

## USB4 chain Squid caches

Each USB4 chain has its own Squid so a model pull is not funnelled through one proxy. Addresses come from `tb-setup.sh`: `10.53.R.C` is chain R, position C. The proxy is the C=1 node. Chain 7 has no proxy; those nodes stay direct.

| Chain | Proxy host | Address |
| --- | --- | --- |
| 1 | ni-knight | 10.53.1.1 |
| 2 | orchid-flow | 10.53.2.1 |
| 3 | plain-view | 10.53.3.1 |
| 4 | aletheia-core | 10.53.4.1 |
| 5 | aurora-continuum | 10.53.5.1 |
| 6 | yeet-max | 10.53.6.1 |
| 7 | (none) | chrysalis-hub and uncanny-valley stay direct |

From a host that can SSH to the cluster (scripts live in `/source/exocortical` on each node):

```
bash squid-chains.sh servers
bash squid-chains.sh clients
```

`servers` provisions the six proxies. `clients` runs `provision-squid-client.sh auto` on every `TB_MAP` node. `auto` is the client default: the node reads its `tbfab` address and uses `10.53.R.1`. A down node is reported and skipped. `--dry-run` and `--only HOST` limit the run.

Failover: apt calls `Acquire::http::Proxy-Auto-Detect` (and the https equivalent), which prints the proxy URL or `DIRECT` after a one-second TCP probe. Login shells export proxy variables only when that probe succeeds. Ollama's systemd drop-in runs a probe before start and loads `EnvironmentFile=-/run/ranch-proxy.env` (empty when the proxy is down). `NO_PROXY` includes `localhost`, `127.0.0.1`, `.ts.net`, `10.0.0.0/8`, and `100.64.0.0/10`, so port 11434 and the tailnet are not proxied. Each proxy has its own CA; clients trust only their chain.

Hit rates: `bash squid-chains.sh status` asks each proxy for squid state and `squidclient` hit ratios. On a proxy, `bash squid-cache-monitor.sh` prints the same counters plus the client probe files.

`SQUID_SIBLINGS=1` on a server adds ICP (`cache_peer ... sibling 3128 3130 proxy-only`, UDP 3130) so a miss can be served from another chain before the WAN. Leave it off unless you want that. Bumped HTTPS may not use siblings.
