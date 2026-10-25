# fw-picorv32

[picorv32](https://github.com/YosysHQ/picorv32) (RV32I) written with
fw-hdl, following fw-uart16550 and fw-i2c: a class model behind the
Wishbone kit, verified side by side against the reference core. Both
designs retire through RVFI; the bench compares the RVFI stream and the
Wishbone transactions in order.

## Layout

- `src/ref/`: the reference. `picorv32.v` (YosysHQ, unmodified) and
  `picorv32_ref.sv`, its configuration (`picorv32_wb`,
  `ENABLE_COUNTERS = 0`, RVFI out).

## Running

    ivpm update            # fetch packages/
    direnv allow           # IVPM_PACKAGES etc.
    dfm run lint-rtl

Quick lint of the reference without the flow:

    verilator --lint-only -Wno-fatal -DRISCV_FORMAL --top-module picorv32_ref \
        src/ref/picorv32.v src/ref/picorv32_ref.sv
