// fw-hdl class model of picorv32 (plan §3: RV32I, picorv32_wb bus, RVFI out).
package fw_picorv32_spl_pkg;
    import fw_hdl_pkg::*;
    import fw_std_pkg::*;
    import fw_proto_wb_pkg::*;

    localparam logic [31:0] PROGADDR_RESET = 32'h0000_0000;

    `include "fw_picorv32.svh"     // the core: fetch/execute loop over a WB port

endpackage
