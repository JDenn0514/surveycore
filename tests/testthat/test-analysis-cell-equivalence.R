# Golden-fixture equivalence tests for the six cell-building analysis
# functions: get_freqs(), get_means(), get_totals(), get_variance(),
# get_covariance() and get_ratios(), plus get_quantiles() and
# get_effective_n(), which share their cell code.
#
# tests/testthat/fixtures/analysis-cell-golden.rds holds the results and
# warnings of 261 scenarios, recorded on the base commit by
# data-raw/analysis-cell-golden.R. The helpers and the scenario list are in
# tests/testthat/helper-cell-golden.R.

# The file builds several hundred designs and runs every scenario, so it is
# slow. It skips on CRAN for run time only; it needs no resource CRAN lacks.
skip_on_cran()

# Ids of one function's scenarios. A noisy id is in cell_golden_noisy. A quiet
# id records no warning in the fixture and is not in cell_golden_noisy.
golden_ids <- function(fixture, prefix, noisy) {
  ids <- names(fixture$results)
  ids <- ids[startsWith(ids, prefix)]
  in_noisy <- ids %in% names(cell_golden_noisy)
  if (noisy) {
    return(ids[in_noisy])
  }
  ids[!in_noisy & lengths(fixture$warnings[ids]) == 0L]
}

expect_quiet_golden <- function(prefix) {
  fixture <- cell_golden_fixture()
  scenarios <- cell_golden_scenarios()
  ids <- unlist(lapply(prefix, golden_ids, fixture = fixture, noisy = FALSE))
  expect_gt(length(ids), 0L)
  for (id in ids) {
    r <- expect_warning_count(scenarios[[id]](), character(0), 0L)
    expect_matches_golden(r, fixture$results[[id]], id)
  }
}

expect_noisy_golden <- function(prefix) {
  fixture <- cell_golden_fixture()
  scenarios <- cell_golden_scenarios()
  ids <- golden_ids(fixture, prefix, noisy = TRUE)
  expect_gt(length(ids), 0L)
  for (id in ids) {
    r <- expect_warning_count(
      scenarios[[id]](),
      cell_golden_noisy[[id]],
      length(cell_golden_noisy[[id]])
    )
    expect_matches_golden(r, fixture$results[[id]], id)
  }
}

# ------------------------------------------------------------------------------
# Fixture integrity
# ------------------------------------------------------------------------------

test_that("the golden fixture designs build and pass the design invariants", {
  test_invariants(cell_golden_design("tay"))
  test_invariants(cell_golden_design("rep"))
  test_invariants(cell_golden_design("tph"))
  test_invariants(cell_golden_design("np_srs"))
})

test_that("every golden scenario is asserted by at least one block", {
  fixture <- cell_golden_fixture()
  expect_setequal(names(fixture$results), names(cell_golden_scenarios()))
  expect_length(fixture$results, 261L)
  expect_setequal(names(fixture$warnings), names(fixture$results))
  expect_setequal(
    names(cell_golden_noisy),
    names(Filter(length, fixture$warnings))
  )
  for (id in names(cell_golden_noisy)) {
    expect_identical(
      sort(cell_golden_noisy[[id]]),
      sort(fixture$warnings[[id]])
    )
  }
})

test_that("the six analysis functions keep their base-commit formals", {
  fixture <- cell_golden_fixture()
  fns <- list(
    get_freqs = get_freqs,
    get_means = get_means,
    get_totals = get_totals,
    get_variance = get_variance,
    get_covariance = get_covariance,
    get_ratios = get_ratios
  )
  for (name in names(fns)) {
    expect_identical(formals(fns[[name]]), fixture$formals[[name]])
  }
})

# ------------------------------------------------------------------------------
# Quiet scenarios: no warning, and the base-commit result
# ------------------------------------------------------------------------------

test_that("get_freqs() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("freqs/")
})

test_that("get_means() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("means/")
})

test_that("get_totals() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("totals/")
})

test_that("get_variance() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("variance/")
})

test_that("get_covariance() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("covariance/")
})

test_that("get_ratios() matches the base-commit results on every quiet scenario", {
  expect_quiet_golden("ratios/")
})

test_that("get_quantiles() and get_effective_n() match the base-commit results", {
  expect_quiet_golden(c("quantiles/", "effn/"))
})

