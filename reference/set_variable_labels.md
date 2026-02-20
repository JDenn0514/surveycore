# Set Variable Labels for Multiple Variables

Sets variable labels for multiple variables at once using named
arguments. All variable names must exist in the survey data.

## Usage

``` r
set_variable_labels(x, ...)
```

## Arguments

- x:

  A survey design object.

- ...:

  Named arguments where the name is the variable (unquoted) and the
  value is the label string. Supports `!!!` list splicing for
  programmatic use.

## Value

The modified survey object, invisibly.

## See also

[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
for setting a single label

Other metadata:
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)

## Examples

``` r
df <- data.frame(age = 25:30, income = 1:6, wt = rep(1, 6))
d  <- survey_taylor(
  data = df,
  variables = list(
    ids = NULL, weights = "wt", strata = NULL,
    fpc = NULL, nest = FALSE, probs_provided = FALSE
  )
)
d <- set_variable_labels(
  d,
  age    = "Age in years",
  income = "Annual household income"
)

# Programmatic with list splicing
lbls <- list(age = "Age in years", income = "Annual household income")
d <- set_variable_labels(d, !!!lbls)
```
