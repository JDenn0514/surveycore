# Comprehension — svydesign-replicate-bridge

Covers issues #197 (`from_svydesign()`) and #198 (`as_svydesign()`). Both
defects sit in `R/methods-conversion.R`, about 150 lines apart, and both come
from reading `x$repweights` or `@variables$fpc` without checking what the shape
means on the other side of the bridge.

Every measurement in this file was taken in this run against survey 4.5 on
this worktree. §Measurement log lists how each one was taken.

## Problem

surveycore and the `survey` package store a replicate design differently.
surveycore names replicate weight columns inside `@data` and treats the named
columns as finished weights — weights already on the population scale, ready
to use as they stand. `survey` stores a numeric matrix beside the data, may
compress it, may leave its columns unnamed, and records in
`x$combined.weights` whether the matrix holds finished weights or bare
replication factors that still need the base weight folded in. The two
conversion routes ignore three of those differences, so a replicate design
does not survive the crossing: columns vanish in one direction, the standard
error moves in another, and a design carrying a finite population correction
fails outright in the third.

## Formulas

### F1 — replication factors to finished weights (#197 mechanism 2)

`survey` records which form its matrix holds:

```
combined.weights = TRUE   ->  R[i, r] is already a finished weight
combined.weights = FALSE  ->  R[i, r] is a replication factor
```

surveycore has no equivalent field, so the stored columns must always be
finished weights. The conversion therefore folds the base weight in when, and
only when, `survey` reports the factor form:

```
w[i, r] = R[i, r] * p[i]      when combined.weights is FALSE
w[i, r] = R[i, r]             when combined.weights is TRUE
```

| Symbol | Meaning | Bound to |
|---|---|---|
| `R[i, r]` | value in row i, replicate r of survey's matrix | `as.matrix(x$repweights)` |
| `p[i]` | base sampling weight for row i | `x$pweights` |
| `w[i, r]` | finished replicate weight surveycore stores | column r of the generated block written into `@data` |
| `R` | replicate count | `ncol(as.matrix(x$repweights))` |
| `n` | row count | `nrow(as.data.frame(x$variables))` |

The product is row-wise: `p` has length `n` and multiplies down each column.
`R[i, r] * p[i]` is what `as.matrix(x$repweights) * x$pweights` computes in R,
because a matrix times a length-`n` vector recycles down columns. Zeros in
`R` stay zero, which is correct — JK1 and JKn delete a whole PSU per replicate
and a deleted row genuinely carries weight 0 in that replicate.

Measured on a 40-row JKn design: folding the base weight in reproduces
`survey::svymean()`'s SE of 0.1775 exactly. Storing the factors unchanged
gives 0.1633.

### F2 — the two FPC shapes (#198)

`survey::svrepdesign()` treats the FPC as a per-replicate multiplier on the
replicate scales. From `survey:::svrepdesign.default`, survey 4.5:

```r
if (type %in% c("BRR", "Fay", "JK2", "ACS", "successive-difference"))
  stop("fpc not available for this type")
if (type %in% "bootstrap")
  stop("Separate fpc not needed for bootstrap")
if (length(fpc) != length(rscales)) stop("fpc is wrong length")
if (any(fpc > 1) || any(fpc < 0))  stop("Illegal fpc value")
fpc <- switch(fpctype, correction = fpc, fraction = 1 - fpc)
rscales <- rscales * fpc
```

So `length(fpc)` must equal `length(rscales)`, which is `R`. surveycore's
`@variables$fpc` names a column of `@data`, which has length `n`. The two
lengths coincide only when `n` equals `R`, so the failure is effectively
unconditional.

The mismatch is semantic, not only a length problem. In `svrepdesign()` the
FPC scales replicate variance contributions, one value per replicate. In
`svydesign()` it is a per-row population size or sampling fraction. Reshaping
the column to length `R` would not make it the right quantity.

## Gotchas

- **Unnamed replicate columns, both compress values.**
  `survey::as.svrepdesign()` never names the columns of the matrix it builds.
  `length(colnames(x$repweights))` is 0 for `compress = TRUE` and for
  `compress = FALSE`. `colnames()` is not a safe source of column names, and
  the current code has no fallback.

- **`repweights_compressed` is a list, not a matrix.** With survey's default
  `compress = TRUE`, `x$repweights` has class `repweights_compressed` and is a
  list with elements `weights` and `index`: one row per distinct weight
  pattern plus an index that maps each data row onto a pattern. `dim()` still
  reports the full `n x R`, so a `dim()` check alone will not tell the two
  forms apart. `as.matrix()` expands it to the full `n x R` matrix. Any
  arithmetic on `x$repweights` must expand first.

- **`as.matrix()` dispatch works under `requireNamespace()`.** `survey` sits in
  `Suggests`, so the conversion routes guard on
  `requireNamespace("survey", quietly = TRUE)` rather than attaching the
  package. That guard loads survey's namespace, which registers
  `as.matrix.repweights_compressed`, so plain `as.matrix()` dispatches
  correctly. Verified in this run. No `survey::` prefix is needed, and none is
  available, because the method is not exported.

