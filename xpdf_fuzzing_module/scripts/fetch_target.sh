#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/third_party"
cd "$ROOT/third_party"
if [[ ! -f xpdf-3.02.tar.gz ]]; then
  wget -O xpdf-3.02.tar.gz "https://dl.xpdfreader.com/old/xpdf-3.02.tar.gz"
fi
tar -xzf xpdf-3.02.tar.gz
echo "Sources ready at: $ROOT/third_party/xpdf-3.02"
