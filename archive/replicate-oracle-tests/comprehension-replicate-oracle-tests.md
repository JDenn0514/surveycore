# Comprehension — replicate-oracle-tests

## How the facts below were established

An earlier session wrote this document with no shell. It read the `survey`
source from the CRAN mirror and ran nothing, so every claim carried
`[unverified]`. A second session ran the probes. Every claim below now names
its method: **read** (from source) or **measured** (from a run).

Every run is recorded verbatim in
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/measurements.md` [no such file],
with the script and its output in fenced blocks. Each measured claim below
cites a section of that file, `M0` to `M8`.

Environment, measured (M0 header): R 4.6.1, `survey` 4.5, `testthat` 3.3.2.

What is still unmeasured, and why:

| Claim | Why it stands unmeasured |
|---|---|
| GitHub issue #256's own text | No `gh` access in either session. Every statement about #256 comes from `plans/issue-cleanup.md`, which quotes and corrects it. |

Everything else in this file was run.

---

## Problem

surveycore's replicate oracle tests are supposed to prove that
`as_survey_replicate()` returns the number `survey::svrepdesign()` returns. One
block breaks that proof. The JK1 block at
`tests/testthat/test-variance-replicate.R:97-114` computes `(n_rep - 1)/n_rep`
in the test body and hands it to `svrepdesign()` as `scale =`. That is
surveycore's own default formula, restated in the test. The two sides then agree
because the test fed the same number to both, not because the two packages
agree. A wrong surveycore JK1 default would still pass. Four replicate types —
JKn, bootstrap, Fay and `other` — have no oracle block at all, so nothing
measures them. The work rebuilds the file so that each of the nine types gets
one block, neither side receives a value derived from the other, and a wrong
default turns a block red. Two known-wrong defaults, JKn and bootstrap, stay
pinned behind `testthat::expect_failure()` until the arc's later PR fixes them.

---

## Formulas

### The replicate variance, both packages

Both packages compute the same expression. Read from both bodies.

```
V = scale * sum_{r=1..R} rscales_r * (theta_r - center)^2

