# Set Value Labels for Multiple Variables

Sets value labels for multiple variables at once using named arguments.
Each argument value must be a fully named vector. A warning is issued
for any variable where some observed values lack a label.

## Usage

``` r
set_value_labels(x, ...)
```

## Arguments

- x:

  A survey design object.

- ...:

  Named arguments where the name is the variable (unquoted) and the
  value is a named vector of value labels.

## Value

The modified survey object, invisibly.

## See also

[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
for setting value labels for a single variable

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)

## Examples

``` r
df <- data.frame(sex = c(1L, 2L), edu = c(1L, 3L), wt = c(1, 1))
d  <- survey_taylor(
  data = df,
  variables = list(
    ids = NULL, weights = "wt", strata = NULL,
    fpc = NULL, nest = FALSE, probs_provided = FALSE
  )
)
d <- set_value_labels(
  d,
  sex = c(Male = 1L, Female = 2L),
  edu = c("Less than HS" = 1L, "Some college" = 3L)
)
```
