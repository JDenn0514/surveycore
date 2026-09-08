# tests/testthat/test-methods-compat.R
#
# Tests for IDE-compatibility methods on survey design objects.
# Source: R/methods-compat.R
#
# Test structure:
#   1. names() — survey_taylor returns @data column names
#   2. names() — survey_replicate returns @data column names
#   3. names() — survey_twophase returns @data column names
#   4. names() — SRS-style survey_taylor returns @data column names
#   5. names() — consistent with names(survey_data(design))
#   6. size functions — the four design classes report @data size
#   7. size functions — survey_collection raises
#   8. size functions — edge cases
#   9. size functions — regression rows
#
# The size functions under test are dim(), nrow(), ncol(), NROW() and
# NCOL(). Only dim() is generic: base R defines nrow(x) as dim(x)[1L] and
# ncol(x) as dim(x)[2L], and NROW()/NCOL() read dim() first and fall back to
# length(x) only when dim(x) is NULL. Testing dim() alone would leave four
# of the five unverified, and those four are the ones a user calls, so every
# behavioural block below runs all five names.
#
# The oracle is surveycore's own exported accessor, survey_data(). Nothing
# here is estimated, so no numerical tolerance applies and every assertion
# uses expect_identical().

test_that("names() returns @data column names for survey_taylor", {
  df <- make_survey_data(n = 100, seed = 1)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  test_invariants(d)
  expect_identical(names(d), names(df))
})

test_that("names() returns @data column names for survey_replicate", {
  df <- make_survey_data(n = 100, design = "replicate", seed = 2)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  test_invariants(d)
  expect_identical(names(d), names(df))
})

test_that("names() returns @data column names for survey_twophase", {
  df <- make_survey_data(n = 200, design = "twophase", seed = 3)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d <- as_survey_twophase(
    phase1,
    probs2 = phase2_prob,
    subset = subset
  )
  test_invariants(d)
  expect_identical(names(d), names(df))
})

test_that("names() returns @data column names for SRS-style survey_taylor", {
  df <- data.frame(y = 1:10, grp = letters[1:10], w = rep(1, 10))
  d <- as_survey(df, weights = w)
  expect_identical(names(d), names(df))
})

test_that("names() is consistent with names(survey_data(design))", {
  df <- make_survey_data(n = 100, seed = 4)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  expect_identical(names(d), names(survey_data(d)))
})


# ── size functions on the four design classes ────────────────────────────────
# A1-A7 and the cheap regression rows R1-R3, R7, R8.

test_that("the five size functions report @data size for survey_taylor", {
  df <- make_survey_data(n = 100, n_psu = 10, n_strata = 2, seed = 101)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  stored <- survey_data(d)

  # A1 — all five names against the accessor oracle.
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))

  # Second oracle — as_survey() passes this frame through unchanged, so the
  # input frame answers the same question independently of the accessor.
  expect_identical(dim(d), dim(df))

  # A5 / A6 — length 2 and integer, asserted as type rather than as values.
  expect_length(dim(d), 2L)
  expect_type(dim(d), "integer")

  # A7 — not NULL. NULL is the exact defect under repair, and a mis-typed
  # comparison could pass A1 while dim() still returned NULL.
  expect_false(is.null(dim(d)))

  # R1 / R2 — a non-NULL dim() must not make the object array-like.
  # is.matrix() and is.array() are internal and read the object's real dim
  # ATTRIBUTE, which an S7 object does not have; nrow() and ncol() call the
  # dim() generic, which the new method serves.
  expect_false(is.matrix(d))
  expect_false(is.vector(d))
  expect_false(is.array(d))
  expect_false(inherits(d, "matrix"))

  # R3 — answering a size question does not make the design a frame.
  expect_false(is.data.frame(d))
  expect_false(is.list(d))

  # R7 — length() is out of scope for this change (issue #235).
  expect_identical(length(d), 1L)

  # R8 — no dimnames() method was added, so it stays at its default.
  expect_null(dimnames(d))
})

