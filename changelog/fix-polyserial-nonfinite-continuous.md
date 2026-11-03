# Changelog: fix/polyserial-nonfinite-continuous

**Branch:** `JDenn0514/get_corr-method-polyserial-lets-an-untyped-base`
**Status:** Complete
**Date:** 2026-09-02

## Summary

Fixes #208. `get_corr(method = "polyserial")` let an untyped base R error
escape when the continuous side of a pair carried `Inf` or `-Inf`. The
infinite value entered the weighted moment sums, so `mean_w`, `var_w` and
`sd_w` were all `NaN`, `NaN > 0` evaluated `NA`, and the `if (sd_w > 0)` in
`.corr_weighted_standardize()` aborted:

```
Error: missing value where TRUE/FALSE needed
```

`class(cnd)` was `simpleError`, `error`, `condition`. No class, no bullet, no
column name — against the `class=` rule in `.claude/rules/code-style.md`.

Pre-existing, and not attributable to #201: the `is.finite()` guard in
`.corr_detect_ordinal()` keeps an `Inf`-carrying column classified
`continuous`, so the pair is ordinal + continuous before and after that
change, on the identical code path.

The issue offered two answers: guard the `if`, or refuse at the gate. The
user chose the gate. Three reasons:

- An infinite value makes every moment of the continuous side undefined.
  There is no estimate to return, so the call should name the column and
  stop.
- The guard-only route lands in PC-6, whose message points at "extreme
  weight skew, sparse cells, or degenerate ordinal coding" and never
  mentions `Inf`. That abort is also marked `# nocov` as unreachable.
- `polychoric` already refuses an `Inf`-carrying column, at PC-1. The
  polyserial gate makes the two methods agree.

The check reads the active-domain rows only, so `filter()` remains a way to
drop the offending row. That matches PC-4, PC-5 and PC-10, which all scope
their degeneracy checks the same way.

`NA` and `NaN` need no gate. `.corr_weighted_standardize()` drops them
through its `!is.na()` filter, in both `na.rm` modes — measured on both.
The ordinal side needs no gate either: an `Inf`-carrying `double`
classifies as `continuous`, and `factor` / `ordered` / `integer` cannot
hold an infinite value.

## Files Modified

- `R/analysis-corr-latent.R` — new PC-15 gate in `.corr_latent_pair()`,
  placed after the all-`NA` early return and before the MLE, raising
  `surveycore_error_polyserial_nonfinite_continuous` with the column name
  and the count of infinite values; `is.finite(sd_w) && sd_w > 0` guard in
  `.corr_weighted_standardize()`, so a non-finite SD reaches the
  degenerate-SD branch its own comment always intended; renumbered the step
  comments after the insertion and extended the helper's header contract
- `plans/error-messages.md` — new row PC-15. The PC block carries no rows in
  that file's test-mapping table, so no mapping row was added
- `tests/testthat/test-analysis-corr-latent.R` — new Category 16 with nine
  rows and the `.pc15_design()` fixture
- `tests/testthat/test-analysis-corr-latent-primitives.R` — three rows on the
  guard, so it needs no `# nocov`
- `tests/testthat/_snaps/analysis-corr-latent.md` — two new snapshots
- `NEWS.md` — one Bug fixes bullet

## Changes

- Refuse a non-finite continuous side at the gate, with a typed class, the
  column name and the count, before any estimation work
- Guard the `if` in `.corr_weighted_standardize()` so a non-finite SD yields
  `NaN` z values instead of aborting the comparison
- Pin the behaviour in nine integration rows: `Inf` on a whole-valued double
  and on a genuine `rnorm` column (both dual pattern), both signs in one
  column, the `Inf` row filtered out of the domain (succeeds, `n = 299`),
  the `Inf` row the domain keeps (refuses), `NaN` in both `na.rm` modes
  (unaffected), `polychoric` and `pearson` unchanged, and the replicate path
- Add the PC-15 row to `plans/error-messages.md` before using the class in
  code, per `.claude/rules/code-style.md`
