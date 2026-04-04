# LibXML2 fuzzing lab — dictionary and ASan

This module teaches you how to fuzz **LibXML2 2.9.4** using AFL++. The target is to find a crash (CVE-2017-9048) in the DTD validation functionality.

## What you will learn

- Fuzzing a complex file format (XML) using **custom dictionaries**.
- Creating **highly-targeted seeds** to guide the fuzzer directly to vulnerable parser code paths.
- Splitting builds into **FAST (No ASan)** for high-speed fuzzing, and **ASan** for crash triage.
- Parallelizing fuzzing with a **20-core fuzzer fleet** (1 Master, 19 Slaves) running in the background.

## Module layout

```text
libxml2_fuzzing_module/
├── scripts/
│   ├── fetch_target.sh   # download + unpack LibXML2 2.9.4 into third_party/
│   ├── fetch_seeds.sh    # download dictionary and create targeted XML seed
│   ├── build_target.sh   # build extremely fast target for the fuzzer
│   └── build_target_asan.sh # build separate ASan target strictly for triage
├── corpora/
│   ├── seed/             # input seeds for AFL++ (-i)
│   ├── in/               # optional: copy seeds here before a run
│   └── out_parallel/     # AFL++ output for parallel instances
├── dictionaries/         # contains the xml.dict dictionary for AFL++ (-x)
├── install/              # local install prefix for FAST binaries
├── install_asan/         # local install prefix for ASan binaries
├── third_party/          # created by scripts; ignored by git
└── README.md
```

## Prerequisites

- Native AFL++ setup available on host:
  - `afl-fuzz`
  - `afl-clang-fast` (or `afl-clang-lto`)
- Enough disk for source + build artifacts.

Recommended AFL env (same style as other modules):

```bash
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1
```

## Running the Fuzzer

## The ASan Trade-off

If you've been experiencing "hangs" or the fuzzer taking several days to find a crash, it is usually because:
1. **Building the fuzzing target with ASan makes it drastically slower and memory-heavy** (causing false timeouts/hangs).
2. The initial seed (`<!DOCTYPE a []>`) forces the fuzzer to randomly guess the syntax of `<!ELEMENT ...>` entirely from scratch, which takes days.

**Why not just fuzz with ASan?**
While ASan is incredible at catching subtle bugs (like 1-byte heap out-of-bounds reads), it drops fuzzer execution speed significantly and consumes a massive amount of "shadow memory". This huge memory footprint often hits the fuzzer's memory limits (`-m`), causing the fuzzer to kill the process and incorrectly log it as a "Hang" instead of a "Crash". 

Since CVE-2017-9048 is a massive stack buffer overflow (smashing a 5000-byte buffer), it will cause a loud, undeniable Segfault even without ASan. We take the 300% speed boost by fuzzing with a **FAST (No ASan)** build to find the crashing file in minutes instead of days. Once the crash is found, we pass it to the **ASan-built version during triage** to get the beautiful, color-coded stack trace.

We solve the speed problem by separating the builds (fast vs ASan) and providing an intelligently targeted seed!

```bash
cd libxml2_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources, create targeted XML seed, and dictionary
chmod +x scripts/*.sh
./scripts/fetch_target.sh
./scripts/fetch_seeds.sh

# 2. Build FAST LibXML2 for high-speed fuzzing
./scripts/build_target.sh

# 3. Build ASan LibXML2 for post-crash triage
./scripts/build_target_asan.sh

# 4. Prepare AFL++ input/output dirs
mkdir -p corpora/in corpora/out_parallel
cp corpora/seed/*.xml corpora/in/ 2>/dev/null || true

# Test that the built FAST xmllint binary works
./install/bin/xmllint --memory corpora/seed/SampleInput.xml

# 5. Start the Master node in the background (using FAST install)
mkdir -p /dev/shm/afl_main
AFL_TMPDIR=/dev/shm/afl_main afl-fuzz -M main -m none -i corpora/in -o corpora/out_parallel -x dictionaries/xml.dict -D -- ./install/bin/xmllint --memory --noenc --nocdata --dtdattr --loaddtd --valid --xinclude @@ >/dev/null 2>&1 &

# 6. Start Secondary nodes in the background (running 20 instances in total: 1 master + 19 slaves)
for i in {1..19}; do
  mkdir -p /dev/shm/afl_sec$i
  AFL_TMPDIR=/dev/shm/afl_sec$i afl-fuzz -S "sec$i" -m none -i corpora/in -o corpora/out_parallel -x dictionaries/xml.dict -- ./install/bin/xmllint --memory --noenc --nocdata --dtdattr --loaddtd --valid --xinclude @@ >/dev/null 2>&1 &
done
```

**How to monitor the fleet:**
```bash
afl-whatsup corpora/out_parallel
```

## Crash triage

Once a crash is found in `corpora/out_parallel/main/crashes`, stop fuzzing (`killall afl-fuzz`) and run the crashing input directly using the **ASan** version of `xmllint`.

Because the triage binary was compiled with ASan, it will print a detailed stack trace and memory state.

```bash
CRASH=$(ls corpora/out_parallel/main/crashes/id:000000* | head -n 1)
./install_asan/bin/xmllint --memory --noenc --nocdata --dtdattr --loaddtd --valid --xinclude "$CRASH"
```

Look for the ASan report indicating a **stack-buffer-overflow**, which confirms you've successfully reproduced CVE-2017-9048!
