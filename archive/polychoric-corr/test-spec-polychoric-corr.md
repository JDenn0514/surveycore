# Test-spec — polychoric-corr

## Reference oracle

- **Polychoric**: `polycor::polychor()`. Canonical R implementation of the Olsson (1979) two-step MLE. Used with equal weights (`weights = rep(1, n)`) to produce ρ̂ on an unweighted subset and compared against `get_corr(method = "polychoric")` on a `survey_taylor` design with equal weights.
- **Polyserial**: `polycor::polyserial()`. Same pattern — equal-weight oracle for the unweighted two-step estimate.
- **Pearson (regression/guard)**: `survey::svyvar()` / `survey::svymean()` via the existing numerical tests in `test-analysis-corr.R`. Guard test that `method = "pearson"` remains numerically bit-identical to the current implementation.
- **Not used as oracles**:
  - `jtools::svycor()` — Pearson only; cannot validate polychoric/polyserial numerical correctness.
  - Mannan (2025) tabulated outputs — illustrative only; the paper does not publish reproducible data or seeds.

## Datasets

- `make_survey_data(seed = 2026)` — the standard synthetic generator; produces numeric `y1`, `y2`, `y3`, plus design variables. For polychoric/polyserial tests, the numeric outcomes are binned inline into ordinal factors with 3 to 5 levels.
- `make_survey_data(seed = ..., design = "replicate", type = "JK1" | "BRR" | "bootstrap")` — replicate-design variants for variance-path tests.
- Hand-crafted synthetic ordinal data inline — for boundary, single-level, zero-count, sparse-cell, and insufficient-cell edge cases, tiny data frames are constructed directly in the test to trigger the exact condition.
- An unweighted ordinalized frame derived from `make_survey_data()` — used with equal weights for the numerical-oracle comparison against `polycor`.
- No real dataset binding (NHANES / GSS / ACS) is required. If builder wants an integration test with a labelled dataset, the GSS or NHANES columns may be binned inline; this is optional and not part of the spec's minimum.
- Snapshot files: `tests/testthat/_snaps/analysis-corr-latent/*.md` — one file per test block per surveycore convention.

## Per-function test plan

### `get_corr(method = "pearson")` — regression guard

- **Happy path**: `get_corr(d, c(y1, y2))` on a `survey_taylor` design returns a tibble bit-identical to the current implementation for `r`, `se`, `ci_low`, `ci_high`, `p_value`, `statistic`, `df`, `n`. Use the existing `test-analysis-corr.R` fixtures.
- **Invariant**: `test_invariants(d)` first assertion.
- **Goal**: catch any regression where the dispatch branch on `method` mistakenly alters Pearson behavior (e.g., changes `df` handling, silent-drop warning behavior, `meta()` contents).

### `get_corr(method = "polychoric")` — `survey_taylor` happy path

- **Scenario**: two ordinal columns (3-level and 4-level) built by binning `y1` and `y2`; equal weights; no strata.
- **Oracle**: `polycor::polychor(table(o1, o2))` on the same binning.
- **Assertions**: `r` (i.e. ρ̂) matches oracle within `1e-6`. `se`, `ci_low`, `ci_high` populated and finite. `meta(result)$method == "polychoric"`.
- **Invariant**: `test_invariants(d)` first assertion.

### `get_corr(method = "polychoric")` — stratified `survey_taylor`

- **Scenario**: stratified clustered design from `make_survey_data()`; ordinalize `y1` and `y2`; non-trivial weights.
- **No numerical oracle** (weights differ from `polycor`). Assertions:
  - `r ∈ (-1, 1)`.
  - `se > 0`; `ci_low < r < ci_high`.
  - `ci_low, ci_high ∈ [-1, 1]`.
  - `meta(result)$method == "polychoric"`.

### `get_corr(method = "polychoric")` — `survey_replicate` (JK1) happy path

- **Scenario**: JK1 replicate design; ordinalize two outcomes.
- **Assertions**: `r`, `se` match the polychoric MLE run over the full weights (i.e. the `r` from this call equals the `r` from a Taylor call on the same underlying data at full weights, within `1e-6`). `se` is positive.
- **Invariant**: `test_invariants(d)` first assertion.

