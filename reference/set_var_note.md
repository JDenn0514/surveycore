# Set Analyst Note(s)

Sets an analyst note for one or more variables. Notes are free-text
annotations for documenting processing decisions, data quality concerns,
or other context.

## Usage

``` r
set_var_note(x, ..., variable = NULL, note = NULL)
```

## Arguments

- x:

  A survey design object or a data frame.

- ...:

  Named arguments where the name is the variable and the value is the
  note string. Supports `!!!` list splicing.

- variable:

  A character vector of variable names. Use with `note`.

- note:

  A character vector of note strings, one per element of `variable`.

## Value

The modified object, invisibly.

## Details

Supports Conventions 1, 2, and 3 — see
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
for details.

## See also

[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md)
to retrieve a note

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_sata()`](https://jdenn0514.github.io/surveycore/reference/extract_sata.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
[`set_sata()`](https://jdenn0514.github.io/surveycore/reference/set_sata.md),
[`set_universe()`](https://jdenn0514.github.io/surveycore/reference/set_universe.md),
[`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md),
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
d <- as_survey(gss_2024, ids = vpsu, weights = wtssps,
               strata = vstrat, nest = TRUE)
d <- set_var_note(d, age = "Top-coded at 89")
extract_var_note(d, age)
#>               age 
#> "Top-coded at 89" 
```
