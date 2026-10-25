// Side by side at tlm: picorv32 (signals, its own wb_mem) beside the
// fw_picorv32 class model with no pins (fw_picorv32_tlm_pkg, its own class
// memory), both loaded from the same +hex. The model runs to its trap in no
// time; its records then wait in dut_q while picorv32 runs, and the two
// streams are compared in order (rvfi_check.svh).
`timescale 1ns/1ps
module hdl_top_tlm_eq;
  import fw_picorv32_spl_pkg::*;
  import fw_picorv32_tlm_pkg::*;

  reg clock = 0;
  reg reset = 1;
  always #5 clock = ~clock;

  `include "rvfi_check.svh"

  wire        trap;
  wire [31:0] adr, dat_w, dat_r;
  wire        we, stb, ack, cyc;
  wire  [3:0] sel;
  wire        rvfi_valid, rvfi_trap, rvfi_halt, rvfi_intr;
  wire [63:0] rvfi_order;
  wire [31:0] rvfi_insn, rvfi_rs1_rdata, rvfi_rs2_rdata, rvfi_rd_wdata;
  wire  [4:0] rvfi_rs1_addr, rvfi_rs2_addr, rvfi_rd_addr;
  wire [31:0] rvfi_pc_rdata, rvfi_pc_wdata, rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata;
  wire  [3:0] rvfi_mem_rmask, rvfi_mem_wmask;

  picorv32_ref u_ref (
    .clock(clock), .reset(reset), .trap(trap),
    .adr(adr), .dat_w(dat_w), .dat_r(dat_r), .we(we), .sel(sel),
    .stb(stb), .ack(ack), .cyc(cyc),
    .rvfi_valid(rvfi_valid), .rvfi_order(rvfi_order), .rvfi_insn(rvfi_insn),
    .rvfi_trap(rvfi_trap), .rvfi_halt(rvfi_halt), .rvfi_intr(rvfi_intr),
    .rvfi_rs1_addr(rvfi_rs1_addr), .rvfi_rs2_addr(rvfi_rs2_addr),
    .rvfi_rs1_rdata(rvfi_rs1_rdata), .rvfi_rs2_rdata(rvfi_rs2_rdata),
    .rvfi_rd_addr(rvfi_rd_addr), .rvfi_rd_wdata(rvfi_rd_wdata),
    .rvfi_pc_rdata(rvfi_pc_rdata), .rvfi_pc_wdata(rvfi_pc_wdata),
    .rvfi_mem_addr(rvfi_mem_addr), .rvfi_mem_rmask(rvfi_mem_rmask),
    .rvfi_mem_wmask(rvfi_mem_wmask), .rvfi_mem_rdata(rvfi_mem_rdata),
    .rvfi_mem_wdata(rvfi_mem_wdata));

  wb_mem u_ref_mem (
    .clock(clock), .reset(reset), .adr(adr), .dat_w(dat_w), .dat_r(dat_r),
    .we(we), .sel(sel), .stb(stb), .cyc(cyc), .ack(ack));

  // The model: its clock domain is the same clock as picorv32's.
  fw_clock_xtor_if u_clk (.clock(clock), .reset(reset));
  fw_picorv32_tlm_root root;

  function automatic rec_t rec_of(retire_t r);
    return '{r.insn, r.trap, r.rd_addr, r.rd_wdata, r.pc_rdata, r.pc_wdata,
             r.mem_addr, r.mem_rmask, r.mem_wmask, r.mem_rdata, r.mem_wdata};
  endfunction

  initial begin
    root = new("tlm", 1'b1);
    wait (!reset);
    root.run_to_trap(u_clk);
    foreach (root.rvfi.q[i]) dut_q.push_back(rec_of(root.rvfi.q[i]));
    d_done = 1;
  end

  always @(posedge clock) begin
    if (!reset) begin
      if (rvfi_valid && !r_done) begin
        ref_q.push_back('{rvfi_insn, rvfi_trap, rvfi_rd_addr, rvfi_rd_wdata,
                          rvfi_pc_rdata, rvfi_pc_wdata, rvfi_mem_addr, rvfi_mem_rmask,
                          rvfi_mem_wmask, rvfi_mem_rdata, rvfi_mem_wdata});
        if (rvfi_trap) r_done = 1;
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
    if (root.mem.tohost != 0 && root.mem.tohost != 1) begin
      $display("ERROR: TOHOST=%0d (test %0d failed)", root.mem.tohost, root.mem.tohost >> 1);
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
      $dumpvars(0, hdl_top_tlm_eq);
    end
  end
endmodule
