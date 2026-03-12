# surveycore Audit Remediation Plan

**Status:** Draft — not yet approved
**Source:** Post-Phase-2 adversarial audit (2026-03-12)
**Audit findings:** Summarized in session; full catalog in conversation history

---

## Overview

This plan addresses the 10 prioritized findings from the post-Phase-2 adversarial
audit. Items are grouped into four waves ordered by dependency: refactoring first
(to clean up the soil before planting), then critical correctness bugs, then major
correctness issues, then minor bugs. Two major new features (GREG calibration
variance and multi-stage cluster variance) require their own specs before
implementation and are called out separately.

Items that are **not** in scope for this plan (require full spec workflow first):
- GREG/calibration variance (`survey_nonprob` complete redesign)
- Bootstrap with recalibration
- Yates-Grundy WOR variance
- Three-phase, rotating panel, multi-frame designs

---

## PR Map

### Wave 1 — Refactoring (no behavior change)
- [ ] PR 1: `refactor/extract-fpc-helper` — deduplicate FPC conversion logic (7+ sites)
- [ ] PR 2: `refactor/extract-psu-strata-builder` — deduplicate PSU/strata matrix builder (6+ sites)

### Wave 2 — Critical correctness
- [ ] PR 3: `fix/multistage-cluster-variance` — un-truncate multi-stage variance to use all PSU levels (**requires spec first — see below**)

### Wave 3 — Major correctness
- [ ] PR 4: `fix/srs-weighted-variance` — replace unweighted `s²` with weighted variance estimator
- [ ] PR 5: `fix/twophase-phase1-type-restriction` — allow replicate and SRS phase-1 in `as_survey_twophase()`
- [ ] PR 6: `fix/nonprob-dispatch-consistency` — unify `survey_nonprob` routing in `get_freqs()` vs `get_means()`

### Wave 4 — Minor bugs
- [ ] PR 7: `fix/glm-weights-na-contiguous` — fix `@weights` non-contiguous NA indexing in `glm.R:999`
- [x] PR 8: `fix/quantiles-deff` — implement or document `se_srs` for quantile DEFF
- [x] PR 9: `fix/as-survey-srs-warning` — reconsider warning behavior for weight-only `as_survey()` dispatch

---

## PR 1: Extract shared FPC helper

**Branch:** `refactor/extract-fpc-helper`
**Depends on:** none
**Tier:** 3 (Direct — behavior unchanged, approach clear)

**Problem:** The FPC conversion block — `if (any(fpc_vals > 1)) { N <- mean(fpc_col); f <- n/N } else { f <- mean(fpc_col) }` — is copy-pasted in at least 7 places:
- `R/variance-taylor.R` ~line 243
- `R/analysis-means-helpers.R` ~line 103
- `R/analysis-freqs-helpers.R` ~line 112
- `R/glm.R` ~line 261
- `R/variance-srs.R` (two places)
- `R/variance-twophase.R`

**Fix:** Extract a single internal helper `.resolve_fpc()` in `R/utils.R`:

```r
# Returns list(f = sampling_fraction, N_hat = population_size_estimate)
# fpc_col: numeric vector of raw FPC values (either population sizes or fractions)
# n:       sample size for this stratum/domain
# w_sum:   sum of weights (used as N_hat fallback when fpc_type != "population")
.resolve_fpc <- function(fpc_col, n, w_sum, fpc_type) { ... }
```

**Files changed:**
- `R/utils.R` — add `.resolve_fpc()`
- `R/variance-taylor.R` — replace inline block with `.resolve_fpc()` call
- `R/analysis-means-helpers.R` — replace inline block
- `R/analysis-freqs-helpers.R` — replace inline block
- `R/glm.R` — replace inline block
- `R/variance-srs.R` — replace inline blocks
- `R/variance-twophase.R` — replace inline block
- `tests/testthat/test-utils.R` — add direct unit tests for `.resolve_fpc()`

**Acceptance criteria:**
- [ ] All existing tests pass unchanged (pure refactor — no behavior change)
- [ ] `.resolve_fpc()` has direct tests covering: population FPC type, fraction FPC type, NULL FPC
- [ ] `devtools::check()` 0/0/≤2
- [ ] `devtools::document()` run

---

## PR 2: Extract shared PSU/strata matrix builder

**Branch:** `refactor/extract-psu-strata-builder`
**Depends on:** PR 1 (can be done in parallel, but simpler to sequence)
**Tier:** 3 (Direct — behavior unchanged, approach clear)

