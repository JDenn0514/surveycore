# Set Value Labels for a Variable

Sets value labels for a single variable in a survey design object. Extra
labels (for values not present in the data) are allowed — they document
the full coding scheme. A warning is issued if some observed data values
lack a label.

## Usage

``` r
set_val_labels(x, var, labels)
```

## Arguments

- x:

  A survey design object.

- var:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable to label (bare, unquoted).

- labels:

  A fully named vector where names are the display labels and values are
  the data codes (e.g., `c(Male = 1L, Female = 2L)`). All elements must
  be named.

## Value

The modified survey object, invisibly.

## See also

[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md)
for setting labels for multiple variables,
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
to retrieve value labels

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
d <- set_val_labels(
  d, ridstatr, c("Interview only" = 1L, "Interview + exam" = 2L)
)
```
