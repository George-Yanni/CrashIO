#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IN_MIN="$ROOT/corpora/in_min"
OUT_TINY="$ROOT/corpora/in_tiny"
MAX_FILES="${MAX_FILES:-4}"

if [[ ! -d "$IN_MIN" ]]; then
  echo "Missing minimized corpus dir: $IN_MIN" >&2
  echo "Run ./scripts/minimize_corpus.sh first." >&2
  exit 1
fi

mkdir -p "$OUT_TINY"
rm -rf "$OUT_TINY"/*

ls -1S "$IN_MIN" | head -n "$MAX_FILES" | while read -r f; do
  cp "$IN_MIN/$f" "$OUT_TINY/"
done

echo "Tiny corpus ($MAX_FILES files) ready in: $OUT_TINY"
