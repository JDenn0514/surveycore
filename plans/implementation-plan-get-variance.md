# Implementation plan — get-variance

**Target version**: 0.7.1.9000
**PR range**: PR 1–2
**Pipeline split**: recommended (inherited from `spec.md`)

## Sequencing note

PR 1 and PR 2 are **sequential, not concurrent**. PR 2 branches from
`develop` only after PR 1 has merged, and PR 2 edits files that PR 1
created or modified (`R/analysis-variance.R`,
`R/analysis-variance-helpers.R`, plus PR-2-only test files). Because
the two PRs are not open at the same time, the shared-file edits do
**not** violate the "disjoint write surfaces across concurrent PRs"
rule. PR 2 consumes PR 1's helpers; it does not re-author them.

## PR map

- [x] **PR 1: feature/get-variance-core** — Ship the full `get_variance()` public API with Taylor + replicate dispatch, the `FAMILY_META_KEYS` refactor, the `survey_variance` print method, the broom adapter rename, and the full non-dispatch-specific test suite.

  - **Tasks** (2–5 min each, TDD sub-steps explicit)

    1. Create feature branch `feature/get-variance-core` off `develop`.
    2. Bump `DESCRIPTION` version field to `0.7.1.9000`; add a stub `# surveycore (development version)` heading block to `NEWS.md` with a placeholder entry for `get_variance()`.
    3. Write failing test: Taylor-design single-variable happy path — point estimate parity against `survey::svyvar(~ridageyr, design, na.rm = TRUE)` on `nhanes_2017`, tolerance `1e-10`. Assert `test_invariants(design)` first.
    4. Write failing test: same scenario, SE parity against `survey::SE(svyvar(...))`, tolerance `1e-8`.
    5. Write failing test: same scenario, default-CI computed as `coef ± qnorm(0.975) * SE`, tolerance `1e-6`.
    6. Refactor `R/analysis-meta.R`: extract the shared `FAMILY_META_KEYS` constant from the existing per-function `*_META_KEYS` definitions; update every current caller (`get_means`, `get_freqs`, `get_totals`, `get_corr`, `get_quantiles`, `get_ratios`, `get_diffs`, `get_t_test`, `get_pairwise`, `get_anova`) to reference the shared constant. Run `devtools::test()` — all currently-passing tests still pass (no behavioral change).
    7. Register a new `survey_variance` meta constructor in `R/analysis-meta.R` using `FAMILY_META_KEYS`.
    8. Create `R/analysis-variance-helpers.R`. Define `.score_variance(y, weights, domain, na_vec)` returning `z_i = a_i · (y_i − ȳ_d)² · n_d / (n_d − 1)` with `ȳ_d` and `n_d` computed on the active domain-restricted, non-NA, positive-weight subset.
    9. In the same file, define `.variance_cell(design, y, weights, domain, na_vec, ...)` that (a) builds the score via `.score_variance()`, (b) dispatches on `class(design)` to `.taylor_mean_cell()` for `survey_taylor` and `.replicate_mean_cell()` for `survey_replicate`, (c) returns the cell payload (point, var-of-estimate, n, n_weighted components) expected by the result assembler. Leave `survey_twophase` / `survey_nonprob` branches as explicit "not implemented in PR 1" stubs that `cli_abort(class = "surveycore_error_unsupported_class")` — removed in PR 2.
    10. Create `R/analysis-variance.R`. Implement the exported `get_variance()` wrapper with the full signature from spec (all arguments including `na_handling`, `.id`, `.on_missing`). Route through `.validate_shared_args()`, `.check_unsupported_class()`, `.resolve_groups()`, `.apply_domain()`, and the multi-variable iteration loop. Each variable call delegates to `.variance_cell()`; results are row-bound and passed through `.add_variance_cols()`, `.apply_decimals()`, `.make_result_tibble()`, `.apply_name_style()`, and the column-label pass. Class the tibble `c("survey_variance", "survey_result", "tbl_df", "tbl", "data.frame")`.
    11. Run tests from tasks 3–5. Iterate until they pass (Taylor happy path green).
    12. Regenerate `NAMESPACE` and `man/get_variance.Rd` via `devtools::document()`.
    13. Write failing test: replicate (BRR) parity against `svyvar()` on `acs_pums_wy` wrapped as `survey_replicate`, point `1e-10` and SE `1e-8`. Verify dispatch into `.replicate_mean_cell()` returns correct values. Iterate.
    14. Write failing test: multi-variable pairwise — `c(ridageyr, bpxsy1)` against two separate per-variable `svyvar()` calls. Implement or extend the multi-variable loop; verify.
    15. Write failing test: multi-variable listwise — same input, `na_handling = "listwise"` — against `svyvar(~ridageyr + bpxsy1, design, na.rm = TRUE)` diagonal. Implement the shared-active-mask branch; verify.
    16. Write failing test: grouped estimate via `group_by(design, g)` against `survey::svyby(~focal, ~g, design, svyvar, na.rm = TRUE)`. Verify grouping wiring; iterate.
    17. Write failing test: grouped estimate via `group =` argument — same oracle as task 16. Verify.
    18. Write failing test: constant variable returns `variance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0`, `cv = NA` with `surveycore_warning_cv_undefined` fired when `variance = "cv"` is requested. Implement the constant-variable guard in `.variance_cell()`. Verify.
    19. Write failing test: `name_style = "broom"` renames `variance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high`. Extend `.apply_name_style()` to include the `variance → estimate` entry in the broom rename map. Verify.
    20. Write failing test: `n_weighted = TRUE` appends `n_weighted = sum(w[in_domain & !is.na(y) & w > 0])` to tolerance `1e-10`. Verify.
    21. Write failing test: column-level `label` attribute on every output column (`variance`, `se`, `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`, `n`, `n_weighted`, `name`, group columns); interpolated CI label reads `"{conf}% CI low"` / `"{conf}% CI high"`. Implement the label-attribute pass in `R/analysis-variance.R`; verify.
    22. Write failing test: `.meta` top-level structure — keys are the exact `FAMILY_META_KEYS` plus `design_class`, `conf_level`, `name_style`, `min_cell_n`, `na_handling`; **no `function_name` or `variable` keys**; `.meta$group` empty when no grouping, populated when grouping; `.meta$x` has one entry per focal variable with `variable_label`, `question_preface`, `value_labels`. Verify.
    23. Write failing test: `label_vars = TRUE` substitutes the variable label into the `name` column (falling back to raw name when unset); `label_vars = FALSE` keeps the raw name. Verify.
    24. Write failing test: `decimals = 3` rounds every numeric output column to exactly 3 decimals (exact equality after `round()`). Verify.
    25. Write failing test: `deff` column equals `var(V_hat) / var_srs(score)` using `svymean` on the score under SRS, tolerance `1e-8`. Verify.
    26. Add the `survey_variance` print method to `R/methods-print.R` following the existing family template; write a smoke test asserting `print(result)` returns invisibly and does not error on a single-variable and a multi-variable result.
    27. Add the `survey_variance` broom `tidy` / `glance` adapters to `R/methods-compat.R`; write smoke tests for both (tidy returns a tibble; glance returns a 1-row tibble with the expected columns). No new semantics, just registration.
    28. Error paths — write dual-pattern tests (`expect_error(class = ...)` + `expect_snapshot(error = TRUE)`) for every error class that PR 1 can trigger:
        - `surveycore_error_unsupported_class` (pass a plain data frame)
        - `surveycore_error_wrong_variable_count` (empty `x` selection)
        - `surveycore_error_non_numeric_variable` (factor column)
        - `surveycore_error_non_numeric_variable` (character column)
        - `surveycore_error_invalid_variance_arg` (`variance = "foo"`)
        - `surveycore_error_invalid_conf_level` (three cases: `0`, `1`, `NA`)
        - `surveycore_error_invalid_decimals` (two cases: `-1`, `1.5`)
        - `surveycore_error_invalid_name_style` (`"foo"`)
        - `surveycore_error_na_rm_not_logical` (two cases: `NA`, `1`)
        - `na_handling = "foo"` — `match.arg()` error; `expect_error()` only (no snapshot), consistent with row 18 pattern
    29. Warning paths — write `expect_warning(class = ...)` tests for:
        - `surveycore_warning_small_cell` (construct a domain where any row has `n < min_cell_n = 30L`)
        - `surveycore_warning_single_level` (grouping var with one observed level)
        - `surveycore_warning_cv_undefined` (request `variance = "cv"` on a constant variable)
        - `surveycore_warning_variance_all_na` (focal variable all-NA in active domain, `na.rm = TRUE`)
        - `surveycore_warning_variance_all_na` (`na_handling = "listwise"` with empty intersection)
        - `surveycore_warning_variance_insufficient_n` (focal variable with exactly one non-NA row)
    30. Edge-case tests reachable from PR 1 dispatch:
        - All-NA focal variable with `na.rm = TRUE` → `variance = NaN`, all uncertainty cols `NaN`, `n = 0L`
        - Single non-NA observation → `variance = NaN`, `n = 1L`
        - Constant variable with `n ≥ 2` → exact `0` for point + SE + CI + moe + deff; `cv = NA` only when `"cv"` requested
        - `na.rm = FALSE` with NAs in focal var → `variance = NaN`, `n` reflects all in-domain rows
        - Grouping var with one level → single output row per focal variable
        - `na_handling = "listwise"` with some rows NA in one var → all output rows share `n` equal to intersection count
        - `na_handling = "pairwise"` with rows NA in different vars → per-variable `n` differs across rows
        - Replicate near-constant variable with tiny negative replicate residual → `se = 0` (not `NaN`) via `max(0, v)` guard in `.replicate_mean_cell()` — add the guard only if it isn't already in place; verify
        - CI bounds below zero (construct a near-zero-variance case with wide SE) → `ci_low` returned as-is, not clamped
    31. Add a roxygen `@details` block to `get_variance()` explicitly documenting: CIs use the normal-Wald approximation on the SE of the variance estimate; `ci_low` may be negative when the point estimate is near zero; bounds are not clamped; users may clamp at `0` if desired; matches `survey::svyvar()`.
    32. Run `devtools::document()`; commit regenerated `NAMESPACE` and `man/get_variance.Rd`.
    33. Run `devtools::test()` — every test passes.
    34. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.
    35. Update `NEWS.md` entry under `# surveycore (development version)` to name the new function, the new `survey_variance` class, and the two new warning classes.

  - **Acceptance criteria** — observable outcomes before merge

    All tests below pass at the tolerances named in `test-spec.md`:

    1. Taylor happy-path: point parity to `svyvar()` at `1e-10`; SE parity at `1e-8`; CI at `1e-6`.
    2. Replicate (BRR) happy-path on `acs_pums_wy`: point `1e-10`, SE `1e-8`.
    3. Multi-variable pairwise parity to per-variable `svyvar()`: point `1e-10`, SE `1e-8`.
    4. Multi-variable listwise parity to `svyvar(~y1 + y2, ...)` diagonal: point `1e-10`, SE `1e-8`.
    5. Grouped estimate (via `group_by(design, g)`) parity to `svyby(~y, ~g, ..., svyvar)`: point `1e-10`, SE `1e-8`.
    6. Grouped estimate (via `group =`) parity to same oracle: point `1e-10`, SE `1e-8`.
    7. Constant variable returns exact `0` for `variance`, `se`, `ci_low`, `ci_high`, `moe`, `deff`; exact `NA` for `cv` when requested; `surveycore_warning_cv_undefined` fires exactly once.
    8. `name_style = "broom"` renames the four columns (`variance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high`) and their `label` attributes.
    9. `n_weighted` column equals the manual weighted sum at `1e-10`.
    10. Every output column has a non-`NULL` `label` attribute; CI labels are conf-level-interpolated.
    11. `.meta` top-level keys equal the `FAMILY_META_KEYS` set plus `design_class`, `conf_level`, `name_style`, `min_cell_n`, `na_handling`; contains no `function_name` and no `variable` keys; `.meta$x` has one entry per focal variable with `variable_label`, `question_preface`, `value_labels`; `.meta$group` empty when no grouping, populated when grouping.
    12. `label_vars = TRUE` substitutes variable label into `name`; `label_vars = FALSE` keeps raw name; fallback to raw name when a label is unset.
    13. `decimals = 3` rounds every numeric output column exactly.
    14. `deff` parity at `1e-8` against the manual SRS-of-score comparator.
    15. Print method and broom `tidy`/`glance` adapters dispatch without error on single-variable and multi-variable results.
    16. Dual-pattern (`expect_error(class = ...)` + `expect_snapshot`) green for all error classes listed in task 28.
    17. `expect_warning(class = ...)` green for all warning classes listed in task 29.
    18. Edge cases listed in task 30 behave as specified.
    19. `test_invariants(design)` is the first assertion of every test that constructs a survey design.
    20. `R CMD check`: 0 errors, 0 warnings, ≤2 pre-approved notes.
    21. `devtools::document()` is idempotent after commit (re-running produces no diff).
    22. Existing test suite (pre-refactor) remains fully green after the `FAMILY_META_KEYS` refactor — no other family member's behavior changes.

  - **Files touched** — exact write surface

    | File | Action |
    |---|---|
    | `R/analysis-variance.R` | created |
    | `R/analysis-variance-helpers.R` | created |
    | `R/analysis-meta.R` | modified (introduce `FAMILY_META_KEYS`; register `survey_variance` meta constructor; mechanical update of existing callers) |
    | `R/methods-print.R` | modified (add `survey_variance` print method) |
    | `R/methods-compat.R` | modified (broom adapter for `survey_variance`; extend `.apply_name_style()` broom map with `variance → estimate`) |
    | `NAMESPACE` | regenerated |
    | `man/get_variance.Rd` | generated |
    | `DESCRIPTION` | modified (version bump to `0.7.1.9000`) |
    | `NEWS.md` | modified (dev-version entry) |
    | `tests/testthat/test-analysis-variance.R` | created (all PR 1 tests live here: happy path + multi-variable + grouping + constant + broom + n_weighted + labels + meta + decimals + deff + print smoke + broom smoke + error paths + warning paths + edge cases) |
    | `tests/testthat/_snaps/analysis-variance.md` | created (error-snapshot file generated by testthat) |

    **Test-file convention waiver**: `R/analysis-variance-helpers.R` does **not** get its own `test-analysis-variance-helpers.R`. Per `.claude/rules/testing-surveycore.md` (precedent: `R/07-utils.R`), helper files may be covered inline by the parent module's test file when the helpers are exclusively private and exclusively reachable through the public function. `.variance_cell()` and `.score_variance()` are tested indirectly through `get_variance()` per the project's "Testing private functions" rule (default to indirect; direct only when public-API coverage is genuinely unreachable).

  - **Pipeline split**: recommended

