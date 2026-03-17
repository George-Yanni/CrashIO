#pragma once

#include <cstddef>
#include <cstdint>

// A small, intentionally fragile parsing API designed for fuzzing.
//
// Why this is a good AFL++ target:
// - Byte-oriented input format with multiple branches (good for coverage-guided fuzzing)
// - "Magic" tokens and length-prefixed fields (good for dictionaries and corpus evolution)
// - Several bug classes triggered by edge cases:
//   - stack buffer overflow via unsafe copy on a specific tag
//   - OOB write via length arithmetic bug
//   - controlled aborts for "logic bugs" (assert-like conditions) that AFL++ can find quickly
//
// NOTE: This is for research/training. Do not reuse patterns like these in production.

namespace crashio::intro {

// Parses a custom binary-ish format from memory.
// Returns 0 on "success", non-zero on parse error.
int parse_message(const std::uint8_t* data, std::size_t size);

}  // namespace crashio::intro

