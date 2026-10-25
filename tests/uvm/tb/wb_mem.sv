// Simple Wishbone (classic) memory: one ack per strobe, byte selects.
// Loads +hex=<file> ($readmemh, word per line) at address 0.
module wb_mem #(
    parameter int WORDS = 4096
) (
    input             clock,
    input             reset,
    input      [31:0] adr,
    input      [31:0] dat_w,
    output reg [31:0] dat_r,
    input             we,
    input       [3:0] sel,
    input             stb,
    input             cyc,
    output reg        ack
);
  reg [31:0] mem [0:WORDS-1];

  initial begin
    string hex;
    for (int i = 0; i < WORDS; i++) mem[i] = 32'h0;
    if ($value$plusargs("hex=%s", hex)) $readmemh(hex, mem);
    else $display("wb_mem: no +hex=<file> given");
  end

  wire [31:0] widx = adr >> 2;

  always @(posedge clock) begin
    if (reset) begin
      ack   <= 1'b0;
      dat_r <= 32'h0;
    end else begin
      ack <= 1'b0;
      if (cyc && stb && !ack) begin
        ack <= 1'b1;
        if (widx < WORDS) begin
          dat_r <= mem[widx];
          if (we) begin
            if (sel[0]) mem[widx][7:0]   <= dat_w[7:0];
            if (sel[1]) mem[widx][15:8]  <= dat_w[15:8];
            if (sel[2]) mem[widx][23:16] <= dat_w[23:16];
            if (sel[3]) mem[widx][31:24] <= dat_w[31:24];
          end
        end else begin
          dat_r <= 32'h0;
        end
      end
    end
  end
endmodule
