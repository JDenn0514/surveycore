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

  A survey design object (inheriting from `survey_base`) representing
  the Phase 1 design. Accepts a `survey_taylor` object. A
  `survey_replicate` object is refused: the phase-1 variance for a
  replicate design is not implemented. Its `@data` must contain ALL rows
  from both phases, plus a logical indicator column for Phase 2
  membership. Create with
  [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md).

- ids2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 cluster ID column: a single column, such as `ids2 = psu2`.
  Omit if Phase 2 has no within-stratum clustering. Without `probs2` or
  `fpc2`, the Phase 2 inclusion probability is the fraction of clusters
  selected within each Phase 2 stratum, not the fraction of rows.

  Multi-stage Phase 2 is not supported. The two-phase variance uses one
  Phase 2 sampling stage, so selecting more than one column, such as
  `ids2 = c(psu2, ssu2)`, is an error
  (`surveycore_error_twophase_multistage_phase2`) rather than a standard
  error that silently ignores the later stages.

- strata2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 stratification column (a single column; more than one is an
  error, as Phase 2 has one sampling stage). Optional.

- probs2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 inclusion probability column (a single column, values in (0,
  1\]). Optional.

- fpc2:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Phase 2 finite population correction column (a single column; more
  than one is an error, as Phase 2 has one sampling stage). Optional.

- subset:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Single logical column in `phase1@data`. `TRUE` = row selected into
  Phase 2; `FALSE` = Phase 1 only. Required. Must contain both `TRUE`
  and `FALSE` values (non-degenerate).

- method:

  Character. Variance estimation method for combining Phase 1 and Phase
  2 variability. One of `"full"` (default), `"approx"`, or `"simple"`.
  Case-sensitive. See Details.

  `"full"` and `"approx"` both match
  [`survey::twophase()`](https://rdrr.io/pkg/survey/man/twophase.html),
  and both can give standard errors that are too large (conservative)
  for some designs:

  - `"full"` without an `fpc` on the Phase 1 design treats the Phase 1
    sampling units (clusters, or rows when Phase 1 is unclustered) as
    Poisson-sampled. For a fixed-size Phase 1 sample that is very
    conservative for totals: in a simulation of a stratified cluster
    sample, about 13 times the true variance, or 3.7 times the standard
    error, and an unclustered, unstratified Phase 1 was overstated by a
    similar amount. Means are much less affected when Phase 1 is
    unstratified, but are still overstated when it is stratified. Supply
    `fpc` to
    [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
    for Phase 1; a weighted Phase 1 with no `fpc` raises a warning; see
    Details.

  - `"approx"` (and so `"simple"`) is conservative when Phase 1 is
    clustered and Phase 2 subsamples rows within the Phase 1 clusters,
    that is, when `ids2` is absent or finer than the Phase 1 cluster: in
    a simulation, about 2.4 times the true variance, or 1.55 times the
    standard error. It is close to unbiased when Phase 2 draws whole
    Phase 1 clusters or Phase 1 is unclustered. For the first kind of
    design, `method = "full"` with a Phase 1 `fpc` is the alternative.

## Value

A `survey_twophase` object. Columns imported with `haven`-style value
labels are stored as their underlying type: the `label` and `labels`
attributes are kept, and the value labels are also recorded in the
metadata system, but the `haven_labelled` class is not stored. Use
`survey_data(x, haven_class = TRUE)` to read the data back with that
class rebuilt.

## Details

### Variance methods

- `"full"` — Full two-phase variance formula: the double-expansion
  Horvitz-Thompson estimator of `survey::twophase(method = "full")`
  (Breslow and Chatterjee, 1999). Accounts for variability in both
  phases, using the Phase 1 weights as inclusion probabilities, and
  treats a Phase 1 with no weights, strata or `fpc` as an iid sample.
  Requires Phase 2 design information (`probs2`, `ids2`, `strata2`) when
  Phase 2 is not a simple random subsample. If none of these are
  provided, an error is raised.

- `"approx"` — The two-phase variance formula from survey 3.14 and
  earlier: a Phase 1 term plus a Phase 2 term. Needs less memory than
  `"full"`, and is exact for some special cases, most importantly Phase
  1 simple random sampling with stratified random sampling at Phase 2.

- `"simple"` — The same method as `"approx"`, as in
  [`survey::twophase()`](https://rdrr.io/pkg/survey/man/twophase.html).
  The design records `"simple"`, and every estimate and standard error
  equals the `"approx"` one.

### Phase 1 fpc and `method = "full"`

The `"full"` variance needs the Phase 1 sampling probabilities and, for
a fixed-size sample, the Phase 1 population sizes. Without a Phase 1
`fpc` it treats each Phase 1 sampling unit as drawn independently with
probability `1 / weight` (Poisson sampling), so it never centres the
unit totals. For a fixed-size Phase 1 sample the resulting standard
error of a total can be several times too large, whether or not Phase 1
is clustered or stratified. With an `fpc`, the variance is that of a
fixed-size sample in each Phase 1 stratum, and is close to unbiased.

`as_survey_twophase()` raises a warning of class
`surveycore_warning_twophase_full_no_fpc` when all three hold:
`method = "full"`, the Phase 1 design has no `fpc`, and the Phase 1
weights are not all 1. Phase 1 weights of all 1 mean the design was
built with no weights, which `"full"` treats as an iid sample, or is a
census, which contributes no Phase 1 variance; neither is overstated.
The warning fires once, when the design is built.
[`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
raises the same warning for a `twophase2` object under the same rule.

## References

Sarndal, C-E., Swensson, B. and Wretman, J. (1992) *Model Assisted
Survey Sampling*. Springer.

Breslow, N.E. and Chatterjee, N. (1999) Design and analysis of two-phase
studies with binary outcome applied to Wilms tumour prognosis. *Applied
Statistics* **48**, 457–468.

Breslow, N., Lumley, T., Ballantyne, C.M., Chambless, L.E. and Kulick,
M. (2009) Improved Horvitz-Thompson estimation of model parameters from
two-phase stratified samples: applications in epidemiology. *Statistics
in Biosciences*.
[doi:10.1007/s12561-009-9001-6](https://doi.org/10.1007/s12561-009-9001-6)

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
for Taylor series designs

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Minimal two-phase design: Phase 1 = a sample of 20 from 40, Phase 2 =
# random subset. The Phase 1 fpc gives method = "full" the population size.
df <- data.frame(
  id = 1:20,
  wt = rep(2, 20),
  pop = rep(40, 20),
  in_phase2 = c(rep(TRUE, 10), rep(FALSE, 10)),
  y = rnorm(20)
)
phase1 <- as_survey(df, ids = id, weights = wt, fpc = pop)
d2 <- as_survey_twophase(phase1, subset = in_phase2)

# With Phase 2 stratification and inclusion probabilities
df2 <- data.frame(
  id = 1:30,
  wt = rep(3, 30),
  pop = rep(90, 30),
  in_phase2 = c(rep(TRUE, 15), rep(FALSE, 15)),
  arm = rep(c("A", "B", "C"), 10),
  subsamprate = rep(c(0.5, 0.7, 0.3), 10),
  y = rnorm(30)
)
phase1b <- as_survey(df2, ids = id, weights = wt, fpc = pop)
d2b <- as_survey_twophase(
  phase1b,
  strata2 = arm,
  probs2 = subsamprate,
  subset = in_phase2,
  method = "full"
)
```
