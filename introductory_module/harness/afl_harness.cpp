#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "../target/parser_lib.h"

// AFL++ harness notes:
// - Reads all input from stdin (works with afl-fuzz via "@@" or stdin mode).
// - Optional persistent mode:
//   Compile with -DUSE_AFL_PERSISTENT and AFL++ will reuse the process across many inputs,
//   improving throughput for "fast" targets.
//
// Persistent mode requires an AFL++ compiler wrapper (afl-clang-fast++/afl-g++) which injects
// __AFL_LOOP and associated runtime glue.

#if defined(USE_AFL_PERSISTENT)
extern "C" {
int __AFL_LOOP(unsigned int);
}
#endif

static std::vector<std::uint8_t> read_all_stdin() {
  std::vector<std::uint8_t> buf;
  constexpr std::size_t kChunk = 4096;
  std::uint8_t tmp[kChunk];

  while (true) {
    const std::size_t n = std::fread(tmp, 1, kChunk, stdin);
    if (n > 0) buf.insert(buf.end(), tmp, tmp + n);
    if (n < kChunk) break;
  }
  return buf;
}

int main() {
#if defined(USE_AFL_PERSISTENT)
  // In persistent mode, AFL++ will repeatedly feed inputs to the same process.
  while (__AFL_LOOP(1000)) {
    auto data = read_all_stdin();
    (void)crashio::intro::parse_message(data.data(), data.size());
  }
  return 0;
#else
  auto data = read_all_stdin();
  (void)crashio::intro::parse_message(data.data(), data.size());
  return 0;
#endif
}

