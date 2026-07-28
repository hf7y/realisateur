# ecosim -- rolling status

updated: 2026-07-28 01:40:15
generations complete: 2

## latest generation: 901 (regime: smoke:high_break)

| arm | paradigm | undetected | wasted% | drain | trust |
|---|---|---|---|---|---|
| A_baseline | control | 822 | 0.14 | 0.193 | 0.89 |
| B_more_sensors | P1_ashby | 822 | 0.14 | 0.193 | 0.89 |
| B2_decorrelated | P1_ashby | 898 | 0.47 | 0.215 | 0.43 |
| C_blind_symbol | P1_ashby | 536 | 0.00 | 0.213 | 1.00 |
| D_both | P1_ashby | 536 | 0.00 | 0.213 | 1.00 |
| C_hostile | P1_ashby | 582 | 0.00 | 0.216 | 1.00 |
| P_devices | P2_perrow | 824 | 0.30 | 0.183 | 0.72 |
| P_slack | P2_perrow | 1088 | 0.21 | 0.138 | 0.86 |
| P_slack_devices | P2_perrow | 1001 | 0.35 | 0.138 | 0.68 |
| H_local | P3_hayek | 249 | 0.24 | 0.215 | 0.72 |
| H_local_blind | P3_hayek | 98 | 0.00 | 0.223 | 1.00 |

## hypothesis verdicts (across all regimes)

| id | paradigm | SUPPORTED | FALSIFIED | INCONCL | claim |
|---|---|---|---|---|---|
| H1 | P1_ashby | 2 | 0 | 0 | Ashby's Law binds at the SENSOR, not only the effector. Adding sensor ... |
| H1b | P1_ashby | 2 | 0 | 0 | The BLIND advantage is not an artifact of assuming a BLIND report alwa... |
| H2 | P1_ashby | 0 | 0 | 2 | More sensors, reconciled, does NOT help when blind spots are correlate... |
| H3 | P2_perrow | 2 | 0 | 0 | Perrow's corollary -- that adding safety devices to an interactively c... |
| H4 | P2_perrow | 0 | 2 | 0 | Perrow's actual prescription is a COUPLING intervention, not a complex... |
| H5 | P3_hayek | 1 | 1 | 0 | Hayek's structural claim -- the centre is missing an input that cannot... |
| H6 | P3_hayek | 2 | 0 | 0 | Decentralisation and null-discrimination are COMPLEMENTS, not substitu... |

Robustness reading: a hypothesis is only credible if it holds across REGIMES, not generations. Repeated SUPPORTED in one regime is one result measured many times.