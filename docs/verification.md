# Aether Verification

## Overview

Aether uses multiple verification methods rather than relying on a single test
suite.

The current verification flow includes:

- Verilator lint
- directed C tests
- assembly ISA tests
- stress tests
- Spike differential testing
- performance benchmarks
- synthesis structural checks
- physical-design timing and verification checks

## RTL Lint

Verilator is run with `-Wall`.

Two lint configurations are maintained:

- simulation-oriented core lint
- synthesis-oriented core lint with `SYNTHESIS` defined

Run:

    make lint-all

Lint detects structural and coding problems but does not prove architectural
correctness.

## RTL Regression

The regression suite contains C and assembly tests covering the implemented
processor functionality.

Final regression result:

    79 passed
    0 failed

The suite covers areas including:

- integer arithmetic
- logical operations
- shifts
- RV64 word operations
- branches
- jumps
- loads
- stores
- RV64M multiplication
- RV64M division/remainder
- CSR behavior
- traps
- illegal instructions
- misaligned accesses
- stress/integration behavior

Run:

    make regression

## RISC-V ISA Tests

The regression integrates assembly tests derived from the `riscv-tests`
repository for the implemented RV64I and RV64M functionality.

The upstream repository is maintained as a Git submodule.

The local test environment provides the bridge between the ISA tests and
Aether's simulation termination mechanism.

## Directed Tests

Additional C tests exercise behavior that is useful to test at the integrated
core level, including:

- ALU behavior
- branches
- load/store behavior
- CSR behavior
- traps
- M-extension behavior
- stress sequences

These complement the assembly ISA tests.

## Spike Differential Testing

Spike is used as an architectural reference model.

The differential flow:

1. builds a test program;
2. executes it on Aether;
3. records RTL retirement events;
4. executes the same program using Spike;
5. parses both traces;
6. compares architectural execution.

The comparison checks retirement information including:

- PC
- instruction
- architectural register updates

Final differential-regression result:

    73 selected tests passed
    0 failed
    6 excluded

The exclusions are tests for which the current differential comparison is not
used.

Run:

    make spike-regression

A single test can be compared with:

    make spike TEST=<test_name>

Passing differential testing increases confidence that the RTL behaves like the
reference ISA model for the compared executions. It is not a formal proof of
architectural correctness.

## Benchmarks

A small benchmark suite is used to characterize processor behavior.

Workloads include:

- arithmetic
- branch loops
- memory operations
- multiply/divide
- mixed workloads

Reported hardware counters include:

- cycles
- retired instructions
- CPI
- branches
- taken branches
- EX stall cycles
- MEM stall cycles

Run:

    make benchmarks

The benchmark suite is intended for comparative microarchitectural analysis,
not standardized application-performance scoring.

## Synthesis Validation

The synthesizable `core_top` is elaborated using Slang and synthesized with
Yosys.

Checks include:

- successful SystemVerilog elaboration
- successful synthesis
- Yosys structural `CHECK`

The final Sky130HD synthesis reported:

    Found and reported 0 problems.

Simulation-only tracing logic is excluded when `SYNTHESIS` is defined.

## Physical-Design Verification

The Sky130HD implementation additionally checks the physical realization.

Final implementation results include:

- setup violations: 0
- hold violations: 0
- maximum-slew violations: 0
- maximum-capacitance violations: 0
- maximum-fanout violations: 0
- detailed-routing violations: 0
- antenna violations: 0
- KLayout DRC violations: 0
- LVS: PASS

Detailed results are documented in:

    docs/physical_design/

## Logical Equivalence Checking

ORFS logical equivalence checking was not completed.

The bundled Kepler Formal executable terminated with an illegal-instruction
error in the WSL/Docker environment.

The project therefore does not claim completed LEC or formal-equivalence
signoff.

## What the Verification Does Not Prove

Passing the current verification flow does not establish:

- exhaustive correctness for every possible instruction sequence
- formal proof of the complete ISA implementation
- complete privileged-architecture compliance
- interrupt correctness beyond implemented functionality
- silicon correctness
- production signoff

The results establish a tested and physically implemented RV64IM core within
the documented scope.