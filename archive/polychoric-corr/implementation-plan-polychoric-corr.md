# Implementation plan — polychoric-corr

**Status**: PLAN_READY
**Target version**: 0.6.x.9000 → 0.7.0
**Spec**: `spec.md` (SPEC_READY)
**Test-spec**: `test-spec.md`

---

## Sequencing

PRs 1, 2, and 3 are **strictly sequential** because:

- PRs 1 and 2 both write to `R/analysis-corr-latent.R` (created in PR 1, extended in PR 2).
- PR 3 writes to `R/analysis-corr.R` and depends on both the estimator primitives (PR 1) and the variance helpers (PR 2) being available.
- PR 1 owns the `DESCRIPTION` edit (adds `pbivnorm` Import) because PR 1 is the first PR that calls `pbivnorm::pbivnorm()`.

There is no concurrent-PR file overlap because no two PRs run concurrently.

---

## PR map

### PR 1: `feature/polychoric-corr-estimator-primitives`

- [x] Merged in #107 (`0a7197f`) on 2026-04-24.

**One-line goal**: Add internal MLE primitives (threshold estimation, polychoric / polyserial log-likelihoods, MLEs, ordinal detection, polyserial canonicalization) in a new file, with unit tests against the `polycor` oracle. No user-facing API change.

**Error / warning classes owned by this PR**: PC-1, PC-2, PC-3, PC-4, PC-5, PC-6, PC-10, PC-11, PC-13 (all emission sites that live inside the primitives — i.e. threshold estimation, canonicalization, and MLE). The dispatcher-layer re-raises in PR 3 reuse these same classes from this PR's error table.

**Tasks** (TDD sub-steps explicit)

