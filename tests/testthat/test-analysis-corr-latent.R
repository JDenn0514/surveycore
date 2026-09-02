# Tests for get_corr() — PR 3 public-API integration of polychoric / polyserial.
#
# Scope: integration tests through the exported get_corr() covering
#   - method = "pearson" bit-identity regression guard
#   - method = "polychoric" / "polyserial" happy paths on Taylor and replicate
#   - polycor::polychor() / polycor::polyserial() parity (1e-6)
#   - multi-pair long format, redundant / diagonal / wide
#   - grouped estimation
#   - variance column selection (se, ci, moe, deff, NULL)
#   - df / statistic / p_value method-awareness
#   - column label attributes (method-neutral)
#   - edge cases (empty domain, single-level, all-NA, zero-weight rows,
#     integer ordinal, 6x7 ordinal, surveytidy::filter domain)
#   - survey_collection dispatch
#   - meta(result)$method, bivariate_normal_cdf, n_failed_replicates_total
#
# Error / warning classes exercised at the public-API layer:
#   PC-1 .. PC-15 plus pre-existing Pearson classes (regression guard).

skip_on_cran()

# ── helpers ───────────────────────────────────────────────────────────────────

# Build a small unweighted Taylor design with two 4-level ordinal factors;
# correlated via a shifted coding of o1 into o2.
make_latent_taylor <- function(
  n = 200L,
  seed = 42L,
  n_psu = 20L,
  n_strata = 4L
) {
  set.seed(seed)
  df <- make_survey_data(
    n = n,
    n_psu = n_psu,
    n_strata = n_strata,
    seed = seed
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  df$o3 <- factor(sample(1:3, nrow(df), replace = TRUE), ordered = TRUE)
  df$cont <- as.numeric(df$o1) + stats::rnorm(nrow(df), sd = 0.7)
  as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
}

# Unweighted-equivalent Taylor design (weights all 1, no strata): lets
# us sanity-check polychoric against polycor::polychor() at 1e-6.
#
# Uses the latent-Gaussian cut pattern from PR 1's
# tests/testthat/test-analysis-corr-latent-primitives.R (`make_ordinal_pair`):
# draw (x*, y*) bivariate-normal with correlation `rho`, then cut each by
# marginal quantiles into k_x / k_y ordered levels. This matches the
# fixture construction that PR 1 achieves 1e-6 parity against
# polycor::polychor() on — so the public-API wrapper should too.
make_unit_weight_design <- function(
  n = 200L,
  seed = 1L,
  n_levels_x = 4L,
  n_levels_y = 5L,
  rho = -0.3
) {
  set.seed(seed)
  x_latent <- stats::rnorm(n)
  y_latent <- rho * x_latent + sqrt(1 - rho^2) * stats::rnorm(n)
  tx <- stats::qnorm(seq_len(n_levels_x - 1L) / n_levels_x)
  ty <- stats::qnorm(seq_len(n_levels_y - 1L) / n_levels_y)
  x_ord <- as.integer(cut(x_latent, c(-Inf, tx, Inf), include.lowest = TRUE))
  y_ord <- as.integer(cut(y_latent, c(-Inf, ty, Inf), include.lowest = TRUE))
  df <- data.frame(
    id = seq_len(n),
    wt = 1,
    o1 = factor(x_ord, levels = seq_len(n_levels_x), ordered = TRUE),
    o2 = factor(y_ord, levels = seq_len(n_levels_y), ordered = TRUE),
    cont = x_latent + stats::rnorm(n, sd = 0.7),
    grp = factor(sample(c("A", "B"), n, replace = TRUE))
  )
  list(df = df, design = as_survey(df, weights = wt))
}

# Hand-computed two-step polyserial MLE (Cox 1974; Mannan 2025 §5.1) —
# the strict oracle surveycore's .corr_polyserial_mle() targets at 1e-6.
# .hand_polyserial_twostep() — the strict polyserial oracle — lives in
# helper-test-data.R (shared with test-analysis-corr-latent-primitives.R).

# Hand-computed oracle polyserial fixture matching PR 1's
# make_polyserial_pair (rho = 0.5, n = 500, k_ord = 3, seed = 21).
make_polyserial_fixture <- function(rho, n, k_ord, seed) {
  set.seed(seed)
  ord_latent <- stats::rnorm(n)
  cont <- rho * ord_latent + sqrt(1 - rho^2) * stats::rnorm(n)
  tx <- stats::qnorm(seq_len(k_ord - 1L) / k_ord)
  ord <- as.integer(cut(ord_latent, c(-Inf, tx, Inf), include.lowest = TRUE))
  df <- data.frame(
    id = seq_len(n),
    wt = 1,
    o1 = factor(ord, levels = seq_len(k_ord), ordered = TRUE),
    cont = cont
  )
  list(
    df = df,
    design = as_survey(df, weights = wt),
    ord_int = ord,
    cont = cont
  )
}

make_latent_replicate <- function(
  type = "jk1",
  n = 200L,
  seed = 7L,
  n_psu = 20L,
  n_strata = 4L
) {
  set.seed(seed)
  df <- make_survey_data(
    n = n,
    n_psu = n_psu,
    n_strata = n_strata,
    design = "replicate",
    type = type,
    seed = seed
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  df$cont <- as.numeric(df$o1) + stats::rnorm(nrow(df), sd = 0.7)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = toupper(type)
  )
}


# =============================================================================
# Category 1 — Regression guard: method = "pearson" dispatch invariance
# (Task 1, 2). The spec's original "bit-identical numeric snapshot" framing
# is structurally impossible on a cross-BLAS CI matrix (macOS / Ubuntu /
# Windows produce 1-ULP divergence on otherwise-deterministic computations).
# We instead prove dispatch invariance — `method` omitted equals
# `method = "pearson"` to 1e-10 — and rely on pre-existing
# `test-analysis-corr.R` oracle tests for absolute Pearson correctness.
# =============================================================================

test_that("get_corr() explicit method = 'pearson' equals omitted method", {
  df <- make_survey_data(
    n = 200L,
    n_psu = 20L,
    n_strata = 4L,
    design = "taylor",
    seed = 1L
  )
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r_default <- get_corr(d, x = c(y1, y2))
  r_explicit <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_equal(r_default$r, r_explicit$r, tolerance = 1e-10)
  expect_equal(r_default$ci_low, r_explicit$ci_low, tolerance = 1e-10)
  expect_equal(r_default$ci_high, r_explicit$ci_high, tolerance = 1e-10)
})

test_that("get_corr() method = 'nonsense' raises match.arg error", {
  df <- make_survey_data(n = 100L, seed = 2L)
  d <- as_survey(df, weights = wt)
  expect_error(get_corr(d, x = c(y1, y2), method = "spearman"))
})


# =============================================================================
# Category 2 — Polychoric happy path + oracle parity (Tasks 6-11)
# =============================================================================

test_that("get_corr() method = 'polychoric' matches polycor on 4x5 equal wt", {
  skip_if_not_installed("polycor")
  # Spec §Tolerances pins polycor::polychor() parity at 1e-6 on 3x3, 4x5,
  # and 2x2 equal-weight fixtures. PR 1's primitives test achieves 1e-6
  # at the .corr_polychoric_mle() layer with exactly the fixture below
  # (rho = -0.3, n = 800, k_x = 4, k_y = 5, seed = 2). The public-API
  # wrapper adds no new numerics, so the same tolerance holds here.
  fixt <- make_unit_weight_design(
    n = 800L,
    seed = 2L,
    n_levels_x = 4L,
    n_levels_y = 5L,
    rho = -0.3
  )
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-6)
  expect_identical(meta(r)$method, "polychoric")
})

test_that("get_corr() polychoric matches polycor on 3x3 equal weight", {
  skip_if_not_installed("polycor")
  # Matches PR 1's 3x3 primitive fixture (rho = 0.5, n = 500, seed = 1)
  # to reuse the 1e-6 strict-parity budget established there.
  fixt <- make_unit_weight_design(
    n = 500L,
    seed = 1L,
    n_levels_x = 3L,
    n_levels_y = 3L,
    rho = 0.5
  )
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-6)
})

test_that("get_corr() polychoric matches polycor on 2x2 equal weight", {
  skip_if_not_installed("polycor")
  # Matches PR 1's 2x2 primitive fixture (rho = 0.6, n = 1000, seed = 3)
  # at 1e-6 strict parity.
  fixt <- make_unit_weight_design(
    n = 1000L,
    seed = 3L,
    n_levels_x = 2L,
    n_levels_y = 2L,
    rho = 0.6
  )
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric")
  oracle <- polycor::polychor(fixt$df$o1, fixt$df$o2)
  expect_equal(r$r[[1L]], oracle, tolerance = 1e-6)
})

