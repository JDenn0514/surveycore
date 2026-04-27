# Test-spec — get-covariance

## Reference oracle

- `survey::svyvar()` — authoritative oracle for point and SE values
  across `survey_taylor`, `survey_replicate`, and `survey_twophase`
  numerical-parity tests. The off-diagonal entries of
  `survey::svyvar(~x + y + ..., design, na.rm = TRUE)` are compared
  against `get_covariance()` row-by-row.
- `survey::svyvar()` also serves as the diagonal oracle for
  `diagonal = TRUE` self-pairs: the diagonal of `svyvar()` is the
  variance, which is what `get_covariance()` is specified to return on
  the diagonal.
- `surveycore::get_variance()` — secondary oracle for internal
  consistency. For a single variable `v`,
  `get_covariance(design, c(v, v), diagonal = TRUE)` must return the
  same point estimate (to `1e-10`) and SE (to `1e-8`) as
  `get_variance(design, v)` on the same active domain.
- `surveycore::get_covariance()` itself is the symmetry oracle: for
  any off-diagonal pair,
  `get_covariance(design, c(x, y))$covariance` must equal
  `get_covariance(design, c(y, x))$covariance` (and similarly for SE)
  to the project tolerance.
- Nonprob parity uses `survey::svydesign(ids = ~1, weights = ~w)` as
  the oracle (nonprob-with-weights is treated as a one-stage
  SRS-with-weights design for off-diagonal `svyvar()` purposes).
- `survey` package version: whichever the project's `DESCRIPTION`
  Suggests pins (do not hard-code). Tests wrap oracle calls in
  `skip_if_not_installed("survey")` at the block level.

## Datasets

| Dataset | Purpose |
|---|---|
| `nhanes_2017` (project data) | Stratified clustered Taylor-design parity tests against `survey::svyvar()` off-diagonals, using `ridageyr`, `bpxsy1`, and a third numeric variable as focal. Also used for the `svyvar()` parity test against a 3-variable call. |
| `acs_pums_wy` (project data) | Replicate-weight (BRR or JK1/JKn, whichever is configured in the dataset) parity tests against `survey::svyvar()` on the replicate design path. |
| `make_survey_data(n = 500, seed = 42, design = "twophase")` | Synthetic twophase design for numerical parity on the twophase path (Phase 1 rows vs Phase 2 rows) and for invariant checks. |
| `make_survey_data(n = 400, seed = 11, design = "taylor")` | Synthetic Taylor design for edge-case tests (all-NA pair, single-observation pair, constant variable, small-cell warnings, single-level grouping, non-numeric drop) where exact control of values is easier than with real data. |
| `make_survey_data(n = 400, seed = 11, design = "taylor", with_labels = TRUE)` | Metadata / label propagation, `label_values`, `label_vars`, `.meta` nested-shape tests, and column-level `label` attribute checks. |
| `make_survey_data(n = 300, seed = 99, design = "replicate", type = "BRR")` | Synthetic replicate design for replicate-path edge cases (tiny-negative replicate residual on near-constant variable) and for dispatch tests separate from the ACS parity check. |
| `make_survey_data(n = 200, seed = 5, design = "nonprob")` (or equivalent constructor) with some zero-weight rows and some strictly positive weights | Nonprob edge-case tests including zero-weight-row exclusion and all-NA-pair behaviour. |
| Inline `data.frame` with explicit NA patterns | Edge-case tests for `na.rm = FALSE`, pair-specific complete-case domains, differing per-pair `n`, and empty domain after group filtering. |
| Inline `data.frame` with one constant column (e.g. `y = rep(5, n)`) and one varying column | Zero-variance edge-case tests: `covariance = 0, se = 0`, no warning. |
| A two-survey `survey_collection` built from `make_survey_data()` twice with different seeds, one survey missing a focal variable | `survey_collection` dispatch: happy path, `.on_missing = "skip"`, `.on_missing = "error"`, `.id` collision, meta divergence, all-skipped. |

## Per-function test plan

### `get_covariance()`

#### Happy path

