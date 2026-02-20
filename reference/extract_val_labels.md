# Extract Value Labels for a Variable

Returns the named value-label vector for a single variable in a survey
design object, or `NULL` if no value labels have been set.

## Usage

``` r
extract_val_labels(x, var)
```

## Arguments

- x:

  A survey design object.

- var:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable name (bare, unquoted).

## Value

A named vector (e.g., `c(Male = 1L, Female = 2L)`), or `NULL`.

## See also

[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
to set value labels

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)

## Examples

``` r
df <- data.frame(sex = c(1L, 2L, 1L), wt = c(1, 1, 1))
d  <- survey_taylor(
  data = df,
  variables = list(
    ids = NULL, weights = "wt", strata = NULL,
    fpc = NULL, nest = FALSE, probs_provided = FALSE
  )
)
d <- set_val_labels(d, sex, c(Male = 1L, Female = 2L))
extract_val_labels(d, sex)
#>   Male Female 
#>      1      2 
```