**Problem:** The 30-line block that builds `clusters_mat`, `strata_mat`,
`sampsize_mat`, and `popsize_mat` for `.svy_recvar()` is duplicated in:
- `R/variance-taylor.R` (`.taylor_build_inputs()`)
- `R/analysis-means-helpers.R` (`.taylor_mean_cell()`)
- `R/analysis-freqs-helpers.R` (`.taylor_freq_cell()`)
- `R/glm.R` (Taylor variance path, ~line 233-281)
- `R/variance-srs.R` (`.vcov_pair_srs()`)
- Possibly `R/variance-twophase.R`

**Fix:** Extract `.build_recvar_inputs()` in `R/utils.R`:

```r
# Builds the cluster/strata/FPC matrix inputs required by .svy_recvar().
# Returns list(clusters_mat, strata_mat, fpcs, lonely.psu)
.build_recvar_inputs <- function(design, keep = NULL) { ... }
```

**Files changed:**
- `R/utils.R` — add `.build_recvar_inputs()`
- All 5+ call sites above — replace inline blocks
- `tests/testthat/test-utils.R` — add direct unit tests

**Acceptance criteria:**
- [ ] All existing tests pass unchanged
- [ ] `.build_recvar_inputs()` has tests covering: Taylor design, SRS design, with FPC, without FPC, with `keep` subset, without
- [ ] `devtools::check()` 0/0/≤2

---

## PR 3: Fix multi-stage cluster variance truncation

**Branch:** `fix/multistage-cluster-variance`
**Depends on:** PRs 1 and 2
**Tier:** 1 — **requires spec before implementation**

**Problem (CRITICAL):** `variance-taylor.R` calls `data[[vars$ids[[1L]]]]` — only the
first PSU level. The recursive `# nocov start` block inside `.svy_multistage()` is
dead code. Two-stage cluster designs silently produce first-stage-only variance
estimates, which underestimates variance for designs where subsampling occurs within
PSUs. `core-constructors.R` correctly stores all `ids` column names (e.g., `c("psu", "ssu")`),
but `.taylor_build_inputs()` discards all but the first.

**What needs to be specified before coding:**
- What is the correct recursive multi-stage formula? (Cochran 1977 §10.4, Lumley 2010 §3.4)
- Does `survey::svydesign(ids = ~psu + ssu)` produce the benchmark? Yes.
- How does `.svy_multistage()` differ from `.svy_onestage()`? The former recurses; the
  latter handles a single stage.
- What oracle test dataset demonstrates multi-stage bias vs correctness?

**Proposed fix (high-level):**
1. Remove `# nocov start / # nocov end` guards from `.svy_multistage()`
2. In `.taylor_build_inputs()`, pass all `ids` columns, not just `[[1L]]`
3. Wire the recursive path correctly through `.svy_recvar()` → `.svy_multistage()`
4. Add oracle tests against `survey::svydesign(ids = ~psu + ssu, ...)`

**Action required before this PR can proceed:**
Write a spec section in this file (below) or a dedicated `plans/spec-multistage-variance.md`
covering: correct formula, which existing vendored functions to activate, and oracle test design.

**Acceptance criteria:**
- [ ] Spec approved
- [ ] Oracle test: `get_means()` on a two-stage design matches `survey::svymean()` at tolerance 1e-8 (SE)
- [ ] Old single-stage oracle tests still pass
- [ ] `.svy_multistage()` no longer has `# nocov` guards
- [ ] `devtools::check()` 0/0/≤2

---

## PR 4: Fix SRS weighted variance

**Branch:** `fix/srs-weighted-variance`
**Depends on:** none (can start any time after PRs 1-2 for cleanliness)
**Tier:** 2 (Plan only — behavior change, approach needs deciding)

