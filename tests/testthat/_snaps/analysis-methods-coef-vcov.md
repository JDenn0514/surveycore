# coef() on survey_t_test throws surveycore_error_result_method_unsupported

    Code
      coef(rt)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` is not supported for <survey_t_test> objects.
      i These result types have dedicated columns (estimate, se, t_stat, df, p_value). Access them directly.
      v Use `result$estimate`, `result$se`, etc.

# coef() on survey_pairwise throws surveycore_error_result_method_unsupported

    Code
      coef(rp)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` is not supported for <survey_pairwise> objects.
      i These result types have dedicated columns (estimate, se, t_stat, df, p_value). Access them directly.
      v Use `result$estimate`, `result$se`, etc.

# vcov() on survey_t_test throws surveycore_error_result_method_unsupported

    Code
      vcov(rt)
    Condition
      Error in `.check_result_preconditions()`:
      x `vcov()` is not supported for <survey_t_test> objects.
      i These result types have dedicated columns (estimate, se, t_stat, df, p_value). Access them directly.
      v Use `result$estimate`, `result$se`, etc.

# SE() on survey_t_test throws surveycore_error_result_method_unsupported

    Code
      SE(rt)
    Condition
      Error in `.check_result_preconditions()`:
      x `vcov()` is not supported for <survey_t_test> objects.
      i These result types have dedicated columns (estimate, se, t_stat, df, p_value). Access them directly.
      v Use `result$estimate`, `result$se`, etc.

# confint() on survey_t_test throws surveycore_error_result_method_unsupported

    Code
      confint(rt)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` is not supported for <survey_t_test> objects.
      i These result types have dedicated columns (estimate, se, t_stat, df, p_value). Access them directly.
      v Use `result$estimate`, `result$se`, etc.

# coef() on result with stripped .survey_result throws surveycore_error_result_method_unsupported

    Code
      coef(r)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` requires a <survey_result> built with `get_means()`, `get_totals()`, or another supported `get_*()` function.
      i The `.survey_result` metadata attribute is absent.

# confint(result, level = 0) throws surveycore_error_invalid_conf_level

    Code
      confint(r, level = 0)
    Condition
      Error in `confint()`:
      x `level` must be a single number strictly between 0 and 1.
      i Got 0.

# confint(result, level = 1) throws surveycore_error_invalid_conf_level

    Code
      confint(r, level = 1)
    Condition
      Error in `confint()`:
      x `level` must be a single number strictly between 0 and 1.
      i Got 1.

# confint(result, level = NA) throws surveycore_error_invalid_conf_level

    Code
      confint(r, level = NA_real_)
    Condition
      Error in `confint()`:
      x `level` must be a single number strictly between 0 and 1.
      i Got NA.

# confint() with df = -1L stored throws surveycore_error_invalid_df

    Code
      confint(r)
    Condition
      Error in `confint()`:
      x Design degrees of freedom must be positive (got -1).
      i The `.survey_result` attribute was constructed with `df = -1`.
      v Ensure the survey design has at least one degree of freedom.

# coef() on wide-format survey_corr throws surveycore_error_result_method_unsupported

    Code
      coef(rcorr_wide)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` is not supported for wide-format <survey_corr> objects.
      i Wide-format correlation results do not have an `estimate_cols` mapping.
      v Use `format = "long"` in `get_corr()` before calling `coef()`.

# confint() with parm containing NA emits surveycore_warning_parm_na

    Code
      confint(r, parm = c("y1", NA_character_))
    Condition
      Warning:
      ! `parm` contains 1 `NA` element(s).
      i `NA` elements are dropped before parameter selection.
    Output
            2.5 %   97.5 %
      y1 49.02904 51.67635

# confint() with partially unmatched parm emits surveycore_warning_parm_unmatched

    Code
      confint(r, parm = c(valid_nm, "not_a_param"))
    Condition
      Warning:
      ! `parm` contains 1 name(s) not found in `coef()` output.
      i Unmatched names: "not_a_param".
      i These parameters are dropped. Check `names(coef(result))` for valid names.
    Output
              2.5 %   97.5 %
      A:y1 47.58754 52.43242

# confint() with all unmatched parm emits warning and returns 0x2 matrix

    Code
      suppressWarnings(confint(r, parm = c("no_match_1", "no_match_2")))
    Output
           2.5 % 97.5 %

# confint(result, level = 1.1) throws surveycore_error_invalid_conf_level

    Code
      confint(r, level = 1.1)
    Condition
      Error in `confint()`:
      x `level` must be a single number strictly between 0 and 1.
      i Got 1.1.

# vcov() and confint() on stripped-attribute result have correct error snapshots

    Code
      vcov(r)
    Condition
      Error in `.check_result_preconditions()`:
      x `vcov()` requires a <survey_result> built with `get_means()`, `get_totals()`, or another supported `get_*()` function.
      i The `.survey_result` metadata attribute is absent.

---

    Code
      confint(r)
    Condition
      Error in `.check_result_preconditions()`:
      x `coef()` requires a <survey_result> built with `get_means()`, `get_totals()`, or another supported `get_*()` function.
      i The `.survey_result` metadata attribute is absent.

