# ---------------------------------------------------------------------------
# R/variance-vendored-saddlepoint.R
# ---------------------------------------------------------------------------
# Saddlepoint CDF helpers for weighted chi-square and F sums.
#
# ATTRIBUTION — VENDORED CODE:
# Adapted from the survey package by Thomas Lumley
# (https://cran.r-project.org/package=survey), licensed under GPL-2 | GPL-3.
# Source: survey/R/pchisqsum.R at version 4.4-8.
#
# - .saddle() is a byte-for-byte port of survey:::saddle().
# - .pchisqsum_sad() is a port of the saddlepoint branch of
#   survey::pchisqsum().
# - .pFsum_sad() is DERIVED from survey::pFsum() — surveycore's signature
#   adds a `mean.deff` scalar argument that pre-applies the Rao-Scott
#   rescaling at the call site (spec §V.5, Pass 3 Issue 65). Under the
#   default mean.deff = mean(a) the helper is equivalent to upstream when
#   the caller passes `x` pre-divided by mean(a).
#
# Modifications: helpers are dotted/internal (not exported); no dependency
# on CompQuadForm; no Satterthwaite-only / integration branches (those are
# intentionally out of scope for the vendored slice).
# ---------------------------------------------------------------------------

# Saddlepoint root-finder (direct port of survey:::saddle).
#
# @keywords internal
# @noRd
.saddle <- function(x, lambda) {
  d <- max(lambda)
  lambda <- lambda / d
  x <- x / d
  k0 <- function(zeta) -sum(log(1 - 2 * zeta * lambda)) / 2
  kprime0 <- function(zeta) {
    sapply(zeta, function(zz) sum(lambda / (1 - 2 * zz * lambda)))
  }
  kpprime0 <- function(zeta) {
    2 * sum(lambda^2 / (1 - 2 * zeta * lambda)^2)
  }
  n <- length(lambda)
  if (any(lambda < 0)) {
    lmin <- max(1 / (2 * lambda[lambda < 0])) * 0.99999
  } else if (x > sum(lambda)) {
    lmin <- -0.01
  } else {
    lmin <- -length(lambda) / (2 * x)
  }
  lmax <- min(1 / (2 * lambda[lambda > 0])) * 0.99999
  hatzeta <- stats::uniroot(
    function(zeta) kprime0(zeta) - x,
    lower = lmin,
    upper = lmax,
    tol = 1e-08
  )$root
  w <- sign(hatzeta) * sqrt(2 * (hatzeta * x - k0(hatzeta)))
  v <- hatzeta * sqrt(kpprime0(hatzeta))
  if (abs(hatzeta) < 1e-04) {
    NA
  } else {
    stats::pnorm(w + log(v / w) / w, lower.tail = FALSE)
  }
}

# Saddlepoint approximation to Pr(sum(a_i * chi2(df_i)) > x).
#
# Port of the saddlepoint branch of survey::pchisqsum(). Falls back to the
# Satterthwaite moment-matched chi-square approximation when .saddle()
# returns NA (consistent with upstream's `if (!is.na(sad)) guess <- sad`
# pattern).
#
# @keywords internal
# @noRd
.pchisqsum_sad <- function(x, df, a, lower.tail = FALSE) {
  # Satterthwaite guess — serves as the fallback when the saddlepoint
  # root-finder returns NA.
  sat_a <- a
  if (any(df > 1)) {
    sat_a <- rep(a, df)
  }
  tr <- mean(sat_a)
  tr2 <- mean(sat_a^2) / (tr^2)
  scale <- tr * tr2
  ndf <- length(sat_a) / tr2
  guess <- stats::pchisq(x / scale, ndf, lower.tail = lower.tail)

  # Saddlepoint: expand a by df to produce the per-chi-square-component
  # eigenvalue vector, then call .saddle() per x element.
  lambda <- rep(a, df)
  sad <- sapply(x, .saddle, lambda = lambda)
  if (lower.tail) {
    sad <- 1 - sad
  }
  ifelse(is.na(sad), guess, sad)
}

# Saddlepoint approximation to the design-adjusted F reference.
#
# Derived from survey::pFsum() — the surveycore signature adds a
# `mean.deff` scalar. Callers supply `x` already divided by `mean.deff`;
# the helper multiplies back internally when it needs the original
# statistic (for the F reference and for the saddle augmentation
# `-x / ddf`). Under the default `mean.deff = mean(a)` the helper matches
# upstream when the caller passes `x_upstream / mean(a)`.
#
# @keywords internal
# @noRd
.pFsum_sad <- function(x, df, a, ddf, mean.deff = mean(a), lower.tail = FALSE) {
  if (is.infinite(ddf)) {
    return(.pchisqsum_sad(
      x * mean.deff,
      df = df,
      a = a,
      lower.tail = lower.tail
    ))
  }

  # Expand a by df for the Satterthwaite moments (matches upstream's
  # `if (any(df > 1)) a <- rep(a, df)` step).
  sat_a <- a
  sat_df <- df
  if (any(df > 1)) {
    sat_a <- rep(a, df)
  }
  tr <- mean(sat_a)
  tr2 <- mean(sat_a^2) / (tr^2)
  scale <- tr * tr2
  ndf <- length(sat_a) / tr2

  # Satterthwaite fallback; x is pre-divided by mean.deff so multiply back
  # to reconstruct the upstream statistic before dividing by ndf * scale.
  orig_x <- x * mean.deff
  rval <- stats::pf(orig_x / ndf / scale, ndf, ddf, lower.tail = lower.tail)

  # Saddlepoint: augment the eigenvalue vector with -orig_x / ddf, expand by
  # df, and call .saddle() at 0. Upstream only uses the saddle value when
  # it is non-NA.
  a_aug <- c(a, -orig_x / ddf)
  df_aug <- c(df, ddf)
  if (any(df_aug > 1)) {
    a_aug <- rep(a_aug, df_aug)
  }
  s <- .saddle(0, a_aug)
  if (!is.na(s)) {
    if (lower.tail) {
      rval <- 1 - s
    } else {
      rval <- s
    }
  }
  rval
}
