# Changelog: fix/detect-ordinal-all-na-numeric

**Branch:** `JDenn0514/corr_detect_ordinal-calls-an-all-na-integer-ordi`
**Status:** Complete
**Date:** 2026-09-02

## Summary

Fixes #209. `.corr_detect_ordinal()` gave two answers for the same data
depending on its storage type when every value was missing. The `is.integer`
branch counted distinct non-`NA` values without a zero-length guard:

```r
n_distinct <- length(unique(col[!is.na(col)]))  # 0 for an all-NA integer
if (n_distinct <= integer_cardinality_cutoff) { # 0 <= 10 is TRUE
  return("integer_ordinal")
}
```

The `is.double` branch guarded the same case and returned `continuous`. So
`get_corr(method = "polychoric")` returned `r = NA, n = 0` for an all-`NA`
integer and raised `surveycore_error_polychoric_requires_ordinal` for an
all-`NA` double. An empty column behaved the same way: `integer(0)` was
`integer_ordinal`, `numeric(0)` was `continuous`.

Pre-existing. The `is.integer` branch is untouched by #201, and
`archive/haven-labelled/spec-haven-labelled.md` §VI.4's classification table
records only the double row.

The issue offered two answers — make both return the `NA` row, or make both
raise. The user chose to raise. Three reasons:

- Ordinality of a bare numeric column is inferred from its observed values.
  A column with none shows no scale, so there is no evidence to infer from.
  A `factor` or `ordered` column declares its levels and needs no evidence,
  which is why an all-`NA` factor stays ordinal and keeps the `NA` row.
- A typed error is more informative than a silent `NA` row for a caller who
  did not expect an empty column.
- It keeps the #201 guard and its stated rationale intact. No existing
  expectation flips and no snapshot changes; the suite gains one snapshot.

`surveycore_error_polychoric_single_level_ordinal` (PC-4) is the condition an
all-`NA` ordinal column actually meets, and the issue asked why it does not
fire. It cannot: `.corr_latent_pair()` runs the PC-1 ordinal gate at step 2
and the `n_pair == 0` early return at step 5, both before
`.corr_estimate_thresholds()`. PC-4 is reachable only for a column with
exactly one *observed* level.

Parity was measured across all eight cells — method × pair partner ×
`na.rm`. An all-`NA` integer and an all-`NA` double now give identical
outcomes in every one:

| Pair | `polychoric` | `polyserial` |
|---|---|---|
| all-`NA` numeric + ordered factor | PC-1 | `r = NA, n = 0` |
| all-`NA` numeric + continuous | PC-1 | PC-2 |

The polychoric integer cell changed. The two polyserial integer cells swapped
with each other, because the classification the pair canonicalizes on moved.
No double cell moved, which is why `P-7` and its snapshot are untouched.

One shape stays out of scope. `get_corr(method = "polyserial", na.rm = FALSE)`
on an all-`NA` continuous side returns a spurious `rho` near `1` with a
boundary-rho warning, rather than `NA` or a typed error: the PC-15 gate
excludes `NA` by design, `pair_active` stays full under `na.rm = FALSE`, and
`.corr_weighted_standardize()` degenerates. It affects the all-`NA` double
identically, so it predates this change and is not part of #209.

## Files Modified

- `R/analysis-corr-latent.R` — zero-length guard in the `is.integer` branch
  of `.corr_detect_ordinal()`, returning `continuous` when the column holds
  no non-`NA` value; a comment on the `is.double` branch pointing at the same
  rule; the helper's header contract rewritten, since `integer_ordinal` now
  needs at least one distinct value and `continuous` now covers an empty
  `integer`
- `R/analysis-corr.R` and `man/get_corr.Rd` — `@param x` states the
  empty-column rule and the `factor` exception
- `plans/error-messages.md` — PC-1's condition text names the new rule. No new
  class, so no new row
- `tests/testthat/test-analysis-corr-latent-primitives.R` — four rows on the
  guard: empty `integer`, all-`NA` `integer`, integer/double parity for both
  shapes, and an all-`NA` `ordered` column staying `ordered`
- `tests/testthat/test-analysis-corr-latent.R` — `P-7b` (all-`NA` integer
  raises PC-1, dual pattern), `P-7c` (both storage types carry the same
  condition class), `P-7d` (an all-`NA` `ordered` column still returns the
  `NA` row), `Y-15` and `Y-16` (the two polyserial outcomes, each asserted
  against the all-`NA` double)
- `tests/testthat/_snaps/analysis-corr-latent.md` — one new snapshot, none
  changed
- `archive/haven-labelled/spec-haven-labelled.md` — a dated correction note
  under §VI.4 carrying the two rows, the rule behind them, and the two
  polyserial shifts. The shipped table is left as the record of what #201
  shipped
- `NEWS.md` — one Bug fixes bullet

## Changes

- Guard the `is.integer` branch of `.corr_detect_ordinal()` against a column
  with no non-`NA` value, so it agrees with the `is.double` branch
- Pin the classification in four primitive rows and the behaviour in five
  integration rows, each asserting the integer against the double rather than
  against a literal
- Record the correction in the archived spec table's successor note, in PC-1's
  condition text, in the helper's header contract, and in `@param x`
