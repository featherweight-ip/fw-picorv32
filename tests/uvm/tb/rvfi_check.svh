// The in-order RVFI compare shared by the side-by-side tops (hdl_top_eq,
// hdl_top_tlm_eq), included in the module body. Each top pushes one rec_t per
// retired instruction onto ref_q / dut_q, sets r_done / d_done on the trap
// record, and pops pairs into check().
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