1. Write failing test: `.corr_detect_ordinal()` classifies an `ordered` vector as `"ordered"`.
2. Write failing test: `.corr_detect_ordinal()` classifies an unordered `factor` as `"factor"`.
3. Write failing test: `.corr_detect_ordinal()` classifies `is.integer` with 3 distinct values as `"integer_ordinal"` (default cutoff 10).
4. Write failing test: `.corr_detect_ordinal()` classifies `is.integer` with 50 distinct values as `"ambiguous"`.
5. Write failing test: `.corr_detect_ordinal()` classifies `is.double` non-integer-valued as `"continuous"`.
6. Write failing test: `.corr_detect_ordinal()` classifies a character vector as `"ambiguous"`.
7. Write failing test: `.corr_detect_ordinal()` classifies a logical vector as `"ambiguous"`.
8. Implement `.corr_detect_ordinal()` in `R/analysis-corr-latent.R`.
9. Verify tests 1–7 pass.
10. Write failing test: `.corr_canonicalize_polyserial()` returns `list(ordinal_name, continuous_name)` with correct role assignment when given one ordered factor and one numeric.
11. Write failing test: `.corr_canonicalize_polyserial()` raises `surveycore_error_polyserial_requires_mixed_types` (PC-2) for two ordered factors, with dual pattern (`class=` + snapshot).
12. Write failing test: `.corr_canonicalize_polyserial()` raises `surveycore_error_polyserial_canonicalization_ambiguous` (PC-3) for one high-cardinality integer + one ordered factor, dual pattern.
13. Write failing test: `.corr_canonicalize_polyserial()` raises PC-3 naming both columns when both sides are ambiguous.
14. Implement `.corr_canonicalize_polyserial()` in `R/analysis-corr-latent.R`.
15. Verify tests 10–13 pass.
16. Write failing test: `.corr_estimate_thresholds()` returns `qnorm(cumsum(w_k)/sum(w_k))` for `k = 1..K-1` on a 4-level weighted ordinal.
17. Write failing test: `.corr_estimate_thresholds()` drops a zero-weight interior level and reports it in `dropped_levels`.
18. Write failing test: `.corr_estimate_thresholds()` raises `surveycore_error_polychoric_single_level_ordinal` (PC-4) when only one level has positive weight, dual pattern.
19. Write failing test: `.corr_estimate_thresholds()` honors `active_domain` (rows with domain = 0 contribute weight 0).
20. Implement `.corr_estimate_thresholds()` in `R/analysis-corr-latent.R`.
21. Verify tests 16–19 pass.
22. Write failing test: `.corr_weighted_standardize()` returns `mean_w = Σ w_i x_i / Σ w_i` and population `sd_w` (Cox 1974, not sample SD).
23. Write failing test: `.corr_weighted_standardize()` returns `z[i] = NA_real_` for zero-weight rows.
24. Implement `.corr_weighted_standardize()`.
25. Verify tests 22–23 pass.
26. Write failing test: `.corr_polychoric_loglik()` at known `ρ, θ_x, θ_y` matches a hand-computed value within `1e-8`.
27. Write failing test: `.corr_polychoric_loglik()` sets `any_floor_active = TRUE` when a cell probability is pinned to `1e-300`.
28. Write failing test: `.corr_polychoric_loglik()` handles θ_1 ≡ −∞ and θ_{K+1} ≡ +∞ sentinels.
29. Add `pbivnorm (>= 0.6.0)` to `DESCRIPTION` under `Imports:` (declared before first call site, so intermediate-state `R CMD check` / `devtools::test()` runs remain clean).
30. Implement `.corr_polychoric_loglik()` using `pbivnorm::pbivnorm`.
31. Verify tests 26–28 pass.
32. Write failing test: `.corr_polyserial_loglik()` at known `ρ, θ, z` matches a hand-computed value within `1e-8`.
33. Implement `.corr_polyserial_loglik()` (objective drops the ρ-independent `φ(z)` factor).
34. Verify test 32 passes.
35. Write failing test: `.corr_polychoric_mle()` on a 3×3 equal-weight ordinalized input matches `polycor::polychor()` within `1e-6`.
36. Write failing test: `.corr_polychoric_mle()` on a 4×5 equal-weight input matches oracle within `1e-6`.
37. Write failing test: `.corr_polychoric_mle()` on a 2×2 equal-weight input matches oracle within `1e-6`.
38. Write failing test: `.corr_polychoric_mle()` raises `surveycore_error_polychoric_insufficient_cells` (PC-5) when `n_cells_obs < 4`, dual pattern.
39. Write failing test: `.corr_polychoric_mle()` raises `surveycore_error_polychoric_optim_failed` (PC-6) on a degenerate all-in-one-cell input, dual pattern.
40. Write failing test: `.corr_polychoric_mle()` returns `converged = TRUE` and `rho ∈ (-1 + ε, 1 − ε)` for every well-formed case.
41. Write failing test: `.corr_polychoric_mle()` surfaces `any_floor_active` via `n_sparse_cells > 0` on a sparse-cell setup (used later to emit PC-11).
42. Implement `.corr_polychoric_mle()` using `stats::optimize()` on `(-1 + 1e-6, 1 - 1e-6)`.
43. Verify tests 35–41 pass.
44. Write failing test: `.corr_polyserial_mle()` on a 3-level ordinal + continuous input (equal weights) matches `polycor::polyserial()` within `1e-6`.
45. Write failing test: `.corr_polyserial_mle()` on a 5-level input matches oracle within `1e-6`.
46. Write failing test: `.corr_polyserial_mle()` on a 2-level input matches oracle within `1e-6` (biserial reduction).
47. Write failing test: `.corr_polyserial_mle()` raises PC-4 when the ordinal side has < 2 levels.
48. Implement `.corr_polyserial_mle()`.
49. Verify tests 44–47 pass.
50. Run `devtools::document()` and confirm no unexpected NAMESPACE diff (no new exports from this PR).
51. Run `devtools::test()` locally: all new tests pass; pre-existing tests unchanged.
52. Run `devtools::check()` locally: 0 errors, 0 warnings, ≤ 2 notes.

**Acceptance criteria**

