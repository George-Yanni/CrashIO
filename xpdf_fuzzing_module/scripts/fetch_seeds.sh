#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/corpora/seed"
mkdir -p "$SEED"
cd "$SEED"
# Small public-domain or permissively hosted examples suitable for fuzzing seeds.
wget -q -N -O helloworld.pdf "https://github.com/mozilla/pdf.js-sample-files/raw/master/helloworld.pdf" || true
wget -q -N -O sample.pdf "http://www.africau.edu/images/default/sample.pdf" || true
wget -q -N -O small-example.pdf "https://www.melbpc.org.au/wp-content/uploads/2017/10/small-example-pdf-file.pdf" || true
ls -la "$SEED"
