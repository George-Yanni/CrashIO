#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-crashio/tcpdump-fuzz:latest}"

docker build -t "$TAG" "$ROOT"
echo "Built image: $TAG"
