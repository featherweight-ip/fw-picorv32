// The classes that put the fw_picorv32 class model behind pins
// (fw_picorv32_top.sv): the export for the model's pins port on
// fw_picorv32_xtor_if.
package fw_picorv32_spl_rtl_pkg;
    import fw_hdl_pkg::*;
    import fw_picorv32_spl_pkg::*;

    // fw_picorv32_pins_if on the pins: RVFI stream and trap.
    class fw_picorv32_pins_export extends fw_export #(fw_picorv32_pins_if) implements fw_picorv32_pins_if;
        virtual fw_picorv32_xtor_if vif;
        function new(string name, fw_component parent, virtual fw_picorv32_xtor_if vif);
            super.new(name, parent, null);
            set_imp(this);
            this.vif = vif;
        endfunction
        virtual task retire(retire_t r)               ; vif.retire(r);      endtask
        virtual function void set_trap(bit level)     ; vif.set_trap(level); endfunction
    endclass
endpackage
