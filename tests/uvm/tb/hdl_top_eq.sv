// Side-by-side equivalence top: picorv32 reference vs fw-hdl model.
// Each core has its own WB memory loaded from the same +hex image.
// RVFI records are queued per side and compared in order.
`timescale 1ns/1ps
module hdl_top_eq;
  reg clock = 0;
  reg reset = 1;
  always #5 clock = ~clock;

  typedef struct packed {
    logic [31:0] insn;
    logic        trap;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic [31:0] mem_wdata;
  } rec_t;

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

  rec_t ref_q[$];
  rec_t dut_q[$];
  int   n_cmp  = 0;
  int   n_err  = 0;
  bit   r_done = 0, d_done = 0;

  function automatic logic [31:0] bmask(logic [3:0] m);
    return {{8{m[3]}}, {8{m[2]}}, {8{m[1]}}, {8{m[0]}}};
  endfunction

  task automatic check(input rec_t r, input rec_t d);
    string why = "";
    if (r.insn !== d.insn)         why = {why, " insn"};
    if (r.pc_rdata !== d.pc_rdata) why = {why, " pc_rdata"};
    if (r.trap !== d.trap)         why = {why, " trap"};
    if (!r.trap) begin
      if (r.pc_wdata !== d.pc_wdata) why = {why, " pc_wdata"};
      if (r.rd_addr !== d.rd_addr)   why = {why, " rd_addr"};
      if (r.rd_addr != 0 && r.rd_wdata !== d.rd_wdata) why = {why, " rd_wdata"};
      if (r.mem_rmask !== d.mem_rmask) why = {why, " mem_rmask"};
      if (r.mem_wmask !== d.mem_wmask) why = {why, " mem_wmask"};
      if ((r.mem_rmask | r.mem_wmask) != 0 &&
          (r.mem_addr & ~32'h3) !== (d.mem_addr & ~32'h3)) why = {why, " mem_addr"};
      if ((r.mem_rdata & bmask(r.mem_rmask)) !== (d.mem_rdata & bmask(r.mem_rmask)))
        why = {why, " mem_rdata"};
      if ((r.mem_wdata & bmask(r.mem_wmask)) !== (d.mem_wdata & bmask(r.mem_wmask)))
        why = {why, " mem_wdata"};
    end
    n_cmp++;
    if (why != "") begin
      n_err++;
      $display("MISMATCH #%0d:%s", n_cmp, why);
      $display("  ref: pc=%08h insn=%08h trap=%0d rd=x%0d<=%08h npc=%08h mem a=%08h r=%h w=%h rd=%08h wd=%08h",
               r.pc_rdata, r.insn, r.trap, r.rd_addr, r.rd_wdata, r.pc_wdata,
               r.mem_addr, r.mem_rmask, r.mem_wmask, r.mem_rdata, r.mem_wdata);
      $display("  dut: pc=%08h insn=%08h trap=%0d rd=x%0d<=%08h npc=%08h mem a=%08h r=%h w=%h rd=%08h wd=%08h",
               d.pc_rdata, d.insn, d.trap, d.rd_addr, d.rd_wdata, d.pc_wdata,
               d.mem_addr, d.mem_rmask, d.mem_wmask, d.mem_rdata, d.mem_wdata);
    end
  endtask

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
endmodule
