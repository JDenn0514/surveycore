# Set Variable Label(s)

Sets variable labels using one of three conventions.

## Usage

``` r
set_var_label(x, ..., variable = NULL, label = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is the
  label string. Supports `!!!` list splicing.

- variable:

  A character vector of variable names. Use with `label`.

- label:

  A character vector of label strings, one per element of `variable`.

## Value

The modified object, invisibly.

## Details

**Convention 1 (named `...`)** — recommended for interactive use:

    set_var_label(x, age = "Age in years", income = "Annual income")
    set_var_label(x, !!!labels_list)   # list splicing

**Convention 2 (named vector in `...`)** — useful for programmatic use:

    set_var_label(x, c(age = "Age in years", income = "Annual income"))

**Convention 3 (`variable` + `label` arguments)** — for vector input:

    vars <- c("age", "income")
    lbls <- c("Age in years", "Annual income")
    set_var_label(x, variable = vars, label = lbls)

## See also

[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md)
to retrieve a label

Other metadata:
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
d <- set_var_label(d, indfmpir = "Income-to-poverty ratio")

# Multiple variables
d <- set_var_label(d, bpxsy1 = "Systolic BP (1st reading)",
                      bpxdi1 = "Diastolic BP (1st reading)")
```
