#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/third_party"
mkdir -p "$TP"
cd "$TP"

TCPDUMP_TGZ="tcpdump-4.9.2.tar.gz"
LIBPCAP_TGZ="libpcap-1.8.0.tar.gz"

if [[ ! -f "$TCPDUMP_TGZ" ]]; then
  wget -O "$TCPDUMP_TGZ" "https://github.com/the-tcpdump-group/tcpdump/archive/refs/tags/tcpdump-4.9.2.tar.gz"
fi
if [[ ! -f "$LIBPCAP_TGZ" ]]; then
  wget -O "$LIBPCAP_TGZ" "https://github.com/the-tcpdump-group/libpcap/archive/refs/tags/libpcap-1.8.0.tar.gz"
fi

tar -xzf "$TCPDUMP_TGZ"
tar -xzf "$LIBPCAP_TGZ"

# Normalize directory names across archive variants.
if [[ -d "$TP/libpcap-libpcap-1.8.0" && ! -d "$TP/libpcap-1.8.0" ]]; then
  mv "$TP/libpcap-libpcap-1.8.0" "$TP/libpcap-1.8.0"
fi

echo "Sources under: $TP"
echo "  tcpdump: $TP/tcpdump-tcpdump-4.9.2"
echo "  libpcap: $TP/libpcap-1.8.0"
