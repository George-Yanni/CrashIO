# TCPdump fuzzing lab — file mode AFL++, ASan triage

This module fuzzes **TCPdump 4.9.2** with AFL++ in **file mode** (`@@`) and triages crashes with AddressSanitizer, using a fully native workflow.

## What you will learn

- Building **libpcap + tcpdump** with AFL++ compiler wrappers.
- Running AFL++ against a target that expects a **packet capture file path**.
- Using **ASan-enabled** builds to make crash triage faster and cleaner.
- Keeping runs reproducible with a fixed AFL seed (`-s 123`).

## Module layout

```text
tcpdump_fuzzing_module/
├── scripts/
│   ├── fetch_sources.sh   # download tcpdump/libpcap sources
│   ├── prepare_corpus.sh  # copy tcpdump tests/*.pcap* into corpora/in/
│   ├── build_target.sh    # build target (default: fast non-ASan)
│   ├── build_target_asan.sh # build separate ASan target for triage
│   ├── minimize_corpus.sh # coverage-based corpus minimization (afl-cmin)
│   ├── prepare_tiny_corpus.sh # create tiny startup corpus (smallest files)
│   ├── fuzz.sh            # run afl-fuzz in file mode (@@)
│   ├── fuzz_ultra_fast.sh # tiny corpus + aggressive AFL options
│   └── triage.sh          # replay crash with ASan output
├── corpora/
│   ├── seed/
│   ├── in/                # AFL++ input corpus (created/populated by script)
│   ├── in_min/            # minimized corpus for speed
│   └── out/               # AFL++ findings
├── third_party/           # downloaded sources (ignored by git)
└── install/               # local install prefix (ignored by git)
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

## Choose Your Fuzzing Path

`build_target.sh` automatically prefers `afl-clang-lto` and falls back to `afl-clang-fast`.

Select ONE of the following paths depending on your goal. Each block contains all the commands needed from start to finish.

### Path 0: Ultra-fast (Recommended for quickest results)

Use this when startup/calibration time is your biggest pain point. It creates a tiny corpus and uses aggressive AFL mutation modes.

```bash
cd tcpdump_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources and prepare initial corpus
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh

# 2. Build the fast non-ASan target
./scripts/build_target.sh

# 3. Minimize corpus to save startup time
./scripts/minimize_corpus.sh

# 4. Generate tiny corpus and run with aggressive AFL options
./scripts/fuzz_ultra_fast.sh
```
*(To tune this mode, you can use: `MAX_FILES=16 ./scripts/prepare_tiny_corpus.sh` before fuzzing).*

---

### Path 1: Saturating your CPU (Parallel Fleet Fuzzing)

A single `afl-fuzz` process is strictly single-threaded. To utilize 100% of a multi-core system (like a 24-core VM), you must run multiple AFL workers in parallel. They will automatically sync their findings.

```bash
cd tcpdump_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources, prepare corpus, build fast target
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh
./scripts/build_target.sh

# 2. Minimize to a tiny corpus for fast fleet startup
./scripts/minimize_corpus.sh
./scripts/prepare_tiny_corpus.sh

# 3. Clean any old parallel runs and temporary RAM folders
rm -rf corpora/out_parallel /dev/shm/afl_*

# 4. Start the Master node in the background
mkdir -p /dev/shm/afl_main
AFL_TMPDIR=/dev/shm/afl_main afl-fuzz -M main -m none -i corpora/in_tiny -o corpora/out_parallel -- ./install/sbin/tcpdump -n -r @@ >/dev/null 2>&1 &

# 5. Start 23 Secondary nodes in the background
for i in {1..23}; do
  mkdir -p /dev/shm/afl_sec$i
  AFL_TMPDIR=/dev/shm/afl_sec$i afl-fuzz -S "sec$i" -m none -i corpora/in_tiny -o corpora/out_parallel -- ./install/sbin/tcpdump -n -r @@ >/dev/null 2>&1 &
done