**Problem:** `variance-srs.R:79` uses the unweighted sample variance:
```r
s2 <- sum((y - ybar)^2, na.rm = na.rm) / (n_used - 1L)
```
This is only correct when all weights are equal (true SRS). For non-proportional
weights the comment acknowledges this is approximate ("accommodates this
approximation"). The weighted estimator should be:
```r
s2_w <- sum(w * (y - ybar)^2) / (sum(w) - 1)  # or / W_d depending on convention
```

**Decision needed:** Which weighted variance formula matches `survey::svydesign(ids=~1, weights=~wt)`?
The `survey` package uses the Horvitz-Thompson style via `.svy_recvar()` for SRS designs
with non-constant weights. The question is whether `survey_srs` should continue to use
the closed-form SRS formula (faster, less general) or delegate to the Taylor engine
when weights are non-constant.

**Proposed approach:**
- If weights are approximately proportional (all within ε of `mean(w)`), use the
  classical formula — it's exact for SRS and fast.
- If weights are detectably non-proportional, either warn and use `.svy_recvar()`
  or always use `.svy_recvar()` and retire the closed-form path.

**Files changed:**
- `R/variance-srs.R` — `.srs_mean()`, `.srs_total()`
- `tests/testthat/test-variance-srs.R` — update oracle tests at tolerance 1e-8

**Acceptance criteria:**
- [ ] Oracle test with non-proportional weights matches `survey::svymean()` at 1e-8 (SE)
- [ ] Oracle test with proportional weights unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## PR 5: Fix two-phase phase-1 type restriction

**Branch:** `fix/twophase-phase1-type-restriction`
**Depends on:** none
**Tier:** 3 (Direct — behavior change is clear, approach is clear)

**Problem:** `core-constructors.R:858` hard-rejects phase-1 designs that are not
`survey_taylor`:
```r
if (!S7::S7_inherits(phase1, survey_taylor)) {
  cli::cli_abort(..., class = "surveycore_error_twophase_phase1_not_taylor")
}
```
Valid use cases include `survey_srs` phase-1 (simple random sampling of phase-1 units)
and `survey_replicate` phase-1. Lumley (2010) describes two-phase designs where the
phase-1 frame is an SRS or a replicate design.

**Fix:**
- Accept `survey_srs`, `survey_taylor`, and `survey_replicate` as valid phase-1 types
- Route each to the appropriate variance computation in `variance-twophase.R`
- Add tests for `survey_srs` and `survey_replicate` phase-1 designs

**Files changed:**
- `R/core-constructors.R` — relax the phase-1 type check
- `R/variance-twophase.R` — add dispatch for non-taylor phase-1
- `plans/error-messages.md` — update error class description if needed
- `tests/testthat/test-constructors.R` — update error test snapshot
- `tests/testthat/test-variance-twophase.R` — add new design type tests

**Acceptance criteria:**
- [ ] `as_survey_twophase(phase1 = srs_design, ...)` no longer errors
- [ ] Variance estimates for SRS phase-1 match `survey` package oracle at 1e-8
- [ ] Old `survey_taylor` phase-1 path unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## PR 6: Fix `survey_nonprob` dispatch consistency

**Branch:** `fix/nonprob-dispatch-consistency`
**Depends on:** none
**Tier:** 3 (Direct — the inconsistency is clear, pick one and apply it)

**Problem:** `survey_nonprob` objects are routed differently depending on which
analysis function is called:
- `get_freqs()` → `.taylor_freq_cell()` (Taylor linearization)
- `get_means()` → `.calibrated_mean_cell()` (HT/calibration formula)

Neither is clearly "correct" for a design-less nonprob object, but they must be
consistent. Both functions should use the same variance approach.

**Decision:** Use `.calibrated_mean_cell()` / the HT formula for `get_freqs()` as
well, since it is the formula matched to the `survey_nonprob` class contract. Update
`get_freqs()` dispatcher.

**Files changed:**
- `R/analysis-freqs-helpers.R` — change nonprob dispatch in `.freq_cell()` to
  route to `.calibrated_freq_cell()` (or equivalent)
- `tests/testthat/test-analysis-freqs.R` — verify variance matches `get_means()` approach

**Acceptance criteria:**
- [ ] `get_freqs()` and `get_means()` use the same variance method for `survey_nonprob`
- [ ] Oracle test: SE from `get_freqs(d_nonprob, x)` matches expected value at 1e-8
- [ ] `devtools::check()` 0/0/≤2

---

## PR 7: Fix GLM `@weights` non-contiguous NA bug

**Branch:** `fix/glm-weights-na-contiguous`
**Depends on:** none
**Tier:** 3 (Direct — bug is well-defined)

**Problem:** `R/glm.R:999`:
```r
weights = as.numeric(wt_fit[seq_len(length(stats::fitted(fit)))])
```
`seq_len(length(fitted(fit)))` is always `1:n_complete` regardless of where NAs
appear in the original data. When NAs are non-contiguous (e.g., rows 1, 3, 5 are
non-NA), this takes the first `n_complete` rows of `wt_fit` instead of the rows
actually used. The correct indexing is the non-NA row positions.

**Fix:**
```r
# Track non-NA rows before fitting
na_rows  <- which(!is.na(y_vec) & !is.na(... all x cols ...))
wt_fit   <- w[na_rows]
```

**Why tests didn't catch this:** `make_survey_data()` produces complete data — no NAs
in `y1`/`y2`/`y3`. The one test that injects NAs uses `na.action = na.fail`, which
aborts before reaching line 1000. No existing test inspects `fit@weights` directly.

**Files changed:**
- `R/glm.R` — fix weight indexing around line 1000; replace `wt_fit[seq_len(...)]`
  with `wt_fit[-na_idx]` (using the `na_idx` already computed at line 968)
- `tests/testthat/test-glm.R` — add test with non-contiguous NAs (e.g., rows 3, 7, 15)
  using `na.action = na.omit`; assert `length(fit@weights) == n_complete` and that
  weights correspond to the correct non-NA rows

**Acceptance criteria:**
- [ ] New test: non-contiguous NAs in response with `na.action = na.omit` produces
  correct `fit@weights` (length == n_complete, values from correct rows)
- [ ] New test: `survey_glm()` with NAs produces same coefficients as fitting on
  the NA-removed data directly
- [ ] Existing GLM tests unchanged
- [ ] `devtools::check()` 0/0/≤2

---

## PR 8: Quantiles DEFF — document or implement

**Branch:** `fix/quantiles-deff`
**Depends on:** none
**Tier:** 3 (Direct — either document the limitation or implement)

**Problem:** `analysis-quantiles-helpers.R:213` hardcodes `se_srs = NA_real_`, making
DEFF always `NA` for quantile estimates. For means and totals, DEFF = Var(complex) / Var(SRS)
is a useful diagnostic. For quantiles the SRS SE can be approximated via the Woodruff
formula applied under SRS assumptions.

**Proposed approach (simplest first):** Document the limitation explicitly in the
`get_quantiles()` roxygen `@return` and add a note in the output tibble. If the
quantile SRS SE approximation is straightforward (use the normal quantile density
approximation), implement it. If not, document `deff = NA` as intentional with a
`# TODO` and a reference.

**Files changed:**
- `R/analysis-quantiles-helpers.R` — either implement `se_srs` or add documentation comment
- `R/analysis-quantiles.R` — update `@return` roxygen if documenting as limitation
- `man/get_quantiles.Rd` — regenerated

**Acceptance criteria:**
- [ ] `deff` column behavior is documented (either works or clearly noted as `NA` by design)
- [ ] No regression in existing quantile tests
- [ ] `devtools::check()` 0/0/≤2

---

## PR 9: Reconsider `as_survey()` SRS warning

**Branch:** `fix/as-survey-srs-warning`
**Depends on:** none
**Tier:** 3 (Direct — policy decision, then one-line change)

**Problem:** When `ids` and `strata` are both `NULL`, `as_survey()` emits a warning
and dispatches to `as_survey_srs()`. The warning is surprising for users who
intentionally have a weight-only design and know it's an SRS. The warning text is
also vague.

**Decision needed:** Should weight-only designs dispatch to `survey_srs` silently
(with a message, not a warning), only warn when weights are non-constant, or always
warn? The current behavior penalizes users with simple legitimate designs.

**Proposed fix:** Downgrade from `cli_warn()` to `cli_inform()` (or suppress entirely
for weight-only designs with constant weights). Update class=.

**Files changed:**
- `R/core-constructors.R` — change `cli_warn()` to `cli_inform()` or remove
- `plans/error-messages.md` — update or remove the warning class entry
- `tests/testthat/test-constructors.R` — update test to use `expect_message()` or remove

**Acceptance criteria:**
- [ ] No unexpected warning for users with intentional weight-only designs
- [ ] `devtools::check()` 0/0/≤2

---

## Out of scope — requires full spec workflow before any implementation

These findings from the audit require new specs (Tier 1) before any code is written.
They are tracked here as reminders but have no PRs assigned yet.

| Finding | Why spec-first |
|---------|----------------|
| GREG/calibration variance | `survey_nonprob` is a skeleton; full calibration design requires new class properties, new `as_survey_calibrated()` constructor, and Deville-Särndal residual linearization — a new major feature |
| Bootstrap with recalibration | Requires changes to how replicate weights are generated and applied to calibrated estimates — new estimation path |
| Yates-Grundy / PPSWOR variance | PPSWOR designs currently silently fall back to the with-replacement (SYG) approximation. Exact Yates-Grundy requires storing joint inclusion probabilities π_ij — a new class property, new constructor argument (analogous to `survey::svydesign(pps=)`), and new variance formula |
| Multi-frame / dual-frame designs | No existing class structure; requires new S7 class |

---

## Implementation order summary

```
PRs 1–2  (refactor, parallelizable)
    ↓
PR 3     (critical — spec required first; block here until spec written)
    ↓
PRs 4–6  (major correctness — parallelizable after PRs 1–2)
    ↓
PRs 7–9  (minor bugs — any order)
```

PRs 4, 5, 6, 7, 8, 9 are all independent of each other and can be parallelized
once PRs 1–2 land.
