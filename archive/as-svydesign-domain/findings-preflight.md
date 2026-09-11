# Preflight findings — as-svydesign-domain

Measured 2026-09-09 in the session, on branch
`JDenn0514/as_svydesign-drops-a-filtered-designs-domain-res` at `a545505`.
survey 4.5, R 4.6.1, Windows. Package loaded with `pkgload::load_all(".")`, so
every figure comes from this branch and not from an installed copy.

Scripts are in the session scratchpad and are not durable. Every command below
is written out, so any figure can be re-measured from this file alone.

## Reproduction of the reported defect, on all five routes

Each row filters a design with `surveytidy::filter(d, y1 > 50)`, converts with
`as_svydesign()`, and compares three point estimates for `y1`.

| Route | `svymean()` on the converted object | `get_means()` on the filtered design | `svymean()` after `x[r, ]` |
|---|--:|--:|--:|
| Taylor | 50.761561 | 58.176655 | 58.176655 |
| replicate | 50.143 | 57.154 | 57.154 |
| twophase | 49.203 | 58.458 | 58.067 |
| nonprob, replicate weights | 47.719 | 57.124 | 57.124 |
| nonprob, no replicate weights | 47.719 | 57.124 | 57.124 |

The Taylor row reproduces the issue's table exactly. Four of the five routes
recover the domain estimate to every printed digit. The twophase row does not,
and F3 below says why.

Designs used: `make_survey_data(n = 200, n_psu = 20, n_strata = 4, seed = 3)`
for Taylor; the `make_replicate()`, `make_twophase()` and `make_nonprob()`
shapes from `tests/testthat/test-conversion.R` for the rest, with `ids2 = psu`
added to the twophase (see F3).

## F1 — Use `x[r, ]`. `subset()` breaks the round trip, and breaks it silently.

All three `survey` subset methods end the same way:

```r
survey:::subset.survey.design   # and .svyrep.design, and .twophase
function (x, subset, ...) {
    e <- substitute(subset)
    r <- eval(e, x$variables, parent.frame())
    r <- r & !is.na(r)
    x <- x[r, ]
    x$call <- sys.call(-1)      # <- this line
    x
}
```

`x$call <- sys.call(-1)` overwrites the stored call. `.as_svydesign_taylor()`
builds that call deliberately with `bquote()` so the formulas are inlined
(`R/methods-conversion.R:194-206`), and `from_svydesign()` reads it back at
`R/methods-conversion.R:642-653` through `x$call$ids`, `$strata`, `$weights`,
`$fpc` and `$nest`. Each read is wrapped in
`tryCatch(..., error = function(e) NULL)`, so a destroyed call raises nothing.

Measured on the Taylor design above:

| Path | stored call after the step | `@variables` after `from_svydesign()` |
|---|---|---|
| `sv[r, ]` | unchanged: `survey::svydesign(ids = ~psu, strata = ~strata, weights = ~wt, fpc = NULL, data = x@data, nest = FALSE)` | `ids = "psu"`, `strata = "strata"`, `weights = "wt"` |
| `subset(sv, ..surveycore_domain..)` | `subset(sv, ..surveycore_domain..)` | `ids = NULL`, `strata = NULL`, `weights = "wt"` |

Neither path errors. Both return a 107-row design and the same point estimate.
The confidence interval differs, because the `subset()` path lost the clustering
and the stratification:

| Path | mean | ci_low | ci_high |
|---|--:|--:|--:|
| `sv[r, ]` | 58.2 | 56.8 | 59.6 |
| `subset(sv, ...)` | 58.2 | 56.9 | 59.5 |

`weights` survives only because `from_svydesign()` has a second route to it.
`ids` and `strata` have none.

`[` preserved the call on all five routes, checked with
`identical(deparse(sv$call), deparse(sv[r, ]$call))`.

The issue's §Suggested fix names `subset()` by name. Taking it literally
regresses the round trip that PR #239 was built to make work.

## F2 — The twophase route needs the domain vector from the object, not from `@data`

`@data` holds one row per phase-1 row. The converted twophase object's phase-1
sample holds only the phase-2 rows:

