# Extract Variable Labels

Returns variable labels for one or more variables in a survey design
object or data frame.

## Usage

``` r
extract_var_label(x, ..., format = "named_vector", fill = NULL)
```

## Arguments

- x:

  A survey design object or `data.frame`.

- ...:

  \<[`data-masked`](https://rlang.r-lib.org/reference/args_data_masking.html)\>
  Variable names (bare, unquoted). If empty, metadata for all variables
  is returned.

- format:

  `character(1)`. Output format: `"named_vector"` (default), `"list"`,
  or `"data_frame"`.

- fill:

  Scalar or `NULL`. How to handle variables with no label: `NULL`
  (default) omits them; `NA_character_` includes them with `NA`.

## Value

- `"named_vector"` (default): named character vector. Empty:
  `character(0)`.

- `"list"`: named list of character scalars. Empty:
  [`list()`](https://rdrr.io/r/base/list.html).

- `"data_frame"`: tibble with columns `variable` and `label`. Empty:
  zero-row tibble.

## See also

[`set_var_label()`](https://jdenn0514.github.io/surveycore/reference/set_var_label.md)
to set a variable label

Other metadata:
[`extract_metadata()`](https://jdenn0514.github.io/surveycore/reference/extract_metadata.md),
[`extract_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/extract_missing_codes.md),
[`extract_question_preface()`](https://jdenn0514.github.io/surveycore/reference/extract_question_preface.md),
[`extract_universe()`](https://jdenn0514.github.io/surveycore/reference/extract_universe.md),
[`extract_val_labels()`](https://jdenn0514.github.io/surveycore/reference/extract_val_labels.md),
[`extract_var_note()`](https://jdenn0514.github.io/surveycore/reference/extract_var_note.md),
[`infer_question_prefaces()`](https://jdenn0514.github.io/surveycore/reference/infer_question_prefaces.md),
[`set_missing_codes()`](https://jdenn0514.github.io/surveycore/reference/set_missing_codes.md),
[`set_question_preface()`](https://jdenn0514.github.io/surveycore/reference/set_question_preface.md),
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
extract_var_label(d)
#>                                    seqn                                 sdmvpsu 
#>            "Respondent sequence number"            "Masked variance pseudo-PSU" 
#>                                sdmvstra                                wtmec2yr 
#>        "Masked variance pseudo-stratum"    "Full sample 2 year MEC exam weight" 
#>                                wtint2yr                                ridstatr 
#>   "Full sample 2 year interview weight"          "Interview/Examination status" 
#>                                riagendr                                ridageyr 
#>                                "Gender"             "Age in years at screening" 
#>                                ridreth3                                indfmpir 
#>      "Race/Hispanic origin w/ NH Asian"     "Ratio of family income to poverty" 
#>                                dmdeduc2                                  bpxsy1 
#>          "Education level - Adults 20+"  "Systolic: Blood pres (1st rdg) mm Hg" 
#>                                  bpxdi1                                  bpxpls 
#> "Diastolic: Blood pres (1st rdg) mm Hg"     "60 sec. pulse (30 sec. pulse * 2)" 
extract_var_label(d, riagendr, ridageyr)
#>                    riagendr                    ridageyr 
#>                    "Gender" "Age in years at screening" 
extract_var_label(d, format = "data_frame")
#> # A tibble: 14 × 2
#>    variable label                                
#>    <chr>    <chr>                                
#>  1 seqn     Respondent sequence number           
#>  2 sdmvpsu  Masked variance pseudo-PSU           
#>  3 sdmvstra Masked variance pseudo-stratum       
#>  4 wtmec2yr Full sample 2 year MEC exam weight   
#>  5 wtint2yr Full sample 2 year interview weight  
#>  6 ridstatr Interview/Examination status         
#>  7 riagendr Gender                               
#>  8 ridageyr Age in years at screening            
#>  9 ridreth3 Race/Hispanic origin w/ NH Asian     
#> 10 indfmpir Ratio of family income to poverty    
#> 11 dmdeduc2 Education level - Adults 20+         
#> 12 bpxsy1   Systolic: Blood pres (1st rdg) mm Hg 
#> 13 bpxdi1   Diastolic: Blood pres (1st rdg) mm Hg
#> 14 bpxpls   60 sec. pulse (30 sec. pulse * 2)    
extract_var_label(d, fill = NA_character_)
#>                                    seqn                                 sdmvpsu 
#>            "Respondent sequence number"            "Masked variance pseudo-PSU" 
#>                                sdmvstra                                wtmec2yr 
#>        "Masked variance pseudo-stratum"    "Full sample 2 year MEC exam weight" 
#>                                wtint2yr                                ridstatr 
#>   "Full sample 2 year interview weight"          "Interview/Examination status" 
#>                                riagendr                                ridageyr 
#>                                "Gender"             "Age in years at screening" 
#>                                ridreth3                                indfmpir 
#>      "Race/Hispanic origin w/ NH Asian"     "Ratio of family income to poverty" 
#>                                dmdeduc2                                  bpxsy1 
#>          "Education level - Adults 20+"  "Systolic: Blood pres (1st rdg) mm Hg" 
#>                                  bpxdi1                                  bpxpls 
#> "Diastolic: Blood pres (1st rdg) mm Hg"     "60 sec. pulse (30 sec. pulse * 2)" 
```
