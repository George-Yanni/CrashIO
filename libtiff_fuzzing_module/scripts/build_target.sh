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
TIFF_DIR="$TP/tiff-4.0.4"

if [[ ! -d "$TIFF_DIR" ]]; then
  echo "Sources are missing in $TP" >&2
  echo "Run ./scripts/fetch_sources.sh first." >&2
  exit 1
fi

if command -v afl-clang-lto >/dev/null 2>&1; then
  AFL_CC="${AFL_CC:-afl-clang-lto}"
  AFL_CXX="${AFL_CXX:-afl-clang-lto++}"
else
  AFL_CC="${AFL_CC:-afl-clang-fast}"
  AFL_CXX="${AFL_CXX:-afl-clang-fast++}"
fi

echo "Using AFL compiler wrapper: $AFL_CC"
echo "Build profile: $BUILD_PROFILE"
echo "Install dir: $INSTALL_DIR"

rm -rf "$INSTALL_DIR"

cd "$TIFF_DIR"
make distclean 2>/dev/null || make clean || true
CC="$AFL_CC" CXX="$AFL_CXX" ./configure --prefix="$INSTALL_DIR" --disable-shared
make clean || true
make CC="$AFL_CC" CXX="$AFL_CXX" -j"$(nproc)"
make CC="$AFL_CC" CXX="$AFL_CXX" install

echo "Build complete: $INSTALL_DIR/bin/tiffinfo"
