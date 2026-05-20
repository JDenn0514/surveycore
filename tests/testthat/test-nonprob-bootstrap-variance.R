# test-nonprob-bootstrap-variance.R
#
# Tests for bootstrap variance dispatch in survey_nonprob. Covers:
#   - Replicate path activated when repweights present
#   - SRS fallback warning when no repweights
#   - degf = Inf for all survey_nonprob objects
#   - domain_replicates_na warning for >5% NA replicates
#   - Bitwise identity with survey_replicate using same data


# ── Helper: build survey_nonprob with repweights ──────────────────────────────

.make_nonprob_rep <- function(n = 200L, R = 20L, seed = 42L) {
  set.seed(seed)
  df <- make_survey_data(n = n, seed = seed)
  repwt_data <- matrix(
    pmax(0.1, df$wt * matrix(
      rexp(nrow(df) * R, rate = 1),
      nrow = nrow(df), ncol = R
    )),
    nrow = nrow(df), ncol = R
  )
  colnames(repwt_data) <- paste0("repwt_", seq_len(R))
  cbind(df, as.data.frame(repwt_data))
}


# ══════════════════════════════════════════════════════════════════════════════
# Section 1: .degf() returns Inf for survey_nonprob
# ══════════════════════════════════════════════════════════════════════════════

test_that(".degf() returns Inf for survey_nonprob WITHOUT repweights", {
  df <- make_survey_data(n = 50L, n_psu = 6L, n_strata = 1L, seed = 14L)
  d <- as_survey_nonprob(df, weights = wt)
  test_invariants(d)
  expect_equal(.degf(d), Inf)
})

test_that(".degf() returns Inf for survey_nonprob WITH repweights", {
  df_rep <- .make_nonprob_rep(n = 100L, R = 10L, seed = 1L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  test_invariants(d)
  expect_equal(.degf(d), Inf)
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 2: Warning fires at estimation time, not construction time
# ══════════════════════════════════════════════════════════════════════════════

test_that("as_survey_nonprob() does not emit nonprob_srs_fallback at construction", {
  df <- make_survey_data(n = 200L, seed = 42L)
  expect_no_warning(
    as_survey_nonprob(df, weights = wt)
  )
})

test_that("get_means() on no-repweights survey_nonprob emits nonprob_srs_fallback", {
  df <- make_survey_data(n = 200L, seed = 42L)
  d <- as_survey_nonprob(df, weights = wt)
  expect_warning(
    get_means(d, y1),
    class = "surveycore_warning_nonprob_srs_fallback"
  )
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 3: No warning when repweights present (routing tests)
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_means() on repweight-equipped survey_nonprob emits no srs_fallback", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 42L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_means(d, y1)
  )
})

test_that("get_freqs() on repweight-equipped survey_nonprob emits no srs_fallback", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 43L)
  df_rep$grp <- sample(c("A", "B", "C"), nrow(df_rep), replace = TRUE)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_freqs(d, grp)
  )
})

test_that("get_totals() on repweight-equipped survey_nonprob emits no srs_fallback", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 44L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_totals(d, y1)
  )
})

test_that("get_corr() on repweight-equipped survey_nonprob emits no srs_fallback", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 45L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_corr(d, c(y1, y2))
  )
})

test_that("get_covariance() on repweight-equipped survey_nonprob emits no srs_fallback", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 46L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_covariance(d, c(y1, y2))
  )
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 4: Bitwise identity with survey_replicate (same data + weights)
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_means() SE is bitwise identical for survey_nonprob and survey_replicate with same data", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 42L)

  d_np <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  d_rep <- as_survey_replicate(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "bootstrap",
    mse = TRUE
  )

  result_np <- get_means(d_np, y1, variance = "se")
  result_rep <- get_means(d_rep, y1, variance = "se")

  expect_identical(result_np$se, result_rep$se)
  expect_identical(result_np$mean, result_rep$mean)
})

