#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/install_asan/sbin/tcpdump" ]]; then
  TCPDUMP_BIN="$ROOT/install_asan/sbin/tcpdump"
else
  TCPDUMP_BIN="$ROOT/install/sbin/tcpdump"
fi
CRASH_PATH="${1:-}"

if [[ ! -x "$TCPDUMP_BIN" ]]; then
  echo "Missing tcpdump binary: $TCPDUMP_BIN" >&2
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
  "$TCPDUMP_BIN" -vvvvXX -ee -nn -r "$CRASH_PATH"
