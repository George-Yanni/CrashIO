#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Building ASan target for triage..."
cd "$ROOT/third_party/libxml2-2.9.4"
make clean >/dev/null 2>&1 || true

./configure --prefix="$ROOT/install_asan" \
  --disable-shared \
  --without-debug --without-ftp --without-http \
  --without-legacy --without-python \
  CC=afl-clang-fast CXX=afl-clang-fast++ \
  CFLAGS="-fsanitize=address" CXXFLAGS="-fsanitize=address" LDFLAGS="-fsanitize=address" LIBS='-ldl'

make -j"$(nproc)" >/dev/null 2>&1
make install >/dev/null 2>&1
echo "ASan target installed to $ROOT/install_asan"
