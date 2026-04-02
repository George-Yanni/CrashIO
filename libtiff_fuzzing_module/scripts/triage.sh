#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/install_asan/bin/tiffinfo" ]]; then
  TIFFINFO_BIN="$ROOT/install_asan/bin/tiffinfo"
else
  TIFFINFO_BIN="$ROOT/install/bin/tiffinfo"
fi
CRASH_PATH="${1:-}"

if [[ ! -x "$TIFFINFO_BIN" ]]; then
  echo "Missing tiffinfo binary: $TIFFINFO_BIN" >&2
  echo "Run ./scripts/build_target.sh first." >&2
  exit 1
fi

if [[ -z "$CRASH_PATH" ]]; then
  latest="$(ls -1t "$ROOT"/corpora/out/default/crashes/id:* 2>/dev/null | head -n 1 || true)"
  if [[ -z "$latest" ]]; then
    echo "No crash file found. Pass a crash path explicitly." >&2
    exit 1
  fi
  CRASH_PATH="$latest"
fi

if [[ ! -f "$CRASH_PATH" ]]; then
  echo "Crash file not found: $CRASH_PATH" >&2
  exit 1
fi

ASAN_OPTIONS="${ASAN_OPTIONS:-abort_on_error=1:symbolize=1}" \
  "$TIFFINFO_BIN" -D -j -c -r -s -w "$CRASH_PATH"