center = coef                          when mse = TRUE
center = mean(theta_r : rscales_r > 0) when mse = FALSE
```

surveycore, `R/variance-replicate.R:40-46`:

```r
if (isTRUE(mse)) {
  meantheta <- coef
} else {
  meantheta <- mean(thetas[rscales > 0])
}
sum((thetas - meantheta)^2 * rscales) * scale
```

`survey`, `svrVar()`, scalar branch:

```r
if (mse) {
  meantheta <- coef
} else {
  meantheta <- mean(thetas[rscales > 0])
}
v <- sum((thetas - meantheta)^2 * rscales) * scale
```

The two are the same expression, term for term. So every numerical disagreement
between the packages on a replicate design comes from `scale`, from `rscales`,
from `mse`, or from `theta_r` — never from the variance expression itself.

**Measured (M3).** On a `make_survey_data(seed = 15)` fixture the two packages
return the same mean to 15 significant figures on all five types run — BRR,
JK1, JK2, JKn and bootstrap. The difference is exactly `0`. So `theta_r` and
`coef` agree, and only `scale` can separate the standard errors.

### Symbol binding

| Symbol | Meaning | surveycore | `survey` |
|---|---|---|---|
| `R` | number of replicates | `length(@variables$repweights)` | `ncol(repweights)` |
| `theta_r` | estimate on replicate `r` | `rep_stat_fn(y, rep_mat)[r]` | column `r` of the replicate estimates |
| `coef` | full-sample estimate | `full_stat_fn(y, w)` | the `svymean`/`svytotal` coefficient |
| `scale` | overall variance scale | `@variables$scale` | `des$scale` |
| `rscales_r` | per-replicate scale | `@variables$rscales`, or `rep(1, R)` when `NULL` (`R/variance-replicate.R:92`) | `des$rscales` |
| `mse` | centring rule | `@variables$mse` | `des$mse` |
| `rho` | Fay shrinkage factor | not an argument today | `rho` |

surveycore always uses combined replicate weights. `R/variance-replicate.R:51-53`
states it, and the replicate mean is `sum(repwt * y) / sum(repwt)`.
`survey`'s `combined.weights` argument defaults to `TRUE`, so the two agree with
no argument passed.

### The scale each type uses

The caller supplies nothing. **Measured (M1)** at `R = 20`, except BRR and Fay,
which the generator gives `R = 10` on the same `n_psu` (M2).

| Type | `survey` scale, formula | `survey` value measured | Deparse line |
|---|---|--:|--:|
| BRR | `1/R` | `0.05` | 79-84 |
| Fay | `1/(R * (1 - rho)^2)` | `0.102040816326531` at `rho = 0.3` | 86-87 |
| JK1 | `(R-1)/R` | `0.95` | 96-106 |
| JK2 | `1` | `1` | 118-121 |
| JKn | `1` | `1` | 107-112, then the fall-through at 148-149 |
| bootstrap | `1/(R-1)` | `0.0526315789473684` | 88-95 |
| ACS | `4/R` | `0.2` | 114-116 |
| successive-difference | `4/R` | `0.2` | 114-116 |
| other | `1` | `1` | 123-128 |

Every measured value equals its formula at `R = 20`. `rscales` came back
`rep(1, R)` on all nine.

surveycore's value, read off `R/core-constructors.R:796-818`:

```r
JK1 = (n_rep - 1L) / n_rep,
JK2 = 1,
JKn = (n_rep - 1L) / n_rep,
BRR = 1 / n_rep,
Fay = 1 / n_rep,
bootstrap = 1 / n_rep,
ACS = 4 / n_rep,
`successive-difference` = 4 / n_rep,
other = 1
```

**Measured (M2)**, by building each design and reading `@variables$scale` back
at `R = 20`: BRR `0.05`, JK1 `0.95`, JK2 `1`, JKn `0.95`, bootstrap `0.05`, ACS
`0.2`, successive-difference `0.2`, other `1`, Fay `0.05`. The source and the
built object agree on every type.

### The size of the two open defects

Both open defects are a pure scale ratio, so the standard error ratio is the
square root of the scale ratio.

JKn: `SE_surveycore / SE_survey = sqrt(((R-1)/R) / 1) = sqrt((R-1)/R)`.

bootstrap: `SE_surveycore / SE_survey = sqrt((1/R) / (1/(R-1))) = sqrt((R-1)/R)`.

**Measured (M3)** on `make_survey_data(n = 200, n_psu = 20, n_strata = 4,
design = "replicate", seed = 15)`, `get_means(sc, y1, variance = c("se","ci"))`
against `survey::SE(svymean(~y1, sv))`, `mse = TRUE` on both sides, `R = 20`:

| Type | SE surveycore | SE `survey` | ratio | `sqrt(19/20)` | gap |
|---|--:|--:|--:|--:|--:|
| JKn | `0.240186788963527` | `0.2464264459334` | `0.974679434480991` | `0.974679434480896` | `-2.532057%` |
| bootstrap | `0.0551026284560812` | `0.0565341039389252` | `0.974679434480991` | `0.974679434480896` | `-2.532057%` |
| JK2 | `0.246426445933424` | `0.2464264459334` | `1.0000000000001` | — | `0.000000%` |
| JK1 | `0.240186788963527` | `0.240186788963503` | `1.0000000000001` | — | `0.000000%` |
| BRR (`R = 10`) | `0.0476228676218052` | `0.0476228676217971` | `1.00000000000017` | — | `0.000000%` |

Direction and size both confirmed. surveycore is **below** `survey` on JKn and
bootstrap, by the same factor, and the measured ratio matches `sqrt((R-1)/R)` to
13 significant figures. The gap is 2.53%; the SE tolerance is `1e-8`, so the gap
is about six orders of magnitude above it. The assertion fails loudly, which is
what `expect_failure()` needs.

The three agreeing types sit at a relative difference near `1e-13`, five orders
below the `1e-8` tolerance.

---

## Gotchas

### G1 — `survey` raises no typed condition. Every warning is a `simpleWarning`.

This is the finding that most affects the coming spec.

**Measured (M1)**, by `class()` on the condition object caught from each branch.
Every warning came back as `simpleWarning/warning/condition`. Both refusals came
back as `simpleError/error/condition`. Nine types, twelve distinct warning
branches, two stops — no typed condition anywhere.

The request's acceptance criterion says "Each block asserts the warning `survey`
raises, by class". The only class available is `"simpleWarning"`, which every
bare `warning()` in R shares. Asserting it proves almost nothing — a block would
pass on any warning at all, including the "Data do not look like combined
weights" warning that means the test data is wrong.

The useful assertion is on the message text:
`expect_warning(sv <- survey::svrepdesign(...), regexp = "guessing n=number of replicates")`.
That names the branch. The spec has to choose, and O2 records it.

### G2 — `expect_failure()` mechanics

Read from the `testthat` source:

```r
expect_failure <- function(expr, message = NULL, ...) {
  status <- capture_success_failure(expr)
  if (status$n_failure == 1 && status$n_success == 0) { ... pass() ... }
  fail(format_success_failure(status, exp_n_success = 0, exp_n_failure = 1))
}
```

`capture_success_failure()` runs `expr` under `withCallingHandlers()` with
handlers on the `expectation_failure` and `expectation_success` conditions.

**Measured (M4)** on the installed `testthat` 3.3.2, edition 3:

| Inside one wrapper | Result |
|---|---|
| 1 failing expectation | **passes** |
| 2 failing expectations | fails, `Expected 0 successes and 1 failure.` |
| 1 failing + 1 passing | fails, same message |
| 1 passing only | fails, same message |
| 0 expectations | fails, same message |
| `expect_equal(1, 1.1, tolerance = 1e-8)` — inner fails | **passes** |
| `expect_equal(1, 1.0000000001, tolerance = 1e-8)` — inner passes | fails |
| 3 failing expectations in one wrapper | fails |
| 3 failing expectations in 3 separate wrappers | **passes** |

Five mechanics follow, and each one constrains the coming test blocks:

1. **It wraps expectations, not values.** The argument must be an expectation
   call. `expect_failure(expect_equal(a, b, tolerance = 1e-8))` is the shape.
2. **It passes on exactly one failure and zero successes.** Measured. Zero
   expectations also fails, so an empty wrapper is not silent.
3. **Tolerance composes.** Measured. `expect_equal(tolerance = )` runs unchanged
   inside the wrapper, and the tolerance decides the outcome the wrapper reads.
4. **It muffles the inner failure.** The test stays green and the suite reports
   the wrapper's own single passing expectation.
5. **It does not capture R warnings.** Measured: a bare `warning()` raised inside
   the wrapper escaped it and reached the caller.

**Correction to the earlier draft.** It claimed that under edition 3 an escaped
warning fails the test. It does not. Measured inside `test_that()` at edition 3,
the run printed `Warning: probe: warning inside expect_failure` and then
`Test passed with 1 success`. `test_that()` returned `TRUE`. So an escaped
warning is reported, not fatal. It is still noise the block should not create,
because issue #167 is open on 256 unasserted warnings already masking new ones.

**Nesting order, measured (M4).** Only one order works:

| Shape | Result |
|---|---|
| `expect_warning(expect_failure(<warns, then fails>), "boom")` | **passes** |
| `expect_failure(expect_warning(<warns, then fails>, "boom"))` | fails |

The inner order fails because `expect_warning()` emits an expectation of its
own, which pushes the wrapper's count past one.

Consequence 2 is the one that will bite. The JKn and bootstrap blocks are wrong
by a scale factor, and the confidence interval bounds derive from the standard
error. So `se`, `ci_low` and `ci_high` all disagree. One wrapper around all
three fails, because `n_failure` is 3 — measured. Each assertion needs its own
wrapper, and three separate wrappers pass — also measured. That conflicts with
the request's criterion "Each block asserts the point estimate, the SE and both
CI bounds" only in shape, not in coverage. O3 records the choice.

### G3 — the point estimate cannot detect a scale defect

`scale` enters `svrVar()` only. It never touches `theta_r` or `coef`.
**Measured (M3):** on the JKn and bootstrap fixtures the mean agreed exactly
(difference `0`) while the standard error was wrong by 2.53%. A block that
asserted only the point estimate would report green on a wrong default. Each
oracle block must assert the standard error. The confidence interval bounds
detect the defect too, because they are `estimate +/- z * se`.

### G4 — JK2 warns even when the caller supplies nothing

`svrepdesign.default`'s JK2 branch, deparse lines 118-122:

```r
if (type == "JK2") {
    warning(paste("with type", type, "scale= and rscales= are not needed and will be ignored"))
    rscales <- rep(1, ncol(repweights))
    scale <- 1
}
```

The `warning()` sits outside any `is.null()` test. **Measured (M1):** a bare
`svrepdesign(type = "JK2")` with no `scale` and no `rscales` warned
`with type JK2 scale= and rscales= are not needed and will be ignored`. This is
D8's "one deliberate divergence", and it is why the current JK2 oracle block
wraps the call in `suppressWarnings()`
(`tests/testthat/test-variance-replicate.R:150`).

JK1 does the same thing for a different reason. Its branch fires when `scale` is
`NULL`, which is exactly the case where the caller supplied nothing (deparse
96-106). **Measured:** the bare JK1 call warned
`scale (n-1)/n not provided: guessing n=number of replicates`.

**Measured** for `type = "other"` on a bare call:
`scale or rscales not specified, set to 1`.

So three of the nine types warn on a bare call: JK1, JK2 and `other`. **Measured
(M1):** BRR, Fay, JKn, bootstrap, ACS and successive-difference were all silent
on a bare call. ACS and successive-difference warn only when the caller supplies
`scale` or `rscales`.

### G4b — `survey`'s `rho` warning names JK1 for five types

**Measured (M1).** A `rho` supplied for JK1, JK2, JKn, ACS or
successive-difference raises the one message
`rho not relevant to JK1 design: ignored.` — the type name is hard-coded, and it
is wrong for four of the five. Deparse lines 12-14 show why: one `%in%` test
covers all five. `type = "other"` has its own line, `rho ignored.` (15-16). BRR
has its own, `type='BRR' does not use 'rho=' argument, you may want type='Fay'`
(82-83). `type = "bootstrap"` raised **no** warning for a supplied `rho`, which
matches D7's `—` cell. A block that asserts the `rho` warning by message text
must expect the JK1 wording on four non-JK1 types.

### G5 — ACS emits a `message()` about `mse` when `mse` is omitted

Deparse lines 161-169:

```r
if (type == "ACS") {
    if (missing(mse) && !mse) {
        mse <- TRUE
        message("mse=TRUE assumed for type=\"ACS\"")
    }
    else if (!mse) {
        warning("The ACS uses MSE standard errors but you have specified mse=FALSE")
    }
}
```

The formal default is `mse = getOption("survey.replicates.mse")`. **Measured
(M3):** the option is unset (`NULL`) until the `survey` namespace loads, and
`FALSE` after. So a bare ACS call takes the first branch. **Measured (M2):**
`svrepdesign(type = "ACS")` with `mse` omitted emitted
`mse=TRUE assumed for type="ACS"` and returned `mse = TRUE`, `scale = 0.2`. It
is a `message()`, not a warning.

If the block passes `mse = TRUE` explicitly, `missing(mse)` is `FALSE`, so
neither branch runs and the call is silent. The current ACS blocks pass
`mse = TRUE` to both sides (`tests/testthat/test-variance-replicate.R:446,452`),
so they are already on the silent path. The rewrite should keep passing `mse`
explicitly on the ACS block.

### G6 — the combined-weights heuristic stays quiet on the generator's data

```r
repwtmn <- mean(apply(repweights, 2, mean))
wtmn <- mean(weights)
probably.not.combined.weights <- (repwtmn < 5) & (wtmn/repwtmn > 5)
if (combined.weights & probably.not.combined.weights)
  warning(paste("Data do not look like combined weights: ..."))