test_that("get_corr() method = 'polychoric' works on stratified survey_taylor", {
  d <- make_latent_taylor(n = 200L, seed = 11L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_true(abs(r$r[[1L]]) <= 1)
  expect_true(r$ci_low[[1L]] >= -1)
  expect_true(r$ci_high[[1L]] <= 1)
  expect_lte(r$ci_low[[1L]], r$r[[1L]])
  expect_gte(r$ci_high[[1L]], r$r[[1L]])
})

test_that("get_corr() method = 'polychoric' on JK1 replicate matches taylor", {
  # Use the same underlying data for both designs so the MLE rho is equal.
  set.seed(20L)
  df <- make_survey_data(
    n = 160L,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "jk1",
    seed = 20L
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  d_rep <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  d_tay <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  r_rep <- get_corr(d_rep, x = c(o1, o2), method = "polychoric")
  r_tay <- get_corr(d_tay, x = c(o1, o2), method = "polychoric")
  expect_equal(r_rep$r[[1L]], r_tay$r[[1L]], tolerance = 1e-6)
})

test_that("get_corr() method = 'polychoric' on BRR replicate produces se > 0", {
  d <- make_latent_replicate(type = "brr", n = 160L, seed = 22L)
  r <- get_corr(
    d,
    x = c(o1, o2),
    method = "polychoric",
    variance = c("se", "ci")
  )
  expect_true(is.finite(r$r[[1L]]))
  expect_true(r$se[[1L]] > 0)
})


# =============================================================================
# Category 3 — Polyserial happy path + oracle parity (Tasks 12-13)
# =============================================================================

test_that("get_corr() method = 'polyserial' matches hand two-step on 3-level fixture", {
  # decisions.md B1 established .hand_polyserial_twostep() as the strict
  # oracle for surveycore's Cox (1974) two-step polyserial MLE, pinned at
  # 1e-6. PR 1 achieves 1e-6 at the primitive layer; the public API
  # wraps the same .corr_polyserial_mle() call and so inherits the
  # tolerance. polycor::polyserial(ML = TRUE) is a joint MLE and is
  # mathematically inappropriate as an oracle regardless of tolerance.
  fixt <- make_polyserial_fixture(rho = 0.5, n = 500L, k_ord = 3L, seed = 21L)
  r <- get_corr(fixt$design, x = c(o1, cont), method = "polyserial")
  hand <- .hand_polyserial_twostep(fixt$ord_int, fixt$cont)
  expect_equal(r$r[[1L]], hand, tolerance = 1e-6)
  expect_identical(meta(r)$method, "polyserial")
})

test_that("get_corr() method = 'polyserial' matches hand two-step on 5-level fixture", {
  fixt <- make_polyserial_fixture(
    rho = -0.4,
    n = 600L,
    k_ord = 5L,
    seed = 22L
  )
  r <- get_corr(fixt$design, x = c(o1, cont), method = "polyserial")
  hand <- .hand_polyserial_twostep(fixt$ord_int, fixt$cont)
  expect_equal(r$r[[1L]], hand, tolerance = 1e-6)
})

test_that("get_corr() method = 'polyserial' matches hand two-step on 2-level fixture", {
  fixt <- make_polyserial_fixture(
    rho = 0.3,
    n = 800L,
    k_ord = 2L,
    seed = 23L
  )
  r <- get_corr(fixt$design, x = c(o1, cont), method = "polyserial")
  hand <- .hand_polyserial_twostep(fixt$ord_int, fixt$cont)
  expect_equal(r$r[[1L]], hand, tolerance = 1e-6)
})

test_that("get_corr() method = 'polyserial' works on JK1 replicate", {
  d <- make_latent_replicate(type = "jk1", n = 160L, seed = 32L)
  r <- get_corr(d, x = c(o1, cont), method = "polyserial")
  expect_true(abs(r$r[[1L]]) <= 1)
  expect_true(r$ci_low[[1L]] >= -1)
  expect_true(r$ci_high[[1L]] <= 1)
})


# =============================================================================
# Category 4 — Multi-pair long format, redundant, diagonal, wide (Tasks 15-18)
# =============================================================================

test_that("multi-pair polychoric returns 3 rows for 3 ordinal columns", {
  d <- make_latent_taylor(n = 200L, seed = 40L)
  r <- get_corr(d, x = c(o1, o2, o3), method = "polychoric")
  expect_identical(nrow(r), 3L)
  expect_identical(
    paste0(as.character(r$var1), "-", as.character(r$var2)),
    c("o1-o2", "o1-o3", "o2-o3")
  )
  # Each pair's r should be in [-1, 1].
  expect_true(all(r$r >= -1 & r$r <= 1))
})

test_that("polychoric + redundant = TRUE yields symmetric pairs", {
  d <- make_latent_taylor(n = 200L, seed = 41L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", redundant = TRUE)
  expect_identical(nrow(r), 2L)
  expect_equal(r$r[[1L]], r$r[[2L]], tolerance = 1e-10)
  expect_identical(as.character(r$var1[[1L]]), as.character(r$var2[[2L]]))
  expect_identical(as.character(r$var1[[2L]]), as.character(r$var2[[1L]]))
})

test_that("polychoric + diagonal = TRUE includes self-rows with r = 1", {
  d <- make_latent_taylor(n = 200L, seed = 42L)
  r <- get_corr(
    d,
    x = c(o1, o2),
    method = "polychoric",
    diagonal = TRUE,
    variance = c("se", "ci")
  )
  expect_identical(nrow(r), 3L)
  self_rows <- r[as.character(r$var1) == as.character(r$var2), ]
  # Strip column-level `label` attributes before comparing values.
  expect_equal(unname(self_rows$r), c(1, 1), ignore_attr = TRUE)
  expect_equal(unname(self_rows$se), c(0, 0), ignore_attr = TRUE)
})

test_that("polychoric + format = 'wide' returns square matrix with NA diag", {
  d <- make_latent_taylor(n = 200L, seed = 43L)
  r <- get_corr(d, x = c(o1, o2, o3), method = "polychoric", format = "wide")
  expect_identical(nrow(r), 3L)
  expect_true(all(c("o1", "o2", "o3") %in% names(r)))
  expect_false("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  # Diagonal is NA.
  diag_idx <- match(as.character(r$variable), c("o1", "o2", "o3"))
  for (i in seq_len(nrow(r))) {
    expect_true(is.na(r[[i + 1L]][[i]]))
  }
})


# =============================================================================
# Category 5 — Grouping (Task 19)
# =============================================================================

test_that("polychoric + group = 2-level factor produces 2 rows", {
  fixt <- make_unit_weight_design(n = 200L, seed = 50L)
  r <- get_corr(fixt$design, x = c(o1, o2), method = "polychoric", group = grp)
  expect_identical(nrow(r), 2L)
  expect_true("grp" %in% names(r))
  expect_setequal(as.character(r$grp), c("A", "B"))
})


# =============================================================================
# Category 6 — Variance column selection (Task 20)
# =============================================================================

test_that("variance = 'se' emits only se; no ci_low/ci_high", {
  d <- make_latent_taylor(n = 200L, seed = 60L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "se")
  expect_true("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  expect_false("moe" %in% names(r))
})

test_that("variance = 'ci' emits ci_low / ci_high", {
  d <- make_latent_taylor(n = 200L, seed = 61L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "ci")
  expect_true("ci_low" %in% names(r))
  expect_true("ci_high" %in% names(r))
  expect_false("se" %in% names(r))
})

test_that("variance = c('se', 'ci', 'moe') emits all three; moe = (hi-lo)/2", {
  d <- make_latent_taylor(n = 200L, seed = 62L)
  r <- get_corr(
    d,
    x = c(o1, o2),
    method = "polychoric",
    variance = c("se", "ci", "moe")
  )
  expect_true(all(c("se", "ci_low", "ci_high", "moe") %in% names(r)))
  expected_moe <- (r$ci_high - r$ci_low) / 2
  expect_equal(r$moe, expected_moe, tolerance = 1e-10, ignore_attr = TRUE)
})

test_that("variance = 'deff' emits deff only", {
  d <- make_latent_taylor(n = 200L, seed = 63L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = "deff")
  expect_true("deff" %in% names(r))
  expect_false("se" %in% names(r))
  expect_true(is.finite(r$deff[[1L]]) || is.na(r$deff[[1L]]))
})

test_that("variance = NULL emits no variance-derived columns", {
  d <- make_latent_taylor(n = 200L, seed = 64L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric", variance = NULL)
  expect_false("se" %in% names(r))
  expect_false("ci_low" %in% names(r))
  expect_false("moe" %in% names(r))
  expect_false("deff" %in% names(r))
})


# =============================================================================
# Category 7 — df / statistic / p_value method awareness (Task 21, 22)
# =============================================================================

test_that("non-Pearson emits df = NA_integer_ and z-scale statistic", {
  d <- make_latent_taylor(n = 200L, seed = 70L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(r$df[[1L]], NA_integer_)
  expect_true(is.finite(r$statistic[[1L]]))
  # p_value consistent with two-sided standard normal reference.
  z_ref <- 2 * stats::pnorm(-abs(r$statistic[[1L]]))
  expect_equal(r$p_value[[1L]], z_ref, tolerance = 1e-10)
})

test_that("Pearson retains df = n - 2 and t-scale statistic", {
  d <- make_latent_taylor(n = 200L, seed = 71L)
  r <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_identical(r$df[[1L]], r$n[[1L]] - 2L)
  expect_true(is.finite(r$statistic[[1L]]))
})

test_that("column label attributes are method-neutral strings", {
  d <- make_latent_taylor(n = 200L, seed = 72L)
  r_poly <- get_corr(d, x = c(o1, o2), method = "polychoric")
  r_pear <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_identical(attr(r_poly$statistic, "label"), "statistic")
  expect_identical(attr(r_pear$statistic, "label"), "statistic")
  expect_identical(attr(r_poly$df, "label"), "df")
  expect_identical(attr(r_poly$p_value, "label"), "p-value")
})


# =============================================================================
# Category 8 — Edge cases (Tasks 24-31)
# =============================================================================

test_that("empty active domain yields r = NA and n = 0 without aborting", {
  skip_if_not_installed("surveytidy")
  d <- make_latent_taylor(n = 120L, seed = 80L)
  # Construct a domain that is empty by filtering on a condition with no
  # rows. surveytidy::filter() emits an informational warning that the
  # domain is empty; we suppress it here for test-output hygiene.
  d2 <- suppressWarnings(
    surveytidy::filter(d, as.integer(o1) > 999L)
  )
  # After PR 2 the .corr_latent_pair() dispatcher short-circuits to
  # r = NA_real_, n = 0 when the pair has 0 active-complete rows.
  r <- suppressWarnings(
    get_corr(d2, x = c(o1, o2), method = "polychoric")
  )
  expect_identical(r$n[[1L]], 0L)
  expect_identical(unname(r$r[[1L]]), NA_real_)
})

test_that("single-level ordinal emits PC-4", {
  set.seed(81L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(rep(1L, 100L), levels = 1:3, ordered = TRUE),
    o2 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_single_level_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, o2), method = "polychoric")
  )
})

test_that("all-NA focal column routes to empty-pair handling", {
  set.seed(82L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE),
    o2 = factor(rep(NA_integer_, 100L), levels = 1:3, ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(r$n[[1L]], 0L)
  expect_identical(r$r[[1L]], NA_real_)
})

test_that("tiny-weight rows match physical-removal equivalent at 1e-3", {
  skip_if_not_installed("polycor")
  set.seed(83L)
  n <- 300L
  o1 <- sample(1:4, n, replace = TRUE)
  o2 <- o1 + sample(-1:1, n, replace = TRUE)
  o2[o2 < 1L] <- 1L
  o2[o2 > 4L] <- 4L
  keep <- sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.8, 0.2))
  # surveycore rejects non-positive weights in as_survey(); use a tiny
  # positive weight (1e-10) to preserve the row count while effectively
  # zeroing the row's contribution to the weighted likelihood.
  df_zw <- data.frame(
    id = 1:n,
    wt = ifelse(keep, 1, 1e-10),
    o1 = factor(o1, levels = 1:4, ordered = TRUE),
    o2 = factor(o2, levels = 1:4, ordered = TRUE)
  )
  d_zw <- as_survey(df_zw, weights = wt)
  r_zw <- get_corr(d_zw, x = c(o1, o2), method = "polychoric")
  # Compare against polychor on the physically subset data.
  df_sub <- df_zw[keep, , drop = FALSE]
  oracle <- polycor::polychor(df_sub$o1, df_sub$o2)
  expect_equal(r_zw$r[[1L]], oracle, tolerance = 1e-3)
})

test_that("integer vector with 3 distinct values is accepted for polychoric", {
  set.seed(84L)
  df <- data.frame(
    id = 1:150,
    wt = 1,
    x1 = sample(1:3, 150L, replace = TRUE),
    x2 = sample(1:3, 150L, replace = TRUE)
  )
  df$x1 <- as.integer(df$x1)
  df$x2 <- as.integer(df$x2)
  d <- as_survey(df, weights = wt)
  expect_no_warning(
    r <- get_corr(d, x = c(x1, x2), method = "polychoric")
  )
  expect_true(abs(r$r[[1L]]) <= 1)
})

test_that("integer with 15 distinct values + polyserial raises PC-3", {
  set.seed(85L)
  df <- data.frame(
    id = 1:200,
    wt = 1,
    x1 = as.integer(sample(1:20, 200L, replace = TRUE)),
    cont = rnorm(200L)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(x1, cont), method = "polyserial"),
    class = "surveycore_error_polyserial_canonicalization_ambiguous"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(x1, cont), method = "polyserial")
  )
})

test_that("character column + method = 'polychoric' raises PC-1", {
  set.seed(86L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE),
    s1 = sample(c("a", "b", "c"), 100L, replace = TRUE),
    stringsAsFactors = FALSE
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, s1), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, s1), method = "polychoric")
  )
})