### `get_corr(method = "polychoric")` — `survey_replicate` (BRR) variance sanity

- **Scenario**: small BRR design (e.g. R = 8) with two ordinal variables.
- **Assertion**: `r` matches the Taylor MLE (the point estimate is a function of the full weights only, not the replicate structure) within `1e-6`. `se` is positive and finite.
- **No external oracle** — paper's variance estimator is the oracle definitionally.

### `get_corr(method = "polychoric")` — replicate variance vs Taylor variance

- **Scenario**: same synthetic data; construct both a `survey_taylor` and a `survey_replicate` version.
- **Assertion**: both produce the same `r` within `1e-6`; `se` values may differ. Do **not** compare SE against each other; each is validated against its own path's internal consistency.

### `get_corr(method = "polyserial")` — happy path

- **Scenario**: one continuous column (`y1` unchanged), one 4-level ordinal column (binned from `y2`); `survey_taylor` with equal weights.
- **Oracle**: `polycor::polyserial(x = y1, y = ordinal)`.
- **Assertions**: `r` matches oracle within `1e-6`. `meta(result)$method == "polyserial"`.

### `get_corr(method = "polyserial")` — replicate path

- **Scenario**: JK1 design with one continuous and one ordinal column.
- **Assertions**: `r` matches Taylor path MLE; `se > 0`; `ci_low < r < ci_high`; bounds ∈ [-1, 1].

### `get_corr(method = "polychoric")` — multi-pair long format

- **Scenario**: three ordinal columns → 3 pairs.
- **Assertions**: 3 rows in long format; `var1`, `var2` correctly labelled; each `r` matches a per-pair oracle; `method` attribute in `meta()`.

### `get_corr(method = "polychoric")` — `redundant = TRUE`

- **Scenario**: two ordinal columns, `redundant = TRUE`.
- **Assertions**: 2 rows; `r` value is the same in both rows; `var1`/`var2` order swapped.

### `get_corr(method = "polychoric")` — `diagonal = TRUE`

- **Scenario**: two ordinal columns, `diagonal = TRUE`.
- **Assertions**: self-correlation rows have `r = 1`, `se = 0` (unchanged convention from Pearson).

### `get_corr(method = "polychoric")` — wide format

- **Scenario**: three ordinal columns, `format = "wide"`.
- **Assertions**: square matrix; diagonal is `NA` (since `diagonal = FALSE` default); off-diagonal entries are real MLEs; no `se` / `ci_*` columns (wide format contract).

### `get_corr(method = ...)` — grouped (`group = sex`)

- **Scenario**: group variable with 2 levels; two ordinal outcomes.
- **Assertions**: output has `sex` column prepended; 2 rows (one per level); per-group `r` values differ.

### `get_corr(method = "polychoric")` — `variance` column selection

- **Scenarios**: `variance = "se"`, `variance = "ci"`, `variance = c("se", "ci", "moe")`, `variance = "deff"`, `variance = NULL`.
- **Assertions**: requested columns are present, unrequested are absent; `ci_low, ci_high ∈ [-1, 1]`; `moe = (ci_high - ci_low) / 2`.

### Error paths (one block per error class)

