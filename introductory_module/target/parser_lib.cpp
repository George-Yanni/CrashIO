#include "parser_lib.h"

#include <cassert>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace crashio::intro {
namespace {

static inline bool has_prefix(const std::uint8_t* data, std::size_t size, const char* lit) {
  const std::size_t n = std::strlen(lit);
  if (size < n) return false;
  return std::memcmp(data, lit, n) == 0;
}

static inline std::uint16_t read_u16_le(const std::uint8_t* p) {
  return static_cast<std::uint16_t>(p[0]) | (static_cast<std::uint16_t>(p[1]) << 8);
}

static inline std::uint32_t read_u32_le(const std::uint8_t* p) {
  return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
         (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

static inline bool is_printable_ascii(std::uint8_t b) {
  return b >= 0x20 && b <= 0x7e;
}

}  // namespace

// Format (deliberately quirky):
//   0..3   "CRIO"
//   4      version (1)
//   5      flags
//   6..7   section_count (u16 LE)
//   then section_count records:
//     0      tag (ASCII)
//     1..2   len (u16 LE)
//     3..(3+len-1) payload bytes
//
// Tags:
//   'N' - name string (ASCII-ish). If payload starts with "BOOM", triggers an unsafe copy.
//   'S' - "sum" section: 4-byte u32. Certain values trigger assert-like aborts.
//   'B' - blob section: length arithmetic bug may cause OOB write.
int parse_message(const std::uint8_t* data, std::size_t size) {
  if (data == nullptr) return 1;
  if (size < 8) return 2;
  if (!has_prefix(data, size, "CRIO")) return 3;

  const std::uint8_t version = data[4];
  if (version != 1) return 4;

  const std::uint8_t flags = data[5];
  const std::uint16_t section_count = read_u16_le(&data[6]);

  // Mild structure constraint (good for fuzzing to learn constraints).
  if (section_count == 0 || section_count > 64) return 5;

  std::size_t off = 8;
  std::uint32_t running_sum = 0;

  // Some state to make later checks depend on earlier discoveries.
  bool saw_name = false;
  std::string name;

  for (std::uint16_t i = 0; i < section_count; i++) {
    if (off + 3 > size) return 6;
    const char tag = static_cast<char>(data[off + 0]);
    const std::uint16_t len = read_u16_le(&data[off + 1]);
    off += 3;

    if (off + len > size) return 7;
    const std::uint8_t* payload = &data[off];
    off += len;

    switch (tag) {
      case 'N': {
        // Parse "name" with a few branchy checks.
        if (len == 0) return 10;
        if (len > 256) return 11;
        for (std::uint16_t k = 0; k < len; k++) {
          if (!is_printable_ascii(payload[k])) return 12;
        }

        name.assign(reinterpret_cast<const char*>(payload), reinterpret_cast<const char*>(payload) + len);
        saw_name = true;

        // AFL++ should discover "BOOM" quickly with a dictionary.
        if (name.rfind("BOOM", 0) == 0) {
          // Intentional bug: stack buffer overflow via unsafe copy.
          // The bug is gated behind a prefix to encourage coverage-guided discovery.
          char small[16];
          std::strcpy(small, name.c_str());  // NOLINT(cert-err34-c): intentionally unsafe for fuzzing
          // Use the buffer so optimizers don't trivially remove it.
          if (small[0] == 'X') return 99;
        }

        break;
      }
      case 'S': {
        if (len != 4) return 20;
        const std::uint32_t v = read_u32_le(payload);
        running_sum ^= v;

        // "Logic bug" crash: useful for showing how AFL++ finds aborts quickly.
        if ((flags & 0x1) && v == 0x13371337u) {
          std::abort();
        }

        // Another gated crash path: requires prior structure and a specific name.
        if (saw_name && name == "CRASHME" && v == 0x42424242u) {
          assert(false && "Intentional assertion for fuzzing");  // NOLINT
        }

        break;
      }
      case 'B': {
        // A length arithmetic mistake that can lead to an out-of-bounds write.
        // We intentionally keep it small and deterministic for educational triage.
        if (len < 2) return 30;
        const std::uint8_t mode = payload[0];
        const std::uint8_t count = payload[1];
        std::vector<std::uint8_t> buf(32, 0);

        // Intentional bug:
        // - When mode == 0xF0, we "trust" count too much and write count+16 bytes into a 32-byte buffer.
        // - This becomes an OOB write when count > 16.
        if (mode == 0xF0) {
          const std::size_t to_write = static_cast<std::size_t>(count) + 16;
          for (std::size_t j = 0; j < to_write; j++) {
            buf[j] = static_cast<std::uint8_t>(j);  // OOB when to_write > buf.size()
          }
        }

        // More branches based on payload content (for coverage growth).
        for (std::uint16_t k = 2; k < len; k++) {
          running_sum += payload[k];
          if (payload[k] == 0x00 && (flags & 0x2)) running_sum ^= 0xdeadbeefu;
          if (std::isalpha(static_cast<unsigned char>(payload[k])) && (flags & 0x4)) running_sum += 7;
        }

        break;
      }
      default:
        // Unknown tags are tolerated but influence state.
        running_sum += static_cast<std::uint8_t>(tag);
        break;
    }
  }

  // Final check: a branch that depends on the whole input.
  if ((running_sum & 0xffffu) == 0xB16Bu && saw_name && name.size() > 8) {
    // Another explicit crash site (useful for showcasing unique crashes).
    std::abort();
  }

  return 0;
}

}  // namespace crashio::intro