```
phase1$full rows:   60
phase1$sample rows: 29
domain column length in @data: 60
```

Indexing with the `@data`-side vector raises a bare, unclassed error:

```
ERROR: logical subscript too long (60, should be 29)
```

Reading the same column off `sv$phase1$sample$variables` gives a length-29
vector with 12 `TRUE`, and `sv[rs, ]` then works and preserves the call. The
domain column does reach the phase-1 sample variables, so nothing extra has to
be carried across:

```r
DC %in% names(sv$phase1$sample$variables)   # TRUE
```

The other four routes take the `@data`-side vector unchanged.

## F3 — The twophase verification criterion in the issue cannot be met, and this fix is not why

surveycore's twophase `get_means()` and `survey`'s twophase object weight the
same 12 rows differently. Reproduced by hand:

| Weighting | weighted mean of `y1` over the 12 domain rows |
|---|--:|
| the phase-1 weight column, `wt` | 58.45753 |
| the combined two-phase probability, `1 / sv$prob` | 58.06658 |

`get_means()` answers 58.45753. `svymean()` on the restricted object answers
58.06658. The same gap sits on the **unfiltered** design, where no domain is
involved at all:

| Unfiltered twophase | mean |
|---|--:|
| `get_means(d3, y1)` | 48.9 |
| `svymean(~y1, as_svydesign(d3))` | 49.203 |

So the gap is pre-existing and independent of the domain. The issue's
§Verification asks that a filtered twophase design "converts to an object whose
`survey::svymean()` matches surveycore's own `get_means()`". That criterion is
unmeetable on the twophase route today, and no change inside this issue's write
surface would make it meetable.

The twophase route needs a different oracle: the restricted object must equal
the object a caller restricts by hand, and the unfiltered gap must not move.
Both are measurable. Whether the weighting gap itself is a defect is a separate
question and belongs in its own issue.

## F4 — An unfiltered design carries no domain column at all

```r
SURVEYCORE_DOMAIN_COL %in% names(survey_data(d))   # FALSE
```

So "apply it when the column is present" is the whole guard. There is no
all-`TRUE` column to detect on an unfiltered design, and no route needs to tell
"never filtered" apart from "filtered to everything".

## F5 — An all-FALSE domain returns zeros, not an error

`surveytidy::filter(d, y1 > 1e6)` warns at filter time:

```
! filter() produced an empty domain — no rows match the condition.
i Variance estimation on this domain will fail.
```

It keeps all 200 rows with 0 marked. `svymean()` on the restricted object then
answers `mean 0, SE 0` and raises nothing. The behaviour is survey's, not
surveycore's, and the spec should say which of the two it wants.

## F6 — `[` does not handle `NA` and `subset()` does

`subset()` computes `r <- r & !is.na(r)` before indexing. Moving to `[` moves
that responsibility into surveycore.

Measured: `surveytidy::filter()` never leaves `NA` in the column. On a design
whose `y1` holds three `NA` values, `filter(d, y1 > 50)` returns a logical
column with `anyNA()` FALSE and 105 `TRUE`, so the predicate's `NA` results
arrive as FALSE.

That closes the question for every column surveytidy writes. It does not close
it for a column written by hand into `@data`, which nothing forbids. Carrying
`r & !is.na(r)` costs one expression and matches what `survey` does, so the
spec should carry it.

## F7 — `as_tbl_svy()` inherits the defect today

`as_tbl_svy()` on the filtered 200-row Taylor design returns a `tbl_svy` whose
`$variables` has 200 rows. It calls `as_svydesign()` internally, so it inherits
whatever that returns.

## What none of this settles

The two questions the issue defers, both untouched by the measurements above:

1. Whether the domain column is dropped from the converted object once applied.
   Note that the round trip currently carries it back in: `from_svydesign()` on
   a restricted object returns a design printing `Domain: 107 of 107 rows`, with
   an all-`TRUE` `..surveycore_domain..` column in `@data`.
2. Whether the reverse direction recovers a domain. The issue states it cannot.
