# tests/testthat/test-s7-classes.R
#
# Tests for S7 class definitions in R/00-s7-classes.R.
#
# Coverage: error-messages.md rows 31–35 (S7 Layer 1 validator errors).
# Per testing-standards.md: validator errors use expect_error(class=) only
# — no expect_snapshot(), because S7 validator messages are not CLI-formatted
# the same way as Layer 3 constructor errors.


# ── Helpers ────────────────────────────────────────────────────────────────────

# Build a minimal variables list for survey_taylor with all keys present.
.taylor_vars <- function(
  weights       = "wt",
  ids           = NULL,
  strata        = NULL,
  fpc           = NULL,
  nest          = FALSE,
  probs_provided = FALSE
) {
  list(
    ids            = ids,
    weights        = weights,
    strata         = strata,
    fpc            = fpc,
    nest           = nest,
    probs_provided = probs_provided,
    visible_vars   = NULL
  )
}

# Build a minimal variables list for survey_replicate with all keys present.
.rep_vars <- function(
  weights     = "wt",
  repweights  = c("rw1", "rw2"),
  type        = "BRR",
  scale       = 1,
  rscales     = NULL,
  fpc         = NULL,
  fpctype     = "fraction",
  mse         = TRUE
) {
  list(
    weights      = weights,
    repweights   = repweights,
    type         = type,
    scale        = scale,
    rscales      = rscales,
    fpc          = fpc,
    fpctype      = fpctype,
    mse          = mse,
    visible_vars = NULL
  )
}

# A small valid data frame for survey_taylor tests.
.df10 <- function(seed = 42L) {
  set.seed(seed)
  data.frame(
    psu    = paste0("psu_", rep(1:5, 2)),
    strata = paste0("s", rep(1:2, each = 5)),
    fpc    = rep(c(500L, 600L), each = 5),
    wt     = runif(10, 0.5, 2),
    y      = rnorm(10),
    stringsAsFactors = FALSE
  )
}

# A small valid data frame for survey_replicate tests.
.df_rep <- function(R = 4L, seed = 42L) {
  set.seed(seed)
  df <- data.frame(
    wt = runif(20, 0.5, 2),
    y  = rnorm(20),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(R)) {
    df[[paste0("rw", i)]] <- runif(20, 0.3, 3)
  }
  df
}


# ── survey_metadata ────────────────────────────────────────────────────────────

test_that("survey_metadata() creates object with empty default lists", {
  m <- survey_metadata()
  expect_true(S7::S7_inherits(m, survey_metadata))
  expect_identical(m@variable_labels,   list())
  expect_identical(m@value_labels,      list())
  expect_identical(m@question_prefaces, list())
  expect_identical(m@notes,             list())
  expect_identical(m@transformations,   list())
})

test_that("survey_metadata() stores variable labels correctly", {
  m <- survey_metadata(
    variable_labels = list(age = "Age in years", income = "Annual income")
  )
  expect_identical(m@variable_labels$age,    "Age in years")
  expect_identical(m@variable_labels$income, "Annual income")
})

test_that("survey_metadata() stores value labels correctly", {
  m <- survey_metadata(
    value_labels = list(sex = c(Male = 1L, Female = 2L))
  )
  expect_identical(m@value_labels$sex, c(Male = 1L, Female = 2L))
})


# ── survey_base ────────────────────────────────────────────────────────────────

test_that("survey_base cannot be instantiated directly (abstract class)", {
  df <- data.frame(x = 1)
  expect_error(
    survey_base(data = df),
    regexp = "abstract"
  )
})


# ── survey_taylor — happy paths ────────────────────────────────────────────────

test_that("survey_taylor() creates valid object for simple random sample", {
  df <- data.frame(y = rnorm(20), wt = runif(20, 0.5, 2))
  d  <- survey_taylor(
    data      = df,
    variables = .taylor_vars(weights = "wt")
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$weights, "wt")
  expect_identical(d@variables$ids,     NULL)
  expect_identical(d@variables$strata,  NULL)
  expect_identical(d@variables$fpc,     NULL)
  expect_false(d@variables$nest)
  expect_false(d@variables$probs_provided)
})

