# Replicate Weights Survey Design

A survey design object using replicate weights for variance estimation.
Create with
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md).

## Usage

``` r
survey_replicate(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL,
  calibration = NULL
)
```

## Arguments

- data:

  A `data.frame` containing the survey data. Prefer
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Created automatically by
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md).

- variables:

  A named list of design specification (weights, repweights, type,
  scale, rscales, fpc, fpctype, fpc_applied, fpc_fraction, mse, rho).
  Set automatically by
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md).

- groups:

  Set by surveytidy's `group_by()`. Always `character(0)` in standalone
  surveycore use.

- call:

  Language object capturing the construction call.

- calibration:

  A list of calibration data elements produced by
  [`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
  or `NULL` (default) for no calibration. When non-`NULL`, variance
  estimation routines apply a Deville-Sarndal calibration correction.

## Value

A `survey_replicate` object.

## Design variables (`@variables`)

- `weights`:

  Character string naming the weight column.

- `repweights`:

  Character vector of replicate weight column names. The replicate
  weight matrix is computed on demand from
  `design@data[, design@variables$repweights]` — it is not stored as a
  property.

- `type`:

  Replicate weight method: one of `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`,
  `"Fay"`, `"bootstrap"`, `"ACS"`, `"successive-difference"`, or
  `"other"`.

- `scale`:

  Numeric scaling factor for variance estimation.

- `rscales`:

  Numeric vector of replicate-specific scales, or `NULL`.

- `fpc`:

  Name of the FPC column the design was built from, or `NULL`.
  Provenance only: no replicate variance formula reads it.

- `fpctype`:

  `"fraction"` or `"correction"`: how to read the `fpc` column.

- `fpc_applied`:

  Where the finite population correction reached the variance:
  `"rscales"` (inside `rscales`), `"repweights"` (inside the replicate
  weight columns), `"none"` (an FPC was available and was not applied),
  or `NULL` (no FPC was available, or the design predates this key).
  With `fpc` set and `fpc_applied` `NULL`, whether the FPC was applied
  is not recorded.

- `fpc_fraction`:

  The sampling fraction `f` per replicate, a numeric vector with one
  value per replicate column, when
  [`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
  applied a numeric `fpc`; otherwise `NULL`.

- `mse`:

  Logical. Use MSE estimates?

- `rho`:

  Fay shrinkage factor for `type = "Fay"`; `NULL` for every other type.

## References

Canty, A.J. and Davison, A.C. (1999) Resampling-based variance
estimation for labour force surveys. *The Statistician* **48**(3),
379–391.

Deville, J.-C. and Sarndal, C.-E. (1992) Calibration estimators in
survey sampling. *Journal of the American Statistical Association*
**87**(418), 376–382.

Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993) Generalized raking
procedures in survey sampling. *Journal of the American Statistical
Association* **88**(423), 1013–1020.

Judkins, D.R. (1990) Fay's method for variance estimation. *Journal of
Official Statistics* **6**(3), 223–239.

Rao, J.N.K., Wu, C.F.J. and Yue, K. (1992) Some recent work on
resampling methods for complex surveys. *Survey Methodology* **18**(2),
209–217.

Shao, J. and Tu, D. (1995) *The Jackknife and Bootstrap*. Springer.

## See also

[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md)
to create a `survey_replicate` object.

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md),
[`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)

## Examples

``` r
# Prefer as_survey_replicate() over calling survey_replicate() directly
set.seed(1)
df <- data.frame(
  y = rnorm(20),
  wt = runif(20, 1, 3),
  rep1 = runif(20, 0.5, 2),
  rep2 = runif(20, 0.5, 2)
)
d <- as_survey_replicate(
  df,
  weights = wt,
  repweights = starts_with("rep"),
  type = "BRR"
)
class(d)
#> [1] "surveycore::survey_replicate" "surveycore::survey_base"     
#> [3] "S7_object"                   
```
