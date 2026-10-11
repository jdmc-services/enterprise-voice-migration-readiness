# Illustrative benefits and cost model

Every amount is a synthetic USD assumption, not a quote, realized result, or promise. 20,000 number identifiers are **not** 20,000 billable seats. The scenario independently assumes 12,000 comparable billable seats. Confirm actual units and bundle contents before applying this model.

[data/cost-assumptions.csv](../data/cost-assumptions.csv) is the input record. Baseline and target monthly rates are $18 and $16 per seat for comparable scope. Both exclude taxes and common pass-through items; differences in those items require an added scenario. Transition overlap is included once below.

| Calculation | Formula | Illustrative value |
| --- | --- | ---: |
| Baseline recurring annual cost | 12,000 × $18 × 12 | $2,592,000 |
| Target recurring annual cost | 12,000 × $16 × 12 | $2,304,000 |
| Gross annual recurring difference | Baseline − target | $288,000 |
| One-time implementation | Assumed | $210,000 |
| Transition/dual-service overlap | Assumed once | $90,000 |
| Combined transition cost | $210,000 + $90,000 | $300,000 |
| Steady-state first 12 months net, including transition cost | $288,000 − $300,000 | −$12,000 |
| Simple payback after steady-state savings begin | $300,000 / $24,000 monthly | 12.5 months |

The first-12-month calculation assumes a full year of steady-state service, rather than the first project calendar year. Staged rollout can delay savings; payback from project start may be longer. Financing, tax, inflation and discounting are excluded. A target rate of $18 gives zero recurring savings and no finite payback; $20 increases annual recurring cost by $288,000. Lower prices alone do not satisfy readiness gates.

**Do not add unlike benefits:** staff time freed is capacity unless an actual budget reduction is supported; avoided future spend is a separate counterfactual; reduced incident exposure is an uncertain risk benefit. None is added to the cash difference above. Measure service quality, support workload and user experience against an agreed baseline rather than asserting improvement.
