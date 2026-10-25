#!/usr/bin/env python3
"""Build the rv32ui riscv-tests (from picorv32's tests/) to $readmemh hex.

Each <name>.S here is compiled with riscv_test.h / link.ld (code at 0x0,
result to TOHOST 0x3ffc) and written to tests/sw/rv32ui-<name>.hex, one
32-bit word per line, like asm.py.

  python3 tests/sw/rv32ui/build.py [--gcc <riscv gcc>] [name ...]

The gcc defaults to $RISCV_GCC, else riscv64-unknown-elf-gcc on PATH.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.dirname(HERE)


def build(gcc, name, tmp):
    src = os.path.join(HERE, name + ".S")
    elf = os.path.join(tmp, name + ".elf")
    binf = os.path.join(tmp, name + ".bin")
    subprocess.check_call([
        gcc, "-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles",
        "-I" + HERE, "-T", os.path.join(HERE, "link.ld"), "-o", elf, src])
    objcopy = gcc[:-len("gcc")] + "objcopy"
    subprocess.check_call([objcopy, "-O", "binary", elf, binf])
    with open(binf, "rb") as f:
        data = f.read()
    data += b"\0" * (-len(data) % 4)
    out = os.path.join(OUT_DIR, "rv32ui-" + name + ".hex")
    with open(out, "w") as f:
        for i in range(0, len(data), 4):
            f.write("%08x\n" % int.from_bytes(data[i:i + 4], "little"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gcc", default=os.environ.get(
        "RISCV_GCC", shutil.which("riscv64-unknown-elf-gcc")))
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()
    if not args.gcc:
        sys.exit("no riscv gcc: give --gcc or set RISCV_GCC")
    names = args.names or sorted(
        os.path.basename(p)[:-2] for p in glob.glob(os.path.join(HERE, "*.S")))
    with tempfile.TemporaryDirectory() as tmp:
        for n in names:
            print(build(args.gcc, n, tmp))


if __name__ == "__main__":
    main()
