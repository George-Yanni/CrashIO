# LibTIFF fuzzing lab — file mode AFL++, ASan triage

This module fuzzes **LibTIFF 4.0.4** with AFL++ in **file mode** (`@@`) and triages crashes with AddressSanitizer, using a fully native workflow. It targets `tiffinfo` based on CVE-2016-9297.

## What you will learn

- Building **libtiff** with AFL++ compiler wrappers.
- Running AFL++ against a target that expects an **image file path**.
- Using **ASan-enabled** builds to make crash triage faster and cleaner.
- Keeping runs reproducible with a fixed AFL seed (`-s 123`).

## Module layout

```text
libtiff_fuzzing_module/
├── scripts/
│   ├── fetch_sources.sh   # download libtiff sources
│   ├── prepare_corpus.sh  # copy libtiff tests/*.tiff into corpora/in/
│   ├── build_target.sh    # build target (default: fast non-ASan)
│   ├── build_target_asan.sh # build separate ASan target for triage
│   ├── minimize_corpus.sh # coverage-based corpus minimization (afl-cmin)
│   ├── prepare_tiny_corpus.sh # create tiny startup corpus (smallest files)
│   ├── fuzz.sh            # run afl-fuzz in file mode (@@)
│   ├── fuzz_ultra_fast.sh # tiny corpus + aggressive AFL options
│   └── triage.sh          # replay crash with ASan output
├── corpora/
│   ├── in/                # AFL++ input corpus (created/populated by script)
│   ├── in_min/            # minimized corpus for speed
│   ├── in_tiny/           # tiny corpus for very fast startup
│   └── out_parallel_asan/ # AFL++ findings for parallel ASan fleet
├── third_party/           # downloaded sources (ignored by git)
├── install/               # local install prefix (non-ASan)
├── install_asan/          # local ASan install prefix
├── Screenshots/           # screenshots from runs/triage
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



`build_target.sh` automatically prefers `afl-clang-lto` and falls back to `afl-clang-fast`.

Follow the following to reproduce the findings:

### Slow/Deep (Recommended for triage quality & deepest bug detection)

```bash
cd libtiff_fuzzing_module
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

# 1. Fetch sources and prepare initial corpus
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh

# 2. Build ASan target (slower fuzzing, but finds hidden memory bugs)
./scripts/build_target_asan.sh

# 3. Minimize to a tiny corpus
./scripts/minimize_corpus.sh
./scripts/prepare_tiny_corpus.sh

# 4. Start the Master node in the background
mkdir -p /dev/shm/afl_main
AFL_TMPDIR=/dev/shm/afl_main afl-fuzz -M main -m none -i corpora/in_tiny -o corpora/out_parallel_asan -- ./install_asan/bin/tiffinfo -D -j -c -r -s -w @@ >/dev/null 2>&1 &

# 5. Start Secondary nodes in the background (adjust loop as needed)
for i in {1..3}; do
  mkdir -p /dev/shm/afl_sec$i
  AFL_TMPDIR=/dev/shm/afl_sec$i afl-fuzz -S "sec$i" -m none -i corpora/in_tiny -o corpora/out_parallel_asan -- ./install_asan/bin/tiffinfo -D -j -c -r -s -w @@ >/dev/null 2>&1 &
done
```

**How to monitor the ASan fleet:**
```bash
afl-whatsup corpora/out_parallel_asan
```

**Triage crashes:**
Once a crash is found, stop fuzzing (`killall afl-fuzz`) and run:
```bash
./scripts/triage.sh
```

## Crash triage

Replay a specific crash:

```bash
./scripts/triage.sh corpora/out/default/crashes/id:000000,sig:06,src:...
```

Or let the script pick the newest one:

```bash
./scripts/triage.sh
```

## Safety / ethics

This module is for local security lab work in an isolated environment. Do not expose these builds to untrusted networks.
