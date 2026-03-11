# tests/testthat/test-metadata-system.R
#
# Tests for R/01-metadata-system.R
# Error/warning coverage map (plans/error-messages.md):
#   Row 27: surveycore_error_var_not_found   — singular setters
#   Row 28: surveycore_error_vars_not_found  — plural setters
#   Row 29: surveycore_error_labels_unnamed  — set_val_labels / set_value_labels
#   Row 30: surveycore_warning_missing_labels — set_val_labels / set_value_labels

# ── Test fixtures ─────────────────────────────────────────────────────────────

# Minimal survey_taylor for metadata tests (constructed directly because
# as_survey() is not implemented until Component 3).
make_design <- function() {
  df <- data.frame(
    age    = c(25L, 30L, 45L, 50L, 35L),
    sex    = c(1L, 2L, 1L, 2L, 1L),
    income = c(40000, 80000, 60000, 90000, 55000),
    wt     = c(1.2, 0.9, 1.1, 1.0, 1.3),
    stringsAsFactors = FALSE
  )
  survey_taylor(
    data = df,
    variables = list(
      ids           = NULL,
      weights       = "wt",
      strata        = NULL,
      fpc           = NULL,
      nest          = FALSE,
      probs_provided = FALSE
    )
  )
}

# Design with labels, universe, and missing codes for integration tests.
# Uses new unified setters — works after Steps 3.4–3.11 are complete.
make_labeled_design <- function(seed = 42) {
  df  <- make_survey_data(n = 100, seed = seed)
  svy <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  svy <- set_var_label(svy, y1 = "Outcome 1", y2 = "Outcome 2")
  svy <- set_val_labels(
    svy,
    strata = setNames(seq_len(5L), paste0("Stratum ", seq_len(5L)))
  )
  svy <- set_universe(svy, y1 = "All respondents")
  svy <- set_missing_codes(svy, y1 = c("Missing" = -1L))
  svy
}


# ── extract_var_label() ───────────────────────────────────────────────────────

test_that("extract_var_label() returns NULL when no label set", {
  d <- make_design()
  expect_null(extract_var_label(d, age))
})

test_that("extract_var_label() returns the label after set_var_label()", {
  d <- make_design()
  d <- set_var_label(d, age = "Age in years")
  expect_identical(extract_var_label(d, age), "Age in years")
})

test_that("extract_var_label() does not error on non-existent variable", {
  d <- make_design()
  # Non-existent var — returns NULL, no error
  expect_null(extract_var_label(d, nonexistent))
})


# ── extract_val_labels() ──────────────────────────────────────────────────────

test_that("extract_val_labels() returns NULL when no labels set", {
  d <- make_design()
  expect_null(extract_val_labels(d, sex))
})

test_that("extract_val_labels() returns the labels after set_val_labels()", {
  d <- make_design()
  d <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  result <- extract_val_labels(d, sex)
  expect_identical(result, c(Male = 1L, Female = 2L))
})


# ── extract_question_preface() ────────────────────────────────────────────────

test_that("extract_question_preface() returns NULL when no preface set", {
  d <- make_design()
  expect_null(extract_question_preface(d, age))
})

test_that("extract_question_preface() returns preface after set_question_preface()", {
  d <- make_design()
  d <- set_question_preface(d, age = "In the past 12 months, how old were you?")
  expect_identical(
    extract_question_preface(d, age),
    "In the past 12 months, how old were you?"
  )
})


# ── extract_var_note() ────────────────────────────────────────────────────────

test_that("extract_var_note() returns NULL when no note set", {
  d <- make_design()
  expect_null(extract_var_note(d, income))
})

test_that("extract_var_note() returns the note after set_var_note()", {
  d <- make_design()
  d <- set_var_note(d, income = "Imputed for 3% of respondents.")
  expect_identical(
    extract_var_note(d, income),
    "Imputed for 3% of respondents."
  )
})


# ── set_var_label() ───────────────────────────────────────────────────────────

test_that("set_var_label() convention 1 sets label for one variable", {
  d <- make_design()
  d <- set_var_label(d, age = "Age in years")
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
})

