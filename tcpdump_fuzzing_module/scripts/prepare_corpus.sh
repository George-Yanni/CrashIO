#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/third_party/tcpdump-tcpdump-4.9.2/tests"
IN_DIR="$ROOT/corpora/in"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "Missing tests directory: $TESTS_DIR" >&2
  echo "Run ./scripts/fetch_sources.sh first." >&2
  exit 1
fi

mkdir -p "$IN_DIR"

shopt -s nullglob
files=("$TESTS_DIR"/*.pcap "$TESTS_DIR"/*.pcapng)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .pcap or .pcapng files found in $TESTS_DIR" >&2
  exit 1
fi

cp "${files[@]}" "$IN_DIR/"
echo "Copied ${#files[@]} seed file(s) into $IN_DIR"
