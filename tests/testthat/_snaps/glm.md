# survey_glm() programmatic interface: predictors without response errors

    Code
      survey_glm(d, predictors = c("y2", "y3"))
    Condition
      Error in `survey_glm()`:
      x `formula` is required.
      i `response` is required when using `predictors`.

# survey_glm() errors for non-survey design (P2-1)

    Code
      survey_glm(list(x = 1), y ~ x)
    Condition
      Error in `.check_unsupported_class()`:
      x `survey_glm()` requires a survey design object.
      i Got <list>.

# survey_glm() errors when formula/response/predictors all NULL (P2-2)

    Code
      survey_glm(d)
    Condition
      Error in `survey_glm()`:
      x `formula` is required.

# survey_glm() errors when predictors given without response (P2-2)

    Code
      survey_glm(d, predictors = "y2")
    Condition
      Error in `survey_glm()`:
      x `formula` is required.
      i `response` is required when using `predictors`.

# survey_glm() errors when formula and response both supplied (P2-16)

    Code
      survey_glm(d, formula = y1 ~ y2, response = "y1")
    Condition
      Error in `survey_glm()`:
      x `formula` and `response`/`predictors` are mutually exclusive.
      i Specify the model using either `formula` or `response`/`predictors`, not both.

# survey_glm() errors when formula arg is not a formula (P2-3)

    Code
      survey_glm(d, formula = "y1 ~ y2")
    Condition
      Error in `survey_glm()`:
      x `formula` must be a formula object, not <character>.

# survey_glm() errors when response variable absent from design@data (P2-4)

    Code
      survey_glm(d, nonexistent ~ y2)
    Condition
      Error in `survey_glm()`:
      x Response variable nonexistent not found in survey data.

# survey_glm() errors when predictor absent from design@data (P2-5)

    Code
      survey_glm(d, y1 ~ nonexistent)
    Condition
      Error in `survey_glm()`:
      x Predictor nonexistent not found in survey data.
      i Available columns: psu, strata, fpc, wt, y1, y2, y3, and group.

# survey_glm() errors for singular model matrix (P2-9)

    Code
      survey_glm(d, y1 ~ y2 + y2b)
    Condition
      Error in `survey_glm()`:
      x Model matrix is singular.
      i Check for perfect collinearity or empty factor levels.

# survey_glm() errors when weight column has NA (P2-11)

    Code
      survey_glm(d, y1 ~ y2)
    Condition
      Error in `survey_glm()`:
      x Weight column wt contains 1 NA value(s).
      i Survey weights must be fully observed. Remove rows with missing weights or impute before calling `survey_glm()`.

# survey_glm() errors for cbind() on LHS of formula (P2-20)

    Code
      survey_glm(d, cbind(y1, y2) ~ y3)
    Condition
      Error in `survey_glm()`:
      x `cbind()` on the left-hand side of `formula` is not supported.
      i Multinomial logistic regression is deferred to a later phase. Use a single binary or continuous response variable.

# survey_glm() errors for empty active domain (P2-17)

    Code
      d2 <- .glm_taylor()
      d2@data[["..surveycore_domain.."]] <- rep(FALSE, nrow(d2@data))
      survey_glm(d2, y1 ~ y2)
    Condition
      Error in `survey_glm()`:
      x Active domain contains no in-domain rows.
      i Apply a less restrictive `surveytidy::filter()` before calling `survey_glm()`.

# survey_glm() errors with na.action = na.fail and NA in response (P2-21)

    Code
      df2 <- make_survey_data(n = 100L, seed = 1L)
      df2$y1[5L] <- NA_real_
      d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata, nest = TRUE)
      survey_glm(d2, y1 ~ y2, na.action = na.fail)
    Condition
      Error in `survey_glm()`:
      x 1 column in the model has NA values with `na.action = na.fail`: y1 (1 NA).
      v Set `na.action = na.omit` to drop rows with NA, or remove them manually before calling `survey_glm()`.