test_that("set_var_label() convention 1 sets labels for multiple variables", {
  d <- make_design()
  d <- set_var_label(d, age = "Age in years", income = "Annual income")
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
  expect_identical(d@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_var_label() convention 1 with !!! splicing sets labels", {
  d    <- make_design()
  lbls <- list(age = "Age in years", income = "Annual income")
  d    <- set_var_label(d, !!!lbls)
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
  expect_identical(d@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_var_label() convention 2 (named char vector in ...) sets labels", {
  d <- make_design()
  d <- set_var_label(d, c(age = "Age in years", income = "Annual income"))
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
  expect_identical(d@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_var_label() convention 3 (variable + label) sets one label", {
  d <- make_design()
  d <- set_var_label(d, variable = "age", label = "Age in years")
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
})

test_that("set_var_label() convention 3 (variable + label) sets multiple labels", {
  d <- make_design()
  d <- set_var_label(
    d,
    variable = c("age", "income"),
    label    = c("Age in years", "Annual income")
  )
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
  expect_identical(d@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_var_label() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_var_label(d, age = "Age in years"))
  expect_false(result$visible)
  expect_identical(result$value@metadata@variable_labels[["age"]], "Age in years")
})

test_that("set_var_label() survives pipe chain of three calls", {
  d <- make_design() |>
    set_var_label(age = "Age") |>
    set_var_label(sex = "Sex") |>
    set_var_label(income = "Income")
  expect_identical(d@metadata@variable_labels[["age"]], "Age")
  expect_identical(d@metadata@variable_labels[["sex"]], "Sex")
  expect_identical(d@metadata@variable_labels[["income"]], "Income")
})

test_that("set_var_label() NULL label deletes the existing entry", {
  d <- make_design()
  d <- set_var_label(d, age = "Age in years")
  d <- set_var_label(d, age = NULL)
  expect_false("age" %in% names(d@metadata@variable_labels))
})

test_that("set_var_label() data frame: sets attr(df$age, 'label')", {
  df  <- data.frame(age = 1:3, wt = 1:3)
  df2 <- set_var_label(df, age = "Age in years")
  expect_identical(attr(df2$age, "label"), "Age in years")
})

test_that("set_var_label() does not modify other metadata", {
  d <- make_design()
  d <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  d <- set_var_label(d, age = "Age in years")
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_var_label() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_var_label(list(x = 1), age = "A"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_var_label() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_var_label(d, age = "A", variable = "income"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_var_label() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_var_label(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_var_label() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_var_label(d, variable = c("age", "income"), label = "Age"),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_var_label() errors with surveycore_error_old_positional_setter for old form", {
  d <- make_design()
  expect_error(
    set_var_label(d, age, "Age in years"),
    class = "surveycore_error_old_positional_setter"
  )
})

test_that("set_var_label() errors with surveycore_error_label_not_scalar for non-character", {
  d <- make_design()
  expect_error(
    set_var_label(d, age = 123L),
    class = "surveycore_error_label_not_scalar"
  )
})

test_that("set_var_label() errors with surveycore_error_label_not_scalar for length > 1", {
  d <- make_design()
  expect_error(
    set_var_label(d, age = c("A", "B")),
    class = "surveycore_error_label_not_scalar"
  )
})

test_that("set_var_label() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_var_label(d, "Age in years"),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_var_label() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_var_label(d, zzz_missing = "Label"),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_var_label() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_var_label(d, age = "Age", zzz_missing = "Gone")
  )
  expect_identical(result@metadata@variable_labels[["age"]], "Age")
  expect_false("zzz_missing" %in% names(result@metadata@variable_labels))
})

test_that("set_var_label() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_var_label(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_var_label() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_var_label(list(x = 1), age = "A"))
})

test_that("snapshot: set_var_label() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_label(d, age = "A", variable = "income"))
})

test_that("snapshot: set_var_label() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_label(d))
})

test_that("snapshot: set_var_label() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_var_label(d, variable = c("age", "income"), label = "Age")
  )
})

test_that("snapshot: set_var_label() surveycore_error_old_positional_setter", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_label(d, age, "Age in years"))
})

test_that("snapshot: set_var_label() surveycore_error_label_not_scalar", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_label(d, age = 123L))
})

test_that("snapshot: set_var_label() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_var_label(d, zzz_missing = "Label"))
})

test_that("snapshot: set_var_label() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_var_label(d, variable = character(0)))
})


# ── set_val_labels() ──────────────────────────────────────────────────────────

test_that("set_val_labels() convention 1 sets labels for one variable", {
  d <- make_design()
  d <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_val_labels() convention 1 sets labels for multiple variables", {
  d <- make_design()
  d <- set_val_labels(
    d,
    sex = c(Male = 1L, Female = 2L),
    age = c("25" = 25L, "30" = 30L, "35" = 35L, "45" = 45L, "50" = 50L)
  )
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
  expect_false(is.null(d@metadata@value_labels[["age"]]))
})

test_that("set_val_labels() convention 2 (single named list in ...) sets labels", {
  d <- make_design()
  d <- set_val_labels(d, list(sex = c(Male = 1L, Female = 2L)))
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_val_labels() convention 3 (variable + labels list) sets labels", {
  d <- make_design()
  d <- set_val_labels(d, variable = "sex", labels = list(c(Male = 1L, Female = 2L)))
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_val_labels() convention 3 bare named vector accepted when length(variable) == 1", {
  d <- make_design()
  d <- set_val_labels(d, variable = "sex", labels = c(Male = 1L, Female = 2L))
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_val_labels() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_val_labels(d, sex = c(Male = 1L, Female = 2L)))
  expect_false(result$visible)
  expect_identical(
    result$value@metadata@value_labels[["sex"]],
    c(Male = 1L, Female = 2L)
  )
})

test_that("set_val_labels() NULL value deletes the entry", {
  d <- make_design()
  d <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  d <- set_val_labels(d, sex = NULL)
  expect_false("sex" %in% names(d@metadata@value_labels))
})

test_that("set_val_labels() data frame: sets attr(df$sex, 'labels')", {
  df  <- data.frame(sex = c(1L, 2L, 1L))
  df2 <- set_val_labels(df, sex = c(Male = 1L, Female = 2L))
  expect_identical(attr(df2$sex, "labels"), c(Male = 1L, Female = 2L))
})

test_that("set_val_labels() allows extra labels not present in data", {
  d <- make_design()
  expect_no_warning(
    set_val_labels(d, sex = c(Male = 1L, Female = 2L, Other = 3L))
  )
})

test_that("set_val_labels() errors with surveycore_error_labels_unnamed for unnamed vector", {
  d <- make_design()
  expect_error(
    set_val_labels(d, sex = c(1L, 2L)),
    class = "surveycore_error_labels_unnamed"
  )
})

test_that("set_val_labels() errors with surveycore_error_labels_unnamed for partially named", {
  d <- make_design()
  expect_error(
    set_val_labels(d, sex = c(Male = 1L, 2L)),
    class = "surveycore_error_labels_unnamed"
  )
})

test_that("set_val_labels() warns with surveycore_warning_missing_labels for partially labeled", {
  d <- make_design()
  expect_warning(
    set_val_labels(d, sex = c(Male = 1L)),
    class = "surveycore_warning_missing_labels"
  )
})

test_that("set_val_labels() warns with surveycore_warning_missing_labels on data frame", {
  df <- data.frame(sex = c(1L, 2L, 1L))
  expect_warning(
    set_val_labels(df, sex = c(Male = 1L)),
    class = "surveycore_warning_missing_labels"
  )
})

test_that("set_val_labels() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_val_labels(list(x = 1), sex = c(Male = 1L)),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_val_labels() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_val_labels(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_val_labels() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_val_labels(d, sex = c(Male = 1L), variable = "age"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_val_labels() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_val_labels(d, variable = c("sex", "age"), labels = list(c(Male = 1L))),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_val_labels() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_val_labels(d, c(-1L, -2L)),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_val_labels() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_val_labels(d, zzz_missing = c(A = 1L)),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_val_labels() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_val_labels(d, sex = c(Male = 1L, Female = 2L), zzz_missing = c(A = 1L))
  )
  expect_identical(result@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
  expect_false("zzz_missing" %in% names(result@metadata@value_labels))
})

