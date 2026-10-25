// fw_picorv32 DESIGN TOP: the class model on picorv32_ref's pins (the WB
// master side of picorv32_wb). The kit's wb_initiator_xtor drives the bus;
// the bind class makes fw_picorv32 the fw_root and binds its `wb` port to the
// initiator bridge over u_wb.u_if.
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
    output            cyc
);
    import fw_hdl_pkg::*;
    import fw_proto_wb_pkg::*;
    import fw_picorv32_spl_pkg::*;

    assign trap = 1'b0;

    wb_initiator_xtor #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) u_wb (
        .clock(clock), .reset(reset),
        .adr(adr), .dat_w(dat_w), .dat_r(dat_r), .cyc(cyc), .err(1'b0),
        .sel(sel), .stb(stb), .ack(ack), .we(we));

    class fw_picorv32_top_bind extends fw_component_root #(fw_picorv32);
        function new(string name); super.new(name); endfunction

        virtual function void connect();
            wb_initiator_xtor_bridge #(32, 32)    br;
            fw_export #(wb_proto_if #(32, 32))    ex;
            br = new(u_wb.u_if);
            ex = new("wb_bridge", this, br);
            wb.connect(ex);
            super.connect();
        endfunction
    endclass

    fw_root #(.Tbind(fw_picorv32_top_bind)) u_root (.clock(clock), .reset(reset));
endmodule
