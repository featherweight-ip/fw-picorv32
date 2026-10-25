// The core: a top-level runnable component that fetches and executes over a
// Wishbone initiator port. fw_picorv32_top binds `wb` to the kit's
// wb_initiator_xtor_bridge, so each access() is one WB cycle on the pins.
//
// RV32I, one instruction at a time: fetch, decode, execute, retire. Decode
// follows picorv32 (CATCH_ILLINSN=1): anything it does not decode, including
// CSR instructions (ENABLE_COUNTERS=0), ECALL and EBREAK, sets `trapped` and
// the core halts with the trap pin high. Each retired instruction leaves its
// record in `ret` (the RVFI fields), which goes out on the `pins` port.
class fw_picorv32 extends fw_component implements fw_runnable;
    fw_port #(wb_proto_if #(32, 32)) wb;
    fw_port #(fw_picorv32_pins_if)   pins;      // RVFI stream, trap

    bit   [31:0][31:0] regs;     // packed: the lowering writes only packed arrays in a process
    logic [31:0] pc;
    bit          trapped;
    bit   [63:0] order;
    retire_t     ret;

    function new(string name, fw_component parent);
        super.new(name, parent);
        add_runnable(this);
    endfunction

    function void build();
        wb   = new("wb", this);
        pins = new("pins", this);
    endfunction

    function bit [31:0] rd_reg(input bit [4:0] a);
        return (a == 5'd0) ? 32'h0 : regs[a];
    endfunction

    // --- Immediate decode -----------------------------------------------
    function bit [31:0] imm_i(input bit [31:0] i);
        return {{20{i[31]}}, i[31:20]};
    endfunction
    function bit [31:0] imm_s(input bit [31:0] i);
        return {{20{i[31]}}, i[31:25], i[11:7]};
    endfunction
    function bit [31:0] imm_b(input bit [31:0] i);
        return {{19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0};
    endfunction
    function bit [31:0] imm_u(input bit [31:0] i);
        return {i[31:12], 12'h000};
    endfunction
    function bit [31:0] imm_j(input bit [31:0] i);
        return {{11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0};
    endfunction

    // --- ALU: f3 = funct3, alt = funct7[5] (SUB / SRA) -------------------
    function bit [31:0] alu(input bit [2:0] f3, input bit alt,
                            input bit [31:0] a, input bit [31:0] b);
        case (f3)
            3'b000: return alt ? a - b : a + b;
            3'b001: return a << b[4:0];
            3'b010: return ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
            3'b011: return (a < b) ? 32'h1 : 32'h0;
            3'b100: return a ^ b;
            3'b101: return alt ? 32'($signed(a) >>> b[4:0]) : a >> b[4:0];
            3'b110: return a | b;
            default: return a & b;
        endcase
    endfunction

    function bit branch_taken(input bit [2:0] f3, input bit [31:0] a, input bit [31:0] b);
        case (f3)
            3'b000: return a == b;
            3'b001: return a != b;
            3'b100: return $signed(a) < $signed(b);
            3'b101: return $signed(a) >= $signed(b);
            3'b110: return a < b;
            default: return a >= b;    // 3'b111 (010/011 are illegal)
        endcase
    endfunction

    // Does picorv32 decode this instruction? (CATCH_ILLINSN, no PCPI/IRQ/counters)
    function bit legal(input bit [31:0] i);
        bit [2:0] f3 = i[14:12];
        bit [6:0] f7 = i[31:25];
        bit [6:0] op = i[6:0];
        // As one expression: a case of returns here lowers wrong (state/notes/7.md).
        return op == 7'b0110111 || op == 7'b0010111 || op == 7'b1101111    // LUI AUIPC JAL
            || (op == 7'b1100111 && f3 == 3'b000)                          // JALR
            || (op == 7'b1100011 && f3 != 3'b010 && f3 != 3'b011)          // BRANCH
            || (op == 7'b0000011 && f3 != 3'b011 && f3 < 3'b110)           // LOAD
            || (op == 7'b0100011 && f3 < 3'b011)                           // STORE
            || (op == 7'b0010011 && (f3 == 3'b001 ? f7 == 7'h00            // OP-IMM
                                   : f3 == 3'b101 ? (f7 == 7'h00 || f7 == 7'h20) : 1'b1))
            || (op == 7'b0110011 && ((f3 == 3'b000 || f3 == 3'b101)        // OP
                                   ? (f7 == 7'h00 || f7 == 7'h20) : f7 == 7'h00))
            || (op == 7'b0001111 && f3 == 3'b000);                         // FENCE (nop)
        // anything else (SYSTEM: ECALL/EBREAK/CSR) traps
    endfunction

    // Byte lanes for a size (f3[1:0]: 0 byte, 1 half, 2 word) at addr[1:0].
    function bit [3:0] lane_mask(input bit [1:0] sz, input bit [1:0] off);
        return sz == 2'b00 ? 4'b0001 << off
             : sz == 2'b01 ? (off[1] ? 4'b1100 : 4'b0011)
             : 4'b1111;
    endfunction

    function bit misaligned(input bit [1:0] sz, input bit [1:0] off);
        return (sz == 2'b01 && off[0]) || (sz == 2'b10 && off != 2'b00);
    endfunction

    // Load result from the bus word: shift down the lane, then extend (f3[2]: unsigned).
    function bit [31:0] load_ext(input bit [2:0] f3, input bit [1:0] off, input bit [31:0] w);
        bit [31:0] s = w >> {off, 3'b000};
        case (f3)
            3'b000:  return {{24{s[7]}}, s[7:0]};
            3'b001:  return {{16{s[15]}}, s[15:0]};
            3'b100:  return {24'h0, s[7:0]};
            3'b101:  return {16'h0, s[15:0]};
            default: return s;
        endcase
    endfunction

    // Store data replicated into every lane, as picorv32 drives mem_wdata.
    function bit [31:0] store_data(input bit [1:0] sz, input bit [31:0] d);
        case (sz)
            2'b00:   return {4{d[7:0]}};
            2'b01:   return {2{d[15:0]}};
            default: return d;
        endcase
    endfunction

    // One bus cycle. `we` selects write; rdata is the bus word.
    task bus(input logic [31:0] addr, input logic [31:0] wdat, input logic [3:0] sel,
             input logic we, output logic [31:0] rdat, output bit err);
        wb.t.access(addr, wdat, sel, we, rdat, err);
    endtask

    // Fetch, decode and execute one instruction; fills `ret`, or sets `trapped`.
    task step();
        logic [31:0] insn, rdat;
        bit          err;
        bit   [31:0] a, b, ea, nxt, wd;
        bit   [4:0]  rd;
        bit   [3:0]  m;

        ret = '0;
        if (pc[1:0] != 2'b00) begin trapped = 1'b1; return; end
        bus(pc, 32'h0, 4'hF, 1'b0, insn, err);
        ret.insn = insn;
        if (!legal(insn)) begin trapped = 1'b1; return; end

        rd  = insn[11:7];
        a   = rd_reg(insn[19:15]);
        b   = rd_reg(insn[24:20]);
        nxt = pc + 32'd4;
        wd  = 32'h0;

        ret.insn     = insn;
        ret.pc_rdata = pc;
        ret.rs1_addr = insn[19:15];
        ret.rs2_addr = insn[24:20];
        ret.rs1_rdata = a;
        ret.rs2_rdata = b;

        case (insn[6:0])
            7'b0110111: wd = imm_u(insn);                               // LUI
            7'b0010111: wd = pc + imm_u(insn);                          // AUIPC
            7'b1101111: begin wd = nxt; nxt = pc + imm_j(insn); end     // JAL
            7'b1100111: begin                                           // JALR
                wd  = nxt;
                nxt = (a + imm_i(insn)) & ~32'h1;
            end
            7'b1100011: begin                                           // BRANCH
                rd = 5'd0;
                if (branch_taken(insn[14:12], a, b)) nxt = pc + imm_b(insn);
            end
            7'b0000011: begin                                           // LOAD
                ea = a + imm_i(insn);
                if (misaligned(insn[13:12], ea[1:0])) begin trapped = 1'b1; return; end
                // Like the ref: whole-word read (WB sel=0, RVFI rmask=4'hf)
                bus({ea[31:2], 2'b00}, 32'h0, 4'h0, 1'b0, rdat, err);
                wd = load_ext(insn[14:12], ea[1:0], rdat);
                ret.mem_addr  = {ea[31:2], 2'b00};
                ret.mem_rmask = 4'hf;
                ret.mem_rdata = rdat;
            end
            7'b0100011: begin                                           // STORE
                rd = 5'd0;
                ea = a + imm_s(insn);
                if (misaligned(insn[13:12], ea[1:0])) begin trapped = 1'b1; return; end
                m = lane_mask(insn[13:12], ea[1:0]);
                wd = store_data(insn[13:12], b);
                bus({ea[31:2], 2'b00}, wd, m, 1'b1, rdat, err);
                ret.mem_addr  = {ea[31:2], 2'b00};
                ret.mem_wmask = m;
                ret.mem_wdata = wd;
                wd = 32'h0;
            end
            7'b0010011: wd = alu(insn[14:12],                           // OP-IMM
                                 insn[14:12] == 3'b101 && insn[30], a, imm_i(insn));
            7'b0110011: wd = alu(insn[14:12], insn[30], a, b);          // OP
            default:    rd = 5'd0;                                      // FENCE
        endcase

        if (rd != 5'd0) regs[rd] = wd;
        ret.rd_addr  = rd;
        ret.rd_wdata = (rd != 5'd0) ? wd : 32'h0;
        ret.pc_wdata = nxt;
        ret.order    = order;
        ret.valid    = 1'b1;
        order++;
        pc = nxt;
    endtask

    virtual task run();
        pc      = PROGADDR_RESET;
        trapped = 1'b0;
        order   = 0;
        regs    = '0;
        pins.t.set_trap(1'b0);
        // One forever loop: the lowering supports only threads that loop
        // forever, and every path round it must wait for the clock (retire
        // takes one clock). A trap, as in picorv32, gives one last record
        // with trap set (insn and pc of the trapping instruction); then the
        // core idles with trap high.
        forever begin
            if (!trapped) begin
                step();
                if (trapped) begin
                    ret.valid    = 1'b1;
                    ret.trap     = 1'b1;
                    ret.pc_rdata = pc;
                    ret.order    = order;
                    order++;
                    pins.t.set_trap(1'b1);
                end
                pins.t.retire(ret);
            end else begin
                tick(1);
            end
        end
    endtask
endclass
