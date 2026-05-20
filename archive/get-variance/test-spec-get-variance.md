# Test-spec — get-variance

## Reference oracle

- `survey::svyvar()` — authoritative oracle for point and SE values across
  `survey_taylor`, `survey_replicate`, and `survey_twophase` numerical
  parity tests.
- `survey::svymean()` applied to the derived score
  `z_i = (y_i - ȳ)^2 * n / (n-1)` — used only as a secondary confirmation
  oracle that the point estimate reduces to a weighted mean of the Kish-scaled
  centred-squared, and as the SRS comparator used in the `deff` parity check.
- `survey::svydesign(ids = ~1, weights = ~w)` for the `survey_nonprob` parity
  tests (nonprob-with-weights is treated as a one-stage SRS-with-weights
  design for oracle purposes).
- `survey` package version: whichever the project's `DESCRIPTION`
  Suggests pins (≥ 4.2-1 at time of writing; do not hard-code).
- Tests that compare against `survey::svyvar()` must wrap the oracle call
  in `skip_if_not_installed("survey")` at the block level.

## Datasets

| Dataset | Purpose |
|---|---|
| `nhanes_2017` (project data) | Stratified clustered Taylor-design parity tests against `survey::svyvar()` with `ridageyr` and `bpxsy1` as focal numeric variables. |
| `acs_pums_wy` (project data) | Replicate-weight (BRR) parity tests against `survey::svyvar()` on the replicate design path. |
| `make_survey_data(n = 500, seed = 42, design = "twophase")` | Synthetic twophase design for numerical parity on the twophase path (Phase 1 rows vs Phase 2 rows), and for invariant checks. |
| `make_survey_data(n = 400, seed = 11, design = "taylor")` | Synthetic Taylor design for edge-case tests (all-NA variable, single-obs variable, constant variable, small-cell warnings, single-level grouping, zero-weight rows) where exact control of values is easier than with real data. |
| `make_survey_data(n = 400, seed = 11, design = "taylor", with_labels = TRUE)` | Metadata / label propagation, `label_values`, `label_vars`, `.meta` nested-shape tests, and column-level `label` attribute checks. |
| `make_survey_data(n = 300, seed = 99, design = "replicate", type = "BRR")` | Synthetic replicate design for replicate-path edge cases (tiny-negative replicate residual on near-constant variable) and for dispatch tests separate from the ACS parity check. |
| Inline `data.frame` with explicit NA patterns | Edge-case tests for `na.rm = FALSE`, `na_handling = "pairwise"` vs `"listwise"` differing `n`, and empty domain after group filtering. |
| A two-survey `survey_collection` built from `make_survey_data()` twice with different seeds, one survey missing a focal variable | `survey_collection` dispatch: happy path, `.on_missing = "skip"`, `.on_missing = "error"`, `.id` collision, meta divergence. |

## Per-function test plan

### `get_variance()`

#### Happy path