test_that("6x7 ordinal pair runs without error", {
  set.seed(87L)
  n <- 300L
  df <- data.frame(
    id = 1:n,
    wt = 1,
    o1 = factor(sample(1:6, n, replace = TRUE), levels = 1:6, ordered = TRUE),
    o2 = factor(sample(1:7, n, replace = TRUE), levels = 1:7, ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_no_error({
    r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  })
  expect_true(is.finite(r$r[[1L]]))
})

test_that("surveytidy::filter domain matches raw-subset equivalent within 1e-4", {
  skip_if_not_installed("surveytidy")
  skip_if_not_installed("polycor")
  fixt <- make_unit_weight_design(n = 300L, seed = 88L)
  d_full <- fixt$design
  df <- fixt$df
  d_filt <- surveytidy::filter(d_full, grp == "A")
  r_filt <- get_corr(d_filt, x = c(o1, o2), method = "polychoric")
  df_sub <- df[df$grp == "A", , drop = FALSE]
  oracle <- polycor::polychor(df_sub$o1, df_sub$o2)
  # Agreement with polycor on equal-weight data is bounded by the
  # shared optimizer tolerance (~1e-4). Domain correctness is the gate;
  # optimizer precision is not.
  expect_equal(r_filt$r[[1L]], oracle, tolerance = 1e-4)
})


# =============================================================================
# Category 9 — Survey collection dispatch (Tasks 33-35)
# =============================================================================

test_that("survey_collection of all taylor members dispatches polychoric per-survey", {
  d1 <- make_latent_taylor(n = 120L, seed = 100L)
  d2 <- make_latent_taylor(n = 120L, seed = 101L)
  coll <- as_survey_collection(wave1 = d1, wave2 = d2)
  r <- get_corr(coll, x = c(o1, o2), method = "polychoric")
  expect_true(".survey" %in% names(r))
  expect_setequal(as.character(r$.survey), c("wave1", "wave2"))
})

.make_twophase_design <- function(seed) {
  df_tp <- make_survey_data(
    n = 120L,
    n_psu = 12L,
    n_strata = 3L,
    design = "twophase",
    seed = seed
  )
  df_tp$o1 <- factor(
    sample(1:4, nrow(df_tp), replace = TRUE),
    ordered = TRUE
  )
  df_tp$o2 <- factor(
    sample(1:4, nrow(df_tp), replace = TRUE),
    ordered = TRUE
  )
  ph1 <- as_survey(
    df_tp,
    ids = psu,
    weights = wt,
    strata = strata,
    nest = TRUE
  )
  as_survey_twophase(ph1, subset = subset, method = "approx")
}

test_that("survey_collection with twophase member + polychoric raises PC-7 (dual)", {
  d_taylor <- make_latent_taylor(n = 120L, seed = 110L)
  d_tp <- .make_twophase_design(110L)
  coll <- as_survey_collection(w1 = d_taylor, w2 = d_tp)
  expect_error(
    get_corr(coll, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_design_unsupported"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(coll, x = c(o1, o2), method = "polychoric")
  )
})

test_that("survey_collection with twophase + .if_missing_var = 'skip' still raises PC-7", {
  # Note: the collection's `.if_missing_var` hook catches
  # surveycore_error_variable_not_found only. PC-7 is a distinct class and
  # propagates through the dispatcher to the caller regardless of
  # `.if_missing_var`. (This matches the `.dispatch_over_collection()`
  # contract in R/survey-collection.R; altering it is out of scope for
  # PR 3.)
  d_taylor <- make_latent_taylor(n = 120L, seed = 120L)
  d_tp <- .make_twophase_design(120L)
  coll <- as_survey_collection(w1 = d_taylor, w2 = d_tp)
  expect_error(
    get_corr(
      coll,
      x = c(o1, o2),
      method = "polychoric",
      .if_missing_var = "skip"
    ),
    class = "surveycore_error_polychoric_design_unsupported"
  )
})


# =============================================================================
# Category 10 — Pearson regression: warning + error classes still fire (Task 36)
# =============================================================================

test_that("method = 'pearson' still warns on non-numeric columns (regression guard)", {
  set.seed(130L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    y1 = rnorm(100L),
    y2 = rnorm(100L),
    grp = sample(c("A", "B"), 100L, replace = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_warning(
    get_corr(d, x = c(y1, y2, grp), method = "pearson"),
    class = "surveycore_warning_corr_non_numeric"
  )
})

test_that("surveycore_error_insufficient_variables fires for < 2 columns under latent", {
  set.seed(131L)
  df <- data.frame(
    id = 1:100,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = o1, method = "polychoric"),
    class = "surveycore_error_insufficient_variables"
  )
})

test_that("surveycore_error_invalid_variance_arg still fires under latent methods", {
  d <- make_latent_taylor(n = 120L, seed = 132L)
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polychoric", variance = "bogus"),
    class = "surveycore_error_invalid_variance_arg"
  )
})


# =============================================================================
# Category 11 — meta() population (Tasks 37-38)
# =============================================================================

test_that("meta()$bivariate_normal_cdf is 'pbivnorm' for polychoric", {
  d <- make_latent_taylor(n = 120L, seed = 140L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_identical(meta(r)$bivariate_normal_cdf, "pbivnorm")
})

test_that("meta()$bivariate_normal_cdf is 'pbivnorm' for polyserial", {
  d <- make_latent_taylor(n = 120L, seed = 141L)
  r <- get_corr(d, x = c(o1, cont), method = "polyserial")
  expect_identical(meta(r)$bivariate_normal_cdf, "pbivnorm")
})

test_that("meta()$bivariate_normal_cdf is absent for pearson", {
  d <- make_latent_taylor(n = 120L, seed = 142L)
  r <- get_corr(d, x = c(y1, y2), method = "pearson")
  expect_null(meta(r)$bivariate_normal_cdf)
})

test_that("meta()$n_failed_replicates_total absent when n_failed == 0", {
  d <- make_latent_replicate(type = "jk1", n = 160L, seed = 143L)
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
  expect_null(meta(r)$n_failed_replicates_total)
})


# =============================================================================
# Category 12 — Public-API dual-pattern tests for PC warnings (PC-9, PC-13)
# =============================================================================

test_that("PC-13 (unordered factor) surfaces via the public API (dual)", {
  set.seed(150L)
  df <- data.frame(
    id = 1:200,
    wt = 1,
    o1 = factor(
      sample(c("a", "b", "c"), 200L, replace = TRUE),
      ordered = FALSE
    ),
    o2 = factor(sample(1:3, 200L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_warning(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_warning_polychoric_unordered_factor"
  )
  # Snapshot the PC-13 condition text. Result is numeric and auto-prints,
  # so wrap in invisible() for Windows-BLAS stability.
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_unordered_factor = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})


# =============================================================================
# Category 14 — Public-API dual-pattern tests for remaining PC classes
# =============================================================================
# PC-1, PC-3, PC-4 already covered in Category 8. PC-13 above. This category
# covers PC-2, PC-5, PC-6, PC-7 (collection path above covers one flavour),
# PC-8, PC-9, PC-10, PC-11, PC-12, PC-14. Fixtures reuse PR 2's variance-layer
# constructions where possible; PC-6 and PC-11 are structurally unreachable
# at the public API with realistic data (PC-11 is marked # nocov in
# R/analysis-corr-latent.R; PC-6 arises only when the numerical-IF
# perturbation makes the MLE degenerate, which PR 2 exercises by directly
# invoking .corr_numerical_influence on a bogus rho_hat_full). Those two use
# `testthat::local_mocked_bindings()` to force the class to fire under
# `get_corr()` so the public-API surface is exercised end-to-end.

test_that("PC-2 (polyserial with two ordered factors) at public API (dual)", {
  set.seed(200L)
  df <- data.frame(
    id = 1:100L,
    wt = 1,
    o1 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE),
    o2 = factor(sample(1:3, 100L, replace = TRUE), ordered = TRUE)
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, o2), method = "polyserial")
  )
})

test_that("PC-5 (polychoric insufficient cells) at public API (dual)", {
  # 3 nonempty cells of a 2x2 table — below the MLE-identification floor.
  df <- data.frame(
    id = 1:25L,
    wt = 1,
    o1 = factor(
      c(rep(1L, 10), rep(2L, 10), rep(1L, 5)),
      levels = 1:2,
      ordered = TRUE
    ),
    o2 = factor(
      c(rep(1L, 10), rep(2L, 10), rep(2L, 5)),
      levels = 1:2,
      ordered = TRUE
    )
  )
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_insufficient_cells"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, o2), method = "polychoric")
  )
})

test_that("PC-6 (polychoric optim_failed) at public API (dual, mocked)", {
  # PC-6 fires when a perturbation inside .corr_numerical_influence() makes
  # the pair-level MLE degenerate. Not reachable at public API with realistic
  # data (see PR 2 decisions.md note). Mock .corr_polychoric_mle to raise
  # PC-6 directly on its first call; get_corr() should surface the class.
  d <- make_latent_taylor(n = 80L, seed = 201L)
  testthat::local_mocked_bindings(
    .corr_polychoric_mle = function(...) {
      cli::cli_abort(
        c(
          "x" = "Numerical optimization did not converge for pair (o1, o2).",
          "i" = "Optimizer message: simulated failure.",
          "v" = "Inspect the pair for extreme weight skew or sparse cells."
        ),
        class = "surveycore_error_polychoric_optim_failed"
      )
    }
  )
  expect_error(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_optim_failed"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(o1, o2), method = "polychoric")
  )
})

test_that("PC-7 (twophase, single design) at public API (dual)", {
  # Single-design PC-7 path (the collection path is covered above).
  d_tp <- .make_twophase_design(202L)
  expect_error(
    get_corr(d_tp, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_error_polychoric_design_unsupported"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d_tp, x = c(o1, o2), method = "polychoric")
  )
})

test_that("PC-8 (> 20% replicate failure) at public API (dual)", {
  # Zero out every replicate except the last, producing ~R-1 failures.
  # Pattern mirrors PR 2's test-analysis-corr-latent-variance.R PC-8 fixture.
  set.seed(203L)
  df <- make_survey_data(
    n = 60L,
    n_psu = 30L,
    n_strata = 5L,
    design = "replicate",
    type = "jk1",
    seed = 203L
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  keep_rows <- which(
    as.integer(df$o1) == 1L & as.integer(df$o2) == 1L
  )
  if (length(keep_rows) < 2L) {
    skip("fixture does not produce the required degenerate replicates")
  }
  for (cn in rep_cols[-length(rep_cols)]) {
    df[[cn]] <- 0
    df[[cn]][keep_rows] <- df$wt[keep_rows]
  }
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  expect_error(
    suppressWarnings(get_corr(d, x = c(o1, o2), method = "polychoric")),
    class = "surveycore_error_replicate_convergence_failure"
  )
  expect_snapshot(
    error = TRUE,
    suppressWarnings(get_corr(d, x = c(o1, o2), method = "polychoric"))
  )
})

test_that("PC-9 (near-boundary rho, replicate path) at public API (dual)", {
  # 2x2 fixture saturating at the optimizer upper bound, on a replicate
  # design so PC-14 (Taylor-only) doesn't also fire. Pattern mirrors PR 2's
  # test-analysis-corr-latent-variance.R PC-9 fixture.
  set.seed(1L)
  o1_int <- c(rep(1L, 249L), rep(2L, 249L), 1L, 2L)
  o2_int <- c(rep(1L, 249L), rep(2L, 249L), 2L, 1L)
  n <- length(o1_int)
  df <- make_survey_data(
    n = n,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "jk1",
    seed = 1L
  )
  df$o1 <- factor(o1_int, levels = 1:3, ordered = TRUE)
  df$o2 <- factor(o2_int, levels = 1:3, ordered = TRUE)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  # Primary dual assertion: PC-9 fires. PC-10 also fires because the
  # boundary fixture's (1,3) and (3,1) cells are empty in the active
  # domain; muffle it so expect_warning() resolves on PC-9.
  expect_warning(
    withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_zero_count_level = function(w) {
        invokeRestart("muffleWarning")
      }
    ),
    class = "surveycore_warning_polychoric_boundary_rho"
  )
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_boundary_rho = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})

test_that("PC-10 (zero-count interior level) at public API (dual)", {
  # 4 levels with level 3 holding zero observations in the domain. Pattern
  # mirrors PR 2's test-analysis-corr-latent-variance.R PC-10 fixture.
  set.seed(204L)
  n <- 100L
  codes <- sample(c(1L, 2L, 4L), n, replace = TRUE)
  df <- make_survey_data(n = n, n_psu = 20L, n_strata = 4L, seed = 204L)
  df$o1 <- factor(codes, levels = 1:4, ordered = TRUE)
  df$o2 <- factor(sample(1:3, n, replace = TRUE), ordered = TRUE)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_warning(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_warning_polychoric_zero_count_level"
  )
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_zero_count_level = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})

test_that("PC-11 (polychoric sparse cell) at public API (dual, mocked)", {
  # PC-11 is unreachable at the public API with realistic data (marked
  # `# nocov` in R/analysis-corr-latent.R). Mock .corr_polychoric_mle to
  # return a fit object with n_sparse_cells > 0 and let .corr_latent_pair()
  # raise PC-11 through its normal code path.
  d <- make_latent_taylor(n = 80L, seed = 205L)
  # Compute the real fit first so the variance path has a valid rho, then
  # wrap to inject n_sparse_cells.
  real_mle <- surveycore:::.corr_polychoric_mle
  testthat::local_mocked_bindings(
    .corr_polychoric_mle = function(...) {
      out <- real_mle(...)
      out$n_sparse_cells <- 1L
      out
    }
  )
  expect_warning(
    withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_zero_count_level = function(w) {
        invokeRestart("muffleWarning")
      }
    ),
    class = "surveycore_warning_polychoric_sparse_cell"
  )
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_sparse_cell = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})

test_that("PC-12 at public API populates meta()$n_failed_replicates_total", {
  # Partial replicate failure (1 of R replicates fails). Pattern mirrors
  # PR 2's test-analysis-corr-latent-variance.R PC-12 fixture. Assertions:
  #   * PC-12 warning class fires.
  #   * meta(result)$n_failed_replicates_total equals the planned failure
  #     count (1L) — exercises the populated-scalar branch of the accumulator
  #     that Invariant 6 requires and spec test-spec.md PC-12 mandates.
  #   * meta(result)$bivariate_normal_cdf == "pbivnorm".
  # This test also satisfies Fix D coverage on R/analysis-corr.R.
  set.seed(13L)
  df <- make_survey_data(
    n = 60L,
    n_psu = 30L,
    n_strata = 5L,
    design = "replicate",
    type = "jk1",
    seed = 13L
  )
  df$o1 <- factor(sample(1:4, nrow(df), replace = TRUE), ordered = TRUE)
  shift <- as.integer(df$o1) + sample(-1:1, nrow(df), replace = TRUE)
  shift[shift < 1L] <- 1L
  shift[shift > 4L] <- 4L
  df$o2 <- factor(shift, levels = 1:4, ordered = TRUE)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  keep_rows <- which(
    as.integer(df$o1) == 1L & as.integer(df$o2) == 1L
  )
  if (length(keep_rows) < 2L) {
    skip("fixture does not produce the required degenerate replicate")
  }
  # Break exactly 1 replicate column — produces k = 1 planned failure.
  df[[rep_cols[[1L]]]] <- 0
  df[[rep_cols[[1L]]]][keep_rows] <- df$wt[keep_rows]
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  expect_warning(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    class = "surveycore_warning_polychoric_replicate_convergence"
  )
  # Populated-scalar path: meta$n_failed_replicates_total = 1L.
  r <- suppressWarnings(
    get_corr(d, x = c(o1, o2), method = "polychoric")
  )
  expect_identical(meta(r)$n_failed_replicates_total, 1L)
  expect_identical(meta(r)$bivariate_normal_cdf, "pbivnorm")
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_replicate_convergence = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})

test_that("PC-14 (Taylor near-boundary wide CI) at public API (dual)", {
  # Same 2x2 boundary fixture as PC-9, but on a Taylor design so PC-14
  # fires in addition to PC-9. Pattern mirrors PR 2's PC-14 fixture.
  set.seed(2L)
  o1_int <- c(rep(1L, 249L), rep(2L, 249L), 1L, 2L)
  o2_int <- c(rep(1L, 249L), rep(2L, 249L), 2L, 1L)
  n <- length(o1_int)
  df <- make_survey_data(n = n, n_psu = 20L, n_strata = 4L, seed = 2L)
  df$o1 <- factor(o1_int, levels = 1:3, ordered = TRUE)
  df$o2 <- factor(o2_int, levels = 1:3, ordered = TRUE)
  d <- as_survey(df, ids = psu, weights = wt, strata = strata, nest = TRUE)
  expect_warning(
    withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_boundary_rho = function(w) {
        invokeRestart("muffleWarning")
      },
      surveycore_warning_polychoric_zero_count_level = function(w) {
        invokeRestart("muffleWarning")
      }
    ),
    class = "surveycore_warning_polychoric_taylor_boundary_wide_ci"
  )
  expect_snapshot({
    invisible(withCallingHandlers(
      get_corr(d, x = c(o1, o2), method = "polychoric"),
      surveycore_warning_polychoric_taylor_boundary_wide_ci = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      warning = function(w) invokeRestart("muffleWarning")
    ))
  })
})


# =============================================================================
# Category 13 — name_style = "broom" threads statistic / df / p.value labels
# =============================================================================

test_that("name_style = 'broom' produces broom columns with neutral labels", {
  d <- make_latent_taylor(n = 200L, seed = 160L)
  r <- get_corr(
    d,
    x = c(o1, o2),
    method = "polychoric",
    variance = c("se", "ci"),
    name_style = "broom"
  )
  expect_true("estimate" %in% names(r))
  expect_true("std.error" %in% names(r))
  expect_true("conf.low" %in% names(r))
  expect_true("conf.high" %in% names(r))
  expect_identical(attr(r$statistic, "label"), "statistic")
})


# ── B3: PC-9 boundary warning threshold ──────────────────────────────────────

test_that("PC-9 boundary warning message contains '1e-4' not '1e-6'", {
  # Same near-boundary fixture as the PC-9 dual test above, but on a replicate
  # design to avoid PC-14 also firing.
  set.seed(1L)
  o1_int <- c(rep(1L, 249L), rep(2L, 249L), 1L, 2L)
  o2_int <- c(rep(1L, 249L), rep(2L, 249L), 2L, 1L)
  n <- length(o1_int)
  df <- make_survey_data(
    n = n,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "jk1",
    seed = 1L
  )
  df$o1 <- factor(o1_int, levels = 1:3, ordered = TRUE)
  df$o2 <- factor(o2_int, levels = 1:3, ordered = TRUE)
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  # Capture the PC-9 warning text and verify threshold value
  captured_msg <- NULL
  withCallingHandlers(
    get_corr(d, x = c(o1, o2), method = "polychoric"),
    surveycore_warning_polychoric_boundary_rho = function(cond) {
      captured_msg <<- conditionMessage(cond)
      invokeRestart("muffleWarning")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_true(grepl("1e-4", captured_msg, fixed = TRUE))
  expect_false(grepl("1e-6", captured_msg, fixed = TRUE))
})


# =============================================================================
# Category 14 — whole-valued doubles classify as ordinal (issue #175)
# =============================================================================
#
# A double whose non-missing values are all finite and whole, with at most 10
# distinct values, is an ordinal scale. SPSS, Stata and SAS files store every
# coded scale as a double, so the earlier "is.double means continuous" rule
# refused the exact input polychoric correlation exists to serve.
#
# Row identifiers:
#   P-1  .. P-18f — classification, asserted through get_corr()
#   P-19 .. P-23  — numerical agreement with the ordered-factor form
#   Y-1  .. Y-14  — polyserial, including two breaking changes
#   E-1           — the class named in the PC-1 message after the strip
#
# `is.finite()` is the load-bearing half of the rule. Without it a column
# containing `Inf` classifies as a scale, `Inf` becomes an ordinary top
# category, and the call returns a fabricated correlation instead of raising.
# P-18a, P-18b and P-18f are the gate on that guard.

# ── helpers ───────────────────────────────────────────────────────────────────

# Cut `z` into `k` ascending integer codes at its marginal normal quantiles.
.wd_cut <- function(z, k) {
  tk <- stats::qnorm(seq_len(k - 1L) / k)
  as.integer(cut(z, c(-Inf, tk, Inf), include.lowest = TRUE))
}

# Draw a bivariate-normal pair and cut each margin into ascending integer
# codes, so every pair below carries real correlation and both optimizers
# converge. `y_latent` is the genuine continuous column the polyserial rows
# use; `y` is the ordinal partner.
.wd_codes <- function(n = 400L, seed = 11L, rho = 0.5, k_x = 4L, k_y = 4L) {
  set.seed(seed)
  x_latent <- stats::rnorm(n)
  y_latent <- rho * x_latent + sqrt(1 - rho^2) * stats::rnorm(n)
  list(
    x = .wd_cut(x_latent, k_x),
    y = .wd_cut(y_latent, k_y),
    y_latent = y_latent,
    n = n
  )
}

# Unit-weight Taylor design carrying the column under test as `v`, plus the
# four partners the rows pair it with: `ref` (4-level ordered factor), `cont`
# (genuine continuous), `iv` (small integer), `hi_iv` (integer with more than
# 10 distinct values) and `cv` (character).
#
# `map` receives the ascending integer codes and returns the column exactly as
# the row wants it stored, so one helper serves every shape.
.wd_design <- function(map, seed = 11L, n = 400L, k_x = 4L, k_y = 4L) {
  cd <- .wd_codes(n = n, seed = seed, k_x = k_x, k_y = k_y)
  df <- data.frame(id = seq_len(n), wt = 1)
  df$v <- map(cd$x)
  df$ref <- factor(cd$y, levels = seq_len(k_y), ordered = TRUE)
  df$ref2 <- factor(.wd_cut(cd$y_latent, 3L), levels = 1:3, ordered = TRUE)
  df$cont <- cd$y_latent
  df$iv <- cd$y
  df$hi_iv <- as.integer(rank(cd$y_latent, ties.method = "first")) %% 20L + 1L
  df$cv <- letters[cd$y]
  list(df = df, design = as_survey(df, weights = wt), codes = cd)
}

# The identity map: ascending codes stored as a plain double. This is the
# shape the whole category is about.
.wd_dbl <- function(codes) as.numeric(codes)

# Replicate design carrying the same pair, for the two variance rows.
.wd_replicate <- function(seed = 21L, k_x = 4L, k_y = 4L, labelled = FALSE) {
  df <- make_survey_data(
    n = 400L,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "jk1",
    seed = seed
  )
  cd <- .wd_codes(n = nrow(df), seed = seed, k_x = k_x, k_y = k_y)
  df$v1 <- as.numeric(cd$x)
  df$v2 <- as.numeric(cd$y)
  df$cont <- cd$y_latent
  if (isTRUE(labelled)) {
    df$v1 <- make_labelled(
      df$v1,
      stats::setNames(as.numeric(seq_len(k_x)), LETTERS[seq_len(k_x)]),
      "Scale one"
    )
  }
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
}


# ── P-1 .. P-18f: classification through get_corr(polychoric) ────────────────

test_that("P-1: a double with 3 distinct whole values is ordinal", {
  d <- .wd_design(.wd_dbl, k_x = 3L)$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-2: a double with 7 distinct whole values is ordinal", {
  d <- .wd_design(.wd_dbl, k_x = 7L, n = 600L)$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-3: a double with exactly 10 distinct whole values is ordinal", {
  fx <- .wd_design(.wd_dbl, k_x = 10L, n = 800L)
  # The inclusive boundary: the cutoff is 10, so 10 distinct values pass.
  expect_length(unique(fx$df$v), 10L)
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-4: a double with exactly 11 distinct whole values raises PC-1", {
  fx <- .wd_design(.wd_dbl, k_x = 11L, n = 800L)
  # One value past the boundary.
  expect_length(unique(fx$df$v), 11L)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-5: a double with 12 distinct whole values raises PC-1", {
  fx <- .wd_design(.wd_dbl, k_x = 12L, n = 800L)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-6: a double with a fractional value raises PC-1", {
  fx <- .wd_design(function(codes) as.numeric(codes) + 0.5)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-7: an all-NA double raises PC-1", {
  fx <- .wd_design(function(codes) rep(NA_real_, length(codes)))
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-7b: an all-NA integer raises PC-1", {
  fx <- .wd_design(function(codes) rep(NA_integer_, length(codes)))
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-7c: an all-NA integer and an all-NA double raise the same error", {
  # Issue #209: the integer side returned r = NA, n = 0 while the double
  # side raised PC-1. Both now raise, and the two conditions carry the
  # same class vector.
  int_fx <- .wd_design(function(codes) rep(NA_integer_, length(codes)))
  dbl_fx <- .wd_design(function(codes) rep(NA_real_, length(codes)))
  int_cnd <- tryCatch(
    get_corr(int_fx$design, x = c(v, ref), method = "polychoric"),
    error = identity
  )
  dbl_cnd <- tryCatch(
    get_corr(dbl_fx$design, x = c(v, ref), method = "polychoric"),
    error = identity
  )
  expect_identical(class(int_cnd), class(dbl_cnd))
})

test_that("P-7d: an all-NA ordered column still returns r = NA and n = 0", {
  # The empty-column rule covers bare numerics only. A factor declares its
  # levels, so it stays ordinal and routes to empty-pair handling.
  fx <- .wd_design(function(codes) {
    factor(rep(NA_integer_, length(codes)), levels = 1:4, ordered = TRUE)
  })
  r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  expect_identical(r$n[[1L]], 0L)
  expect_identical(unname(r$r[[1L]]), NA_real_)
})

test_that("P-8: a character column still raises PC-1", {
  fx <- .wd_design(function(codes) letters[codes])
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-9: a logical column still raises PC-1", {
  fx <- .wd_design(function(codes) codes > 2L)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-10: an integer with 3 distinct values is still ordinal", {
  d <- .wd_design(function(codes) as.integer(codes), k_x = 3L)$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-11: an integer with 11 distinct values still raises PC-1", {
  fx <- .wd_design(function(codes) as.integer(codes), k_x = 11L, n = 800L)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-12: an ordered factor is still ordinal", {
  d <- .wd_design(function(codes) {
    factor(codes, levels = sort(unique(codes)), ordered = TRUE)
  })$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-13: an unordered factor is ordinal and warns PC-13", {
  d <- .wd_design(function(codes) {
    factor(codes, levels = sort(unique(codes)))
  })$design
  expect_warning(
    r <- get_corr(d, x = c(v, ref), method = "polychoric"),
    class = "surveycore_warning_polychoric_unordered_factor"
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-14: a labelled double with 4 labelled whole codes is ordinal", {
  # The reported defect. Every code carries a label, and the column is a
  # double because that is what haven::read_sav() produces.
  d <- .wd_design(function(codes) {
    make_labelled(
      as.numeric(codes),
      c(A = 1, B = 2, C = 3, D = 4),
      "Agreement"
    )
  })$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-15: a labelled integer with 4 distinct codes is ordinal", {
  # The control that located the gap: this shape passed before the change
  # too, so the gap was about storage type and not about the label class.
  d <- .wd_design(function(codes) {
    make_labelled(
      as.integer(codes),
      c(A = 1L, B = 2L, C = 3L, D = 4L),
      "Agreement"
    )
  })$design
  expect_no_error(r <- get_corr(d, x = c(v, ref), method = "polychoric"))
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-16: a double of 1000/2000/3000 is treated as a 3-point scale", {
  # A documented false positive, pinned so a later reader sees it was chosen
  # and not overlooked. Three distinct whole values inside the cutoff, so the
  # column classifies as ordinal even though it could be income in whole
  # dollars. Accepted because method = "polychoric" is opt-in.
  fx <- .wd_design(function(codes) as.numeric(codes) * 1000, k_x = 3L)
  expect_identical(sort(unique(fx$df$v)), c(1000, 2000, 3000))
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-17: a double of 0/1 is ordinal — the tetrachoric case", {
  fx <- .wd_design(function(codes) as.numeric(codes) - 1, k_x = 2L)
  expect_identical(sort(unique(fx$df$v)), c(0, 1))
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-18: a single-valued double raises PC-4, not PC-1", {
  # The gate accepts the column as ordinal; the level-count guard downstream
  # rejects it and names the column and the remedy. A typed error naming the
  # column beats the untyped refusal this change removed.
  fx <- .wd_design(function(codes) rep(2, length(codes)))
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_single_level_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-18a: a double carrying Inf raises PC-1", {
  # Gate 12. Without the is.finite() guard the column classifies as a scale,
  # Inf becomes an ordinary top category, and the call returns a fabricated
  # correlation of about -0.056 instead of raising.
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- Inf
    v
  })
  expect_true(any(is.infinite(fx$df$v)))
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-18b: a double carrying -Inf raises PC-1", {
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- -Inf
    v
  })
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})

test_that("P-18c: a double carrying NA is still ordinal", {
  # NA is missing, not infinite. A guard that rejected it would break every
  # real scale column, because real survey data carries missing values.
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- NA_real_
    v
  })
  expect_true(anyNA(fx$df$v))
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-18d: a double carrying NaN is still ordinal", {
  # NaN is missing too: is.na(NaN) is TRUE, so the missing filter removes it
  # before the finiteness test ever sees it.
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- NaN
    v
  })
  expect_true(any(is.nan(fx$df$v)))
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-18e: 10 whole values plus NA and NaN is still ordinal", {
  # The distinct count is taken over the non-missing values only, so the
  # column sits on the inclusive boundary and not one past it.
  fx <- .wd_design(
    function(codes) {
      v <- as.numeric(codes)
      v[[1L]] <- NA_real_
      v[[2L]] <- NaN
      v
    },
    k_x = 10L,
    n = 800L
  )
  expect_length(unique(fx$df$v[!is.na(fx$df$v)]), 10L)
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("P-18f: a labelled double carrying Inf raises PC-1", {
  # The label class makes no difference: the finiteness guard reads values.
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- Inf
    make_labelled(v, c(A = 1, B = 2, C = 3, D = 4), "Agreement")
  })
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})


