#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Building FAST target (No ASan) for optimal fuzzer speed..."
cd "$ROOT/third_party/libxml2-2.9.4"
make clean >/dev/null 2>&1 || true

./autogen.sh >/dev/null 2>&1 || true
./configure --prefix="$ROOT/install" \
  --disable-shared \
  --without-debug --without-ftp --without-http \
  --without-legacy --without-python \
  CC=afl-clang-fast CXX=afl-clang-fast++

make -j"$(nproc)" >/dev/null 2>&1
make install >/dev/null 2>&1
echo "Fast target installed to $ROOT/install"
