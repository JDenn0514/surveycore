# tests/testthat/test-labelled-analysis.R
#
# Every analysis entry point, run on a design whose columns arrived carrying the
# haven labelled class, compared against the identical design whose columns
# arrived without it. Source: the `data` property setter in R/core-classes.R and
# the two strip helpers in R/utils.R.
#
# Each A row asserts two things, because either alone is too weak. An
# error-free run alone would pass a silent numerical change; an identity
# comparison alone would not say which half raised. `.la_both()` runs both
# halves under expect_no_error(), and the caller compares the two results.
#
# The comparison is exact. The setter removes a class attribute and changes no
# value, so every estimate must come out bit for bit the same. Rows use
# expect_identical(), or expect_equal(tolerance = 0) where the result holds an
# environment that identical() distinguishes and all.equal() does not. No row
# uses a default tolerance.
#
# Test structure:
#   A-1  to A-31  — the analysis sweep
#   G-1  to G-6   — value labels on a group column after the strip
#   X-*           — behaviour worth covering that matches no numbered row

# ── Fixtures ─────────────────────────────────────────────────────────────────

# One frame in two shapes. `labelled = FALSE` keeps every attribute the import
# set and removes only the class, so the metadata harvest is identical in both
# shapes and the class is the only difference the rows can see.
#
# 20 PSUs nested in 2 strata, 400 rows. The smallest group cell is 100, so no
# row trips the AAPOR small-cell notice at the default min_cell_n.
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
    q = rep(c(1, 2, 3, 4), 100L),
    q1 = runif(n, 10, 40),
    q2 = runif(n, 1, 5),
    qna = rep(c(1, 2, 3, NA), 100L),
    g = factor(rep(c("west", "east"), each = 200L), levels = c("west", "east")),
    g_lbl = rep(c("a", "b"), each = 200L),
    g1 = rep(c(1, 2), each = 200L),
    g2 = rep(c(1, 1, 2, 2), 100L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(n_rep)) {
    df[[paste0("rw", i)]] <- runif(n, 0.3, 3)
  }
  df$q <- make_labelled(df$q, c(A = 1, B = 2, C = 3, D = 4), "Agreement")
  df$q1 <- make_labelled(df$q1, NULL, "Outcome one")
  df$q2 <- make_labelled(df$q2, NULL, "Outcome two")
  df$qna <- make_labelled(df$qna, c(Low = 1, Mid = 2, High = 3), "With NA")
  df$g_lbl <- make_labelled(df$g_lbl, c(Alpha = "a", Beta = "b"), "Cohort")
  df$g1 <- make_labelled(df$g1, c(North = 1, South = 2), "Region")
  df$g2 <- make_labelled(df$g2, c(Young = 1, Old = 2), "Age band")
  if (!labelled) {
    for (nm in c("q", "q1", "q2", "qna", "g_lbl", "g1", "g2")) {
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

# Runs `fn` on a labelled-input design and on its plain-input twin, asserting
# that neither half raises, and returns both results for the caller's identity
# check. Both designs are bound to the same symbol, so the call the result
# metadata records is the same language object in both halves and the two
# results compare exactly.
.la_both <- function(fn, type = "taylor") {
  d <- .la_design(TRUE, type)
  expect_no_error(labelled <- fn(d))
  d <- .la_design(FALSE, type)
  expect_no_error(plain <- fn(d))
  list(labelled = labelled, plain = plain)
}


# ── A. The analysis sweep ────────────────────────────────────────────────────

test_that("A-1: get_freqs() on a labelled column matches plain input", {
  d <- .la_design(TRUE)
  test_invariants(d)
  r <- .la_both(function(d) get_freqs(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-2: get_freqs() grouped by a plain column matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-3: get_freqs() grouped by a labelled column matches", {
  r <- .la_both(function(d) get_freqs(d, q, group = g_lbl))
  expect_identical(r$labelled, r$plain)
})

test_that("A-4: get_freqs() grouped by two labelled columns matches", {
  r <- .la_both(function(d) get_freqs(d, q, group = c(g1, g2)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-5: get_freqs(label_values = FALSE) matches plain input", {
  r <- .la_both(function(d) get_freqs(d, q, label_values = FALSE))
  expect_identical(r$labelled, r$plain)
})

test_that("A-6: get_freqs(na.rm = FALSE) on a labelled column with NA", {
  r <- .la_both(function(d) get_freqs(d, qna, na.rm = FALSE))
  expect_identical(r$labelled, r$plain)
})

test_that("A-7: get_means() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_means(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-8: get_means() grouped matches plain input", {
  r <- .la_both(function(d) get_means(d, q, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-9: get_means(na.rm = TRUE) matches plain input", {
  r <- .la_both(function(d) get_means(d, q, na.rm = TRUE))
  expect_identical(r$labelled, r$plain)
})

test_that("A-10: get_means() on a replicate design matches plain input", {
  d <- .la_design(TRUE, "replicate")
  test_invariants(d)
  r <- .la_both(function(d) get_means(d, q), type = "replicate")
  expect_identical(r$labelled, r$plain)
})

test_that("A-11: get_means() on a two-phase design matches plain input", {
  d <- .la_design(TRUE, "twophase")
  test_invariants(d)
  r <- .la_both(function(d) get_means(d, q), type = "twophase")
  expect_identical(r$labelled, r$plain)
})

test_that("A-12: get_means() on a nonprob design matches plain input", {
  d <- .la_design(TRUE, "nonprob")
  test_invariants(d)
  r <- .la_both(function(d) get_means(d, q), type = "nonprob")
  expect_identical(r$labelled, r$plain)
})

# get_totals() passes on the base by accident: ifelse() at
# R/analysis-totals-helpers.R:36 strips the class before the subtraction that
# breaks get_means(). One rename there would move the defect, so this row and
# A-14 are the fence that would catch it.
test_that("A-13: get_totals() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_totals(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-14: get_totals() grouped matches plain input", {
  r <- .la_both(function(d) get_totals(d, q, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-15: get_quantiles() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_quantiles(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-16: get_quantiles() grouped matches plain input", {
  r <- .la_both(function(d) get_quantiles(d, q, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-17: get_variance() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_variance(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-18: get_variance() grouped matches plain input", {
  r <- .la_both(function(d) get_variance(d, q, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-19: get_covariance() on two labelled columns matches", {
  r <- .la_both(function(d) get_covariance(d, c(q1, q2)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-20: get_ratios() on two labelled columns matches", {
  r <- .la_both(function(d) get_ratios(d, q1, q2))
  expect_identical(r$labelled, r$plain)
})

test_that("A-21: get_corr() on two labelled columns matches plain input", {
  r <- .la_both(function(d) get_corr(d, c(q1, q2)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-22: get_t_test() by a plain column matches plain input", {
  r <- .la_both(function(d) get_t_test(d, q, g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-23: get_diffs() with a plain treatment column matches", {
  r <- .la_both(function(d) get_diffs(d, q, g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-24: get_diffs() with a labelled treatment column matches", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_diffs(d, q, g_lbl),
    class = "surveycore_warning_treats_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_diffs(d, q, g_lbl),
    class = "surveycore_warning_treats_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("A-25: get_pairwise() by a plain column matches plain input", {
  r <- .la_both(function(d) get_pairwise(d, q, g))
  expect_identical(r$labelled, r$plain)
})

test_that("A-26: get_anova() from a formula matches plain input", {
  r <- .la_both(function(d) get_anova(d, q ~ g))
  expect_equal(r$labelled, r$plain, tolerance = 0)
})

test_that("A-27: survey_glm() on labelled columns matches plain input", {
  # The fit holds a model-frame environment that identical() distinguishes and
  # all.equal() does not, so the comparison is all.equal at zero tolerance.
  r <- .la_both(function(d) survey_glm(d, q ~ g))
  expect_equal(r$labelled, r$plain, tolerance = 0)
})

test_that("A-28: get_anova() on a fitted model matches plain input", {
  r <- .la_both(function(d) get_anova(survey_glm(d, q ~ g)))
  expect_equal(r$labelled, r$plain, tolerance = 0)
})

test_that("A-29: clean() on a fitted model matches plain input", {
  r <- .la_both(function(d) clean(survey_glm(d, q ~ g)))
  expect_identical(r$labelled, r$plain)
})

test_that("A-30: get_effective_n() on a labelled column matches plain input", {
  r <- .la_both(function(d) get_effective_n(d, q))
  expect_identical(r$labelled, r$plain)
})

test_that("A-31: meta() on a result carries the same method and design type", {
  r <- .la_both(function(d) meta(get_corr(d, c(q1, q2))))
  expect_identical(r$labelled, r$plain)
  expect_identical(r$labelled$method, "pearson")
  expect_identical(r$labelled$design_type, "taylor")
})


# ── G. Value labels on a group column after the strip ────────────────────────
#
# The strip keeps the `labels` attribute on the column and the harvest keeps a
# copy in @metadata@value_labels, so group labelling has two independent
# sources. These blocks read both.
#
# `gc` codes 1, 2, 3 to labels Zulu, Alpha, Mike. The labels are deliberately
# not in alphabetical order, so a row asserting "ordered by ascending code" can
# fail if the ordering ever changes to alphabetical.

.la_group_frame <- function(labelled = TRUE, seed = 19L) {
  set.seed(seed)
  n <- 400L
  df <- data.frame(
    psu = paste0("psu_", rep(1:20, each = 20L)),
    wt = runif(n, 0.5, 2),
    y = rnorm(n, 50, 10),
    gc = rep(c(1, 2, 3, 2), 100L),
    gt = rep(c(1, 2, make_tagged_na("a"), 2), 100L),
    gu = rep(c(1, 2, 3, 2), 100L),
    gp = factor(
      rep(c("Zulu", "Alpha"), each = 200L),
      levels = c("Zulu", "Alpha")
    ),
    stringsAsFactors = FALSE
  )
  df$gc <- make_labelled(df$gc, c(Zulu = 1, Alpha = 2, Mike = 3), "Coded")
  df$gt <- make_labelled(
    df$gt,
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged group"
  )
  # `gu` carries code 3 in the data with no matching label entry.
  df$gu <- make_labelled(df$gu, c(Yes = 1, No = 2), "Unlabelled code")
  if (!labelled) {
    for (nm in c("gc", "gt", "gu")) {
      attr(df[[nm]], "class") <- NULL
    }
  }
  df
}

.la_group_design <- function(labelled = TRUE) {
  as_survey(.la_group_frame(labelled), ids = psu, weights = wt)
}

test_that("G-1: label_values = TRUE labels the group by ascending code", {
  d <- .la_group_design()
  out <- get_means(d, y, group = gc, label_values = TRUE)

  expect_s3_class(out$gc, "factor")
  # Ordered by ascending code (1, 2, 3), not alphabetically.
  expect_identical(levels(out$gc), c("Zulu", "Alpha", "Mike"))
})

test_that("G-2: label_values = FALSE leaves the group as raw codes", {
  d <- .la_group_design()
  out <- get_means(d, y, group = gc, label_values = FALSE)

  expect_false(is.factor(out$gc))
  expect_identical(out$gc, c(1, 2, 3))
})

# G-3 and G-3a record a pre-existing behaviour that this work does not change
# and does not fix: a tagged NA is NA to base R, so na.rm decides whether the
# level carries a row, while the label resolves into the factor levels either
# way. Read the two rows together — neither is a defect this PR introduced.
test_that("G-3: a tagged-NA group label resolves, and na.rm = FALSE keeps it", {
  d <- .la_group_design()
  out <- get_means(d, y, group = gt, na.rm = FALSE, label_values = TRUE)

  # The label is among the factor levels, resolved from the tag.
  expect_identical(levels(out$gt), c("Yes", "No", "Refused"))
  # Measured on this branch: with na.rm = FALSE the level does carry a row.
  expect_identical(sum(!is.na(out$gt) & out$gt == "Refused"), 1L)
})

test_that("G-3a: na.rm = TRUE leaves the tagged-NA level with no row", {
  d <- .la_group_design()
  out <- get_means(d, y, group = gt, na.rm = TRUE, label_values = TRUE)

  # The label is still among the factor levels...
  expect_identical(levels(out$gt), c("Yes", "No", "Refused"))
  # ...but no row carries it, because na.rm dropped the NA-valued rows.
  expect_identical(sum(!is.na(out$gt) & out$gt == "Refused"), 0L)
  expect_identical(as.character(out$gt), c("Yes", "No"))
})

test_that("G-4: with haven absent the tagged-NA label does not resolve", {
  testthat::local_mocked_bindings(
    .haven_available = function() FALSE,
    .package = "surveycore"
  )
  d <- .la_group_design()

  expect_no_error(
    out <- get_means(d, y, group = gt, na.rm = FALSE, label_values = TRUE)
  )
  # Reading the tag is the one thing that needs haven, so its label is gone.
  expect_identical(levels(out$gt), c("Yes", "No"))
  # Every non-tagged label still resolves, and the row itself is not lost.
  expect_true(any(is.na(out$gt)))
  expect_identical(nrow(out), 3L)
})

test_that("G-5: a group code with no label keeps its row", {
  d <- .la_group_design()

  labelled_out <- get_means(d, y, group = gu, label_values = TRUE)
  # The unlabelled code is not dropped: its row survives with its full n.
  expect_identical(nrow(labelled_out), 3L)
  expect_identical(sum(labelled_out$n), 400L)
  expect_identical(levels(labelled_out$gu), c("Yes", "No"))
  expect_true(any(is.na(labelled_out$gu)))

  # With the labels off, the same code appears as its raw value.
  raw_out <- get_means(d, y, group = gu, label_values = FALSE)
  expect_identical(raw_out$gu, c(1, 2, 3))
})

test_that("G-6: a plain factor group keeps its declared level order", {
  d <- .la_group_design()
  out <- get_means(d, y, group = gp, label_values = TRUE)

  # Declared as Zulu then Alpha, so not re-sorted alphabetically.
  expect_identical(levels(out$gp), c("Zulu", "Alpha"))
  expect_identical(as.character(out$gp), c("Zulu", "Alpha"))
})


# ── X. Behaviour worth covering that matches no numbered row ─────────────────
#
# An `X-` label claims no row identifier. Each block states the behaviour it
# asserts, and the spec clause behind it where there is one.

test_that("X-1: get_means() after direct S7 construction matches plain", {
  r <- .la_both(function(d) get_means(d, q), type = "direct")
  expect_identical(r$labelled, r$plain)
})

test_that("X-2: get_means() on an SPSS labelled column matches plain", {
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

test_that("X-3: clean() on a fit with a labelled predictor matches plain", {
  r <- .la_both(function(d) clean(survey_glm(d, q1 ~ g_lbl)))
  expect_identical(r$labelled, r$plain)
})

test_that("X-4: meta() on a get_freqs() result carries the x value labels", {
  r <- .la_both(function(d) meta(get_freqs(d, q)))
  expect_identical(r$labelled, r$plain)
  expect_identical(
    r$labelled$x$q$value_labels,
    c(A = 1, B = 2, C = 3, D = 4)
  )
})

test_that("X-5: set_val_labels() on a labelled column stores the new labels", {
  r <- .la_both(function(d) {
    extract_val_labels(
      set_val_labels(d, q = c(W = 1, X = 2, Y = 3, Z = 4)),
      q
    )
  })
  expect_identical(r$labelled, r$plain)
  expect_identical(r$labelled, list(q = c(W = 1, X = 2, Y = 3, Z = 4)))
})

test_that("X-6: get_freqs() uses the labels set_val_labels() wrote", {
  r <- .la_both(function(d) {
    get_freqs(set_val_labels(d, q = c(W = 1, X = 2, Y = 3, Z = 4)), q)
  })
  expect_identical(r$labelled, r$plain)
  expect_identical(levels(r$labelled$q), c("W", "X", "Y", "Z"))
})

# Integer backing is what the ordinality gate accepts on this branch. A
# whole-valued double raises surveycore_error_polychoric_requires_ordinal, and
# making that case pass is spec item 4, a separate change.
test_that("X-7: polychoric get_corr() on labelled ordinals matches plain", {
  ordinal_design <- function(labelled) {
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

  d <- ordinal_design(TRUE)
  expect_no_error(labelled <- get_corr(d, c(o1, o2), method = "polychoric"))
  d <- ordinal_design(FALSE)
  expect_no_error(plain <- get_corr(d, c(o1, o2), method = "polychoric"))
  expect_identical(labelled, plain)
})

test_that("X-8: get_diffs(label_values = FALSE) matches plain input", {
  d <- .la_design(TRUE)
  expect_warning(
    labelled <- get_diffs(d, q, g_lbl, label_values = FALSE),
    class = "surveycore_warning_treats_coerced"
  )
  d <- .la_design(FALSE)
  expect_warning(
    plain <- get_diffs(d, q, g_lbl, label_values = FALSE),
    class = "surveycore_warning_treats_coerced"
  )
  expect_identical(labelled, plain)
})

test_that("X-9: grouped get_covariance() matches plain input", {
  r <- .la_both(function(d) get_covariance(d, c(q1, q2), group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-10: grouped get_ratios() matches plain input", {
  r <- .la_both(function(d) get_ratios(d, q1, q2, group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-11: grouped get_corr() matches plain input", {
  r <- .la_both(function(d) get_corr(d, c(q1, q2), group = g))
  expect_identical(r$labelled, r$plain)
})

test_that("X-12: the harvested metadata survives the strip", {
  d <- .la_design(TRUE)
  expect_identical(
    extract_val_labels(d, q),
    list(q = c(A = 1, B = 2, C = 3, D = 4))
  )
  expect_identical(extract_var_label(d, q1), c(q1 = "Outcome one"))
  expect_identical(extract_var_label(d, g_lbl), c(g_lbl = "Cohort"))
})

test_that("X-13: labels resolve from the column with no harvested metadata", {
  d <- .la_design(TRUE, "direct")
  # A direct S7 call runs no harvest, so @metadata is empty and the `labels`
  # attribute the strip preserved is the only source left.
  expect_identical(d@metadata@value_labels, list())
  out <- get_means(d, q1, group = q)
  expect_identical(levels(out$q), c("A", "B", "C", "D"))
})

# G-7 is where the two halves of this work meet: a tagged NA sits in a
# grouping column, and the columns under analysis are whole-valued doubles
# with few distinct values, which this release accepts as ordinal scales. A
# tagged NA is NA to the estimator, so it is excluded pairwise like any other
# missing value.
test_that("G-7: polychoric on whole-valued doubles grouped by a tagged NA", {
  set.seed(57L)
  n <- 400L
  df <- data.frame(
    psu = paste0("psu_", rep(1:20, each = 20L)),
    wt = runif(n, 0.5, 2),
    stringsAsFactors = FALSE
  )
  # Two four-point coded scales, stored as doubles, as an SPSS export stores
  # them. `s2` follows `s1` with a one-step jitter, so the pair is correlated.
  # `s1` is drawn at random rather than cycled, so it is independent of the
  # cyclic group column and every group holds all four levels.
  s1 <- as.numeric(sample(1:4, n, replace = TRUE))
  s2 <- s1 + sample(-1:1, n, replace = TRUE)
  s2[s2 < 1] <- 1
  s2[s2 > 4] <- 4
  df$s1 <- make_labelled(s1, c(A = 1, B = 2, C = 3, D = 4), "Scale one")
  df$s2 <- make_labelled(s2, c(A = 1, B = 2, C = 3, D = 4), "Scale two")
  df$gt <- make_labelled(
    rep(c(1, 2, make_tagged_na("a"), 2), 100L),
    c(Yes = 1, No = 2, Refused = make_tagged_na("a")),
    "Tagged group"
  )
  d <- as_survey(df, ids = psu, weights = wt)

  expect_no_error(
    out <- get_corr(d, c(s1, s2), group = gt, method = "polychoric")
  )
  expect_true(all(is.finite(out$r)))
  # The tagged-NA rows form no group of their own: na.rm defaults to TRUE, so
  # the tag is dropped exactly as a plain NA would be.
  expect_identical(nrow(out), 2L)
})
