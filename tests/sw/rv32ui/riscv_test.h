#ifndef _ENV_FW_PICORV32_TEST_H
#define _ENV_FW_PICORV32_TEST_H

// Bare test env for the side-by-side bench (tests/uvm/tb/hdl_top_eq.sv):
// code at 0x0, no console. The result goes to TOHOST (last word of the
// 16 KB wb_mem): 1 = pass, (TESTNUM << 1) | 1 = fail. Both end in ebreak,
// so the cores halt on a trap either way.

#define RVTEST_RV32U
#define TESTNUM x28
#define TOHOST  0x3ffc

#define RVTEST_CODE_BEGIN		\
	.text;				\
	.global _start;			\
_start:

#define RVTEST_PASS			\
	li	a0, TOHOST;		\
	li	a1, 1;			\
	sw	a1, 0(a0);		\
	ebreak;

#define RVTEST_FAIL			\
	li	a0, TOHOST;		\
	slli	a1, TESTNUM, 1;		\
	ori	a1, a1, 1;		\
	sw	a1, 0(a0);		\
	ebreak;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .data; .balign 4;
#define RVTEST_DATA_END

#endif
