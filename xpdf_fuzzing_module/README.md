# Xpdf fuzzing lab — real binary, file-mode AFL++

This module is the **next step** after the synthetic parser in `introductory_module/`. Here you fuzz a **real third-party program** (Xpdf 3.02): you build it with AFL++ instrumentation, run `afl-fuzz` in **file mode** (`@@`), then **reproduce** and **triage** a crash with GDB.

## How this differs from the introductory module

| | Introductory module | This module |
|---|---------------------|-------------|
| Target | Small in-repo parser (`parser_lib`) | External Xpdf toolkit |
| Input | Stdin via `afl_harness` | Files on disk; AFL++ substitutes `@@` |
| Harness | You write a thin wrapper | The **program under test** (`pdftotext`, etc.) *is* the entry point |
| Build | CMake + Ninja in-repo | Autotools `./configure && make` in `third_party/` |

## What you will learn

- Building a **legacy C/C++ codebase** with **`afl-clang-fast`** (or `afl-gcc`).
- Running AFL++ when the target expects a **file path**, not stdin.
- **Reproducing** fuzzer-found crashes outside `afl-fuzz`.
- **Triage** with GDB: backtrace, spotting patterns like **deep recursion** and stack exhaustion.

## Module layout

```
xpdf_fuzzing_module/
├── scripts/
│   ├── fetch_target.sh   # download + unpack Xpdf 3.02 into third_party/
│   └── fetch_seeds.sh    # download a few seed PDFs into corpora/seed/
├── corpora/
│   ├── seed/             # input seeds for AFL++ (-i)
│   ├── in/               # optional: copy seeds here before a run
│   └── out/              # AFL++ output (created when you fuzz)
├── third_party/          # created by scripts; ignored by git
│   └── xpdf-3.02/
└── README.md
```

Install paths below use **`install/`** under this module so everything stays self-contained.

## Prerequisites

- Same base tooling as the intro lab: build essentials, AFL++ installed (`afl-fuzz`, `afl-clang-fast`).
- Ubuntu 22.04/24.04 is fine; use **matching** compiler toolchain for AFL++ (see AFL++ docs if `llvm-config` errors appear).

Recommended environment (same idea as the intro README):

```bash
export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
```

## Step 1 — Fetch sources and seed PDFs

From the **CrashIO repo root**:

```bash
cd xpdf_fuzzing_module
./scripts/fetch_target.sh
./scripts/fetch_seeds.sh
```

## Step 2 — Build Xpdf (normal, sanity check)

```bash
cd third_party/xpdf-3.02
./configure --prefix="$(pwd)/../../install"
make -j"$(nproc)"
make install
cd ../..
```

Smoke test (adjust path if you moved directories):

```bash
./install/bin/pdfinfo -box -meta corpora/seed/helloworld.pdf
```

## Step 3 — Rebuild with AFL++ instrumentation

Clean and reconfigure so **all** object files are built with the AFL compiler wrappers:

```bash
rm -rf install
cd third_party/xpdf-3.02
make distclean 2>/dev/null || make clean
CC=afl-clang-fast CXX=afl-clang-fast++ ./configure --prefix="$(pwd)/../../install"
make -j"$(nproc)"
make install
cd ../..
```

If `afl-clang-fast` is not on your PATH, use the full path to your AFL++ build.

## Step 4 — Prepare AFL++ input/output dirs

```bash
mkdir -p corpora/in corpora/out
cp corpora/seed/*.pdf corpora/in/ 2>/dev/null || true
```

Ensure `corpora/in` is non-empty (at least one `.pdf`).

## Step 5 — Fuzz with file mode (`@@`)

`@@` is the placeholder AFL++ replaces with the path to each generated input file.

Example: fuzz **`pdftotext`** (writes decoded text to a fixed output file):

```bash
mkdir -p /tmp/xpdf_afl_out
afl-fuzz -i corpora/in -o corpora/out -s 123 -- \
  ./install/bin/pdftotext @@ /tmp/xpdf_afl_out/out.txt
```

- **`-i`**: seed inputs  
- **`-o`**: fuzzer output (queue, crashes, hangs)  
- **`-s 123`**: fixed RNG seed so runs are easier to compare across machines/sessions  

When the first interesting crash appears, stop the fuzzer if you only need one case for the lab. Runtime varies widely by CPU and luck.

### If AFL++ warns about `core_pattern`

On some systems:

```bash
echo core | sudo tee /proc/sys/kernel/core_pattern
```

(Only do this if you understand the system-wide effect; common on dedicated lab VMs.)

## Step 6 — Reproduce the crash

Crashes live under `corpora/out/default/crashes/` with names like `id:000000,sig:11,...`.

```bash
CRASH="corpora/out/default/crashes/id:000000"*
./install/bin/pdftotext "$CRASH" /tmp/xpdf_afl_out/repro.txt
```

You should see the same failure mode (e.g. segfault) as under the fuzzer.

## Step 7 — Triage with GDB (debug build)

For readable stack traces, rebuild **without** AFL instrumentation but **with** debug symbols:

```bash
rm -rf install
cd third_party/xpdf-3.02
make distclean 2>/dev/null || make clean
CFLAGS="-g -O0" CXXFLAGS="-g -O0" ./configure --prefix="$(pwd)/../../install"
make -j"$(nproc)"
make install
cd ../..
```

Run under GDB:

```bash
CRASH="corpora/out/default/crashes/id:000000"*
gdb --args ./install/bin/pdftotext "$CRASH" /tmp/xpdf_afl_out/gdb_out.txt
```

Inside GDB:

```text
run
bt
```

A **very deep** stack with repeated calls (e.g. into PDF object parsing) often indicates **uncontrolled recursion**: each nested call uses stack space until the process dies — a classic **denial-of-service** class ([CWE-674](https://cwe.mitre.org/data/definitions/674.html)).

## Step 8 — Optional: fix or upgrade

As an exercise: locate the recursion/guard in the source, add a depth limit or correct the parse logic, rebuild, and confirm the crash input no longer kills the process. Alternatively, compare behavior against a **maintained** Xpdf / Poppler release where the issue class may already be addressed.

## Relationship to the introductory module

- **Intro**: teaches harness design, stdin, persistent mode, ASan, coverage — on **your** code.  
- **This lab**: same fuzzing **ideas**, applied to a **prebuilt real tool** and **file** inputs. Together they map how most “fuzz this binary” work is actually done.

## Safety / ethics

Xpdf 3.02 is old and **intentionally used here as a teaching target**. Do not expose fuzzed services to untrusted networks; use an isolated VM and treat crashes as local-only experiments.
