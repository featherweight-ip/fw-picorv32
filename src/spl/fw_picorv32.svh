// The core: a top-level runnable component that fetches and executes over a
// Wishbone initiator port. fw_picorv32_top binds `wb` to the kit's
// wb_initiator_xtor_bridge, so each access() is one WB cycle on the pins.
//
// Stub for now (item 4a): fetches the word at PROGADDR_RESET, then idles.
class fw_picorv32 extends fw_component implements fw_runnable;
    fw_port #(wb_proto_if #(32, 32)) wb;

    logic [31:0] pc;

    function new(string name, fw_component parent);
        super.new(name, parent);
        add_runnable(this);
    endfunction

    function void build();
        wb = new("wb", this);
    endfunction

    // One 32-bit read: the instruction fetch and data-load bus cycle.
    task fetch(input logic [31:0] addr, output logic [31:0] insn, output bit err);
        wb.t.access(addr, 32'h0, 4'hF, 1'b0, insn, err);
    endtask

    virtual task run();
        logic [31:0] insn;
        bit          err;
        pc = PROGADDR_RESET;
        fetch(pc, insn, err);
        forever tick(1);
    endtask
endclass
