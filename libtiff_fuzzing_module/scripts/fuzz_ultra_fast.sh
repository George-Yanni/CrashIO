#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure we have the tiny corpus
if [[ ! -d "$ROOT/corpora/in_tiny" ]]; then
  "$ROOT/scripts/prepare_tiny_corpus.sh"
fi

IN_DIR="$ROOT/corpora/in_tiny" \
OUT_DIR="$ROOT/corpora/out_ultra_fast" \
AFL_ARGS="-a text" \
TARGET_ARGS="-D -j -c -r -s -w @@" \
"$ROOT/scripts/fuzz.sh"
