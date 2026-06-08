# Spec — surveywts-calibration

**Status**: DRAFT
**Target version**: X.Y.Z.9000
**PR range**: PR 1–2

---

## Scope

### In
- Documenting and formalizing the `as_caldata()` contract for GREG and raking
  (both Architecture A combined-matrix approach per HOLD-1 resolution)
- Adding and formally specifying the `calibration =` parameter on `as_survey()`
  (already present in working tree — needs validation logic and docs formalized)
- Adding and formally specifying the `calibration =` parameter on
  `as_survey_replicate()` (already present in working tree — needs validation
  logic and docs formalized)
- Validation of `calibration =` inputs in both constructors
- Updating `as_caldata()` roxygen to document the inter-package contract for
  GREG vs raking model matrices
- Documenting that `@calibration` on `survey_replicate` is provenance-only
  (no variance adjustment applied)
- Replacing the raking oracle test (two sequential `survey::calibrate()` calls)
  with a `survey::calibrate(calfun = "raking")` oracle using the combined model
  matrix approach

### Out
- Changes to `.apply_caldata_projection()` (already correct for Architecture A)
- Within-PSU calibration (`stage != 0`) — deferred per JC-6
- GREG-GLM variance — deferred per existing limitation note
- New S7 class changes
- Changes to any analysis functions (`get_means`, `get_totals`, etc.)

---

## Architecture

- **Files touched**:
  - `R/calibration.R` — update `as_caldata()` roxygen to document inter-package
    contract (GREG vs raking `model_matrix` semantics); no code changes needed
  - `R/core-constructors.R` — add/formalize validation for `calibration =`
    parameter in `as_survey()` and `as_survey_replicate()`; update roxygen for
    both
  - `tests/testthat/test-calibration.R` — replace raking oracle test with
    `survey::calibrate(calfun = "raking")` oracle; add constructor validation tests
  - `plans/error-messages.md` — add CAL-15 and CAL-16 rows

- **Functions modified**:
  - `as_caldata(base_weights, g_weights, model_matrix)` — roxygen update only;
    no code changes (existing implementation is already correct)
  - `as_survey(data, ..., calibration = NULL)` — add validation for
    `calibration =`; update roxygen
  - `as_survey_replicate(data, ..., calibration = NULL)` — add validation for
    `calibration =`; update roxygen

- **Functions added**:
  - `.validate_calibration_arg(calibration, nrow_data)` — internal, non-exported.
    Shared validation helper called by both `as_survey()` and
    `as_survey_replicate()`. Lives in `R/calibration.R` (two confirmed call
    sites satisfies the two-call-site rule from `code-style.md`).

- **Class changes**: none

---

## Function contracts

### `as_caldata(base_weights, g_weights, model_matrix)`

- **Signature**: `as_caldata(base_weights, g_weights, model_matrix)`

- **Arguments**:
  - `base_weights` — numeric vector, length n, all strictly positive and
    finite. Base sampling weights (1/π_k) before calibration. Must not contain
    NA, NaN, or Inf.
  - `g_weights` — numeric vector, length n, all strictly positive and finite.
    Calibration g-factors: `calibrated_weight_k / base_weight_k`. A value of
    1.0 for all units means calibration did not change the weights.
  - `model_matrix` — numeric matrix with n rows and at least 1 column. All
    entries must be finite. See "Inter-package contract" section below.

- **Returns**: A named list with exactly four elements:
  - `qr` — class `"qr"`. QR decomposition of
    `sqrt(base_weights) * model_matrix`. Used by the variance engine to project
    the linearized influence function onto the orthogonal complement of the
    calibration column space.
  - `w` — numeric vector, length n. Equal to
    `g_weights * sqrt(base_weights)`. Encodes both the calibration factors and
    the base weight scaling used during projection.
  - `stage` — integer scalar `0L`. Only between-PSU calibration is supported.
    Reserved field: future within-PSU calibration will set stage to the PSU
    level index.
  - `index` — always `NULL`. Reserved for within-PSU calibration: will be a
    logical index vector identifying which rows belong to the PSU being
    calibrated. NULL means all rows are in scope.

