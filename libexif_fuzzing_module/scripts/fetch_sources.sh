#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/third_party"
mkdir -p "$TP"
cd "$TP"

LIBEXIF_TGZ="libexif-0_6_14-release.tar.gz"
EXIF_CLI_TGZ="exif-0_6_15-release.tar.gz"
SAMPLES_ZIP="exif-samples-master.zip"

if [[ ! -f "$LIBEXIF_TGZ" ]]; then
  wget -O "$LIBEXIF_TGZ" "https://github.com/libexif/libexif/archive/refs/tags/libexif-0_6_14-release.tar.gz"
fi
tar -xzf "$LIBEXIF_TGZ"

if [[ ! -f "$EXIF_CLI_TGZ" ]]; then
  wget -O "$EXIF_CLI_TGZ" "https://github.com/libexif/exif/archive/refs/tags/exif-0_6_15-release.tar.gz"
fi
tar -xzf "$EXIF_CLI_TGZ"

if [[ ! -f "$SAMPLES_ZIP" ]]; then
  wget -O "$SAMPLES_ZIP" "https://github.com/ianare/exif-samples/archive/refs/heads/master.zip" \
    || wget -O "$SAMPLES_ZIP" "https://github.com/ianare/exif-samples/archive/refs/heads/main.zip"
fi
unzip -q -o "$SAMPLES_ZIP"

echo "Sources under: $TP"
echo "  libexif:  $TP/libexif-libexif-0_6_14-release"
echo "  exif CLI: $TP/exif-exif-0_6_15-release"
echo "  samples:  $TP/exif-samples-master/ or $TP/exif-samples-main/"