```

**Measured (M2)** on `make_survey_data(n = 200, n_psu = 20, n_strata = 4,
seed = 15)`, all four replicate types:

| Type | `R` | `repwtmn` | `wtmn` | ratio | warning fires? |
|---|--:|--:|--:|--:|---|
| brr | 10 | 11.9312 | 11.8389 | 0.9923 | no |
| jk1 | 20 | 11.9183 | 11.8389 | 0.9933 | no |
| jkn | 20 | 11.9183 | 11.8389 | 0.9933 | no |
| bootstrap | 20 | 11.9183 | 11.8389 | 0.9933 | no |

Both conditions fail with a wide margin: `repwtmn` is about 11.9 against the
threshold of 5, and the ratio is about 0.99 against the threshold of 5. The
warning did not fire on any bare call in M1 either. A block that asserts
`survey`'s warning by message text will catch this if it ever fires; a block
that asserts by class `"simpleWarning"` will not (G1).

### G7 — `rscales` of length 1 is legal

Deparse lines 71-74:

```r
if (!is.null(rscales) && !(length(rscales) %in% c(1, ncol(repweights)))) {
  stop(paste("rscales has length ", length(rscales), ", should be ncol(repweights)", sep = ""))
}
```

`survey` accepts length 1 or length `R`. `plans/issue-cleanup.md` D12 says
`survey`'s replicate `fpc` is "a numeric vector of length `R`" and that it
multiplies `rscales`; that is right for the `fpc` (deparse 140-146), and the
`rscales` check itself is looser than length `R`. surveycore's
`.validate_rscales(rscales, n_rep)` enforces its own rule, which is unread here.
Minor, and it matters only if the JKn block ever passes a scalar.

### G8 — the request's "several blocks" is one block

The request says "several blocks pass surveycore's OWN computed `scale` into
`svrepdesign()`". **Measured by grep over the whole file:** exactly one
`svrepdesign()` call receives a `scale`, at line 111, `scale = jk1_scale`, where
line 99 sets `jk1_scale <- (n_rep - 1L) / n_rep`. That is the same expression as
`R/core-constructors.R:799`. Two other `scale =` hits, at lines 558 and 573, are
direct `surveycore:::.svy_rep_var()` calls, not `svrepdesign()` calls. Every
other `svrepdesign()` call in the file passes `weights`, `repweights`, `type`,
`mse` and `data` only.

The file's real gap is wider than one round trip, and the rewrite still needs to
close it. Current oracle coverage:

| Type | Oracle blocks today |
|---|---|
| BRR | 4 (mean, total, `mse = FALSE`, `R != 4`) |
| JK1 | 1, and it is the round trip |
| JK2 | 1, with `suppressWarnings()` |
| ACS | 2 (mean, total) |
| successive-difference | 2 (mean, total) |
| JKn | 0 |
| bootstrap | 0 |
| Fay | 0 |
| other | 0 |

So four of the nine types have no oracle at all. `[unverified]` against #256's
own text, which neither session could read.

### G9 — issue #242 is merged, and the JK2 block passes

`R/core-constructors.R:806` reads `JK2 = 1`, with a comment at lines 800-805
citing issue #242. The JK2 oracle block at
`tests/testthat/test-variance-replicate.R:148` asserts
`expect_equal(sc@variables$scale, 1)` and at line 157 asserts
`expect_equal(sv$scale, 1)`.

**Measured (M5):** `NOT_CRAN=false testthat::test_local(filter =
"variance-replicate")` ran 24 blocks with **0 failures and 0 skips**. The JK2
block is green today and needs no `expect_failure()`. One block carries a
warning — `get_corr() replicate returns NA for domain with fewer than 2 paired
obs` — which is pre-existing and touches no oracle block.

**Measured (M3)** independently: JK2's SE ratio is `1.0000000000001`, a relative
difference near `1e-13` against a `1e-8` tolerance.

`plans/issue-cleanup.md` lines 13-17 record a second, separate defect, which D3
describes: the `@param scale` roxygen said JK2's per-stratum factors belong in
`rscales`. **That defect is fixed.** Issue #260 closed on 2026-09-16T07:32:40Z
with PR #280, commit `7800ea9`. `R/core-constructors.R:602-611` now reads that
the per-stratum factor is already inside the replicate weights, so `rscales`
stays at `rep(1, R)`, and a grep for the old wording across `R/`, `man/` and
`tests/` returns nothing. An earlier draft of this section described #260 as
open; it is not.

The fact still matters to this arc, as hygiene. The JK2 block carries a comment
about the scale, and that comment must not reintroduce the wording PR #280
removed.

### G10 — surveycore does not refuse JKn without `rscales` today

`survey` refuses. **Measured (M1):**
`stop("Must provide rscales for combined JKn weights")`, class
`simpleError/error/condition`.

`as_survey_replicate()` does not refuse. **Measured (M2):** building a JKn
design with no `rscales` succeeded and returned `scale = 0.95`. `rscales`
defaults to `NULL`, only `.validate_rscales(rscales, n_rep)` runs, and
`R/variance-replicate.R:92` substitutes `rep(1L, n_rep)` at estimation time.

The refusal is PR 4 of the arc (issue #255, per D4), not this PR. So the JKn
oracle block must pass the same literal `rscales` to both sides — `survey` will
not build without it, and passing it to both keeps the two sides symmetric.

### G11 — the export route's line number has moved

`plans/issue-cleanup.md` D10 says `as_svydesign()` passes `x@variables$scale`
into `svrepdesign()` at `R/methods-conversion.R:166`. **Measured by grep (M6):**
it is at **line 494**, `scale = scale_arg`, inside the `svrepdesign()` call at
lines 490-499. The BRR and Fay exclusion that D10 describes sits at line 372.
Line 166 in the current file is roxygen prose about a filtered design's domain.
D10's claim is right and its line number is stale. This arc's PR 1 touches no
source file, so the correction only matters to PR 4.

### G12 — both packages build the confidence bound from the normal distribution

Every numerical block compares both confidence bounds. That comparison rests on
a premise no earlier draft recorded: both sides must use the same distribution
and the same degrees of freedom. They do, and the distribution is the normal
one.

**Measured (M7):** four facts, all from one probe.

1. `survey:::confint.svrepstat` and `survey:::confint.svystat` both carry
   `df = Inf` in their formals.
2. `survey:::tconfint` takes its critical value from `qt(a, df = df)`. At
   `df = Inf` that value is bit-identical to `qnorm(a)`:
   `1.95996398454005361` from both.
3. On a JK1 design at `R = 20`, `confint(m)` is identical to
   `confint(m, df = Inf)`. Against `confint(m, df = survey::degf(sv))`, with
   `degf(sv) = 19`, each bound moves by `0.032`.
4. surveycore's Phase 1 analysis files assign `degf <- Inf` unconditionally, at
   six sites: `R/analysis-covariance.R:241`, `R/analysis-freqs.R:173`,
   `R/analysis-means.R:166`, `R/analysis-ratios.R:207`,
   `R/analysis-totals.R:166` and `R/analysis-variance.R:192`. `.degf(design)`,
   which computes design-based degrees of freedom, has eight live call sites.
   Seven fill the result's `cell_df` attribute behind an `is_taylor_like` guard,
   so a replicate design never reaches them. The eighth is `R/glm.R:587`, inside
   `survey_glm()`, which no oracle block builds.

surveycore's bounds sit `4.974e-14` from `survey`'s default bounds and
`3.196e-02` from the design-based ones. So the agreement the blocks assert comes
from the shared normal approximation, not from the estimator alone.

Nothing enforces the premise. If a later PR moves surveycore's replicate path to
design-based degrees of freedom, every bound assertion in the file fails at once,
the standard error assertions all stay green, and the pattern reads as a scale
defect. That PR must revisit the oracle blocks with it.

### G13 — the literature anchor for JKn, for PR 3 to inherit

This is a note for PR 3 of the arc, which fixes the JKn and bootstrap defaults
(issue #253). PR 1 ships no scale change, so nothing here is PR 1's work.

Wolter (2007), *Introduction to Variance Estimation*, chapter 4 gives the
stratified jackknife a per-replicate factor keyed to the number of primary
sampling units in the stratum that the replicate drops. That is why `survey`
carries the factor in `rscales`, one entry per replicate, and why it refuses JKn
with combined weights and no `rscales`. `survey` is right by the literature
here, not merely different from surveycore.

surveycore's `(R-1)/R` substitutes the total replicate count for the per-stratum
count. The two agree only when every stratum contributes the same number of
primary sampling units. So closing the 2.53% gap by changing the default to `1`
leaves surveycore wrong under unequal stratum sizes, and PR 3's spec should say
what it does about the per-stratum factor.

**`[verify]`** — the Wolter citation came from a review agent, not from the book.
Check the chapter and the formula against a copy before PR 3's spec cites it.

---

## Reference mapping

One row per type. **Measured (M1)** by building a probe design at `R = 20` and
reading `des$scale` and `des$rscales`, three times per type: with nothing
supplied, with `scale = 0.123` and `rscales = rep(0.77, 20)` supplied, and with
`rho = 0.3` supplied.

The deparse column gives the line numbers observed in the 172-line dump of
`survey:::svrepdesign.default` (M0). They agree with `plans/issue-cleanup.md`
D2 and D7 on every cited row; no observed number disagrees.

| Type | `survey` default scale | surveycore default scale | Agree? | Overrides a supplied `scale`? | Discards a supplied `rscales`? | Refuses without? | Warning text and trigger | Deparse lines observed |
|---|---|---|---|---|---|---|---|--:|
| BRR | `1/R` = `0.05` | `1/R` = `0.05` | yes | yes, and warns `type='BRR' does not use 'scale=' argument` | no, honoured (`0.77` kept) | no | none on a bare call. Warns on a supplied `scale`, and on a supplied `rho`: `type='BRR' does not use 'rho=' argument, you may want type='Fay'` | 79-84 |
| Fay | `1/(R*(1-rho)^2)` = `0.102040816326531` at `rho = 0.3` | `1/R` = `0.05` | no — surveycore has no `rho`, so it computes the BRR scale | yes, silently (`0.123` overridden, no warning) | no, honoured | **yes, refuses without `rho`**: `With type='Fay' you must supply the correct rho`, `simpleError` | 10-11 (the stop), 86-87 |
| JK1 | `(R-1)/R` = `0.95` | `(R-1)/R` = `0.95` | yes | no, honoured (`0.123` kept) | no, honoured | no | `scale (n-1)/n not provided: guessing n=number of replicates`, whenever `scale` is `NULL` and `combined.weights = TRUE` | 96-106 |
| JK2 | `1` | `1` | yes | yes, and warns | yes, and warns (forced to `rep(1, R)`) | no | `with type JK2 scale= and rscales= are not needed and will be ignored`, **unconditional** | 118-121 |
| JKn | `1` | `(R-1)/R` = `0.95` | **no** | no, honoured (`0.123` kept) | no, required and honoured (`0.95` kept) | **yes, refuses without `rscales`** when `combined.weights = TRUE`: `Must provide rscales for combined JKn weights`, `simpleError` | 107-112, then 148-149 |
| bootstrap | `1/(R-1)` = `0.0526315789473684` | `1/R` = `0.05` | **no** | no, honoured | no, honoured | no | none, on any of the three probes | 88-95 |
| ACS | `4/R` = `0.2` | `4/R` = `0.2` | yes | yes | yes, forced to `rep(1, R)` | no | `with type ACS scale= and rscales= are not needed and will be ignored`, only when `scale` or `rscales` is supplied | 75-77 (the warn), 114-116 (the force) |
| successive-difference | `4/R` = `0.2` | `4/R` = `0.2` | yes | yes | yes, forced | no | `with type successive-difference scale= and rscales= are not needed and will be ignored`; same branch as ACS with the type name substituted | 75-77, 114-116 |
| other | `1` | `1` | yes | no, honoured | no, honoured | no | `scale or rscales not specified, set to 1`, whenever **either** is `NULL`. Measured: supplying **both** silences it. | 123-128 |

**Measured:** condition class for every warning row is
`simpleWarning/warning/condition`; for every refusal row it is
`simpleError/error/condition`. See G1.

Two types disagree on the default scale: **JKn and bootstrap**. Fay disagrees as
well, but `survey` refuses the comparison before it reaches the scale — measured
at deparse line 11 — so no oracle block can measure it until issue #243 adds
`rho`. JK2 agrees, because PR #258 merged; measured green in M5.

That is three types where surveycore is wrong, not four. The task brief listed
JK2 among them as "fixed and merged in PR #258", and the run confirms the fix
landed.

### Decision mapping

| Locked decision | What it fixes in this work |
|---|---|
| D2 (the target table) | The nine per-type expectations. Each oracle block asserts against the row for its type. Every D2 line number and every D2 value is measured correct (M0, M1). |
| D3 (JK2 does not use `rscales`) | The JK2 block's comment. `survey` forces `rscales <- rep(1, R)` and `scale <- 1`; measured. The block supplies neither. |
| D4 (JKn requires `rscales`; JK2 does not) | The JKn block supplies a literal `rscales`, because `survey` refuses without it; refusal measured. The JK2 block supplies nothing. |
| D5 (bootstrap default becomes `1/(R-1)`) | The bootstrap block's SE assertion goes inside `expect_failure()` and names issue #253. Measured gap: `0.0551026` against `0.0565341`. |
| D7 (what happens to a supplied argument) | The rule that no block passes a `scale` to either side. Measured: for five types `survey` discards it, four of them with a warning, so passing it turns the block into a warning test. |
| D8 (do not warn when the caller supplied nothing) | Explains why the JK2 block sees a warning on a bare call — measured — and why surveycore will not raise one. The block asserts `survey`'s warning; it asserts nothing about a surveycore warning. |
| D9 (JK1: the numbers agree, the warnings do not) | The JK1 block drops `scale = jk1_scale` and asserts `survey`'s guessing warning instead of suppressing it. Measured: both sides give `scale = 0.95` and SEs agree to `1e-13`. |
| D1 (oracle scope) | `as_survey_nonprob()` is not in this file's oracle scope. The existing block "get_means() agrees between the two JK2 constructors" compares the two surveycore constructors and uses no oracle, so the rule does not reach it. |
| D10 (export route) | The cited line `R/methods-conversion.R:166` is stale; the site is line 494 (M6). PR 4's concern, not PR 1's. |

### Source mapping

| Source | Design decision it informs |
|---|---|
| `svrepdesign.default`, Fay guard (deparse 10-11) | Fay is out of scope for PR 1. `survey` stops before it builds, so no comparison is possible. |
| `svrepdesign.default`, JKn `rscales` guard (107-112) | The JKn block passes a literal `rscales` to both sides. |
| `svrepdesign.default`, JK2 branch (118-121) | The JK2 block asserts an unconditional warning and passes neither `scale` nor `rscales`. |
| `svrepdesign.default`, JK1 branch (96-106) | The JK1 block asserts the guessing warning and passes no `scale`. |
| `svrepdesign.default`, bootstrap branch (88-95) | The bootstrap SE differs by `sqrt((R-1)/R)`, measured `0.974679`; wrap it. |
| `svrepdesign.default`, ACS `mse` branch (161-169) | The ACS block keeps passing `mse` explicitly, which silences the `message()`. |
| `svrVar` | The two variance expressions are identical, so the oracle isolates `scale`, `rscales` and `mse`. Measured: the point estimates agree exactly. |
| `testthat::expect_failure` | One wrapper holds exactly one failing expectation. Measured on 3.3.2. |
| `.claude/rules/testing-surveycore.md` | Tolerances `1e-10` point, `1e-8` SE, `1e-6` CI. `skip_if_not_installed("survey")` sits inside each block, never at file level. `test_invariants(design)` runs once per constructor per FILE. |

---

## Assumptions

- **The installed `survey` matches the mirror source.** Now measured (M0). The
  earlier session read the mirror; this one deparsed the installed
  `svrepdesign.default` into 172 lines. Every behaviour the mirror-derived table
  claims appears in the dump, at the line numbers the table gives. The two
  sources agree on all nine types, both refusals and every warning text.
- **`combined.weights = TRUE` is the right mode.** `survey`'s formal default is
  `TRUE` (deparse line 4), and `R/variance-replicate.R:51-53` states surveycore
  always uses combined weights. Every oracle block relies on this, because three
  of `survey`'s branches take a different path when it is `FALSE`. No block
  should pass `combined.weights`.
- **`make_survey_data()` produces combined-looking weights.** Now measured (G6,
  M2). `repwtmn` is about 11.9 and the ratio about 0.99, on all four replicate
  types at `seed = 15`. The heuristic does not fire.
- **`R` differs by type on the same `n_psu`.** Measured (M2): at `n_psu = 20`,
  `brr` gives `R = 10` and `jk1`, `jk2`, `jkn` and `bootstrap` give `R = 20`.
  `fay` follows `brr` in the generator's `switch`. A block that hard-codes a
  replicate count breaks when the type changes. Each block should read `R` from
  the selected columns.
- **The variance expression is not under test.** The two bodies are identical, so
  a block that disagrees disagrees on an argument, not on the estimator.
- **`test_invariants()` does not run in this file.** Measured by grep: no
  `test_invariants` call in `tests/testthat/test-variance-replicate.R`. The
  house rule is once per constructor per FILE, so the spec may place at most one
  call per constructor here.
- **`theta_r` agrees between the packages.** Measured (M3): the mean difference
  is exactly `0` on BRR, JK1, JK2, JKn and bootstrap.
- **surveycore raises no warning of its own in any block.** Measured (M2):
  building all nine types with nothing supplied produced no surveycore warning.
  Under D8 the constructors will warn only on a supplied argument, and no block
  supplies one.

---

## Open questions

**O1 — CLOSED.** The probes ran. Every `[unverified]` mark in the earlier draft
is now a measured value, except #256's own text, which needs `gh`. The scripts
and their verbatim output are in
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/measurements.md` [no such file].

