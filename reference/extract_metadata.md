# Extract All Metadata for Variables

Returns a summary of all metadata fields for one or more variables in a
survey design object or data frame. Useful for auditing metadata state
or building codebooks.

## Usage

``` r
extract_metadata(x, ..., fill = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Variables to query. Supports selection helpers:
  [`tidyselect::starts_with()`](https://tidyselect.r-lib.org/reference/starts_with.html),
  [`tidyselect::all_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html),
  [`tidyselect::matches()`](https://tidyselect.r-lib.org/reference/starts_with.html),
  etc. If empty, returns metadata for all variables. Use
  [`tidyselect::any_of()`](https://tidyselect.r-lib.org/reference/all_of.html)
  to silently skip missing variable names.

- fill:

  `NULL` (default) or `"include"`. `NULL` omits variables that have no
  metadata in any field; `"include"` returns all variables regardless.

## Value

A named list. Each entry is a named list with keys: `variable_label`,
`value_labels`, `question_preface`, `note`, `universe`, `missing_codes`,
`transformations`.

## See also

Other metadata:
[`classify_question_type()`](https://jdenn0514.github.io/surveycore/reference/classify_question_type.md),
[`extract_higher_is()`](https://jdenn0514.github.io/surveycore/reference/extract_higher_is.md),
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
d <- as_survey(nhanes_2017, ids = sdmvpsu, weights = wtint2yr,
               strata = sdmvstra, nest = TRUE)
d <- set_universe(d, ridageyr = "All participants 0+")
extract_metadata(d, ridageyr)
#> $ridageyr
#> $ridageyr$variable_label
#> [1] "Age in years at screening"
#> 
#> $ridageyr$value_labels
#> NULL
#> 
#> $ridageyr$question_preface
#> NULL
#> 
#> $ridageyr$note
#> NULL
#> 
#> $ridageyr$universe
#> [1] "All participants 0+"
#> 
#> $ridageyr$missing_codes
#> NULL
#> 
#> $ridageyr$transformations
#> list()
#> 
#> 
extract_metadata(d, fill = "include")
#> $seqn
#> $seqn$variable_label
#> [1] "Respondent sequence number"
#> 
#> $seqn$value_labels
#> NULL
#> 
#> $seqn$question_preface
#> NULL
#> 
#> $seqn$note
#> NULL
#> 
#> $seqn$universe
#> NULL
#> 
#> $seqn$missing_codes
#> NULL
#> 
#> $seqn$transformations
#> list()
#> 
#> 
#> $sdmvpsu
#> $sdmvpsu$variable_label
#> [1] "Masked variance pseudo-PSU"
#> 
#> $sdmvpsu$value_labels
#> NULL
#> 
#> $sdmvpsu$question_preface
#> NULL
#> 
#> $sdmvpsu$note
#> NULL
#> 
#> $sdmvpsu$universe
#> NULL
#> 
#> $sdmvpsu$missing_codes
#> NULL
#> 
#> $sdmvpsu$transformations
#> list()
#> 
#> 
#> $sdmvstra
#> $sdmvstra$variable_label
#> [1] "Masked variance pseudo-stratum"
#> 
#> $sdmvstra$value_labels
#> NULL
#> 
#> $sdmvstra$question_preface
#> NULL
#> 
#> $sdmvstra$note
#> NULL
#> 
#> $sdmvstra$universe
#> NULL
#> 
#> $sdmvstra$missing_codes
#> NULL
#> 
#> $sdmvstra$transformations
#> list()
#> 
#> 
#> $wtmec2yr
#> $wtmec2yr$variable_label
#> [1] "Full sample 2 year MEC exam weight"
#> 
#> $wtmec2yr$value_labels
#> NULL
#> 
#> $wtmec2yr$question_preface
#> NULL
#> 
#> $wtmec2yr$note
#> NULL
#> 
#> $wtmec2yr$universe
#> NULL
#> 
#> $wtmec2yr$missing_codes
#> NULL
#> 
#> $wtmec2yr$transformations
#> list()
#> 
#> 
#> $wtint2yr
#> $wtint2yr$variable_label
#> [1] "Full sample 2 year interview weight"
#> 
#> $wtint2yr$value_labels
#> NULL
#> 
#> $wtint2yr$question_preface
#> NULL
#> 
#> $wtint2yr$note
#> NULL
#> 
#> $wtint2yr$universe
#> NULL
#> 
#> $wtint2yr$missing_codes
#> NULL
#> 
#> $wtint2yr$transformations
#> list()
#> 
#> 
#> $ridstatr
#> $ridstatr$variable_label
#> [1] "Interview/Examination status"
#> 
#> $ridstatr$value_labels
#> NULL
#> 
#> $ridstatr$question_preface
#> NULL
#> 
#> $ridstatr$note
#> NULL
#> 
#> $ridstatr$universe
#> NULL
#> 
#> $ridstatr$missing_codes
#> NULL
#> 
#> $ridstatr$transformations
#> list()
#> 
#> 
#> $riagendr
#> $riagendr$variable_label
#> [1] "Gender"
#> 
#> $riagendr$value_labels
#> NULL
#> 
#> $riagendr$question_preface
#> NULL
#> 
#> $riagendr$note
#> NULL
#> 
#> $riagendr$universe
#> NULL
#> 
#> $riagendr$missing_codes
#> NULL
#> 
#> $riagendr$transformations
#> list()
#> 
#> 
#> $ridageyr
#> $ridageyr$variable_label
#> [1] "Age in years at screening"
#> 
#> $ridageyr$value_labels
#> NULL
#> 
#> $ridageyr$question_preface
#> NULL
#> 
#> $ridageyr$note
#> NULL
#> 
#> $ridageyr$universe
#> [1] "All participants 0+"
#> 
#> $ridageyr$missing_codes
#> NULL
#> 
#> $ridageyr$transformations
#> list()
#> 
#> 
#> $ridreth3
#> $ridreth3$variable_label
#> [1] "Race/Hispanic origin w/ NH Asian"
#> 
#> $ridreth3$value_labels
#> NULL
#> 
#> $ridreth3$question_preface
#> NULL
#> 
#> $ridreth3$note
#> NULL
#> 
#> $ridreth3$universe
#> NULL
#> 
#> $ridreth3$missing_codes
#> NULL
#> 
#> $ridreth3$transformations
#> list()
#> 
#> 
#> $indfmpir
#> $indfmpir$variable_label
#> [1] "Ratio of family income to poverty"
#> 
#> $indfmpir$value_labels
#> NULL
#> 
#> $indfmpir$question_preface
#> NULL
#> 
#> $indfmpir$note
#> NULL
#> 
#> $indfmpir$universe
#> NULL
#> 
#> $indfmpir$missing_codes
#> NULL
#> 
#> $indfmpir$transformations
#> list()
#> 
#> 
#> $dmdeduc2
#> $dmdeduc2$variable_label
#> [1] "Education level - Adults 20+"
#> 
#> $dmdeduc2$value_labels
#> NULL
#> 
#> $dmdeduc2$question_preface
#> NULL
#> 
#> $dmdeduc2$note
#> NULL
#> 
#> $dmdeduc2$universe
#> NULL
#> 
#> $dmdeduc2$missing_codes
#> NULL
#> 
#> $dmdeduc2$transformations
#> list()
#> 
#> 
#> $bpxsy1
#> $bpxsy1$variable_label
#> [1] "Systolic: Blood pres (1st rdg) mm Hg"
#> 
#> $bpxsy1$value_labels
#> NULL
#> 
#> $bpxsy1$question_preface
#> NULL
#> 
#> $bpxsy1$note
#> NULL
#> 
#> $bpxsy1$universe
#> NULL
#> 
#> $bpxsy1$missing_codes
#> NULL
#> 
#> $bpxsy1$transformations
#> list()
#> 
#> 
#> $bpxdi1
#> $bpxdi1$variable_label
#> [1] "Diastolic: Blood pres (1st rdg) mm Hg"
#> 
#> $bpxdi1$value_labels
#> NULL
#> 
#> $bpxdi1$question_preface
#> NULL
#> 
#> $bpxdi1$note
#> NULL
#> 
#> $bpxdi1$universe
#> NULL
#> 
#> $bpxdi1$missing_codes
#> NULL
#> 
#> $bpxdi1$transformations
#> list()
#> 
#> 
#> $bpxpls
#> $bpxpls$variable_label
#> [1] "60 sec. pulse (30 sec. pulse * 2)"
#> 
#> $bpxpls$value_labels
#> NULL
#> 
#> $bpxpls$question_preface
#> NULL
#> 
#> $bpxpls$note
#> NULL
#> 
#> $bpxpls$universe
#> NULL
#> 
#> $bpxpls$missing_codes
#> NULL
#> 
#> $bpxpls$transformations
#> list()
#> 
#> 
```
