# Known Issues and Planned Work

This file records known limitations of the M0 Aether baseline.

These items are not necessarily RTL bugs. They identify functionality or
verification infrastructure that is incomplete or intentionally deferred.

## Verification

### Incomplete retirement tracing

The existing tracer observes writeback-oriented events rather than every
architecturally retired instruction.

Consequences include incomplete representation of instructions such as:

- stores
- branches
- instructions without GPR destination writes
- some system effects

A proper retirement interface will be implemented in M1.

### Spike trace termination

RTL and Spike traces can have different lengths for some tests even when their
compared common sequence matches.

The differential-verification infrastructure will be redesigned around explicit
architectural retirement.

### Formal verification

RVFI and architectural formal verification have not yet been implemented.

These are planned for M1.

## Architecture

### Machine interrupts

Machine-mode synchronous exception infrastructure exists, but machine interrupt
support is incomplete.

Future work will include timer, software and external interrupt handling.

### `minstret`

The CSR infrastructure contains `minstret`, but the current core does not yet
provide a proper instruction-retirement event to drive it.

This will be addressed together with the retirement interface.

### Branch prediction

Branches are currently resolved without dynamic branch prediction.

Branch prediction will be introduced and characterized in a later
microarchitecture milestone.

### Floating point

The current core implements RV64IM only.

Floating-point support is planned as a later architectural extension.

### Cache hierarchy

The current core does not contain L1 instruction or data caches.

Cache architecture will be investigated after the frontend and verification
infrastructure are mature.

## Implementation

### PPA

The M0 core successfully completes generic Yosys synthesis.

The current generic gate counts are not treated as physical area measurements.

Technology-mapped:

- area
- maximum frequency
- timing
- power

have not yet been characterized.

### Physical Design

The following have not yet been performed:

- floorplanning
- placement
- clock-tree synthesis
- routing
- post-route STA
- DRC
- LVS
- GDS generation

These are planned for the physical-design milestone.

## M0 Baseline

The M0 baseline currently establishes:

- clean Verilator build
- 74/74 existing regression tests passing
- functional Spike comparison infrastructure
- separated RTL, DV and simulation sources
- synthesizable processor core
- successful Slang/Yosys generic synthesis
- zero problems reported by the final Yosys CHECK pass