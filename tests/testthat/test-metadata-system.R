# tests/testthat/test-metadata-system.R
#
# Tests for R/01-metadata-system.R
# Error/warning coverage map (plans/error-messages.md):
#   Row 27: surveycore_error_var_not_found   — singular setters
#   Row 28: surveycore_error_vars_not_found  — plural setters
#   Row 29: surveycore_error_labels_unnamed  — set_val_labels / set_value_labels
#   Row 30: surveycore_warning_missing_labels — set_val_labels / set_value_labels

# ── Test fixture ──────────────────────────────────────────────────────────────

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


# ── extract_var_label() ───────────────────────────────────────────────────────

test_that("extract_var_label() returns NULL when no label set", {
  d <- make_design()
  expect_null(extract_var_label(d, age))
})

test_that("extract_var_label() returns the label after set_var_label()", {
  d <- make_design()
  d <- set_var_label(d, age, "Age in years")
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
  d <- set_val_labels(d, sex, c(Male = 1L, Female = 2L))
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
  d <- set_question_preface(d, age, "In the past 12 months, how old were you?")
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
  d <- set_var_note(d, income, "Imputed for 3% of respondents.")
  expect_identical(
    extract_var_note(d, income),
    "Imputed for 3% of respondents."
  )
})


# ── set_var_label() ───────────────────────────────────────────────────────────

test_that("set_var_label() stores a variable label and returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_var_label(d, age, "Age in years"))
  expect_false(result$visible)
  expect_identical(result$value@metadata@variable_labels[["age"]], "Age in years")
})

test_that("set_var_label() is pipe-friendly", {
  d <- make_design() |>
    set_var_label(age, "Age in years") |>
    set_var_label(sex, "Biological sex")
  expect_identical(d@metadata@variable_labels[["age"]], "Age in years")
  expect_identical(d@metadata@variable_labels[["sex"]], "Biological sex")
})

test_that("set_var_label() does not modify other metadata", {
  d <- make_design()
  d <- set_val_labels(d, sex, c(Male = 1L, Female = 2L))
  d <- set_var_label(d, age, "Age in years")
  # Value labels for sex must be unchanged
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
})

test_that("set_var_label() errors on variable not in data [row 27]", {
  d <- make_design()
  expect_error(
    set_var_label(d, zzz_missing, "Label"),
    class = "surveycore_error_var_not_found"
  )
})

test_that("set_var_label() error snapshot [row 27]", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_var_label(d, zzz_missing, "Label"))
})

test_that("set_var_label() overwrites an existing label", {
  d <- make_design()
  d <- set_var_label(d, age, "Original label")
  d <- set_var_label(d, age, "Updated label")
  expect_identical(extract_var_label(d, age), "Updated label")
})


# ── set_val_labels() ──────────────────────────────────────────────────────────

test_that("set_val_labels() stores value labels and returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_val_labels(d, sex, c(Male = 1L, Female = 2L)))
  expect_false(result$visible)
  expect_identical(
    result$value@metadata@value_labels[["sex"]],
    c(Male = 1L, Female = 2L)
  )
})

test_that("set_val_labels() allows extra labels not present in data", {
  d <- make_design()
  # sex has only 1 and 2 in data; extra label "Other = 3L" is OK
  expect_no_warning(
    set_val_labels(d, sex, c(Male = 1L, Female = 2L, Other = 3L))
  )
})

test_that("set_val_labels() warns when some data values lack a label [row 30]", {
  d <- make_design()
  # sex = 1 and 2 in data; only labelling 1
  expect_warning(
    set_val_labels(d, sex, c(Male = 1L)),
    class = "surveycore_warning_missing_labels"
  )
})

test_that("set_val_labels() warning snapshot [row 30]", {
  d <- make_design()
  expect_snapshot(set_val_labels(d, sex, c(Male = 1L)))
})

test_that("set_val_labels() errors on variable not in data [row 27]", {
  d <- make_design()
  expect_error(
    set_val_labels(d, zzz_missing, c(A = 1L)),
    class = "surveycore_error_var_not_found"
  )
})

test_that("set_val_labels() errors on unnamed labels [row 29]", {
  d <- make_design()
  expect_error(
    set_val_labels(d, sex, c(1L, 2L)),
    class = "surveycore_error_labels_unnamed"
  )
})

test_that("set_val_labels() error snapshot for unnamed labels [row 29]", {
  d <- make_design()
  expect_snapshot(error = TRUE, set_val_labels(d, sex, c(1L, 2L)))
})

test_that("set_val_labels() errors on partially named labels [row 29]", {
  d <- make_design()
  expect_error(
    set_val_labels(d, sex, c(Male = 1L, 2L)),
    class = "surveycore_error_labels_unnamed"
  )
})


# ── set_question_preface() ────────────────────────────────────────────────────

test_that("set_question_preface() stores preface and returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_question_preface(d, age, "How old are you?"))
  expect_false(result$visible)
  expect_identical(
    result$value@metadata@question_prefaces[["age"]],
    "How old are you?"
  )
})

test_that("set_question_preface() errors on variable not in data [row 27]", {
  d <- make_design()
  expect_error(
    set_question_preface(d, zzz_missing, "Q text"),
    class = "surveycore_error_var_not_found"
  )
})


# ── set_var_note() ────────────────────────────────────────────────────────────

test_that("set_var_note() stores a note and returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_var_note(d, income, "Top-coded at 999999"))
  expect_false(result$visible)
  expect_identical(
    result$value@metadata@notes[["income"]],
    "Top-coded at 999999"
  )
})

test_that("set_var_note() errors on variable not in data [row 27]", {
  d <- make_design()
  expect_error(
    set_var_note(d, zzz_missing, "Some note"),
    class = "surveycore_error_var_not_found"
  )
})


