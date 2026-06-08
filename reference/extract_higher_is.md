# Extract Direction-of-Improvement Attributes

Returns the direction-of-improvement (`"better"` or `"worse"`) for one
or more variables in a survey design object or data frame. Variables
with no direction set return `NA_character_`.

## Usage

``` r
extract_higher_is(x, ..., variable = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to query. If empty, returns direction for all columns of
  `x`. Mutually exclusive with `variable`.

- variable:

  `character`. Variable name(s) — alternative to `...`. Mutually
  exclusive with `...`.

## Value

A named character vector. Unset variables return `NA_character_`.
Returns `character(0)` (named, zero-length) when all specified variables
are missing from `x`.

## See also

[`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md)
to set direction attributes

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/extract_reverse_coded.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_higher_is()`](https://jdenn0514.github.io/surveycore/reference/set_higher_is.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(
  nhanes_2017,
  ids = sdmvpsu,
  weights = wtint2yr,
  strata = sdmvstra,
  nest = TRUE
)
d <- set_higher_is(d, bpxsy1 = "worse")
extract_higher_is(d, bpxsy1)
#>  bpxsy1 
#> "worse" 
extract_higher_is(d)
#>     seqn  sdmvpsu sdmvstra wtmec2yr wtint2yr ridstatr riagendr ridageyr 
#>       NA       NA       NA       NA       NA       NA       NA       NA 
#> ridreth3 indfmpir dmdeduc2   bpxsy1   bpxdi1   bpxpls 
#>       NA       NA       NA  "worse"       NA       NA 
```
