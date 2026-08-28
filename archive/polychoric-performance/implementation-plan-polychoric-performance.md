# Implementation Plan — polychoric speed fix (issue #177)

**Issue:** #177 — `get_corr(method = "polychoric")` is ~164x slower than
`polycor::polychor()`.
**Branch:** `fix/polychoric-performance` → `develop`
**Tier:** 2 (plan only) — the behaviour is fixed, the approach is not.
**Status:** Amended 2026-08-27 after the Step 0.5 verification run. Steps 1–3
are verified bit-identical in advance.

---

## 1. What must not change

The two implementations agree to 6.4e-12. This is a speed defect only.

- No estimate, standard error, or confidence bound may move beyond the
  tolerances already in the suite.
- No test tolerance may be relaxed. The issue states this. Treat it as a
  hard gate.
- Every exported signature stays as it is. No user-facing change.
- `.corr_polychoric_loglik()` keeps its argument list and its return
  contract `list(ll, any_floor_active)`. Four tests in
  `test-analysis-corr-latent-primitives.R` call it directly.

## 2. Cost structure

The cost has two layers. The issue names the first one.

**Layer 1 — the inner constant.** `.corr_bivnorm_cdf()`
(`R/analysis-corr-latent.R:340`) takes scalars only. Both cell loops call it
four times per cell:

| Site | Lines |
|---|---|
| `.corr_polychoric_loglik()` | 408–411 |
| `.corr_count_sparse_cells()` | 709–712 |

For a 6x7 table that is 42 cells x 4 = 168 entries into the `pbivnorm`
wrapper for each log-likelihood evaluation. The wrapper runs four
`replace()` calls and one `sapply()` on every entry. The profile in the
issue shows this: `replace` 13.7% self, `simplify2array` 8.7% self, and only
16.8% self in `pbivnorm` itself.

The 168 entries read a grid of just `(k_x + 1)` x `(k_y + 1)` = 56 distinct
threshold pairs. Neighbouring cells recompute the same corner up to four
times.

**Layer 2 — the outer multiplier.** `.corr_numerical_influence()`
(`R/analysis-corr-latent.R:944`) refits the complete MLE once for every
active observation, to build the influence function. Line 1573 calls it on
every `survey_taylor` design. There is no option to skip it.

Step 0 instrumented one `get_corr()` call on the 6x7 fixture, n = 300:

```
301 MLE fits  ->  4,816 loglik evaluations  ->  809,088 wrapper entries
                                            +   50,568 from the sparse-cell loop
```

`polycor::polychor()` runs one fit and computes no variance. That is the
real source of the ratio: 29.69 s / 301 fits = 98.6 ms per fit, against
120 ms for `polycor`'s one fit. The per-fit speeds already match.
`polycor::binBvn()` loops `mvtnorm::pmvnorm()` cell by cell, so it is not
vectorised either. Layer 1 divides the whole product by a large constant;
Steps 2–3 attack the multiplier.

The 4,816 loglik evaluations split exactly: 301 × 16, of which 5 per fit
are the pre-`optimize()` probe and 11 are `optimize()` itself.

`.corr_estimate_thresholds()` and the cell-count loop also run once per
refit, which makes them O(n^2) across the influence loop. Step 3 removes
them from the refits with a delta update.

## 3. Steps

### Step 0 — record the baseline — DONE

Measured on this branch at `95d9ddd`, R 4.6.1, `pbivnorm` 0.6.0,
`polycor` 0.8.2. Scripts stay in the scratchpad; they are not committed.

| Measure | Issue | Measured here |
|---|---|---|
| 6x7 table, n = 300 | 36.09 s | **29.69 s** |
| `polycor` on the same data | 0.22 s | **0.12 s** |
| Ratio | 164x | **247x** |
| 3x3 table, n = 200 | 4.39 s | **3.81 s** |
| `polycor` on the same data | 0.03 s | **0.02 s** |
| Ratio | 146x | **191x** |

Both machines agree on the shape. This machine is faster in absolute terms
and `polycor` gains more from that, so the ratio here is higher.

Test-file wall time, `NOT_CRAN = true`, all pass:

| File | Time | Expectations |
|---|---|---|
| `test-analysis-corr-latent.R` | **306.7 s** | 126 |
| `test-analysis-corr-latent-variance.R` | **48.7 s** | 86 |
| `test-analysis-corr-latent-primitives.R` | 4.4 s | 86 |
| Two slow files | **355.4 s** | 212 |

