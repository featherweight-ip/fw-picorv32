#!/usr/bin/env python3
"""Tiny RV32I encoder for hand-written test programs.

Writes one 32-bit word per line (hex, for $readmemh). Program starts at
address 0 (PROGADDR_RESET).

  python3 tests/sw/asm.py [-o out.hex]
"""
import argparse
import os


def _r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12)
            | (rd << 7) | opcode)


def _i(imm, rs1, funct3, rd, opcode):
    assert -2048 <= imm < 2048, imm
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def _s(imm, rs2, rs1, funct3, opcode):
    assert -2048 <= imm < 2048, imm
    imm &= 0xfff
    return (((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12)
            | ((imm & 0x1f) << 7) | opcode)


def _b(off, rs2, rs1, funct3, opcode):
    assert off % 2 == 0 and -4096 <= off < 4096, off
    off &= 0x1fff
    return ((((off >> 12) & 1) << 31) | (((off >> 5) & 0x3f) << 25)
            | (rs2 << 20) | (rs1 << 15) | (funct3 << 12)
            | (((off >> 1) & 0xf) << 8) | (((off >> 11) & 1) << 7) | opcode)


def _j(off, rd, opcode):
    assert off % 2 == 0 and -(1 << 20) <= off < (1 << 20), off
    off &= 0x1fffff
    return ((((off >> 20) & 1) << 31) | (((off >> 1) & 0x3ff) << 21)
            | (((off >> 11) & 1) << 20) | (((off >> 12) & 0xff) << 12)
            | (rd << 7) | opcode)


def addi(rd, rs1, imm):  return _i(imm, rs1, 0b000, rd, 0b0010011)
def add(rd, rs1, rs2):   return _r(0, rs2, rs1, 0b000, rd, 0b0110011)
def lw(rd, rs1, imm):    return _i(imm, rs1, 0b010, rd, 0b0000011)
def sw(rs2, rs1, imm):   return _s(imm, rs2, rs1, 0b010, 0b0100011)
def beq(rs1, rs2, off):  return _b(off, rs2, rs1, 0b000, 0b1100011)
def jal(rd, off):        return _j(off, rd, 0b1101111)
def ebreak():            return 0x00100073


def smoke():
    return [
        addi(1, 0, 5),        # 0x00 x1 = 5
        addi(2, 0, 7),        # 0x04 x2 = 7
        add(3, 1, 2),         # 0x08 x3 = 12
        sw(3, 0, 0x100),      # 0x0c [0x100] = 12
        lw(4, 0, 0x100),      # 0x10 x4 = 12
        beq(3, 4, 8),         # 0x14 taken -> 0x1c
        addi(5, 0, 1),        # 0x18 skipped
        jal(6, 8),            # 0x1c x6 = 0x20, -> 0x24
        addi(5, 0, 2),        # 0x20 skipped
        addi(7, 0, -1),       # 0x24 x7 = -1
        sw(7, 0, 0x104),      # 0x28 [0x104] = 0xffffffff
        lw(8, 0, 0x104),      # 0x2c x8 = -1
        add(9, 8, 3),         # 0x30 x9 = 11
        ebreak(),             # 0x34 trap
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out",
                    default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "smoke.hex"))
    args = ap.parse_args()
    with open(args.out, "w") as f:
        for w in smoke():
            f.write("%08x\n" % w)


if __name__ == "__main__":
    main()