# ------------------------------------------------------------------------------
# Noisy scenarios: the base-commit warnings, and the base-commit result
# ------------------------------------------------------------------------------

test_that("get_freqs() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("freqs/")
})

test_that("get_means() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("means/")
})

test_that("get_totals() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("totals/")
})

test_that("get_variance() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("variance/")
})

test_that("get_covariance() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("covariance/")
})

test_that("get_ratios() raises the base-commit warnings and results on every noisy scenario", {
  expect_noisy_golden("ratios/")
})

# ------------------------------------------------------------------------------
# Cross-function rows
# ------------------------------------------------------------------------------

test_that("a call that errors under lonely.psu fail raises no small-cell warning", {
  withr::local_options(survey.lonely.psu = "fail")
  calls <- cell_core_calls(cell_golden_design("lonely"), min_cell_n = 1000L)
  for (fn in calls) {
    expect_no_warning(
      expect_error(fn(), class = "surveycore_error_lonely_psu")
    )
  }
})

# Runs the core calls named in `warnings` on both designs of
# make_domain_pair(class): `a` stores NA in the domain marker, `b` stores
# FALSE in its place. Asserts the warnings each call raises (the same on both
# sides) and that the two results agree. The pair's frame has no f5 column,
# so get_freqs() runs on y3. These rows are not in the fixture: both sides
# run the current code.
expect_na_marker_matches <- function(class, warnings) {
  pair <- make_domain_pair(class)
  ca <- cell_core_calls(pair$a, freqs_x = "y3")
  cb <- cell_core_calls(pair$b, freqs_x = "y3")
  for (fn in names(warnings)) {
    w <- warnings[[fn]]
    ra <- expect_warning_count(ca[[fn]](), w, length(w))
    rb <- expect_warning_count(cb[[fn]](), w, length(w))
    expect_matches_golden(ra, cell_golden_strip(rb), fn)
  }
}

# get_covariance() warns once that cv is undefined for a cell whose
# covariance is 0 or negative, on both sides.
na_marker_warnings <- list(
  freqs = character(0),
  means = character(0),
  totals = character(0),
  variance = character(0),
  covariance = "surveycore_warning_cv_undefined",
  ratios = character(0)
)

test_that("an NA domain marker gives the same results as FALSE on a Taylor design", {
  expect_na_marker_matches("taylor", na_marker_warnings)
})

test_that("an NA domain marker gives the same results as FALSE on a replicate design", {
  expect_na_marker_matches("replicate", na_marker_warnings)
})

test_that("an NA domain marker gives the same results as FALSE on a two-phase design", {
  expect_na_marker_matches("twophase", na_marker_warnings)
})

test_that("an NA domain marker gives the same results as FALSE on a nonprob design without replicate weights", {
  # One fallback warning per cell: three groups.
  expect_na_marker_matches(
    "nonprob",
    list(means = rep("surveycore_warning_nonprob_srs_fallback", 3L))
  )
})

# ------------------------------------------------------------------------------
# get_variance() rows
# ------------------------------------------------------------------------------

test_that("get_variance() and get_covariance() results carry no stored covariance matrix", {
  ids <- c(
    "variance/tay_c_na",
    "variance/blk65",
    "covariance/tay_c_na",
    "covariance/blk65"
  )
  scenarios <- cell_golden_scenarios()
  for (id in ids) {
    w <- cell_golden_noisy[[id]]
    if (is.null(w)) {
      w <- character(0)
    }
    r <- expect_warning_count(scenarios[[id]](), w, length(w))
    expect_null(attr(r, ".vcov"))
  }
})

test_that("get_variance() gives each clean group the SE of its own domain when another group has an Inf", {
  expect_groups_match_domain(
    "variance/tay_y1_inf",
    "tay",
    function(d) {
      get_variance(
        d,
        y1_inf,
        variance = .cg_variance,
        n_weighted = TRUE,
        min_cell_n = 0L
      )
    },
    "variance"
  )
})

