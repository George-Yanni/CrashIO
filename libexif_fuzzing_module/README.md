# libexif fuzzing lab — library + CLI driver, LTO instrumentation

This module fuzzes **libexif** (EXIF parsing library) **indirectly**: AFL++ runs the small **`exif`** command-line tool, which links against libexif. That pattern — **library under test + external harness program** — is how most real-world library fuzzing starts.

It follows the same CrashIO conventions as **`xpdf_fuzzing_module/`**: sources under `third_party/`, install prefix under `install/`, seeds under `corpora/in/`, AFL++ **file mode** (`@@`).

## How this differs from the other modules

| | Introductory module | Xpdf module | This module |
|---|---------------------|-------------|-------------|
| Code under test | In-repo parser | Whole application | **Library** (libexif) |
| AFL++ entry point | Your `afl_harness` | `pdftotext` / `pdfinfo` | **`exif`** CLI (driver) |
| Linking | N/A | Default shared/static per build | **`--enable-static` / no shared** so instrumentation stays in one binary |
| Instrumentation | `afl-clang-fast++` | `afl-clang-fast` | Prefer **`afl-clang-lto`** (collision-free); fall back to `afl-clang-fast` |

## What you will learn

- Fuzzing a **library** by choosing a **driver** that exercises its API (`exif` reads EXIF from image files and prints tags).
- Building **autotools** projects with **`afl-clang-lto`** when your toolchain supports it ([AFL++ LTO mode](https://github.com/AFLplusplus/AFLplusplus/blob/stable/instrumentation/README.lto.md)).
- Keeping a **fixed fuzzer seed** (`afl-fuzz -s …`) so runs are easier to compare.
- **Triage** with GDB: backtraces into **heap corruption** vs **out-of-bounds reads** (typical classes in older EXIF parsers).

Historical note: libexif **0.6.14** was affected by several public issues; two representative classes are **heap-based buffer overflow** ([CWE-122](https://cwe.mitre.org/data/definitions/122.html)) and **out-of-bounds read** ([CWE-125](https://cwe.mitre.org/data/definitions/125.html)). Your goal in the lab is to **practice the workflow**, not to rediscover a specific CVE.

## Module layout

```
libexif_fuzzing_module/
├── scripts/
│   ├── fetch_sources.sh   # libexif + exif CLI + JPEG sample corpus
│   └── prepare_corpus.sh  # copy samples into corpora/in/
├── corpora/
│   ├── in/                # AFL++ input dir (-i)
│   └── out/               # AFL++ output (queue, crashes)
├── third_party/           # created by scripts; gitignored
│   ├── libexif-libexif-0_6_14-release/
│   ├── exif-exif-0_6_15-release/
│   └── exif-samples-master/
├── install/               # install prefix (gitignored)
└── README.md
```

## Prerequisites

- Ubuntu 22.04/24.04 (or similar) with build tools and AFL++ installed (`afl-fuzz`, and preferably `afl-clang-lto` / `afl-clang-fast`).
- Extra packages for autotools and the `exif` CLI:

```bash
sudo apt update
sudo apt install -y \
  build-essential autoconf automake libtool pkg-config gettext autopoint \
  libpopt-dev wget unzip
```

Recommended (same as other CrashIO labs):

```bash
export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
```

Point **`LLVM_CONFIG`** at the LLVM that matches your AFL++ build (examples: `llvm-config`, `llvm-config-18`). If `afl-clang-lto` fails to link or configure, use `afl-clang-fast` for both packages instead.

## Step 1 — Download sources and samples

From the **module root**:

```bash
cd libexif_fuzzing_module
./scripts/fetch_sources.sh
./scripts/prepare_corpus.sh
```

## Step 2 — Build libexif and `exif` (sanity check, no AFL)

Use an **absolute** install prefix under this module:

```bash
ROOT="$(pwd)"
export PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"

cd third_party/libexif-libexif-0_6_14-release
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install"
make -j"$(nproc)"
make install
cd "$ROOT"

cd third_party/exif-exif-0_6_15-release
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install" PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"
make -j"$(nproc)"
make install
cd "$ROOT"
```

Smoke test:

```bash
./install/bin/exif corpora/in/*.jpg | head
```

## Step 3 — Rebuild with AFL++ (LTO preferred)

Clean the install and rebuild **both** libexif and `exif` with the same compiler wrapper so the binary and static library are fully instrumented.

Pick a compiler:

```bash
# Prefer LTO (collision-free instrumentation); fall back if unavailable.
if command -v afl-clang-lto >/dev/null 2>&1; then
  export CC=afl-clang-lto
else
  export CC=afl-clang-fast
fi
# Example — adjust to your system (see `llvm-config --version`):
export LLVM_CONFIG="${LLVM_CONFIG:-llvm-config}"
```

Then:

```bash
ROOT="$(pwd)"
rm -rf install
export PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"

cd third_party/libexif-libexif-0_6_14-release
make distclean 2>/dev/null || make clean
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install"
make -j"$(nproc)"
make install
cd "$ROOT"

cd third_party/exif-exif-0_6_15-release
make distclean 2>/dev/null || make clean
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install" PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"
make -j"$(nproc)"
make install
cd "$ROOT"
```

## Step 4 — Fuzz (file mode)

```bash
mkdir -p corpora/out
afl-fuzz -i corpora/in -o corpora/out -s 123 -- ./install/bin/exif @@
```

- **`-s 123`**: fixed RNG seed for more comparable runs across machines/sessions.
- **`@@`**: AFL++ replaces this with the path to each mutated input file.

Stop when you have enough **unique crashes** in `corpora/out/default/crashes/` for triage practice.

## Step 5 — Reproduce outside the fuzzer

```bash
CRASH="corpora/out/default/crashes/id:000000"*
./install/bin/exif "$CRASH"
```

## Step 6 — Triage with GDB (debug symbols)

Rebuild **without** AFL wrappers but with **`-g -O0`** (same `--prefix` and order: libexif first, then `exif`):

```bash
ROOT="$(pwd)"
rm -rf install
export PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"
export CFLAGS="-g -O0"
export CXXFLAGS="-g -O0"

cd third_party/libexif-libexif-0_6_14-release
make distclean 2>/dev/null || make clean
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install"
make -j"$(nproc)"
make install
cd "$ROOT"

cd third_party/exif-exif-0_6_15-release
make distclean 2>/dev/null || make clean
autoreconf -fvi
./configure --enable-shared=no --prefix="$ROOT/install" PKG_CONFIG_PATH="$ROOT/install/lib/pkgconfig"
make -j"$(nproc)"
make install
cd "$ROOT"

unset CFLAGS CXXFLAGS
```

Debug:

```bash
CRASH="corpora/out/default/crashes/id:000000"*
gdb --args ./install/bin/exif "$CRASH"
```

Inside GDB: `run`, then `bt`. Use `frame N` / `list` to see whether the fault looks like **heap metadata corruption**, **write past allocation**, or **read past buffer** — map that to CWE-122 vs CWE-125 style reasoning.

Any C/C++ IDE with a GDB backend can attach the same way; the CrashIO default is the **GDB CLI**.

## Step 7 — Optional: fix or upgrade

As an exercise: patch libexif (bounds checks, parser limits), rebuild libexif + `exif`, and confirm your crash inputs no longer fault. Alternatively, compare against a **current** libexif release and see which classes of issues are gone.

## Safety / ethics

You are building **known-vulnerable-era** code for a **closed lab**. Do not deploy this stack to production or expose it to untrusted input on a network.