echo "Launched 24 AFL workers in the background!"
```

**How to monitor the fleet:**
Since the workers run in the background, use `afl-whatsup` to check their combined progress (total execs/sec, crashes, and uptime):
```bash
afl-whatsup corpora/out_parallel
or
watch -n 2 afl-whatsup corpora/out_parallel
```

**How to stop the fleet:**
```bash
killall afl-fuzz
```
> ***Note: After running this for approximately one day, no issues were detected.***

---

### Path 2: Fast (Recommended for standard discovery)

Use this path when your goal is a good balance of high exec/sec and thorough coverage discovery using a fully minimized corpus.

```bash
cd tcpdump_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources and prepare initial corpus
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh

# 2. Build the fast non-ASan target
./scripts/build_target.sh

# 3. Reduce startup/calibration cost
./scripts/minimize_corpus.sh

# 4. Faster fuzz run (lighter target args + minimized corpus)
IN_DIR=corpora/in_min \
OUT_DIR=corpora/out_fast \
TARGET_ARGS="-n -r @@" \
./scripts/fuzz.sh
```

---

### Path 3: Slow/Deep (Recommended for triage quality & deepest bug detection)

> ***Note: This path led to the successful discovery of the crashes; the screenshots in the Screenshots folder correspond to this path.***

Use this path when your goal is sanitizer-backed diagnostics to catch subtle memory bugs. Fuzzing will be much slower, but AddressSanitizer (ASan) will catch things that normal fuzzing misses. 


```bash
cd tcpdump_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources and prepare initial corpus
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh

# 2. Build ASan target (slower fuzzing, but finds hidden memory bugs)
./scripts/build_target_asan.sh

# 3. Minimize to a tiny corpus for fast fleet startup
./scripts/minimize_corpus.sh
./scripts/prepare_tiny_corpus.sh

# 4. Clean any old parallel runs and temporary RAM folders
rm -rf corpora/out_parallel_asan /dev/shm/afl_*

# 5. Start the Master node in the background (using ASan binary and ASan specific out dir)
mkdir -p /dev/shm/afl_main
AFL_TMPDIR=/dev/shm/afl_main afl-fuzz -M main -m none -i corpora/in_tiny -o corpora/out_parallel_asan -- ./install_asan/sbin/tcpdump -vvvvXX -ee -nn -r @@ >/dev/null 2>&1 &

# 6. Start 19 Secondary nodes in the background (to saturate 20 total cores)
for i in {1..19}; do
  mkdir -p /dev/shm/afl_sec$i
  AFL_TMPDIR=/dev/shm/afl_sec$i afl-fuzz -S "sec$i" -m none -i corpora/in_tiny -o corpora/out_parallel_asan -- ./install_asan/sbin/tcpdump -vvvvXX -ee -nn -r @@ >/dev/null 2>&1 &
done

