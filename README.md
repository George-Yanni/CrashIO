# CrashIO

Hands-on fuzzing labs with reproducible build and corpus layout.

## Modules

- **[introductory_module/](introductory_module/)** — Synthetic parser target, stdin harness, AFL++ (normal + persistent), ASan triage, coverage (lcov + Clang).
- **[xpdf_fuzzing_module/](xpdf_fuzzing_module/)** — Real third-party binary (Xpdf 3.02), AFL++ **file mode** (`@@`), crash reproduction, GDB triage.