test_that("set_val_labels() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_val_labels(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_val_labels() surveycore_error_labels_unnamed", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_val_labels(d, sex = c(1L, 2L)))
})

test_that("snapshot: set_val_labels() surveycore_warning_missing_labels", {
  d <- make_design()
  expect_snapshot(set_val_labels(d, sex = c(Male = 1L)))
})

test_that("snapshot: set_val_labels() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_val_labels(list(x = 1), sex = c(Male = 1L)))
})

test_that("snapshot: set_val_labels() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_val_labels(d))
})

test_that("snapshot: set_val_labels() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_val_labels(d, sex = c(Male = 1L), variable = "age"))
})

test_that("snapshot: set_val_labels() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_val_labels(d, variable = c("sex", "age"), labels = list(c(Male = 1L)))
  )
})

test_that("snapshot: set_val_labels() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_val_labels(d, zzz_missing = c(A = 1L)))
})

test_that("snapshot: set_val_labels() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_val_labels(d, variable = character(0)))
})


# ── set_question_preface() ────────────────────────────────────────────────────

test_that("set_question_preface() convention 1 sets preface for one variable", {
  d <- make_design()
  d <- set_question_preface(d, age = "How old are you?")
  expect_identical(d@metadata@question_prefaces[["age"]], "How old are you?")
})

test_that("set_question_preface() convention 1 sets prefaces for multiple variables", {
  d <- make_design()
  d <- set_question_preface(d, age = "In the past year...", income = "For your household...")
  expect_identical(d@metadata@question_prefaces[["age"]], "In the past year...")
  expect_identical(d@metadata@question_prefaces[["income"]], "For your household...")
})

test_that("set_question_preface() convention 2 (named char vector in ...) sets prefaces", {
  d <- make_design()
  d <- set_question_preface(d, c(age = "In the past year...", income = "For your household..."))
  expect_identical(d@metadata@question_prefaces[["age"]], "In the past year...")
  expect_identical(d@metadata@question_prefaces[["income"]], "For your household...")
})

test_that("set_question_preface() convention 3 (variable + preface) sets preface", {
  d <- make_design()
  d <- set_question_preface(d, variable = "age", preface = "How old are you?")
  expect_identical(d@metadata@question_prefaces[["age"]], "How old are you?")
})

test_that("set_question_preface() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_question_preface(d, age = "How old are you?"))
  expect_false(result$visible)
  expect_identical(
    result$value@metadata@question_prefaces[["age"]],
    "How old are you?"
  )
})

test_that("set_question_preface() NULL preface deletes the entry", {
  d <- make_design()
  d <- set_question_preface(d, age = "How old are you?")
  d <- set_question_preface(d, age = NULL)
  expect_false("age" %in% names(d@metadata@question_prefaces))
})

test_that("set_question_preface() data frame: sets attr(df$age, 'question_preface')", {
  df  <- data.frame(age = 1:3)
  df2 <- set_question_preface(df, age = "How old are you?")
  expect_identical(attr(df2$age, "question_preface"), "How old are you?")
})

test_that("set_question_preface() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_question_preface(list(x = 1), age = "Q text"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_question_preface() errors with surveycore_error_label_not_scalar for non-character", {
  d <- make_design()
  expect_error(
    set_question_preface(d, age = 123L),
    class = "surveycore_error_label_not_scalar"
  )
})

test_that("set_question_preface() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_question_preface(d, zzz_missing = "Q text"),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_question_preface() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_question_preface(d, age = "Q text", variable = "income"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_question_preface() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_question_preface(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_question_preface() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_question_preface(d, variable = c("age", "income"), preface = "Q"),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_question_preface() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_question_preface(d, "Q text"),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_question_preface() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_question_preface(d, age = "Q text", zzz_missing = "Q2")
  )
  expect_identical(result@metadata@question_prefaces[["age"]], "Q text")
  expect_false("zzz_missing" %in% names(result@metadata@question_prefaces))
})

test_that("set_question_preface() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_question_preface(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_question_preface() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_question_preface(list(x = 1), age = "Q text"))
})

test_that("snapshot: set_question_preface() surveycore_error_label_not_scalar", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_question_preface(d, age = 123L))
})

test_that("snapshot: set_question_preface() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_question_preface(d, age = "Q text", variable = "income"))
})

test_that("snapshot: set_question_preface() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_question_preface(d))
})

test_that("snapshot: set_question_preface() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_question_preface(d, variable = c("age", "income"), preface = "Q")
  )
})

test_that("snapshot: set_question_preface() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_question_preface(d, zzz_missing = "Q text"))
})

test_that("snapshot: set_question_preface() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_question_preface(d, variable = character(0)))
})


# ── set_var_note() ────────────────────────────────────────────────────────────

test_that("set_var_note() convention 1 sets note for one variable", {
  d <- make_design()
  d <- set_var_note(d, income = "Top-coded at 999999")
  expect_identical(d@metadata@notes[["income"]], "Top-coded at 999999")
})

test_that("set_var_note() convention 1 sets notes for multiple variables", {
  d <- make_design()
  d <- set_var_note(d, age = "Recoded from continuous.", income = "Top-coded at 999999.")
  expect_identical(d@metadata@notes[["age"]], "Recoded from continuous.")
  expect_identical(d@metadata@notes[["income"]], "Top-coded at 999999.")
})

test_that("set_var_note() convention 2 (named char vector in ...) sets notes", {
  d <- make_design()
  d <- set_var_note(d, c(age = "Recoded.", income = "Top-coded."))
  expect_identical(d@metadata@notes[["age"]], "Recoded.")
  expect_identical(d@metadata@notes[["income"]], "Top-coded.")
})

