# Classify Variable Question Types

Groups variables by their shared `question_preface` metadata and
classifies each group as one of `"single"`, `"sata"`, or `"battery"`.
This is the single source of truth used by downstream export functions
to decide how to render each question.

## Usage

``` r
classify_question_type(x, ..., variable = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to classify. Supports selection helpers:
  [`tidyselect::starts_with()`](https://tidyselect.r-lib.org/reference/starts_with.html),
  [`tidyselect::all_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  etc. Cannot be combined with `variable`.

- variable:

  `character`. Alternative programmatic interface: character vector of
  variable names. Cannot be combined with `...`.

## Value

A tibble with columns:

- `variable` (character) — variable name

- `question_preface` (character) — the preface, or `NA` if none

- `type` (character) — one of `"single"`, `"sata"`, or `"battery"`

- `group` (integer) — group id; variables with the same non-NA preface
  share a group

## Details

The classification rules, applied per requested variable:

1.  If the variable has no `question_preface`, or is the only requested
    variable sharing its preface, `type = "single"`.

2.  If a `question_preface` is shared by 2+ requested variables and at
    least one is flagged via
    [`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
    all variables in that group get `type = "sata"`.

3.  Otherwise (shared preface, no SATA flag), all variables in the group
    get `type = "battery"`.

Group numbers are assigned sequentially by first appearance in the
input.

## See also

[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md)

Other metadata:
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
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
d <- set_question_preface(
  d,
  riagendr = "Demographics",
  ridageyr = "Demographics"
)
d <- set_sata(d, riagendr, ridageyr)
classify_question_type(d, riagendr, ridageyr, bpxsy1)
#> # A tibble: 3 × 4
#>   variable question_preface type   group
#>   <chr>    <chr>            <chr>  <int>
#> 1 riagendr Demographics     sata       1
#> 2 ridageyr Demographics     sata       1
#> 3 bpxsy1   NA               single     2
```
