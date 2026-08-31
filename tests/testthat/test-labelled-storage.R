# tests/testthat/test-labelled-storage.R
#
# The storage contract for a frame that arrives carrying the haven labelled
# class. Two sources, and the rows are split along that line:
#
#   - the `data` property setter in R/core-classes.R normalises whatever
#     reaches `@data`;
#   - the four `.strip_labelled_columns(data)` calls on entry to `as_survey()`,
#     `as_survey_replicate()`, `as_survey_nonprob()` and `as_survey_twophase()`
#     in R/core-constructors.R normalise the caller's frame before any
#     validation reads a design column.
#
# The setter cannot reach the second group. A labelled `weights` or `fpc`
# column is compared and coerced on the raw caller frame, so the constructor
# aborts before any `@data` write happens and the setter never runs.
#
# Test structure:
#   S-1  to S-13 — storage: what the stored frame looks like after a write
#   S-14 to S-20 — design variables that carry the class and must still work
#   S-21 to S-23a — validation that must keep raising on a labelled column
#   S-23b to S-23h — the other three constructors, measured rather than
#                    inferred
#   S-30 to S-34 — SRS shape, probs, tagged NA, and the subset trap
#
# Two rows are traps for an over-broad fix. S-30 must keep raising, because a
# labelled column is never logical and a two-phase `subset` must be. S-12 must
# keep its class, because a bare `labelled` class carries no `vctrs_vctr` and
# never reaches the failing dispatch.
#
# Every labelled-versus-plain comparison is exact. The strip removes a class
# attribute and changes no value, so every estimate must come out bit for bit
# the same. No row uses a default tolerance.
#
# make_labelled(), make_labelled_spss() and make_tagged_na() live in
# helper-test-data.R.

# ── Fixtures ─────────────────────────────────────────────────────────────────