- All tests in `tests/testthat/test-analysis-corr-latent-primitives.R` pass.
- `.corr_polychoric_mle()` on equal weights agrees with `polycor::polychor()` to `1e-6` on 3×3, 4×5, and 2×2 fixtures.
- `.corr_polyserial_mle()` on equal weights agrees with `polycor::polyserial()` to `1e-6` on 3-, 5-, and 2-level ordinal fixtures.
- PC-1 is NOT emitted by this PR's code (PC-1 is a dispatcher-layer error; the primitives return classification strings and let the caller decide). PC-2, PC-3, PC-4, PC-5, PC-6 are each emitted by the expected helper and each has a dual-pattern test.
- No user-visible behavior change when calling `get_corr()` (the file `R/analysis-corr.R` is untouched).
- `DESCRIPTION` Imports list contains `pbivnorm (>= 0.6.0)`.
- Coverage of `R/analysis-corr-latent.R` ≥ 98 %.

**Files touched** (write surface)

- `R/analysis-corr-latent.R` — created
- `tests/testthat/test-analysis-corr-latent-primitives.R` — created
- `tests/testthat/_snaps/analysis-corr-latent-primitives/` — created (snapshots for PC-2, PC-3, PC-4, PC-5, PC-6)
- `DESCRIPTION` — modified (add `pbivnorm (>= 0.6.0)` to Imports)
- `NAMESPACE` — regenerated by `devtools::document()` (no new exports expected)

**Pipeline split**: `recommended`

---

### PR 2: `feature/polychoric-corr-variance-paths`

- [x] Merged in #108 (`cf1d2a3`) on 2026-04-24.

**One-line goal**: Add the design-aware variance paths — numerical-influence-function Taylor variance and per-replicate loop — plus the pair-level dispatcher that composes primitives + variance + CI. Still no user-facing API change.