**Pinned values.** Step 1 must reproduce these to 1e-10 or better — not
bit for bit, because the `ll` sum-order change moves the objective in its
last bits, so `optimize()` may move `r`'s trailing digits. Record the
post-Step-1 values; Steps 2 and 3 must then reproduce those exactly
(`identical()`), because both are bit-identical given the Step 1 objective.

6x7 fixture, n = 300, seed 87:

| Field | Value |
|---|---|
| `r` | `-0.01243641783992804` |
| `ci_low` | `-0.1400506894810396` |
| `ci_high` | `0.11558427081546385` |
| `p_value` | `0.84959233507917253` |
| `statistic` | `-0.18963860322111747` |
| `polycor` rho | `-0.012436417833492502` |
| Difference | 6.4e-12 — matches the issue |

3x3 fixture, n = 200, seed 87:

| Field | Value |
|---|---|
| `r` | `-0.017920077145335597` |
| `ci_low` | `-0.18251303814298397` |
| `ci_high` | `0.14764990104790368` |
| `p_value` | `0.8330680248080119` |
| `statistic` | `-0.21076836534021023` |

**Call counts, instrumented on the 6x7 fit.** These confirm both layers:

| Count | Value |
|---|---|
| `.corr_polychoric_mle()` fits per `get_corr()` call | **301** (1 + 300 refits) |
| `.corr_polychoric_loglik()` evaluations per call | **4,816** |
| Scalar `pbivnorm` entries from the loglik loop | **809,088** |
| Scalar `pbivnorm` entries from the sparse-cell loop | 50,568 (301 x 42 x 4) |

**Baseline profile, 20.4 s sampled.** Self time, grouped:

| Group | Self % |
|---|---|
| `pbivnorm` wrapper plumbing — `replace`, `sapply`, `simplify2array`, `unique`, `lapply`, `unlist`, `%in%`, `match.fun`, `max`, `isFALSE`, `lengths` | **≈ 55%** |
| `pbivnorm::pbivnorm` itself | 17.1% |
| `.Fortran` — the real numerical work | **6.3%** |
| `.corr_bivnorm_cdf` | 6.3% |
| `.corr_polychoric_loglik` | 4.4% |

By total time: `.corr_numerical_influence` **99.1%**,
`.corr_bivnorm_cdf` 93.2%, `pbivnorm::pbivnorm` 84.7%.

About 55% of the run is per-call entry overhead inside the `pbivnorm`
wrapper. Only 6.3% is the Fortran routine. Step 1 removes almost all of the
55%.

### Step 0.5 — verify the bit-identity claims — DONE

Four checks ran on 2026-08-27. The scripts live in the session scratchpad
(`check_A.R` … `check_D.R`); they are not committed.

| Check | Claim | Result |
|---|---|---|
| A | One vectorised `pbivnorm` call gives the same doubles as scalar calls | **PASS** — `identical()` on a 168-pair grid × 10 rho values, including ±8, ±37, and rho = ±(1 − 1e-6) |
| A | The `ll` sum-order change stays inside the 1e-8 pin | **PASS** — max relative difference 4.0e-16 |
| B | Influence refits consume only `$rho`; the probe and the sparse-cell count feed nothing there | **PASS** — static read confirmed (probe → unreachable guard only; sparse count runs after `rho_hat` is fixed; the loop reads `fit_pert$rho` once). 10 refits rebuilt without both gave `identical()` rho |
| C | The delta recompute equals the full rebuild, bit for bit | **PASS** — 300 rows × 2 weight fixtures; level sums, thresholds, and cell counts all `identical()`, max difference exactly 0 |
| C | `sum()` is a safe substitute for the `+=` cell loop | **REFUTED** — `sum()` diverges from the `+=` loop on 130/300 rows with lognormal weights. The delta path must use the `+=` style |
| D | Rows with the same (cell x, cell y, weight) key give the same IF value | **MEASURED** — wt = 1 fixture: 42 distinct keys, within-key spread exactly 0. Lognormal weights: 300 distinct keys, so dedup never triggers |

Consequences:

- Step 1 is safe as specified.
- The probe and the sparse-cell count can leave the refits with no numeric
  change — that is Step 2.
- The delta refit is bit-identical only with `+=` accumulation in
  increasing row order — that is Step 3.
