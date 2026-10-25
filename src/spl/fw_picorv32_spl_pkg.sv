// fw-hdl class model of picorv32 (plan §3: RV32I, picorv32_wb bus, RVFI out).
package fw_picorv32_spl_pkg;
    import fw_hdl_pkg::*;
    import fw_std_pkg::*;
    import fw_proto_wb_pkg::*;

    localparam logic [31:0] PROGADDR_RESET = 32'h0000_0000;

    // One retired instruction: the RVFI fields. As in picorv32, a trap gives
    // one last record with trap set (rvfi_trap and rvfi_halt; rvfi_intr is 0).
    typedef struct packed {
        bit        valid;
        bit        trap;
        bit [63:0] order;
        bit [31:0] insn;
        bit [4:0]  rs1_addr;
        bit [4:0]  rs2_addr;
        bit [31:0] rs1_rdata;
        bit [31:0] rs2_rdata;
        bit [4:0]  rd_addr;
        bit [31:0] rd_wdata;
        bit [31:0] pc_rdata;
        bit [31:0] pc_wdata;
        bit [31:0] mem_addr;
        bit [3:0]  mem_rmask;
        bit [3:0]  mem_wmask;
        bit [31:0] mem_rdata;
        bit [31:0] mem_wdata;
    } retire_t;

    `include "fw_picorv32_pins_if.svh"  // RVFI stream and trap pin
    `include "fw_picorv32.svh"     // the core: fetch/execute loop over a WB port

endpackage