# ── P-19 .. P-23: numerical agreement ────────────────────────────────────────

test_that("P-19: two whole-valued doubles match the ordered-factor pair", {
  cd <- .wd_codes(n = 400L, seed = 31L)
  base_df <- data.frame(id = seq_len(400L), wt = 1)
  base_df$v1 <- as.numeric(cd$x)
  base_df$v2 <- as.numeric(cd$y)

  dbl <- as_survey(base_df, weights = wt)
  fac_df <- base_df
  fac_df$v1 <- factor(
    base_df$v1,
    levels = sort(unique(base_df$v1)),
    ordered = TRUE
  )
  fac_df$v2 <- factor(
    base_df$v2,
    levels = sort(unique(base_df$v2)),
    ordered = TRUE
  )
  fac <- as_survey(fac_df, weights = wt)

  r_dbl <- get_corr(dbl, x = c(v1, v2), method = "polychoric")
  r_fac <- get_corr(fac, x = c(v1, v2), method = "polychoric")
  expect_equal(r_dbl$r, r_fac$r, tolerance = 1e-10)
})

test_that("P-20: a labelled side matches the same pair with no class", {
  make_pair <- function(labelled) {
    cd <- .wd_codes(n = 400L, seed = 33L)
    df <- data.frame(id = seq_len(400L), wt = 1)
    df$v1 <- as.numeric(cd$x)
    df$v2 <- as.numeric(cd$y)
    if (isTRUE(labelled)) {
      df$v1 <- make_labelled(
        df$v1,
        c(A = 1, B = 2, C = 3, D = 4),
        "Scale one"
      )
    }
    as_survey(df, weights = wt)
  }
  lbl <- get_corr(
    make_pair(TRUE),
    x = c(v1, v2),
    method = "polychoric",
    variance = c("se", "ci")
  )
  pln <- get_corr(
    make_pair(FALSE),
    x = c(v1, v2),
    method = "polychoric",
    variance = c("se", "ci")
  )
  # One input re-classed, same computation, so the comparison is exact by
  # construction: stripping a class cannot perturb a floating-point result.
  # Measured on this fixture, bit-identical on all four fields, maximum
  # absolute difference exactly 0. A numerical bound here would let a
  # tenth-decimal drift in the labelled path ship green, so there is none.
  expect_identical(lbl$r, pln$r)
  expect_identical(lbl$se, pln$se)
  expect_identical(lbl$ci_low, pln$ci_low)
  expect_identical(lbl$ci_high, pln$ci_high)
})

