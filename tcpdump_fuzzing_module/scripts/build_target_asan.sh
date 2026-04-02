#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_PROFILE=asan "$ROOT/scripts/build_target.sh"
