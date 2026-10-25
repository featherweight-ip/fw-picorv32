// Spike S1 (next-design §4): a 32 x 32 register file, 2 read / 1 write,
// written in the form fw-hdl's lowering emits for a class-model array today
// (see fw-uart16550's lowered fw_fifo: one flat vector, a write that
// rebuilds the vector per index, an AND-OR read mux). Hand-written, not
// lowered: the lowering needs an fw_root design with pin bridges, which the
// core (item 4) will have. Compare with regs_ref.v (picorv32_regs's form).
module regs_lowered_style(
    input             clk,
    input             wen,
    input      [4:0]  waddr,
    input      [31:0] wdata,
    input      [4:0]  raddr1,
    input      [4:0]  raddr2,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2
);
    reg [1023:0] mem;
    reg [1023:0] mem__n;
    integer i;

    always @* begin
        mem__n = mem;
        if (wen)
            for (i = 0; i < 32; i = i + 1)
                if (waddr == i[4:0])
                    mem__n[i*32 +: 32] = wdata;
    end

    always @(posedge clk) mem <= mem__n;

    always @* begin
        rdata1 = 32'h0;
        rdata2 = 32'h0;
        for (i = 0; i < 32; i = i + 1) begin
            rdata1 = rdata1 | (mem[i*32 +: 32] & ((raddr1 == i[4:0]) ? 32'hffffffff : 32'h0));
            rdata2 = rdata2 | (mem[i*32 +: 32] & ((raddr2 == i[4:0]) ? 32'hffffffff : 32'h0));
        end
    end
endmodule