test_that("get_variance() errors when every replicate weight is NA on a row inside a cell", {
  d <- cell_golden_design("rep_allna")
  expect_error(
    get_variance(
      d,
      y1,
      group = group,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "surveycore_error_all_replicates_na"
  )
  expect_snapshot(error = TRUE, {
    get_variance(
      d,
      y1,
      group = group,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    )
  })
})

test_that("get_variance() errors on a single-PSU stratum when lonely.psu is fail", {
  calls <- cell_core_calls(cell_golden_design("lonely"))
  withr::local_options(survey.lonely.psu = "fail")
  expect_error(calls$variance(), class = "surveycore_error_lonely_psu")
  expect_snapshot(error = TRUE, calls$variance())
})

test_that("get_variance() errors on a single-PSU stratum when lonely.psu is an unknown value", {
  calls <- cell_core_calls(cell_golden_design("lonely"))
  withr::local_options(survey.lonely.psu = "unknown_value")
  expect_error(
    calls$variance(),
    class = "surveycore_error_lonely_psu_unknown_option"
  )
  expect_snapshot(error = TRUE, calls$variance())
})

test_that("get_variance() errors on a single-PSU stratum under fail when the call has 65 cells", {
  d <- cell_golden_design("lonely")
  withr::local_options(survey.lonely.psu = "fail")
  expect_error(
    get_variance(
      d,
      y1,
      group = g65,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "surveycore_error_lonely_psu"
  )
  expect_snapshot(error = TRUE, {
    get_variance(
      d,
      y1,
      group = g65,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    )
  })
})

test_that("get_variance() errors on a single-PSU stratum under fail when its only cell has an NA and na.rm = FALSE", {
  # Ungrouped: the one cell is the only cell that reaches the variance step,
  # and it has an NA (at b1) in its active domain. A flush that skipped a cell
  # under the na.rm = FALSE override would raise nothing.
  d <- cell_golden_design("lonely")
  withr::local_options(survey.lonely.psu = "fail")
  expect_error(
    get_variance(
      d,
      y1_na,
      na.rm = FALSE,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "surveycore_error_lonely_psu"
  )
  expect_snapshot(error = TRUE, {
    get_variance(
      d,
      y1_na,
      na.rm = FALSE,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    )
  })
})

test_that("get_variance() still errors when a base weight inside a cell is NA", {
  # Base R raises this error, so it has no surveycore class and no snapshot.
  d <- cell_golden_design("nawt_in")
  expect_error(
    get_variance(
      d,
      y1,
      group = group,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "simpleError"
  )
})

# ------------------------------------------------------------------------------
# get_freqs() rows
# ------------------------------------------------------------------------------

test_that("get_freqs() errors when every replicate weight is NA on a row outside the domain", {
  d <- cell_golden_design("rep_allna_dom")
  expect_error(
    get_freqs(
      d,
      f5,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "surveycore_error_all_replicates_na"
  )
  expect_snapshot(error = TRUE, {
    get_freqs(
      d,
      f5,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    )
  })
})

test_that("get_freqs() errors on a single-PSU stratum when lonely.psu is fail", {
  calls <- cell_core_calls(cell_golden_design("lonely"))
  withr::local_options(survey.lonely.psu = "fail")
  expect_error(calls$freqs(), class = "surveycore_error_lonely_psu")
  expect_snapshot(error = TRUE, calls$freqs())
})

test_that("get_freqs() errors on a single-PSU stratum when lonely.psu is an unknown value", {
  calls <- cell_core_calls(cell_golden_design("lonely"))
  withr::local_options(survey.lonely.psu = "unknown_value")
  expect_error(
    calls$freqs(),
    class = "surveycore_error_lonely_psu_unknown_option"
  )
  expect_snapshot(error = TRUE, calls$freqs())
})

test_that("get_freqs() still errors when a base weight is Inf", {
  # Base R raises this error, so it has no surveycore class and no snapshot.
  d <- cell_golden_design("infwt")
  expect_error(
    get_freqs(
      d,
      f5,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "simpleError"
  )
})

test_that("get_freqs() errors on an all-NA variable when na.rm is FALSE", {
  d <- cell_golden_design("tay")
  expect_error(
    get_freqs(
      d,
      y_allna,
      na.rm = FALSE,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    ),
    class = "surveycore_error_all_na"
  )
  expect_snapshot(error = TRUE, {
    get_freqs(
      d,
      y_allna,
      na.rm = FALSE,
      variance = .cg_variance,
      n_weighted = TRUE,
      min_cell_n = 0L
    )
  })
})
