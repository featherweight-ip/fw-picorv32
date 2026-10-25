// Side-by-side equivalence top: picorv32 reference vs fw-hdl model.
// Each core has its own WB memory loaded from the same +hex image.
// RVFI records are queued per side and compared in order.
`timescale 1ns/1ps
module hdl_top_eq;
  reg clock = 0;
  reg reset = 1;
  always #5 clock = ~clock;

  `include "rvfi_check.svh"

`define CORE_SIG(p) \
  wire        p``trap; \
  wire [31:0] p``adr, p``dat_w, p``dat_r; \
  wire        p``we, p``stb, p``ack, p``cyc; \
  wire  [3:0] p``sel; \
  wire        p``rvfi_valid, p``rvfi_trap, p``rvfi_halt, p``rvfi_intr; \
  wire [63:0] p``rvfi_order; \
  wire [31:0] p``rvfi_insn, p``rvfi_rs1_rdata, p``rvfi_rs2_rdata, p``rvfi_rd_wdata; \
  wire  [4:0] p``rvfi_rs1_addr, p``rvfi_rs2_addr, p``rvfi_rd_addr; \
  wire [31:0] p``rvfi_pc_rdata, p``rvfi_pc_wdata, p``rvfi_mem_addr, p``rvfi_mem_rdata, p``rvfi_mem_wdata; \
  wire  [3:0] p``rvfi_mem_rmask, p``rvfi_mem_wmask;

`define CORE_CONN(p) \
  .clock(clock), .reset(reset), .trap(p``trap), \
  .adr(p``adr), .dat_w(p``dat_w), .dat_r(p``dat_r), .we(p``we), .sel(p``sel), \
  .stb(p``stb), .ack(p``ack), .cyc(p``cyc), \
  .rvfi_valid(p``rvfi_valid), .rvfi_order(p``rvfi_order), .rvfi_insn(p``rvfi_insn), \
  .rvfi_trap(p``rvfi_trap), .rvfi_halt(p``rvfi_halt), .rvfi_intr(p``rvfi_intr), \
  .rvfi_rs1_addr(p``rvfi_rs1_addr), .rvfi_rs2_addr(p``rvfi_rs2_addr), \
  .rvfi_rs1_rdata(p``rvfi_rs1_rdata), .rvfi_rs2_rdata(p``rvfi_rs2_rdata), \
  .rvfi_rd_addr(p``rvfi_rd_addr), .rvfi_rd_wdata(p``rvfi_rd_wdata), \
  .rvfi_pc_rdata(p``rvfi_pc_rdata), .rvfi_pc_wdata(p``rvfi_pc_wdata), \
  .rvfi_mem_addr(p``rvfi_mem_addr), .rvfi_mem_rmask(p``rvfi_mem_rmask), \
  .rvfi_mem_wmask(p``rvfi_mem_wmask), .rvfi_mem_rdata(p``rvfi_mem_rdata), \
  .rvfi_mem_wdata(p``rvfi_mem_wdata)

`define MEM_CONN(p) \
  .clock(clock), .reset(reset), .adr(p``adr), .dat_w(p``dat_w), .dat_r(p``dat_r), \
  .we(p``we), .sel(p``sel), .stb(p``stb), .cyc(p``cyc), .ack(p``ack)

`define REC(p) '{p``rvfi_insn, p``rvfi_trap, p``rvfi_rd_addr, p``rvfi_rd_wdata, \
  p``rvfi_pc_rdata, p``rvfi_pc_wdata, p``rvfi_mem_addr, p``rvfi_mem_rmask, \
  p``rvfi_mem_wmask, p``rvfi_mem_rdata, p``rvfi_mem_wdata}

  `CORE_SIG(r_)
  `CORE_SIG(d_)

  picorv32_ref   u_ref (`CORE_CONN(r_));
  fw_picorv32_top u_dut (`CORE_CONN(d_));
  wb_mem u_ref_mem (`MEM_CONN(r_));
  wb_mem u_dut_mem (`MEM_CONN(d_));

  always @(posedge clock) begin
    if (!reset) begin
      if (r_rvfi_valid && !r_done) begin
        ref_q.push_back(`REC(r_));
        if (r_rvfi_trap) r_done = 1;
      end
      if (d_rvfi_valid && !d_done) begin
        dut_q.push_back(`REC(d_));
        if (d_rvfi_trap) d_done = 1;
      end
      while (ref_q.size() > 0 && dut_q.size() > 0)
        check(ref_q.pop_front(), dut_q.pop_front());
      if (n_err > 10) finish_test();
      if (r_done && d_done) finish_test();
    end
  end

  int max_cycles = 100000;

  task automatic finish_test();
    if (ref_q.size() != 0 || dut_q.size() != 0) begin
      $display("ERROR: unmatched records ref=%0d dut=%0d", ref_q.size(), dut_q.size());
      n_err++;
    end
    // Self-checking programs (rv32ui) write 1 to TOHOST on pass
    if (u_dut_mem.tohost != 0 && u_dut_mem.tohost != 1) begin
      $display("ERROR: TOHOST=%0d (test %0d failed)", u_dut_mem.tohost, u_dut_mem.tohost >> 1);
      n_err++;
    end
    if (n_err == 0 && n_cmp > 0) $display("PASS: %0d RVFI records match", n_cmp);
    else $fatal(1, "FAIL: %0d errors in %0d records", n_err, n_cmp);  // nonzero exit for dfm
    $finish;
  endtask

  initial begin
    void'($value$plusargs("max_cycles=%d", max_cycles));
    repeat (10) @(posedge clock);
    reset <= 0;
    repeat (max_cycles) @(posedge clock);
    $display("TIMEOUT after %0d cycles (ref_done=%0d dut_done=%0d)", max_cycles, r_done, d_done);
    n_err++;
    finish_test();
  end

  // Waveforms: `--build dbg` builds with --trace-fst and passes
  // +trace=waves.<fmt> (hdlsim.vlt.SimRunArgsDbg); the dump lands in the run dir.
  initial begin
    string trace_f;
    if ($value$plusargs("trace=%s", trace_f)) begin
      $dumpfile(trace_f);
      $dumpvars(0, hdl_top_eq);
    end
  end
endmodule
