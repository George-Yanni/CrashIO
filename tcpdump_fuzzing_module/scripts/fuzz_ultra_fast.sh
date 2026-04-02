#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/prepare_tiny_corpus.sh"

AFL_NO_UI="${AFL_NO_UI:-1}" \
AFL_SKIP_CPUFREQ="${AFL_SKIP_CPUFREQ:-1}" \
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES="${AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES:-1}" \
AFL_TMPDIR="/dev/shm" \
IN_DIR="$ROOT/corpora/in_tiny" \
OUT_DIR="$ROOT/corpora/out_ultra_fast" \
AFL_ARGS="${AFL_ARGS:--d -p fast}" \
TARGET_ARGS="${TARGET_ARGS:--n -r @@}" \
"$ROOT/scripts/fuzz.sh"