**Error / warning classes owned by this PR**: PC-7 (design unsupported — dispatcher level), PC-8 (replicate convergence failure), PC-9 (boundary ρ̂), PC-12 (replicate partial convergence), PC-14 (Taylor boundary wide CI). Also the dispatcher-level re-raises of PC-1, PC-2, PC-3, PC-4, PC-5, PC-6, PC-10, PC-11, PC-13 (all propagated from PR 1's helpers, with dispatcher-level integration tests).

**Dependencies**: PR 1 merged.

**Tasks** (TDD sub-steps explicit)

1. Write failing test: `.corr_detect_boundary_rho(0.5)` returns `FALSE`; `.corr_detect_boundary_rho(1 - 1e-7)` returns `TRUE`; `.corr_detect_boundary_rho(-1 + 1e-7)` returns `TRUE`.
2. Implement `.corr_detect_boundary_rho()` in `R/analysis-corr-latent.R`.
3. Verify test 1 passes.
4. Write failing test: `.corr_numerical_influence()` on a small `survey_taylor` + polychoric case returns a numeric vector of length `sum(active_domain)`.
5. Write failing test: `.corr_numerical_influence()` on a polyserial case returns correct length; `vec_b` standardization is recomputed per perturbation.
6. Write failing test: `.corr_numerical_influence()` propagates `surveycore_error_polychoric_optim_failed` (PC-6) if any inner MLE fails.
7. Write failing test: `.corr_numerical_influence()` under equal weights produces IFs whose sum (sample-mean surrogate) approximates zero within a loose tolerance (sanity check — first-moment centering).
8. Implement `.corr_numerical_influence()` with the per-respondent perturbation loop and threshold-caching where possible.
9. Verify tests 4–7 pass.
10. Write failing test: `.corr_taylor_variance_latent()` on a synthetic `survey_taylor` + known IF vector returns `var_z > 0` and `var_z_srs > 0`.
11. Write failing test: `.corr_taylor_variance_latent()` reuses the existing `.vcov_pair_taylor()` inner HT/Hájek path (assert via result equality against a direct call with matching IF).
12. Write failing test: `.corr_taylor_variance_latent()` with unit weights in `var_z_srs` does NOT re-fit the MLE (assert no change to `rho_hat_full` threshold bookkeeping — via a counter / spy helper).
13. Implement `.corr_taylor_variance_latent()` wiring into existing Pearson Taylor variance infrastructure.
14. Verify tests 10–12 pass.
15. Write failing test: `.corr_replicate_variance_latent()` on a JK1 design returns `list(var_z, var_z_srs, n_ok, n_failed)` with `n_ok = R`, `n_failed = 0` on a clean fixture.
16. Write failing test: `.corr_replicate_variance_latent()` on a BRR fixture returns `var_z` computed using `@variables$scale` and `@variables$rscales`.
17. Write failing test: `.corr_replicate_variance_latent()` emits `surveycore_warning_polychoric_replicate_convergence` (PC-12) when `0 < n_failed ≤ 0.2 R`, dual pattern.
18. Write failing test: `.corr_replicate_variance_latent()` raises `surveycore_error_replicate_convergence_failure` (PC-8) when `n_failed / R > 0.2`, dual pattern.
19. Write failing test: `.corr_replicate_variance_latent()` raises PC-8 when `n_ok == 0`.
20. Write failing test: `.corr_replicate_variance_latent()`'s point estimate (implicit via full-weights MLE run outside the loop) equals the Taylor-path point estimate within `1e-6`.
21. Implement `.corr_replicate_variance_latent()`.
22. Verify tests 15–20 pass.
23. Write failing test: `.corr_latent_pair()` on `survey_twophase` + `method = "polychoric"` raises `surveycore_error_polychoric_design_unsupported` (PC-7) before any MLE work, dual pattern.
24. Write failing test: `.corr_latent_pair()` on `survey_nonprob` + `method = "polyserial"` raises PC-7, dual pattern.
25. Write failing test: `.corr_latent_pair()` on `method = "polychoric"` with a numeric column raises `surveycore_error_polychoric_requires_ordinal` (PC-1), dual pattern.
26. Write failing test: `.corr_latent_pair()` on `method = "polyserial"` with two ordered factors raises PC-2 (propagated via canonicalization), dual pattern.
27. Write failing test: `.corr_latent_pair()` emits `surveycore_warning_polychoric_boundary_rho` (PC-9) when ρ̂ is within `1e-6` of ±1, dual pattern.
28. Write failing test: `.corr_latent_pair()` on `survey_taylor` emits PC-14 (`surveycore_warning_polychoric_taylor_boundary_wide_ci`) additionally when ρ̂ is at boundary.
29. Write failing test: `.corr_latent_pair()` on `survey_replicate` does NOT emit PC-14 at boundary (Taylor-only).
30. Write failing test: `.corr_latent_pair()` emits `surveycore_warning_polychoric_unordered_factor` (PC-13) when any side is an unordered factor, dual pattern.
31. Write failing test: `.corr_latent_pair()` surfaces PC-10 (zero-count level) from the threshold helper, dual pattern.
32. Write failing test: `.corr_latent_pair()` surfaces PC-11 (sparse cell) from the MLE helper, dual pattern.
33. Write failing test: `.corr_latent_pair()` returns a list with fields `r, se_r, se_srs, n, n_weighted, ci_low, ci_high, rho_z, se_z, method` of the correct types.
34. Write failing test: `.corr_latent_pair()` CI endpoints are in `[-1, 1]` (invariant 2).
35. Write failing test: `.corr_latent_pair()` with all-NA pair (0 pairwise-complete rows) returns `r = NA_real_`, `n = 0`, variance columns `NA_real_` (no abort).
36. Write failing test: `.corr_latent_pair()` uses the existing `.corr_fisher_ci()` helper (no duplicate CI implementation).
37. Implement `.corr_latent_pair()` (dispatcher).
38. Verify tests 23–36 pass.
39. Run `devtools::test()`: all PR 1 tests still pass; all new tests pass.
40. Run `devtools::check()`: 0 errors, 0 warnings, ≤ 2 notes.

**Acceptance criteria**

- All tests in `tests/testthat/test-analysis-corr-latent-variance.R` pass.
- `.corr_latent_pair()` returns a list with the ten documented fields of correct types for every tested design class.
- PC-7 fires from `.corr_latent_pair()` before any MLE work when design is twophase / nonprob.
- PC-8 fires when replicate failure exceeds 20 %; PC-12 fires (warning only) when failure is within (0 %, 20 %].
- PC-9 fires for boundary ρ̂ on both Taylor and replicate paths; PC-14 fires only on Taylor.
- `.corr_latent_pair()`'s CI endpoints are in `[-1, 1]` on all tested cases.
- Still no user-visible behavior change from `get_corr()` (file untouched).
- Coverage of `R/analysis-corr-latent.R` ≥ 98 %.

**Files touched** (write surface)

- `R/analysis-corr-latent.R` — modified (adds `.corr_detect_boundary_rho`, `.corr_numerical_influence`, `.corr_taylor_variance_latent`, `.corr_replicate_variance_latent`, `.corr_latent_pair`)
- `tests/testthat/test-analysis-corr-latent-variance.R` — created
- `tests/testthat/_snaps/analysis-corr-latent-variance/` — created (snapshots for PC-7, PC-8, PC-9, PC-12, PC-14, plus dispatcher-level PC-1, PC-2, PC-10, PC-11, PC-13)

**Pipeline split**: `recommended`

---

### PR 3: `feature/polychoric-corr-api-wiring`

- [x] Merged in #109 (`897ade3`) on 2026-04-24.

**One-line goal**: Wire the `method` argument into the exported `get_corr()`, update roxygen / NEWS / docs, add integration tests covering format, grouping, variance-column selection, collection dispatch, and edge cases.

**Error / warning classes owned by this PR**: integration-level re-validation of PC-1 through PC-14 via the public API. No new classes introduced at this layer. Pre-existing classes (`surveycore_error_insufficient_variables`, `surveycore_error_invalid_variance_arg`, `surveycore_warning_corr_non_numeric`, `surveycore_warning_small_cell`, `surveycore_warning_cv_undefined`, `surveycore_warning_single_level`) must remain functional when `method = "pearson"` (regression guard).

**Dependencies**: PR 2 merged.

**Tasks** (TDD sub-steps explicit)

1. Write failing test (regression guard): `get_corr(d, c(y1, y2))` with default `method` (omitted) produces bit-identical `r`, `se`, `ci_low`, `ci_high`, `p_value`, `statistic`, `df`, `n` compared to the pre-change implementation (numeric snapshot).
2. Write failing test: `get_corr(d, c(y1, y2), method = "pearson")` produces the same result as the call without `method` (to `1e-10`).
3. Write failing test: `get_corr(d, ..., method = "nonsense")` raises the standard `match.arg` error.
4. Implement: add `method = "pearson"` argument to `get_corr()` signature (position per spec §Function contracts), add `match.arg(method, c("pearson", "polychoric", "polyserial"))` inside the function, keep existing Pearson code path untouched.
5. Verify tests 1–3 pass.
6. Write failing test: `get_corr(d, ..., method = "polychoric")` on two ordinal cols (equal weights, `survey_taylor`) matches `polycor::polychor()` within `1e-6`; `meta(result)$method == "polychoric"`.
7. Write failing test: `get_corr(d, ..., method = "polychoric")` on a stratified `survey_taylor` returns `r ∈ (-1, 1)`, `se > 0`, `ci_low < r < ci_high`, CI bounds in `[-1, 1]`.
8. Write failing test: `get_corr(d, ..., method = "polychoric")` on a JK1 replicate design — `r` matches Taylor path within `1e-6`.
9. Write failing test: `get_corr(d, ..., method = "polychoric")` on a BRR replicate design — `r` matches Taylor path within `1e-6`, `se > 0`.
10. Implement the dispatch in `R/analysis-corr.R`: when `method != "pearson"`, delegate per-pair resolution to `.corr_latent_pair()` and pass results to the existing long/wide assembly pipeline.
11. Verify tests 6–9 pass.
12. Write failing test: `get_corr(d, ..., method = "polyserial")` on one continuous + one ordinal matches `polycor::polyserial()` within `1e-6`; `meta(result)$method == "polyserial"`.
13. Write failing test: `get_corr(d, ..., method = "polyserial")` on a JK1 replicate — `r` matches Taylor path; bounds in `[-1, 1]`.
14. Verify tests 12–13 pass.
15. Write failing test: multi-pair `get_corr(d, c(o1, o2, o3), method = "polychoric")` returns 3 rows in long format with correct `var1`/`var2` labelling and per-pair MLE matching oracle within `1e-6`.
16. Write failing test: `get_corr(..., method = "polychoric", redundant = TRUE)` returns 2 rows with `r` equal across both rows and `var1`/`var2` swapped.
17. Write failing test: `get_corr(..., method = "polychoric", diagonal = TRUE)` has `r = 1`, `se = 0` on self-correlation rows.
18. Write failing test: `get_corr(..., method = "polychoric", format = "wide")` on 3 ordinal columns returns a square matrix with NA diagonal; no `se`/`ci_*` columns.
19. Write failing test: `get_corr(..., method = "polychoric", group = sex)` on a 2-level group produces 2 rows with `sex` column prepended and differing `r` values.
20. Write failing test: `variance = "se"`, `variance = "ci"`, `variance = c("se", "ci", "moe")`, `variance = "deff"`, `variance = NULL` produce the correct subset of variance columns on a polychoric call; `moe = (ci_high - ci_low) / 2`.
21. Write failing test: `df = NA_integer_` and `statistic = ζ̂ / SE(ζ̂)` (z-scale Wald) for `method != "pearson"`; `df = n - 2` preserved for `method = "pearson"`.
22. Write failing test: column label attributes are method-neutral strings (`"statistic"`, not `"t-statistic"` / `"z-statistic"`).
23. Verify tests 15–22 pass (may require minor additions to the long-format assembly in `R/analysis-corr.R` to thread method-aware `df`/`statistic`/`p_value`).
24. Write failing test (edge): empty active domain (via all-FALSE filter) → `r = NA`, `n = 0`; no abort.
25. Write failing test (edge): single-level ordinal (global) → PC-4, dual pattern.
26. Write failing test (edge): all-NA focal column → `r = NA`, `n = 0`, no spurious PC-4.
27. Write failing test (edge): zero-weight rows present → `r` matches a call where those rows were physically removed, within `1e-8`.
28. Write failing test (edge): integer vector with 3 distinct values + `method = "polychoric"` → accepted, no warning.
29. Write failing test (edge): integer vector with 15 distinct values + `method = "polyserial"` → PC-3.
30. Write failing test (edge): character column + `method = "polychoric"` → PC-1.
31. Write failing test (edge): 6×7 ordinal → runs without error.
32. Write failing test (edge): domain via `surveytidy::filter()` → point estimate matches equivalent raw subset call within `1e-6` (unweighted).
33. Write failing test (collection): `survey_collection` of all `survey_taylor` members with `method = "polychoric"` dispatches per-survey; `.survey` id column present.
34. Write failing test (collection): `survey_collection` containing a `survey_twophase` member with `method = "polychoric"` + `.on_missing = "error"` raises PC-7.
35. Write failing test (collection): same as above but `.on_missing = "skip"` returns only the supported surveys and emits `surveycore_message_collection_skipped_surveys`.
36. Write failing test (Pearson regression): existing test-analysis-corr.R tests all still pass without modification; `surveycore_warning_corr_non_numeric` still fires for non-numeric columns under `method = "pearson"`.
37. Write failing test: `meta(result)$bivariate_normal_cdf == "pbivnorm"` for polychoric / polyserial results.
38. Write failing test: `meta(result)$n_failed_replicates_total` is absent when `n_failed == 0`; scalar integer when `n_failed > 0`.
39. Implement the remaining wiring: method-aware `df`/`statistic`/`p_value` in long-format assembly; `meta()` population for `method`, `bivariate_normal_cdf`, and `n_failed_replicates_total`.
40. Verify tests 24–38 pass.
41. Update roxygen in `R/analysis-corr.R`: add `@param method`, add a `@details` paragraph describing polychoric / polyserial semantics, bivariate-normal assumption, Taylor-path O(n) cost note, and replicate-type caveat (BRR / Fay unverified for the paper's replicate variance estimator).
42. Update `NEWS.md` with a user-facing bullet describing the new `method =` values and the new `pbivnorm` Import.
43. Run `devtools::document()`; verify `man/get_corr.Rd` regenerates cleanly and NAMESPACE has no unexpected diff.
44. Run `devtools::run_examples()`: the updated `get_corr()` examples all run.
45. Run `devtools::test()`: all tests (including pre-existing) pass.
46. Run `devtools::check()` / `R CMD check --as-cran`: 0 errors, 0 warnings, ≤ 2 notes (pre-approved notes only).
47. Run `covr::package_coverage()`: ≥ 95 % overall; ≥ 98 % on `R/analysis-corr-latent.R`.

**Acceptance criteria**

- Every test row in test-spec.md §Per-function test plan passes.
- Every row in test-spec.md §Error paths table (PC-1 through PC-8, plus reused classes) has a passing dual-pattern test at the public-API layer.
- Every row in test-spec.md §Warning paths table (PC-9 through PC-14) has a passing dual-pattern test at the public-API layer.
- `method = "pearson"` is bit-identical to the current implementation on canonical inputs (pinned numeric snapshot).
- `polycor::polychor()` parity at `1e-6` on 3×3, 4×5, 2×2 equal-weight fixtures.
- `polycor::polyserial()` parity at `1e-6` on 3-, 5-, 2-level fixtures.
- `meta(result)$method`, `meta(result)$bivariate_normal_cdf`, and `meta(result)$n_failed_replicates_total` all set as specified.
- `df = NA_integer_` and `statistic` is the z-scale Wald statistic for `method != "pearson"`; `df = n - 2` preserved for Pearson.
- `surveytidy::filter()` domain correctness verified against raw-subset equivalent.
- Survey collection dispatch works for all-`survey_taylor` collections; PC-7 is surfaced through the collection's usual `.on_missing` machinery.
- `man/get_corr.Rd` regenerates with the new `@param method` and `@details` paragraph.
- `NEWS.md` has the user-facing bullet.
- All profile gates from test-spec.md §Profile gates pass.

**Files touched** (write surface)

- `R/analysis-corr.R` — modified (adds `method` argument, `match.arg` call, dispatch branch, method-aware long-format assembly)
- `tests/testthat/test-analysis-corr-latent.R` — created (integration tests through the public API)
- `tests/testthat/_snaps/analysis-corr-latent/` — created (snapshots for all PC classes at the public-API layer)
- `NEWS.md` — modified (user-facing bullet)
- `man/get_corr.Rd` — regenerated by `devtools::document()`
- `NAMESPACE` — regenerated by `devtools::document()` (no new exports)

**Pipeline split**: `recommended`

---

## Coverage map: spec contract items → PR

| Spec contract function | PR |
|---|---|
| `get_corr()` (modified signature, dispatch, meta) | PR 3 |
| `.corr_detect_ordinal()` | PR 1 |
| `.corr_canonicalize_polyserial()` | PR 1 |
| `.corr_estimate_thresholds()` | PR 1 |
| `.corr_weighted_standardize()` | PR 1 |
| `.corr_polychoric_loglik()` | PR 1 |
| `.corr_polyserial_loglik()` | PR 1 |
| `.corr_polychoric_mle()` | PR 1 |
| `.corr_polyserial_mle()` | PR 1 |
| `.corr_numerical_influence()` | PR 2 |
| `.corr_taylor_variance_latent()` | PR 2 |
| `.corr_replicate_variance_latent()` | PR 2 |
| `.corr_latent_pair()` | PR 2 |
| `.corr_detect_boundary_rho()` | PR 2 |
| `.corr_fisher_ci()` (reused, not re-implemented) | PR 2 (caller in `.corr_latent_pair`) |

## Coverage map: error / warning classes (PC-1 … PC-14) → PR

| Class | Condition | Emission-site PR | Integration-test PR |
|---|---|---|---|
| PC-1 `surveycore_error_polychoric_requires_ordinal` | Non-ordinal column under polychoric | PR 2 (dispatcher) | PR 3 |
| PC-2 `surveycore_error_polyserial_requires_mixed_types` | Both sides ordinal or both continuous under polyserial | PR 1 (canonicalize) | PR 3 |
| PC-3 `surveycore_error_polyserial_canonicalization_ambiguous` | Ambiguous column under polyserial | PR 1 (canonicalize) | PR 3 |
| PC-4 `surveycore_error_polychoric_single_level_ordinal` | < 2 observed levels | PR 1 (threshold helper / MLE) | PR 3 |
| PC-5 `surveycore_error_polychoric_insufficient_cells` | `n_cells_obs < 4` | PR 1 (MLE) | PR 3 |
| PC-6 `surveycore_error_polychoric_optim_failed` | Optimizer non-convergence | PR 1 (MLE) | PR 3 |
| PC-7 `surveycore_error_polychoric_design_unsupported` | twophase / nonprob + non-Pearson | PR 2 (dispatcher) | PR 3 |
| PC-8 `surveycore_error_replicate_convergence_failure` | > 20 % replicate failure or 0 succeeded | PR 2 (replicate helper) | PR 3 |
| PC-9 `surveycore_warning_polychoric_boundary_rho` | ρ̂ within ε of ±1 | PR 2 (dispatcher) | PR 3 |
| PC-10 `surveycore_warning_polychoric_zero_count_level` | Zero-weight interior level dropped | PR 1 (threshold helper returns bookkeeping); PR 2 (dispatcher emits warning) | PR 3 |
| PC-11 `surveycore_warning_polychoric_sparse_cell` | Cell prob < 1e-12 at MLE | PR 1 (MLE returns `n_sparse_cells`); PR 2 (dispatcher emits warning) | PR 3 |
| PC-12 `surveycore_warning_polychoric_replicate_convergence` | 0 < failed ≤ 20 % | PR 2 (replicate helper) | PR 3 |
| PC-13 `surveycore_warning_polychoric_unordered_factor` | Unordered factor supplied | PR 2 (dispatcher emits on detection) | PR 3 |
| PC-14 `surveycore_warning_polychoric_taylor_boundary_wide_ci` | Taylor path + boundary ρ̂ | PR 2 (dispatcher) | PR 3 |

Every PC-1 … PC-14 has at least one emission-site test (in its owning PR) and at least one integration test (in PR 3).

---

## Challenge-gate checklist (pre-return)

- [x] Every task has a TDD sub-step (failing test → implement → verify) or is a pure docs / NEWS / regeneration task (PR 3 tasks 41–47).
- [x] No two **concurrent** PRs share a file in their write surface — PR 1, 2, 3 are strictly sequential; the only shared file across them is `R/analysis-corr-latent.R` (PR 1 creates it, PR 2 extends it) and that is serialized by sequencing.
- [x] Every PC-1 … PC-14 has an emission-site PR and an integration-test PR (see the coverage map above).
- [x] Every spec contract function (`get_corr` plus the 14 internal helpers) is scheduled in exactly one PR (see coverage map).
- [x] The `DESCRIPTION` edit (adding `pbivnorm`) lives in PR 1, the first PR that calls `pbivnorm::pbivnorm()`.
- [x] Files required by the plan all appear: `R/analysis-corr.R` (PR 3), `R/analysis-corr-latent.R` (PR 1 create, PR 2 modify), `tests/testthat/test-analysis-corr-latent-*.R` (PR 1, PR 2, PR 3), `DESCRIPTION` (PR 1), `NEWS.md` (PR 3), `NAMESPACE` (auto, PRs 1/3), `man/get_corr.Rd` (auto, PR 3).