| Scenario | Dataset | Oracle | Tolerance |
|---|---|---|---|
| Single numeric variable, Taylor design, no group — point estimate | `nhanes_2017` wrapped as `survey_taylor` with `ids = sdmvpsu`, `strata = sdmvstra`, `weights = wtint2yr`, `nest = TRUE` | `survey::svyvar(~ridageyr, design, na.rm = TRUE)` coefficient | point `1e-10` |
| Single numeric variable, Taylor design, no group — SE | Same as above | `survey::SE(survey::svyvar(~ridageyr, design, na.rm = TRUE))` | SE `1e-8` |
| Single numeric variable, Taylor design — default CI | Same | Manual: `coef ± qnorm(0.975) * SE` computed from oracle | CI `1e-6` |
| Multi-variable input, Taylor design, pairwise | `nhanes_2017` with `c(ridageyr, bpxsy1)` | Per-variable `svyvar(~ridageyr, ...)` and `svyvar(~bpxsy1, ...)` — separate calls, each with its own `na.rm = TRUE` (to match pairwise) | point `1e-10`, SE `1e-8` |
| Multi-variable input, Taylor design, listwise | Same input, `na_handling = "listwise"` | `survey::svyvar(~ridageyr + bpxsy1, design, na.rm = TRUE)` diagonal only | point `1e-10`, SE `1e-8` |
| Replicate (BRR) parity — point and SE | `acs_pums_wy` wrapped as `survey_replicate` | `survey::svyvar(~focal, design, na.rm = TRUE)` | point `1e-10`, SE `1e-8` |
| Twophase parity — point and SE | Synthetic twophase | `survey::svyvar(~focal, design, na.rm = TRUE)` on `survey::twophase()` design built from the same data | point `1e-10`, SE `1e-8` |
| Nonprob parity — point and SE | Synthetic nonprob (weights only, no ids/strata) | `survey::svyvar(~focal, svydesign(ids = ~1, weights = ~w, data))` | point `1e-10`, SE `1e-8` |
| Grouped estimate, Taylor, `group_by()` active | Synthetic labelled | `survey::svyby(~focal, ~g, design, survey::svyvar, na.rm = TRUE)` | point `1e-10`, SE `1e-8` |
| Grouped estimate via `group =` argument | Synthetic labelled | Same as above | point `1e-10`, SE `1e-8` |
| Constant variable returns `variance = 0`, `se = 0` | Inline `data.frame` with y = rep(5, n) | No oracle; check exact `0`s | exact equality |
| `name_style = "broom"` renames `variance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high` | Any happy-path dataset | Column-name assertion | — |
| `n_weighted = TRUE` appends `n_weighted` column equal to `sum(w[in_domain & !is.na(y) & w > 0])` | Synthetic labelled | Manually computed weighted sum | `1e-10` |
| Column-level `label` attributes present on every output column | Synthetic labelled | `attr(col, "label")` not `NULL` and matches expected string | — |
| `.meta` structure: top-level keys are exactly `group`, `x`, `design_class`, `conf_level`, `name_style`, `min_cell_n`, `na_handling` (no `function_name` or `variable` keys — family parity with `get_means()` / `get_freqs()`) | Synthetic labelled | Structural assertion: `expect_identical(sort(names(meta(result))), sort(c("group", "x", "design_class", "conf_level", "name_style", "min_cell_n", "na_handling")))` | — |
| `.meta$x` has one entry per focal variable with `variable_label`, `question_preface`, `value_labels` sub-keys | Synthetic labelled | Structural assertion | — |
| `.meta$group` empty when no group, populated when group active | Synthetic labelled | Structural assertion | — |
| `label_vars = TRUE` substitutes variable label for `name` column value; `label_vars = FALSE` keeps raw name | Synthetic labelled | String equality | — |
| `decimals = 3` rounds all numeric output columns to 3 decimals | Any happy path | Column equality to manually rounded oracle output | exact equality after rounding |
| `deff` column equals `var(V_hat) / var_srs(score)` where `score = (y - ȳ)^2 * n/(n-1)` | Synthetic labelled, Taylor | Manual computation using SRS variance of score via `survey::svymean((y-mean)^2 * n/(n-1), srs_design)` | `1e-8` |
| `survey_collection` dispatch happy path | Two-survey collection, both surveys contain focal var | Per-survey `get_variance()` on each, row-bound, with `.survey` id column equal to survey name | point `1e-10`, SE `1e-8` |

#### Error paths

| Condition | Error class | Assertion pattern |
|---|---|---|
| `design` is not a recognized survey class | `surveycore_error_unsupported_class` | Dual pattern (`expect_error(class=)` + `expect_snapshot(error = TRUE)`) |
| `x` resolves to 0 columns | `surveycore_error_wrong_variable_count` | Dual |
| A selected `x` column is non-numeric (factor) | `surveycore_error_non_numeric_variable` | Dual |
| A selected `x` column is non-numeric (character) | `surveycore_error_non_numeric_variable` | Dual |
| `variance` contains a value not in the valid set (e.g. `"foo"`) | `surveycore_error_invalid_variance_arg` | Dual |
| `conf_level = 0` | `surveycore_error_invalid_conf_level` | Dual |
| `conf_level = 1` | `surveycore_error_invalid_conf_level` | Dual |
| `conf_level = NA` | `surveycore_error_invalid_conf_level` | Dual |
| `decimals = -1` | `surveycore_error_invalid_decimals` | Dual |
| `decimals = 1.5` | `surveycore_error_invalid_decimals` | Dual |
| `name_style = "foo"` | `surveycore_error_invalid_name_style` | Dual |
| `na.rm = NA` | `surveycore_error_na_rm_not_logical` | Dual |
| `na.rm = 1` | `surveycore_error_na_rm_not_logical` | Dual |
| `na_handling = "foo"` | `match.arg()` error (class-free check) | `expect_error()` only (no snapshot, consistent with row 18 precedent) |
| Collection: requested variable missing, `.on_missing = "error"` | `surveycore_error_collection_missing_var` | Dual |
| Collection: all surveys skipped | `surveycore_error_collection_all_skipped` | Dual |
| Collection: `.id` collides with a produced column name (`"name"`, `"variance"`, etc.) | `surveycore_error_collection_id_collision` | Dual |
| Collection: `.id = ""` | `surveycore_error_collection_invalid_id` | Dual |
| Collection: `.id = c("a", "b")` | `surveycore_error_collection_invalid_id` | Dual |
| Per-survey collection path with variable not in design | `surveycore_error_variable_not_found` | Dual |

#### Warnings