# One frame, 200 rows, 20 PSUs nested in 2 strata. `prob` supports the
# probs-to-weights routes, `ph2` the two-phase subset, `sub` the double-backed
# subset column that S-30 needs, `q` and `qi` the double- and integer-backed
# labelled outcomes.
.ls_frame <- function(n_rep = 0L, seed = 11L) {
  set.seed(seed)
  n <- 200L
  df <- data.frame(
    psu = rep(1:20, each = 10L),
    strata = rep(1:2, each = 100L),
    fpc = rep(c(5000, 6000), each = 100L),
    wt = runif(n, 0.5, 2),
    prob = runif(n, 0.2, 0.9),
    ph2 = rep(c(TRUE, FALSE), 100L),
    sub = rep(c(1, 0), 100L),
    y = runif(n, 10, 40),
    q = as.numeric(rep(1:4, 50L)),
    qi = rep(1:4, 50L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(n_rep)) {
    df[[paste0("rw", i)]] <- runif(n, 0.3, 3)
  }
  df
}

# The four value labels `q` and `qi` carry.
.ls_labels <- c(A = 1, B = 2, C = 3, D = 4)

# Attach the labelled class to the named columns. `labelled = FALSE` attaches
# the same `labels` and `label` attributes and then drops the class, so the two
# halves of every comparison differ in the class vector and in nothing else.
# The metadata harvest is therefore identical in both halves and cannot explain
# a difference the rows see.
.ls_mark <- function(df, cols, labelled = TRUE, labels = NULL) {
  for (nm in cols) {
    df[[nm]] <- make_labelled(df[[nm]], labels, paste("Label for", nm))
    if (!labelled) {
      attr(df[[nm]], "class") <- NULL
    }
  }
  df
}

# TRUE when any column of the stored frame still carries the class.
.ls_any_labelled <- function(design) {
  any(vapply(survey_data(design), inherits, logical(1L), "haven_labelled"))
}

# Evaluate `expr` with haven's vctrs methods removed, then put them back.
#
# The construction failures this file covers are vctrs dispatch failures. They
# fire only when haven's `vec_ptype2`, `vec_cast` and `vec_arith` methods are
# absent — the state on a machine that reads a .sav file written elsewhere and
# has no haven installed. `haven` is in Suggests, the suite installs it, and
# several test files load it, so by the time this file runs the methods are
# registered and every constructor row below would pass with the strip and
# without it.
#
# `unloadNamespace("haven")` does not undo the registration. Measured: R leaves
# all 42 entries haven wrote into the `vctrs` S3 method table in place, and the
# labelled design still constructs. Removing those entries for the duration of
# one call is the only way to put a row back under the condition the strip is
# for, and it is exact — measured on the unfixed tree, a labelled `weights` or
# `fpc` column aborts with `vctrs_error_ptype2` with the entries removed and
# constructs with them present.
#
# The removal is reversed on exit, including on an error, so no later test sees
# a changed table. When haven has never been loaded there is nothing to remove
# and `expr` already runs under the right condition.
.ls_without_haven <- function(expr) {
  tbl <- asNamespace("vctrs")[[".__S3MethodsTable__."]]
  hits <- grep("haven", ls(tbl, all.names = TRUE), value = TRUE)
  if (length(hits) > 0L) {
    saved <- mget(hits, envir = tbl)
    rm(list = hits, envir = tbl)
    on.exit(list2env(saved, envir = tbl), add = TRUE)
  }
  expr
}

# Build the labelled design and its plain twin from the same builder, then run
# `fn` on each. Both designs are bound to the same symbol, so the call each
# result records is the same language object and the two results compare
# exactly. Construction is wrapped too: an abort there is the defect this file
# covers, and the caller wants to see which half raised.
#
# Only the labelled half builds with haven's vctrs methods removed. The plain
# half never reaches vctrs, and after the strip neither does anything
# downstream of construction, so `fn` runs the same way in both halves.
.ls_both <- function(build, fn) {
  expect_no_error(d <- .ls_without_haven(build(TRUE)))
  labelled_design <- d
  expect_no_error(labelled <- fn(d))
  expect_no_error(d <- build(FALSE))
  expect_no_error(plain <- fn(d))
  list(labelled = labelled, plain = plain, design = labelled_design)
}


# ── S. Storage ───────────────────────────────────────────────────────────────

test_that("S-1: as_survey() stores a labelled column without the class", {
  df <- .ls_mark(.ls_frame(), "q", labels = .ls_labels)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  test_invariants(d)
  expect_false(.ls_any_labelled(d))
  expect_identical(attr(survey_data(d)$q, "labels"), .ls_labels)
  expect_identical(extract_val_labels(d, q), list(q = .ls_labels))
})

test_that("S-2: as_survey_replicate() stores a labelled column stripped", {
  df <- .ls_mark(.ls_frame(n_rep = 8L), "q", labels = .ls_labels)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("rw"),
    type = "bootstrap"
  )

  test_invariants(d)
  expect_false(.ls_any_labelled(d))
  expect_identical(attr(survey_data(d)$q, "labels"), .ls_labels)
  expect_identical(extract_val_labels(d, q), list(q = .ls_labels))
})

test_that("S-3: as_survey_nonprob() stores a labelled column stripped", {
  df <- .ls_mark(.ls_frame(n_rep = 8L), "q", labels = .ls_labels)
  d <- as_survey_nonprob(
    df,
    weights = wt,
    repweights = tidyselect::starts_with("rw"),
    type = "bootstrap"
  )

  test_invariants(d)
  expect_false(.ls_any_labelled(d))
  expect_identical(attr(survey_data(d)$q, "labels"), .ls_labels)
  expect_identical(extract_val_labels(d, q), list(q = .ls_labels))
})

test_that("S-4: as_survey_twophase() stores a labelled column stripped", {
  df <- .ls_mark(.ls_frame(), "q", labels = .ls_labels)
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  d <- as_survey_twophase(phase1, subset = ph2, method = "approx")

  test_invariants(d)
  expect_false(.ls_any_labelled(d))
  expect_identical(attr(survey_data(d)$q, "labels"), .ls_labels)
  expect_identical(extract_val_labels(d, q), list(q = .ls_labels))
})

test_that("S-5: every column labelled leaves no labelled column stored", {
  # Direct S7 construction. No constructor entry point runs, so this row is
  # about the property setter alone, and it can label the design columns too
  # without meeting the validation the constructor rows cover.
  df <- .ls_mark(.ls_frame(), names(.ls_frame()))
  expect_true(all(vapply(df, inherits, logical(1L), "haven_labelled")))

  d <- survey_taylor(
    data = df,
    variables = list(
      ids = "psu",
      weights = "wt",
      strata = "strata",
      fpc = NULL,
      nest = FALSE,
      probs_provided = FALSE,
      visible_vars = NULL
    )
  )

  expect_false(.ls_any_labelled(d))
})

