# Sky130HD Physical Implementation

## Configuration

- Process/platform: Sky130HD
- Top module: `core_top`
- Flow: OpenROAD-flow-scripts
- HDL frontend: Slang/Yosys
- Clock constraint: 20 ns (50 MHz)
- Initial core utilization: 45%
- Input/output delay assumption: 20% of clock period
- Final slew repair margin: 20%
- Final capacitance repair margin: 20%

The ORFS configuration is stored in `syn/sky130hd/config.mk`.
Timing constraints are stored in `syn/sky130hd/constraint.sdc`.

## Initial synthesis issue

The original MULDIV unit used behavioral `*`, `/`, and `%` operators while
using counters to delay completion.

The counters made the interface multi-cycle, but the arithmetic itself remained
combinational after synthesis.

Initial Sky130HD synthesis produced:

- 87,490 standard cells
- 802,513 um^2 standard-cell area
- 9,051 full adders
- 7,571 half adders

The initial physical flow also exposed a large setup violation in the MULDIV
datapath, with approximately -202 ns worst negative slack at the 20 ns clock
constraint.

## MULDIV redesign

The behavioral arithmetic was replaced with:

- radix-2 iterative shift-and-add multiplication
- radix-2 restoring division
- registered intermediate state
- explicit handling of signed operations and RISC-V division corner cases

The updated unit was rechecked with the existing RTL verification and benchmark
flow before physical implementation was repeated.

After the redesign:

- standard-cell count: 29,231
- standard-cell area: 295,352 um^2
- full adders: 6
- half adders: 607
- synthesis structural problems: 0

This reduced synthesized cell area by approximately 63%.

## Floorplan

The initial floorplan used a 45% core-utilization target.

Result:

- die: approximately 812 x 812 um
- core area: 654,027 um^2
- logic area before tapcell insertion: 295,352 um^2
- effective initial utilization: approximately 45.2%
- no macros

Tapcell insertion increased utilization to approximately 47%.

## Placement

Detailed placement completed with:

- 0 overlap violations
- 0 row-alignment violations
- 0 site-alignment violations
- 0 edge-spacing/padding violations
- approximately 49% utilization

Post-placement timing at the 20 ns clock constraint:

- setup violations: 0
- hold violations: 0
- worst setup slack: approximately +7.26 ns
- worst hold slack: approximately +0.38 ns

## Clock Tree Synthesis

CTS created the physical clock distribution network for `core_clk`.

Key results:

- 550 clock buffers created
- approximately four clock buffers per sink path
- setup violations after CTS: 0
- hold violations after CTS: 0

The final implementation reports approximately 0.11 ns setup clock skew.

## Routing

Detailed routing initially produced many temporary spacing and short violations.
TritonRoute iteratively ripped up and rerouted affected nets until the final
routing violation count reached zero.

The routed design also completed antenna checking with zero antenna violations.

## Post-route electrical repair

Final extracted parasitics initially exposed:

- 16 maximum-slew violations
- 6 maximum-capacitance violations

These violations were not present before routing.

The ORFS `repair_design` stage was given:

- `SLEW_MARGIN = 20`
- `CAP_MARGIN = 20`

The routing and final extraction stages were repeated.

Final result:

- maximum-slew violations: 0
- maximum-capacitance violations: 0
- maximum-fanout violations: 0
- setup violations: 0
- hold violations: 0

## Final timing

At the 20 ns (50 MHz) constraint:

- setup violations: 0
- hold violations: 0
- worst setup slack: approximately +6.5 ns
- reported minimum clock period: 13.48 ns
- reported timing-based Fmax estimate: 74.18 MHz
- setup clock skew: approximately 0.11 ns

The 74.18 MHz value is a timing estimate for this implementation and analysis
corner. It is not a measured silicon operating frequency.

## Physical verification

Final checks:

- detailed-routing violations: 0
- antenna violations: 0
- KLayout DRC violations: 0
- LVS: PASS (`Netlists match`)

## Power estimate

The final OpenROAD report gives approximately:

- sequential: 10.9 mW
- combinational: 5.43 mW
- clock: 10.8 mW
- total: 27.1 mW

This is a tool-generated power estimate. No workload-derived switching activity
was supplied, so it should not be interpreted as measured workload power.

## Known limitation

ORFS logical equivalence checking was disabled because the bundled Kepler Formal
binary terminated with an illegal-instruction error in the WSL/Docker
environment.

The project therefore does not claim completed LEC/formal-equivalence signoff.
