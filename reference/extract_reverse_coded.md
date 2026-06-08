# Extract Reverse-Coded Flags

Returns the reverse-coded status for one or more variables in a survey
design object or data frame.

## Usage

``` r
extract_reverse_coded(x, ..., variable = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to query. If empty, returns reverse-coded status for all
  columns of `x`. Cannot be combined with `variable`.

- variable:

  `character`. Alternative programmatic interface: character vector of
  variable names. Cannot be combined with `...`.

## Value

A named logical vector. Variables not marked as reverse-coded return
`FALSE`. When all specified variables are missing, returns `logical(0)`.

## See also

[`set_reverse_coded()`](https://jdenn0514.github.io/surveycore/reference/set_reverse_coded.md)
to set reverse-coded flags

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
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
d <- set_reverse_coded(d, bpxsy1)
extract_reverse_coded(d, bpxsy1)
#> bpxsy1 
#>   TRUE 
extract_reverse_coded(d)
#>     seqn  sdmvpsu sdmvstra wtmec2yr wtint2yr ridstatr riagendr ridageyr 
#>    FALSE    FALSE    FALSE    FALSE    FALSE    FALSE    FALSE    FALSE 
#> ridreth3 indfmpir dmdeduc2   bpxsy1   bpxdi1   bpxpls 
#>    FALSE    FALSE    FALSE     TRUE    FALSE    FALSE 
```
