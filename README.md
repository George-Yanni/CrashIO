# CrashIO

Hands-on fuzzing labs with reproducible build and corpus layout.

## Modules

- **[introductory_module/](introductory_module/)** — Synthetic parser target, stdin harness, AFL++ (normal + persistent), ASan triage, coverage (lcov + Clang).
- **[xpdf_fuzzing_module/](xpdf_fuzzing_module/)** — Real third-party binary (Xpdf 3.02), AFL++ **file mode** (`@@`), crash reproduction, GDB triage.
- **[libexif_fuzzing_module/](libexif_fuzzing_module/)** — Fuzz **libexif** via the **`exif`** CLI driver; static linking; prefer **`afl-clang-lto`**, JPEG corpus, GDB triage (heap vs OOB-read patterns).
- **[tcpdump_fuzzing_module/](tcpdump_fuzzing_module/)** — Fuzz **TCPdump 4.9.2** with AFL++ **file mode** (`@@`), ASan-enabled native build flow for modern Ubuntu, and crash triage helper script.
- **[libxml2_fuzzing_module/](libxml2_fuzzing_module/)** — Fuzz **LibXML2 2.9.4** to reproduce CVE-2017-9048 using **custom dictionaries** and parallel AFL++ instances with AddressSanitizer (ASan).
