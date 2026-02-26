# Package index

## Survey design constructors

Create survey design objects from a data frame. All use a tidy-select
interface — bare column names, no formula syntax.

- [`as_survey()`](https://jdenn0514.github.io/surveycore/reference/as_survey.md)
  : Create a Taylor Series Linearization Survey Design
- [`as_survey_srs()`](https://jdenn0514.github.io/surveycore/reference/as_survey_srs.md)
  : Create a Simple Random Sample Survey Design
- [`as_survey_rep()`](https://jdenn0514.github.io/surveycore/reference/as_survey_rep.md)
  : Create a Replicate Weights Survey Design
- [`as_survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/as_survey_twophase.md)
  : Create a Two-Phase Survey Design
- [`as_survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/as_survey_calibrated.md)
  **\[experimental\]** : Create a Calibrated / Non-Probability Survey
  Design
- [`update_design()`](https://jdenn0514.github.io/surveycore/reference/update_design.md)
  : Update Design Variables on an Existing Survey Object

## Estimation

Compute weighted estimates with design-correct standard errors.

- [`meta()`](https://jdenn0514.github.io/surveycore/reference/meta.md) :
  Extract Metadata from a Survey Result
- [`get_freqs()`](https://jdenn0514.github.io/surveycore/reference/get_freqs.md)
  : Weighted Frequency Tables for Categorical Survey Variables
- [`get_means()`](https://jdenn0514.github.io/surveycore/reference/get_means.md)
  : Weighted Mean for a Survey Design
- [`get_totals()`](https://jdenn0514.github.io/surveycore/reference/get_totals.md)
  : Weighted Total for a Survey Design
- [`get_corr()`](https://jdenn0514.github.io/surveycore/reference/get_corr.md)
  : Survey-Weighted Pearson Correlation
- [`get_quantiles()`](https://jdenn0514.github.io/surveycore/reference/get_quantiles.md)
  : Survey-Weighted Quantiles

## Metadata — setters

Assign variable labels, value labels, question prefaces, and notes.
Single-variable setters accept bare names; plural setters accept named
lists.

- [`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
  : Set a Variable Label
- [`set_variable_labels()`](https://jdenn0514.github.io/surveycore/reference/set_variable_labels.md)
  : Set Variable Labels for Multiple Variables
- [`set_val_labels()`](https://jdenn0514.github.io/surveycore/reference/set_val_labels.md)
  : Set Value Labels for a Variable
- [`set_value_labels()`](https://jdenn0514.github.io/surveycore/reference/set_value_labels.md)
  : Set Value Labels for Multiple Variables
- [`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md)
  : Set a Question Preface
- [`set_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/set_question_prefaces.md)
  : Set Question Prefaces for Multiple Variables
- [`set_var_note()`](https://jdenn0514.github.io/surveycore/reference/set_var_note.md)
  : Set an Analyst Note
- [`set_variable_notes()`](https://jdenn0514.github.io/surveycore/reference/set_variable_notes.md)
  : Set Analyst Notes for Multiple Variables

## Metadata — extractors

Retrieve metadata for a single variable.

- [`extract_var_label()`](https://jdenn0514.github.io/surveycore/reference/extract_var_label.md)
  : Extract a Variable Label
- [`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md)
  : Extract Value Labels for a Variable
- [`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md)
  : Extract a Question Preface
- [`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md)
  : Extract an Analyst Note

## Conversion

Convert between surveycore objects,
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html),
and [`srvyr::tbl_svy`](http://gdfe.co/srvyr/reference/tbl_svy.md).

- [`as_svydesign()`](https://jdenn0514.github.io/surveycore/reference/as_svydesign.md)
  : Convert a surveycore Design Object to a survey Package Design
- [`from_svydesign()`](https://jdenn0514.github.io/surveycore/reference/from_svydesign.md)
  : Convert a survey Package Design to a surveycore Design Object
- [`as_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/as_tbl_svy.md)
  : Convert a surveycore Design Object to an srvyr tbl_svy
- [`from_tbl_svy()`](https://jdenn0514.github.io/surveycore/reference/from_tbl_svy.md)
  : Convert an srvyr tbl_svy to a surveycore Design Object

## S7 class objects

S7 classes exported for use in downstream packages and extension code.
Use `S7::S7_inherits(x, survey_taylor)` for class testing.

- [`survey_base()`](https://jdenn0514.github.io/surveycore/reference/survey_base.md)
  : Abstract Base Survey Design Class
- [`survey_srs()`](https://jdenn0514.github.io/surveycore/reference/survey_srs.md)
  : Simple Random Sample Survey Design
- [`survey_taylor()`](https://jdenn0514.github.io/surveycore/reference/survey_taylor.md)
  : Taylor Series Linearization Survey Design
- [`survey_replicate()`](https://jdenn0514.github.io/surveycore/reference/survey_replicate.md)
  : Replicate Weights Survey Design
- [`survey_twophase()`](https://jdenn0514.github.io/surveycore/reference/survey_twophase.md)
  : Two-Phase Survey Design
- [`survey_calibrated()`](https://jdenn0514.github.io/surveycore/reference/survey_calibrated.md)
  : Calibrated / Non-Probability Survey Design
- [`survey_metadata()`](https://jdenn0514.github.io/surveycore/reference/survey_metadata.md)
  : Survey Metadata Container

## Utilities

Internal helpers exported for use in extension packages.

- [`survey_data()`](https://jdenn0514.github.io/surveycore/reference/survey_data.md)
  : Access the Data Component of a Survey Design Object
- [`SURVEYCORE_DOMAIN_COL`](https://jdenn0514.github.io/surveycore/reference/SURVEYCORE_DOMAIN_COL.md)
  : Internal Domain Column Name Constant

## Example datasets

Real-world survey datasets included for testing and illustration.

- [`nhanes_2017`](https://jdenn0514.github.io/surveycore/reference/nhanes_2017.md)
  : NHANES 2017-2018: Demographics and Blood Pressure
- [`acs_pums_wy`](https://jdenn0514.github.io/surveycore/reference/acs_pums_wy.md)
  : ACS PUMS 2022 1-Year: Wyoming Persons
- [`anes_2024`](https://jdenn0514.github.io/surveycore/reference/anes_2024.md)
  : ANES 2024: American National Election Studies Time Series
- [`gss_2024`](https://jdenn0514.github.io/surveycore/reference/gss_2024.md)
  : GSS 2024: General Social Survey
- [`pew_jewish_2020`](https://jdenn0514.github.io/surveycore/reference/pew_jewish_2020.md)
  : Pew Jewish Americans 2020
- [`pew_npors_2025`](https://jdenn0514.github.io/surveycore/reference/pew_npors_2025.md)
  : Pew NPORS 2025: National Public Opinion Reference Survey