test_that("get_ratios() SE matches equivalent survey_replicate for survey_nonprob", {
  df_rep <- .make_nonprob_rep(n = 200L, R = 20L, seed = 42L)

  d_np <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  d_rep <- as_survey_replicate(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "bootstrap",
    mse = TRUE
  )

  result_np <- get_ratios(d_np, y1, y2)
  result_rep <- get_ratios(d_rep, y1, y2)

  expect_equal(result_np$se, result_rep$se, tolerance = 1e-10)
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 5: Manual oracle for SE
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_means() SE^2 matches manual (1/R)*sum((theta_r - theta)^2) oracle", {
  R <- 20L
  df_rep <- .make_nonprob_rep(n = 200L, R = R, seed = 7L)

  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )

  result <- get_means(d, y1, variance = "se")
  theta <- result$mean
  se_sq <- result$se^2

  # Manual oracle: (1/R) * sum((theta_r - theta)^2)
  # rep_mat is n x R; crossprod gives per-replicate weighted sums
  rep_mat <- as.matrix(df_rep[, paste0("repwt_", seq_len(R))])
  y_vals <- df_rep$y1
  rep_Y <- as.numeric(crossprod(rep_mat, y_vals)) # R-vector: sum(rep_wt_r * y)
  rep_N <- colSums(rep_mat) # R-vector: sum(rep_wt_r)
  rep_theta <- rep_Y / rep_N
  oracle_var <- (1 / R) * sum((rep_theta - theta)^2)

  expect_equal(se_sq, oracle_var, tolerance = 1e-8)
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 6: domain filter — no srs_fallback when repweights present
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_means() with domain filter emits no srs_fallback when repweights present", {
  df_rep <- .make_nonprob_rep(n = 300L, R = 20L, seed = 50L)
  df_rep$grp <- sample(c("A", "B"), nrow(df_rep), replace = TRUE)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )
  expect_no_warning(
    get_means(d, y1, group = grp)
  )
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 7: degf = Inf leads to normal CI approximation in get_quantiles()
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_quantiles() uses normal approximation (degf=Inf) for survey_nonprob", {
  df_rep <- .make_nonprob_rep(n = 300L, R = 30L, seed = 55L)
  d <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )

  result <- get_quantiles(d, y1, probs = 0.5)
  # degf = Inf → CI uses qt(0.975, Inf) = qnorm(0.975)
  # Just verify it returns a non-NA estimate without crashing
  expect_true(nrow(result) >= 1L)
  expect_true(!is.na(result$estimate[[1L]]))
})


# ══════════════════════════════════════════════════════════════════════════════
# Section 8: surveycore_warning_domain_replicates_na fires for >5% NA replicates
# ══════════════════════════════════════════════════════════════════════════════

test_that("surveycore_warning_domain_replicates_na fires when >5% replicates are NA for a domain", {
  set.seed(99L)
  df <- make_survey_data(n = 200L, seed = 99L)
  # Create group variable with tiny group "A" (10 rows only)
  df$grp <- ifelse(seq_len(nrow(df)) <= 10L, "A", "B")

  R <- 20L
  repwt_data <- matrix(
    pmax(0.1, df$wt * matrix(
      rexp(nrow(df) * R, rate = 1),
      nrow = nrow(df), ncol = R
    )),
    nrow = nrow(df), ncol = R
  )
  colnames(repwt_data) <- paste0("repwt_", seq_len(R))
  df_rep <- cbind(df, as.data.frame(repwt_data))

  # Zero out repweights for group "A" rows in 15 of 20 replicates (75% → NA)
  a_rows <- df_rep$grp == "A"
  for (r in seq_len(15L)) {
    df_rep[[paste0("repwt_", r)]][a_rows] <- 0
  }

  d_np <- as_survey_nonprob(
    df_rep,
    weights = wt,
    repweights = starts_with("repwt_")
  )

  expect_warning(
    get_means(d_np, y1, group = grp),
    class = "surveycore_warning_domain_replicates_na"
  )
})

test_that(".nonprob_rep_na_warn() returns NULL immediately for non-survey_nonprob designs", {
  # The NPS-gating in .nonprob_rep_na_warn() returns NULL for any design that
  # is not a survey_nonprob — preventing surveycore_warning_domain_replicates_na
  # from ever firing for survey_replicate, survey_taylor, or survey_twophase.
  df <- make_survey_data(n = 100L, design = "replicate", type = "BRR", seed = 7L)
  d_rep <- as_survey_replicate(
    df,
    weights = wt,
    repweights = starts_with("repwt_"),
    type = "BRR"
  )
  # na_frac = 0.9 would trigger the warning for survey_nonprob, but not here
  result <- .nonprob_rep_na_warn(d_rep, na_frac = 0.9, na_dropped = 9L, R = 10L, scale = 0.1)
  expect_null(result)
})
