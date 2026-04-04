# CrashIO

Welcome to **CrashIO** — a comprehensive, hands-on vulnerability research and fuzzing laboratory. This repository is designed to provide reproducible, modular, and progressively advanced environments for learning how to fuzz real-world software using **AFL++**. 

This project reflects a deep dive into the practical aspects of fuzzing, from synthetic targets to complex, heavily parallelized real-world applications. It emphasizes **reproducibility**, **performance optimization** (like RAM-disk parallel fuzzing and split ASan/Fast builds), and **effective crash triage**.

> *Note: Some of the foundational concepts and target inspirations in this repository were learned from the excellent [Fuzzing101](https://github.com/antonio-morales/Fuzzing101) repository.*

## 🔗 Related Projects

If you are interested in fuzzing, you might also like my other dedicated fuzzing projects:

- **[FuzzMatryoshka](https://github.com/George-Yanni/FuzzMatryoshka)**: A Radamsa-based fuzzing framework designed to stress-test and harden a custom firmware update parser and protocol. Focuses on targeted fuzzing of binary parsing, header handling, and protocol/state-machine logic.
- **[Fuzzabella](https://github.com/George-Yanni/Fuzzabella)**: An FTP control-channel fuzzing setup for ProFTPD with Boofuzz. Provides one-command session orchestration, configurable command profiles, and unified crash/coverage reports.

---

## Philosophy & Effort

CrashIO is not just a collection of vulnerable binaries. It is a carefully engineered set of modules demonstrating real-world vulnerability research workflows. Great effort has been put into:

- **Automated Workflows**: Each module contains `scripts/` to fetch targets, build with correct compiler wrappers, and minimize corpora.
- **Performance Tuning**: Tackling the reality of fuzzing bottlenecks by using `/dev/shm` RAM disks for parallel fuzzer fleets, avoiding disk I/O chokes.
- **Split-Build Architecture**: Building separate **FAST** (un-sanitized) binaries for high-speed fuzzing and **ASan** (AddressSanitizer) binaries exclusively for crash triage, solving the speed vs. visibility trade-off.
- **Progressive Complexity**: Starting from a synthetic target with a custom harness, moving to CLI applications, libraries, and eventually complex parsers requiring custom dictionaries.

---

## Modules Overview

The repository is structured into distinct, self-contained modules. Each module focuses on different fuzzing techniques, target architectures, and vulnerability classes.

### 1. `introductory_module/` (The Synthetic Parser)
A synthetic C++ parsing target to teach the fundamentals of AFL++.
- **Key Skills**: Writing an AFL++ harness, stdin fuzzing, Normal vs. Persistent mode (`__AFL_LOOP`), dictionary-assisted fuzzing, and coverage analysis (lcov/gcov).
- **Features**: A clean CMake build system, seeded crashes (OOB write, stack buffer overflow).

### 2. `xpdf_fuzzing_module/` (Real Binary, File-Mode)
Fuzzing a legacy, real-world C/C++ codebase (Xpdf 3.02).
- **Key Skills**: Fuzzing with AFL++ in file mode (`@@`), handling Autotools (`./configure && make`) with `afl-clang-fast`.
- **Triage**: Using GDB to identify uncontrolled recursion and stack exhaustion (DoS).

### 3. `libexif_fuzzing_module/` (Library Fuzzing & LTO)
Fuzzing the `libexif` library indirectly through the `exif` CLI driver.
- **Key Skills**: Library-to-driver fuzzing patterns, static linking instrumentation, and utilizing the collision-free **`afl-clang-lto`**.
- **Triage**: GDB analysis of heap metadata corruption vs. out-of-bounds reads.

### 4. `tcpdump_fuzzing_module/` (ASan Triage & Parallel Fleet)
Fuzzing TCPdump 4.9.2 with advanced performance techniques.
- **Key Skills**: Parallel fleet fuzzing (Master/Slave nodes), mitigating disk I/O bottlenecks using `/dev/shm` RAM disks.
- **Architecture**: Implements the Split-Build strategy (Fast profile for 2,700+ execs/sec, ASan profile for precise crash triage). Includes `afl-cmin` corpus minimization.

### 5. `libtiff_fuzzing_module/` (Image Fuzzing)
Fuzzing LibTIFF 4.0.4 via the `tiffinfo` utility.
- **Key Skills**: Image format fuzzing, parallel ASan triage fleets, handling complex target arguments.
- **Triage**: Streamlined crash reproduction using automated triage scripts.

### 6. `libxml2_fuzzing_module/` (Dictionaries & Targeted Seeds)
Fuzzing LibXML2 2.9.4 to hit deep parser states (CVE-2017-9048).
- **Key Skills**: Fuzzing complex structured formats (XML) using **custom dictionaries** (`xml.dict`).
- **Strategy**: Creating highly targeted initial seeds to bypass days of random mutation, combined with a 20-core parallel fuzzer fleet to find crashes in minutes.

---

## General Setup & Prerequisites

All modules are designed to run on a modern Linux system (Ubuntu 22.04/24.04 recommended). 

**Base Requirements:**
```bash
sudo apt update
sudo apt install -y build-essential clang cmake ninja-build git python3 lcov gdb
```

**AFL++ Installation:**
Most modules expect `afl-fuzz`, `afl-clang-fast`, and ideally `afl-clang-lto` to be available in your PATH. We highly recommend building AFL++ from source for the latest features.

**Recommended Environment Variables:**
To maximize throughput and minimize noisy warnings during lab sessions, run:
```bash
export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
```

---

## ⚠️ Safety & Ethics

These modules download and compile older, known-vulnerable software versions intentionally. **Do not** use these compiled binaries in production, and **do not** expose them to untrusted networks. This repository is strictly for educational, local security laboratory use.



Happy Fuzzing! 🐛💥


\>_ [George Yanni](https://www.linkedin.com/in/george-yanni-0x13/)
