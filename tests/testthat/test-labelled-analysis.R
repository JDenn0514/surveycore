# tests/testthat/test-labelled-analysis.R
#
# Every analysis entry point, run on a design whose columns arrived carrying the
# haven labelled class, compared against the identical design whose columns
# arrived without it. Source: the `data` property setter in R/core-classes.R and
# the two strip helpers in R/utils.R.
#
# The contract under test is equality, not a tolerance: the setter removes a
# class attribute and changes no value, so every estimate must come out bit for
# bit the same. Rows therefore use expect_identical(), or
# expect_equal(tolerance = 0) where the result object holds an environment that
# identical() distinguishes and all.equal() does not.
#
# Test structure:
#   A-1  to A-22  — fourteen of the seventeen entry points, Taylor design
#   A-23 to A-29  — replicate, non-probability, and two-phase designs
#   A-30, A-31    — direct S7 construction; the SPSS labelled variant
#   G-1  to G-4   — value labels on a group column after the strip
#   X-1  to X-14  — the last three entry points, plus five more call forms
#   X-20 to X-22  — three more group-label rows
#
# The seventeen public entry points of spec VIII.4, and the row that covers
# each. Read this table against the file to check the sweep is complete.
#
#   get_freqs        A-6, A-7, A-8, A-9, X-6, X-8, X-9, A-24, A-27
#   get_means        A-1, A-2, A-3, A-23, A-26, A-28, A-30, A-31
#   get_totals       A-4, A-5, A-29
#   get_quantiles    A-10, A-11, A-25
#   get_ratios       A-15, X-13
#   get_variance     A-12, X-11
#   get_covariance   A-13, X-12
#   get_corr         A-14, X-7 (polychoric), X-14 (grouped)
#   get_diffs        A-20, X-10
#   get_t_test       A-18
#   get_pairwise     A-19
#   get_anova        A-22
#   get_effective_n  A-16, A-17
#   survey_glm       A-21
#   clean            X-1, X-2
#   meta             X-3, X-4
#   set_val_labels   X-5, X-6

# ── Fixtures ─────────────────────────────────────────────────────────────────