test_that("set_var_note() convention 3 (variable + note) sets note", {
  d <- make_design()
  d <- set_var_note(d, variable = "income", note = "Top-coded at 999999")
  expect_identical(d@metadata@notes[["income"]], "Top-coded at 999999")
})

test_that("set_var_note() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_var_note(d, income = "Top-coded at 999999"))
  expect_false(result$visible)
  expect_identical(result$value@metadata@notes[["income"]], "Top-coded at 999999")
})

test_that("set_var_note() NULL note deletes the entry", {
  d <- make_design()
  d <- set_var_note(d, income = "Top-coded at 999999")
  d <- set_var_note(d, income = NULL)
  expect_false("income" %in% names(d@metadata@notes))
})

test_that("set_var_note() data frame: sets attr(df$age, 'note')", {
  df  <- data.frame(age = 1:3)
  df2 <- set_var_note(df, age = "A note")
  expect_identical(attr(df2$age, "note"), "A note")
})

test_that("set_var_note() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_var_note(list(x = 1), age = "A note"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_var_note() errors with surveycore_error_label_not_scalar for non-character", {
  d <- make_design()
  expect_error(
    set_var_note(d, age = 123L),
    class = "surveycore_error_label_not_scalar"
  )
})

test_that("set_var_note() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_var_note(d, zzz_missing = "Some note"),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_var_note() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_var_note(d, age = "A note", variable = "income"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_var_note() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_var_note(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_var_note() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_var_note(d, variable = c("age", "income"), note = "A note"),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_var_note() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_var_note(d, "A note"),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_var_note() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_var_note(d, income = "Top-coded", zzz_missing = "Note")
  )
  expect_identical(result@metadata@notes[["income"]], "Top-coded")
  expect_false("zzz_missing" %in% names(result@metadata@notes))
})

test_that("set_var_note() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_var_note(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_var_note() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_var_note(list(x = 1), age = "A note"))
})

test_that("snapshot: set_var_note() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_note(d, age = "A note", variable = "income"))
})

test_that("snapshot: set_var_note() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_note(d))
})

test_that("snapshot: set_var_note() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_var_note(d, variable = c("age", "income"), note = "A note")
  )
})

test_that("snapshot: set_var_note() surveycore_error_label_not_scalar", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_note(d, age = 123L))
})

test_that("snapshot: set_var_note() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_var_note(d, zzz_missing = "Some note"))
})

test_that("snapshot: set_var_note() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_var_note(d, variable = character(0)))
})


# ── set_universe() ────────────────────────────────────────────────────────────

test_that("set_universe() convention 1 sets universe for one variable", {
  d <- make_design()
  d <- set_universe(d, age = "Adults 18+")
  expect_identical(d@metadata@universe[["age"]], "Adults 18+")
})

test_that("set_universe() convention 1 sets universe for multiple variables", {
  d <- make_design()
  d <- set_universe(d, age = "Adults 18+", income = "Employed adults")
  expect_identical(d@metadata@universe[["age"]], "Adults 18+")
  expect_identical(d@metadata@universe[["income"]], "Employed adults")
})

test_that("set_universe() convention 2 (named char vector in ...) sets universe", {
  d <- make_design()
  d <- set_universe(d, c(age = "Adults 18+", income = "Employed adults"))
  expect_identical(d@metadata@universe[["age"]], "Adults 18+")
  expect_identical(d@metadata@universe[["income"]], "Employed adults")
})

test_that("set_universe() convention 3 (variable + universe) sets universe", {
  d <- make_design()
  d <- set_universe(d, variable = "age", universe = "Adults 18+")
  expect_identical(d@metadata@universe[["age"]], "Adults 18+")
})

test_that("set_universe() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_universe(d, age = "Adults 18+"))
  expect_false(result$visible)
  expect_identical(result$value@metadata@universe[["age"]], "Adults 18+")
})

test_that("set_universe() NULL universe deletes the entry", {
  d <- make_design()
  d <- set_universe(d, age = "Adults 18+")
  d <- set_universe(d, age = NULL)
  expect_false("age" %in% names(d@metadata@universe))
})

test_that("set_universe() data frame: sets attr(df$age, 'universe')", {
  df  <- data.frame(age = 1:3)
  df2 <- set_universe(df, age = "Adults 18+")
  expect_identical(attr(df2$age, "universe"), "Adults 18+")
})

test_that("set_universe() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_universe(list(x = 1), age = "Adults 18+"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_universe() errors with surveycore_error_label_not_scalar for non-character", {
  d <- make_design()
  expect_error(
    set_universe(d, age = 123L),
    class = "surveycore_error_label_not_scalar"
  )
})

test_that("set_universe() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_universe(d, zzz_missing = "Some universe"),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_universe() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_universe(d, age = "Adults 18+", variable = "income"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_universe() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_universe(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_universe() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_universe(d, variable = c("age", "income"), universe = "Adults 18+"),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_universe() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_universe(d, "Adults 18+"),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_universe() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_universe(d, age = "Adults 18+", zzz_missing = "Some universe")
  )
  expect_identical(result@metadata@universe[["age"]], "Adults 18+")
  expect_false("zzz_missing" %in% names(result@metadata@universe))
})

test_that("set_universe() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_universe(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_universe() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_universe(list(x = 1), age = "Adults 18+"))
})

test_that("snapshot: set_universe() surveycore_error_label_not_scalar", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_universe(d, age = 123L))
})

test_that("snapshot: set_universe() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_universe(d, age = "Adults 18+", variable = "income"))
})

test_that("snapshot: set_universe() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_universe(d))
})

test_that("snapshot: set_universe() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_universe(d, variable = c("age", "income"), universe = "Adults 18+")
  )
})

test_that("snapshot: set_universe() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_universe(d, zzz_missing = "Some universe"))
})

test_that("snapshot: set_universe() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_universe(d, variable = character(0)))
})


# ── set_missing_codes() ───────────────────────────────────────────────────────

test_that("set_missing_codes() convention 1 sets codes for one variable", {
  d <- make_design()
  d <- set_missing_codes(d, age = c("Missing" = -1L, "Refused" = -2L))
  expect_identical(d@metadata@missing_codes[["age"]], c("Missing" = -1L, "Refused" = -2L))
})