| # | Class | Setup | Assertion |
|---|---|---|---|
| PC-1 | `surveycore_error_polychoric_requires_ordinal` | `method = "polychoric"` with a `numeric` column in `x` | `expect_error(..., class = "surveycore_error_polychoric_requires_ordinal")` + snapshot |
| PC-2 | `surveycore_error_polyserial_requires_mixed_types` | `method = "polyserial"` with two ordered factors | both `expect_error(class = ...)` and `expect_snapshot(error = TRUE, ...)` |
| PC-3 | `surveycore_error_polyserial_canonicalization_ambiguous` | `method = "polyserial"` with an `integer` column of 50 distinct values paired with an ordered factor | both assertions |
| PC-4 | `surveycore_error_polychoric_single_level_ordinal` | Ordinal column where domain filtering leaves only one observed level | both assertions |
| PC-5 | `surveycore_error_polychoric_insufficient_cells` | 2×2 ordinal with only 3 observed non-empty cells (e.g., everyone in one diagonal) | both assertions |
| PC-6 | `surveycore_error_polychoric_optim_failed` | Force a degenerate dataset where all mass is in one cell (expect MLE to fail) | both assertions (may need to simulate) |
| PC-7 | `surveycore_error_polychoric_design_unsupported` | `survey_twophase` + `method = "polychoric"`; also `survey_nonprob` + `method = "polyserial"` | both assertions |
| PC-8 | `surveycore_error_replicate_convergence_failure` | Replicate design crafted so > 20% of replicates fail (use a tiny R with many degenerate cells); may require a helper that injects failure via a mocked optimizer | both assertions |
| Reused: `surveycore_error_insufficient_variables` | `method = "polychoric"` with only one variable in `x` | `expect_error(class = ...)` |
| Reused: `surveycore_error_invalid_variance_arg` | `method = "polychoric", variance = "nonsense"` | `expect_error(class = ...)` |

### Warning paths (one block per warning class)

| # | Class | Setup | Assertion |
|---|---|---|---|
| PC-9 | `surveycore_warning_polychoric_boundary_rho` | Construct data where true ρ = 0.99 (e.g., near-identical ordinal columns) so ρ̂ lands within ε of 1 | `expect_warning(class = ...)` + snapshot |
| PC-10 | `surveycore_warning_polychoric_zero_count_level` | 5-level ordered factor where level 3 has no observations in the active domain | `expect_warning(class = ...)` + snapshot |
| PC-11 | `surveycore_warning_polychoric_sparse_cell` | 5×5 ordinal where one observed cell has modeled prob < 1e-12 at the MLE (tiny count in an off-diagonal cell of a strongly positively correlated pair) | `expect_warning(class = ...)` + snapshot |
| PC-12 | `surveycore_warning_polychoric_replicate_convergence` | Replicate design where exactly 1 of 10 replicates fails (inject failure) | `expect_warning(class = ...)` + snapshot + assert `meta(result)$n_failed_replicates_total` has expected scalar value (per A9; no per-row attribute) |
| PC-13 | `surveycore_warning_polychoric_unordered_factor` | Unordered `factor` (not `ordered`) in `x` with `method = "polychoric"` | `expect_warning(class = ...)` + snapshot |
| PC-14 | `surveycore_warning_polychoric_taylor_boundary_wide_ci` | `survey_taylor` design with near-boundary ρ̂ | `expect_warning(class = ...)` + snapshot |

### Edge cases (one per spec edge-case row)

- **Empty active domain (all-FALSE filter)**: result row has `r = NA`, `n = 0`; no abort.
- **Single-row active domain**: fires `surveycore_error_polychoric_single_level_ordinal` because only one level is observed.
- **Single-level ordinal (global)**: fires `surveycore_error_polychoric_single_level_ordinal`.
- **Zero-weight rows present**: result matches a run on a dataset where those rows were physically removed, within `1e-8` on ρ̂. Confirms `0 · log 0 = 0` convention held.
- **All-NA focal column**: result row has `r = NA`, `n = 0`, variance columns `NA`; no abort; no spurious warning from PC-4 (because pairwise deletion happens before level count).
- **Integer vector with 3 distinct values under `method = "polychoric"`**: accepted (classified `"integer_ordinal"`); no warning fires.
- **Integer vector with 15 distinct values under `method = "polyserial"`**: fires PC-3.
- **Character column under `method = "polychoric"`**: fires PC-1 (asks to coerce to factor).
- **Large `t × t'` (6×7 ordinal)**: runs without error; no performance assertion (compute cost is non-normative).
- **Domain via `surveytidy::filter()`**: equivalent to a raw `as_survey()` on the filtered subset for the point estimate within `1e-6` (when variance paths are comparable, e.g. unweighted).
- **`survey_collection` with all `survey_taylor` members**: dispatches per-survey; each survey's row appears with `.survey` id column; one failed survey with `.on_missing = "skip"` is dropped.
- **`survey_collection` with a `survey_twophase` member under `method = "polychoric"`**: the failing survey surfaces `surveycore_error_polychoric_design_unsupported` via the collection error path (or is skipped under `.on_missing = "skip"`).
- **Collection with mixed design types**: an `as_survey_collection(t1 = survey_taylor_obj, tp = survey_twophase_obj, t2 = survey_taylor_obj)` called with `method = "polychoric"` and `.on_missing = "error"` raises PC-7 from the twophase member; with `.on_missing = "skip"` returns rows for `t1` and `t2` only and emits the standard `surveycore_message_collection_skipped_surveys` message.

