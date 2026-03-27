# Survey Metadata Container

Stores variable labels, value labels, question prefaces, notes, and
transformation history for variables in a survey design object.
Automatically populated from haven-style attributes when
[`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
or related constructors are called.

## Usage

``` r
survey_metadata(
  variable_labels = list(),
  value_labels = list(),
  question_prefaces = list(),
  notes = list(),
  universe = list(),
  missing_codes = list(),
  transformations = list(),
  weighting_history = list()
)
```

## Arguments

- variable_labels:

  A named list mapping variable names to character labels (e.g.,
  `list(age = "Age in years")`).

- value_labels:

  A named list mapping variable names to named vectors of value labels
  (e.g., `list(sex = c(Male = 1L, Female = 2L))`).

- question_prefaces:

  A named list mapping variable names to shared question battery preface
  text.

- notes:

  A named list mapping variable names to analyst notes.

- universe:

  A named list mapping variable names to universe descriptions (e.g.,
  `list(age = "Adults 18+")`). Describes the population to which a
  variable applies.

- missing_codes:

  A named list mapping variable names to atomic vectors of missing-value
  codes (e.g., `list(age = c(Refused = 99L, DK = 98L))`).

- transformations:

  A named list tracking variable transformation history (populated
  automatically during operations).

- weighting_history:

  A list recording weighting operations applied to the survey object
  (e.g., raking, trimming). Each entry is written by a surveywts
  function and contains the operation name, parameters, effective sample
  size before/after, and design effect. Always
  [`list()`](https://rdrr.io/r/base/list.html) until a surveywts
  weighting function is applied. Reserved for Phase 2.5.

## Value

A `survey_metadata` object.

## See also

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
[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md),
[`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md),
[`survey_weighting_history()`](https://jdenn0514.github.io/surveycore/reference/survey_weighting_history.md)

## Examples

``` r
# Empty metadata (default)
m <- survey_metadata()
m@variable_labels
#> list()

# Pre-populated metadata
m <- survey_metadata(
  variable_labels = list(age = "Respondent age", income = "Annual income"),
  value_labels = list(sex = c(Male = 1L, Female = 2L))
)
m@variable_labels$age
#> [1] "Respondent age"
m@value_labels$sex
#>   Male Female 
#>      1      2 
```
