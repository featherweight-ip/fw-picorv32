# The `tlm` bench (plan and status)

The class model `fw_picorv32` (src/spl) with no pins: its `wb` port is bound
to a class memory (an `access()` call, zero time) and its `pins` port to a
class that collects the RVFI records. The only signals are clock and reset:
the model's clock domain is a `fw_clock_xtor_if` on the clock, as in
fw-uart16550's tlm view (in tlm-eq, the same clock as picorv32). This is the
instruction-set-simulator view of next-design §3: "Class model, memory as a
method call".

## Shape

- `tests/uvm/tb/fw_picorv32_tlm_pkg.sv`
  - `tlm_mem`: `wb_proto_if` over a word array, same map as `tb/wb_mem.sv`
    (4096 words, `+hex`, TOHOST 0x3ffc recorded).
  - `tlm_rvfi`: `fw_picorv32_pins_if`; counts records, optionally queues
    them, `done` on the trap record, `$fatal` past `+max_insns`.
  - `fw_picorv32_tlm_root`: `fw_component_root #(fw_picorv32)` whose
    `connect()` binds `wb` and `pins` to those two.
- `tests/uvm/tb/hdl_top_tlm.sv`: the model alone. PASS when it halts on a
  trap and TOHOST is 0 or 1. Prints the instruction count.
- `tests/uvm/tb/hdl_top_tlm_eq.sv`: picorv32 (signals) beside the tlm model;
  RVFI records compared in order with the same check as `hdl_top_eq`
  (`tb/rvfi_check.svh`, shared).
- dfm (`tests/uvm/flow.yaml`, `rv32ui.yaml`): `tlm-<prog>`, `tlm-eq-<prog>`,
  `tlm-all`, `tlm-eq-all`, `tlm-rv32ui`, `tlm-eq-rv32ui`.
- Speed: `tests/sw/perf.hex` (asm.py `perf`, 250k rounds of an 8-instruction
  loop, 2,000,006 records); roots `tlm-perf` and `tlm-eq-perf`.

## Steps

- [x] 1 tb package + `hdl_top_tlm`; hand Verilator build; smoke and an rv32ui test PASS.
- [x] 2 `rvfi_check.svh` out of `hdl_top_eq`; `hdl_top_tlm_eq`; all directed programs PASS;
      wb-eq-all still PASS.
- [x] 3 dfm roots (+ generator); `dfm run tlm-eq-all tlm-rv32ui tlm-eq-rv32ui` rc 0.
- [x] 4 perf program + timing script; numbers below.

## Status notes
- 1, 2 done (hand Verilator build, packages/verilator 5.052). All 42 hex programs PASS on
  tlm-eq and on the refactored wb eq bench. Mutation (store byte ^1 in tlm_mem) gives
  MISMATCH on tlm-eq mem.hex and TOHOST=5 FAIL on tlm rv32ui-sb. +max_insns guard stops
  a runaway run.
- 3 done. `dfm run` of tlm-all, tlm-eq-all, tlm-rv32ui, tlm-eq-rv32ui and wb-eq-all: each rc 0,
  42 PASS sim.logs per bench, 36x TOHOST 1 on tlm-rv32ui. (`dfm run` takes one root per call.)
  `gen_rv32ui.py` now writes wb-eq, rtl-eq, tlm-eq and tlm roots (148 roots).
- 4 done. perf.hex, 2,000,006 instructions, Verilator 5.052, wall time from /usr/bin/time:

  | Bench | Wall | Notes |
  |---|---|---|
  | tlm (model alone) | 0.12 s | **~17M instructions/s** |
  | tlm-eq (picorv32 + tlm model) | 9.2 s | so picorv32 RTL alone is about 9 s, ~0.22M insn/s |
  | wb-eq (picorv32 + model behind WB pins) | 24.1 s | wb model is about 15 s by difference, ~0.13M insn/s |

  The wb and picorv32 numbers are by subtraction; there is no single-core
  bench for those views. The tlm model is about 130x the wb view and 75x the
  picorv32 RTL. The rtl view (lowered netlist) was not timed.
- Regression after the rvfi_check.svh refactor: wb-eq-all and rtl-eq-all rc 0, 6x PASS each.
- Clock domain switched from fw_clock_period_xtor to fw_clock_xtor_if on a clock (the fw-uart16550 tlm
  pattern; in tlm-eq the same clock as picorv32). All six tlm dfm roots rc 0, 43 PASS each (incl. perf);
  tlm-perf 0.10 s wall. Simulated time does not advance while the program runs: all 2M instructions
  retire at 95 ns (right after reset), since the model only calls tick() after its trap.
