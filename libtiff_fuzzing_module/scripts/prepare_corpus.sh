#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/third_party/tiff-4.0.4/test/images"
IN_DIR="$ROOT/corpora/in"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "Missing tests directory: $TESTS_DIR" >&2
  echo "Run ./scripts/fetch_sources.sh first." >&2
  exit 1
fi

mkdir -p "$IN_DIR"

shopt -s nullglob
files=("$TESTS_DIR"/*.tiff "$TESTS_DIR"/*.tif)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .tiff files found in $TESTS_DIR" >&2
  exit 1
fi

cp "${files[@]}" "$IN_DIR/"
echo "Copied ${#files[@]} seed file(s) into $IN_DIR"
