# Aether Architecture

## Overview

Aether is a 64-bit in-order RISC-V processor core implemented in SystemVerilog.

The current baseline implements the RV64IM instruction set with a five-stage
pipeline and basic machine-mode CSR and exception support.

This document describes the M0 baseline before further architectural
development.

## ISA

Current baseline:

- RV64I base integer instruction set
- RV64M multiplication and division extension
- 64-bit integer register file
- RV64 word operations
- CSR instructions
- FENCE / FENCE.I handling

Not currently implemented:

- Floating-point extensions
- Compressed instructions
- Branch prediction
- Virtual memory
- Supervisor mode

## Pipeline

Aether uses a five-stage in-order pipeline:

1. Instruction Fetch (IF)
2. Instruction Decode (ID)
3. Execute (EX)
4. Memory (MEM)
5. Writeback (WB)

Pipeline registers:

- IF/ID
- ID/EX
- EX/MEM
- MEM/WB

## Instruction Fetch

The frontend contains an instruction prefetch buffer connected to the
instruction bus.

Control-flow redirection currently occurs when branches and jumps are resolved
in the execute stage.

The frontend supports pipeline flushing following control-flow redirects and
traps.

## Decode

The decode stage determines:

- source and destination registers
- immediate values
- ALU operation
- load/store operation
- branch operation
- multiply/divide operation
- CSR operation
- register-write control
- memory control
- jump control
- system instruction information

The integer register file contains 32 64-bit architectural registers.

## Execute

The execute stage contains:

- 64-bit integer ALU
- branch comparator
- RV64M multiply/divide unit
- CSR execution
- trap detection logic
- operand forwarding logic

Branches and jumps are currently resolved in the execute stage.

## Hazard Handling

The baseline implements pipeline interlocking and forwarding.

Forwarding paths exist from later pipeline stages to the execute stage.

A load-use hazard detector stalls the frontend and inserts the required
pipeline bubble.

Long-latency multiply/divide and memory operations can also stall appropriate
pipeline stages.

## Memory

Aether uses separate instruction and data interfaces.

The load/store unit supports:

- byte accesses
- halfword accesses
- word accesses
- doubleword accesses
- signed loads
- unsigned loads

Misaligned load and store accesses are detected and can generate traps.

An AXI wrapper is provided separately from the processor core.

## System and Trap Support

The baseline contains machine-mode CSR and synchronous trap infrastructure.

Implemented functionality includes:

- ECALL
- EBREAK
- MRET
- illegal-instruction traps
- misaligned load traps
- misaligned store traps

Implemented CSR infrastructure includes registers such as:

- mstatus
- misa
- mtvec
- mscratch
- mepc
- mcause
- mtval
- mcycle
- minstret

Machine interrupt support is not yet complete.

## Current Design Boundary

`core_top` represents the synthesizable processor core.

Simulation-only infrastructure is maintained separately under `sim/` and
`dv/`.

The AXI wrapper is maintained separately under `rtl/bus/`.

## Future Development

Planned development after the M0 baseline includes:

- architectural retirement interface
- stronger differential verification
- formal verification / RVFI
- complete machine interrupt support
- performance instrumentation
- branch prediction
- floating-point support
- cache hierarchy
- PPA characterization
- RTL-to-GDS physical implementation