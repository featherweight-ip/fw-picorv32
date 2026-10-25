// The `tlm` bench (docs/tlm-bench.md): the fw_picorv32 class model with no
// pins. Its `wb` port is bound to a class memory (each access() is a method
// call that takes no time) and its `pins` port to a class that takes the RVFI
// records. The only signals are the clock and reset: the bench seats the
// root's clock domain on a fw_clock_xtor_if and starts it.
package fw_picorv32_tlm_pkg;
    import fw_hdl_pkg::*;
    import fw_proto_wb_pkg::*;
    import fw_picorv32_spl_pkg::*;

    // The memory of tb/wb_mem.sv as a class: WORDS words at address 0, loaded
    // from +hex=<file>, stores to TOHOST recorded (riscv-tests: 1 = pass).
    class tlm_mem implements wb_proto_if #(32, 32);
        localparam int WORDS  = 4096;
        localparam int TOHOST = 32'h3ffc;

        logic [31:0] mem [WORDS];
        logic [31:0] tohost;

        function new();
            string hex;
            tohost = 32'h0;
            foreach (mem[i]) mem[i] = 32'h0;
            if ($value$plusargs("hex=%s", hex)) $readmemh(hex, mem);
            else $display("tlm_mem: no +hex=<file> given");
        endfunction

        virtual task access(
                input  [31:0] adr,
                input  [31:0] dat_w,
                input  [3:0]  sel,
                input         we,
                output [31:0] dat_r,
                output        err);
            automatic logic [31:0] widx = adr >> 2;
            err   = 1'b0;
            dat_r = 32'h0;
            if (widx < WORDS) begin
                dat_r = mem[widx];
                if (we) begin
                    if (widx == (TOHOST >> 2)) begin
                        tohost = dat_w;
                        $display("TOHOST %0d", dat_w);
                    end
                    if (sel[0]) mem[widx][7:0]   = dat_w[7:0];
                    if (sel[1]) mem[widx][15:8]  = dat_w[15:8];
                    if (sel[2]) mem[widx][23:16] = dat_w[23:16];
                    if (sel[3]) mem[widx][31:24] = dat_w[31:24];
                end
            end
        endtask
    endclass

    // The model's pins as a class: each retire() is one RVFI record, taken in
    // no time. `done` is set by the trap record (the core halts after it).
    // A program that never traps would run forever in zero time, so past
    // +max_insns=<n> records the run stops.
    class tlm_rvfi implements fw_picorv32_pins_if;
        bit      keep;          // queue the records (for a compare)
        retire_t q[$];
        longint  n;
        longint  max_insns = 1000000;
        bit      trap;
        bit      done;

        function new(bit keep = 1'b0);
            this.keep = keep;
            void'($value$plusargs("max_insns=%d", max_insns));
        endfunction

        virtual task retire(retire_t r);
            if (done) return;
            if (keep) q.push_back(r);
            n++;
            if (r.trap) done = 1'b1;
            else if (n >= max_insns)
                $fatal(1, "FAIL: no trap after %0d instructions (+max_insns)", n);
        endtask

        virtual function void set_trap(bit level); trap = level; endfunction
    endclass

    // fw_picorv32 as the root, its ports bound to `mem` and `rvfi`.
    class fw_picorv32_tlm_root extends fw_component_root #(fw_picorv32);
        tlm_mem  mem;
        tlm_rvfi rvfi;

        function new(string name, bit keep = 1'b0);
            super.new(name);
            mem  = new();
            rvfi = new(keep);
        endfunction

        virtual function void connect();
            fw_export #(wb_proto_if #(32, 32)) ex;
            fw_export #(fw_picorv32_pins_if)   px;
            ex = new("tlm_mem", this, mem);
            wb.connect(ex);
            px = new("tlm_rvfi", this, rvfi);
            pins.connect(px);
            super.connect();
        endfunction

        // Seat the clock domain on `vif` and run until the trap record.
        task run_to_trap(virtual fw_clock_xtor_if vif);
            fw_clock_xtor_bridge clk;
            clk = new("clock", this, vif);
            clock.connect(clk);
            fork
                start();
            join_none
            wait (rvfi.done);
        endtask
    endclass
endpackage