- Refit dedup is exactly free on equal weights and inert on continuous
  weights. It stays a follow-up (Step 5): mixed weights — duplicate values
  among varied ones — were not measured.

### Step 1 — one vectorised grid call per rho

Add one internal helper. Both loops then call it.

```r
# Returns the (k_x + 1) x (k_y + 1) matrix of bivariate-normal CDF values
# over the grid tx_full x ty_full, at a single rho.
.corr_bivnorm_cdf_grid <- function(tx_full, ty_full, rho) { ... }
```

Rules the helper applies element-wise, in this precedence order. The order
is the same one `.corr_bivnorm_cdf()` uses today, and it matters — a pair of
`-Inf` and `NA` must give `NA`, not `0`.

1. `NA` or `NaN` in `a`, `b`, or `rho` → `NA_real_`
2. `a == -Inf` or `b == -Inf` → `0`
3. `a == +Inf` and `b == +Inf` → `1`
4. `a == +Inf` → `pnorm(b)`
5. `b == +Inf` → `pnorm(a)`
6. otherwise → one `pbivnorm::pbivnorm()` call over all remaining entries

Interior thresholds are not always finite. `qnorm()` returns `±Inf` when a
cumulative proportion reaches 0 or 1, and the `NaN` threshold test at
`test-analysis-corr-latent-primitives.R:732` passes `NaN` in. So the helper
applies all six rules across the whole grid. It must not assume that only
the border carries a sentinel.

Implement the six rules with base logical masks (`out[mask] <- value`).
Do not use `ifelse()`, `dplyr::if_else()`, or `dplyr::case_when()` — the
grid is small (56 values) but the helper runs ~4,800 times per call, so
per-call overhead dominates throughput.

Then replace both loops:

- `.corr_polychoric_loglik()` — build the grid once, form the whole
  `k_x` x `k_y` cell-probability matrix by differencing four shifted
  sub-matrices, floor it, and sum `w * log(p)` over cells with positive
  weight.
- `.corr_count_sparse_cells()` — same cell-probability matrix, then count
  entries below `tol` among cells with positive weight.

The cell probabilities come out bit-identical: the same `pbivnorm` Fortran
routine loops over its input element by element, so a vector of 30 gives the
same doubles as 30 calls of length 1, and the differencing is element-wise
arithmetic on those same doubles. Only the order of the final `ll` sum
changes, from row-major accumulation to `sum()` over a matrix. That moves
`ll` by about 1e-16 relative. The direct test pins `ll` at `1e-8`, so it
absorbs this. Step 0.5 (check A) confirmed both claims empirically; test 2
in section 5 keeps the grid-vs-scalar comparison as the regression guard.

Extract the shared cell-probability construction into one helper. The two
call sites must not each carry their own copy of the differencing — that is
the DRY rule in `.claude/rules/engineering-preferences.md`, and it is how
the duplicate loop at line 709 came to exist.

Delete `.corr_bivnorm_cdf()`. Nothing else calls it, and leaving it in place
leaves uncovered lines behind. Update the helper index in the file header at
lines 11–21.

### Step 2 — lean refit mode for the influence loop

Each fit spends 5 of its 16 loglik evaluations on the pre-`optimize()`
probe (`.corr_polychoric_mle()` lines 592–597). The probe feeds only a
guard the code's own nocov comment calls unreachable. The sparse-cell count
(lines 660–666) runs after `rho_hat` is fixed. The influence loop reads
only `fit_pert$rho` (line 1008). Step 0.5 (check B) verified all three
facts, statically and dynamically.

Add an internal argument `refit = FALSE` to `.corr_polychoric_mle()` and
`.corr_polyserial_mle()`. When `TRUE`:

- skip the 5-point probe;
- skip `.corr_count_sparse_cells()` (polychoric only) and return
  `n_sparse_cells = NA_integer_`.

`.corr_numerical_influence()` passes `refit = TRUE`. So does
`.corr_replicate_variance_latent()` for its per-replicate refits — it also
consumes only `$rho` (lines 44–45, 128–132, 167–168 of that function), so
the same bit-identity argument holds. Its full-sample fits stay
`refit = FALSE`. No exported signature changes, and
`.corr_polychoric_loglik()` keeps its pinned contract — the new argument
lives on the MLE functions, which no test pins.

Bit-identical by construction: the skipped work feeds no value the refit
caller uses. Cuts refit loglik evaluations from 16 to 11 and removes one
grid evaluation per refit.