test_that("S-6: a frame with no labelled column is stored unchanged", {
  df <- .ls_frame()
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_identical(survey_data(d), df)
})

test_that("S-7: nhanes_2017 is stored unchanged, with no type change", {
  d <- as_survey(
    nhanes_2017,
    ids = sdmvpsu,
    weights = wtint2yr,
    strata = sdmvstra,
    nest = TRUE
  )

  expect_identical(survey_data(d), nhanes_2017)
  expect_identical(
    vapply(survey_data(d), typeof, character(1L)),
    vapply(nhanes_2017, typeof, character(1L))
  )
})

test_that("S-8: a labelled integer column stays an integer once stored", {
  df <- .ls_mark(.ls_frame(), "qi", labels = c(A = 1L, B = 2L, C = 3L, D = 4L))
  expect_identical(typeof(df$qi), "integer")

  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_false(inherits(survey_data(d)$qi, "haven_labelled"))
  expect_identical(typeof(survey_data(d)$qi), "integer")
  expect_true(is.integer(survey_data(d)$qi))
})

test_that("S-9: an SPSS labelled column keeps all four attributes", {
  df <- .ls_frame()
  df$q <- make_labelled_spss(
    df$q,
    labels = .ls_labels,
    na_values = c(98, 99),
    na_range = c(90, 99),
    label = "Agreement"
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  stored <- survey_data(d)$q

  expect_false(inherits(stored, "haven_labelled"))
  expect_identical(attr(stored, "labels", exact = TRUE), .ls_labels)
  expect_identical(attr(stored, "label", exact = TRUE), "Agreement")
  expect_identical(attr(stored, "na_values", exact = TRUE), c(98, 99))
  expect_identical(attr(stored, "na_range", exact = TRUE), c(90, 99))
})

test_that("S-10: a tagged NA survives storage as an NA that keeps its tag", {
  df <- .ls_frame()
  df$q[c(1L, 2L)] <- c(make_tagged_na("a"), make_tagged_na("b"))
  df$q <- make_labelled(df$q, .ls_labels, "Agreement")

  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  stored <- survey_data(d)$q

  expect_false(inherits(stored, "haven_labelled"))
  expect_identical(is.na(stored[1:2]), c(TRUE, TRUE))

  skip_if_not_installed("haven")
  expect_identical(haven::na_tag(stored[1:2]), c("a", "b"))
})

test_that("S-11: label attributes without a class are stored unchanged", {
  # This proves the strip keys on the class vector, not on the attributes. A
  # column carrying `label` and `labels` and no class never reached the failing
  # vctrs dispatch, so nothing about it may change.
  df <- .ls_frame()
  attr(df$q, "labels") <- .ls_labels
  attr(df$q, "label") <- "Agreement"

  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_identical(survey_data(d), df)
  expect_identical(survey_data(d)$q, df$q)
  expect_null(attr(survey_data(d)$q, "class", exact = TRUE))
})

test_that("S-12: a bare `labelled` class is kept, not stripped", {
  # The legacy shape from the `labelled` package: one class entry, no
  # `vctrs_vctr` under it, so no vctrs dispatch and no defect. Deliberately
  # left alone. A change here means the strip reaches too far.
  df <- .ls_frame()
  attr(df$q, "labels") <- .ls_labels
  attr(df$q, "class") <- "labelled"

  d <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_identical(class(survey_data(d)$q), "labelled")
  expect_identical(survey_data(d)$q, df$q)
})

test_that("S-13: a tibble input stays a tibble and loses the class", {
  df <- tibble::as_tibble(.ls_mark(.ls_frame(), "q", labels = .ls_labels))
  d <- as_survey(df, ids = psu, weights = wt, strata = strata)
  stored <- survey_data(d)

  expect_true(tibble::is_tibble(stored))
  expect_false(.ls_any_labelled(d))
  expect_identical(attr(stored$q, "labels", exact = TRUE), .ls_labels)
})


# ── S. Design variables that carry the class ─────────────────────────────────

test_that("S-14: a labelled weight column estimates as the plain one does", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "wt", labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata)
  }
  # `variance = "se"` puts the standard error in the result. The point estimate
  # alone would pass even if the weights were silently dropped.
  out <- .ls_both(build, function(d) get_means(d, y, variance = "se"))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
  expect_equal(out$labelled$se, out$plain$se, tolerance = 0)
  expect_false(anyNA(out$labelled$se))
})

