#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TCPDUMP_BIN="${TCPDUMP_BIN:-$ROOT/install/sbin/tcpdump}"
IN_DIR="${IN_DIR:-$ROOT/corpora/in}"
OUT_DIR="${OUT_DIR:-$ROOT/corpora/in_min}"

if [[ ! -x "$TCPDUMP_BIN" ]]; then
  echo "Missing tcpdump binary: $TCPDUMP_BIN" >&2
  echo "Build fast target first: ./scripts/build_target.sh" >&2
  exit 1
fi

if [[ ! -d "$IN_DIR" ]]; then
  echo "Missing input dir: $IN_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR"/*

afl-cmin -m none -i "$IN_DIR" -o "$OUT_DIR" -- "$TCPDUMP_BIN" -n -r @@
echo "Minimized corpus written to: $OUT_DIR"
