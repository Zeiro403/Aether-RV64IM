# Aether Sky130HD Results

## Implementation

| Metric | Result |
|---|---:|
| Process / library | Sky130HD |
| Top module | `core_top` |
| Clock constraint | 20 ns (50 MHz) |
| Initial core utilization | 45% |
| Die dimensions | ~812 x 812 um |
| Synthesized standard-cell count | 29,231 |
| Synthesized standard-cell area | 295,352 um^2 |

## Timing

| Metric | Result |
|---|---:|
| Setup violations | 0 |
| Hold violations | 0 |
| Final worst setup slack | ~+6.5 ns |
| Minimum reported period | 13.48 ns |
| Timing-based Fmax estimate | 74.18 MHz |
| Setup clock skew | ~0.11 ns |

## Electrical checks

| Check | Result |
|---|---:|
| Max slew violations | 0 |
| Max capacitance violations | 0 |
| Max fanout violations | 0 |
| Antenna violations | 0 |

## Physical verification

| Check | Result |
|---|---:|
| Detailed-routing violations | 0 |
| KLayout DRC | 0 violations |
| LVS | PASS — netlists match |

## Power estimate

| Component | Estimated power |
|---|---:|
| Sequential | 10.9 mW |
| Combinational | 5.43 mW |
| Clock | 10.8 mW |
| Total | 27.1 mW |

Power is a tool-generated estimate without workload-derived switching activity.

## MULDIV redesign impact

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Standard cells | 87,490 | 29,231 | -66.6% |
| Cell area | 802,513 um^2 | 295,352 um^2 | -63.2% |
| Full adders | 9,051 | 6 | -99.9% |
| Half adders | 7,571 | 607 | -92.0% |
| 50 MHz timing | ~-202 ns WNS | Timing closed | — |

The original MULDIV interface delayed completion using counters, but arithmetic
was still implemented with behavioral `*`, `/`, and `%` operators. Synthesis
therefore inferred large combinational arithmetic networks.

The replacement uses iterative shift-and-add multiplication and restoring
division with registered intermediate state.

## Limitation

ORFS logical equivalence checking was not completed because the bundled Kepler
Formal executable terminated with an illegal-instruction error in the
WSL/Docker environment.
