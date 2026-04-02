#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TCPDUMP_BIN="${TCPDUMP_BIN:-$ROOT/install/sbin/tcpdump}"
IN_DIR="${IN_DIR:-$ROOT/corpora/in}"
OUT_DIR="${OUT_DIR:-$ROOT/corpora/out}"
AFL_SEED="${AFL_SEED:-123}"

if [[ ! -x "$TCPDUMP_BIN" ]]; then
  echo "Missing tcpdump binary: $TCPDUMP_BIN" >&2
  echo "Run ./scripts/build_target.sh first." >&2
  exit 1
fi

if [[ -d "/dev/shm" ]]; then
  export AFL_TMPDIR="/dev/shm"
  echo "Using RAM disk (/dev/shm) for temporary AFL inputs."
fi

if [[ ! -d "$IN_DIR" ]]; then
  echo "Missing corpus input dir: $IN_DIR" >&2
  echo "Run ./scripts/prepare_corpus.sh first." >&2
  exit 1
fi

if ! compgen -G "$IN_DIR/*" >/dev/null; then
  echo "Input corpus is empty: $IN_DIR" >&2
  echo "Add at least one .pcap or .pcapng file." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

AFL_ARGS="${AFL_ARGS:-}"
TARGET_ARGS="${TARGET_ARGS:--n -r @@}"

afl-fuzz -m none \
  -i "$IN_DIR" \
  -o "$OUT_DIR" \
  -s "$AFL_SEED" \
  $AFL_ARGS \
  -- "$TCPDUMP_BIN" $TARGET_ARGS
