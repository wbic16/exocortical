# enable-distributed-builds.sh -- SOURCE this file, do not execute it
# Turns the current shell into a distributed-build shell:
#   sccache in front of every compile (fleet-shared cache on the
#   orchid-flow NFS share), icecream behind it for C/C++ jobs, so
#   I/O-bound compiles spread across the fleet's iceccd daemons.
# The scheduler lives on aletheia-core (icecream-scheduler.sh);
# this node must already run iceccd (icecream-node.sh) and sccache
# (sccache-setup.sh).
# Usage: source /source/exocortical/enable-distributed-builds.sh
# ============================================================

# Scheduler for icecream client compiles (daemon config also has it,
# but the client reads the environment).
export ICECC_SCHEDULER_HOST="${ICECC_SCHEDULER_HOST:-aletheia-core}"

# sccache: shared cache location (matches sccache-setup.sh).
if [ -f /etc/profile.d/sccache.sh ]; then
  . /etc/profile.d/sccache.sh
fi
export SCCACHE_DIR="${SCCACHE_DIR:-/mnt/mirrorborn/shared/sccache}"
export SCCACHE_CACHE_SIZE="${SCCACHE_CACHE_SIZE:-50G}"

# Rust: sccache wraps rustc (cache only - icecream cannot carry
# rustc jobs). Incremental artifacts cannot be cached, so it is off.
export RUSTC_WRAPPER="$(command -v sccache)"
export CARGO_INCREMENTAL=0

# C/C++: sccache in front, the icecc client (as gcc/g++) behind it.
# On a cache miss the compile itself is handed to the cluster.
export CC="sccache /usr/lib/icecc/bin/gcc"
export CXX="sccache /usr/lib/icecc/bin/g++"

echo "distributed builds enabled on $(hostname):"
echo "  scheduler:  ${ICECC_SCHEDULER_HOST}"
echo "  cache:      sccache @ ${SCCACHE_DIR} (${SCCACHE_CACHE_SIZE})"
echo "  rustc:      via sccache"
echo "  cc/cxx:     via sccache -> icecream cluster"
