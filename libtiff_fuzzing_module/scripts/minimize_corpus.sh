#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIFFINFO_BIN="${TIFFINFO_BIN:-$ROOT/install/bin/tiffinfo}"
IN_DIR="${IN_DIR:-$ROOT/corpora/in}"
OUT_DIR="${OUT_DIR:-$ROOT/corpora/in_min}"

if [[ ! -x "$TIFFINFO_BIN" ]]; then
  echo "Missing tiffinfo binary: $TIFFINFO_BIN" >&2
  echo "Build fast target first: ./scripts/build_target.sh" >&2
  exit 1
fi

if [[ ! -d "$IN_DIR" ]]; then
  echo "Missing input dir: $IN_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR"/*

afl-cmin -m none -i "$IN_DIR" -o "$OUT_DIR" -- "$TIFFINFO_BIN" -D -j -c -r -s -w @@
echo "Minimized corpus written to: $OUT_DIR"
