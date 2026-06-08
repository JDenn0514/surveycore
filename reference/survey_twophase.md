# Two-Phase Survey Design

A survey design object for two-phase (double) sampling. Create with
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

## Usage

``` r
survey_twophase(
  data = data.frame(),
  metadata = survey_metadata(),
  variables = list(),
  groups = character(0),
  call = NULL
)
```

## Arguments

- data:

  A `data.frame` containing the survey data (all Phase 1 rows, with a
  logical indicator for Phase 2 membership). Prefer
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
  over calling this constructor directly.

- metadata:

  A
  [survey_metadata](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  object. Inherited from the Phase 1 design when using
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

- variables:

  A named list of design specification (phase1, phase2, subset, method).
  Set automatically by
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

- groups:

  Set by surveytidy's `group_by()`. Always `character(0)` in standalone
  surveycore use.

- call:

  Language object capturing the construction call.

## Value

A `survey_twophase` object.

## Design variables (`@variables`)

- `phase1`:

  Named list containing the Phase 1 design specification (from a
  `survey_taylor` object's `@variables`).

- `phase2`:

  Named list with optional Phase 2 design columns: `ids`, `strata`,
  `probs`, `fpc` — each `NULL` or a character vector of column names.

- `subset`:

  Character string naming the logical column that indicates Phase 2
  membership (`TRUE` = selected into Phase 2).

- `method`:

  `"full"`, `"approx"`, or `"simple"`.

## See also

[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
to create a `survey_twophase` object.

Other constructors:
[`as_caldata()`](https://jdenn0514.github.io/surveycore/reference/as_caldata.md),
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md),
[`as_survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/as_survey_nonprob.md),
[`as_survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/as_survey_replicate.md),
[`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md),
[`survey_glm()`](https://jdenn0514.github.io/surveycore/reference/survey_glm.md),
[`survey_glm_fit()`](https://jdenn0514.github.io/surveycore/reference/survey_glm_fit.md),
[`survey_nonprob()`](https://jdenn0514.github.io/surveycore/reference/survey_nonprob.md),
[`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md),
[`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)

## Examples

``` r
# Prefer as_survey_twophase() over calling survey_twophase() directly
set.seed(1)
df <- data.frame(
  id = 1:100,
  y = rnorm(100),
  x = rnorm(100),
  wt = runif(100, 1, 3),
  in_phase2 = c(rep(TRUE, 40), rep(FALSE, 60))
)
phase1 <- as_survey(df, weights = wt)
d <- as_survey_twophase(phase1, subset = in_phase2)
class(d)
#> [1] "surveycore::survey_twophase" "surveycore::survey_base"    
#> [3] "S7_object"                  
```
