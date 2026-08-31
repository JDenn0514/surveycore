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
#   A-1  to A-22  — the fourteen analysis entry points on a Taylor design
#   A-23 to A-29  — replicate, non-probability, and two-phase designs
#   A-30, A-31    — direct S7 construction; the SPSS labelled variant
#   G-1  to G-6   — value labels on a group column after the strip

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

test_that("G-2: grouped get_means() labels a previously labelled group", {
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

test_that("G-5: the harvested metadata survives the strip", {
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

test_that("G-6: a tagged NA group resolves to its label when haven is there", {
  skip_if_not_installed("haven")
  df <- .la_tagged_frame()
  d <- as_survey(df, ids = psu, weights = wt)
  out <- get_means(d, y1, group = q2, na.rm = FALSE)
  expect_identical(levels(out$q2), c("Yes", "No", "Refused"))
})
