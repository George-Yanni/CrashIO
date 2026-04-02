#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT/corpora/in_min}"
if [[ ! -d "$SRC_DIR" ]]; then
  SRC_DIR="$ROOT/corpora/in"
fi
OUT_DIR="${OUT_DIR:-$ROOT/corpora/in_tiny}"
MAX_FILES="${MAX_FILES:-32}"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Missing source corpus dir: $SRC_DIR" >&2
  echo "Run ./scripts/prepare_corpus.sh first." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR"/*

python3 - "$SRC_DIR" "$OUT_DIR" "$MAX_FILES" <<'PY'
import os
import shutil
import sys

src, out, max_files = sys.argv[1], sys.argv[2], int(sys.argv[3])
entries = []
for name in os.listdir(src):
    p = os.path.join(src, name)
    if os.path.isfile(p):
        entries.append((os.path.getsize(p), name, p))

entries.sort(key=lambda t: t[0])
chosen = entries[:max_files]
for _, name, path in chosen:
    shutil.copy2(path, os.path.join(out, name))

print(f"Selected {len(chosen)} smallest files from {src} into {out}")
PY