- **`as.svrepdesign()` always reports the factor form.** `combined.weights` is
  `FALSE` for every type measured — bootstrap, JK1, JKn. Factor-form input is
  the ordinary case coming out of survey, not an exotic one, so the fold-in
  path is the path nearly every real conversion takes.

- **Mechanism 2 moves the standard error by an amount and in a direction that
  both depend on the design.** The point estimate is untouched: it reads
  `pweights`, not the replicate columns. The standard error changes, but not
  by a fixed factor and not always downward. Measured across five designs in
  this run:

  | Design | Correct SE | Buggy SE | Error |
  |---|---|---|---|
  | `gss_2024` bootstrap R=50 (issue #197) | 0.428678 | 0.279983 | 35% too small |
  | JKn, 40 rows | 0.177500 | 0.163300 | 8% too small |
  | JKn, 32 rows | 0.176645 | 0.183755 | 4% too large |
  | BRR, 32 rows | 0.184410 | 0.201942 | 10% too large |
  | JK1, no clustering | 0.190136 | 0.190269 | 0.1% too large |

  Same replicate type, different draw, opposite direction. The reason is that a
  weighted mean is invariant to a constant rescaling of its weights, so the
  defect is not a shrinkage. It depends on how the replication-factor pattern
  correlates with the base weights: where the base weights barely vary the
  error nearly vanishes, and where they vary a lot it is large in either
  direction.

  This retires the claim that the defect "fails in the direction that hides
  it". That holds for the `gss_2024` case in issue #197 and not for the defect
  in general. Nothing may assert a direction or a ratio; the only sound
  assertion is parity against `survey`.

- **Mechanism 1 raises nothing at conversion time.** The loss surfaces later as
  `surveycore_error_all_replicates_na` from `.svy_rep_var()`, which points at
  the analysis call rather than the conversion.

- **`as.matrix()` does not return a plain matrix.**
  `survey::svrepdesign()` puts the class `"repweights"` on the object it
  stores, and `as.matrix()` keeps it: for an uncompressed source,
  `class(as.matrix(x$repweights))` is `"repweights"`, not
  `c("matrix", "array")`. `dim()`, `ncol()`, `colnames()` and `[ , j]` all
  still work, but `is.matrix()` returns `FALSE` and `as.data.frame()` collapses
  the whole matrix into a single column. Arithmetic keeps the class. Strip it
  with `unclass()` once, at expansion, and every later step works on a plain
  matrix.

- **surveycore's replicate variance never reads the FPC.**
  `R/variance-replicate.R` contains no reference to `fpc`, and
  `.get_design_vars_flat()` in `R/utils.R` omits `fpc` from the design columns
  it reports for `survey_replicate` while including it for `survey_taylor`. On
  a replicate design the FPC is recorded and printed but takes no part in any
  surveycore number. This is the fact that settles D3 — see `decisions.md`.

- **Zero replicate weights are legal.** The `survey_replicate` validator checks
  that each replicate column is numeric; it does not require positive values.
  Only the base weight column must be positive. JK1 and JKn produce genuine
  zeros, so neither the fold-in nor the column writing may treat a zero as
  missing or invalid.

- **Generated names can collide.** Writing a replicate block into `@data` adds
  `R` new columns. Their names must not overwrite a user column. surveycore
  already has a convention for this in `..surveycore_wt..`, the internal name
  used when a weight column has to be manufactured.

## Reference mapping

- `survey:::svrepdesign.default`, survey 4.5, `fpc` block -> the FPC on this
  route is per-replicate and length-checked against `rscales`; six of survey's
  nine types reject an FPC outright. Only `JK1`, `JKn` and `other` accept one.
- `survey:::svrepdesign.default` formals -> `combined.weights` defaults to
  `TRUE`. `.as_svydesign_replicate()` passes no value, so the exported design
  declares finished weights, which is the correct declaration for surveycore's
  stored columns. Confirmed by #198's own measurement: finished-weight columns
  match `survey::svymean()` exactly through the bridge as it stands. No change
  is needed to that argument.
- `survey::as.svrepdesign()` output -> unnamed matrix columns and
  `combined.weights = FALSE` for every measured type.
- `survey:::as.matrix.repweights_compressed` -> the supported way to expand a
  compressed matrix.
- `weights.svyrep.design`, the `analysis` branch -> `combined.weights` is a
  live flag, read at call time, not documentation:
  `if (object$combined.weights) as.matrix(object$repweights) else as.matrix(object$repweights) * object$pweights`.
  So declaring `combined.weights = TRUE` for a matrix that already holds
  finished weights is the flag's intended value for that data shape. The
  export route's silence on the argument is correct, not merely convenient.
- `survey:::as.svrepdesign.default`, the Fay and BRR branch ->
  `warning("Finite population correction dropped in conversion")`. `survey`
  itself uses warn-and-drop for an FPC it cannot represent on a replicate
  design. D3 repeats a pattern survey already applies on its own conversion
  route.
- `survey:::svrepdesign.default` return list ->
  `list(type=, scale=, rscales=, rho=, call=, combined.weights=)`. The raw
  `fpc` value is never stored; only its applied effect on `rscales` survives.
  So the import route's `fpc = NULL` is not a choice — a `svyrep.design` has no
  FPC field to read.
- `survey:::svrepdesign.default` scale computation -> for Fay,
  `scale <- 1/(ncol(repweights) * (1 - rho)^2)`; for BRR,
  `scale <- 1/ncol(repweights)`. BRR's scale has no free parameter and
  reproduces exactly from any source. Fay's depends on `rho`, which
  `survey_replicate` cannot store. This asymmetry is why the Fay gap is
  Fay-only and BRR is unaffected.
- `plans/error-messages.md` row 89,
  `surveycore_warning_fpc_partial_stages` -> a second precedent for a
  `surveycore_warning_*` class raised over an FPC that cannot be represented
  as given.
- `R/variance-replicate.R:51-52` comment -> records the convention the
  arithmetic already assumes: "Replicate weights are full survey weights
  (surveycore always uses the combined.weights = TRUE mode)". F1 makes the
  conversion honour a convention the variance code already depends on.
- `plans/error-messages.md` row 62,
  `surveycore_warning_twophase_method_unknown` -> precedent for a
  `surveycore_warning_*` class raised by a conversion route when a design
  detail cannot cross intact.
- `plans/error-messages.md` row DF-7,
  `surveycore_error_all_replicates_na` -> the downstream error that mechanism 1
  currently surfaces instead of a conversion-time diagnosis.

## Assumptions

- **`x$pweights` is the base weight for every row.** F1 relies on it. survey
  populates it in `svrepdesign()` and in `as.svrepdesign()` for every type.
- **`ncol(as.matrix(x$repweights))` equals `length(x$rscales)`.** surveycore's
  `as_survey_replicate()` enforces the equivalent through
  `surveycore_error_rscales_length`, so a mismatch arriving from survey is
  caught by the constructor the conversion calls.
- **Round-trip parity is the correctness standard.** `from_svydesign()`
  followed by analysis must reproduce what `survey` reports on the original
  design. This holds only if the conversion changes no quantity that enters
  variance — which is why the FPC must be dropped rather than translated, since
  surveycore would ignore it but the exported survey design would not.
- **The row order of `@data` matches the row order of the replicate matrix.**
  `as.data.frame(x$variables)` and `x$pweights` share survey's row order, and
  the conversion writes columns without reordering.

## Measurement log

Run in this worktree against survey 4.5.

| Claim | How it was measured |
|---|---|
| `length(colnames(x$repweights))` is 0 for both compress values | `as.svrepdesign(tay, type = "bootstrap", replicates = 20, compress = TRUE)` and the same with `FALSE`, then `length(colnames(.))` |
| `repweights_compressed` is a list with `weights` and `index`; `dim()` reports full size | `class()`, `is.list()`, `names()`, `dim()` on the same objects |
| `as.matrix()` expands to `n x R` under `requireNamespace()` only | fresh session, `requireNamespace("survey")`, then `as.matrix(b$repweights)` |
| `combined.weights` is `FALSE` for bootstrap, JK1 and JKn | `$combined.weights` on each |
| Folding `pweights` in reproduces survey's SE; omitting it does not | 40-row JKn design: `svymean()` gives 0.1775; rebuilt with finished weights 0.1775; rebuilt with factors 0.1633 |
| The size and the sign of mechanism 2's error both depend on the design | five designs rebuilt twice each, finished against factor columns, `svymean()` on both; the table in §Gotchas |
| `as.matrix(x$repweights)` keeps the class `"repweights"` | `class(as.matrix(src$repweights))` on an uncompressed `as.svrepdesign()` object; and `as.data.frame()` on the result yields one column, not `R` |
| `survey` stores Fay's `rho` and `survey_replicate` has no key for it | `as.svrepdesign(tay, type = "Fay", fay.rho = 0.3)` gives `rho = 0.3` and `"rho" %in% names(design)` `TRUE`; `type = "BRR"` gives `rho = 0`; `grep -n "rho" R/core-classes.R` returns nothing. Both BRR and Fay need an even PSU count per stratum, so the design for this measurement was 4 strata of 4 PSUs |
| `combined.weights` is read at call time | the `analysis` branch of `weights.svyrep.design`, quoted in §Reference mapping |
| `survey` itself warns and drops an FPC it cannot represent | the Fay and BRR branch of `as.svrepdesign.default`, quoted in §Reference mapping |
| survey's own heuristic notices the factor form | the factor rebuild emits `"Data do not look like combined weights"` — a useful cross-check, not something to depend on |
| The FPC block and the type restrictions | `deparse(survey:::svrepdesign.default)`, quoted verbatim in F2 |
| surveycore's replicate variance ignores the FPC | `grep -n "fpc" R/variance-replicate.R` returns nothing; `.get_design_vars_flat()` omits it for `survey_replicate` |

## Open questions

None blocking. The three decisions the spec must settle are resolved in
`decisions.md` as D1, D2 and D3, each with the measurement that decides it.