test_that("P-21: the labelled/plain match also holds on a replicate design", {
  lbl <- get_corr(
    .wd_replicate(labelled = TRUE),
    x = c(v1, v2),
    method = "polychoric",
    variance = c("se", "ci")
  )
  pln <- get_corr(
    .wd_replicate(labelled = FALSE),
    x = c(v1, v2),
    method = "polychoric",
    variance = c("se", "ci")
  )
  # Exact by construction, for the reason written out in P-20. Measured,
  # bit-identical on all four fields, maximum absolute difference exactly 0.
  # The replicate variance path adds R refits and does not change that: both
  # designs feed it the same numbers.
  expect_identical(lbl$r, pln$r)
  expect_identical(lbl$se, pln$se)
  expect_identical(lbl$ci_low, pln$ci_low)
  expect_identical(lbl$ci_high, pln$ci_high)
})

test_that("P-22: reversing one side's codes negates the correlation", {
  cd <- .wd_codes(n = 400L, seed = 35L)
  df <- data.frame(id = seq_len(400L), wt = 1)
  df$v1 <- as.numeric(cd$x)
  df$v2 <- as.numeric(cd$y)
  df$v2r <- max(df$v2) + min(df$v2) - df$v2

  d <- as_survey(df, weights = wt)
  r_plain <- get_corr(d, x = c(v1, v2), method = "polychoric")
  r_rev <- get_corr(d, x = c(v1, v2r), method = "polychoric")
  expect_equal(r_rev$r, -r_plain$r, tolerance = 1e-10)
})