| Condition | Warning class | Assertion pattern |
|---|---|---|
| `n < min_cell_n` for at least one row | `surveycore_warning_small_cell` | `expect_warning(class = ...)` |
| Grouping variable has a single observed level in the active domain | `surveycore_warning_single_level` | `expect_warning(class = ...)` |
| `variance = "cv"` requested and at least one row has `variance = 0` (constant) | `surveycore_warning_cv_undefined` | `expect_warning(class = ...)` |
| Focal variable all-NA in the active domain with `na.rm = TRUE` | `surveycore_warning_variance_all_na` | `expect_warning(class = ...)` + result has `variance = NaN`, `n = 0` |
| Focal variable has exactly 1 non-NA row in the active domain | `surveycore_warning_variance_insufficient_n` | `expect_warning(class = ...)` + result has `variance = NaN`, `n = 1` |
| Focal variable has 0 non-NA rows under `na_handling = "listwise"` (intersection empty) | `surveycore_warning_variance_all_na` | `expect_warning(class = ...)` |
| Collection: surveys skipped with `.on_missing = "skip"` | `surveycore_message_collection_skipped_surveys` | `expect_message(class = ...)` |
| Collection: per-survey `.meta` diverges for same variable | `surveycore_warning_collection_meta_divergence` | `expect_warning(class = ...)` |
| Collection: duplicate survey names auto-repaired | `surveycore_warning_collection_duplicate_name_repaired` | `expect_warning(class = ...)` |

#### Edge cases (from spec)

| Edge case | Behavior asserted | Assertion pattern |
|---|---|---|
| Empty `x` selection | Error (see above) | Dual error |
| All-NA focal variable with `na.rm = TRUE` | `variance = NaN`, all uncertainty cols `NaN`, `n = 0L`; `surveycore_warning_variance_all_na` fires once | `expect_warning` + structural |
| Single non-NA observation | `variance = NaN`, uncertainty cols `NaN`, `n = 1L`; `surveycore_warning_variance_insufficient_n` fires | `expect_warning` + structural |
| Constant (zero-variance) variable, `n ≥ 2` | `variance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0`; `cv = NA` with `surveycore_warning_cv_undefined` fired (only when `"cv"` requested); no variance-specific warning | Exact-equality structural + warning assertion |
| `na.rm = FALSE`, focal variable contains some NAs | `variance = NaN`, `se = NaN`; `n` reflects all in-domain rows; no variance-specific warning | Structural |
| Grouping variable with a single observed level | Single output row per focal variable; `surveycore_warning_single_level` fires | `expect_warning` + `nrow` assertion |
| `na_handling = "listwise"` with some rows NA in one variable | All output rows share the same `n`; each `n` equals the intersection complete-case count | Structural |
| `na_handling = "pairwise"` with rows NA in different variables | Per-variable `n` differs across rows; no shared-`n` constraint | Structural |
| Zero-weight rows in a `survey_nonprob` design | Zero-weight rows excluded from `n`; parity with oracle where zero-weight rows are pre-filtered | Parity `1e-10` / `1e-8` |
| Twophase: Phase 1-only rows contribute zero influence | Parity with `survey::svyvar()` on the `survey::twophase()`-wrapped design | Parity `1e-10` / `1e-8` |
| Replicate path: near-constant variable with tiny negative replicate residual | `se` returned as `0` (not `NaN`); no `sqrt(-eps)` warning | Exact equality + no extra warning |
| CI below zero for variance near 0 with wide SE | `ci_low` returned as-is (may be negative); not clamped | Structural; documented behavior |
| `survey_collection`: all surveys missing variable → `surveycore_error_collection_all_skipped` | Error | Dual |
| `survey_collection`: per-survey `.meta` divergence | Warning fires; `meta(result)$per_survey` present | Structural + warning |

#### Invariants

- `test_invariants(design)` is the **first** assertion of every test that constructs a survey design via `as_survey()`, `as_survey_rep()`, `as_survey_twophase()`, or `as_survey_srs()`. This rule applies to every happy-path, edge-case, warning-path, and collection-path test that creates a design inline. Collection tests additionally assert `test_invariants()` on each component survey.
- For every successful call, the result must satisfy:
  - Inherits `c("survey_variance", "survey_result", "tbl_df")`.
  - Contains a `variance` column that is numeric (not `NA_real_` when the cell is defined; `NaN` when undefined).
  - Contains a `name` column of length = number of focal variables × number of active group combinations (or just number of focal variables when no grouping active).
  - Every output column has a non-`NULL` `label` attribute.
  - `names(meta(result)$x)` equals the resolved variable names.
  - `meta(result)$na_handling %in% c("pairwise", "listwise")` matches the argument.
  - `meta(result)$design_class` matches the design class (one of `"survey_taylor"`, `"survey_replicate"`, `"survey_twophase"`, `"survey_nonprob"`, `"survey_collection"`).
  - `meta(result)` does **not** contain `function_name` or `variable` keys (family parity).
  - No column named `var` exists unless `"var"` was passed in `variance`.
  - No column named `estimate` / `std.error` / `conf.low` / `conf.high` exists unless `name_style = "broom"`.

## Tolerances

- Point estimates: `1e-10`
- SE / variance of the estimate: `1e-8`
- CI bounds: `1e-6`
- `deff` parity: `1e-8` (treated as an SE-like derived quantity)
- `n_weighted`: `1e-10` (sum of floats; tighter than SE)
- Rounding tests (`decimals`): exact equality after `round()`
- Constant-variable tests: exact equality to `0`

No deviations from the project defaults.

## Profile gates

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgcheck PASS
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)