test_that("the five size functions report @data size for survey_replicate", {
  df <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    seed = 102
  )
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  stored <- survey_data(d)

  # A2
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("the five size functions report @data size for survey_twophase", {
  df <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 2,
    design = "twophase",
    seed = 103
  )
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d <- as_survey_twophase(phase1, probs2 = phase2_prob, subset = subset)
  stored <- survey_data(d)

  # A3
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("the five size functions report @data size for survey_nonprob", {
  df <- make_survey_data(n = 100, n_psu = 10, n_strata = 2, seed = 104)
  d <- as_survey_nonprob(df, weights = wt)
  test_invariants(d)
  stored <- survey_data(d)

  # A4
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("the array predicates stay FALSE on the other three classes", {
  df_rep <- make_survey_data(
    n = 100,
    n_psu = 10,
    n_strata = 2,
    design = "replicate",
    seed = 105
  )
  d_rep <- as_survey_replicate(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  df_tp <- make_survey_data(
    n = 200,
    n_psu = 20,
    n_strata = 2,
    design = "twophase",
    seed = 106
  )
  d_tp <- as_survey_twophase(
    as_survey(df_tp, ids = psu, weights = wt, strata = strata),
    probs2 = phase2_prob,
    subset = subset
  )
  d_np <- as_survey_nonprob(
    make_survey_data(n = 100, n_psu = 10, n_strata = 2, seed = 107),
    weights = wt
  )

  # R1 / R2 on the three classes the survey_taylor block does not cover.
  for (d in list(d_rep, d_tp, d_np)) {
    expect_false(is.matrix(d))
    expect_false(is.vector(d))
    expect_false(is.array(d))
    expect_false(inherits(d, "matrix"))
  }
})


# ── size functions on survey_collection ──────────────────────────────────────
# B1-B12. survey_collection is NOT a child of survey_base, so the method on
# survey_base cannot reach it and the class needs its own.

test_that("the five size functions raise on a survey_collection", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 111)
  df2 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 112)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    wave_one = d1,
    wave_two = d2,
    group = character(0)
  )

  # B1-B5. B4 and B5 are not redundant with B1: before this change NROW()
  # returned the member count and NCOL() returned 1L, because both fall back
  # to length() when dim() is NULL. They are the two calls that move from a
  # working value to an error.
  expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  expect_error(nrow(cl), class = "surveycore_error_collection_no_dim")
  expect_error(ncol(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NROW(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NCOL(cl), class = "surveycore_error_collection_no_dim")

  # B11 / B12 — the two container-shaped questions still have answers. A
  # dim() method that routed through the container's length would break one.
  expect_identical(length(cl), 2L)
  expect_identical(names(cl), c("wave_one", "wave_two"))
})

test_that("dim() on a two-member survey_collection renders its message", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 113)
  df2 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 114)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    wave_one = d1,
    wave_two = d2,
    group = character(0)
  )

  # B6
  expect_snapshot(error = TRUE, dim(cl))
})

test_that("dim() on a one-member survey_collection reads the singular noun", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 115)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(wave_one = d1, group = character(0))

  # B7 — the count bullet must read "1 survey", never "1 surveys". A
  # plural-only implementation passes B6 and fails here.
  expect_snapshot(error = TRUE, dim(cl))
})

test_that("nrow() on a survey_collection renders the same message as dim()", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 116)
  df2 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 117)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    wave_one = d1,
    wave_two = d2,
    group = character(0)
  )

  # B8 — nrow() is not generic, so this confirms the wrapper neither
  # rewords nor re-wraps the message the user actually meets.
  expect_snapshot(error = TRUE, nrow(cl))
})

test_that("the collection message names a member, not a caller variable", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 118)
  df2 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 119)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  first_name <- "alpha_qzk"
  second_name <- "beta_qzk"
  members <- list(d1, d2)
  names(members) <- c(first_name, second_name)
  cl <- rlang::exec(as_survey_collection, !!!members, group = character(0))

  cnd <- expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  msg <- conditionMessage(cnd)

  # B9 — the fix-it bullet names the first member, read off the object.
  expect_true(grepl(first_name, msg, fixed = TRUE))

  # B10 — and it never guesses the caller's variable name. An earlier draft
  # showed a snippet built around an object named x; this row makes a revert
  # to that form fail rather than pass through a re-accepted snapshot.
  expect_false(grepl("x[[", msg, fixed = TRUE))
})