test_that("P-23: a whole-valued double plus a continuous column raises PC-1", {
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(v, cont), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  # The message names the continuous column and not the accepted scale.
  err <- expect_error(
    get_corr(fx$design, x = c(v, cont), method = "polychoric")
  )
  msg <- conditionMessage(err)
  # Singular "column", naming cont alone. Before the change both sides read
  # as continuous and the message named v as well, in the plural.
  expect_true(grepl("cont", msg, fixed = TRUE))
  expect_false(grepl("columns", msg, fixed = TRUE))
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, cont), method = "polychoric")
  )
})


# ── Y-1 .. Y-14: polyserial ──────────────────────────────────────────────────

test_that("Y-1: a whole-valued double plus a continuous column now works", {
  # Newly working: both sides classified continuous before the change, so
  # this pair raised the mixed-types error.
  fx <- .wd_design(.wd_dbl)
  expect_no_error(
    r <- get_corr(fx$design, x = c(v, cont), method = "polyserial")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("Y-2: two whole-valued doubles raise the mixed-types error", {
  # The outcome is unchanged; the classification the message reports differs,
  # because both sides now read as integer_ordinal rather than continuous.
  cd <- .wd_codes(n = 400L, seed = 37L)
  df <- data.frame(id = seq_len(400L), wt = 1)
  df$v1 <- as.numeric(cd$x)
  df$v2 <- as.numeric(cd$y)
  d <- as_survey(df, weights = wt)
  expect_error(
    get_corr(d, x = c(v1, v2), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
})

test_that("Y-3: BREAKING — double plus ordered factor now raises PC-2", {
  # A caller who paired a whole-valued double with an ordered factor got a
  # polyserial number before this change. Both sides are ordinal now, so the
  # pair raises surveycore_error_polyserial_requires_mixed_types instead.
  # method = "polychoric" is the correct method for a pair of ordinal
  # columns, and the message says so.
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polyserial")
  )
})

test_that("Y-4: BREAKING — double plus small integer now raises PC-2", {
  # The same breaking change in its second shape: a small-cardinality integer
  # was already ordinal, so pairing it with a whole-valued double moves from
  # ordinal + continuous to two ordinal sides.
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(v, iv), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, iv), method = "polyserial")
  )
})

test_that("Y-5: an ordered factor plus a continuous column still works", {
  fx <- .wd_design(.wd_dbl)
  expect_no_error(
    r <- get_corr(fx$design, x = c(ref, cont), method = "polyserial")
  )
  expect_true(is.finite(r$r[[1L]]))
})

test_that("Y-6: two ordered factors still raise the mixed-types error", {
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(ref, ref2), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
})

test_that("Y-7: a high-cardinality integer plus ordered factor stays PC-3", {
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(hi_iv, ref), method = "polyserial"),
    class = "surveycore_error_polyserial_canonicalization_ambiguous"
  )
})