**O2 — "Assert the warning by class" has no useful answer.** OPEN. A user
decision.

Measured facts it needs:

- Every `survey` warning in `svrepdesign.default` came back as
  `simpleWarning/warning/condition`. Both refusals came back as
  `simpleError/error/condition`. Measured on twelve warning branches and two
  stops (M1).
- Three types warn on a bare call: JK1, JK2 and `other`. Six do not.
- The message texts are stable and distinct per branch, so
  `expect_warning(regexp = )` names the branch. The exact texts are in the
  Reference mapping table, each copied from a run.
- One text is misleading: a supplied `rho` on JK2, JKn, ACS or
  successive-difference raises `rho not relevant to JK1 design: ignored.` (G4b).
  A regexp on "JK1" would match four non-JK1 types.
- Asserting `class = "simpleWarning"` also matches the combined-weights warning,
  which means the test data is wrong. Measured: that warning does not fire on
  `make_survey_data()` today (G6), so the class assertion would not catch a
  future change in the generator.

The spec must pick one of three: assert on the message text with
`expect_warning(regexp = )`; assert `class = "simpleWarning"` and accept that it
proves little; or assert the message and record in the test-spec why no class
exists. The measured evidence favours the message text, because it names the
branch. Raised as a **HOLD candidate**, not settled here.

