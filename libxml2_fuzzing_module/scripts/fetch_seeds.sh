#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/corpora/seed"
DICT="$ROOT/dictionaries"

mkdir -p "$SEED" "$DICT"

echo "Fetching XML dictionary..."
wget -q -N -O "$DICT/xml.dict" "https://raw.githubusercontent.com/AFLplusplus/AFLplusplus/stable/dictionaries/xml.dict" || true

echo "Creating highly-optimized seed for CVE-2017-9048..."
# The original seed was too generic (<!DOCTYPE a []>).
# Since CVE-2017-9048 is a buffer overflow in DTD element content parsing (xmlSnprintfElementContent),
# providing a seed that already contains a basic <!ELEMENT ...> declaration dramatically speeds up the
# fuzzer's ability to discover the nested elements necessary to trigger the overflow.
cat << 'EOF' > "$SEED/SampleInput.xml"
<?xml version="1.0"?>
<!DOCTYPE a [
  <!ELEMENT a (b, c)>
  <!ELEMENT b (#PCDATA)>
  <!ELEMENT c (#PCDATA)>
]>
<a><b>1</b><c>2</c></a>
EOF

echo "Seed files:"
ls -la "$SEED"
echo "Dictionaries:"
ls -la "$DICT"
