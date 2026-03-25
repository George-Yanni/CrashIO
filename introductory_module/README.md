# Introductory Module — AFL++ Hands-on Starter

This module is the **hands-on “first lab”** for CrashIO Repo. It provides a small, intentionally fragile C++ parsing target and a clean workflow for:

- building an AFL++-instrumented target
- running AFL++ in **normal** and **persistent** modes
- using a **dictionary** to accelerate structure discovery
- collecting and triaging crashes
- minimizing corpus
- generating **coverage reports** (lcov/gcov) and interpreting results

The emphasis is **reproducibility** and a **modular layout** you can reuse in later modules.

## Module layout

```
introductory_module/
├── target/                # target library + build system (CMake)
├── harness/               # AFL++ harness (stdin, optional persistent mode)
├── scripts/               # automation entrypoints (build/fuzz/coverage)
├── corpora/
│   ├── seed/              # generated seed corpus (scripts/gen_seeds.py)
│   └── dictionaries/      # AFL++ dictionary tokens for structure discovery
├── coverage/              # (generated) coverage artifacts
└── README.md
```

## What you will learn (objectives)

- **How AFL++ “thinks”**: coverage feedback, favored inputs, queue growth, crash bucketing.
- **How to constrain a fuzzing problem**: seed corpus + dictionary + light structure checks.
- **How to choose build modes**:
  - **instrumented** build for fuzzing
  - **ASan** build for crash root-cause triage
  - **coverage** build for reporting and progress tracking
- **How to interpret coverage**: what increasing line/function coverage does (and doesn’t) imply.

## Target program overview (why it’s a good AFL++ target)

The target parses a compact “binary-ish” message format:

- **Header**: `"CRIO"` + version (1) + flags + section count (u16 LE)
- **Sections**: `tag (1 byte)` + `len (u16 LE)` + `payload (len bytes)`

Tags currently implemented:

- **`'N'` (name)**: printable ASCII string with branching checks; special prefixes enable deeper paths.
- **`'S'` (sum)**: 4-byte value; gated “logic crash” branches.
- **`'B'` (blob)**: contains a deliberate **out-of-bounds write** triggered by a specific mode byte.

Intentional bug classes you should expect AFL++ to find:

- **Stack buffer overflow** gated behind `name` starting with `BOOM...`
- **OOB write** in the `'B'` section when `mode == 0xF0` and `count` is large
- **Abort/assert-style “logic crashes”** behind specific flag/value combinations

Relevant source files:
- `target/parser_lib.cpp`: the parser and bug sites
- `harness/afl_harness.cpp`: stdin harness; optional AFL++ persistent loop
- `corpora/dictionaries/crio.dict`: dictionary tokens (`CRIO`, `N`, `S`, `B`, `BOOM`, `CRASHME`)

## What is the harness in this module?

In AFL++ terms, a **harness** is the small program that:

- reads the fuzzer-controlled bytes (here: from **stdin**)
- passes them into the code you want to test (here: the parser library)

In this module:

- **AFL++ executes** the harness binary: `build/afl/afl_harness` (or `build/afl_persist/afl_harness`)
- **The harness calls into** the real target code: `crashio::intro::parse_message(...)` implemented in `target/parser_lib.cpp`

So you fuzz the **harness executable**, but you are really fuzzing the **parser logic** it drives.

### Persistent mode (what changes)

With `-DUSE_AFL_PERSISTENT=ON`, the harness uses AFL++’s persistent loop (`__AFL_LOOP(...)`) to process many inputs in one process for higher throughput. The **target code stays the same**; only how the harness feeds inputs changes.

## Lab setup (Ubuntu)

This module is designed to be reproducible on **Ubuntu 22.04/24.04**.

### System dependencies

Install build tools and coverage tooling:

```bash
sudo apt update
sudo apt install -y \
  build-essential clang cmake ninja-build git python3 \
  lcov gdb
```

### Install AFL++

