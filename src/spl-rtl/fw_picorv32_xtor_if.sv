// The model's side of the non-bus pins: the RVFI retire stream and the trap
// level. The class side calls these through fw_picorv32_pins_export
// (fw_picorv32_spl_rtl_pkg). rvfi_trap and rvfi_halt follow the record's trap; rvfi_intr stays 0.
interface fw_picorv32_xtor_if (
        input  wire        clock,
        input  wire        reset,
        output reg         trap,
        output reg         rvfi_valid,
        output reg  [63:0] rvfi_order,
        output reg  [31:0] rvfi_insn,
        output reg         rvfi_trap,
        output reg         rvfi_halt,
        output reg         rvfi_intr,
        output reg  [4:0]  rvfi_rs1_addr,
        output reg  [4:0]  rvfi_rs2_addr,
        output reg  [31:0] rvfi_rs1_rdata,
        output reg  [31:0] rvfi_rs2_rdata,
        output reg  [4:0]  rvfi_rd_addr,
        output reg  [31:0] rvfi_rd_wdata,
        output reg  [31:0] rvfi_pc_rdata,
        output reg  [31:0] rvfi_pc_wdata,
        output reg  [31:0] rvfi_mem_addr,
        output reg  [3:0]  rvfi_mem_rmask,
        output reg  [3:0]  rvfi_mem_wmask,
        output reg  [31:0] rvfi_mem_rdata,
        output reg  [31:0] rvfi_mem_wdata
    );
    import fw_picorv32_spl_pkg::*;

    initial begin
        trap           = 1'b0;
        rvfi_valid     = 1'b0;
        rvfi_order     = 64'd0;
        rvfi_insn      = 32'd0;
        rvfi_trap      = 1'b0;
        rvfi_halt      = 1'b0;
        rvfi_intr      = 1'b0;
        rvfi_rs1_addr  = 5'd0;
        rvfi_rs2_addr  = 5'd0;
        rvfi_rs1_rdata = 32'd0;
        rvfi_rs2_rdata = 32'd0;
        rvfi_rd_addr   = 5'd0;
        rvfi_rd_wdata  = 32'd0;
        rvfi_pc_rdata  = 32'd0;
        rvfi_pc_wdata  = 32'd0;
        rvfi_mem_addr  = 32'd0;
        rvfi_mem_rmask = 4'd0;
        rvfi_mem_wmask = 4'd0;
        rvfi_mem_rdata = 32'd0;
        rvfi_mem_wdata = 32'd0;
    end

    // rvfi_valid high for one clock with the record on the rvfi_* pins.
    task automatic retire(input retire_t r);
        rvfi_order     <= r.order;
        rvfi_insn      <= r.insn;
        rvfi_rs1_addr  <= r.rs1_addr;
        rvfi_rs2_addr  <= r.rs2_addr;
        rvfi_rs1_rdata <= r.rs1_rdata;
        rvfi_rs2_rdata <= r.rs2_rdata;
        rvfi_rd_addr   <= r.rd_addr;
        rvfi_rd_wdata  <= r.rd_wdata;
        rvfi_pc_rdata  <= r.pc_rdata;
        rvfi_pc_wdata  <= r.pc_wdata;
        rvfi_mem_addr  <= r.mem_addr;
        rvfi_mem_rmask <= r.mem_rmask;
        rvfi_mem_wmask <= r.mem_wmask;
        rvfi_mem_rdata <= r.mem_rdata;
        rvfi_mem_wdata <= r.mem_wdata;
        rvfi_trap      <= r.trap;
        rvfi_halt      <= r.trap;
        rvfi_valid     <= 1'b1;
        @(posedge clock);
        rvfi_valid     <= 1'b0;
    endtask

    function automatic void set_trap(input bit level); trap = level; endfunction
endinterface
