#!/usr/bin/env python3
import argparse
import os
import struct
from pathlib import Path


def u16(x: int) -> bytes:
    return struct.pack("<H", x)


def u32(x: int) -> bytes:
    return struct.pack("<I", x)


def sec(tag: bytes, payload: bytes) -> bytes:
    assert len(tag) == 1
    return tag + u16(len(payload)) + payload


def msg(flags: int, sections: list[bytes]) -> bytes:
    return b"CRIO" + bytes([1, flags]) + u16(len(sections)) + b"".join(sections)


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate deterministic seed corpus for AFL++ intro module.")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parents[1] / "corpora" / "seed"))
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    seeds: dict[str, bytes] = {}
    seeds["seed_01_valid_min.bin"] = msg(0x00, [sec(b"N", b"A")])
    seeds["seed_02_name.bin"] = msg(0x00, [sec(b"N", b"HELLO"), sec(b"S", u32(0x01))])
    seeds["seed_03_sum.bin"] = msg(0x01, [sec(b"N", b"CRASHME"), sec(b"S", u32(0x42424242))])
    seeds["seed_04_blob.bin"] = msg(0x00, [sec(b"B", bytes([0x10, 0x02, 0x41, 0x42, 0x43]))])
    seeds["seed_05_boom_prefix.bin"] = msg(0x00, [sec(b"N", b"BOOM"), sec(b"S", u32(0x1234))])

    for name, data in seeds.items():
        p = out / name
        with open(p, "wb") as f:
            f.write(data)

    # Convenience: show what we wrote.
    total = sum(len(v) for v in seeds.values())
    print(f"[gen_seeds] wrote {len(seeds)} seeds to {out} ({total} bytes total)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