# ── edge cases ───────────────────────────────────────────────────────────────
# E1-E12.

test_that("the size functions report the smallest design a constructor makes", {
  df <- data.frame(y = c(1, 2), w = c(1.5, 2.5))
  d <- as_survey(df, weights = w)
  stored <- survey_data(d)

  # E1 — two rows is the constructor floor (E1b fixes that premise).
  expect_identical(dim(d), c(2L, 2L))
  expect_identical(nrow(d), 2L)
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("as_survey() rejects a one-row frame", {
  # E1b — this row is not about dim(). It fixes the premise E1c depends on,
  # so a later relaxation of the floor cannot silently turn E1c into a
  # duplicate of E1. Class assertion only: the message is already
  # snapshotted where the constructor is tested.
  df <- data.frame(y = 1, w = 1.5)
  expect_error(
    as_survey(df, weights = w),
    class = "surveycore_error_single_row"
  )
})

test_that("the size functions report one row for a design holding one row", {
  df <- data.frame(y = c(1, 2), w = c(1.5, 2.5))
  d <- as_survey(df, weights = w)

  # A one-row design is not reachable through a constructor (E1b), but the
  # @data property assignment accepts it: no class validator checks the row
  # count. One row is not special-cased anywhere, and this row proves it.
  d@data <- d@data[1, , drop = FALSE]
  stored <- survey_data(d)

  # E1c
  expect_identical(dim(d), c(1L, 2L))
  expect_identical(nrow(d), 1L)
  expect_identical(NROW(d), 1L)
  expect_identical(ncol(d), 2L)
  expect_identical(NCOL(d), 2L)
  expect_identical(dim(d), dim(stored))
})

test_that("a domain filter widens the columns and keeps the rows", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 121)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d_filtered <- surveytidy::filter(d, y1 > 50)

  # E2 — the filter adds a domain-membership column and keeps every row.
  expect_gt(ncol(d_filtered), ncol(d))
  expect_identical(nrow(d_filtered), nrow(d))
  expect_identical(ncol(d_filtered), ncol(survey_data(d_filtered)))
  expect_identical(NCOL(d_filtered), ncol(survey_data(d_filtered)))
})

test_that("nrow() on a filtered design reports the stored row count", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 122)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  # A condition that selects a strict subset of the 60 rows.
  d_filtered <- surveytidy::filter(d, y1 > 50)
  expect_lt(sum(survey_data(d)$y1 > 50), 60L)

  # E3 — the expected value is the full sample size. A filter on a design
  # marks domain membership and keeps every row (CLAUDE.md, "Domain
  # estimation vs physical subsetting"). A future change that makes this
  # row fail is a change in domain semantics, not a fix.
  expect_identical(nrow(d_filtered), 60L)
  expect_identical(nrow(d_filtered), nrow(d))
  expect_identical(nrow(d_filtered), nrow(survey_data(d_filtered)))
  expect_identical(NROW(d_filtered), nrow(survey_data(d_filtered)))
})

test_that("column selection reduces the reported column count", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 123)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d_sel <- surveytidy::select(d, psu, strata, wt, y1, y2)
  stored <- survey_data(d_sel)

  # E4
  expect_lt(ncol(d_sel), ncol(d))
  expect_identical(ncol(d_sel), ncol(stored))
  expect_identical(NCOL(d_sel), ncol(stored))
  expect_identical(nrow(d_sel), nrow(d))
})

test_that("adding a column raises the reported column count by one", {
  skip_if_not_installed("surveytidy")
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 124)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d_mut <- surveytidy::mutate(d, y1_doubled = y1 * 2)
  stored <- survey_data(d_mut)

  # E5 — update_design() cannot do this: it re-specifies design variables
  # only, and a data-column argument raises "unused argument".
  expect_identical(ncol(d_mut), ncol(d) + 1L)
  expect_identical(ncol(d_mut), ncol(stored))
  expect_identical(NCOL(d_mut), ncol(stored))
  expect_identical(nrow(d_mut), nrow(d))
})

