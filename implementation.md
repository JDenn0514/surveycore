# Implementation: PR 2 — Replace raking oracle with survey::calibrate(calfun = "raking")

## Write surface

- `tests/testthat/test-calibration.R` — lines 631–719 (old test block replaced)
- `NEWS.md` — bullet added under `# surveycore 0.9.0 > ## New features`

## What was implemented

- Deleted the old test block (lines 631–716 of the original file) which used
  two sequential `survey::calibrate()` calls (`sv_cal1`, `sv_raked`) as the
  oracle and two `as_caldata()` elements (`cd1`, `cd2`).
- Replaced with a new test that uses a single `survey::calibrate(calfun = "raking")`
  call as the oracle, with a combined model matrix built via
  `model.matrix(~riagendr_f + age_group, nhanes_sub)`.
- The surveycore side uses a single `as_caldata()` element (`g = raked_wts / base_wts`)
  stored as `list(cd)` in `design@calibration`.
- Used `survey::rake()` only to obtain the converged IPF weights for computing
  `g`; the oracle SE comes exclusively from `survey::calibrate(calfun = "raking")`.
- Fixed two issues during development: (a) `survey::calibrate()` does not accept
  a raw matrix in `formula=` — changed to use the R formula `~riagendr_f + age_group`
  which matches the combined model matrix; (b) `nhanes_sub$wt_raked` was added
  to `nhanes_sub` after `sc_design` was constructed — corrected to assign to
  `sc_design@data$wt_raked` so `update_design()` finds the column.

## Task checklist

- [x] Old test block (referencing `sv_cal1`, `cd1`, `cd2`, `pop_gender`/`pop_age`
      as named vectors) removed from lines 631–716
- [x] New test `"calibration-adjusted SE from get_means() matches survey::calibrate(calfun = 'raking') oracle [raking, nhanes]"` inserted at the same location
- [x] Oracle uses `survey::calibrate(..., calfun = "raking")` — not two sequential calls
- [x] Single `as_caldata()` element stored at `design@calibration` as `list(cd)`
- [x] SE tolerance is `1e-8`
- [x] All 312 calibration tests pass (0 failures, 0 warnings, 0 skips)
- [x] NEWS.md bullet added

## Test result

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 312 ]
```

## Notes for tester

- The `survey::calibrate()` function does not accept a raw model matrix in
  `formula=`; it requires an R formula object. The combined matrix and the
  `population=` vector are both derived from `model.matrix(~riagendr_f + age_group)`,
  ensuring they are consistent.
- The `survey::rake()` call is still present in the test but only to obtain
  converged IPF weights for the `g` ratio — it does not contribute to the
  oracle SE.