Option A (recommended for research workflows): build AFL++ from source.

```bash
git clone https://github.com/AFLplusplus/AFLplusplus.git
cd AFLplusplus
make distrib
sudo make install
```

Quick sanity check:

```bash
afl-fuzz -V
afl-clang-fast++ --version
```

### Environment (recommended)

For a beginner-friendly lab (less friction with “noisy” aborts/timeouts), export:

```bash
export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
```

If your target is *too fast* and AFL++ complains about stability/variable behavior, you can also set:

```bash
export AFL_MAP_SIZE=262144
```

## Quickstart (end-to-end)

From the CrashIO repo root:

```bash
cd introductory_module
python3 scripts/gen_seeds.py
```

Then build an instrumented binary with AFL++ (normal mode):

```bash
mkdir -p build/afl && cd build/afl
CC=afl-clang-fast CXX=afl-clang-fast++ cmake -G Ninja ../../target -DCMAKE_BUILD_TYPE=Release
ninja -v
```

Run AFL++ with the seed corpus and dictionary:

```bash
cd ../../
mkdir -p corpora/in corpora/out
cp corpora/seed/*.bin corpora/in/

afl-fuzz -i corpora/in -o corpora/out -x corpora/dictionaries/crio.dict -- \
  build/afl/afl_harness
```

Stop fuzzing after a few minutes and inspect results:

```bash
tree -L 3 corpora/out
ls -1 corpora/out/default/crashes | head
```

## AFL++ modes used in this module

### Normal mode (baseline)

Normal mode runs one input per process invocation (simpler mental model, lower throughput).

- **When to use**: first experiments; when your target is not persistent-friendly.
- **How to run**: use the build and `afl-fuzz` command shown in Quickstart.

### Persistent mode (higher throughput)

Persistent mode keeps the process alive and loops over many testcases via `__AFL_LOOP()`.

- **When to use**: fast, pure-ish parsing targets where startup cost dominates.
- **What changes**: you compile the harness with `-DUSE_AFL_PERSISTENT` and enable the CMake option.

Build persistent harness:

```bash
mkdir -p build/afl_persist && cd build/afl_persist
CC=afl-clang-fast CXX=afl-clang-fast++ cmake -G Ninja ../../target \
  -DCMAKE_BUILD_TYPE=Release -DUSE_AFL_PERSISTENT=ON
ninja -v
```

Run AFL++ the same way, swapping the target binary:

```bash
cd ../../
afl-fuzz -i corpora/in -o corpora/out_persist -x corpora/dictionaries/crio.dict -- \
  build/afl_persist/afl_harness
```

### Dictionary-assisted fuzzing

This module ships `corpora/dictionaries/crio.dict`. Use it with `-x`:

```bash
afl-fuzz -i corpora/in -o corpora/out -x corpora/dictionaries/crio.dict -- build/afl/afl_harness
```

Why it matters here:
- The parser expects `"CRIO"` and section tags (`N`, `S`, `B`) early.
- Tokens like `BOOM` and `CRASHME` unlock deeper, bug-triggering paths.

## Crash triage (ASan reproduction)

Fuzzing typically uses an optimized instrumented build. For root-cause, reproduce crashes under sanitizers.

### Build an ASan binary (recommended)

```bash
mkdir -p build/asan && cd build/asan
CC=clang CXX=clang++ cmake -G Ninja ../../target -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -O1"
ninja -v
```

### Reproduce a crash file

Pick a crash input from AFL++ output:

```bash
CRASH=corpora/out/default/crashes/id:000000*
./build/asan/afl_harness < "$CRASH"
```

Expected outcome:
- ASan prints a stack trace pointing into `target/parser_lib.cpp` (e.g., unsafe `strcpy` or OOB write).

## Corpus minimization (practical workflow)

After you have a larger corpus, minimize to a small “high-signal” set.

### Option A: `afl-cmin` (coverage-based minimization)