test_that("survey_taylor() creates valid object for stratified cluster design", {
  set.seed(42)
  df <- .df10()
  d  <- survey_taylor(
    data      = df,
    variables = .taylor_vars(
      weights = "wt",
      ids     = "psu",
      strata  = "strata",
      fpc     = "fpc",
      nest    = TRUE
    )
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_taylor))
  expect_identical(d@variables$ids,    "psu")
  expect_identical(d@variables$strata, "strata")
  expect_identical(d@variables$fpc,    "fpc")
  expect_true(d@variables$nest)
})

test_that("survey_taylor() creates valid object for two-stage cluster design", {
  df <- data.frame(
    psu = paste0("p", rep(1:5, 4)),
    ssu = paste0("s", rep(1:4, 5)),
    wt  = runif(20, 1, 3),
    y   = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_taylor(
    data      = df,
    variables = .taylor_vars(
      weights = "wt",
      ids     = c("psu", "ssu")
    )
  )
  test_invariants(d)
  expect_identical(d@variables$ids, c("psu", "ssu"))
})

test_that("survey_taylor() allows NA weights (non-NA must be positive)", {
  df <- data.frame(
    wt = c(1.0, NA_real_, 2.0, 0.5),
    y  = 1:4
  )
  d <- survey_taylor(
    data      = df,
    variables = .taylor_vars(weights = "wt")
  )
  test_invariants(d)
  expect_true(is.na(d@data$wt[2]))
})

test_that("survey_taylor() has @groups = character(0) in Phase 0", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_taylor(
    data      = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_identical(d@groups, character(0))
})

test_that("survey_taylor() inherits from survey_base", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_taylor(
    data      = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_true(S7::S7_inherits(d, survey_base))
})

test_that("survey_taylor() stores empty survey_metadata by default", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_taylor(
    data      = df,
    variables = .taylor_vars(weights = "wt")
  )
  expect_true(S7::S7_inherits(d@metadata, survey_metadata))
  expect_identical(d@metadata@variable_labels, list())
})


# ── survey_taylor — validator error paths (errors 31–35) ──────────────────────

test_that("survey_taylor validator: error 31 — design var not in data", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt", ids = "nonexistent")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_taylor validator: error 31 — weight col not in data", {
  df <- data.frame(y = 1:5)
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "missing_wt")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_taylor validator: error 34 — ids is a list-column", {
  df      <- data.frame(wt = rep(1, 3), y = 1:3, stringsAsFactors = FALSE)
  df$lc   <- list(1, 2, 3)   # list-column
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt", ids = "lc")
    ),
    class = "surveycore_error_design_var_list"
  )
})