# ── set_variable_labels() ────────────────────────────────────────────────────

test_that("set_variable_labels() sets multiple labels and returns invisibly", {
  d      <- make_design()
  result <- withVisible(
    set_variable_labels(
      d,
      age    = "Age in years",
      sex    = "Biological sex",
      income = "Annual income"
    )
  )
  expect_false(result$visible)
  d2 <- result$value
  expect_identical(d2@metadata@variable_labels[["age"]],    "Age in years")
  expect_identical(d2@metadata@variable_labels[["sex"]],    "Biological sex")
  expect_identical(d2@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_variable_labels() supports list splicing with !!!", {
  d    <- make_design()
  lbls <- list(age = "Age in years", income = "Annual income")
  d    <- set_variable_labels(d, !!!lbls)
  expect_identical(d@metadata@variable_labels[["age"]],    "Age in years")
  expect_identical(d@metadata@variable_labels[["income"]], "Annual income")
})

test_that("set_variable_labels() errors when any variable is missing [row 28]", {
  d <- make_design()
  expect_error(
    set_variable_labels(d, age = "Age", zzz_missing = "Gone"),
    class = "surveycore_error_vars_not_found"
  )
})

test_that("set_variable_labels() error snapshot [row 28]", {
  d <- make_design()
  expect_snapshot(
    error = TRUE,
    set_variable_labels(d, age = "Age", zzz_missing = "Gone")
  )
})

test_that("set_variable_labels() errors when ALL variables are missing [row 28]", {
  d <- make_design()
  expect_error(
    set_variable_labels(d, zzz1 = "A", zzz2 = "B"),
    class = "surveycore_error_vars_not_found"
  )
})


# ── set_value_labels() ───────────────────────────────────────────────────────

test_that("set_value_labels() sets value labels for multiple variables", {
  d <- make_design()
  d <- set_value_labels(
    d,
    sex = c(Male = 1L, Female = 2L),
    age = c("25" = 25L, "30" = 30L, "35" = 35L, "45" = 45L, "50" = 50L)
  )
  expect_identical(d@metadata@value_labels[["sex"]], c(Male = 1L, Female = 2L))
  expect_true(!is.null(d@metadata@value_labels[["age"]]))
})

test_that("set_value_labels() errors when a variable is missing [row 28]", {
  d <- make_design()
  expect_error(
    set_value_labels(d, sex = c(Male = 1L), zzz = c(A = 1L)),
    class = "surveycore_error_vars_not_found"
  )
})

test_that("set_value_labels() errors on unnamed labels [row 29]", {
  d <- make_design()
  expect_error(
    set_value_labels(d, sex = c(1L, 2L)),
    class = "surveycore_error_labels_unnamed"
  )
})

test_that("set_value_labels() warns on missing labels [row 30]", {
  d <- make_design()
  expect_warning(
    set_value_labels(d, sex = c(Male = 1L)),
    class = "surveycore_warning_missing_labels"
  )
})

test_that("set_value_labels() returns invisibly", {
  d      <- make_design()
  result <- withVisible(
    set_value_labels(d, sex = c(Male = 1L, Female = 2L))
  )
  expect_false(result$visible)
})


# ── set_question_prefaces() ──────────────────────────────────────────────────

test_that("set_question_prefaces() sets prefaces for multiple variables", {
  d <- make_design()
  d <- set_question_prefaces(
    d,
    age    = "In the past year...",
    income = "For your household..."
  )
  expect_identical(d@metadata@question_prefaces[["age"]],    "In the past year...")
  expect_identical(d@metadata@question_prefaces[["income"]], "For your household...")
})

test_that("set_question_prefaces() errors when a variable is missing [row 28]", {
  d <- make_design()
  expect_error(
    set_question_prefaces(d, age = "Q text", zzz_missing = "Q text"),
    class = "surveycore_error_vars_not_found"
  )
})

test_that("set_question_prefaces() returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_question_prefaces(d, age = "Q text"))
  expect_false(result$visible)
})


# ── set_variable_notes() ─────────────────────────────────────────────────────

test_that("set_variable_notes() sets notes for multiple variables", {
  d <- make_design()
  d <- set_variable_notes(
    d,
    age    = "Recoded from continuous to 5-year bins.",
    income = "Top-coded at 999999."
  )
  expect_identical(d@metadata@notes[["age"]],    "Recoded from continuous to 5-year bins.")
  expect_identical(d@metadata@notes[["income"]], "Top-coded at 999999.")
})

test_that("set_variable_notes() errors when a variable is missing [row 28]", {
  d <- make_design()
  expect_error(
    set_variable_notes(d, age = "Note", zzz_missing = "Note"),
    class = "surveycore_error_vars_not_found"
  )
})

test_that("set_variable_notes() returns invisibly", {
  d      <- make_design()
  result <- withVisible(set_variable_notes(d, age = "A note"))
  expect_false(result$visible)
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
  d    <- set_var_label(d, age, "Age in years")
  d    <- set_val_labels(d, sex, c(Male = 1L, Female = 2L))
  expect_identical(d@data, orig)
})

test_that("metadata operations do not corrupt other metadata properties", {
  d <- make_design()
  d <- set_var_label(d, age, "Age label")
  d <- set_val_labels(d, sex, c(Male = 1L, Female = 2L))
  d <- set_question_preface(d, income, "Preface text")
  d <- set_var_note(d, wt, "A note")

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
    set_val_labels(d, group, c("Group A" = "A", "Group B" = "B", "Group C" = "C"))
  )
})

test_that("set_var_label() and extract_var_label() roundtrip for design col (wt)", {
  d <- make_design()
  d <- set_var_label(d, wt, "Survey weight")
  expect_identical(extract_var_label(d, wt), "Survey weight")
})
