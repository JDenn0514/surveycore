# Set a Variable Label

Sets the variable label for a single variable in a survey design object.

## Usage

``` r
set_var_label(x, var, label)
```

## Arguments

- x:

  A survey design object.

- var:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable to label (bare, unquoted).

- label:

  A character string. The variable label to assign.

## Value

The modified survey object, invisibly.

## See also

[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md)
for setting multiple labels at once,
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md)
to retrieve a label

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)

## Examples

``` r
df <- data.frame(age = 25:30, wt = rep(1, 6))
d  <- survey_taylor(
  data = df,
  variables = list(
    ids = NULL, weights = "wt", strata = NULL,
    fpc = NULL, nest = FALSE, probs_provided = FALSE
  )
)
d <- set_var_label(d, age, "Age in years")

# Pipe-friendly
d <- d |> set_var_label(age, "Age in years")
```