- [x] **PR 2: feature/get-variance-twophase-nonprob-collection** — Extend `.variance_cell()` to cover `survey_twophase` and `survey_nonprob`; wire `survey_collection` dispatch through `.dispatch_over_collection()`; add the numerical parity tests and collection edge-case coverage that PR 1 did not ship.

  - **Tasks** (2–5 min each, TDD sub-steps explicit)

    1. Branch `feature/get-variance-twophase-nonprob-collection` off `develop` **after** PR 1 has merged. Rebase on `develop` before opening.
    2. Write failing test: twophase parity — synthetic `make_survey_data(n = 500, seed = 42, design = "twophase")`, parity against `survey::svyvar(~focal, design_sv, na.rm = TRUE)` on a `survey::twophase()`-wrapped equivalent, tolerance point `1e-10`, SE `1e-8`. Assert `test_invariants(design)` first.
    3. In `R/analysis-variance-helpers.R`, extend `.variance_cell()` to add the `survey_twophase` branch — delegate to `.twophase_mean_cell()` passing the score from `.score_variance()`. Remove the PR-1 stub. Run task 2's test; iterate until green.
    4. Write failing test: twophase Phase 1-only rows contribute zero influence (edge case from spec) — parity against `svyvar()` on the two-phase oracle design, tolerance point `1e-10`, SE `1e-8`. Verify (usually green from task 3, but retain the edge-case-specific test).
    5. Write failing test: nonprob parity — synthetic nonprob design (weights only, no ids/strata), parity against `survey::svyvar(~focal, svydesign(ids = ~1, weights = ~w, data), na.rm = TRUE)`, tolerance point `1e-10`, SE `1e-8`.
    6. In `R/analysis-variance-helpers.R`, extend `.variance_cell()` to add the `survey_nonprob` branch — delegate to `.nonprob_mean_cell()` passing the score. Remove the PR-1 stub. Iterate.
    7. Write failing test: nonprob with zero-weight rows — zero-weight rows excluded from `n` and from the weighted mean (spec edge case); parity against an oracle where zero-weight rows are pre-filtered, tolerance `1e-10` / `1e-8`. Verify the `.score_variance()` domain mask excludes zero-weight rows; iterate only if needed.
    8. Confirm `R/analysis-variance.R` dispatches `survey_collection` through `.dispatch_over_collection()` (this is typically free via the family wrapper). If `.dispatch_over_collection()` requires a surface-level registration, add it in `R/analysis-variance.R`.
    9. Write failing test: `survey_collection` happy path — two-survey collection built from `make_survey_data()` twice with different seeds; result row-binds per-survey `get_variance()` output with a `.survey` id column keyed to survey names; parity at `1e-10` / `1e-8`. Iterate.
    10. Write failing dual-pattern test: `surveycore_error_collection_missing_var` — two-survey collection, one survey missing the focal variable, `.on_missing = "error"`.
    11. Write failing dual-pattern test: `surveycore_error_collection_all_skipped` — all surveys missing variable, `.on_missing = "skip"` → collapses to this error. Verify.
    12. Write failing dual-pattern test: `surveycore_error_collection_id_collision` — `.id = "name"` (collides with the produced `name` column) and `.id = "variance"`.
    13. Write failing dual-pattern test: `surveycore_error_collection_invalid_id` — `.id = ""` and `.id = c("a", "b")`.
    14. Write failing dual-pattern test: `surveycore_error_variable_not_found` — per-survey path with a variable not in one design (distinct from the "collection" all-missing path).
    15. Write failing `expect_message(class = ...)` test: `surveycore_message_collection_skipped_surveys` — `.on_missing = "skip"` with one survey missing the var; at least one survey has the var, so a non-empty result is returned. Verify.
    16. Write failing `expect_warning(class = ...)` test: `surveycore_warning_collection_meta_divergence` — two surveys whose metadata for the same focal variable differs; top-level `.meta` reflects the first survey; `meta(result)$per_survey` is present. Verify.
    17. Write failing `expect_warning(class = ...)` test: `surveycore_warning_collection_duplicate_name_repaired` — two surveys sharing the same name in the collection; repair fires the warning.
    18. Run `devtools::test()` — every new test plus the full PR 1 suite green.
    19. Update `NEWS.md` dev-version entry to note that `get_variance()` now supports `survey_twophase`, `survey_nonprob`, and `survey_collection` dispatch.
    20. Run `devtools::document()` — no new `.Rd` expected (signature did not change); confirm NAMESPACE diff is empty.
    21. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

  - **Acceptance criteria** — observable outcomes before merge

    All tests below pass at the tolerances named in `test-spec.md`:

    1. Twophase parity to `svyvar()` on the `survey::twophase()`-wrapped design: point `1e-10`, SE `1e-8`.
    2. Twophase Phase 1-only rows contribute zero influence (parity retained on the edge-case dataset).
    3. Nonprob parity to `svyvar()` on `svydesign(ids = ~1, weights = ~w)`: point `1e-10`, SE `1e-8`.
    4. Nonprob zero-weight rows excluded from `n` and from the weighted mean (parity against pre-filtered oracle).
    5. `survey_collection` happy-path row-binds per-survey `get_variance()` output with the `.survey` id column; per-survey parity `1e-10` / `1e-8`.
    6. Dual-pattern green for `surveycore_error_collection_missing_var`.
    7. Dual-pattern green for `surveycore_error_collection_all_skipped`.
    8. Dual-pattern green for `surveycore_error_collection_id_collision` (both collision cases).
    9. Dual-pattern green for `surveycore_error_collection_invalid_id` (both invalid-id cases).
    10. Dual-pattern green for `surveycore_error_variable_not_found` on the per-survey path.
    11. `expect_message(class = "surveycore_message_collection_skipped_surveys")` green with `.on_missing = "skip"`.
    12. `expect_warning(class = "surveycore_warning_collection_meta_divergence")` green; `meta(result)$per_survey` present.
    13. `expect_warning(class = "surveycore_warning_collection_duplicate_name_repaired")` green.
    14. PR 1's entire test suite remains green (no regression from the helper extensions).
    15. `test_invariants(design)` is the first assertion of every test that constructs a survey design; collection tests additionally assert `test_invariants()` on each component survey.
    16. `R CMD check`: 0 errors, 0 warnings, ≤2 pre-approved notes.

  - **Files touched** — exact write surface

    | File | Action |
    |---|---|
    | `R/analysis-variance-helpers.R` | modified (extend `.variance_cell()` with `survey_twophase` and `survey_nonprob` branches; remove PR-1 stubs) |
    | `R/analysis-variance.R` | modified (confirm or add `survey_collection` dispatch wiring through `.dispatch_over_collection()`, if not free) |
    | `NEWS.md` | modified (dev-version entry updated) |
    | `tests/testthat/test-analysis-variance-twophase-nonprob.R` | created (twophase + nonprob parity + nonprob zero-weight + twophase phase-1 edge) |
    | `tests/testthat/test-analysis-variance-collection.R` | created (collection happy path + C5, C6, C7, C13, C10 errors + C9 message + C11 divergence warning + C2a duplicate-name warning) |
    | `tests/testthat/_snaps/analysis-variance-twophase-nonprob.md` | created (error-snapshot file generated by testthat) |
    | `tests/testthat/_snaps/analysis-variance-collection.md` | created (error-snapshot file generated by testthat) |

    Overlap with PR 1: `R/analysis-variance-helpers.R` and `R/analysis-variance.R` are edited in both PRs. This is **sequential** (PR 2 opens only after PR 1 merges); no "disjoint concurrent PRs" rule is violated.

  - **Pipeline split**: recommended

