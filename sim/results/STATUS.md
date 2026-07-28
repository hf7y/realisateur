# ecosim -- rolling status

updated: 2026-07-28 03:03:29
generations complete: 50

## latest generation: 549 (regime: clone:failOK_tight_quota)

| arm | paradigm | undetected | wasted% | drain | trust |
|---|---|---|---|---|---|
| A_baseline | control | 688 | 0.00 | 0.096 | 1.00 |
| B_more_sensors | P1_ashby | 688 | 0.00 | 0.096 | 1.00 |
| B2_decorrelated | P1_ashby | 247 | 0.00 | 0.105 | 1.00 |
| C_blind_symbol | P1_ashby | 70 | 0.00 | 0.111 | 1.00 |
| D_both | P1_ashby | 70 | 0.00 | 0.111 | 1.00 |
| C_hostile | P1_ashby | 151 | 0.00 | 0.112 | 1.00 |
| P_devices | P2_perrow | 689 | 0.42 | 0.097 | 0.61 |
| P_slack | P2_perrow | 953 | 0.00 | 0.096 | 1.00 |
| P_slack_devices | P2_perrow | 985 | 0.47 | 0.093 | 0.62 |
| H_local | P3_hayek | 154 | 0.00 | 0.111 | 1.00 |
| H_local_blind | P3_hayek | 5 | 0.00 | 0.112 | 1.00 |

## hypothesis verdicts (across all regimes)

| id | paradigm | SUPPORTED | FALSIFIED | INCONCL | claim |
|---|---|---|---|---|---|
| H1 | P1_ashby | 40 | 10 | 0 | Ashby's Law binds at the SENSOR, not only the effector. Adding sensor ... |
| H1b | P1_ashby | 50 | 0 | 0 | The BLIND advantage is not an artifact of assuming a BLIND report alwa... |
| H2 | P1_ashby | 0 | 0 | 50 | More sensors, reconciled, does NOT help when blind spots are correlate... |
| H3 | P2_perrow | 50 | 0 | 0 | Perrow's corollary -- that adding safety devices to an interactively c... |
| H4 | P2_perrow | 0 | 50 | 0 | Perrow's actual prescription is a COUPLING intervention, not a complex... |
| H5 | P3_hayek | 15 | 30 | 5 | Hayek's structural claim -- the centre is missing an input that cannot... |
| H6 | P3_hayek | 50 | 0 | 0 | Decentralisation and null-discrimination are COMPLEMENTS, not substitu... |

Robustness reading: a hypothesis is only credible if it holds across REGIMES, not generations. Repeated SUPPORTED in one regime is one result measured many times.