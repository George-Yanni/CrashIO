#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/third_party"
cd "$ROOT/third_party"
if [[ ! -d libxml2-2.9.4 ]]; then
  if [[ ! -f libxml2-2.9.4.tar.gz ]]; then
    echo "Downloading LibXML2 2.9.4..."
    wget -q -O libxml2-2.9.4.tar.gz "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.9.4/libxml2-v2.9.4.tar.gz"
  fi
  tar -xzf libxml2-2.9.4.tar.gz
  mv libxml2-v2.9.4 libxml2-2.9.4
fi
echo "Sources ready at: $ROOT/third_party/libxml2-2.9.4"