test_that("the size functions report the frame for an equal-weight design", {
  df <- data.frame(
    y = seq_len(12),
    g = rep(c("a", "b", "c"), 4),
    w = rep(2, 12)
  )

  # E6 — no strata, no ids, no fpc. The constructor's simple-random-sample
  # fallback fires only when neither a probability column nor a weight
  # column is supplied. This call supplies weights, so no warning is
  # expected and none may be captured.
  d <- as_survey(df, weights = w)
  stored <- survey_data(d)

  expect_identical(dim(d), c(12L, 3L))
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("the size functions count the weight column the SRS fallback adds", {
  df <- data.frame(y = seq_len(12), g = rep(c("a", "b", "c"), 4))

  # E6b — assert the warning class only. The wording differs according to
  # whether the call supplied cluster ids; the class is the same in both.
  expect_warning(
    d <- as_survey(df),
    class = "surveycore_warning_srs_no_weights"
  )
  stored <- survey_data(d)

  # Asserted through the accessor, not against a literal count: this branch
  # adds a weight column the input frame did not have.
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
  expect_identical(ncol(d), ncol(df) + 1L)
  expect_identical(nrow(d), nrow(df))
  expect_identical(NROW(d), nrow(df))
})

test_that("an all-NA column is counted", {
  df <- data.frame(
    y = seq_len(12),
    all_na = rep(NA_real_, 12),
    w = rep(2, 12)
  )
  d <- as_survey(df, weights = w)

  # E7 — dim() counts rows and columns; it does not inspect values.
  expect_identical(dim(d), c(12L, 3L))
  expect_identical(dim(d), dim(survey_data(d)))
  expect_identical(ncol(d), 3L)
  expect_identical(NCOL(d), 3L)
})

test_that("zero-weight rows do not reduce the reported size", {
  df <- data.frame(y = seq_len(12), w = rep(2, 12))
  d <- as_survey_nonprob(df, weights = w)

  # E8 — zero weights are physically present in real non-probability data
  # after trimming, but the weight validator does not accept them, so they
  # are injected after construction with S7::set_props(). This is the same
  # route test-analysis-variance-twophase-nonprob.R uses.
  df_zero <- df
  df_zero$w[c(1L, 2L, 7L)] <- 0
  d <- S7::set_props(d, data = df_zero)
  stored <- survey_data(d)

  expect_identical(dim(d), c(12L, 2L))
  expect_identical(dim(d), dim(stored))
  expect_identical(nrow(d), nrow(stored))
  expect_identical(NROW(d), nrow(stored))
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
})

test_that("the five size functions raise on a one-member collection", {
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 131)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(only_member = d, group = character(0))

  # E9 — B7 covers the message at n = 1; this covers all five functions, so
  # the count in the message is not the only thing verified there.
  expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  expect_error(nrow(cl), class = "surveycore_error_collection_no_dim")
  expect_error(ncol(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NROW(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NCOL(cl), class = "surveycore_error_collection_no_dim")
})

test_that("a collection whose members hold identical shapes still raises", {
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 132)
  d1 <- as_survey(df, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    copy_one = d1,
    copy_two = d2,
    group = character(0)
  )

  # E10 — the method does not inspect member shapes, so agreement between
  # members changes nothing. That keeps the contract one sentence long and
  # keeps the answer stable when a member is later replaced.
  expect_identical(dim(survey_data(d1)), dim(survey_data(d2)))
  expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  expect_error(nrow(cl), class = "surveycore_error_collection_no_dim")
  expect_error(ncol(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NROW(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NCOL(cl), class = "surveycore_error_collection_no_dim")
})

test_that("a grouped collection raises and its grouping stays out of it", {
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 133)

  # The group column name must not be a substring of any member name, and
  # no member name may be a substring of it: the message embeds the first
  # member's name, so overlapping names would make the absence check below
  # fail against a correct implementation.
  group_col <- "cohort"
  df1 <- df
  df1[[group_col]] <- "north"
  df2 <- df
  df2[[group_col]] <- "south"
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    site_a = d1,
    site_b = d2,
    group = all_of(group_col)
  )

  # E11
  expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  expect_error(nrow(cl), class = "surveycore_error_collection_no_dim")
  expect_error(ncol(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NROW(cl), class = "surveycore_error_collection_no_dim")
  expect_error(NCOL(cl), class = "surveycore_error_collection_no_dim")

  cnd <- expect_error(dim(cl), class = "surveycore_error_collection_no_dim")
  expect_identical(cl@groups, group_col)
  expect_false(grepl(group_col, conditionMessage(cnd), fixed = TRUE))
})

test_that("the column count reports the stored frame, not printed columns", {
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 134)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  full_dim <- dim(d)

  # This is the state the ecosystem's column-selection verb leaves behind
  # when it keeps a design variable that variance estimation needs but the
  # user did not select. Setting the entry directly needs no suggested
  # package.
  d@variables[["visible_vars"]] <- c("y1", "y2")
  stored <- survey_data(d)

  # E12 — the full stored width, not 2L. This is the expected result, not a
  # bug: the stored frame is what variance estimation reads, so a count
  # that followed the print filter would under-report the data the design
  # holds. A future change that makes this row fail is a change in print
  # semantics, not a fix.
  expect_identical(ncol(d), ncol(stored))
  expect_identical(NCOL(d), ncol(stored))
  expect_gt(ncol(d), 2L)
  expect_identical(dim(d), full_dim)
  expect_identical(nrow(d), nrow(stored))
})


# ── regression rows ──────────────────────────────────────────────────────────
# R6, R9, R10 and R11. R1-R3, R7 and R8 sit in the survey_taylor block
# above. R4 and R5 — the print and summary output of the four design classes
# — are already snapshotted elsewhere in the suite and are verified as a
# gate: no existing snapshot file may be rewritten by this change.

test_that("print() on a survey_collection still renders", {
  df1 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 141)
  df2 <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 142)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    wave_one = d1,
    wave_two = d2,
    group = character(0)
  )

  # R6 — a smoke test, not a snapshot. The collection print path reads each
  # member's stored row count, not the collection's, so it never reaches
  # the raising method. Had it read the collection's, this change would
  # break printing on every collection.
  # The collection print method writes its lines through cli, which sends
  # them to the message stream, so the capture asks for that stream.
  printed <- capture.output(
    visible <- withVisible(print(cl)),
    type = "message"
  )
  expect_gt(length(printed), 0L)
  expect_false(visible$visible)
})