# One frame in two shapes. `labelled = FALSE` keeps every attribute the import
# set and removes only the class, so the metadata harvest is identical in both
# shapes and the class is the only difference the rows can see.
#
# 20 PSUs nested in 2 strata, 400 rows. The smallest group cell is 50, so no row
# trips the AAPOR small-cell notice at the default min_cell_n.
#
# make_labelled(), make_labelled_spss() and make_tagged_na() live in
# helper-test-data.R.
.la_frame <- function(labelled = TRUE, n_rep = 0L, seed = 19L) {
  set.seed(seed)
  n <- 400L
  df <- data.frame(
    psu = paste0("psu_", rep(1:20, each = 20L)),
    strata = paste0("s", rep(1:2, each = 200L)),
    fpc = rep(c(5000, 6000), each = 200L),
    wt = runif(n, 0.5, 2),
    ph2 = rep(c(TRUE, FALSE), 200L),
    y1 = rnorm(n, 50, 10),
    y2 = rnorm(n, 20, 4),
    y3 = rep(c(0L, 1L), 200L),
    q1 = rep(c(1, 2, 3, 4), 100L),
    g = rep(c("a", "b"), each = 200L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(n_rep)) {
    df[[paste0("rw", i)]] <- runif(n, 0.3, 3)
  }
  df$y1 <- make_labelled(df$y1, NULL, "Outcome one")
  df$y2 <- make_labelled(df$y2, NULL, "Outcome two")
  df$y3 <- make_labelled(df$y3, c(No = 0L, Yes = 1L), "Binary")
  df$q1 <- make_labelled(
    df$q1,
    c(`Strongly agree` = 1, Agree = 2, Disagree = 3, `Strongly disagree` = 4),
    "Agreement"
  )
  df$g <- make_labelled(df$g, c(Alpha = "a", Beta = "b"), "Cohort")
  if (!labelled) {
    for (nm in c("y1", "y2", "y3", "q1", "g")) {
      attr(df[[nm]], "class") <- NULL
    }
  }
  df
}

.la_design <- function(labelled = TRUE, type = "taylor") {
  if (type == "taylor") {
    return(as_survey(
      .la_frame(labelled),
      ids = psu,
      weights = wt,
      strata = strata,
      fpc = fpc
    ))
  }
  if (type == "replicate") {
    return(as_survey_replicate(
      .la_frame(labelled, n_rep = 8L),
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    ))
  }
  if (type == "nonprob") {
    return(as_survey_nonprob(
      .la_frame(labelled, n_rep = 8L),
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    ))
  }
  if (type == "twophase") {
    phase1 <- as_survey(
      .la_frame(labelled),
      ids = psu,
      weights = wt,
      strata = strata,
      fpc = fpc
    )
    return(as_survey_twophase(phase1, subset = ph2, method = "approx"))
  }
  # Direct S7 construction. No constructor entry point runs, so only the
  # property setter can normalise the frame.
  survey_taylor(
    data = .la_frame(labelled),
    variables = list(
      ids = "psu",
      weights = "wt",
      strata = "strata",
      fpc = "fpc",
      nest = FALSE,
      probs_provided = FALSE,
      visible_vars = NULL
    )
  )
}

# Runs `fn` on a labelled-input design and on its plain-input twin. Both designs
# are bound to the same symbol, so the call the result metadata records is the
# same language object in both halves and the two results compare exactly.
.la_both <- function(fn, type = "taylor") {
  d <- .la_design(TRUE, type)
  labelled <- fn(d)
  d <- .la_design(FALSE, type)
  list(labelled = labelled, plain = fn(d))
}


# ── A. The analysis sweep on a Taylor design ─────────────────────────────────

test_that("A-1: get_means() on a labelled column matches plain input", {
  d <- .la_design(TRUE)
  test_invariants(d)
  labelled <- get_means(d, y1)
  d <- .la_design(FALSE)
  expect_identical(labelled, get_means(d, y1))
})

test_that("A-2: get_means() grouped by a labelled character column matches", {
  r <- .la_both(function(d) get_means(d, y1, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-3: get_means() grouped by a labelled coded column matches", {
  r <- .la_both(function(d) get_means(d, y1, group = q1))
  expect_identical(r$labelled, r$plain)
})

test_that("A-4: get_totals() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_totals(d, y1))
  expect_identical(r$labelled, r$plain)
})

test_that("A-5: grouped get_totals() matches plain input", {
  r <- .la_both(function(d) get_totals(d, y1, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-6: get_freqs() on a labelled coded double matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q1))
  expect_identical(r$labelled, r$plain)
})

test_that("A-7: get_freqs() on a labelled character column matches", {
  r <- .la_both(function(d) get_freqs(d, g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-8: get_freqs() on a labelled integer column matches", {
  r <- .la_both(function(d) get_freqs(d, y3))
  expect_identical(r$labelled, r$plain)
})

test_that("A-9: grouped get_freqs() matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q1, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-10: get_quantiles() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_quantiles(d, y1))
  expect_identical(r$labelled, r$plain)
})

test_that("A-11: grouped get_quantiles() with three probs matches", {
  r <- .la_both(function(d) {
    get_quantiles(d, y1, probs = c(0.25, 0.5, 0.75), group = g)
  })
  expect_identical(r$labelled, r$plain)
})

test_that("A-12: get_variance() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_variance(d, y1))
  expect_identical(r$labelled, r$plain)
})

test_that("A-13: get_covariance() on two labelled columns matches", {
  r <- .la_both(function(d) get_covariance(d, c(y1, y2)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-14: get_corr() on two labelled columns matches plain input", {
  r <- .la_both(function(d) get_corr(d, c(y1, y2)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-15: get_ratios() on labelled columns matches plain input", {
  r <- .la_both(function(d) get_ratios(d, y1, y2))
  expect_identical(r$labelled, r$plain)
})

test_that("A-16: get_effective_n() matches plain input", {
  r <- .la_both(function(d) get_effective_n(d))
  expect_identical(r$labelled, r$plain)
})

test_that("A-17: grouped get_effective_n() matches plain input", {
  r <- .la_both(function(d) get_effective_n(d, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-18: get_t_test() by a labelled character column matches", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_t_test(d, y1, by = g),
    class = "surveycore_warning_by_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_t_test(d, y1, by = g),
    class = "surveycore_warning_by_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("A-19: get_pairwise() by a labelled coded column matches", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_pairwise(d, y1, by = q1),
    class = "surveycore_warning_by_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_pairwise(d, y1, by = q1),
    class = "surveycore_warning_by_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("A-20: get_diffs() with a labelled treatment column matches", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_diffs(d, y1, treats = g),
    class = "surveycore_warning_treats_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_diffs(d, y1, treats = g),
    class = "surveycore_warning_treats_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("A-21: survey_glm() on labelled columns matches plain input", {
  r <- .la_both(function(d) survey_glm(d, y1 ~ y2))
  # The fit object holds a model frame environment, so compare with all.equal
  # semantics at zero tolerance rather than identical().
  expect_equal(r$labelled, r$plain, tolerance = 0)
})

test_that("A-22: get_anova() on a labelled-column fit matches plain input", {
  r <- .la_both(function(d) get_anova(survey_glm(d, y1 ~ y2 + g)))
  expect_equal(r$labelled, r$plain, tolerance = 0)
})


# ── A. Replicate, non-probability, and two-phase designs ─────────────────────

test_that("A-23: get_means() on a replicate design matches plain input", {
  d <- .la_design(TRUE, "replicate")
  test_invariants(d)
  labelled <- get_means(d, y1)
  d <- .la_design(FALSE, "replicate")
  expect_identical(labelled, get_means(d, y1))
})

test_that("A-24: get_freqs() on a replicate design matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q1), type = "replicate")
  expect_identical(r$labelled, r$plain)
})

test_that("A-25: get_quantiles() on a replicate design matches plain input", {
  r <- .la_both(function(d) get_quantiles(d, y1), type = "replicate")
  expect_identical(r$labelled, r$plain)
})

test_that("A-26: get_means() on a nonprob design matches plain input", {
  d <- .la_design(TRUE, "nonprob")
  test_invariants(d)
  labelled <- get_means(d, y1)
  d <- .la_design(FALSE, "nonprob")
  expect_identical(labelled, get_means(d, y1))
})

test_that("A-27: get_freqs() on a nonprob design matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q1), type = "nonprob")
  expect_identical(r$labelled, r$plain)
})

test_that("A-28: get_means() on a twophase design matches plain input", {
  d <- .la_design(TRUE, "twophase")
  test_invariants(d)
  labelled <- get_means(d, y1)
  d <- .la_design(FALSE, "twophase")
  expect_identical(labelled, get_means(d, y1))
})

test_that("A-29: get_totals() on a twophase design matches plain input", {
  r <- .la_both(function(d) get_totals(d, y1), type = "twophase")
  expect_identical(r$labelled, r$plain)
})

test_that("A-30: get_means() after direct S7 construction matches", {
  r <- .la_both(function(d) get_means(d, y1), type = "direct")
  expect_identical(r$labelled, r$plain)
})

test_that("A-31: get_means() on an SPSS labelled column matches plain", {
  build <- function(labelled) {
    df <- .la_frame(labelled)
    df$sp <- rep(c(1, 2, 98, 99), 100L)
    df$sp <- make_labelled_spss(
      df$sp,
      labels = c(Yes = 1, No = 2, Refused = 98, `Don't know` = 99),
      na_values = c(98, 99),
      na_range = c(98, 99),
      label = "SPSS coded"
    )
    if (!labelled) {
      attr(df$sp, "class") <- NULL
    }
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  }

  d <- build(TRUE)
  expect_false(inherits(d@data$sp, "haven_labelled"))
  labelled <- get_means(d, sp)

  d <- build(FALSE)
  expect_identical(labelled, get_means(d, sp))
})


# ── G. Value labels on a group column after the strip ────────────────────────
#
# The strip keeps the `labels` attribute on the column and the harvest keeps a
# copy in @metadata@value_labels, so group labelling has two independent
# sources. These blocks read both, and the two that concern haven tagged NAs
# read the branch that .haven_available() gates.

.la_tagged_frame <- function(labelled = TRUE, seed = 19L) {
  set.seed(seed)
  n <- 400L
  df <- data.frame(
    psu = paste0("psu_", rep(1:20, each = 20L)),
    wt = runif(n, 0.5, 2),
    y1 = rnorm(n, 50, 10),
    q2 = rep(c(1, 2, make_tagged_na("a"), 2), 100L)
  )
  df$y1 <- make_labelled(df$y1, NULL, "Outcome one")
  df$q2 <- make_labelled(
    df$q2,
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged group"
  )
  if (!labelled) {
    attr(df$y1, "class") <- NULL
    attr(df$q2, "class") <- NULL
  }
  df
}

test_that("G-1: grouped get_freqs() labels a previously labelled group", {
  d <- .la_design(TRUE)
  out <- get_freqs(d, q1, group = g)
  expect_identical(levels(out$g), c("Alpha", "Beta"))
  expect_identical(
    levels(out$q1),
    c("Strongly agree", "Agree", "Disagree", "Strongly disagree")
  )
})

test_that("X-20: grouped get_means() labels a previously labelled group", {
  d <- .la_design(TRUE)
  out <- get_means(d, y1, group = q1)
  expect_identical(
    levels(out$q1),
    c("Strongly agree", "Agree", "Disagree", "Strongly disagree")
  )
})

test_that("G-3: labels resolve from the column attribute with no metadata", {
  d <- .la_design(TRUE, "direct")
  expect_identical(d@metadata@value_labels, list())
  out <- get_means(d, y1, group = q1)
  expect_identical(
    levels(out$q1),
    c("Strongly agree", "Agree", "Disagree", "Strongly disagree")
  )
})

test_that("G-4: group labels still resolve when haven is unavailable", {
  testthat::local_mocked_bindings(
    .haven_available = function() FALSE,
    .package = "surveycore"
  )
  df <- .la_tagged_frame()
  d <- as_survey(df, ids = psu, weights = wt)
  out <- get_means(d, y1, group = q2, na.rm = FALSE)

  # The regular codes still resolve. The tagged NA cannot, because reading its
  # tag needs haven, so that group stays NA rather than raising.
  expect_identical(levels(out$q2), c("Yes", "No"))
  expect_true(any(is.na(out$q2)))
})

test_that("X-21: the harvested metadata survives the strip", {
  d <- .la_design(TRUE)
  expect_identical(
    extract_val_labels(d, q1),
    list(
      q1 = c(
        `Strongly agree` = 1,
        Agree = 2,
        Disagree = 3,
        `Strongly disagree` = 4
      )
    )
  )
  expect_identical(extract_var_label(d, y1), c(y1 = "Outcome one"))
  expect_identical(extract_var_label(d, g), c(g = "Cohort"))
})

test_that("X-22: a tagged NA group resolves to its label when haven is there", {
  skip_if_not_installed("haven")
  df <- .la_tagged_frame()
  d <- as_survey(df, ids = psu, weights = wt)
  out <- get_means(d, y1, group = q2, na.rm = FALSE)
  expect_identical(levels(out$q2), c("Yes", "No", "Refused"))
})


# ── X. The entry points and call forms the sweep above does not reach ────────
#
# `X-n` numbers builder-added coverage for this PR in one sequence that runs
# across three files: this one, test-utils.R and test-s7-classes.R. The prefix
# is deliberate — an `X-` label claims no numbered row in any planning
# document, only the behaviour its own description states.
#
# X-1 to X-14 close the last three of the seventeen public entry points named
# in spec VIII.4 — clean(), meta() and set_val_labels() — together with the
# polychoric call form of get_corr(), the `label_values` argument, and the
# grouped call form of the four multi-column entry points. X-15 and X-16 pin
# spec III.3a, the stacked caller class, and live in the other two files.

# Two integer-backed ordinal columns, for the polychoric call form. Integer
# backing is what the ordinality gate accepts on this branch; a whole-valued
# double is spec item 4 and a separate change.
.la_ordinal_design <- function(labelled = TRUE) {
  df <- .la_frame(labelled)
  df$o1 <- make_labelled(
    rep(c(1L, 2L, 3L, 4L), 100L),
    c(A = 1L, B = 2L, C = 3L, D = 4L),
    "Ordinal one"
  )
  df$o2 <- make_labelled(
    rep(c(1L, 1L, 2L, 3L, 4L, 4L, 2L, 3L), 50L),
    c(A = 1L, B = 2L, C = 3L, D = 4L),
    "Ordinal two"
  )
  if (!labelled) {
    attr(df$o1, "class") <- NULL
    attr(df$o2, "class") <- NULL
  }
  as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
}

.q1_labels <- c(
  `Strongly agree` = 1,
  Agree = 2,
  Disagree = 3,
  `Strongly disagree` = 4
)

test_that("X-1: clean() on a labelled-column fit matches plain input", {
  r <- .la_both(function(d) clean(survey_glm(d, y1 ~ y2)))
  expect_identical(r$labelled, r$plain)
})

test_that("X-2: clean() on a fit with a labelled predictor matches plain", {
  r <- .la_both(function(d) clean(survey_glm(d, y1 ~ g)))
  expect_identical(r$labelled, r$plain)
})

test_that("X-3: meta() on a labelled-column result matches plain input", {
  r <- .la_both(function(d) meta(get_means(d, y1, group = q1)))
  expect_identical(r$labelled, r$plain)

  # The harvested labels reach the result metadata unchanged by the strip.
  expect_identical(r$labelled$group$q1$value_labels, .q1_labels)
  expect_identical(r$labelled$group$q1$variable_label, "Agreement")
  expect_identical(r$labelled$x$y1$variable_label, "Outcome one")
})

test_that("X-4: meta() on a get_freqs() result carries the x value labels", {
  r <- .la_both(function(d) meta(get_freqs(d, q1)))
  expect_identical(r$labelled, r$plain)
  expect_identical(r$labelled$x$q1$value_labels, .q1_labels)
})

test_that("X-5: set_val_labels() on a labelled column stores the new labels", {
  r <- .la_both(function(d) {
    extract_val_labels(
      set_val_labels(d, q1 = c(A = 1, B = 2, C = 3, D = 4)),
      q1
    )
  })
  expect_identical(r$labelled, r$plain)
  expect_identical(r$labelled, list(q1 = c(A = 1, B = 2, C = 3, D = 4)))
})

test_that("X-6: get_freqs() uses the labels set_val_labels() wrote", {
  r <- .la_both(function(d) {
    get_freqs(set_val_labels(d, q1 = c(A = 1, B = 2, C = 3, D = 4)), q1)
  })
  expect_identical(r$labelled, r$plain)
  expect_identical(levels(r$labelled$q1), c("A", "B", "C", "D"))
})

test_that("X-7: polychoric get_corr() on labelled ordinals matches plain", {
  d <- .la_ordinal_design(TRUE)
  labelled <- get_corr(d, c(o1, o2), method = "polychoric")
  d <- .la_ordinal_design(FALSE)
  expect_identical(labelled, get_corr(d, c(o1, o2), method = "polychoric"))
})

test_that("X-8: get_freqs(label_values = FALSE) returns the raw codes", {
  r <- .la_both(function(d) get_freqs(d, q1, label_values = FALSE))
  expect_identical(r$labelled, r$plain)
  expect_identical(r$labelled$q1, c("1", "2", "3", "4"))
})

test_that("X-9: get_freqs(label_values = TRUE) returns the labels", {
  r <- .la_both(function(d) get_freqs(d, q1, label_values = TRUE))
  expect_identical(r$labelled, r$plain)
  expect_identical(levels(r$labelled$q1), names(.q1_labels))
})

test_that("X-10: get_diffs(label_values = FALSE) matches plain input", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_diffs(d, y1, treats = g, label_values = FALSE),
    class = "surveycore_warning_treats_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_diffs(d, y1, treats = g, label_values = FALSE),
    class = "surveycore_warning_treats_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("X-11: grouped get_variance() matches plain input", {
  r <- .la_both(function(d) get_variance(d, y1, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-12: grouped get_covariance() matches plain input", {
  r <- .la_both(function(d) get_covariance(d, c(y1, y2), group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-13: grouped get_ratios() matches plain input", {
  r <- .la_both(function(d) get_ratios(d, y1, y2, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-14: grouped get_corr() matches plain input", {
  r <- .la_both(function(d) get_corr(d, c(y1, y2), group = g))
  expect_identical(r$labelled, r$plain)
})
