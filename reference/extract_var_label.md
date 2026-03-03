# Extract a Variable Label

Returns the variable label for a single variable in a survey design
object, or `NULL` if no label has been set.

## Usage

``` r
extract_var_label(x, var)
```

## Arguments

- x:

  A survey design object (`survey_taylor`, `survey_replicate`, or
  `survey_twophase`).

- var:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable name (bare, unquoted).

## Value

A character string, or `NULL` if no label has been set.

## See also

[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
to set a variable label

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
# nhanes_2017 carries haven-style labels auto-extracted by as_survey()
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
extract_var_label(d, riagendr)   # "Gender"
#> [1] "Gender"
extract_var_label(d, ridageyr)   # "Age in years at screening"
#> [1] "Age in years at screening"
```
