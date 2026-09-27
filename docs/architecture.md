# Aether Architecture

## Overview

Aether is a synthesizable 64-bit RISC-V processor core written in SystemVerilog.

The current implementation supports RV64IM using a five-stage in-order
pipeline with forwarding, hazard control, multi-cycle integer
multiplication/division, machine-mode CSR/trap support, and hardware
performance counters.

The synthesizable processor boundary is `core_top`.

## ISA

Implemented ISA:

- RV64I base integer instruction set
- RV64M integer multiplication and division extension
- RV64 word operations
- CSR instructions
- FENCE / FENCE.I handling

Not implemented:

- compressed instructions
- floating-point extensions
- virtual memory
- supervisor mode
- dynamic branch prediction
- cache hierarchy

## Pipeline

Aether uses five stages:

1. IF — Instruction Fetch
2. ID — Instruction Decode / Register Read
3. EX — Execute
4. MEM — Memory Access
5. WB — Writeback

Pipeline registers:

- IF/ID
- ID/EX
- EX/MEM
- MEM/WB

The pipeline is in-order.

## Instruction Fetch

The fetch stage communicates with the instruction interface using:

- request
- address
- grant
- read-valid
- read-data

Control-flow redirects return a new PC to the frontend.

Branches and jumps are resolved in the execute stage.

## Decode

The decoder determines:

- source registers
- destination register
- source-register usage
- immediate value
- functional unit
- ALU operation
- load/store operation
- branch operation
- multiply/divide operation
- CSR operation
- control-flow operation
- operand selection
- register-write control
- CSR-write control
- system-instruction information
- illegal-instruction status

The integer register file contains 32 architectural 64-bit registers.

## Execute

The execute stage contains:

- 64-bit integer ALU
- branch comparator
- branch/jump target generation
- forwarding selection
- iterative RV64M multiply/divide unit
- CSR execution
- trap generation
- frontend redirect generation

### Forwarding

Execute operands can be selected from:

- register-file values
- MEM-stage forwarding data
- WB-stage forwarding data

This avoids unnecessary stalls when a required value is already available in a
later pipeline stage.

### Branches and jumps

Conditional branches, JAL and JALR are resolved in EX.

Branch and JAL targets use:

    PC + immediate

JALR uses:

    (rs1 + immediate) & ~1

A taken control transfer generates a frontend redirect and flushes younger
incorrect-path work.

## Multiply / Divide

RV64M operations use an iterative multi-cycle unit.

### Multiplication

Multiplication uses radix-2 shift-and-add.

Instead of implementing a complete combinational multiplier, the unit processes
one multiplier bit per cycle and stores intermediate state in registers.

Supported operations include:

- MUL
- MULH
- MULHSU
- MULHU
- MULW

### Division

Division uses radix-2 restoring division.

The divider generates quotient bits iteratively while maintaining a partial
remainder.

Supported operations include:

- DIV
- DIVU
- REM
- REMU
- DIVW
- DIVUW
- REMW
- REMUW

The unit explicitly handles RISC-V-defined divide-by-zero and signed-overflow
cases.

The execute stage stalls while an M-extension operation is active and continues
when the result becomes valid.

## Hazard Control

The core supports:

- MEM -> EX forwarding
- WB -> EX forwarding
- load-use interlocking
- execution-stage stalls
- memory-stage stalls
- redirect flushing
- trap flushing

The hazard unit controls stalls and flushes across the pipeline registers.

## Memory

Aether exposes separate instruction and data interfaces.

The load/store path supports:

- byte
- halfword
- word
- doubleword
- signed loads
- unsigned loads
- byte-enable generation
- misaligned-access detection

Misaligned accesses can generate synchronous traps.

A bus wrapper is maintained separately under `rtl/bus/`.

## CSR and Trap Support

The core includes machine-mode CSR and synchronous exception infrastructure.

Supported system behavior includes:

- ECALL
- EBREAK
- MRET
- illegal-instruction traps
- misaligned load traps
- misaligned store traps

CSR infrastructure includes machine-mode state such as:

- `mstatus`
- `misa`
- `mtvec`
- `mscratch`
- `mepc`
- `mcause`
- `mtval`
- cycle/retirement-related state

Complete machine interrupt support is not currently implemented.

## Performance Monitoring

`core_top` exposes hardware counters for:

- cycles
- retired instructions
- branches
- taken branches
- redirects
- loads
- stores
- M-extension operations
- EX stall cycles
- MEM stall cycles

These counters are used by the benchmark environment to calculate CPI and
identify pipeline stall sources.

## Design Boundaries

Synthesizable RTL:

    rtl/

Verification-only RTL and test infrastructure:

    dv/

Simulation-only SoC/RAM:

    sim/

Software startup and linker support:

    sw/

Generic and physical synthesis configuration:

    syn/

## Current Limitations

Aether is an educational processor core rather than a complete production SoC.

Current limitations include:

- no branch predictor
- no cache hierarchy
- no MMU
- no supervisor mode
- no floating-point extension
- no compressed extension
- incomplete machine interrupt support