test_that("S-15: a labelled fpc column estimates as the plain one does", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "fpc", labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata, fpc = fpc)
  }
  # The FPC moves the standard error, not the point estimate, so the standard
  # error is the assertion that can see a dropped FPC.
  out <- .ls_both(build, function(d) get_totals(d, y, variance = "se"))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
  expect_equal(out$labelled$se, out$plain$se, tolerance = 0)
  expect_false(anyNA(out$labelled$se))
})

test_that("S-16: labelled cluster and stratum columns work with nest = FALSE", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), c("psu", "strata"), labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata, nest = FALSE)
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-17: labelled cluster and stratum columns work with nest = TRUE", {
  # A regression fence, not evidence. This path skips .validate_psu_strata(),
  # so it passed before the strip existed. One logical argument must not decide
  # whether the same design constructs.
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), c("psu", "strata"), labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata, nest = TRUE)
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-18: a labelled cluster column alone works, and a stratum alone", {
  build_psu <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "psu", labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata)
  }
  out_psu <- .ls_both(build_psu, function(d) get_means(d, y))
  expect_identical(out_psu$labelled, out_psu$plain)

  build_strata <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "strata", labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata)
  }
  out_strata <- .ls_both(build_strata, function(d) get_means(d, y))
  expect_identical(out_strata$labelled, out_strata$plain)
})

test_that("S-19: a labelled probs column derives weights as 1 / probs", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "prob", labelled)
    as_survey(d, ids = psu, weights = NULL, probs = prob, strata = strata)
  }
  out <- .ls_both(build, function(d) get_means(d, y))
  d <- out$design

  expect_false(.ls_any_labelled(d))
  expect_identical(d@variables$weights, "..surveycore_wt..")
  expect_equal(
    survey_data(d)[["..surveycore_wt.."]],
    1 / survey_data(d)$prob,
    tolerance = 0
  )
  expect_identical(out$labelled, out$plain)
})

test_that("S-20: labelled replicate weight columns estimate as plain ones", {
  rw <- paste0("rw", 1:8)
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(n_rep = 8L), rw, labelled)
    as_survey_replicate(
      d,
      weights = wt,
      repweights = tidyselect::all_of(rw),
      type = "bootstrap"
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})


# ── S. Validation that must keep raising ─────────────────────────────────────

test_that("S-21: a labelled weight column with a zero still raises", {
  df <- .ls_frame()
  df$wt[5L] <- 0
  df <- .ls_mark(df, "wt")

  expect_error(
    .ls_without_haven(as_survey(df, ids = psu, weights = wt, strata = strata)),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, strata = strata)
  )
})

test_that("S-22: an all-zero labelled weight column still raises", {
  df <- .ls_frame()
  df$wt[] <- 0
  df <- .ls_mark(df, "wt")

  expect_error(
    .ls_without_haven(as_survey(df, ids = psu, weights = wt, strata = strata)),
    class = "surveycore_error_weights_all_zero"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, strata = strata)
  )
})

