#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/third_party"
mkdir -p "$TP"
cd "$TP"

TIFF_TGZ="tiff-4.0.4.tar.gz"

if [[ ! -f "$TIFF_TGZ" ]]; then
  wget -O "$TIFF_TGZ" "https://download.osgeo.org/libtiff/tiff-4.0.4.tar.gz"
fi

tar -xzf "$TIFF_TGZ"

echo "Sources under: $TP"
echo "  libtiff: $TP/tiff-4.0.4"
