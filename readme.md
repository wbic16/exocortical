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
* cmake, ninja-build, gettext, unzip (exovim build — see below)
* lua5.1, liblua5.1-0-dev (exovim configure prerequisites)

## Exovim (phext Neovim)

Phase 12 of `setup.sh` bundles **exovim** — the phext-support fork of
Neovim ([wbic16/neovim](https://github.com/wbic16/neovim)) — on every
node. It clones the fork to `/source/neovim`, builds it with the system
compiler, and installs it into the `/opt/exovim` prefix; the command is
`exovim` (a symlink at `/usr/local/bin/exovim`). Opening any `.phext`
file in exovim gives scroll-as-buffer editing with coordinate
navigation (`:PhextToc`, `:PhextGoto`, `]]`/`[[` — `:help phext.txt`).
Re-running setup rebuilds exovim only when the fork's master has moved
(the built commit is stamped in `/opt/exovim/.exovim-commit`). A phcc
build variant is documented as a comment in the Phase 12 block of
`setup.sh`.

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
* neovim (exovim — built and installed by setup Phase 12)
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
