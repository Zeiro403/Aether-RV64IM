# Aether RV64IM

A synthesizable 64-bit RISC-V processor core implementing the RV64IM ISA in SystemVerilog.

Aether uses a 5-stage in-order pipeline, forwarding and hazard control, iterative integer multiplication/division, separate instruction and data interfaces, machine-mode CSR/trap support, and hardware performance counters.

The core has been verified with directed tests, RISC-V ISA tests, Spike differential testing, and stress tests. It has also been synthesized and physically implemented using the Sky130HD standard-cell library with OpenROAD-flow-scripts.

## Architecture

[Architecture](docs/architecture.md)

### Processor

- ISA: RV64IM
- Pipeline: 5-stage in-order
  - IF — Instruction Fetch
  - ID — Decode / Register Read
  - EX — Execute
  - MEM — Memory Access
  - WB — Writeback
- Reset vector: `0x80000000`
- Separate instruction and data interfaces
- Machine-mode CSR and trap support
- Hardware performance counters

### Hazard handling

The pipeline implements:

- MEM → EX forwarding
- WB → EX forwarding
- load-use interlocks
- execution-stage stalls
- memory-stage stalls
- pipeline flushing on redirects

### Integer multiply/divide

The M extension uses multi-cycle iterative hardware:

- radix-2 shift-and-add multiplication
- radix-2 restoring division
- 64-bit RV64 operations
- 32-bit RV64 word operations
- signed and unsigned operations
- RISC-V divide-by-zero and signed-overflow behavior

The initial implementation used behavioral `*`, `/`, and `%` operators with counters controlling completion. Although the interface appeared multi-cycle, synthesis inferred large combinational arithmetic networks.

Replacing this with iterative hardware reduced Sky130HD synthesis results from:

| Metric | Initial | Iterative MULDIV |
|---|---:|---:|
| Standard cells | 87,490 | 29,231 |
| Cell area | 802,513 µm² | 295,352 µm² |
| Full adders | 9,051 | 6 |
| Half adders | 7,571 | 607 |

Synthesized standard-cell area decreased by approximately 63%.

## Verification

Aether uses several verification levels.

### RTL regression

The regression environment compiles and executes directed C/assembly tests and RISC-V ISA tests using Verilator.

```bash
make regression
```

### Spike differential testing

A retirement tracer records architectural state changes from the RTL.

The differential-testing flow compares retired instructions against Spike, including:

- program counter
- instruction
- architectural register updates

Run the Spike regression with:

```bash
make spike-regression
```

A single test can be compared with:

```bash
make spike TEST=<test_name>
```

### Lint

Simulation-oriented and synthesis-oriented Verilator lint configurations are provided:

```bash
make lint-all
```

### Complete verification

```bash
make verify
```

### Benchmarks

Small processor benchmarks exercise arithmetic, branches, memory accesses, M-extension operations, and mixed workloads.

```bash
make benchmarks
```

Reported metrics include:

- cycles
- retired instructions
- CPI
- branches
- taken branches
- execution stall cycles
- memory stall cycles

More detail is available in [`docs/verification.md`](docs/verification.md).

## Sky130HD Physical Implementation

Aether has been synthesized and physically implemented with OpenROAD-flow-scripts using the Sky130HD standard-cell library.

### Configuration

- Top module: `core_top`
- Platform: Sky130HD
- HDL frontend: Slang/Yosys
- Clock constraint: 20 ns (50 MHz)
- Initial core utilization: 45%
- Final slew repair margin: 20%
- Final capacitance repair margin: 20%

Physical-design configuration:

```text
syn/sky130hd/config.mk
syn/sky130hd/constraint.sdc
```

### Final results

| Metric | Result |
|---|---:|
| Synthesized standard cells | 29,231 |
| Synthesized cell area | 295,352 µm² |
| Die dimensions | ~812 × 812 µm |
| Clock constraint | 20 ns / 50 MHz |
| Final setup violations | 0 |
| Final hold violations | 0 |
| Max slew violations | 0 |
| Max capacitance violations | 0 |
| Max fanout violations | 0 |
| Timing-based Fmax estimate | 74.18 MHz |
| Setup clock skew | ~0.11 ns |
| Antenna violations | 0 |
| KLayout DRC | 0 violations |
| LVS | PASS |

The reported Fmax is a timing estimate for the implemented design and analyzed library corner. It is not a measured silicon operating frequency.

### Physical-design flow

```text
SystemVerilog RTL
       ↓
Elaboration / Synthesis
       ↓
Sky130HD Technology Mapping
       ↓
Floorplanning
       ↓
Placement
       ↓
Static Timing Analysis
       ↓
Clock Tree Synthesis
       ↓
Routing
       ↓
Parasitic Extraction
       ↓
Post-route STA
       ↓
DRC / LVS
       ↓
GDS
```

The final flow generated:

- GDS
- DEF
- SPEF
- SDC
- OpenDB database
- gate-level Verilog netlist

Detailed implementation results and retained reports are available in:

- [`docs/physical_design/sky130hd.md`](docs/physical_design/sky130hd.md)
- [`docs/physical_design/results.md`](docs/physical_design/results.md)

## Project Structure

```text
.
├── docs/
│   ├── physical_design/       # Sky130HD results, reports and layout images
│   └── ...                    # Architecture and verification documentation
│
├── dv/
│   ├── benchmarks/            # Performance benchmarks
│   ├── riscv-tests-repo/      # riscv-tests submodule
│   ├── rtl/                   # Verification-only RTL
│   ├── tb/                    # Verilator C++ testbench
│   └── tests/                 # Regression and differential tests
│
├── rtl/
│   ├── bus/                   # Bus wrapper
│   ├── core/
│   │   ├── decode/
│   │   ├── exec/
│   │   ├── fetch/
│   │   ├── mem/
│   │   ├── perf/
│   │   ├── pipeline/
│   │   └── sys/
│   └── include/
│
├── sim/
│   └── soc/                   # Simulation-only SoC and RAM
│
├── sw/                        # Startup code and linker script
│
├── syn/
│   ├── sky130hd/              # ORFS configuration and SDC constraints
│   └── yosys/                 # Generic synthesis flow
│
├── Dockerfile
└── Makefile
```

## Local Tool Requirements

The RTL verification flow uses:

- Verilator
- RISC-V GNU toolchain
- Spike
- Python 3
- Yosys

Physical implementation uses OpenROAD-flow-scripts and the Sky130HD platform.

Tool versions used for a particular implementation should be recorded with the corresponding results rather than assumed from this README.

## Useful Make Targets

```bash
make lint-all
make regression
make spike-regression
make verify
make benchmarks
make synth
```

Use:

```bash
make toolcheck
```

to inspect the locally configured Yosys and Verilator versions.

## Known Limitations

- Aether currently implements RV64IM rather than the complete RISC-V privileged architecture or additional ISA extensions.
- Physical implementation was performed as a standalone core, not a complete pad-ring/package-level SoC.
- The final power figure from OpenROAD is a tool-generated estimate without workload-derived switching activity.
- ORFS logical equivalence checking was not completed because the bundled Kepler Formal executable terminated with an illegal-instruction error in the WSL/Docker environment.
- The reported timing-based Fmax is not a silicon measurement.

## License

See [`LICENSE`](LICENSE).