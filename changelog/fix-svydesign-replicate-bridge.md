# Changelog: fix/svydesign-replicate-bridge

**Branches:** `fix/svydesign-replicate-bridge`, `fix/svydesign-replicate-foldin`, `fix/svydesign-replicate-guards`, `fix/svydesign-replicate-fpc`, `fix/svydesign-replicate-fay`
**Status:** Complete
**Date:** 2026-09-08
**PRs:** #239, #241, #247, #249, #250
**Issues:** #197, #198

## Summary

The two replicate conversion routes in `R/methods-conversion.R` both carried
defects that produced a wrong number in silence. Five pull requests fixed them.

**The import route lost the replicate weights entirely.** It read the column
names straight off `x$repweights`, and `survey::as.svrepdesign()` never names
the columns of the matrix it builds — for any replicate type, on either
`compress` setting. So `colnames()` returned a length-0 vector, the route
stored zero replicate column names, wrote no columns, and raised nothing. The
converted design carried no replicate weights at all. The loss surfaced much
later, during analysis, as `surveycore_error_all_replicates_na` pointing at the
analysis call rather than at the conversion.

**The import route also ignored `x$combined.weights`.** When that field is
`FALSE` the matrix holds replication factors rather than finished weights.
Storing the factors unchanged left the point estimate correct — it reads
`pweights`, not the replicate columns — and moved the standard error. Measured
across five designs: 35% too small on the `gss_2024` bootstrap design in the
issue, 8% too small on a 40-row JKn design, 4% too large on a 32-row JKn
design, 10% too large on a 32-row BRR design, 0.1% too large on an unclustered
JK1 design. Same replicate type, different draw, opposite direction — because a
weighted mean is invariant to a constant rescaling of its weights, so the error
depends on how the replication-factor pattern correlates with the base weights,
not on a shrinkage. Nothing warned.

**The export route could not carry an FPC at all.**
`survey::svrepdesign()` treats the FPC as one multiplier per replicate and
checks `length(fpc)` against `length(rscales)`, which is `R`. surveycore's
`@variables$fpc` names a column of `@data`, of length `n`. The two agree only
when `n == R`, so any replicate design carrying an FPC failed with survey's own
`fpc is wrong length`, and `as_svydesign(x)` takes only `x`, so the caller had
no way around it.

**The export route could not carry a Fay design at all.**
`svrepdesign.default` contains
`if (type == "Fay" && is.null(rho)) stop("With type='Fay' you must supply the correct rho")`,
and the route passed no `rho`.

## Changes

### Import — `from_svydesign()` on a `svyrep.design`

- Expand `x$repweights` with `as.matrix()` before reading it, which handles
  survey's default `compress = TRUE` storage form, and strip the `"repweights"`
  class the result carries
- Generate replicate column names when `survey` supplies none, on the
  `..surveycore_repwt_N..` pattern, zero-padded so they sort in replicate order
- Write one column per replicate into the design data on every conversion, with
  no branch — a name in `colnames(x$repweights)` can also name a column of
  `x$variables` holding unrelated values, because `survey::svrepdesign()`
  cross-checks the two for neither name nor value
- Multiply each replicate column by `x$pweights` when `x$combined.weights` is
  `FALSE`, so the returned design carries finished weights. Silent by design:
  both forms describe the same design, the product is exact, and `survey`
  performs the same multiplication itself in the analysis branch of
  `weights.svyrep.design`
- Search for the base weight column BEFORE writing the replicate block, so the
  search cannot name a replicate column that happens to hold exactly the base
  weights
- Refuse four unusable sources, each with a typed condition:
  `surveycore_error_replicate_type_unsupported` for a type outside the nine
  `as_survey_replicate()` accepts (`survey::as.svrepdesign()` also produces
  `"subbootstrap"` and `"mrbbootstrap"`), `surveycore_error_empty_data` for a
  zero-row design, `surveycore_error_repweights_names_lost` when no usable
  distinct name per column can be resolved, and
  `surveycore_error_repwt_name_collision` when a generated name already names a
  column

### Export — `as_svydesign()` on a `survey_replicate`

- Stop passing `fpc` and `fpctype` to `survey::svrepdesign()`, and raise
  `surveycore_warning_replicate_fpc_dropped` naming the dropped column. The
  drop rather than a translation is deliberate: the mismatch is semantic, not
  just a length problem, and surveycore's replicate variance never reads the
  FPC — `R/variance-replicate.R` holds no reference to it — so the exported
  design reproduces surveycore's own standard errors exactly, while a
  translated FPC would scale every replicate scale and return numbers
  surveycore does not produce. `survey`'s own `as.svrepdesign()` warns and
  drops for the same reason
- Recover Fay's shrinkage factor from the recorded scale, inverting survey's
  own formula: it computes a Fay scale as `1 / (n_rep * (1 - rho)^2)`, so
  `rho <- 1 - sqrt(1 / (scale * n_rep))` returns it. A design built with
  `fay.rho = 0.3` recovers 0.3 exactly and rebuilds at the source's own scale
  and standard error
- Refuse a Fay design whose recorded scale yields no usable factor, with
  `surveycore_error_fay_rho_unrecoverable`. Both arms are reachable: an
  out-of-range scale from `as_survey_replicate()`, which validates no scale
  value, and no recorded scale at all from the bare exported
  `survey_replicate()` constructor, which is what issue #198's own reproduction
  uses
- Refuse a design naming no replicate weight column, with
  `surveycore_error_repweights_empty`, rather than letting survey fail with an
  untyped `missing value where TRUE/FALSE needed` from inside its own
  `combined.weights` heuristic

### Documentation

- The `from_svydesign()` roxygen block said the replicate weights "are
  preserved", which the fold-in makes false. It now states that the conversion
  transforms them on a factor-form source, that a generated column block is
  written when the source names no replicate column, and that
  `@variables$repweights` names those columns in replicate order

## Files Modified

- `R/methods-conversion.R` — both replicate routes; one new internal helper,
  `.repwt_col_names()`
- `man/from_svydesign.Rd` — regenerated by `devtools::document()`
- `plans/error-messages.md` — new dated section with rows CB-1 to CB-5, and
  extended trigger notes on rows 2 and 16
- `tests/testthat/test-conversion.R` — 58 new blocks
- `tests/testthat/_snaps/conversion.md` — new file; eight snapshots

## Verification

- Package line coverage rose at every pull request: 96.19% → 96.24%.
  `R/methods-conversion.R` ends at 99.75%, its one uncovered line pre-existing
  and already `# nocov`-marked
- `FAIL 0` throughout; the suite's 256 warnings are the pre-existing AAPOR
  small-cell warnings and did not rise
- `R CMD check --as-cran`: 2 NOTEs, both pre-existing
- All 12 observable properties and all 13 quality gates in the spec hold
- Planning documents, per-PR artifacts and 19 decisions:
  `archive/svydesign-replicate-bridge/`