### Step 3 — O(1) refit setup by delta update

This replaces the earlier `rowsum()` idea. `rowsum()` changes the
summation order, so it is not bit-identical; the delta update is, and it is
also faster — O(1) per refit instead of O(n).

Each refit changes one weight, then rebuilds everything from all n rows:
two threshold estimations with a per-level `sum(w_eff[codes_all == k])`
pass (`.corr_estimate_thresholds()` 231–235) and the O(n) cell-count `+=`
loop (`.corr_polychoric_mle()` 552–557). Across n refits that is O(n^2).
But perturbing row i touches exactly one level sum per margin and one cell.

Change the polychoric path of `.corr_numerical_influence()`:

1. Compute once, from the unperturbed data: per-level row-index vectors
   for each margin, per-cell member-index vectors in increasing row order,
   the base level sums, and the base cell counts.
2. Per refit, recompute only what row i touches:
   - the affected level sum per margin, via the same
     `sum(w_eff_pert[idx_level])` call the source uses today;
   - the affected cell, via an R-level `+=` loop over its member indices
     in increasing row order. Not `sum()` — check C showed `sum()`
     diverges on 130/300 rows with lognormal weights, because `sum()`
     accumulates in extended precision and the `+=` loop rounds each step.
3. Rebuild `cum_prop` and the `qnorm()` thresholds from the updated level
   sums — O(K).

   Handle the rows a perturbation does not fully touch: a row with an NA
   code on one margin updates only the other margin and no cell; a row
   with NA on both margins, or with zero effective weight, updates
   nothing. Level and cell membership never changes — `w * (1 + 1e-4)`
   keeps zero at zero and positive at positive.
4. Optimize exactly as the full fit does. Extract the objective-plus-
   `optimize()` core of `.corr_polychoric_mle()` into one shared internal
   helper so the full fit and the delta refit run the same code (the DRY
   rule in `.claude/rules/engineering-preferences.md`).

Error classes stay intact. A perturbation multiplies one weight by
`1 + 1e-4`, so level and cell membership cannot change: a refit cannot
newly hit PC-4 or PC-5 when the full fit passed. The PC-6 rethrow in the
influence loop keeps its existing test.

The polyserial path stays as it is. Its likelihood is O(n) per evaluation
by nature, so setup does not dominate there; it still gains from Steps 1–2.

Step 0.5 (check C) verified the delta path bit-identical on 300 rows × 2
weight fixtures. Test 6 in section 5 pins it in the suite.

### Step 4 — verify, then measure

Run the gates in section 4. Re-run the Step 0 benchmark. Report the new
time and ratio.

**Resolved in Step 0.** The `unique` entry in the profile — 11.4% self in
the issue, 10.6% here — is not surveycore code. `pbivnorm::pbivnorm()` runs
`sapply(list(x, y, rho), length)`, `sapply()` calls `simplify2array()`, and
`simplify2array()` opens with `unique(lengths(x))`. So `unique`, `lengths`,
`unlist`, `%in%`, `match.fun`, and `isFALSE` all belong to the wrapper's own
entry cost. Step 1 removes them.

### Step 5 — profile again and hand off the follow-ups

Re-run `Rprof()` on the 6x7 fit. Then open two follow-up issues and stop:

1. **Refit dedup.** Group refits by the key (cell x, cell y, weight,
   NA pattern) and compute one IF value per key. Step 0.5 (check D)
   measured the gate: on equal weights the within-key spread is exactly 0
   and 300 refits collapse to 42; on continuous weights keys are unique
   and the change is inert. Before implementing, measure the one unproven
   shape: duplicate weights among varied ones. The wt = 1 parity fixtures
   in `test-analysis-corr-latent.R` are the main beneficiary.
2. **Analytic influence function.** The true fix for the 301-fit
   multiplier, and how lavaan solves the same problem. It replaces a
   perturbation approximation, so standard errors would move, and the
   tolerance rule above forbids that here. It needs a spec — Tier 1 work.

Both are out of scope for this PR. Say so in the PR body.

## 4. Verification gates

All four must pass before the PR opens.

| # | Gate | Command |
|---|---|---|
| G1 | Parity — the two corr-latent test files pass, no tolerance edited | `Rscript -e 'testthat::test_local(filter = "corr")'` |
| G2 | Full suite passes | `Rscript -e 'devtools::test()'` |
| G3 | Package check clean — 0 errors, 0 warnings, ≤2 approved notes | `Rscript -e 'devtools::check()'` |
| G4 | Coverage not below the 96.0938% baseline | `NOT_CRAN=true Rscript -e 'covr::package_coverage()'` |