test_that("set_missing_codes() convention 1 sets codes for multiple variables", {
  d <- make_design()
  d <- set_missing_codes(
    d,
    age    = c("Missing" = -1L),
    income = c("Refused" = -2L)
  )
  expect_identical(d@metadata@missing_codes[["age"]], c("Missing" = -1L))
  expect_identical(d@metadata@missing_codes[["income"]], c("Refused" = -2L))
})

test_that("set_missing_codes() convention 2 (single named list in ...) sets codes", {
  d <- make_design()
  d <- set_missing_codes(d, list(age = c("Missing" = -1L)))
  expect_identical(d@metadata@missing_codes[["age"]], c("Missing" = -1L))
})

test_that("set_missing_codes() convention 3 (variable + codes list) sets codes", {
  d <- make_design()
  d <- set_missing_codes(d, variable = "age", codes = list(c("Missing" = -1L)))
  expect_identical(d@metadata@missing_codes[["age"]], c("Missing" = -1L))
})

test_that("set_missing_codes() convention 3 bare named vector accepted when length(variable) == 1", {
  d <- make_design()
  d <- set_missing_codes(d, variable = "age", codes = c("Missing" = -1L))
  expect_identical(d@metadata@missing_codes[["age"]], c("Missing" = -1L))
})

test_that("set_missing_codes() returns x invisibly", {
  d      <- make_design()
  result <- withVisible(set_missing_codes(d, age = c("Missing" = -1L)))
  expect_false(result$visible)
  expect_identical(result$value@metadata@missing_codes[["age"]], c("Missing" = -1L))
})

test_that("set_missing_codes() NULL codes deletes the entry", {
  d <- make_design()
  d <- set_missing_codes(d, age = c("Missing" = -1L))
  d <- set_missing_codes(d, age = NULL)
  expect_false("age" %in% names(d@metadata@missing_codes))
})

test_that("set_missing_codes() data frame: sets attr(df$age, 'missing_codes')", {
  df  <- data.frame(age = c(1L, -1L, 2L))
  df2 <- set_missing_codes(df, age = c("Missing" = -1L))
  expect_identical(attr(df2$age, "missing_codes"), c("Missing" = -1L))
})

test_that("set_missing_codes() errors with surveycore_error_missing_codes_not_vector for list entry", {
  d <- make_design()
  expect_error(
    set_missing_codes(d, age = list("bad")),
    class = "surveycore_error_missing_codes_not_vector"
  )
})

test_that("set_missing_codes() warns with surveycore_warning_var_not_found for missing variable", {
  d <- make_design()
  expect_warning(
    set_missing_codes(d, zzz_missing = c("Missing" = -1L)),
    class = "surveycore_warning_var_not_found"
  )
})

test_that("set_missing_codes() errors with surveycore_error_not_survey_or_df for list x", {
  expect_error(
    set_missing_codes(list(x = 1), age = c("Missing" = -1L)),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("set_missing_codes() errors with surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_error(
    set_missing_codes(d, age = c("Missing" = -1L), variable = "income"),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that("set_missing_codes() errors with surveycore_error_setter_empty", {
  d <- make_design()
  expect_error(
    set_missing_codes(d),
    class = "surveycore_error_setter_empty"
  )
})

test_that("set_missing_codes() errors with surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_error(
    set_missing_codes(d, variable = c("age", "income"), codes = list(c("Missing" = -1L))),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that("set_missing_codes() errors with surveycore_error_setter_mixed_dots for unnamed ...", {
  d <- make_design()
  expect_error(
    set_missing_codes(d, c(-1L, -2L)),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that("set_missing_codes() skips missing var but still sets valid vars", {
  d <- make_design()
  result <- suppressWarnings(
    set_missing_codes(d, age = c("Missing" = -1L), zzz_missing = c("Missing" = -1L))
  )
  expect_identical(result@metadata@missing_codes[["age"]], c("Missing" = -1L))
  expect_false("zzz_missing" %in% names(result@metadata@missing_codes))
})

test_that("set_missing_codes() warns with surveycore_warning_setter_empty_variables for variable = character(0)", {
  d <- make_design()
  expect_warning(
    set_missing_codes(d, variable = character(0)),
    class = "surveycore_warning_setter_empty_variables"
  )
})

test_that("snapshot: set_missing_codes() surveycore_error_missing_codes_not_vector", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_missing_codes(d, age = list("bad")))
})

test_that("snapshot: set_missing_codes() surveycore_error_not_survey_or_df", {
  expect_snapshot(error = TRUE, set_missing_codes(list(x = 1), age = c("Missing" = -1L)))
})

test_that("snapshot: set_missing_codes() surveycore_error_setter_ambiguous", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_missing_codes(d, age = c("Missing" = -1L), variable = "income")
  )
})

test_that("snapshot: set_missing_codes() surveycore_error_setter_empty", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_missing_codes(d))
})

test_that("snapshot: set_missing_codes() surveycore_error_setter_mismatched_lengths", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_missing_codes(d, variable = c("age", "income"), codes = list(c("Missing" = -1L)))
  )
})

test_that("snapshot: set_missing_codes() surveycore_warning_var_not_found", {
  d <- make_design()
  expect_snapshot(set_missing_codes(d, zzz_missing = c("Missing" = -1L)))
})

test_that("snapshot: set_missing_codes() surveycore_warning_setter_empty_variables", {
  d <- make_design()
  expect_snapshot(set_missing_codes(d, variable = character(0)))
})


# ── Removed plural setters ────────────────────────────────────────────────────

test_that("set_variable_labels() is removed — calling it errors with 'could not find function'", {
  expect_error(
    set_variable_labels(make_design(), age = "A"),
    regexp = "could not find function"
  )
})

test_that("set_value_labels() is removed — calling it errors with 'could not find function'", {
  expect_error(
    set_value_labels(make_design(), sex = c(Male = 1L)),
    regexp = "could not find function"
  )
})

