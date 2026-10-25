// The `tlm` bench: the fw_picorv32 class model alone, with no pins. Its clock
// domain is fw_clock_xtor_if on the clock; memory and RVFI are classes
// (fw_picorv32_tlm_pkg). PASS when the core halts on a trap and TOHOST is 0
// (no self-check) or 1 (riscv-tests pass).
module hdl_top_tlm;
  import fw_picorv32_tlm_pkg::*;

  logic clock = 1'b0;
  logic reset = 1'b1;
  always #5ns clock = ~clock;          // 100 MHz, as the other benches

  fw_clock_xtor_if u_clk (.clock(clock), .reset(reset));

  fw_picorv32_tlm_root root;

  initial begin
    repeat (10) @(posedge clock);
    reset = 1'b0;
    root = new("tlm");
    root.run_to_trap(u_clk);
    $display("TLM: %0d instructions retired, trap at pc=%08h",
             root.rvfi.n, root.pc);
    if (root.mem.tohost > 1)
      $fatal(1, "FAIL: TOHOST=%0d (test %0d failed)", root.mem.tohost, root.mem.tohost >> 1);
    $display("PASS: halted on trap after %0d instructions", root.rvfi.n);
    $finish;
  end

  // Waveforms: `--build dbg` builds with --trace-fst and passes
  // +trace=waves.<fmt> (hdlsim.vlt.SimRunArgsDbg); the dump lands in the run dir.
  initial begin
    string trace_f;
    if ($value$plusargs("trace=%s", trace_f)) begin
      $dumpfile(trace_f);
      $dumpvars(0, hdl_top_tlm);
    end
  end
endmodule
