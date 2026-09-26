# Aether Verification

## M0 Baseline

The M0 verification environment establishes a reproducible functional baseline
before further architectural development.

## Simulation

Primary RTL simulator:

- Verilator

The current design builds cleanly with Verilator `-Wall`.

## Regression Suite

The current regression contains 74 assembly and C tests.

M0 result:

    Tests:   74
    Passed:  74
    Failed:  0

The existing suite exercises functionality including:

- integer arithmetic
- logical operations
- shifts
- RV64 word operations
- branches
- jumps
- loads
- stores
- RV64M multiplication
- RV64M division and remainder
- basic CSR functionality
- selected stress and integration tests

Passing this regression is required when modifying the processor.

## Spike Differential Testing

A differential-testing flow exists using the Spike RISC-V ISA simulator as the
reference model.

The flow:

1. Executes a test on Aether.
2. Generates an RTL execution trace.
3. Executes the corresponding program using Spike.
4. Parses the RTL and Spike logs.
5. Compares the observed architectural events.

The existing comparison has demonstrated matching behavior for tested
instruction sequences.

However, the M0 tracer is not a complete architectural retirement interface.

In particular, the current trace is primarily based on writeback/register-write
events. Instructions without a general-purpose register write are therefore not
fully represented.

Some tests can also produce different RTL and Spike trace lengths while their
common compared prefix matches.

For this reason, the M0 Spike flow is treated as baseline differential testing,
not proof of complete architectural equivalence.

## Synthesis Validation

The synthesizable `core_top` is elaborated using the Slang SystemVerilog
frontend and synthesized using Yosys.

M0 synthesis result:

- SystemVerilog elaboration: PASS
- Generic synthesis: PASS
- Yosys CHECK: 0 reported problems
- Generic synthesized netlist generated successfully

Simulation-only tracing logic is excluded from synthesis.

## M1 Verification Goals

The next verification milestone will introduce a proper architectural
retirement mechanism.

This will be used to support:

- complete differential tracing
- instruction retirement accounting
- `minstret`
- assertions
- RVFI
- formal verification

The objective is to establish a trustworthy verification foundation before
adding significant new microarchitectural features.