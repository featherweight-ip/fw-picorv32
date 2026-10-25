// Reference configuration of picorv32 (plan §3): picorv32_wb with its
// defaults except ENABLE_COUNTERS = 0. RVFI is always brought out, so the
// fileset compiles with RISCV_FORMAL defined. PCPI and IRQ are tied off.
module picorv32_ref (
    input             clock,
    input             reset,
    output            trap,

    // Wishbone initiator
    output     [31:0] adr,
    output     [31:0] dat_w,
    input      [31:0] dat_r,
    output            we,
    output      [3:0] sel,
    output            stb,
    input             ack,
    output            cyc,

    // RVFI
    output            rvfi_valid,
    output     [63:0] rvfi_order,
    output     [31:0] rvfi_insn,
    output            rvfi_trap,
    output            rvfi_halt,
    output            rvfi_intr,
    output      [4:0] rvfi_rs1_addr,
    output      [4:0] rvfi_rs2_addr,
    output     [31:0] rvfi_rs1_rdata,
    output     [31:0] rvfi_rs2_rdata,
    output      [4:0] rvfi_rd_addr,
    output     [31:0] rvfi_rd_wdata,
    output     [31:0] rvfi_pc_rdata,
    output     [31:0] rvfi_pc_wdata,
    output     [31:0] rvfi_mem_addr,
    output      [3:0] rvfi_mem_rmask,
    output      [3:0] rvfi_mem_wmask,
    output     [31:0] rvfi_mem_rdata,
    output     [31:0] rvfi_mem_wdata
);

  picorv32_wb #(
      .ENABLE_COUNTERS   (0),
      .ENABLE_COUNTERS64 (0)
  ) u_core (
      .trap        (trap),
      .wb_rst_i    (reset),
      .wb_clk_i    (clock),
      .wbm_adr_o   (adr),
      .wbm_dat_o   (dat_w),
      .wbm_dat_i   (dat_r),
      .wbm_we_o    (we),
      .wbm_sel_o   (sel),
      .wbm_stb_o   (stb),
      .wbm_ack_i   (ack),
      .wbm_cyc_o   (cyc),
      .pcpi_valid  (),
      .pcpi_insn   (),
      .pcpi_rs1    (),
      .pcpi_rs2    (),
      .pcpi_wr     (1'b0),
      .pcpi_rd     (32'b0),
      .pcpi_wait   (1'b0),
      .pcpi_ready  (1'b0),
      .irq         (32'b0),
      .eoi         (),
      .rvfi_valid     (rvfi_valid),
      .rvfi_order     (rvfi_order),
      .rvfi_insn      (rvfi_insn),
      .rvfi_trap      (rvfi_trap),
      .rvfi_halt      (rvfi_halt),
      .rvfi_intr      (rvfi_intr),
      .rvfi_rs1_addr  (rvfi_rs1_addr),
      .rvfi_rs2_addr  (rvfi_rs2_addr),
      .rvfi_rs1_rdata (rvfi_rs1_rdata),
      .rvfi_rs2_rdata (rvfi_rs2_rdata),
      .rvfi_rd_addr   (rvfi_rd_addr),
      .rvfi_rd_wdata  (rvfi_rd_wdata),
      .rvfi_pc_rdata  (rvfi_pc_rdata),
      .rvfi_pc_wdata  (rvfi_pc_wdata),
      .rvfi_mem_addr  (rvfi_mem_addr),
      .rvfi_mem_rmask (rvfi_mem_rmask),
      .rvfi_mem_wmask (rvfi_mem_wmask),
      .rvfi_mem_rdata (rvfi_mem_rdata),
      .rvfi_mem_wdata (rvfi_mem_wdata),
      .trace_valid (),
      .trace_data  (),
      .mem_instr   ()
  );

endmodule