| Scenario | Dataset | Oracle | Tolerance |
|---|---|---|---|
| Single pair, Taylor design, no group — point estimate | `nhanes_2017` wrapped as `survey_taylor` (`ids = sdmvpsu`, `strata = sdmvstra`, `weights = wtint2yr`, `nest = TRUE`) with `x = c(ridageyr, bpxsy1)` | `survey::svyvar(~ridageyr + bpxsy1, design, na.rm = TRUE)[1, 2]` | point `1e-10` |
| Single pair, Taylor design, no group — SE | Same | `survey::vcov(survey::svyvar(~ridageyr + bpxsy1, design, na.rm = TRUE))` off-diagonal element — specifically `sqrt(diag(vcov)[name_of_xy_off_diagonal_entry])` computed via the same path `svyvar()` exposes | SE `1e-8` |
| Single pair, Taylor — default Wald CI | Same | Manual: `coef ± qnorm(0.975) * SE` computed from oracle | CI `1e-6` |
| Three-variable input, Taylor, lower-triangle default (3 pairs) | `nhanes_2017` with `c(ridageyr, bpxsy1, <third numeric>)` | All three off-diagonal entries of `survey::svyvar(~v1 + v2 + v3, design, na.rm = TRUE)` | point `1e-10`, SE `1e-8` |
| Three-variable input, `redundant = TRUE` (6 off-diagonal rows) | Same | Each `(i, j)` and `(j, i)` row matches the same oracle off-diagonal; all-pairs consistency | point `1e-10`, SE `1e-8` |
| Three-variable input, `diagonal = TRUE` (6 rows: 3 off-diag + 3 diagonal) | Same | Off-diagonals: `svyvar()` off-diagonal entries. Diagonals: `svyvar()` diagonal entries (= variance) — these are also compared against `get_variance(design, v)$variance` | point `1e-10`, SE `1e-8` |
| Three-variable input, `redundant = TRUE, diagonal = TRUE` (9 rows) | Same | Union of the two preceding oracles | point `1e-10`, SE `1e-8` |
| Replicate (BRR) parity — point and SE | `acs_pums_wy` wrapped as `survey_replicate`, two focal vars | `survey::svyvar(~v1 + v2, design, na.rm = TRUE)[1, 2]` | point `1e-10`, SE `1e-8` |
| Twophase parity — point and SE | Synthetic twophase (Phase 1 + Phase 2 membership via `make_survey_data(design = "twophase")`), two focal vars | `survey::svyvar(~v1 + v2, design, na.rm = TRUE)` off-diagonal on a `survey::twophase()` design built from the same data | point `1e-10`, SE `1e-8` |
| Nonprob parity — point and SE | Synthetic nonprob (weights only, no ids/strata), two focal vars | `survey::svyvar(~v1 + v2, svydesign(ids = ~1, weights = ~w, data))` off-diagonal | point `1e-10`, SE `1e-8` |
| Internal consistency: `get_covariance(design, c(v, v), diagonal = TRUE)$covariance` == `get_variance(design, v)$variance` | Synthetic Taylor | `surveycore::get_variance(design, v)` on the same design | point `1e-10` |
| Internal consistency SE: diagonal-pair SE == `get_variance(design, v)$se` | Synthetic Taylor | Same | SE `1e-8` |
| **Diagonal-parity quality gate (Taylor)**: under `diagonal = TRUE`, `get_covariance(d, c(x, x))$covariance` and `$se` numerically equal `get_variance(d, x)$variance` and `$se` on identical active domains | Synthetic Taylor (`make_survey_data(design = "taylor")`) | `surveycore::get_variance(d, x)` on the same design | point `1e-10`, SE `1e-8` |
| **Diagonal-parity quality gate (replicate)**: same assertion, replicate design | Synthetic replicate (`make_survey_data(design = "replicate", type = "BRR")`) | `surveycore::get_variance(d, x)` on the same design | point `1e-10`, SE `1e-8` |
| **Diagonal-parity quality gate (twophase)**: same assertion, twophase design | Synthetic twophase (`make_survey_data(design = "twophase")`) | `surveycore::get_variance(d, x)` on the same design | point `1e-10`, SE `1e-8` |
| **Diagonal-parity quality gate (nonprob)**: same assertion, nonprob design | Synthetic nonprob (`make_survey_data(design = "nonprob")`) | `surveycore::get_variance(d, x)` on the same design | point `1e-10`, SE `1e-8` |
| **Diagonal-parity quality gate (collection)**: same assertion applied per-survey within a two-survey `survey_collection`; each per-survey diagonal row matches the corresponding `get_variance()` call | Two-survey synthetic collection | `surveycore::get_variance()` per survey | point `1e-10`, SE `1e-8` |
| Symmetry: `get_covariance(design, c(x, y))$covariance` == `get_covariance(design, c(y, x))$covariance` for an off-diagonal pair | Synthetic Taylor | `get_covariance()` itself, swapped inputs | point `1e-10` |
| Symmetry SE: off-diagonal `(x, y)` SE == `(y, x)` SE | Synthetic Taylor | Same | SE `1e-8` |
| Grouped estimate, Taylor, `group_by()` active | Synthetic labelled | `survey::svyby(~v1 + v2, ~g, design, survey::svyvar, na.rm = TRUE)` (extract off-diagonals per group) | point `1e-10`, SE `1e-8` |
| Grouped estimate via `group =` argument | Synthetic labelled | Same as above | point `1e-10`, SE `1e-8` |
| Constant variable in pair returns `covariance = 0`, `se = 0` (no warning) | Inline data frame with `y = rep(5, n)`, `x = runif(n)` | No oracle; check exact `0`s and absence of covariance-specific warning | exact equality |
| `name_style = "broom"` renames `covariance → estimate`, `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high` | Any happy-path dataset | Column-name assertion | — |
| `n_weighted = TRUE` appends `n_weighted` column equal to sum of weights over the pair's pairwise-complete active domain | Synthetic labelled | Manually computed weighted sum on the pair's complete-case mask | `1e-10` |
| Column-level `label` attributes present on every output column | Synthetic labelled | `attr(col, "label")` not `NULL` and matches expected string for each of: `var1`, `var2`, `covariance`, `se`, `ci_low`, `ci_high`, `n`, `n_weighted` | — |
| `.meta` structure: top-level keys are exactly `group`, `x`, `design_class`, `method`, `conf_level`, `name_style`, `min_cell_n`, `redundant`, `diagonal`, `na_rm` (no `function_name` or `variable` keys) | Synthetic labelled | Structural assertion | — |
| `.meta$method == "covariance"` | Any happy path | `expect_identical(meta(result)$method, "covariance")` | — |
| `.meta$x` has one entry per resolved numeric variable in supply order, with `variable_label`, `question_preface`, `value_labels` sub-keys | Synthetic labelled | Structural assertion | — |
| `.meta$group` empty when no group, populated when group active | Synthetic labelled | Structural assertion | — |
| `var1` and `var2` are factors with levels in supply order | Synthetic labelled | `levels(result$var1)` and `levels(result$var2)` equal supplied variable order | — |
| `label_vars = TRUE` substitutes variable labels in the factor levels for `var1` / `var2` when labels are set; `label_vars = FALSE` uses raw names | Synthetic labelled | String equality | — |
| `decimals = 3` rounds all numeric output columns to 3 decimals | Any happy path | Column equality to manually rounded oracle output | exact equality after rounding |
| `deff` column equals `Var̂(V̂_cov) / ((Var̂(x) · Var̂(y) + cov̂²) / (n − 1))` (Goodnight / Mood-Graybill SRS reference) | Synthetic labelled, Taylor | Manual computation of both numerator (from `get_covariance()` `var` column) and denominator (from `get_variance()` on each variable, the `covariance` point estimate, and the pair's `n`) | `1e-8` |
| Pair generation: default flags emit `|vars|·(|vars|−1)/2` rows per group stratum in lower-triangle supply order | Synthetic labelled, 4-variable `x` | `nrow()` assertion + ordered pair-list equality | — |
| Pair generation: `redundant = TRUE, diagonal = FALSE` emits `|vars|·(|vars|−1)` rows | Same | `nrow()` + ordered pair-list | — |
| Pair generation: `redundant = FALSE, diagonal = TRUE` emits `|vars|·(|vars|+1)/2` rows | Same | `nrow()` + pair-list | — |
| Pair generation: `redundant = TRUE, diagonal = TRUE` emits `|vars|²` rows | Same | `nrow()` + pair-list | — |
| `survey_collection` dispatch happy path — default `.id = ".survey"`, `.on_missing = "error"`, all surveys contain both focal vars | Two-survey collection, both surveys contain both focal vars | Per-survey `get_covariance()` on each, row-bound, with `.survey` id column equal to survey name. Assert row count (= per-survey rows summed), `.meta` top-level keys present, `.meta$per_survey` absent when metadata agrees, `.id` column values match survey names. | point `1e-10`, SE `1e-8` |
| `survey_collection` dispatch with custom `.id = "wave"` | Two-survey collection, both contain both focal vars | Column named `wave` present; no `.survey` column | Structural |
| `survey_collection` dispatch with `.on_missing = "skip"` and one survey missing a focal var | Two-survey collection, second survey missing `bpxsy1` | Result contains rows from first survey only; `surveycore_message_collection_skipped_surveys` fires | `expect_message` + structural |

#### Error paths

Every error row uses the **dual assertion pattern** required by
`testing-surveycore.md`:
`expect_error(class = "surveycore_error_…")` **plus**
`expect_snapshot(error = TRUE, <call>)`. The `class=` check verifies the
thrown class; the snapshot pins the CLI-formatted message text. Both are
required — neither substitutes for the other.

| Condition | Error class | Assertion pattern |
|---|---|---|
| `design` is not a recognized survey class (e.g. plain `data.frame`) | `surveycore_error_unsupported_class` | Dual pattern (`expect_error(class=)` + `expect_snapshot(error = TRUE)`) |
| `x` resolves to 0 columns | `surveycore_error_insufficient_variables` | Dual |
| `x` resolves to 1 column | `surveycore_error_insufficient_variables` | Dual |
| `x` resolves to 2 columns, one numeric and one non-numeric → after dropping, only 1 remains | `surveycore_error_insufficient_variables` (after the non-numeric-drop warning) | Dual (expect both the warning and the error; the error is the hard failure) |
| `variance` contains an invalid value (e.g. `"foo"`) | `surveycore_error_invalid_variance_arg` | Dual |
| `conf_level = 0` | `surveycore_error_invalid_conf_level` | Dual |
| `conf_level = 1` | `surveycore_error_invalid_conf_level` | Dual |
| `conf_level = NA` | `surveycore_error_invalid_conf_level` | Dual |
| `decimals = -1` | `surveycore_error_invalid_decimals` | Dual |
| `decimals = 1.5` | `surveycore_error_invalid_decimals` | Dual |
| `name_style = "foo"` | `surveycore_error_invalid_name_style` | Dual |
| `na.rm = NA` | `surveycore_error_na_rm_not_logical` | Dual |
| `na.rm = 1` | `surveycore_error_na_rm_not_logical` | Dual |
| Collection: requested variable missing, `.on_missing = "error"` | `surveycore_error_collection_missing_var` | Dual |
| Collection: all surveys skipped | `surveycore_error_collection_all_skipped` | Dual |
| Collection: `.id` collides with a produced column name (`"var1"`, `"var2"`, `"covariance"`, etc.) | `surveycore_error_collection_id_collision` | Dual |
| Collection: `.id = ""` | `surveycore_error_collection_invalid_id` | Dual |
| Collection: `.id = c("a", "b")` | `surveycore_error_collection_invalid_id` | Dual |
| Per-survey collection path with variable not in design | `surveycore_error_variable_not_found` | Dual |

#### Warnings

For each of the four covariance-family warning classes — `small_cell`,
`covariance_all_na` (CV-1), `covariance_insufficient_n` (CV-2), and
`covariance_non_numeric` (CV-3) — tests must apply the **dual assertion
pattern**: `expect_warning(class = "surveycore_warning_…")` **plus**
`expect_snapshot(<call>)` to pin the CLI-formatted message text. Other
warnings in the table (inherited from the shared family) already have
snapshot coverage via their owning test files and need only the
`class=` check here.

| Condition | Warning class | Assertion pattern |
|---|---|---|
| Any pair has `n < min_cell_n` | `surveycore_warning_small_cell` | Dual (`expect_warning(class=)` + `expect_snapshot()`) + result-shape check |
| Grouping variable has a single observed level in the active domain | `surveycore_warning_single_level` | `expect_warning(class = ...)` |
| A non-numeric variable is present in `x` and is silently dropped (with at least 2 numeric variables remaining) | `surveycore_warning_covariance_non_numeric` | Dual (`expect_warning(class=)` + `expect_snapshot()`) |
| `variance = "cv"` requested and at least one pair has `covariance = 0` (constant-variable case) | `surveycore_warning_cv_undefined` | `expect_warning(class = ...)` |
| Pair is all-NA in the active domain with `na.rm = TRUE` | `surveycore_warning_covariance_all_na` | Dual (`expect_warning(class=)` + `expect_snapshot()`) + result has `covariance = NaN`, `n = 0` |
| Pair has exactly 1 pairwise-complete row in the active domain | `surveycore_warning_covariance_insufficient_n` | Dual (`expect_warning(class=)` + `expect_snapshot()`) + result has `covariance = NaN`, `n = 1` |
| Pair has 0 pairwise-complete rows in the active domain (different triggering pattern from above — e.g. disjoint NA patterns) | `surveycore_warning_covariance_all_na` | `expect_warning(class = ...)` (snapshot already pinned above) |
| `diagonal = TRUE` with an all-NA variable | `surveycore_warning_covariance_all_na` | `expect_warning(class = ...)` + diagonal row has `covariance = NaN`, `n = 0` |
| Collection: surveys skipped with `.on_missing = "skip"` | `surveycore_message_collection_skipped_surveys` | `expect_message(class = ...)` |
| Collection: per-survey `.meta` diverges for same variable | `surveycore_warning_collection_meta_divergence` | `expect_warning(class = ...)` |
| Collection: duplicate survey names auto-repaired | `surveycore_warning_collection_duplicate_name_repaired` | `expect_warning(class = ...)` |

#### Edge cases (from spec)

| Edge case | Behaviour asserted | Assertion pattern |
|---|---|---|
| Empty `x` selection | Error, `surveycore_error_insufficient_variables` | Dual error |
| `x` with 1 numeric + 1 non-numeric → non-numeric warning then error | Warning fires, then error fires | `expect_warning` inside `expect_error` |
| All-NA pair (every row has ≥ 1 NA across the two variables) | `covariance = NaN`, all uncertainty cols `NaN`, `n = 0L`; `surveycore_warning_covariance_all_na` fires once | `expect_warning` + structural |
| Single pairwise-complete row | `covariance = NaN`, uncertainty cols `NaN`, `n = 1L`; `surveycore_warning_covariance_insufficient_n` fires | `expect_warning` + structural |
| Zero-variance variable in pair, `n ≥ 2` | `covariance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0`; `cv = NA` with `surveycore_warning_cv_undefined` fired (only when `"cv"` requested); no covariance-specific warning | Exact-equality structural + warning assertion |
| Both variables constant, `n ≥ 2` | Same as above: `covariance = 0`, `se = 0`; no warning | Structural |
| `na.rm = FALSE`, pair contains some NAs | `covariance = NaN`, `se = NaN`; `n` reflects all in-domain rows; no covariance-specific warning | Structural |
| Grouping variable with a single observed level | Single output row per emitted pair; `surveycore_warning_single_level` fires | `expect_warning` + `nrow` assertion |
| Zero-weight rows in a `survey_nonprob` design | Zero-weight rows excluded from `n` and from the pair's weighted means; parity with oracle where zero-weight rows are pre-filtered | Parity `1e-10` / `1e-8` |
| Twophase: Phase-1-only rows contribute zero influence | Parity with `survey::svyvar()` on `survey::twophase()`-wrapped design | Parity `1e-10` / `1e-8` |
| Replicate path: near-constant pair with tiny negative replicate residual | `se` returned as `0` (not `NaN`); no `sqrt(-eps)` warning from the engine | Exact equality + no extra warning |
| CI crosses zero when point estimate is near zero with wide SE | `ci_low` and `ci_high` returned as-is (may have opposite signs); not clamped | Structural; documented behaviour |
| `diagonal = TRUE` pair `(v, v)` — semantic divergence from `get_corr()` | `covariance == Var̂(v)` (not `1`); equals `get_variance(design, v)$variance` at the point tolerance; SE equals `get_variance()` SE at the SE tolerance; `n` is the per-variable non-NA count on the active domain, not a pairwise count | Structural equality + parity |
| `diagonal = TRUE` with all-NA variable | Self-pair has `covariance = NaN`, `n = 0`; `surveycore_warning_covariance_all_na` fires | `expect_warning` + structural |
| `redundant = TRUE` produces `(x, y)` and `(y, x)` with identical point and SE | Row equality at point tolerance and SE tolerance | Parity `1e-10` / `1e-8` |
| `redundant` and `diagonal` flag combinations yield correct rowsets | Exact `nrow()` values for all four flag combinations on a 4-variable input (6, 12, 10, 16 rows respectively) | Structural |
| `survey_collection`: all surveys missing a required variable → `surveycore_error_collection_all_skipped` | Error | Dual |
| `survey_collection`: per-survey `.meta` divergence | Warning fires; `meta(result)$per_survey` present | Structural + warning |

#### Invariants

- `test_invariants(design)` is the **first** assertion of every test
  that constructs a survey design via `as_survey()`, `as_survey_rep()`,
  `as_survey_twophase()`, or `as_survey_srs()`. This rule applies to
  every happy-path, edge-case, warning-path, and collection-path test
  that creates a design inline. Collection tests additionally assert
  `test_invariants()` on each component survey.
- For every successful call, the result must satisfy:
  - Inherits `c("survey_covariance", "survey_result", "tbl_df")`.
  - Contains a `covariance` column that is numeric (a finite real
    when the cell is defined; `0` when a variable is constant on the
    active domain; `NaN` when undefined).
  - Contains factor `var1` and factor `var2` columns whose levels are
    the supplied numeric-variable names in supply order.
  - Row count matches the pair-generation rule for the given
    `redundant` / `diagonal` combination and the number of resolved
    numeric variables.
  - Every output column has a non-`NULL` `label` attribute.
  - `names(meta(result)$x)` equals the resolved numeric variable
    names (in supply order).
  - `meta(result)$method == "covariance"`.
  - `meta(result)$redundant` equals the argument value.
  - `meta(result)$diagonal` equals the argument value.
  - `meta(result)$na_rm` equals the argument value.
  - `meta(result)$design_class` matches the design class (one of
    `"survey_taylor"`, `"survey_replicate"`, `"survey_twophase"`,
    `"survey_nonprob"`, `"survey_collection"`).
  - `meta(result)` does **not** contain `function_name` or `variable`
    keys (family parity).
  - No column named `var` exists unless `"var"` was passed in
    `variance`.
  - No column named `estimate` / `std.error` / `conf.low` /
    `conf.high` exists unless `name_style = "broom"`.
  - For off-diagonal pairs under `redundant = TRUE`, the rows
    `(x, y)` and `(y, x)` have numerically identical `covariance` and
    `se` (symmetry invariant).

## Tolerances

- Point estimates: `1e-10`
- SE / variance of the estimate: `1e-8`
- CI bounds: `1e-6`
- `deff` parity: `1e-8` (treated as an SE-like derived quantity)
- `n_weighted`: `1e-10` (sum of floats; tighter than SE)
- Rounding tests (`decimals`): exact equality after `round()`
- Constant-variable tests: exact equality to `0`
- Internal consistency (`get_covariance` diagonal vs `get_variance`):
  point `1e-10`, SE `1e-8`
- Symmetry (`get_covariance(x, y)` vs `get_covariance(y, x)`):
  point `1e-10`, SE `1e-8`

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