test_that("S-23: a labelled fpc column with a non-positive value raises", {
  df <- .ls_frame()
  df$fpc[7L] <- -1
  df <- .ls_mark(df, "fpc")

  expect_error(
    .ls_without_haven(
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    ),
    class = "surveycore_error_fpc_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
})

test_that("S-23a: a labelled fpc column holding an NA raises", {
  df <- .ls_frame()
  df$fpc[7L] <- NA
  df <- .ls_mark(df, "fpc")

  expect_error(
    .ls_without_haven(
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    ),
    class = "surveycore_error_fpc_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
})


# ── S. The other three constructors, measured ────────────────────────────────

test_that("S-23b: as_survey_replicate() takes a labelled weight column", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(n_rep = 8L), "wt", labelled)
    as_survey_replicate(
      d,
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-23c: as_survey_replicate() takes a labelled fpc column", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(n_rep = 8L), "fpc", labelled)
    as_survey_replicate(
      d,
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap",
      fpc = fpc
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-23d: as_survey_nonprob() takes a labelled weight column", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(n_rep = 8L), "wt", labelled)
    as_survey_nonprob(
      d,
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-23e: as_survey_nonprob() takes labelled replicate weights", {
  rw <- paste0("rw", 1:8)
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(n_rep = 8L), rw, labelled)
    as_survey_nonprob(
      d,
      weights = wt,
      repweights = tidyselect::all_of(rw),
      type = "bootstrap"
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-23f: as_survey_replicate() still raises on a zero weight", {
  df <- .ls_frame(n_rep = 8L)
  df$wt[5L] <- 0
  df <- .ls_mark(df, "wt")

  expect_error(
    .ls_without_haven(
      as_survey_replicate(
        df,
        weights = wt,
        repweights = tidyselect::starts_with("rw"),
        type = "bootstrap"
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_replicate(
      df,
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    )
  )
})

test_that("S-23g: as_survey_nonprob() still raises on a zero weight", {
  df <- .ls_frame(n_rep = 8L)
  df$wt[5L] <- 0
  df <- .ls_mark(df, "wt")

  expect_error(
    .ls_without_haven(
      as_survey_nonprob(
        df,
        weights = wt,
        repweights = tidyselect::starts_with("rw"),
        type = "bootstrap"
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_nonprob(
      df,
      weights = wt,
      repweights = tidyselect::starts_with("rw"),
      type = "bootstrap"
    )
  )
})

test_that("S-23h: labelled phase-2 design columns estimate as plain ones", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), c("strata", "prob", "fpc"), labelled)
    phase1 <- as_survey(d, ids = psu, weights = wt)
    as_survey_twophase(
      phase1,
      strata2 = strata,
      probs2 = prob,
      subset = ph2,
      method = "full"
    )
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})


# ── S. SRS shape, probs, tagged NAs, and the subset trap ─────────────────────

test_that("S-30: a labelled two-phase subset column still raises", {
  # The trap for an over-broad fix. A two-phase `subset` must be logical, and a
  # haven labelled column never is: haven backs the class with a double, an
  # integer or a character. Stripping the class leaves a double, so this input
  # is invalid before and after and must keep failing.
  df <- .ls_mark(.ls_frame(), "sub", labels = c(No = 0, Yes = 1))
  phase1 <- as_survey(df, ids = psu, weights = wt, strata = strata)

  expect_error(
    .ls_without_haven(
      as_survey_twophase(phase1, subset = sub, method = "approx")
    ),
    class = "surveycore_error_subset_not_logical"
  )
  expect_snapshot(
    error = TRUE,
    as_survey_twophase(phase1, subset = sub, method = "approx")
  )
})

test_that("S-31: the SRS shape takes a labelled weight column", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "wt", labelled)
    as_survey(d, weights = wt)
  }
  out <- .ls_both(build, function(d) get_means(d, y))

  expect_false(.ls_any_labelled(out$design))
  expect_identical(out$labelled, out$plain)
})

test_that("S-32: the SRS shape takes a labelled probs column", {
  build <- function(labelled) {
    d <- .ls_mark(.ls_frame(), "prob", labelled)
    as_survey(d, probs = prob)
  }
  out <- .ls_both(build, function(d) get_means(d, y))
  d <- out$design

  expect_false(.ls_any_labelled(d))
  expect_equal(
    survey_data(d)[["..surveycore_wt.."]],
    1 / survey_data(d)$prob,
    tolerance = 0
  )
  expect_identical(out$labelled, out$plain)
})

test_that("S-33: a labelled weight column with a tagged NA constructs", {
  # Measured: it constructs. .validate_weights() drops NA weights before every
  # value check, so no missing-weight class applies, and a tagged NA is an NA.
  # The design therefore matches its plain twin exactly.
  build <- function(labelled) {
    d <- .ls_frame()
    d$wt[3L] <- make_tagged_na("a")
    d <- .ls_mark(d, "wt", labelled)
    as_survey(d, ids = psu, weights = wt, strata = strata)
  }
  expect_no_error(d <- .ls_without_haven(build(TRUE)))
  expect_no_error(plain <- build(FALSE))

  expect_false(.ls_any_labelled(d))
  expect_true(is.na(survey_data(d)$wt[3L]))
  expect_identical(survey_data(d), survey_data(plain))
})

test_that("S-34: a labelled fpc column with a tagged NA still raises", {
  df <- .ls_frame()
  df$fpc[3L] <- make_tagged_na("a")
  df <- .ls_mark(df, "fpc")

  expect_error(
    .ls_without_haven(
      as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
    ),
    class = "surveycore_error_fpc_na"
  )
  expect_snapshot(
    error = TRUE,
    as_survey(df, ids = psu, weights = wt, strata = strata, fpc = fpc)
  )
})