test_that("dim() on an analysis result reports the result's own shape", {
  df <- make_survey_data(n = 400, n_psu = 20, n_strata = 2, seed = 143)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  # R9 — the analysis results are tibbles, not designs. A method registered
  # too broadly would change these. The oracle is the list structure of the
  # tibble, which does not read dim().
  r_means <- get_means(d, x = y1)
  expect_identical(dim(r_means), c(length(r_means[[1L]]), length(r_means)))

  r_freqs <- get_freqs(d, x = group)
  expect_identical(dim(r_freqs), c(length(r_freqs[[1L]]), length(r_freqs)))
})

test_that("dim() on a collection analysis result reports the shape", {
  df1 <- make_survey_data(n = 400, n_psu = 20, n_strata = 2, seed = 144)
  df2 <- make_survey_data(n = 400, n_psu = 20, n_strata = 2, seed = 145)
  d1 <- as_survey(df1, ids = psu, weights = wt, strata = strata)
  d2 <- as_survey(df2, ids = psu, weights = wt, strata = strata)
  cl <- as_survey_collection(
    wave_one = d1,
    wave_two = d2,
    group = character(0)
  )

  # R10 — the same reason as R9, on the dispatch path. The result is a
  # tibble even though the input raises on dim().
  r <- get_means(cl, x = y1)
  expect_identical(dim(r), c(length(r[[1L]]), length(r)))
  expect_identical(nrow(r), 2L)
})

test_that("the survey-package conversion still returns its class and shape", {
  skip_if_not_installed("survey")
  df <- make_survey_data(n = 60, n_psu = 10, n_strata = 2, seed = 146)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  # R11 — the conversion reads the stored frame, so a mis-registered method
  # could reach it.
  sv <- as_svydesign(d)
  expect_s3_class(sv, "survey.design")
  expect_identical(dim(sv$variables), dim(survey_data(d)))
})