test_that("set_question_prefaces() is removed — calling it errors with 'could not find function'", {
  expect_error(
    set_question_prefaces(make_design(), age = "Q"),
    regexp = "could not find function"
  )
})

test_that("set_variable_notes() is removed — calling it errors with 'could not find function'", {
  expect_error(
    set_variable_notes(make_design(), age = "note"),
    regexp = "could not find function"
  )
})


# ── .extract_haven_metadata() ────────────────────────────────────────────────

test_that(".extract_haven_metadata() returns empty survey_metadata when no attrs", {
  df  <- data.frame(x = 1:3, y = letters[1:3])
  out <- surveycore:::.extract_haven_metadata(df)
  expect_true(S7::S7_inherits(out, survey_metadata))
  expect_identical(out@variable_labels, list())
  expect_identical(out@value_labels,    list())
})

test_that(".extract_haven_metadata() extracts haven variable labels", {
  df        <- data.frame(age = 1:3, sex = c(1L, 2L, 1L))
  attr(df$age, "label") <- "Age in years"
  attr(df$sex, "label") <- "Biological sex"
  out <- surveycore:::.extract_haven_metadata(df)
  expect_identical(out@variable_labels[["age"]], "Age in years")
  expect_identical(out@variable_labels[["sex"]], "Biological sex")
})

