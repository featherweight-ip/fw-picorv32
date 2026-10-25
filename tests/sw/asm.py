#!/usr/bin/env python3
"""Tiny RV32I encoder for hand-written test programs.

Writes one 32-bit word per line (hex, for $readmemh). Program starts at
address 0 (PROGADDR_RESET).

  python3 tests/sw/asm.py                 # writes every program to tests/sw/<name>.hex
  python3 tests/sw/asm.py --prog alu [-o out.hex]
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


def _u(imm20, rd, opcode):
    assert 0 <= imm20 < (1 << 20), imm20
    return (imm20 << 12) | (rd << 7) | opcode


def _sh(funct7, shamt, rs1, funct3, rd):
    assert 0 <= shamt < 32, shamt
    return _r(funct7, shamt, rs1, funct3, rd, 0b0010011)


OP, OPIMM, LOAD, STORE, BRANCH = 0b0110011, 0b0010011, 0b0000011, 0b0100011, 0b1100011

def lui(rd, imm20):      return _u(imm20, rd, 0b0110111)
def auipc(rd, imm20):    return _u(imm20, rd, 0b0010111)
def jal(rd, off):        return _j(off, rd, 0b1101111)
def jalr(rd, rs1, imm):  return _i(imm, rs1, 0b000, rd, 0b1100111)

def beq(rs1, rs2, off):  return _b(off, rs2, rs1, 0b000, BRANCH)
def bne(rs1, rs2, off):  return _b(off, rs2, rs1, 0b001, BRANCH)
def blt(rs1, rs2, off):  return _b(off, rs2, rs1, 0b100, BRANCH)
def bge(rs1, rs2, off):  return _b(off, rs2, rs1, 0b101, BRANCH)
def bltu(rs1, rs2, off): return _b(off, rs2, rs1, 0b110, BRANCH)
def bgeu(rs1, rs2, off): return _b(off, rs2, rs1, 0b111, BRANCH)

def lb(rd, rs1, imm):    return _i(imm, rs1, 0b000, rd, LOAD)
def lh(rd, rs1, imm):    return _i(imm, rs1, 0b001, rd, LOAD)
def lw(rd, rs1, imm):    return _i(imm, rs1, 0b010, rd, LOAD)
def lbu(rd, rs1, imm):   return _i(imm, rs1, 0b100, rd, LOAD)
def lhu(rd, rs1, imm):   return _i(imm, rs1, 0b101, rd, LOAD)
def sb(rs2, rs1, imm):   return _s(imm, rs2, rs1, 0b000, STORE)
def sh(rs2, rs1, imm):   return _s(imm, rs2, rs1, 0b001, STORE)
def sw(rs2, rs1, imm):   return _s(imm, rs2, rs1, 0b010, STORE)

def addi(rd, rs1, imm):  return _i(imm, rs1, 0b000, rd, OPIMM)
def slti(rd, rs1, imm):  return _i(imm, rs1, 0b010, rd, OPIMM)
def sltiu(rd, rs1, imm): return _i(imm, rs1, 0b011, rd, OPIMM)
def xori(rd, rs1, imm):  return _i(imm, rs1, 0b100, rd, OPIMM)
def ori(rd, rs1, imm):   return _i(imm, rs1, 0b110, rd, OPIMM)
def andi(rd, rs1, imm):  return _i(imm, rs1, 0b111, rd, OPIMM)
def slli(rd, rs1, sh):   return _sh(0b0000000, sh, rs1, 0b001, rd)
def srli(rd, rs1, sh):   return _sh(0b0000000, sh, rs1, 0b101, rd)
def srai(rd, rs1, sh):   return _sh(0b0100000, sh, rs1, 0b101, rd)

def add(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b000, rd, OP)
def sub(rd, rs1, rs2):   return _r(0b0100000, rs2, rs1, 0b000, rd, OP)
def sll(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b001, rd, OP)
def slt(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b010, rd, OP)
def sltu(rd, rs1, rs2):  return _r(0b0000000, rs2, rs1, 0b011, rd, OP)
def xor(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b100, rd, OP)
def srl(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b101, rd, OP)
def sra(rd, rs1, rs2):   return _r(0b0100000, rs2, rs1, 0b101, rd, OP)
def or_(rd, rs1, rs2):   return _r(0b0000000, rs2, rs1, 0b110, rd, OP)
def and_(rd, rs1, rs2):  return _r(0b0000000, rs2, rs1, 0b111, rd, OP)

def ebreak():            return 0x00100073


def li(rd, val):
    """lui+addi pair loading any 32-bit value (always two words)."""
    val &= 0xffffffff
    lo = val & 0xfff
    if lo >= 0x800:
        lo -= 0x1000
    hi = ((val - lo) >> 12) & 0xfffff
    return [lui(rd, hi), addi(rd, rd, lo)]


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


def _flat(items):
    out = []
    for it in items:
        out.extend(it if isinstance(it, list) else [it])
    return out


def alu():
    """Every OP/OP-IMM/U-type op on edge values (0x80000000, -1, shifts by 0/31)."""
    p = [li(1, 0x80000000), addi(2, 0, -1), li(3, 0x12345678), addi(4, 0, 31),
         addi(5, 0, 0), lui(6, 0x12345), auipc(7, 0x1), auipc(8, 0)]
    for a, b in ((1, 2), (2, 1), (3, 1), (1, 1), (2, 2), (3, 0)):
        p += [add(10, a, b), sub(11, a, b), slt(12, a, b), sltu(13, a, b),
              xor(14, a, b), or_(15, a, b), and_(16, a, b)]
    for a in (1, 2, 3):
        for b in (4, 5, 0, 2):           # shift by 31, 0, 0 (x0), 31 (-1 & 31)
            p += [sll(17, a, b), srl(18, a, b), sra(19, a, b)]
        for sh in (0, 1, 4, 31):
            p += [slli(20, a, sh), srli(21, a, sh), srai(22, a, sh)]
        for imm in (0, 1, -1, 2047, -2048):
            p += [addi(23, a, imm), slti(24, a, imm), sltiu(25, a, imm),
                  xori(26, a, imm), ori(27, a, imm), andi(28, a, imm)]
    p += [addi(0, 1, 5), add(0, 1, 2), add(29, 0, 0), ebreak()]   # x0 stays 0
    return _flat(p)


def mem():
    """Byte/half/word stores and loads at every offset, with sign extension."""
    p = [addi(1, 0, 0x200), li(2, 0x8899aabb), li(3, 0x7f80ff01),
         sw(2, 1, 0), sw(3, 1, 4)]
    for off in range(8):
        p += [lb(10, 1, off), lbu(11, 1, off)]
    for off in (0, 2, 4, 6):
        p += [lh(12, 1, off), lhu(13, 1, off)]
    for off in range(4):
        p += [sb(3, 1, 8 + off), lw(14, 1, 8), addi(3, 3, 0x11)]
    for off in (0, 2):
        p += [sh(2, 1, 12 + off), lw(15, 1, 12), lh(16, 1, 12 + off)]
    p += [sw(0, 1, 16), sb(2, 1, 17), sh(3, 1, 18), lw(17, 1, 16),
          lw(18, 1, -4), addi(4, 1, 0x7), lbu(19, 4, -7), sw(2, 4, 13), lw(20, 1, 20),
          ebreak()]
    return _flat(p)


def branch():
    """Each branch taken and not taken; a taken branch skips one marker addi."""
    p = [li(1, 0x80000000), addi(2, 0, -1), addi(3, 0, 1), addi(4, 0, 1)]
    for br in (beq, bne, blt, bge, bltu, bgeu):
        for a, b in ((1, 2), (2, 1), (3, 4), (0, 2)):
            p += [br(a, b, 8), addi(10, 10, 1)]
    p += [blt(0, 3, 12), addi(11, 0, 1), ebreak(),      # forward skip over 2
          jal(5, 8), ebreak(),                          # jal over trap
          auipc(6, 0), jalr(7, 6, 12), ebreak(),        # jalr to auipc+12
          addi(8, 0, 3),
          addi(8, 8, -1), bne(8, 0, -4),                # backward loop x3
          auipc(6, 0), jalr(0, 6, 9),                   # lsb of target cleared
          ebreak(),
          ebreak()]
    return _flat(p)


def trap_misaligned():
    return [addi(1, 0, 0x101), addi(2, 0, 5), lw(3, 1, 0), addi(4, 0, 1), ebreak()]


def trap_illegal():
    return [addi(1, 0, 5), 0xffffffff, addi(4, 0, 1), ebreak()]


PERF_ITERS = 250000


def perf():
    """Speed: PERF_ITERS rounds of an 8-instruction loop (ALU, load, store,
    branch), about 2M instructions, then ebreak."""
    p = [li(1, PERF_ITERS), addi(2, 0, 0x300), addi(3, 0, 1), sw(0, 2, 0)]
    loop = [lw(4, 2, 0), add(4, 4, 3), sw(4, 2, 0), xor(5, 4, 1),
            slli(6, 5, 3), srai(7, 6, 1), addi(1, 1, -1)]
    loop.append(bne(1, 0, -4 * len(loop)))
    return _flat(p + loop + [ebreak()])


PROGS = {
    "smoke": smoke,
    "alu": alu,
    "mem": mem,
    "branch": branch,
    "trap-misaligned": trap_misaligned,
    "trap-illegal": trap_illegal,
    "perf": perf,
}


def write(words, path):
    with open(path, "w") as f:
        for w in words:
            f.write("%08x\n" % w)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prog", choices=sorted(PROGS))
    ap.add_argument("-o", "--out")
    args = ap.parse_args()
    here = os.path.dirname(os.path.abspath(__file__))
    for name in [args.prog] if args.prog else PROGS:
        out = args.out if args.out else os.path.join(here, name + ".hex")
        write(PROGS[name](), out)


if __name__ == "__main__":
    main()
