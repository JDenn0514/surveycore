# Measurements — replicate-scale-jkn-bootstrap

Every measured claim this run relies on, with the script that produced it.
Scripts live in the session scratchpad and are reproduced here in full,
because the scratchpad does not survive the session.

Environment for all three: survey 4.5, R 4.6.1 (2026-06-24 ucrt), Windows.

---

## M1 — `R = 1` with `type = "bootstrap"`, both sides

Run 2026-09-23, before D-1 was decided. This is the measurement D-1 rests on.

| Side | stored `scale` | SE of mean `y` |
|---|---|---|
| `survey::svrepdesign()` | `Inf` | `Inf` |
| `as_survey_replicate()` before this change | `1` | finite |

`survey` builds the design and signals no condition. Script:
`probe-r1-bootstrap.R`, reproduced at the end of this file.

## M2 — the percentage at `R = 20`

Run 2026-09-23, after the Pass 2 delta review reported a transposition.

```
sqrt(19/20)  = 0.9746794
1 - r        = 0.0253206   -> 2.5% SMALLER
1/r - 1      = 0.0259784   -> 2.6% LARGER
```

The two directions do not share one number. Behaviour rule 6 states the rise
and takes 2.6%; the `as_survey_nonprob()` note states the fall and takes
2.5%. `decisions.md` D-4 carries the correction.

## M3 — `test-spec.md` row 2.4's two frames

Run 2026-09-23, to confirm the Pass 2 fix round's pinned values.

`y = c(1, 2, 3, 4)`, base weight `w = c(1, 1, 2, 2)`.

| Replicate column | Deviation | Exactly zero | `Inf * dev^2` |
|---|---|---|---|
| `c(1, 1, 2, 2)` — frame B, equal to `w` | 0 | TRUE | `NaN` |
| `c(5, 1, 2, 2)` — frame A, one element changed | -0.73333333333333339 | FALSE | `Inf` |
| `3 * w` — proportional | 0 | TRUE | `NaN` |

The premise route, a design with an explicit `scale = 1`, gives a standard
error of `0` on frame B and `0.7333333` on frame A. So the premise is
observable, as row 2.4 now requires.

**The third row is the one that matters.** A proportionally rescaled
replicate column differs at every element and still gives a deviation of
exactly zero, because a weighted mean is invariant to a proportional
rescaling of its weights. Frame A must therefore differ non-proportionally.
Without that constraint frame A silently becomes frame B and its
`is.infinite()` assertions fail.

### One unreconciled disagreement, recorded rather than resolved

The Pass 2 delta agent reported that the **lognormal** frame the original
row 2.4 specified — `n = 40`, `y ~ rnorm`, `w = 100 * exp(rnorm(n, 0, 0.3))`,
replicate column equal to `w` — gives a deviation of `1.776e-15` rather than
zero, because the full-sample statistic accumulates through base `sum()` in
long double and the replicate statistic through a BLAS product in double
(`R/variance-replicate.R:106-112`).

A simplified reproduction of the same two routes, run independently by the
orchestrator at seed 11, returned a deviation of exactly `0`.

The two results are not reconciled. The orchestrator's probe approximates the
real accumulation route rather than calling it, so it is the weaker of the
two measurements, and neither is asserted here as the truth.

**The disagreement is itself the finding.** Two attempts at the same
computation returned different answers, so the original row's outcome was
environment-dependent or route-dependent. That is the argument for pinning
exactly-representable values, which the fix round did. The pinned frame in M3
is exact by construction: every value is a small integer or a half-integer
ratio, and no rounding occurs on either route. It does not depend on which of
the two measurements above was right.

---

## Script — `probe-r1-bootstrap.R` (M1)