test_that(".extract_haven_metadata() extracts haven value labels", {
  df        <- data.frame(sex = c(1L, 2L))
  attr(df$sex, "labels") <- c(Male = 1L, Female = 2L)
  out <- surveycore:::.extract_haven_metadata(df)
  expect_identical(out@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that(".extract_haven_metadata() silently ignores zero-length label strings", {
  df        <- data.frame(x = 1:3)
  attr(df$x, "label") <- ""  # empty string — should be ignored
  out <- surveycore:::.extract_haven_metadata(df)
  expect_identical(out@variable_labels, list())
})

test_that(".extract_haven_metadata() preserves NA keys in value labels", {
  df        <- data.frame(x = c(1L, 2L, NA_integer_))
  lbl       <- c("Yes" = 1L, "No" = 2L, "Unknown" = NA_integer_)
  attr(df$x, "labels") <- lbl
  out <- surveycore:::.extract_haven_metadata(df)
  # NA key should be preserved
  expect_true("Unknown" %in% names(out@value_labels[["x"]]))
  expect_true(any(is.na(out@value_labels[["x"]])))
})

test_that(".extract_haven_metadata() does not store empty labels vectors", {
  df        <- data.frame(x = 1:3)
  attr(df$x, "labels") <- c()  # empty — should not be stored
  out <- surveycore:::.extract_haven_metadata(df)
  expect_null(out@value_labels[["x"]])
})

test_that(".extract_haven_metadata() works with make_survey_data(with_labels=TRUE)", {
  df  <- make_survey_data(n = 50L, seed = 1L, with_labels = TRUE)
  out <- surveycore:::.extract_haven_metadata(df)
  expect_true(S7::S7_inherits(out, survey_metadata))
  expect_identical(out@variable_labels[["y1"]], "Outcome variable 1 (continuous)")
  expect_identical(out@variable_labels[["y2"]], "Outcome variable 2 (continuous)")
  expect_identical(out@value_labels[["y3"]],    c("No" = 0L, "Yes" = 1L))
})


# ── Edge cases ────────────────────────────────────────────────────────────────

test_that("metadata operations do not modify @data", {
  d    <- make_design()
  orig <- d@data
  d    <- set_var_label(d, age = "Age in years")
  d    <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  expect_identical(d@data, orig)
})

test_that("metadata operations do not corrupt other metadata properties", {
  d <- make_design()
  d <- set_var_label(d, age = "Age label")
  d <- set_val_labels(d, sex = c(Male = 1L, Female = 2L))
  d <- set_question_preface(d, income = "Preface text")
  d <- set_var_note(d, wt = "A note")

  # Each property holds only what was set
  expect_identical(d@metadata@variable_labels[["age"]], "Age label")
  expect_null(d@metadata@variable_labels[["sex"]])
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
  expect_null(d@metadata@value_labels[["age"]])
  expect_identical(d@metadata@question_prefaces[["income"]], "Preface text")
  expect_null(d@metadata@question_prefaces[["age"]])
  expect_identical(d@metadata@notes[["wt"]], "A note")
  expect_null(d@metadata@notes[["age"]])
})

test_that("set_val_labels() does not warn for character value labels", {
  df <- data.frame(group = c("A", "B", "C"), wt = c(1, 1, 1))
  d  <- survey_taylor(
    data = df,
    variables = list(
      ids = NULL, weights = "wt", strata = NULL,
      fpc = NULL, nest = FALSE, probs_provided = FALSE
    )
  )
  expect_no_warning(
    set_val_labels(d, group = c("Group A" = "A", "Group B" = "B", "Group C" = "C"))
  )
})

test_that("set_var_label() and extract_var_label() roundtrip for design col (wt)", {
  d <- make_design()
  d <- set_var_label(d, wt = "Survey weight")
  expect_identical(extract_var_label(d, wt), "Survey weight")
})


# ── Coverage: .validate_val_labels() strict = TRUE path ──────────────────────

test_that(".validate_val_labels() errors in strict mode with unlabeled values [direct]", {
  var    <- c(1L, 2L, 3L, 1L, 2L)    # value 3 is unlabeled
  labels <- c(a = 1L, b = 2L)
  expect_error(
    surveycore:::.validate_val_labels(var, labels, var_name = "x", strict = TRUE),
    class = "surveycore_error_missing_labels"
  )
})


# ── survey_weighting_history() ────────────────────────────────────────────────

test_that("survey_weighting_history() returns list() when no history set", {
  d <- make_design()
  expect_identical(survey_weighting_history(d), list())
})

test_that("survey_weighting_history() returns the history list when set", {
  df <- make_survey_data(n = 100L, seed = 201L)
  history <- list(list(step = 1L, operation = "raking"))
  attr(df, "weighting_history") <- history
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_identical(survey_weighting_history(d), history)
})


# ── .check_is_survey_or_df() ─────────────────────────────────────────────────

test_that(".check_is_survey_or_df() returns invisibly NULL for a survey_taylor object", {
  d <- make_design()
  result <- withVisible(surveycore:::.check_is_survey_or_df(d))
  expect_null(result$value)
  expect_false(result$visible)
})

test_that(".check_is_survey_or_df() returns invisibly NULL for a plain data.frame", {
  df <- data.frame(x = 1:3)
  result <- withVisible(surveycore:::.check_is_survey_or_df(df))
  expect_null(result$value)
  expect_false(result$visible)
})

test_that(".check_is_survey_or_df() errors with surveycore_error_not_survey_or_df for list input", {
  expect_error(
    surveycore:::.check_is_survey_or_df(list(x = 1)),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that(".check_is_survey_or_df() errors with surveycore_error_not_survey_or_df for character input", {
  expect_error(
    surveycore:::.check_is_survey_or_df("not a survey"),
    class = "surveycore_error_not_survey_or_df"
  )
})

test_that("snapshot: .check_is_survey_or_df() surveycore_error_not_survey_or_df for list input", {
  expect_snapshot(error = TRUE, surveycore:::.check_is_survey_or_df(list(x = 1)))
})


# ── .parse_setter_input() ────────────────────────────────────────────────────

test_that(".parse_setter_input() convention 1 (named ...) returns correct named list", {
  result <- surveycore:::.parse_setter_input(
    dots             = list(age = "Age in years", income = "Annual income"),
    variable         = NULL,
    content          = NULL,
    content_arg_name = "label",
    content_type     = "scalar",
    fn_name          = "set_var_label"
  )
  expect_identical(result, list(age = "Age in years", income = "Annual income"))
})

test_that(".parse_setter_input() convention 1 with !!! splicing returns correct named list", {
  lbls <- list(age = "Age in years", income = "Annual income")
  dots <- rlang::list2(!!!lbls)
  result <- surveycore:::.parse_setter_input(
    dots             = dots,
    variable         = NULL,
    content          = NULL,
    content_arg_name = "label",
    content_type     = "scalar",
    fn_name          = "set_var_label"
  )
  expect_identical(result, list(age = "Age in years", income = "Annual income"))
})

test_that(".parse_setter_input() convention 2 scalar (single named char vector) returns correct named list", {
  # Simulates: set_var_label(svy, c(age = "Age", income = "Annual income"))
  dots <- list(c(age = "Age in years", income = "Annual income"))
  result <- surveycore:::.parse_setter_input(
    dots             = dots,
    variable         = NULL,
    content          = NULL,
    content_arg_name = "label",
    content_type     = "scalar",
    fn_name          = "set_var_label"
  )
  expect_identical(result, list(age = "Age in years", income = "Annual income"))
})

test_that(".parse_setter_input() convention 2 vector (single named list) returns correct named list", {
  # Simulates: set_val_labels(svy, list(sex = c(Male=1L), region = c(N=1L)))
  dots <- list(list(sex = c(Male = 1L, Female = 2L), region = c(N = 1L, S = 2L)))
  result <- surveycore:::.parse_setter_input(
    dots             = dots,
    variable         = NULL,
    content          = NULL,
    content_arg_name = "labels",
    content_type     = "vector",
    fn_name          = "set_val_labels"
  )
  expect_identical(
    result,
    list(sex = c(Male = 1L, Female = 2L), region = c(N = 1L, S = 2L))
  )
})

test_that(".parse_setter_input() convention 3 (variable + content) returns correct named list", {
  result <- surveycore:::.parse_setter_input(
    dots             = list(),
    variable         = c("age", "income"),
    content          = c("Age in years", "Annual income"),
    content_arg_name = "label",
    content_type     = "scalar",
    fn_name          = "set_var_label"
  )
  expect_identical(result, list(age = "Age in years", income = "Annual income"))
})

test_that(".parse_setter_input() convention 3 length mismatch errors with surveycore_error_setter_mismatched_lengths", {
  expect_error(
    surveycore:::.parse_setter_input(
      dots             = list(),
      variable         = c("age", "income"),
      content          = c("Age in years"),
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    ),
    class = "surveycore_error_setter_mismatched_lengths"
  )
})

test_that(".parse_setter_input() both ... and variable errors with surveycore_error_setter_ambiguous", {
  expect_error(
    surveycore:::.parse_setter_input(
      dots             = list(age = "Age"),
      variable         = "income",
      content          = "Annual income",
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    ),
    class = "surveycore_error_setter_ambiguous"
  )
})

test_that(".parse_setter_input() neither ... nor variable errors with surveycore_error_setter_empty", {
  expect_error(
    surveycore:::.parse_setter_input(
      dots             = list(),
      variable         = NULL,
      content          = NULL,
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    ),
    class = "surveycore_error_setter_empty"
  )
})

test_that(".parse_setter_input() unnamed ... elements errors with surveycore_error_setter_mixed_dots", {
  # Unnamed character vector (not a named vector) in ...
  dots <- list(c("Age in years", "Annual income"))
  expect_error(
    surveycore:::.parse_setter_input(
      dots             = dots,
      variable         = NULL,
      content          = NULL,
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    ),
    class = "surveycore_error_setter_mixed_dots"
  )
})

test_that(".parse_setter_input() NULL values pass through in returned list", {
  result <- surveycore:::.parse_setter_input(
    dots             = list(age = NULL, income = "Annual income"),
    variable         = NULL,
    content          = NULL,
    content_arg_name = "label",
    content_type     = "scalar",
    fn_name          = "set_var_label"
  )
  expect_null(result[["age"]])
  expect_identical(result[["income"]], "Annual income")
})

test_that("snapshot: surveycore_error_setter_mismatched_lengths message", {
  expect_snapshot(
    error = TRUE,
    surveycore:::.parse_setter_input(
      dots             = list(),
      variable         = c("age", "income"),
      content          = c("Age in years"),
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    )
  )
})

test_that("snapshot: surveycore_error_setter_ambiguous message", {
  expect_snapshot(
    error = TRUE,
    surveycore:::.parse_setter_input(
      dots             = list(age = "Age"),
      variable         = "income",
      content          = "Annual income",
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    )
  )
})

test_that("snapshot: surveycore_error_setter_empty message", {
  expect_snapshot(
    error = TRUE,
    surveycore:::.parse_setter_input(
      dots             = list(),
      variable         = NULL,
      content          = NULL,
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    )
  )
})

test_that("snapshot: surveycore_error_setter_mixed_dots message", {
  dots <- list(c("Age in years", "Annual income"))
  expect_snapshot(
    error = TRUE,
    surveycore:::.parse_setter_input(
      dots             = dots,
      variable         = NULL,
      content          = NULL,
      content_arg_name = "label",
      content_type     = "scalar",
      fn_name          = "set_var_label"
    )
  )
})


# ── .resolve_vars() ───────────────────────────────────────────────────────────

test_that(".resolve_vars() with empty var_exprs returns all column names", {
  d <- make_design()
  result <- surveycore:::.resolve_vars(d, var_exprs = list())
  expect_identical(result, names(d@data))
})

test_that(".resolve_vars() with specified names returns just those names", {
  d <- make_design()
  var_exprs <- rlang::quos(age, income)
  result <- surveycore:::.resolve_vars(d, var_exprs = var_exprs)
  expect_identical(result, c("age", "income"))
})

test_that(".resolve_vars() warns with surveycore_warning_var_not_found for missing var", {
  d <- make_design()
  var_exprs <- rlang::quos(age, zzz_missing)
  expect_warning(
    surveycore:::.resolve_vars(d, var_exprs = var_exprs),
    class = "surveycore_warning_var_not_found"
  )
})

test_that(".resolve_vars() returns only valid names after warning", {
  d <- make_design()
  var_exprs <- rlang::quos(age, zzz_missing)
  result <- suppressWarnings(
    surveycore:::.resolve_vars(d, var_exprs = var_exprs)
  )
  expect_identical(result, "age")
})

test_that("snapshot: .resolve_vars() surveycore_warning_var_not_found message", {
  d <- make_design()
  var_exprs <- rlang::quos(zzz_missing)
  expect_snapshot(
    surveycore:::.resolve_vars(d, var_exprs = var_exprs)
  )
})


# ── .format_scalar_result() ───────────────────────────────────────────────────

test_that(".format_scalar_result() format = 'named_vector' returns named character vector", {
  result_list <- list(age = "Age in years", income = "Annual income")
  result <- surveycore:::.format_scalar_result(
    result_list, format = "named_vector", col_name = "label", empty_value = NULL
  )
  expect_identical(result, c(age = "Age in years", income = "Annual income"))
})

test_that(".format_scalar_result() format = 'list' returns named list", {
  result_list <- list(age = "Age in years", income = "Annual income")
  result <- surveycore:::.format_scalar_result(
    result_list, format = "list", col_name = "label", empty_value = NULL
  )
  expect_identical(result, list(age = "Age in years", income = "Annual income"))
})

test_that(".format_scalar_result() format = 'data_frame' returns tibble with variable/label columns", {
  result_list <- list(age = "Age in years", income = "Annual income")
  result <- surveycore:::.format_scalar_result(
    result_list, format = "data_frame", col_name = "label", empty_value = NULL
  )
  expect_s3_class(result, "tbl_df")
  expect_identical(names(result), c("variable", "label"))
  expect_identical(result$variable, c("age", "income"))
  expect_identical(result$label, c("Age in years", "Annual income"))
})

test_that(".format_scalar_result() fill = NULL omits entries with NULL values", {
  result_list <- list(age = "Age in years", income = NULL)
  result <- surveycore:::.format_scalar_result(
    result_list, format = "named_vector", col_name = "label", empty_value = NULL
  )
  expect_identical(result, c(age = "Age in years"))
  expect_false("income" %in% names(result))
})

test_that(".format_scalar_result() fill = NA_character_ includes entries with NA", {
  result_list <- list(age = "Age in years", income = NULL)
  result <- surveycore:::.format_scalar_result(
    result_list, format = "named_vector", col_name = "label",
    empty_value = NA_character_
  )
  expect_identical(result, c(age = "Age in years", income = NA_character_))
})


# ── .format_list_result() ─────────────────────────────────────────────────────

test_that(".format_list_result() format = 'list' returns named list", {
  result_list <- list(
    sex    = c(Male = 1L, Female = 2L),
    region = c(N = 1L, S = 2L)
  )
  result <- surveycore:::.format_list_result(
    result_list, format = "list", fn_name = "extract_val_labels"
  )
  expect_identical(result, result_list)
})

test_that(".format_list_result() format = 'data_frame' returns long tibble", {
  result_list <- list(sex = c(Male = 1L, Female = 2L))
  result <- surveycore:::.format_list_result(
    result_list, format = "data_frame", fn_name = "extract_val_labels"
  )
  expect_s3_class(result, "tbl_df")
  expect_identical(names(result), c("variable", "label", "value"))
  expect_equal(nrow(result), 2L)
  expect_identical(result$variable, c("sex", "sex"))
  expect_identical(result$label, c("Male", "Female"))
  expect_identical(result$value, c("1", "2"))
})

test_that(".format_list_result() format = 'named_vector' errors with surveycore_error_format_invalid", {
  result_list <- list(sex = c(Male = 1L, Female = 2L))
  expect_error(
    surveycore:::.format_list_result(
      result_list, format = "named_vector", fn_name = "extract_val_labels"
    ),
    class = "surveycore_error_format_invalid"
  )
})

test_that("snapshot: .format_list_result() surveycore_error_format_invalid message", {
  result_list <- list(sex = c(Male = 1L, Female = 2L))
  expect_snapshot(
    error = TRUE,
    surveycore:::.format_list_result(
      result_list, format = "named_vector", fn_name = "extract_val_labels"
    )
  )
})
