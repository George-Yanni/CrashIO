#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/third_party"
BUILD_PROFILE="${BUILD_PROFILE:-fast}"
if [[ "$BUILD_PROFILE" == "asan" ]]; then
  INSTALL_DIR="${INSTALL_DIR:-$ROOT/install_asan}"
  export AFL_USE_ASAN=1
else
  INSTALL_DIR="${INSTALL_DIR:-$ROOT/install}"
  unset AFL_USE_ASAN
fi
LIBPCAP_DIR="$TP/libpcap-1.8.0"
TCPDUMP_DIR="$TP/tcpdump-tcpdump-4.9.2"

if [[ ! -d "$LIBPCAP_DIR" || ! -d "$TCPDUMP_DIR" ]]; then
  echo "Sources are missing in $TP" >&2
  echo "Run ./scripts/fetch_sources.sh first." >&2
  exit 1
fi

if command -v afl-clang-lto >/dev/null 2>&1; then
  AFL_CC="${AFL_CC:-afl-clang-lto}"
else
  AFL_CC="${AFL_CC:-afl-clang-fast}"
fi

echo "Using AFL compiler wrapper: $AFL_CC"
echo "Build profile: $BUILD_PROFILE"
echo "Install dir: $INSTALL_DIR"

rm -rf "$INSTALL_DIR"

cd "$LIBPCAP_DIR"
make distclean 2>/dev/null || make clean || true
CC="$AFL_CC" ./configure --enable-shared=no --prefix="$INSTALL_DIR"
make clean || true
make CC="$AFL_CC" -j"$(nproc)"
make CC="$AFL_CC" install

cd "$TCPDUMP_DIR"
make distclean 2>/dev/null || make clean || true
# Legacy tcpdump configure checks use pre-C99 style probe code.
# Force GNU89 for configure-stage tests on modern toolchains.
CC="$AFL_CC" CFLAGS="${CONFIGURE_CFLAGS:--std=gnu89}" ./configure --prefix="$INSTALL_DIR"
make clean || true
make CC="$AFL_CC" -j"$(nproc)"
make CC="$AFL_CC" install

echo "Build complete: $INSTALL_DIR/sbin/tcpdump"
