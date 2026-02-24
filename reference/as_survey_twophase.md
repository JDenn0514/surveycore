# Create a Two-Phase Survey Design

Creates a two-phase (double) sampling design from an existing
`survey_taylor` Phase 1 object. Phase 1 covers all rows; Phase 2 is a
strict subset indicated by a logical column. Uses a tidy-select
interface for all Phase 2 design variable arguments.

## Usage

``` r
as_survey_twophase(
  phase1,
  ids2 = NULL,
  strata2 = NULL,
  probs2 = NULL,
  fpc2 = NULL,
  subset,
  method = c("full", "approx", "simple")
)
```

## Arguments

- phase1:

  A `survey_taylor` object representing the Phase 1 design. Its `@data`
  must contain ALL rows from both phases, plus a logical indicator
  column for Phase 2 membership. Create with
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- ids2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 cluster ID column(s). For single-stage Phase 2: `ids2 = psu2`.
  For multi-stage: `ids2 = c(psu2, ssu2)`. Omit if Phase 2 has no
  within-stratum clustering.

- strata2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 stratification column (a single column). Optional.

- probs2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 inclusion probability column (a single column, values in (0,
  1\]). Optional.

- fpc2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 finite population correction column (a single column).
  Optional.

- subset:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Single logical column in `phase1@data`. `TRUE` = row selected into
  Phase 2; `FALSE` = Phase 1 only. Required. Must contain both `TRUE`
  and `FALSE` values (non-degenerate).

- method:

  Character. Variance estimation method for combining Phase 1 and Phase
  2 variability. One of `"full"` (default), `"approx"`, or `"simple"`.
  See Details.

## Value

A `survey_twophase` object.

## Details

### Variance methods

- `"full"` — Full two-phase variance formula. Accounts for variability
  in both phases. Requires Phase 2 design information (`probs2`, `ids2`,
  `strata2`) when Phase 2 is not a simple random subsample. If none of
  these are provided, a warning is issued and Phase 2 selection is
  treated as SRS within Phase 1 strata.

- `"approx"` — Approximation that ignores Phase 1 sampling variability.
  Faster but less accurate than `"full"` when the Phase 1 sampling
  fraction is non-negligible.

- `"simple"` — Treats Phase 2 as a single-phase design, ignoring
  Phase 1. Only valid when Phase 1 is a census (no sampling). Issues a
  warning when Phase 1 has PSU cluster variables, because this
  understates variance for clustered designs.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs,
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
for replicate-weight designs

Other constructors:
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md),
[`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md),
[`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md),
[`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md),
[`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_srs()`](https://jdenn0514.github.io/surveycore/reference/survey_srs.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal two-phase design: Phase 1 = full cohort, Phase 2 = random subset
df <- data.frame(
  id        = 1:20,
  wt        = rep(2, 20),
  in_phase2 = c(rep(TRUE, 10), rep(FALSE, 10)),
  y         = rnorm(20)
)
phase1 <- as_survey(df, ids = id, weights = wt)
d2 <- as_survey_twophase(phase1, subset = in_phase2)

# With Phase 2 stratification and inclusion probabilities
df2 <- data.frame(
  id          = 1:30,
  wt          = rep(3, 30),
  in_phase2   = c(rep(TRUE, 15), rep(FALSE, 15)),
  arm         = rep(c("A", "B", "C"), 10),
  subsamprate = rep(c(0.5, 0.7, 0.3), 10),
  y           = rnorm(30)
)
phase1b <- as_survey(df2, ids = id, weights = wt)
d2b <- as_survey_twophase(
  phase1b,
  strata2 = arm,
  probs2  = subsamprate,
  subset  = in_phase2,
  method  = "full"
)
```