### Invariants (first assertion of every block that builds a design)

- `test_invariants(design)` — always first.

### Numerical parity regression tests

- **`method = "pearson"` guard**: existing `test-analysis-corr.R` cases must continue to pass unchanged. Add one explicit test that pins `r`, `se`, `ci_low`, `ci_high` for a canonical input against the pre-change values (snapshot as a numeric snapshot, not a CLI snapshot).
- **`method = "polychoric"` vs `polycor::polychor()`**: at least 3 scenarios — 3×3, 4×5, 2×2 ordinal.
- **`method = "polyserial"` vs `polycor::polyserial()`**: at least 3 scenarios — 3-level, 5-level, 2-level ordinal sides.

### Coverage map

Every contract item from spec §Function contracts has at least one row above. Spec-side quality gate numbering (invariants 1–8) is covered as:

- Invariant 1 (ρ̂ ∈ [−1+ε, 1−ε]): every polychoric/polyserial result row asserts `abs(r) < 1` (with the PC-9 near-boundary warning case explicitly tolerating `abs(r) > 1 - 2ε`).
- Invariant 2 (CI endpoints ∈ [−1, 1]): asserted in happy-path rows.
- Invariant 3 (Pearson bit-identical): regression guard row above.
- Invariant 4 (equal-weights oracle match): three polychoric and three polyserial parity rows.
- Invariant 5 (domain honored): covered by the filter-vs-subset edge case.
- Invariant 6 (`meta(result)$n_failed_replicates_total` scalar): covered in PC-12 warning block (per A9, no per-row attribute).
- Invariant 7 (`meta(result)$method`): asserted in each happy-path row.
- Invariant 8 (column types): asserted in long-format happy-path rows.

## Tolerances

- Point estimates (`r`) against external oracle (`polycor::polychor`, `polycor::polyserial`): **`1e-6`**. **Justified deviation** from the standard `1e-10` point tolerance: the polychoric / polyserial MLEs are iterative numerical optimizations with no closed form; `polycor` and surveycore will use different optimizer implementations (`optim` with simulated annealing / `nlm` in polycor vs `stats::optimize()` in surveycore). Both converge to the same local maximum within their respective stopping criteria, but the last 6 decimal places reflect numerical noise, not a specification gap. `1e-6` is tighter than reasonable disagreement.
- Internal consistency between Taylor and replicate paths' `r`: **`1e-6`** (same reason — both go through `stats::optimize()` but on different weight vectors; the full-sample `r` is identical).
- Fisher-z transform and back-transform in pure R arithmetic: `1e-8`.
- CI endpoints after `tanh()`: `1e-6`.
- Pearson regression guard (same implementation before/after PR): `1e-10` (no numerical drift expected — branching should not change arithmetic).
- Weighted mean / weighted SD (polyserial standardization): `1e-10`.
- Likelihood value at known ρ, θ (closed-form hand-computed test): `1e-8`.

## Profile gates

- [ ] `devtools::document()` clean
- [ ] `devtools::test()` all pass
- [ ] `devtools::run_examples()` all pass
- [ ] `R CMD check --as-cran` (0 err, 0 warn, notes reviewed)
- [ ] `pkgcheck` PASS
- [ ] `pkgdown::build_site()` clean
- [ ] `covr::package_coverage()` ≥ 95 % (target 98 %)
- [ ] CRAN cookbook scan clean (see `r-package-profile.md`)