test_that("Y-8: a character column plus ordered factor stays PC-3", {
  fx <- .wd_design(.wd_dbl)
  expect_error(
    get_corr(fx$design, x = c(cv, ref), method = "polyserial"),
    class = "surveycore_error_polyserial_canonicalization_ambiguous"
  )
})

test_that("Y-9: a labelled ordinal side matches the same pair with no class", {
  make_d <- function(labelled) {
    .wd_design(function(codes) {
      v <- as.numeric(codes)
      if (isTRUE(labelled)) {
        v <- make_labelled(v, c(A = 1, B = 2, C = 3, D = 4), "Agreement")
      }
      v
    })$design
  }
  lbl <- get_corr(make_d(TRUE), x = c(v, cont), method = "polyserial")
  pln <- get_corr(make_d(FALSE), x = c(v, cont), method = "polyserial")
  # Exact by construction, for the reason written out in P-20. Measured,
  # bit-identical, maximum absolute difference exactly 0.
  expect_identical(lbl$r, pln$r)
})

test_that("Y-10: a double carrying Inf plus ordered factor is unchanged", {
  # The finiteness guard keeps the Inf column continuous, so the pair stays
  # ordinal + continuous and reaches the same code as before the change.
  # Without the guard the Inf column would become ordinal and this pair would
  # start raising the mixed-types error, which is what this row rules out.
  #
  # Measured on develop at 0ef5442: this pair does not return a number. The
  # continuous side is standardized by its weighted mean and SD, and Inf
  # makes the SD NaN, so an untyped base error escapes. That is a
  # pre-existing defect in a shape nobody should send, and this change
  # neither causes nor fixes it. The row asserts only that the pair does not
  # move across the ordinal/continuous boundary.
  fx <- .wd_design(function(codes) {
    v <- as.numeric(codes)
    v[[1L]] <- Inf
    v
  })
  err <- expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polyserial")
  )
  expect_false(
    inherits(err, "surveycore_error_polyserial_requires_mixed_types")
  )
  expect_false(
    inherits(err, "surveycore_error_polyserial_canonicalization_ambiguous")
  )
})

test_that("Y-11: the double ordinal side matches an ordered-factor side", {
  fx <- .wd_design(.wd_dbl, seed = 41L)
  fac_df <- fx$df
  fac_df$v <- factor(fx$df$v, levels = sort(unique(fx$df$v)), ordered = TRUE)
  fac <- as_survey(fac_df, weights = wt)

  r_dbl <- get_corr(fx$design, x = c(v, cont), method = "polyserial")
  r_fac <- get_corr(fac, x = c(v, cont), method = "polyserial")
  expect_equal(r_dbl$r, r_fac$r, tolerance = 1e-10)
})

test_that("Y-12: the double ordinal side matches an outside implementation", {
  # Equal weights on both sides, so the weighted estimator and an unweighted
  # reference are comparable.
  #
  # Two oracles, at the two tolerances this package already uses for
  # polyserial. `.hand_polyserial_twostep()` is the strict one at 1e-6: it is
  # the Cox (1974) / Mannan 2025 §5.1 two-step MLE that
  # `.corr_polyserial_mle()` implements. `polycor::polyserial(ML = TRUE)` is a
  # joint MLE over thresholds and rho together, so it targets a different
  # estimator; decisions.md B1 settled that it is not a strict oracle, and
  # test-analysis-corr-latent-primitives.R compares against it at 1e-3.
  # Measured on this fixture: 0.5104687363 against 0.5124571733, a relative
  # difference of 3.9e-3. The bound below is 5e-3, which is a sanity check on
  # the sign and the magnitude and nothing more.
  fx <- .wd_design(.wd_dbl, seed = 41L)
  r_dbl <- get_corr(fx$design, x = c(v, cont), method = "polyserial")
  hand <- .hand_polyserial_twostep(as.integer(fx$df$v), fx$df$cont)
  expect_equal(r_dbl$r[[1L]], hand, tolerance = 1e-6)

  skip_if_not_installed("polycor")
  ref_r <- polycor::polyserial(fx$df$cont, fx$df$v, ML = TRUE)
  expect_equal(r_dbl$r[[1L]], ref_r, tolerance = 5e-3)
})

test_that("Y-13: the double ordinal side matches on a replicate design", {
  d_rep <- .wd_replicate(seed = 43L)
  fac_df <- survey_data(d_rep)
  fac_df$v1 <- factor(
    fac_df$v1,
    levels = sort(unique(fac_df$v1)),
    ordered = TRUE
  )
  rep_cols <- grep("^repwt_", names(fac_df), value = TRUE)
  d_fac <- as_survey_replicate(
    fac_df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )

  r_dbl <- get_corr(
    d_rep,
    x = c(v1, cont),
    method = "polyserial",
    variance = "se"
  )
  r_fac <- get_corr(
    d_fac,
    x = c(v1, cont),
    method = "polyserial",
    variance = "se"
  )
  expect_equal(r_dbl$r, r_fac$r, tolerance = 1e-10)
  expect_equal(r_dbl$se, r_fac$se, tolerance = 1e-8)
})