## Test-spec coverage map

Every row in `test-spec.md` is scheduled under exactly one PR:

| `test-spec.md` row family | PR |
|---|---|
| Happy path: Taylor point + SE + CI | PR 1 |
| Happy path: multi-variable pairwise + listwise | PR 1 |
| Happy path: replicate (BRR) parity | PR 1 |
| Happy path: twophase parity | PR 2 |
| Happy path: nonprob parity | PR 2 |
| Happy path: grouped via `group_by()` + `group =` | PR 1 |
| Happy path: constant variable → exact `0` | PR 1 |
| Happy path: `name_style = "broom"` rename | PR 1 |
| Happy path: `n_weighted` | PR 1 |
| Happy path: column-level `label` attrs | PR 1 |
| Happy path: `.meta` top-level + `$x` + `$group` structure | PR 1 |
| Happy path: `label_vars` on/off | PR 1 |
| Happy path: `decimals = 3` rounding | PR 1 |
| Happy path: `deff` parity | PR 1 |
| Happy path: `survey_collection` | PR 2 |
| Error: unsupported_class / wrong_variable_count / non_numeric_variable (factor + char) / invalid_variance_arg / invalid_conf_level (3) / invalid_decimals (2) / invalid_name_style / na_rm_not_logical (2) / `na_handling` match.arg | PR 1 |
| Error: collection_missing_var / collection_all_skipped / collection_id_collision / collection_invalid_id (2) / variable_not_found (per-survey) | PR 2 |
| Warning: small_cell / single_level / cv_undefined / variance_all_na (2 trigger paths) / variance_insufficient_n | PR 1 |
| Warning: collection_skipped_surveys (message) / collection_meta_divergence / collection_duplicate_name_repaired | PR 2 |
| Edge: all-NA / single-obs / constant / `na.rm = FALSE` / single-level group / listwise-intersection / pairwise-differ / replicate near-zero | PR 1 |
| Edge: CI below zero (not clamped) | PR 1 |
| Edge: nonprob zero-weight / twophase phase-1 / collection all-missing (→ error) / collection per-survey meta divergence | PR 2 |
| Invariants block (applies to every test) | PR 1 + PR 2 |
| Tolerances block (applies to every test) | PR 1 + PR 2 |
| Profile gates block | PR 1 (full pass); PR 2 (retain full pass) |

## Spec contract coverage map

Every item in `spec.md §Function contracts` is covered by at least one PR's acceptance criteria:

| Contract item | PR |
|---|---|
| Signature (all 15 args including `na_handling`, `.id`, `.on_missing`) | PR 1 (full signature shipped) |
| Arguments semantics (design classes, `x`, `group`, `variance`, `conf_level`, `n_weighted`, `decimals`, `min_cell_n`, `na.rm`, `na_handling`, `label_values`, `label_vars`, `name_style`, `.id`, `.on_missing`) | PR 1 for all except twophase/nonprob/collection-specific behavior which are PR 2 |
| Returns (class, column order, column attrs, `.meta` shape) | PR 1 (full return shipped; PR 2 only extends dispatch paths) |
| Errors (15 rows) | PR 1 for rows not requiring collection dispatch; PR 2 for collection-specific rows |
| Warnings (9 rows) | PR 1 for non-collection; PR 2 for collection-specific |
| Edge cases (14 rows) | PR 1 for non-dispatch-specific; PR 2 for twophase/nonprob/collection-specific |

## HOLDs raised

None. All PR ordering is unambiguous (sequential), and every row in `test-spec.md` maps to exactly one PR.
