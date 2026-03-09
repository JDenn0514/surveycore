# Update Design Variables on an Existing Survey Object

Updates one or more design variables (weights, cluster IDs, strata, FPC,
or replicate weights) on an existing survey design object. Use this
after modifying the underlying data — for example, after recalibrating
weights or adding a stratification variable. Emits an informational
message listing changed variables.

## Usage

``` r
update_design(
  x,
  ids = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  repweights = NULL,
  validate = TRUE
)
```

## Arguments

- x:

  A `survey_taylor` or `survey_replicate` object. `survey_twophase` is
  not supported; create a new design with
  [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md).

- ids:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  New cluster (PSU) ID column(s). `NULL` (default) means no change. Only
  used for `survey_taylor` objects.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  New weight column (a single column, values strictly \> 0). `NULL`
  (default) means no change.

- strata:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  New stratification column (a single column). `NULL` (default) means no
  change. Only used for `survey_taylor` objects.

- fpc:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  New finite population correction column (a single column). `NULL`
  (default) means no change. Only used for `survey_taylor` objects.

- repweights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  New replicate weight columns (one or more). `NULL` (default) means no
  change. Only used for `survey_replicate` objects.

- validate:

  Logical. If `TRUE` (default), re-runs the S7 class validator after
  updating, which checks structural invariants (column existence, weight
  column type and positivity, etc.).

## Value

The modified survey object, invisibly.

## See also

[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
to create a `survey_taylor` object,
[`as_survey_repweights()`](https://jdenn0514.github.io/surveycore/reference/as_survey_repweights.md)
to create a `survey_replicate` object

## Examples

``` r
# NHANES has two weight columns for different analysis types;
# start with the MEC examination weight for exam participants
exam <- nhanes_2017[nhanes_2017$ridstatr == 2, ]
d <- as_survey(exam, ids = sdmvpsu, weights = wtmec2yr,
               strata = sdmvstra, nest = TRUE)

# Switch to interview weight for interview-based variables
d_updated <- update_design(d, weights = wtint2yr)
#> ℹ Survey design updated. This may affect statistical validity.
#> ℹ Updated: weights
```