echo "Launched 20 ASan AFL workers in the background!"
```

**How to monitor the ASan fleet:**
```bash
watch -n 2 afl-whatsup corpora/out_parallel_asan
```

**Triage crashes:**
Once a crash is found, stop fuzzing (`killall afl-fuzz`) and run:
```bash
./scripts/triage.sh
```

## Fixed issues

- **Legacy tcpdump configure probes failing on modern compilers**
  - Issue: older configure tests use pre-C99 probe code that fails under newer defaults.
  - Fix: run tcpdump configure with `CFLAGS=-std=gnu89` to keep those probes compatible.

- **Inconsistent compiler usage between configure and build**
  - Issue: configure/build mismatch caused unreliable library capability checks.
  - Fix: run configure with the AFL wrapper (`CC="$AFL_CC"`) so checks and build use the same toolchain behavior.

- **Target built without AFL instrumentation**
  - Issue: AFL reported "No instrumentation detected" when `make` did not consistently use AFL wrappers.
  - Fix: explicitly force `CC="$AFL_CC"` in `make` and `make install` for both `libpcap` and `tcpdump`.

- **ASan + 64-bit virtual memory constraints during fuzzing**
  - Issue: default AFL memory limits can interfere with ASan runs.
  - Fix: `fuzz.sh` runs with `-m none`, and fast fuzzing now uses a non-ASan build by default.

- **Fast profile was still slow due to ASan leaking into the build**
  - Issue: Setting `AFL_USE_ASAN=0` in the build script did not disable ASAN. The `afl-clang-fast` compiler wrapper checks if the environment variable is *set at all*, not its value. This caused the "fast" binary to still be fully ASAN-instrumented, keeping speeds at ~150 execs/sec.
  - Fix: Modified `build_target.sh` to explicitly `unset AFL_USE_ASAN` for the fast profile, which immediately boosted speed to ~2,700 execs/sec.

- **Fuzzing throughput still too low on ASan binaries**
  - Issue: sanitizers significantly reduce execution speed for this target.
  - Fix: split builds into fast fuzz binary (`build_target.sh`) and ASan triage binary (`build_target_asan.sh`).

- **Too many initial seeds slowing dry run and calibration**
  - Issue: large corpus increases startup time and lowers effective mutation throughput.
  - Fix: `minimize_corpus.sh` uses `afl-cmin` to generate `corpora/in_min` for faster steady-state fuzzing.

- **Calibration overhead still high after minimization**
  - Issue: even minimized corpora can be large for quick startup on modest hardware.
  - Fix: `prepare_tiny_corpus.sh` + `fuzz_ultra_fast.sh` use a tiny corpus and aggressive AFL settings for faster iteration loops.

- **Host warning about `core_pattern` crash handling**
  - Issue: AFL warns about delayed crash reporting on some Ubuntu setups.
  - Fix: keep `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1` for lab mode (documented in Notes).

- **Disk I/O bottleneck during high-speed parallel fuzzing**
  - Issue: AFL++ writes the mutated test file (`.cur_input`) to disk thousands of times per second. With 24 cores, this chokes the VM virtual disk and drops CPU usage drastically due to I/O Wait.
  - Fix: Added `AFL_TMPDIR=/dev/shm` to the parallel launcher and scripts. This directs AFL++ to generate its thousands of temporary files directly in the Linux RAM disk, completely bypassing the hard drive and letting the CPU run at 100%.

## What was implemented and validated in this module

- Scripted source fetch for `tcpdump-4.9.2` and `libpcap-1.8.0`.
- Corpus preparation from `third_party/tcpdump-tcpdump-4.9.2/tests/` into `corpora/in/`.
- Native split-build workflow:
  - fast non-ASan target for fuzzing (`install/`)
  - ASan target for triage (`install_asan/`)
- compatibility handling in `build_target.sh` for modern Ubuntu toolchains:
  - configure stage uses AFL compiler wrapper to keep `libpcap` checks consistent.
  - tcpdump configure uses `CFLAGS=-std=gnu89` to pass legacy configure probes.
  - make/install explicitly force `CC="$AFL_CC"` so instrumentation is preserved.
- `minimize_corpus.sh` for speed-focused corpus reduction (`afl-cmin`).
- `prepare_tiny_corpus.sh` and `fuzz_ultra_fast.sh` for very fast startup/iteration.
- `fuzz.sh` with tunable `IN_DIR`, `OUT_DIR`, `TARGET_ARGS`, and `AFL_ARGS`.
- `triage.sh` auto-selects ASan binary if available.
- Validated locally:
  - target builds and installs at `install/sbin/tcpdump`.
  - AFL dry run and short smoke fuzzing complete successfully with instrumentation detected.

## Crash triage

Replay a specific crash:

```bash
./scripts/triage.sh corpora/out/default/crashes/id:000000,sig:06,src:...
```

Or let the script pick the newest one:

```bash
./scripts/triage.sh
```

## Notes

- AFL++ runs with `-m none` because ASan on 64-bit targets needs large virtual memory.
- If `corpora/in/` is empty, rerun `./scripts/prepare_corpus.sh`.
- If AFL reports `core_pattern` warnings, keep `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1` for lab use or adjust `/proc/sys/kernel/core_pattern`.

## Safety / ethics

This module is for local security lab work in an isolated environment. Do not expose these builds to untrusted networks.