test_that("survey_taylor validator: error 32 — non-numeric weight column", {
  df <- data.frame(
    wt = c("a", "b", "c"),
    y  = 1:3,
    stringsAsFactors = FALSE
  )
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

test_that("survey_taylor validator: error 33 — weight of zero", {
  df <- data.frame(wt = c(1, 0, 1), y = 1:3)
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_taylor validator: error 33 — negative weight", {
  df <- data.frame(wt = c(1, -0.5, 1), y = 1:3)
  expect_error(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_taylor validator: warning 35 — PSU crossing strata", {
  # psu_1 appears in both strata s1 and s2
  df <- data.frame(
    wt     = rep(1, 4),
    psu    = c("psu_1", "psu_1", "psu_2", "psu_2"),
    strata = c("s1", "s2", "s1", "s2"),
    y      = 1:4,
    stringsAsFactors = FALSE
  )
  expect_warning(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(weights = "wt", ids = "psu", strata = "strata")
    ),
    class = "surveycore_warning_psu_multi_strata"
  )
})

test_that("survey_taylor validator: no PSU warning when nest = TRUE", {
  df <- data.frame(
    wt     = rep(1, 4),
    psu    = c("psu_1", "psu_1", "psu_2", "psu_2"),
    strata = c("s1", "s2", "s1", "s2"),
    y      = 1:4,
    stringsAsFactors = FALSE
  )
  # Should NOT warn when nest = TRUE
  expect_no_warning(
    survey_taylor(
      data      = df,
      variables = .taylor_vars(
        weights = "wt",
        ids     = "psu",
        strata  = "strata",
        nest    = TRUE
      )
    )
  )
})


# ── survey_replicate — happy paths ─────────────────────────────────────────────

test_that("survey_replicate() creates valid BRR design", {
  set.seed(1)
  df <- .df_rep(R = 4L)
  d  <- survey_replicate(
    data      = df,
    variables = .rep_vars(
      weights    = "wt",
      repweights = paste0("rw", 1:4),
      type       = "BRR"
    )
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_replicate))
  expect_identical(d@variables$weights,    "wt")
  expect_identical(d@variables$repweights, paste0("rw", 1:4))
  expect_identical(d@variables$type,       "BRR")
})

test_that("survey_replicate() creates valid JK1 design", {
  set.seed(2)
  df <- .df_rep(R = 10L)
  d  <- survey_replicate(
    data      = df,
    variables = .rep_vars(
      weights    = "wt",
      repweights = paste0("rw", 1:10),
      type       = "JK1"
    )
  )
  test_invariants(d)
  expect_identical(d@variables$type, "JK1")
})

test_that("survey_replicate() inherits from survey_base", {
  df <- .df_rep(R = 2L)
  d  <- survey_replicate(
    data      = df,
    variables = .rep_vars(
      weights    = "wt",
      repweights = c("rw1", "rw2"),
      type       = "bootstrap"
    )
  )
  expect_true(S7::S7_inherits(d, survey_base))
})


# ── survey_replicate — validator error paths ───────────────────────────────────

test_that("survey_replicate validator: missing weight column", {
  df <- data.frame(rw1 = 1:3, rw2 = 1:3, y = 1:3)
  expect_error(
    survey_replicate(
      data      = df,
      variables = .rep_vars(
        weights    = "wt",
        repweights = c("rw1", "rw2")
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_replicate validator: missing repweight column", {
  df <- data.frame(wt = rep(1, 3), rw1 = 1:3, y = 1:3)
  expect_error(
    survey_replicate(
      data      = df,
      variables = .rep_vars(
        weights    = "wt",
        repweights = c("rw1", "rw_missing")
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_replicate validator: non-positive weight", {
  df <- data.frame(wt = c(1, 0, 1), rw1 = c(1, 1, 1), y = 1:3)
  expect_error(
    survey_replicate(
      data      = df,
      variables = .rep_vars(
        weights    = "wt",
        repweights = "rw1"
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

test_that("survey_replicate validator: non-numeric repweight column", {
  df <- data.frame(
    wt  = rep(1, 3),
    rw1 = c("a", "b", "c"),
    y   = 1:3,
    stringsAsFactors = FALSE
  )
  expect_error(
    survey_replicate(
      data      = df,
      variables = .rep_vars(
        weights    = "wt",
        repweights = "rw1"
      )
    ),
    class = "surveycore_error_repweights_not_numeric"
  )
})


# ── survey_twophase — happy paths ──────────────────────────────────────────────

test_that("survey_twophase() creates valid object with minimal spec", {
  df <- data.frame(
    wt         = runif(20, 0.5, 2),
    psu        = paste0("p", rep(1:5, 4)),
    ph2        = c(rep(TRUE, 10), rep(FALSE, 10)),
    y          = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_twophase(
    data      = df,
    variables = list(
      phase1       = .taylor_vars(weights = "wt", ids = "psu"),
      phase2       = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset       = "ph2",
      method       = "full",
      visible_vars = NULL
    )
  )
  test_invariants(d)
  expect_true(S7::S7_inherits(d, survey_twophase))
  expect_identical(d@variables$subset, "ph2")
  expect_identical(d@variables$method, "full")
})

test_that("survey_twophase() creates valid object with phase2 strata col", {
  df <- data.frame(
    wt      = runif(20, 0.5, 2),
    ph2     = c(rep(TRUE, 10), rep(FALSE, 10)),
    ph2_str = c(rep(c("A", "B"), 5), rep(NA, 10)),
    y       = rnorm(20),
    stringsAsFactors = FALSE
  )
  d <- survey_twophase(
    data      = df,
    variables = list(
      phase1       = .taylor_vars(weights = "wt"),
      phase2       = list(
        ids    = NULL,
        strata = "ph2_str",
        probs  = NULL,
        fpc    = NULL
      ),
      subset       = "ph2",
      method       = "approx",
      visible_vars = NULL
    )
  )
  test_invariants(d)
  expect_identical(d@variables$phase2$strata, "ph2_str")
})

test_that("survey_twophase() inherits from survey_base", {
  df <- data.frame(
    wt  = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y   = rnorm(10)
  )
  d <- survey_twophase(
    data      = df,
    variables = list(
      phase1 = .taylor_vars(weights = "wt"),
      phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset = "ph2",
      method = "simple"
    )
  )
  expect_true(S7::S7_inherits(d, survey_base))
})


# ── survey_twophase — validator error paths ────────────────────────────────────

test_that("survey_twophase validator: subset column not in data", {
  df <- data.frame(wt = rep(1, 5), y = 1:5)
  expect_error(
    survey_twophase(
      data      = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
        subset = "ph2_missing",
        method = "full"
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_twophase validator: subset column not logical", {
  df <- data.frame(wt = rep(1, 5), ph2 = 1:5, y = 1:5)
  expect_error(
    survey_twophase(
      data      = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_error_subset_not_logical"
  )
})

test_that("survey_twophase validator: phase2 design col not in data", {
  df <- data.frame(
    wt  = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y   = 1:10
  )
  expect_error(
    survey_twophase(
      data      = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(
          ids    = NULL,
          strata = "missing_strata_col",
          probs  = NULL,
          fpc    = NULL
        ),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_error_design_var_missing"
  )
})

test_that("survey_twophase validator: warning 26 — phase2 col all-NA in ph2", {
  df <- data.frame(
    wt      = rep(1, 10),
    ph2     = c(rep(TRUE, 5), rep(FALSE, 5)),
    ph2_str = rep(NA_character_, 10),   # all NA within phase 2 rows
    y       = 1:10,
    stringsAsFactors = FALSE
  )
  expect_warning(
    survey_twophase(
      data      = df,
      variables = list(
        phase1 = .taylor_vars(weights = "wt"),
        phase2 = list(
          ids    = NULL,
          strata = "ph2_str",
          probs  = NULL,
          fpc    = NULL
        ),
        subset = "ph2",
        method = "full"
      )
    ),
    class = "surveycore_warning_phase2_all_na"
  )
})


# ── survey_srs validator ───────────────────────────────────────────────────────

# Helper: minimal valid survey_srs variables list
.srs_vars <- function(
  weights        = "wt",
  fpc            = NULL,
  fpc_type       = NULL,
  probs_provided = FALSE,
  ids            = NULL,
  strata         = NULL,
  nest           = FALSE
) {
  list(
    weights        = weights,
    fpc            = fpc,
    fpc_type       = fpc_type,
    probs_provided = probs_provided,
    ids            = ids,
    strata         = strata,
    nest           = nest,
    visible_vars   = NULL
  )
}

# Row 1 — weight column absent from @data
test_that("survey_srs validator: weight column absent from @data fires error", {
  df <- data.frame(y = 1:5)
  expect_error(
    survey_srs(
      data      = df,
      variables = .srs_vars(weights = "missing_wt")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

# Row 2 — weight column not numeric
test_that("survey_srs validator: non-numeric weight column fires error", {
  df <- data.frame(y = 1:5, wt = letters[1:5])
  expect_error(
    survey_srs(
      data      = df,
      variables = .srs_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_not_numeric"
  )
})

# Row 3 — weight column has non-positive values
test_that("survey_srs validator: non-positive weights fire error", {
  df <- data.frame(y = 1:5, wt = c(1, -1, 1, 1, 1))
  expect_error(
    survey_srs(
      data      = df,
      variables = .srs_vars(weights = "wt")
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

# Row 4 — FPC column absent from @data
test_that("survey_srs validator: FPC column absent from @data fires error", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  expect_error(
    survey_srs(
      data      = df,
      variables = .srs_vars(weights = "wt", fpc = "missing_fpc")
    ),
    class = "surveycore_error_design_var_missing"
  )
})

# Row 5 — all 8 @variables keys present after construction
test_that("survey_srs: all 8 @variables keys present after construction", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_srs(
    data      = df,
    variables = .srs_vars(weights = "wt")
  )
  test_invariants(d)
  keys <- c(
    "weights", "fpc", "fpc_type", "probs_provided",
    "ids", "strata", "nest", "visible_vars"
  )
  expect_true(all(keys %in% names(d@variables)))
})

# Row 6 — @variables$ids is always NULL
test_that("survey_srs: @variables$ids is always NULL", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_srs(
    data      = df,
    variables = .srs_vars(weights = "wt")
  )
  expect_null(d@variables$ids)
})

# Row 7 — @variables$strata is always NULL
test_that("survey_srs: @variables$strata is always NULL", {
  df <- data.frame(y = 1:5, wt = rep(1, 5))
  d  <- survey_srs(
    data      = df,
    variables = .srs_vars(weights = "wt")
  )
  expect_null(d@variables$strata)
})


# ── Cross-class structural tests ───────────────────────────────────────────────

test_that("survey_taylor and survey_replicate are different classes", {
  df_t <- data.frame(wt = rep(1, 5), y = 1:5)
  d_t  <- survey_taylor(
    data      = df_t,
    variables = .taylor_vars(weights = "wt")
  )
  df_r <- .df_rep(R = 2L)
  d_r  <- survey_replicate(
    data      = df_r,
    variables = .rep_vars(
      weights    = "wt",
      repweights = c("rw1", "rw2")
    )
  )
  expect_false(S7::S7_inherits(d_t, survey_replicate))
  expect_false(S7::S7_inherits(d_r, survey_taylor))
})

test_that("all three concrete classes inherit from survey_base", {
  df_t  <- data.frame(wt = rep(1, 5), y = 1:5)
  df_r  <- .df_rep(R = 2L)
  df_tp <- data.frame(
    wt  = rep(1, 10),
    ph2 = c(rep(TRUE, 5), rep(FALSE, 5)),
    y   = 1:10
  )

  d_t  <- survey_taylor(
    data      = df_t,
    variables = .taylor_vars(weights = "wt")
  )
  d_r  <- survey_replicate(
    data      = df_r,
    variables = .rep_vars(weights = "wt", repweights = c("rw1", "rw2"))
  )
  d_tp <- survey_twophase(
    data      = df_tp,
    variables = list(
      phase1 = .taylor_vars(weights = "wt"),
      phase2 = list(ids = NULL, strata = NULL, probs = NULL, fpc = NULL),
      subset = "ph2",
      method = "full"
    )
  )

  expect_true(S7::S7_inherits(d_t,  survey_base))
  expect_true(S7::S7_inherits(d_r,  survey_base))
  expect_true(S7::S7_inherits(d_tp, survey_base))
})