```r
cat("survey:", as.character(utils::packageVersion("survey")), "\n")
cat("R:", R.version.string, "\n\n")

set.seed(11)
n <- 20
dat <- data.frame(
  y = rnorm(n),
  wt = runif(n, 1, 3),
  rep1 = runif(n, 1, 3)
)

res <- try(
  survey::svrepdesign(
    data = dat,
    weights = ~wt,
    repweights = dat["rep1"],
    type = "bootstrap",
    mse = TRUE,
    combined.weights = TRUE
  ),
  silent = TRUE
)

if (inherits(res, "try-error")) {
  cat("survey: refused with:", conditionMessage(attr(res, "condition")), "\n")
} else {
  cat("survey: built. scale =", format(res$scale), "\n")
  est <- survey::svymean(~y, res)
  cat("survey svymean SE:", format(survey::SE(est)), "\n")
}

res2 <- try(
  surveycore::as_survey_replicate(
    dat,
    weights = wt,
    repweights = rep1,
    type = "bootstrap",
    mse = TRUE
  ),
  silent = TRUE
)

if (inherits(res2, "try-error")) {
  cat("surveycore: refused with:",
      conditionMessage(attr(res2, "condition")), "\n")
} else {
  cat("surveycore: built. scale =", format(res2@variables$scale), "\n")
}
```

## Script — `probe-row24-frames.R` (M3)

```r
y <- c(1, 2, 3, 4)
w <- c(1, 1, 2, 2)
repB <- c(1, 1, 2, 2)
repA <- c(5, 1, 2, 2)
rep3w <- 3 * w

full <- sum(y * w) / sum(w)
rep_mean <- function(rp) as.numeric(y %*% matrix(rp, ncol = 1)) / sum(rp)

for (nm in c("repB", "repA", "rep3w")) {
  rp <- get(nm)
  dev <- rep_mean(rp) - full
  cat(sprintf(
    "%-6s dev = %-24s exact zero: %-5s  Inf*dev^2 = %s\n",
    nm, format(dev, digits = 17), identical(dev, 0), Inf * dev^2
  ))
}

for (nm in c("repB", "repA")) {
  rp <- get(nm)
  dev <- rep_mean(rp) - full
  cat(sprintf("%-6s se(scale=1) = %s\n", nm, format(sqrt(1 * dev^2))))
}
```

M2 is one line and needs no script: `sqrt(19/20)`, then `1 - r` and
`1/r - 1`.

## M4 — does `bootstrap.average != 1` survive a round trip?

Run 2026-09-28, after Stage 3 lens 6 flagged F-5's claim as unverified.

`n = 60`, `R = 8`, seed 11, `mse = TRUE`, `combined.weights = TRUE`.

| `bootstrap.average` | `survey` scale | surveycore stored | exported | SE identical at `tolerance = 0` |
|--:|--:|--:|--:|---|
| 1 | 0.1428571429 | 0.1428571429 | 0.1428571429 | yes |
| 3 | 0.4285714286 | 0.4285714286 | 0.4285714286 | yes |

`1/(R-1)` is 0.1428571429 for comparison, so the `bootstrap.average = 3`
design carries three times the default scale and keeps it through both
conversions.

**The effective scale round-trips exactly.** `from_svydesign()` stores
`scale = x$scale` (`R/methods-conversion.R:1016`), taking `survey`'s own
computed value, which already has `bootstrap.average` folded into it.
`as_svydesign()` passes `x@variables$scale` back out (`:372-375`, `:494`),
and `survey` honours a supplied `scale` for the bootstrap. Nothing recomputes
the value on either leg.

**So F-5's claim is wrong as written.** The spec requires the help page to
state that `as_svydesign()` "cannot round-trip a `survey` design built with
`bootstrap.average != 1`". It can, and the variance is preserved bit for bit.

What does not round-trip is the **argument** as a separately named quantity.
surveycore has no `bootstrap.average`, so a caller cannot build a design with
one, and the constructor's default is always `1/(R-1)`. That is a missing
constructor argument and not a lost number.

### Where the error came from

Not from the spec. Issue #253's body says: "`bootstrap.average` has no
surveycore equivalent. It is the numerator of `survey`'s scale, so
`as_svydesign()` cannot round-trip a design built with
`bootstrap.average != 1`." Decision D5 turned that into an instruction to
record it under `@param scale`. The planner implemented the instruction
faithfully. The premise was never checked until now.

The first sentence of that quotation is true. The inference in the second is
false, because the numerator is already inside the stored scale.