```bash
mkdir -p corpora/min
afl-cmin -i corpora/in -o corpora/min -- build/afl/afl_harness
```

### Option B: `afl-tmin` (testcase minimization)

Given a single interesting testcase, minimize it while preserving behavior (e.g., crash):

```bash
INP=corpora/out/default/crashes/id:000000*
cp "$INP" /tmp/crash.bin
afl-tmin -i /tmp/crash.bin -o /tmp/crash.min.bin -- build/afl/afl_harness
```

## Coverage analysis (lcov/gcov)

Coverage complements fuzzing metrics:

- **AFL++ “map coverage”** (edges) is used to guide mutations during fuzzing.
- **Source coverage (gcov/lcov)** is useful for reporting, comparing configurations, and spotting dead code.

### Build a coverage binary

```bash
mkdir -p build/cov && cd build/cov
CC=clang CXX=clang++ cmake -G Ninja ../../target -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="--coverage -O0 -g"
ninja -v
```

### Generate coverage by replaying a corpus

You can replay your minimized corpus to create a report:

```bash
cd ../../
mkdir -p coverage/html coverage/raw

# Clean old counters
find build/cov -name "*.gcda" -delete

# Replay corpus (use seeds, minimized corpus, or afl queue)
for f in corpora/in/*.bin; do
  build/cov/afl_harness < "$f" >/dev/null 2>&1 || true
done

# If you built coverage with clang/llvm, make lcov use llvm-cov's gcov mode.
# Otherwise you may see "Incompatible GCC/GCOV version" errors.
cat > /tmp/gcov-llvm.sh <<'EOF'
#!/usr/bin/env bash
exec llvm-cov gcov "$@"
EOF
chmod +x /tmp/gcov-llvm.sh

# Capture + render HTML
lcov --gcov-tool /tmp/gcov-llvm.sh --capture --directory build/cov \
  --ignore-errors inconsistent --output-file coverage/raw/coverage.info
lcov --remove coverage/raw/coverage.info "/usr/*" --output-file coverage/raw/coverage.filtered.info
genhtml coverage/raw/coverage.filtered.info --output-directory coverage/html
```

Open the report:

```bash
xdg-open coverage/html/index.html
```

### Interpreting the coverage report (how to read it)

- **High line coverage** can still miss important edge conditions (e.g., numeric boundaries).
- **Function coverage** helps detect “never reached” parsing modes and dead error-handling.
- Look specifically at:
  - the `'N'` section paths (printable checks, `BOOM` prefix gate)
  - the `'B'` section gate (`mode == 0xF0`) and how often it’s exercised
  - final “whole-input” checks that depend on aggregated state (`running_sum`)

Practical interpretation pattern:
- If coverage plateaus early, add **dictionary tokens** or improve **seed structure**.
- If coverage grows but no crashes appear, consider switching to **ASan-instrumented fuzzing** for this module.

## Expected AFL++ output (example)

Your exact numbers will vary, but you should see:

- a growing queue (`paths_total`)
- periodic “new finds” (coverage discoveries)
- crash files appearing under `.../crashes/` once bug paths are hit

Example snippets you might observe:

```text
paths_total : 120
unique_crashes : 1
execs_per_sec : 8000
```

And crash files like:

```text
corpora/out/default/crashes/id:000000,sig:11,src:...
```

## Notes for reuse in future modules

- Keep the **target** as a library (`parser_lib`) and the **harness** as a separate executable:
  - later modules can swap in new parsers and reuse the same harness patterns (stdin/persistent).
- Keep corpora and dictionaries under `corpora/`:
  - modules can share conventions for `seed/`, `in/`, `out/`, `min/`, and `dictionaries/`.
- Prefer CMake with exported `compile_commands.json`:
  - it improves integration with tooling (coverage, clang tooling, IDEs).

## Safety / ethics

This module contains **intentional memory-safety bugs** for controlled experimentation. Use it only in an isolated lab environment and do not apply unsafe patterns to production software.

