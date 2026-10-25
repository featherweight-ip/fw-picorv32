/* rv32ui tests: code and data from 0x0 in the 16 KB wb_mem (tb/wb_mem.sv). */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
  . = 0x0;
  .text : { *(.text*) }
  .data : { *(.data*) *(.sdata*) *(.rodata*) *(.bss*) *(.sbss*) }
  ASSERT(. <= 0x3ffc, "program overlaps TOHOST (0x3ffc)")
}
