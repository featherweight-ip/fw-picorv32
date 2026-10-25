// Spike S1 baseline: the register file in picorv32_regs's form (an array,
// synchronous write, asynchronous reads).
module regs_ref(
    input         clk,
    input         wen,
    input  [4:0]  waddr,
    input  [31:0] wdata,
    input  [4:0]  raddr1,
    input  [4:0]  raddr2,
    output [31:0] rdata1,
    output [31:0] rdata2
);
    reg [31:0] regs [0:31];

    always @(posedge clk)
        if (wen) regs[waddr] <= wdata;

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];
endmodule
