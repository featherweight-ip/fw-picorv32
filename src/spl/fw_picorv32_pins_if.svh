// The pins the core drives that are not a bus: the RVFI retire stream and the
// trap level. The pin top implements it on fw_picorv32_xtor_if.
interface class fw_picorv32_pins_if;
    // One retired instruction: rvfi_valid high for one clock with `r` on the
    // rvfi_* pins. Returns after that clock.
    pure virtual task retire(retire_t r);
    // The trap pin: high once the core has trapped and halted.
    pure virtual function void set_trap(bit level);
endclass
