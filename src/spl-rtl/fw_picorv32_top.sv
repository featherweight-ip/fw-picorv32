// fw_picorv32 DESIGN TOP: the class model on picorv32_ref's pins (the WB
// master side of picorv32_wb). The kit's wb_initiator_xtor drives the bus;
// the bind class makes fw_picorv32 the fw_root and binds its `wb` port to the
// initiator bridge over u_wb.u_if, and its `pins` port to u_if (RVFI, trap).
`include "fw_hdl_macros.svh"

module fw_picorv32_top (
    input             clock,
    input             reset,
    output            trap,

    output     [31:0] adr,
    output     [31:0] dat_w,
    input      [31:0] dat_r,
    output            we,
    output      [3:0] sel,
    output            stb,
    input             ack,
    output            cyc,

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
    import fw_hdl_pkg::*;
    import fw_proto_wb_pkg::*;
    import fw_picorv32_spl_pkg::*;
    import fw_picorv32_spl_rtl_pkg::*;

    fw_picorv32_xtor_if u_if (
        .clock(clock), .reset(reset), .trap(trap),
        .rvfi_valid(rvfi_valid), .rvfi_order(rvfi_order), .rvfi_insn(rvfi_insn),
        .rvfi_trap(rvfi_trap), .rvfi_halt(rvfi_halt), .rvfi_intr(rvfi_intr),
        .rvfi_rs1_addr(rvfi_rs1_addr), .rvfi_rs2_addr(rvfi_rs2_addr),
        .rvfi_rs1_rdata(rvfi_rs1_rdata), .rvfi_rs2_rdata(rvfi_rs2_rdata),
        .rvfi_rd_addr(rvfi_rd_addr), .rvfi_rd_wdata(rvfi_rd_wdata),
        .rvfi_pc_rdata(rvfi_pc_rdata), .rvfi_pc_wdata(rvfi_pc_wdata),
        .rvfi_mem_addr(rvfi_mem_addr), .rvfi_mem_rmask(rvfi_mem_rmask),
        .rvfi_mem_wmask(rvfi_mem_wmask), .rvfi_mem_rdata(rvfi_mem_rdata),
        .rvfi_mem_wdata(rvfi_mem_wdata));

    wb_initiator_xtor #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) u_wb (
        .clock(clock), .reset(reset),
        .adr(adr), .dat_w(dat_w), .dat_r(dat_r), .cyc(cyc), .err(1'b0),
        .sel(sel), .stb(stb), .ack(ack), .we(we));

    class fw_picorv32_top_bind extends fw_component_root #(fw_picorv32);
        function new(string name); super.new(name); endfunction

        virtual function void connect();
            wb_initiator_xtor_bridge #(32, 32)    br;
            fw_export #(wb_proto_if #(32, 32))    ex;
            fw_picorv32_pins_export               px;
            br = new(u_wb.u_if);
            ex = new("wb_bridge", this, br);
            wb.connect(ex);
            px = new("pins_xtor", this, u_if);
            pins.connect(px);
            super.connect();
        endfunction
    endclass

    fw_root #(.Tbind(fw_picorv32_top_bind)) u_root (.clock(clock), .reset(reset));
endmodule