- **Errors**:
  - `surveycore_error_caldata_weights_missing` (CAL-1) — `base_weights`
    contains any NA, NaN, or Inf value
  - `surveycore_error_caldata_weights_nonpositive` (CAL-2) — `base_weights`
    contains any non-positive value, or has length 0
  - `surveycore_error_caldata_gweights_missing` (CAL-3) — `g_weights` contains
    any NA, NaN, or Inf value
  - `surveycore_error_caldata_gweights_nonpositive` (CAL-4) — `g_weights`
    contains any non-positive value, or has length 0
  - `surveycore_error_caldata_gweights_length_mismatch` (CAL-5) —
    `length(g_weights) != length(base_weights)`
  - `surveycore_error_caldata_weights_near_zero` (CAL-6) — any element of
    `g_weights * sqrt(base_weights)` falls below `.Machine$double.eps^0.5`
  - `surveycore_error_caldata_dimension_mismatch` (CAL-7) —
    `nrow(model_matrix) != length(base_weights)`
  - `surveycore_error_caldata_empty_model_matrix` (CAL-8) — `model_matrix`
    has 0 columns
  - `surveycore_error_caldata_model_matrix_invalid` (CAL-9) — `model_matrix`
    contains any NA, NaN, or Inf value

- **Warnings**: none

- **Edge cases**:
  - `base_weights` of length 1 (single observation): valid, returns a length-1
    `qr` decomposition with a 1x1 model matrix. No error.
  - `g_weights` all equal to 1.0: valid. The returned `w` equals
    `sqrt(base_weights)` and the projection removes no variance (g-factors of 1
    indicate that calibration applied no weight adjustment but the model matrix
    still spans some columns).
  - Rank-deficient `model_matrix` (e.g., a margin indicator column that is all
    zeros): valid. `qr()` handles this via pivoting; `qr$rank` will be less
    than `ncol(model_matrix)`. Downstream df reduction must use `qr$rank`.
  - `model_matrix` with more columns than rows: valid. `qr()` will have rank
    at most n. The variance engine uses `qr$rank` for df reduction.