**O3 — The JKn and bootstrap blocks cannot assert all four quantities in one
wrapper.** OPEN. A user decision.

Measured facts it needs:

- One `expect_failure()` wrapper round three failing expectations **fails**
  (`Expected 0 successes and 1 failure.`). Three separate wrappers, one each,
  **pass**. Measured on `testthat` 3.3.2, edition 3 (M4).
- A wrapper round zero expectations also fails, so an unused wrapper is not
  silent.
- On the `seed = 15` fixture at `R = 20`, the SE gap is 2.53% on both types, and
  the CI bounds inherit it. Both are far above the `1e-8` SE and `1e-6` CI
  tolerances, so all three assertions fail loudly and reliably.
- The point estimate agrees exactly, so a fourth wrapper round it would itself
  fail. The point estimate must stay outside any wrapper.

So the block needs three separate wrappers — SE, `ci_low`, `ci_high` — plus a
bare point-estimate assertion; or it asserts the point estimate plus one wrapped
SE and adds the CI assertions in PR 3 when the wrapper comes out. Three wrappers
is the honest shape: it pins all three wrong numbers, and PR 3 deletes all three
lines. The spec must state which.

**O4 — The `other` block has no obvious data shape.** OPEN, and cheap.
`type = "other"` accepts any replicate weights and scales at 1.
`make_survey_data()` has no `other` mode. A block can build `other` on top of
`brr` or `jk1` columns, the way the JK2 block builds on `jk1` columns today.
Measured (M1, M2): both sides then carry `scale = 1` and `rscales = rep(1, R)`,
and `survey` warns `scale or rscales not specified, set to 1`. Measured also:
supplying **both** `scale` and `rscales` silences that warning and `survey`
honours both values, so the block must supply neither.

**O5 — What the Fay block becomes.** OPEN. The request puts Fay out of scope.
Measured (M1): `svrepdesign(type = "Fay")` with no `rho` raises
`With type='Fay' you must supply the correct rho`, class `simpleError`, before
it builds anything. Measured (M2): surveycore accepts `type = "Fay"` with no
`rho` and stores `scale = 0.05` = `1/R`. The open choice is whether PR 1 leaves
the file with eight blocks and a comment naming #243, or adds a ninth block that
asserts only the refusal. The second keeps the nine-row shape and pins the
reason Fay is absent.

**O6 — CLOSED.** `getOption("survey.replicates.mse")` is `NULL` before the
`survey` namespace loads and `FALSE` after (M3). So a bare ACS call takes the
`missing(mse) && !mse` branch, emits `message("mse=TRUE assumed for type=\"ACS\"")`
and sets `mse = TRUE` (M2). Every block should still pass `mse` explicitly to
both sides, which the request already requires, and which silences the message.