test_that("Y-14: reverse-coding the double ordinal side negates the result", {
  fx <- .wd_design(.wd_dbl, seed = 41L)
  rev_df <- fx$df
  rev_df$v <- max(fx$df$v) + min(fx$df$v) - fx$df$v
  d_rev <- as_survey(rev_df, weights = wt)

  r_plain <- get_corr(fx$design, x = c(v, cont), method = "polyserial")
  r_rev <- get_corr(d_rev, x = c(v, cont), method = "polyserial")
  expect_equal(r_rev$r, -r_plain$r, tolerance = 1e-10)
})


test_that("Y-15: an all-NA integer plus ordered factor gives r = NA and n = 0", {
  # Issue #209 side effect. The all-NA integer read as ordinal before this
  # change, so this pair raised PC-2. It now reads as continuous, the pair
  # canonicalizes, and empty-pair handling returns the NA row. The all-NA
  # double behaves identically, which is the point of the change.
  int_fx <- .wd_design(function(codes) rep(NA_integer_, length(codes)))
  dbl_fx <- .wd_design(function(codes) rep(NA_real_, length(codes)))
  r_int <- get_corr(int_fx$design, x = c(v, ref), method = "polyserial")
  r_dbl <- get_corr(dbl_fx$design, x = c(v, ref), method = "polyserial")
  expect_identical(r_int$n[[1L]], 0L)
  expect_identical(unname(r_int$r[[1L]]), NA_real_)
  expect_identical(r_int$n[[1L]], r_dbl$n[[1L]])
  expect_identical(unname(r_int$r[[1L]]), unname(r_dbl$r[[1L]]))
})

test_that("Y-16: an all-NA integer plus a continuous column raises PC-2", {
  # The other half of the Y-15 shift: two continuous sides.
  int_fx <- .wd_design(function(codes) rep(NA_integer_, length(codes)))
  dbl_fx <- .wd_design(function(codes) rep(NA_real_, length(codes)))
  expect_error(
    get_corr(int_fx$design, x = c(v, cont), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
  expect_error(
    get_corr(dbl_fx$design, x = c(v, cont), method = "polyserial"),
    class = "surveycore_error_polyserial_requires_mixed_types"
  )
})

# ── E-1: the class named in the PC-1 message ─────────────────────────────────

test_that("E-1: PC-1 on a labelled column names a plain numeric class", {
  # The design stores the column with the labelled class removed, so the
  # class interpolated into the message is the underlying numeric type. This
  # row pins the message text, because the class is what changed.
  fx <- .wd_design(
    function(codes) {
      make_labelled(
        as.numeric(codes),
        stats::setNames(as.numeric(1:11), LETTERS[1:11]),
        "Too many points"
      )
    },
    k_x = 11L,
    n = 800L
  )
  expect_false(inherits(survey_data(fx$design)$v, "haven_labelled"))
  err <- expect_error(
    get_corr(fx$design, x = c(v, ref), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
  msg <- conditionMessage(err)
  expect_true(grepl("numeric", msg, fixed = TRUE))
  expect_false(grepl("haven_labelled", msg, fixed = TRUE))
  expect_snapshot(
    error = TRUE,
    get_corr(fx$design, x = c(v, ref), method = "polychoric")
  )
})
# =============================================================================
# Category 16 — PC-15: a non-finite continuous side (issue #208)
# =============================================================================
# Before the PC-15 gate an Inf on the continuous side made the weighted mean,
# variance and SD all NaN, `NaN > 0` evaluated NA, and the `if` in
# .corr_weighted_standardize() raised an untyped base error. The gate reads
# the continuous column on the active-domain rows and refuses first.

# Build a Taylor design with one ordered factor and two double columns: a
# whole-valued `scale` that .corr_detect_ordinal() classifies "continuous"
# only because of the Inf, and a genuine `cont`. `bad` places the infinite
# value at `row`.
.pc15_design <- function(bad = "scale", value = Inf, row = 5L, n = 300L) {
  set.seed(208L)
  df <- data.frame(
    id = seq_len(n),
    wt = stats::runif(n, 0.5, 2),
    ord = ordered(sample(1:3, n, replace = TRUE)),
    scale = as.double(sample(1:4, n, replace = TRUE)),
    cont = stats::rnorm(n)
  )
  df[[bad]][row] <- value
  as_survey(df, ids = id, weights = wt)
}

test_that("PC-15 fires for Inf on a whole-valued continuous side (dual)", {
  d <- .pc15_design(bad = "scale", value = Inf)
  # The Inf is what makes this column continuous rather than ordinal, so the
  # pair really is ordinal + continuous and really does reach the MLE.
  expect_identical(
    .corr_detect_ordinal(survey_data(d)$scale),
    "continuous"
  )
  err <- expect_error(
    get_corr(d, x = c(scale, ord), method = "polyserial"),
    class = "surveycore_error_polyserial_nonfinite_continuous"
  )
  expect_true(grepl("scale", conditionMessage(err), fixed = TRUE))
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(scale, ord), method = "polyserial")
  )
})

test_that("PC-15 fires for -Inf on a genuine continuous side (dual)", {
  d <- .pc15_design(bad = "cont", value = -Inf)
  expect_error(
    get_corr(d, x = c(cont, ord), method = "polyserial"),
    class = "surveycore_error_polyserial_nonfinite_continuous"
  )
  expect_snapshot(
    error = TRUE,
    get_corr(d, x = c(cont, ord), method = "polyserial")
  )
})

test_that("PC-15 names both infinite values when a column holds each", {
  d <- .pc15_design(bad = "cont", value = -Inf)
  df <- survey_data(d)
  df$cont[9L] <- Inf
  d2 <- as_survey(df, ids = id, weights = wt)
  err <- expect_error(
    get_corr(d2, x = c(cont, ord), method = "polyserial"),
    class = "surveycore_error_polyserial_nonfinite_continuous"
  )
  msg <- conditionMessage(err)
  expect_true(grepl("2 non-finite values", msg, fixed = TRUE))
  expect_true(grepl("-Inf", msg, fixed = TRUE))
})

test_that("PC-15 does not fire when the Inf row is outside the domain", {
  # The estimate uses only the active-domain rows, so an Inf the domain
  # excludes is not the gate's business. n drops by the filtered row.
  d <- .pc15_design(bad = "scale", value = Inf, row = 5L)
  d_filt <- suppressWarnings(surveytidy::filter(d, id != 5L))
  res <- get_corr(d_filt, x = c(scale, ord), method = "polyserial")
  expect_identical(res$n, 299L)
  expect_true(is.finite(res$r))
})

test_that("PC-15 still fires for an Inf row the domain keeps", {
  d <- .pc15_design(bad = "scale", value = Inf, row = 5L)
  d_filt <- suppressWarnings(surveytidy::filter(d, id != 6L))
  expect_error(
    get_corr(d_filt, x = c(scale, ord), method = "polyserial"),
    class = "surveycore_error_polyserial_nonfinite_continuous"
  )
})

test_that("PC-15 leaves NaN on the continuous side alone in both na.rm modes", {
  # NaN is not the gate's business: .corr_weighted_standardize() drops it
  # through the !is.na() filter whether or not na.rm removes the row first.
  d <- .pc15_design(bad = "cont", value = NaN)
  res_t <- get_corr(d, x = c(cont, ord), method = "polyserial", na.rm = TRUE)
  res_f <- get_corr(d, x = c(cont, ord), method = "polyserial", na.rm = FALSE)
  expect_true(is.finite(res_t$r))
  expect_true(is.finite(res_f$r))
  expect_identical(res_t$n, 299L)
  expect_identical(res_f$n, 300L)
})

test_that("PC-15 does not touch the polychoric path", {
  # An Inf-carrying double classifies "continuous", so polychoric refuses it
  # at PC-1 — earlier than the PC-15 gate, and with its own class.
  d <- .pc15_design(bad = "scale", value = Inf)
  expect_error(
    get_corr(d, x = c(scale, ord), method = "polychoric"),
    class = "surveycore_error_polychoric_requires_ordinal"
  )
})

test_that("PC-15 does not touch the pearson path", {
  # Pearson keeps its pre-existing behaviour: an NA row for the pair.
  d <- .pc15_design(bad = "scale", value = Inf)
  res <- get_corr(d, x = c(scale, cont), method = "pearson")
  expect_true(is.na(res$r))
})

test_that("PC-15 fires on the replicate path too", {
  # The gate lives in .corr_latent_pair(), before the variance branch, so
  # every design class reaches it.
  set.seed(208L)
  df <- make_survey_data(
    n = 160L,
    n_psu = 20L,
    n_strata = 4L,
    design = "replicate",
    type = "jk1",
    seed = 208L
  )
  df$ord <- ordered(sample(1:3, nrow(df), replace = TRUE))
  df$cont <- stats::rnorm(nrow(df))
  df$cont[4L] <- Inf
  rep_cols <- grep("^repwt_", names(df), value = TRUE)
  d <- as_survey_replicate(
    df,
    weights = wt,
    repweights = tidyselect::all_of(rep_cols),
    type = "JK1"
  )
  expect_error(
    get_corr(d, x = c(cont, ord), method = "polyserial"),
    class = "surveycore_error_polyserial_nonfinite_continuous"
  )
})
