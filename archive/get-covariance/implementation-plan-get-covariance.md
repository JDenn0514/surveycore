# Implementation plan — get-covariance

**Target version**: 0.7.2.9000
**PR range**: PR 1 (single-PR track)
**Pipeline split**: recommended (inherited from `spec.md`)

## PR map

- [x] **PR 1: feature/get-covariance** — Ship the full `get_covariance()` public API across all five design classes (`survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, `survey_collection`), the `survey_covariance` meta constructor and print method, the broom `tidy` / `glance` adapter, the `covariance → estimate` extension to `.apply_name_style()`, the three new covariance warning rows (CV-1 / CV-2 / CV-3) in `plans/error-messages.md`, and the full test suite (happy-path parity against `svyvar()` on three designs, internal diagonal-parity gate against `get_variance()` on all five designs, symmetry under `redundant = TRUE`, pair-generation-rule tests, collection happy-path + C5/C6/C7/C13/C10/C9/C11/C2a coverage, error/warning dual-pattern tests, edge cases).

  - **Tasks** (2–5 min each, TDD sub-steps explicit)

    1. Create feature branch `feature/get-covariance` off `develop`.
    2. Bump `DESCRIPTION` version field to `0.7.2.9000`; add a stub `# surveycore (development version)` heading block to `NEWS.md` with a placeholder entry for `get_covariance()`.
    3. Append three new warning rows to `plans/error-messages.md`:
       - CV-1 `surveycore_warning_covariance_all_na` — "Pair is all-NA on the active domain; covariance is NaN; n = 0."
       - CV-2 `surveycore_warning_covariance_insufficient_n` — "Pair has fewer than 2 pairwise-complete observations; covariance is NaN."
       - CV-3 `surveycore_warning_covariance_non_numeric` — "Dropped non-numeric variable(s) from `x`: {dropped}."

       Each row includes the canonical `"!"` + `"i"` + `"v"` bullet template per `code-style.md §3` and the class name, registry row number, and a short note about which `get_covariance()` code path fires it. Do not wire the CLI strings into code until the corresponding tests below drive them.
    4. Register a new `survey_covariance` meta constructor in `R/analysis-meta.R` using `COVARIANCE_META_KEYS <- c(FAMILY_META_KEYS, "method")`, exactly mirroring the `CORR_META_KEYS` pattern. The constructor stamps `method = "covariance"` as a top-level key. Write a structural test (assert keys match spec list) before wiring into the result assembler. Verify the existing family tests remain green (no behavioural change to other constructors).
    5. Create `R/analysis-covariance-helpers.R`. Define the pair-helper contract from `spec.md §Architecture`: each `.covariance_pair_{taylor,replicate,twophase,nonprob}(design, x_col, y_col, domain, na.rm)` returns a named list with fields `covariance`, `se`, `se_srs`, `var_x`, `var_y`, `n`, `n_weighted`. Build the Kish-scaled score `z_i = (n/(n−1)) · (x_i − x̄)(y_i − ȳ)` on the pairwise-complete active domain (zero elsewhere) and hand the score to the existing variance engine used by `get_variance()`. Leave the four branches as focused functions without a dispatcher yet. **Also scaffold `.attach_covariance_labels(result, meta, conf_level, name_style)` in the same file**: reuse `.attach_variance_labels()` logic for the shared columns (`se`, `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`, `n`, `n_weighted`) and add the covariance-specific labels (`covariance`/`estimate`, `var1`, `var2`) per the spec §Returns Attributes table. Do **not** overload `.attach_variance_labels()`. This scaffold must exist before task 10 references it; task 44 extends and verifies the full label set.
    6. In the same file, define `.covariance_pair_result(design, x_col, y_col, domain, na.rm)` — the dispatch wrapper that selects among the four pair helpers by design class. Error for any other class via the existing `.check_unsupported_class()` path. (Collection dispatch happens above this layer, via `.dispatch_over_collection()`.)
    7. Write failing test: Taylor-design single-pair happy path — point parity against `survey::svyvar(~ridageyr + bpxsy1, design, na.rm = TRUE)[1, 2]` on `nhanes_2017`, tolerance `1e-10`. Assert `test_invariants(design)` first.
    8. Write failing test: same scenario, SE parity against the corresponding off-diagonal of `survey::vcov(svyvar(...))`, tolerance `1e-8`.
    9. Write failing test: same scenario, default Wald CI — `coef ± qnorm(0.975) * SE`, tolerance `1e-6`.
    10. Create `R/analysis-covariance.R`. Implement the exported `get_covariance()` wrapper with the full spec signature (15 positional args plus `.id` / `.on_missing` after `...`). Route through `.validate_shared_args()`, `.check_unsupported_class()`, `.resolve_groups()`, `.apply_domain()`, then the pair-expansion loop (governed by `redundant` / `diagonal`), each pair delegated to `.covariance_pair_result()`; row-bind pair cells, pass through `.add_variance_cols()`, `.apply_decimals()`, `.make_result_tibble()`, `.apply_name_style()`, and the new `.attach_covariance_labels()` pass; class the tibble `c("survey_covariance", "survey_result", "tbl_df", "tbl", "data.frame")`.
    11. Run tests from tasks 7–9. Iterate until green (Taylor happy path).
    12. Regenerate `NAMESPACE` and `man/get_covariance.Rd` via `devtools::document()`. Include the `@references` entries from `spec.md §References` verbatim in the roxygen block.
    13. Write failing test: three-variable input, default flags (lower-triangle, 3 off-diagonal pairs) — every row point/SE parity against the corresponding off-diagonal of `survey::svyvar(~v1 + v2 + v3, design, na.rm = TRUE)`, tolerances `1e-10` / `1e-8`.
    14. Write failing test: three-variable input, `redundant = TRUE` (6 rows) — each `(i, j)` and `(j, i)` row matches the same oracle off-diagonal value; verify pair-expansion rule `|vars|·(|vars|−1)`.
    15. Write failing test: three-variable input, `diagonal = TRUE`, `redundant = FALSE` (6 rows = 3 off-diag + 3 diagonal) — diagonals match `svyvar()` diagonal entries (= variance) AND `get_variance(design, v)$variance`; verify pair-expansion rule `|vars|·(|vars|+1)/2`.
    16. Write failing test: three-variable input, `redundant = TRUE, diagonal = TRUE` (9 rows = `|vars|²`) — union of the two preceding oracles; verify the `|vars|²` pair-expansion rule.
    17. Write failing test: **diagonal-parity quality gate (Taylor)** — `get_covariance(d, c(x, x), diagonal = TRUE)$covariance` equals `get_variance(d, x)$variance` at `1e-10`; `$se` equals `get_variance(d, x)$se` at `1e-8`. Synthetic Taylor data.
    18. Write failing test: replicate (BRR) parity — `acs_pums_wy` wrapped as `survey_replicate`, two focal vars; point `1e-10`, SE `1e-8`. Verify `.covariance_pair_replicate()` forwards `mse`, `scale`, `rscales` unchanged through `.svy_rep_var()`, per the spec's replicate sub-contract.
    19. Write failing test: **diagonal-parity quality gate (replicate)** — synthetic `make_survey_data(design = "replicate", type = "BRR")`; `$covariance` and `$se` equal `get_variance()` at `1e-10` / `1e-8`.
    20. Write failing test: twophase parity — synthetic `make_survey_data(n = 500, seed = 42, design = "twophase")`, parity against `survey::svyvar(~v1 + v2, design_sv)` off-diagonal on a `survey::twophase()`-wrapped equivalent, point `1e-10`, SE `1e-8`.
    21. Write failing test: twophase Phase 1-only rows contribute zero influence — parity retained on the edge-case dataset at `1e-10` / `1e-8`.
    22. Write failing test: **diagonal-parity quality gate (twophase)** — synthetic twophase; `$covariance` and `$se` equal `get_variance()` at `1e-10` / `1e-8`.
    23. Write failing test: nonprob parity — synthetic `make_survey_data(n = 200, seed = 5, design = "nonprob")`, parity against `svyvar(~v1 + v2, svydesign(ids = ~1, weights = ~w, data))` off-diagonal, point `1e-10`, SE `1e-8`.
    24. Write failing test: nonprob zero-weight rows excluded from `n` and from the pair's weighted means — parity against an oracle where zero-weight rows are pre-filtered, `1e-10` / `1e-8`. Verify domain-mask construction in `.covariance_pair_nonprob()`.
    25. Write failing test: **diagonal-parity quality gate (nonprob)** — synthetic nonprob; `$covariance` and `$se` equal `get_variance()` at `1e-10` / `1e-8`.
    26. Write failing test: internal consistency — `get_covariance(design, c(v, v), diagonal = TRUE, redundant = FALSE)$covariance` equals `get_variance(design, v)$variance` at `1e-10`; `$se` equals at `1e-8`. This is the spec §Quality gate item that prose-overlaps with task 17 — retain as its own test with a deliberately narrower data shape (single-variable synthetic Taylor).
    27. Write failing test: symmetry — for a Taylor off-diagonal pair, `get_covariance(design, c(x, y))$covariance` equals `get_covariance(design, c(y, x))$covariance` at `1e-10` and `$se` equals at `1e-8`.
    28. Write failing test: `redundant = TRUE` symmetry invariant — the row `(x, y)` and the row `(y, x)` within a single call have numerically identical `covariance` and `se` at `1e-10` / `1e-8`.
    29. Write failing test: grouped estimate via `group_by(design, g)` — parity against `survey::svyby(~v1 + v2, ~g, design, svyvar, na.rm = TRUE)` (extract off-diagonals per group), `1e-10` / `1e-8`.
    30. Write failing test: grouped estimate via the `group =` argument — same oracle, same tolerances.
    31. Write failing test: constant variable in pair — `y = rep(5, n)`, `x = runif(n)`; `covariance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0` (exact equality); no covariance-specific warning fires. Implement the 0/0 `deff` guard inside `.covariance_pair_result()` (or the analysis-layer deff computation) so the Goodnight / Mood-Graybill denominator returns 0 when the SRS comparator is also 0.
    32. Write failing test: constant variable + `variance = "cv"` requested — `cv = NA` plus `surveycore_warning_cv_undefined` fires (class check only; existing class, already snapshot-pinned elsewhere).
    33. Write failing test: both-constant pair — same as one-constant (exact 0, no warning).
    34. Write failing test: pair all-NA in active domain with `na.rm = TRUE` — `covariance = NaN`, all uncertainty cols `NaN`, `n = 0L`; **dual pattern** `expect_warning(class = "surveycore_warning_covariance_all_na")` + `expect_snapshot(...)`.
    35. Write failing test: one variable all-NA but the other not — collapses to all-NA pair case; fires CV-1 (class check only; snapshot already pinned in task 34).
    36. Write failing test: pair has exactly 1 pairwise-complete row — `covariance = NaN`, uncertainty cols `NaN`, `n = 1L`; **dual pattern** `expect_warning(class = "surveycore_warning_covariance_insufficient_n")` + `expect_snapshot(...)`.
    37. Write failing test: pair has 0 pairwise-complete rows (disjoint NA patterns across x and y) — fires CV-1 via a different trigger path (class check only; snapshot already pinned in task 34).
    38. Write failing test: `diagonal = TRUE` with all-NA variable — self-pair has `covariance = NaN`, `n = 0`; fires CV-1.
    39. Write failing test: `na.rm = FALSE` with NAs in pair — NAs propagate: `covariance = NaN`, `se = NaN`, `n` reflects all in-domain rows; no covariance-specific warning.
    40. Write failing test: replicate near-constant pair with tiny negative replicate residual — `se` returned as exactly `0` (not `NaN`); verify the `max(0, v)` guard inside `sqrt()` is active in `.covariance_pair_replicate()` (same guard as `get_variance()`; do not re-add, just verify).
    41. Write failing test: CI crosses zero when point estimate is near zero with wide SE — `ci_low` and `ci_high` returned as-is (may have opposite signs); not clamped. Structural assertion only.
    42. Write failing test: `name_style = "broom"` renames `covariance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high` (column names + `label` attrs updated). Extend the broom rename map in `.apply_name_style()` (in `R/analysis-helpers.R`) with `covariance = "estimate"`. Verify.
    43. Write failing test: `n_weighted = TRUE` appends an `n_weighted` column equal to the manual weighted sum over the pair's pairwise-complete active domain, tolerance `1e-10`. On diagonal rows, equals per-variable weighted sum.
    44. Write failing test: column-level `label` attribute on every output column (`var1`, `var2`, `covariance`, `se`, `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`, `n`, `n_weighted`). Labels match the spec §Returns Attributes table exactly, including the interpolated CI label `"{conf_level_pct}% CI low"` / `"{conf_level_pct}% CI high"`. `.attach_covariance_labels()` was scaffolded in task 5; verify every label lands per the spec table and extend the helper to cover any label or name-style branch not yet emitted. Do **not** overload `.attach_variance_labels()`.
    45. Write failing test: `.meta` top-level keys are exactly `group`, `x`, `design_class`, `method`, `conf_level`, `name_style`, `min_cell_n`, `redundant`, `diagonal`, `na_rm`; **no `function_name` or `variable` keys**. `meta(result)$method == "covariance"`. Verify.
    46. Write failing test: `.meta$x` has one entry per resolved numeric variable in supply order with `variable_label`, `question_preface`, `value_labels` sub-keys; `.meta$group` empty when no grouping, populated when grouping active.
    47. Write failing test: `var1` and `var2` are factor columns with levels equal to the resolved-numeric-supply-order variable names.
    48. Write failing test: `label_vars = TRUE` substitutes variable labels into `var1` / `var2` factor levels when labels are set; falls back to raw names when unset; `label_vars = FALSE` keeps raw names.
    49. Write failing test: `decimals = 3` rounds every numeric output column to exactly 3 decimals (exact equality after `round()`).
    50. Write failing test: `deff` parity — `deff` column equals `var / ((Var(x) · Var(y) + cov²) / (n − 1))` using the Goodnight / Mood-Graybill SRS reference, computed from the pair-helper's `var_x`, `var_y`, and the `covariance` point estimate, tolerance `1e-8`. (0/0 case already covered in task 31.)
    51. Write failing test: pair generation rule, `|vars| = 4`, `redundant = FALSE, diagonal = FALSE` → `nrow() == 6`; ordered pair-list equality to the lower-triangle supply-order enumeration.
    52. Write failing test: pair generation rule, `|vars| = 4`, `redundant = TRUE, diagonal = FALSE` → `nrow() == 12`; ordered pair-list equality to `|vars|·(|vars|−1)` supply-order enumeration.
    53. Write failing test: pair generation rule, `|vars| = 4`, `redundant = FALSE, diagonal = TRUE` → `nrow() == 10`; ordered pair-list equality to the lower-triangle-plus-diagonal enumeration.
    54. Write failing test: pair generation rule, `|vars| = 4`, `redundant = TRUE, diagonal = TRUE` → `nrow() == 16`; full `|vars|²` grid enumeration.
    55. Write failing test: single-level grouping variable — fires `surveycore_warning_single_level` (class check); output has a single row per emitted pair.
    56. Write failing test: small-cell trigger — construct a domain where at least one pair has `n < min_cell_n = 30L`; **dual pattern** `expect_warning(class = "surveycore_warning_small_cell")` + `expect_snapshot(...)` + result-shape check.
    57. Write failing test: non-numeric variable dropped — `x = c(numeric1, numeric2, factor1)`; **dual pattern** `expect_warning(class = "surveycore_warning_covariance_non_numeric")` + `expect_snapshot(...)` (CV-3).
    58. Confirm `R/analysis-covariance.R` dispatches `survey_collection` through `.dispatch_over_collection()` (free via the family wrapper); if a surface-level registration is required, add it here.
    59. Write failing test: `survey_collection` happy path — two-survey collection from `make_survey_data()` twice with different seeds, both containing both focal vars; default `.id = ".survey"`, `.on_missing = "error"`; result row-binds per-survey `get_covariance()` output with the `.survey` id column keyed to survey names; per-survey parity at `1e-10` / `1e-8`; `.meta$per_survey` absent when metadata agrees.
    60. Write failing test: `survey_collection` with custom `.id = "wave"` — `wave` column present, no `.survey` column.
    61. Write failing `expect_message(class = "surveycore_message_collection_skipped_surveys")` test — `.on_missing = "skip"` with one survey missing the focal var; result contains rows from the other survey only (C9).
    62. Write failing `expect_warning(class = "surveycore_warning_collection_meta_divergence")` test — two surveys whose metadata for the same focal variable differs; top-level `.meta` reflects the first survey; `meta(result)$per_survey` present (C11).
    63. Write failing `expect_warning(class = "surveycore_warning_collection_duplicate_name_repaired")` test — two surveys sharing the same name in the collection; repair fires the warning (C2a).
    64. Write failing test: **diagonal-parity quality gate (collection)** — two-survey synthetic collection; each per-survey diagonal row matches the corresponding `get_variance()` call on that survey's design at `1e-10` / `1e-8`.
    65. Error paths — write dual-pattern tests (`expect_error(class = ...)` + `expect_snapshot(error = TRUE)`) for every error class:
        - `surveycore_error_unsupported_class` (pass a plain `data.frame`)
        - `surveycore_error_insufficient_variables` — empty `x` selection
        - `surveycore_error_insufficient_variables` — `x` selects 1 column
        - `surveycore_error_insufficient_variables` — `x` selects 2 cols, 1 numeric + 1 non-numeric → after dropping, only 1 remains (also assert the CV-3 warning fires before the error)
        - `surveycore_error_invalid_variance_arg` (`variance = "foo"`)
        - `surveycore_error_invalid_conf_level` — `conf_level = 0`
        - `surveycore_error_invalid_conf_level` — `conf_level = 1`
        - `surveycore_error_invalid_conf_level` — `conf_level = NA`
        - `surveycore_error_invalid_decimals` — `decimals = -1`
        - `surveycore_error_invalid_decimals` — `decimals = 1.5`
        - `surveycore_error_invalid_name_style` — `"foo"`
        - `surveycore_error_na_rm_not_logical` — `na.rm = NA`
        - `surveycore_error_na_rm_not_logical` — `na.rm = 1`
        - `surveycore_error_collection_missing_var` — two-survey collection, one survey missing a focal var, `.on_missing = "error"` (C5)
        - `surveycore_error_collection_all_skipped` — all surveys missing a focal var, `.on_missing = "skip"` → collapses to this error (C6)
        - `surveycore_error_collection_id_collision` — `.id = "covariance"` (collides with a produced column); also `.id = "var1"` (C7)
        - `surveycore_error_collection_invalid_id` — `.id = ""` and `.id = c("a", "b")` (C13)
        - `surveycore_error_variable_not_found` — per-survey path with a variable not in one design (C10, distinct from C6 all-missing)
    66. Add the `survey_covariance` print method to `R/methods-print.R` following the existing family template (mirrors `survey_variance`, `survey_corr`); smoke test that `print(result)` returns invisibly and does not error on a single-pair and a multi-pair result.
    67. Add the `survey_covariance` broom `tidy` / `glance` adapters to `R/methods-compat.R` (registration only; no new semantics); smoke tests for both (tidy returns a tibble; glance returns a 1-row tibble with the expected columns).
    68. Add a roxygen `@details` block to `get_covariance()` explicitly documenting: (a) CIs use the normal-Wald approximation on the SE of the covariance estimate; bounds may cross zero because covariance is unbounded; not clamped; matches `svyvar()`. (b) `diagonal = TRUE` returns the variance on the diagonal (not `1` as in `get_corr()`) — semantic divergence is intentional. (c) NA handling is pairwise-complete per pair; no `na_handling` argument. Add `@references` entries from `spec.md §References` verbatim.
    69. Run `devtools::document()`; commit regenerated `NAMESPACE` and `man/get_covariance.Rd`.
    70. Run `devtools::test()` — every test passes.
    71. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.
    72. Finalise `NEWS.md` dev-version entry naming the new `get_covariance()` function, the new `survey_covariance` class, and the three new warning classes (CV-1, CV-2, CV-3).

  - **Acceptance criteria** — observable outcomes before merge

    All tests below pass at the tolerances named in `test-spec.md`. Items 44–45 are regression and documentation invariants — not new tests; ordering preserves pre-existing behavior and the three CV rows land in `plans/error-messages.md` during task 3.

    1. Taylor happy-path single pair: point parity `1e-10`, SE parity `1e-8`, CI `1e-6`.
    2. Taylor three-variable lower-triangle (3 rows) parity to all three `svyvar()` off-diagonals: `1e-10` / `1e-8`.
    3. Taylor `redundant = TRUE` off-diagonal (6 rows) parity: `1e-10` / `1e-8`.
    4. Taylor `diagonal = TRUE` (6 rows) parity — off-diagonals to `svyvar()` off-diagonals; diagonals to `svyvar()` diagonals AND `get_variance()$variance`: `1e-10` / `1e-8`.
    5. Taylor `redundant = TRUE, diagonal = TRUE` (9 rows) parity: `1e-10` / `1e-8`.
    6. Replicate (BRR) parity on `acs_pums_wy`: `1e-10` / `1e-8`.
    7. Twophase parity on synthetic twophase: `1e-10` / `1e-8`.
    8. Twophase Phase-1-only rows contribute zero influence (parity retained on edge-case dataset).
    9. Nonprob parity: `1e-10` / `1e-8`.
    10. Nonprob zero-weight rows excluded from `n` and weighted means (parity to pre-filtered oracle).
    11. **Diagonal-parity quality gate** — for each of `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, and each per-survey path of a `survey_collection`: `get_covariance(d, c(x, x), diagonal = TRUE)$covariance == get_variance(d, x)$variance` at `1e-10` and `$se == get_variance(d, x)$se` at `1e-8`.
    12. Internal consistency `get_covariance(d, c(v, v), diagonal = TRUE) == get_variance(d, v)` — point `1e-10`, SE `1e-8`.
    13. Symmetry `(x, y) == (y, x)` between calls and within a single `redundant = TRUE` call — point `1e-10`, SE `1e-8`.
    14. Grouped estimate (via `group_by()` and via `group =`) parity to `svyby(~v1 + v2, ~g, ..., svyvar)`: `1e-10` / `1e-8`.
    15. Constant-variable pair returns exact `0` for `covariance`, `se`, `ci_low`, `ci_high`, `moe`, `deff`; exact `NA` for `cv` when requested; `surveycore_warning_cv_undefined` fires; no covariance-specific warning fires.
    16. Both-constant pair returns exact `0`; no warning.
    17. `na.rm = FALSE` with NAs propagates NaN; `n` reflects all in-domain rows; no covariance-specific warning.
    18. Replicate near-constant pair with tiny negative replicate residual returns `se = 0` (not `NaN`) via the existing `max(0, v)` guard; no extra warning.
    19. CI crosses zero when point estimate near zero with wide SE — bounds returned as-is, not clamped.
    20. `name_style = "broom"` renames `covariance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high` (columns + `label` attrs).
    21. `n_weighted` column equals manual weighted sum at `1e-10` (including diagonal-row per-variable counts).
    22. Every output column has a non-`NULL` `label` attribute matching the spec table exactly; CI labels are conf-level-interpolated.
    23. `.meta` top-level keys equal exactly `{group, x, design_class, method, conf_level, name_style, min_cell_n, redundant, diagonal, na_rm}`; no `function_name` or `variable` keys; `.meta$method == "covariance"`; `.meta$x` has one entry per focal variable in supply order; `.meta$group` empty when no grouping, populated when grouping.
    24. `var1` / `var2` factor-level order equals supply order in every case (all four flag combinations).
    25. `label_vars = TRUE` substitutes variable labels; `label_vars = FALSE` keeps raw names; fallback when label unset.
    26. `decimals = 3` rounds every numeric column exactly.
    27. `deff` parity at `1e-8` against the manual Goodnight / Mood-Graybill denominator.
    28. Pair-generation rules: all four `redundant` × `diagonal` combinations yield the expected rowsets on a 4-variable input (`6`, `12`, `10`, `16` rows respectively) with exact ordered pair-list equality.
    29. `surveycore_warning_small_cell` fires under dual pattern when any pair's `n < 30L`.
    30. `surveycore_warning_single_level` fires when grouping variable has one observed level (class check).
    31. `surveycore_warning_covariance_non_numeric` fires under dual pattern when a non-numeric variable is dropped from `x`.
    32. `surveycore_warning_covariance_all_na` fires under dual pattern when a pair is all-NA; also fires on the disjoint-NA trigger path and on the diagonal-all-NA path. Result has `covariance = NaN`, all uncertainty cols `NaN`, `n = 0L`.
    33. `surveycore_warning_covariance_insufficient_n` fires under dual pattern when a pair has exactly 1 pairwise-complete row. Result has `covariance = NaN`, all uncertainty cols `NaN`, `n = 1L`.
    34. `surveycore_warning_cv_undefined` fires when `variance = "cv"` requested and at least one row has `covariance = 0`. Result row has `cv = NA`.
    35. `survey_collection` happy path: row-binds per-survey output with `.survey` id column at per-survey parity `1e-10` / `1e-8`; `.meta$per_survey` absent when metadata agrees; custom `.id = "wave"` column replaces `.survey` when set.
    36. `surveycore_message_collection_skipped_surveys` fires under `.on_missing = "skip"` with one survey missing the var (C9).
    37. `surveycore_warning_collection_meta_divergence` fires with `meta(result)$per_survey` present (C11).
    38. `surveycore_warning_collection_duplicate_name_repaired` fires on duplicate names (C2a).
    39. Dual-pattern green for all error classes: `unsupported_class`, `insufficient_variables` (4 trigger paths), `invalid_variance_arg`, `invalid_conf_level` (3), `invalid_decimals` (2), `invalid_name_style`, `na_rm_not_logical` (2), `collection_missing_var` (C5), `collection_all_skipped` (C6), `collection_id_collision` (C7, two collision columns), `collection_invalid_id` (C13, two cases), `variable_not_found` (C10).
    40. Print method and broom `tidy` / `glance` adapters dispatch without error on single-pair and multi-pair results — `print(result)` returns invisibly; `broom::tidy(result)` returns a tibble; `broom::glance(result)` returns a 1-row tibble with the expected columns. (Covered under the per-family class invariant in `test-spec.md §Invariants`; smoke tests are added alongside the method/adapter registrations in tasks 66–67.)
    41. `test_invariants(design)` is the first assertion of every test that constructs a survey design; collection tests additionally assert `test_invariants()` on each component survey.
    42. `R CMD check --as-cran`: 0 errors, 0 warnings, ≤2 pre-approved notes.
    43. `devtools::document()` is idempotent after commit (re-running produces no diff).
    44. Pre-existing test suite remains fully green (no regression from the `.apply_name_style()` and `analysis-meta.R` edits).
    45. `plans/error-messages.md` contains the three new rows CV-1 / CV-2 / CV-3 with class names, registry row numbers, and CLI templates in the canonical format.

  - **Files touched** — exact write surface

    | File | Action |
    |---|---|
    | `R/analysis-covariance.R` | created (exported `get_covariance()`, argument validation, dispatch to pair helpers, multi-pair iteration, pair expansion under `redundant` / `diagonal`, result assembly) |
    | `R/analysis-covariance-helpers.R` | created (`.covariance_pair_taylor()`, `.covariance_pair_replicate()`, `.covariance_pair_twophase()`, `.covariance_pair_nonprob()`, `.covariance_pair_result()` dispatch wrapper, `.attach_covariance_labels()`) |
    | `R/analysis-meta.R` | modified (register `COVARIANCE_META_KEYS <- c(FAMILY_META_KEYS, "method")` and the `survey_covariance` meta constructor) |
    | `R/analysis-helpers.R` | modified (extend `.apply_name_style()` broom rename map with `covariance = "estimate"`) |
    | `R/methods-print.R` | modified (add `survey_covariance` print method) |
    | `R/methods-compat.R` | modified (broom `tidy` / `glance` adapter for `survey_covariance`) |
    | `NAMESPACE` | regenerated |
    | `man/get_covariance.Rd` | generated |
    | `DESCRIPTION` | modified (version bump to `0.7.2.9000`) |
    | `NEWS.md` | modified (dev-version entry naming `get_covariance()`, `survey_covariance` class, CV-1 / CV-2 / CV-3) |
    | `plans/error-messages.md` | modified (append CV-1 `surveycore_warning_covariance_all_na`, CV-2 `surveycore_warning_covariance_insufficient_n`, CV-3 `surveycore_warning_covariance_non_numeric`) |
    | `tests/testthat/test-analysis-covariance.R` | created (all PR 1 tests: happy path + multi-variable + pair-generation rules + four flag combos + grouping + constant + broom + n_weighted + labels + meta + decimals + deff + diagonal-parity on all five designs + symmetry + collection happy/skip/error/divergence/duplicate + error paths + warning paths + edge cases + print/broom smoke) |
    | `tests/testthat/_snaps/analysis-covariance.md` | created (error and warning snapshots generated by testthat) |

    **Test-file convention waiver**: `R/analysis-covariance-helpers.R` does **not** get its own `test-analysis-covariance-helpers.R`. Per `.claude/rules/testing-surveycore.md` (precedent: `R/07-utils.R`, `R/analysis-variance-helpers.R` from PR 1 of `get_variance()`), helper files may be covered inline by the parent module's test file when the helpers are exclusively private and exclusively reachable through the public function. The four `.covariance_pair_*()` engines, `.covariance_pair_result()`, and `.attach_covariance_labels()` are tested indirectly through `get_covariance()` per the project's "Testing private functions" rule (default to indirect; direct only when public-API coverage is genuinely unreachable).

  - **Pipeline split**: recommended

## Test-spec coverage map

Every row family in `test-spec.md` is scheduled under exactly one PR:

| `test-spec.md` row family | PR |
|---|---|
| Happy path: Taylor single-pair point + SE + CI | PR 1 |
| Happy path: Taylor three-variable, all four `redundant` × `diagonal` combinations | PR 1 |
| Happy path: replicate (BRR) parity | PR 1 |
| Happy path: twophase parity | PR 1 |
| Happy path: nonprob parity | PR 1 |
| Happy path: internal consistency diagonal vs `get_variance()` (point + SE) | PR 1 |
| Happy path: **diagonal-parity quality gate** (Taylor, replicate, twophase, nonprob, collection) | PR 1 |
| Happy path: symmetry `(x, y) == (y, x)` (between calls + within `redundant = TRUE`) | PR 1 |
| Happy path: grouped via `group_by()` + via `group =` | PR 1 |
| Happy path: constant-variable → exact `0` | PR 1 |
| Happy path: `name_style = "broom"` rename | PR 1 |
| Happy path: `n_weighted = TRUE` | PR 1 |
| Happy path: column-level `label` attrs | PR 1 |
| Happy path: `.meta` top-level + `$x` + `$group` + `$method` | PR 1 |
| Happy path: `var1`/`var2` factor-level supply order | PR 1 |
| Happy path: `label_vars` on/off | PR 1 |
| Happy path: `decimals = 3` rounding | PR 1 |
| Happy path: `deff` parity (Goodnight / Mood-Graybill) | PR 1 |
| Happy path: pair-generation rules (all four flag combinations, 4-variable input) | PR 1 |
| Happy path: `survey_collection` dispatch (default `.id`, custom `.id`, `.on_missing = "skip"`) | PR 1 |
| Error: `unsupported_class` / `insufficient_variables` (4 trigger paths) / `invalid_variance_arg` / `invalid_conf_level` (3) / `invalid_decimals` (2) / `invalid_name_style` / `na_rm_not_logical` (2) | PR 1 |
| Error: `collection_missing_var` / `collection_all_skipped` / `collection_id_collision` (2 columns) / `collection_invalid_id` (2 cases) / `variable_not_found` (per-survey) | PR 1 |
| Warning: `small_cell` / `single_level` / `cv_undefined` / `covariance_non_numeric` (CV-3) / `covariance_all_na` (CV-1, three trigger paths including diagonal) / `covariance_insufficient_n` (CV-2) | PR 1 |
| Warning (collection): `collection_skipped_surveys` (message, C9) / `collection_meta_divergence` (C11) / `collection_duplicate_name_repaired` (C2a) | PR 1 |
| Edge: empty `x` / 1-numeric-after-drop / all-NA pair / single-obs pair / constant / both-constant / `na.rm = FALSE` / single-level group | PR 1 |
| Edge: nonprob zero-weight / twophase Phase-1-only / replicate tiny-negative residual | PR 1 |
| Edge: CI crosses zero (not clamped) | PR 1 |
| Edge: `diagonal = TRUE` semantic divergence from `get_corr()` / `diagonal = TRUE` with all-NA variable | PR 1 |
| Edge: `redundant = TRUE` within-call symmetry / all four `redundant`×`diagonal` rowset counts | PR 1 |
| Edge: collection all-missing → `collection_all_skipped` error / collection per-survey meta divergence | PR 1 |
| Invariants block (applies to every test) | PR 1 |
| Tolerances block (applies to every test) | PR 1 |
| Profile gates block | PR 1 |

## Spec contract coverage map

Every item in `spec.md §Function contracts` is covered by at least one PR 1 acceptance criterion:

| Contract item | PR | Acceptance criterion |
|---|---|---|
| Signature (16 args including `...`, `.id`, `.on_missing`) | PR 1 | Covered by task 10 and all downstream argument tests |
| Arguments — `design` (5 classes + unsupported) | PR 1 | 1–11, 35, 39 |
| Arguments — `x` (tidy-select, ≥2 numeric after drop, error if not) | PR 1 | 39 (insufficient_variables 4 paths) |
| Arguments — `group` (via `group_by()` and `group =`) | PR 1 | 14 |
| Arguments — `redundant` / `diagonal` (all four flag combinations) | PR 1 | 3, 4, 5, 28 |
| Arguments — `variance` (subset of 6 opt-in cols, `NULL`) | PR 1 | 22 (every label present) + 39 (invalid_variance_arg) |
| Arguments — `conf_level` (scalar in `(0, 1)`) | PR 1 | 39 (invalid_conf_level 3 cases) + 1 (CI) |
| Arguments — `n_weighted` | PR 1 | 21 |
| Arguments — `decimals` | PR 1 | 26, 39 (invalid_decimals 2 cases) |
| Arguments — `min_cell_n` | PR 1 | 29 |
| Arguments — `na.rm` (pairwise-only; no `na_handling`) | PR 1 | 17 + 39 (na_rm_not_logical 2 cases) |
| Arguments — `label_values` / `label_vars` | PR 1 | 25 |
| Arguments — `name_style` (`"surveycore"` + `"broom"`) | PR 1 | 20 + 39 (invalid_name_style) |
| Arguments — `.id` / `.on_missing` | PR 1 | 35, 36, 39 (collection_invalid_id, collection_id_collision) |
| Returns — class `c("survey_covariance", "survey_result", "tbl_df", "tbl", "data.frame")` | PR 1 | Invariants across all tests |
| Returns — column order + factor `var1` / `var2` | PR 1 | 24 |
| Returns — uncertainty columns opt-in via `variance` | PR 1 | 20, 22 |
| Returns — `n` / `n_weighted` semantics (incl. diagonal per-variable count) | PR 1 | 21 |
| Returns — pair generation rules (4 combos) | PR 1 | 28 |
| Returns — column-level `label` attributes (full table) | PR 1 | 22 |
| Returns — `.meta` nested shape + `method = "covariance"` | PR 1 | 23 |
| Returns — `.meta$per_survey` present only on collection meta divergence | PR 1 | 37 |
| Errors (13 rows) | PR 1 | 39 |
| Warnings (10 rows, including 3 new CV-1/CV-2/CV-3) | PR 1 | 29–34, 36–38 |
| Edge cases (17 rows) | PR 1 | 15–19, 32, 33 + dedicated edge tests |

## HOLDs raised

None. All four spec HOLDs are resolved in `decisions.md`. Every error and warning class the plan references either already exists in `plans/error-messages.md` or is added by the dedicated task 3 (CV-1, CV-2, CV-3). The single-PR shape matches the spec recommendation; no concrete blocker requires splitting.