`git diff` on `tests/testthat/` must show no change to any `tolerance =`
argument. Check this by eye before pushing.

Speed targets, against the Step 0 measurements on this machine:

| Target | Baseline | Goal |
|---|---|---|
| 6x7 fit, n = 300 | 29.69 s | ≤ 3.0 s (10x); expected 1.5–2.5 s |
| Ratio against `polycor` | 247x | under 25x |
| The two slow test files | 355.4 s | ≤ 145 s (60% cut) |

The goal comes from the profile, not from hope. Step 1 removes the ~55%
wrapper entry overhead and shrinks the Fortran work (the grid holds 30
finite pairs where the cell loop reads 168) — that alone is ~7x. Step 2
cuts refit evaluations from 16 to 11 and drops one grid call per refit.
Step 3 removes the O(n) setup from every refit. The expected range carries
one estimate, not a measurement: the residual R cost per grid evaluation
(~200 µs assumed). If that residual is heavier, Steps 2–3 gain more
relative weight, not less.

The ratio will not reach 1x. surveycore runs 301 fits and computes a
design-based variance; `polycor` runs one fit and computes none. The
per-fit speeds already match (Step 0), so the remaining gap is the fit
count, which only the Step 5 follow-ups can shrink. Do not treat parity
with `polycor` as the bar.

## 5. Tests to add

`tests/testthat/test-analysis-corr-latent-primitives.R`:

1. `.corr_bivnorm_cdf_grid()` returns the documented value for each of the
   six precedence rules, including `NA` beating `-Inf`.
2. The grid matches an element-by-element `pbivnorm` reference on a finite
   grid, `expect_equal()`, tolerance 1e-12.
3. The shared cell-probability helper returns a matrix that sums to 1 over
   all cells when every threshold is finite.
4. `.corr_count_sparse_cells()` returns the same count as before on a
   fixture with one deliberately tiny cell.
5. `.corr_polychoric_mle(refit = TRUE)` returns a `rho` that is
   `expect_identical()` to the `refit = FALSE` result on the same inputs,
   and returns `n_sparse_cells = NA_integer_`. Same for the polyserial
   probe skip.
6. The delta refit path: `.corr_numerical_influence()` output is
   `expect_identical()` — not tolerance — to a brute-force reference
   (the full-rebuild loop, written as a local helper in the test) on a
   small fixture with lognormal weights. Lognormal, because equal weights
   cannot expose an accumulation-order mistake (check C). The fixture
   includes at least one row with NA on one margin, one with NA on both,
   and one with zero weight.

Keep the existing four `.corr_polychoric_loglik()` tests as they are. They
are the parity guard for this rewrite.

## 6. Risks

| Risk | Handling |
|---|---|
| A rewritten guard changes an edge case silently | Step 1 fixes the precedence order in writing and tests all six rules |
| The `ll` sum order moves a snapshot or a pinned value | Step 0 records the values first; G1 and G2 catch a move |
| The delta path accumulates with `sum()` where the source uses `+=` | Check C measured the divergence (130/300 rows); test 6 pins bit-identity on lognormal weights |
| The delta refit bypasses the MLE's error classes | Membership is invariant under a `1 + 1e-4` weight scale, so PC-4/PC-5 cannot fire in a refit when the full fit passed; the PC-6 rethrow keeps its test |
| The `refit = TRUE` branches lower coverage | Every existing influence and variance test exercises them; tests 5–6 cover the rest |
| Scope creep into the variance restructure | Step 5 hands dedup and the analytic IF to new issues |
| Deleting `.corr_bivnorm_cdf()` breaks a caller | `grep` shows the two loops are the only callers, and no test calls it |

## 7. Commits

One PR against `develop`. Conventional Commits:

- `perf(analysis): evaluate the polychoric CDF grid in one vectorised call`
- `test(analysis): cover the vectorised bivariate-normal grid helper`
- `perf(analysis): skip the probe and sparse-cell count in influence refits`
- `perf(analysis): delta-update thresholds and cell counts across influence refits`
- `test(analysis): pin influence refits bit-identical to the full rebuild`

Squash message:
`perf(analysis): vectorise the polychoric CDF grid and cut influence-refit overhead (#177)`.