- **Inter-package contract — what `surveywts` must pass as `model_matrix`**:

  This section documents the interface that the companion `surveywts` package
  must satisfy when calling `as_caldata()`.

  **Unified code path (D&S 1992 Result 5)**: both GREG and raking calibration
  use the same QR projection code path (`.apply_caldata_projection()`). D&S
  1992 Result 5 establishes that all calibration family members are
  asymptotically equivalent to the GREG, and that eq (3.4) is the recommended
  asymptotic variance estimator for any member (D&S 1992 uses the word
  "recommended", acknowledging that using base weights d_k instead of
  calibrated weights w_k in the normal equations also yields a
  design-consistent estimator). The key difference between calibration types
  is only in the structure of `model_matrix` passed to `as_caldata()`.

  **Note on D-weighted projection**: the QR projection in
  `.apply_caldata_projection()` uses base-weight-scaled (D-weighted) normal
  equations — `qr(sqrt(d) * X)` — rather than calibrated-weight-scaled
  (W-weighted) equations. This is asymptotically equivalent to D&S 1992
  eq (3.4) with an O(n^{-1}) difference, and matches the survey package
  reference implementation exactly (which makes the same deliberate
  simplification).

  **For GREG calibration (post-stratification, regression calibration)**:
  `model_matrix` is the design matrix of the calibration variables in the usual
  `model.matrix()` sense: one column per calibration variable, including an
  intercept column (column of all 1s) if calibrating to totals. This is the
  same matrix used to set up the calibration equations. Example: if calibrating
  to known gender and age totals using continuous auxiliary variables,
  `model_matrix <- model.matrix(~ gender + age, data)`.

  **For raking calibration (iterative proportional fitting)**:
  `model_matrix` is the combined margin indicator matrix — all margin indicator
  matrices column-bound into a single matrix, with Q − 1 columns dropped for
  identifiability (one reference level from each of Q − 1 margins), where Q is
  the number of raking margins. For each margin q, the sum of that margin's
  indicator columns equals the all-ones vector. These Q constraints all target
  the same vector and collapse by transitivity into Q − 1 independent
  dependencies, so Q − 1 columns must be dropped — not one column total.

  Concretely, for a two-way raking on margins A (r levels) and B (c levels):
  - Construct indicator matrix `X_A` (n × r): `X_A[k, j] = 1` if unit k is in
    level `a_j` of margin A.
  - Construct indicator matrix `X_B` (n × c): `X_B[k, j] = 1` if unit k is in
    level `b_j` of margin B.
  - Drop the last column of B (Q − 1 = 1 drop, per D&S&S 1993 "fix v_c = 0"):
    `model_matrix <- cbind(X_A, X_B[, -c])`, resulting in an
    n × (r + c − 1) matrix.
  For a three-way raking on margins A (r levels), B (c levels), C (s levels):
    `model_matrix <- cbind(X_A, X_B[, -c], X_C[, -s])`, resulting in an
    n × (r + c + s − 2) matrix (Q − 1 = 2 drops, one from each of B and C).
  For Q-way raking in general, the combined matrix has `(sum_q n_q - Q + 1)`
  columns, where `n_q` is the number of levels in margin q. The `+1` arises
  because Q − 1 columns are dropped — one reference level from each of Q − 1
  margins (equivalently: keep all columns of one chosen margin; drop the last
  column of every other margin). This is the dimension of the fitted additive
  ANOVA model (D&S&S 1993 Section 7).

  Do NOT add an explicit intercept column to the raking `model_matrix`. The
  combined margin indicator matrix already spans the intercept (the sum of any
  margin's indicator columns is a vector of 1s), so an explicit intercept
  would create additional rank deficiency.

  **Architecture requirement (supersedes prior JC-4 decision)**: for raking
  calibration, `surveywts` MUST provide a SINGLE `as_caldata()` entry
  constructed from the combined model matrix. Passing multiple per-margin
  caldata entries (one entry per raking margin) is NOT supported for raking
  calibration and will produce incorrect variance estimates for non-orthogonal
  margins. This supersedes the prior JC-4 decision that accepted per-margin
  sequential caldata entries. Independent calibration events (e.g., separate
  GREG calibrations applied in sequence) may still use multiple caldata entries,
  one per event.

  **For `survey_replicate` designs**:
  `model_matrix` and `g_weights` document the calibration that was applied to
  produce the calibrated replicate weights. `surveycore` stores the resulting
  caldata at `@calibration` for provenance, but does NOT use it for variance
  correction (the calibrated replicate weights already incorporate the
  calibration adjustment). See `as_survey_replicate()` for details.

  **caldata must be built from the full dataset**: `as_caldata()` must receive
  vectors and matrices with n rows equal to `nrow(data)` of the full survey
  dataset — not a domain subset. When `get_*()` functions compute domain
  estimates, they zero out out-of-domain rows in the influence function before
  calling the projection; the caldata structure always covers all n rows.

  **g-weights rule**: regardless of calibration type, `g_weights` must always
  be the fully-converged final calibration factors: `w_k^{final} / d_k` where
  `w_k^{final}` is the final calibrated weight and `d_k` is the base sampling
  weight. For raking, this means the g-weights from the last IPF iteration,
  not from an intermediate pass.

  **q_k = 1 assumption**: this contract assumes the unit-specific variance
  factor q_k = 1 for all units, which is the standard case for GREG-to-totals
  and raking calibration. D&S 1992 introduces a unit weight q_k that modifies
  both the calibration equations and the variance formula; the survey package
  stores `w = g * sqrt(d) * sqrt(q)` when `variance = lambda` is passed to
  `calibrate()`. If calibration was performed with non-unit q_k (e.g., ratio
  estimation with q_k = 1/x_k), the caller must pre-scale `model_matrix` by
  `diag(sqrt(q_k))` before passing it to `as_caldata()`, and must extract
  g-weights as `calibrated_weight / (base_weight * sqrt(q_k))`. Using the
  standard `g_k = w_k / d_k` formula when q_k ≠ 1 will produce incorrect
  variance estimates.

---

### `as_survey(data, ids, probs, weights, strata, fpc, nest, calibration)`

Only the `calibration =` parameter contract is documented here. All other
parameters are documented in the existing function and are unchanged.

- **Signature**: `as_survey(data, ids = NULL, probs = NULL, weights = NULL, strata = NULL, fpc = NULL, nest = FALSE, calibration = NULL)`

- **`calibration` argument**:
  - Type: `NULL` or a list (possibly empty) where every element is a valid
    caldata object produced by `as_caldata()`.
  - Default: `NULL` (no calibration adjustment applied to variance estimates).
  - When non-`NULL`, validation is performed by `.validate_calibration_arg()`
    (see §Calibration validation helper). This checks list type, per-element
    structure, and `length(cd$w) == nrow(data)`.
  - The value is stored verbatim at `design@calibration`. No further
    transformation occurs in the constructor.
  - Equivalent in effect to constructing the design with `calibration = NULL`
    and then assigning `design@calibration <- list(cd)` after construction.

- **Returns**: A `survey_taylor` object with `@calibration` set to the
  supplied value (or `NULL`).

- **Errors**: see §Calibration validation helper for error classes and trigger
  conditions. Summary: `surveycore_error_calibration_not_list` (CAL-15) when
  `calibration` is non-`NULL` and not a list; `surveycore_error_caldata_invalid_element`
  (CAL-16) when any element fails structure or length checks.

- **Warnings**: none (beyond those already emitted for other arguments).

- **Edge cases**: see §Calibration validation helper for the authoritative
  edge-case list. Additional note:
  - `calibration = list(cd1, cd2)` (multiple entries): stored as a length-2
    list. Both projections are applied sequentially by the variance engine.
    Use multiple entries for independent GREG calibration events; for raking,
    use a single combined-matrix entry per the Architecture requirement above.
  - **Known limitation**: surveycore cannot validate that the base weights in
    `cd$w` were computed from the same weight column as `data`. If the caldata
    was built from different base weights, the calibration projection will be
    silently incorrect. This is surveywts's responsibility to ensure.

---

### `as_survey_replicate(data, weights, repweights, type, ..., calibration)`

Only the `calibration =` parameter contract is documented here. All other
parameters are unchanged.

- **Signature**: `as_survey_replicate(data, weights, repweights, type = ..., scale = NULL, rscales = NULL, fpc = NULL, fpctype = c("fraction", "correction"), mse = TRUE, calibration = NULL)`

- **`calibration` argument**:
  - Type: `NULL` or a list (possibly empty) where every element is a valid
    caldata object produced by `as_caldata()`.
  - Default: `NULL`.
  - Same structure validation as `as_survey()`, performed by
    `.validate_calibration_arg()` (see §Calibration validation helper).
    Validation ensures correct types even for provenance-only storage — this
    is consistent with surveycore's principle of eager validation at system
    boundaries.
  - When non-`NULL`, the value is stored verbatim at `design@calibration` as
    provenance metadata only.

  **Critical behavior distinction from `as_survey()`**: for replicate designs,
  `@calibration` is stored for reproducibility and audit purposes only. The
  replicate variance engine does NOT apply any calibration projection when
  computing variance. The calibration adjustment for replicate designs is
  implemented by supplying already-calibrated replicate weight columns — i.e.,
  each replicate weight column must contain weights that have already been
  re-calibrated within that replicate. The QR projection path
  (`.apply_caldata_projection()`) is never invoked for `survey_replicate`
  objects.

  The expected surveywts workflow for calibrated replicate designs:
  1. surveywts creates calibrated base weights.
  2. surveywts re-calibrates each replicate weight column independently.
  3. The caller passes the re-calibrated replicate columns to
     `as_survey_replicate(repweights = ...)`.
  4. Optionally, the caller passes `calibration = list(as_caldata(...))` to
     record the calibration provenance at `@calibration`.
  5. `get_means()` and other analysis functions compute variance from
     replicate weight differences — which already incorporate the calibration
     correction because the replicate weights were re-calibrated.

- **Returns**: A `survey_replicate` object with `@calibration` set to the
  supplied value (or `NULL`).

- **Errors**: same error classes as `as_survey()` (see §Calibration validation
  helper): `surveycore_error_calibration_not_list` (CAL-15) and
  `surveycore_error_caldata_invalid_element` (CAL-16). Trigger conditions are
  identical.

- **Warnings**: none (beyond those already emitted for other arguments).

- **Edge cases**: same as §Calibration validation helper. Additional note:
  any non-`NULL` value is purely stored, never applied in any replicate
  variance code path. See §Known limitations in the `as_survey()` contract
  for the base-weight consistency caveat — it applies here too.

---

## Calibration validation helper

Both `as_survey()` and `as_survey_replicate()` must call a shared internal
helper `.validate_calibration_arg(calibration, nrow_data)`. This section is
the authoritative description of validation rules, edge cases, and error
classes for the `calibration =` parameter in both constructors.

### Validation steps

1. If `calibration` is `NULL`, return `invisible(TRUE)` immediately (no-op).
2. If `calibration` is a list of length 0 (empty list), return
   `invisible(TRUE)` immediately. An empty list is valid: the variance engine
   applies no projection when `length(@calibration) == 0`.
3. If `calibration` is not a list (i.e., `!is.list(calibration)`), emit
   `surveycore_error_calibration_not_list` (CAL-15).
4. For each element `cd` in `calibration` (index `i`):
   - If `cd` is `NULL` or not a named list, emit
     `surveycore_error_caldata_invalid_element` (CAL-16).
   - The required fields are `qr`, `w`, `stage`, `index`. Check presence
     with `all(c("qr", "w", "stage", "index") %in% names(cd))`. Extra fields
     beyond these four are permitted and ignored (forward-compatible). If any
     required field is absent, emit `surveycore_error_caldata_invalid_element`.
   - If `length(cd$w) != nrow_data`, emit
     `surveycore_error_caldata_invalid_element`.
5. Return `invisible(TRUE)` on success.

### Error classes

- `surveycore_error_calibration_not_list` (CAL-15) — `calibration` is
  non-`NULL` and not a list (e.g., a bare caldata element, a vector, a
  data frame).
- `surveycore_error_caldata_invalid_element` (CAL-16, same class as CAL-12)
  — any element of `calibration` is `NULL`, not a named list, missing a
  required field, or has `length(cd$w) != nrow_data`. The error message
  should identify the element index `i` and the failing check.

### Edge cases (authoritative)

- `calibration = NULL`: no validation performed; `@calibration` is `NULL`.
- `calibration = list()` (empty list): valid; no projection applied.
- `calibration = list(cd)` where `length(cd$w) != nrow(data)`: triggers
  `surveycore_error_caldata_invalid_element`.
- `calibration = list(cd1, cd2)` (multiple entries): valid; stored as
  length-2 list.
- `calibration` is a bare caldata list (user passed `as_caldata(...)` instead
  of `list(as_caldata(...))`): triggers `surveycore_error_calibration_not_list`.
- `calibration = list(cd)` where `cd` has extra fields beyond `qr`, `w`,
  `stage`, `index`: valid; extra fields are ignored.
- `calibration = list(valid_cd, NULL)`: triggers
  `surveycore_error_caldata_invalid_element` for the NULL element.

### Placement

This helper belongs in `R/calibration.R` — it is semantically a calibration
concern, and both call sites (`as_survey()` and `as_survey_replicate()` in
`R/core-constructors.R`) are confirmed. Placement in `R/calibration.R` is a
defensible exception to the same-file inline rule because calibration helpers
are grouped there for cohesion.

---

## Raking oracle — required contract change

The prior raking oracle used two sequential `survey::calibrate()` calls as a
proxy for raking. Per the HOLD-1 resolution (Architecture A), the correct
oracle for raking-adjusted variance is `survey::calibrate(calfun = "raking")`.

`survey::rake()` uses an iterative cyclic projection approximation for
variance, while `survey::calibrate(calfun = "raking")` uses the exact QR
projection implementing D&S 1992 eq (3.4). Surveycore's
`.apply_caldata_projection()` implements the same QR path as
`survey::calibrate()`, so numerical tests must compare against
`survey::calibrate(calfun = "raking")`, not `survey::rake()`. (Both functions
produce the same calibrated weights via IPF; the difference is in the variance
formula only.)

The raking numerical accuracy requirement is:
1. The oracle is `survey::calibrate(calfun = "raking")` with the combined
   indicator matrix (not `survey::calibrate()` twice, not `survey::rake()`).
2. The combined model matrix is built by column-binding all margin indicator
   matrices with Q − 1 columns dropped for identifiability (one reference
   level from each of Q − 1 margins, per D&S&S 1993 "fix v_c = 0").
3. g-weights are computed as final converged IPF weights / base weights.
4. A single `as_caldata()` element is constructed from the combined model
   matrix and g-weights.
5. That single caldata element is stored at `design@calibration`.
6. `get_means()` SE must match the `survey::calibrate(calfun = "raking")`
   oracle SE to tolerance 1e-8.

The prior two-sequential-calibrate numerical test is superseded by this
requirement and should not be preserved.

---

## Quality gates

- `design@calibration` is either `NULL` or a list where every element passes
  the four-field structure check (`qr`, `w`, `stage`, `index`).
- For `survey_taylor`: when `design@calibration` is non-`NULL` and
  `length(design@calibration) > 0`, the variance engine calls
  `.apply_caldata_projection()` before constructing the Horvitz-Thompson
  variance estimate. The existing `.apply_caldata_projection()` implementation
  is already correct and requires no code modifications.
- **FPC order of operations**: the linearized influence function is first
  projected by `.apply_caldata_projection()` (producing calibration-adjusted
  residuals), then passed to `.svy_recvar()` where FPC adjustments are
  incorporated via `.svy_onestage()`. This is consistent with D&S 1992
  eq (3.4), where calibrated residuals e_k appear inside the Δ_{kl} double-sum
  with FPC embedded in Δ_{kl}.
- For `survey_replicate`: `@calibration` is never read by any variance path.
  The functions `.replicate_mean()` and `.replicate_total()` must NOT call
  `.maybe_apply_calibration()` or `.apply_caldata_projection()`. Setting or
  unsetting `@calibration` on a `survey_replicate` object must not change the
  output of any `get_*()` function.
- For any design: `length(caldata$w) == nrow(design@data)` is enforced at
  construction time.
- The `calibration =` parameter in `as_survey()` is idempotent with the
  equivalent post-construction assignment `design@calibration <- list(cd)`.
- df reduction equals sum of `cd$qr$rank` across all caldata entries
  (`cd$qr$rank`, not `ncol(model_matrix)`, to correctly handle rank-deficient
  model matrices such as those with empty margin cells).
- When df reduction would produce `df_final <= 0`, emit
  `surveycore_warning_zero_df_after_calibration` and clamp to
  `max(1L, df_final)`.
- The calibration adjustment applies uniformly to domain estimates: `get_*(...,
  group = ...)` computations pass the domain-masked influence function (with
  out-of-domain rows zeroed) to `.apply_caldata_projection()`. The caldata QR
  decomposition is built from the full dataset, so domain-specific rank
  deficiency does not affect the projection (which operates on the full-dataset
  column space).

---

## Known limitations

- **Weight column consistency**: surveycore cannot validate that the base
  weights in `cd$w` (from `as_caldata()`) were computed from the same weight
  column as the design's `@variables$weights`. If the caldata was built from
  a different weight column, the calibration projection is silently incorrect.
  This is surveywts's responsibility.
- **update_design() stale calibration**: if `update_design()` changes the
  weight column on a calibrated design, `@calibration` becomes stale. The
  existing `update_design()` implementation emits
  `surveycore_warning_weights_changed_on_calibrated_design` in this case.
  It is the caller's responsibility to update or clear `@calibration` via
  `design@calibration <- NULL` after re-weighting.

---

## Pipeline split

**recommended** — This change touches two constructor functions (with new
validation logic), one documentation-only function, and one test file with an
oracle replacement. The constructor validation and the oracle test replacement
are logically independent and suitable for two PRs.

PR 1: Constructor validation (`calibration =` parameter validation in
`as_survey()` and `as_survey_replicate()`; new `.validate_calibration_arg()`
helper; `as_caldata()` roxygen update).

PR 2: Oracle test replacement (raking oracle replaced with
`survey::calibrate(calfun = "raking")` combined-matrix approach).
