#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IN="$ROOT/corpora/in"
JPG=""
for d in "$ROOT/third_party/exif-samples-master/jpg" "$ROOT/third_party/exif-samples-main/jpg"; do
  if [[ -d "$d" ]]; then
    JPG="$d"
    break
  fi
done
if [[ -z "$JPG" ]]; then
  echo "Run ./scripts/fetch_sources.sh first (expected exif-samples .../jpg)." >&2
  exit 1
fi
mkdir -p "$IN"
shopt -s nullglob
files=("$JPG"/*.jpg "$JPG"/*.JPG)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No JPEG files found under $JPG" >&2
  exit 1
fi
cp "${files[@]}" "$IN/"
echo "Copied ${#files[@]} JPEG seed(s) into $IN"
