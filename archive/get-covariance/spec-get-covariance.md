# Spec — get-covariance

**Status**: DRAFT
**Target version**: 0.7.2.9000
**PR range**: PR 1 (single-PR track recommended)

## Scope

### In

- A new exported analysis function `get_covariance()` that estimates the
  design-based finite-population Pearson covariance for every ordered pair
  of numeric variables in `x`. Matches `survey::svyvar()` off-diagonal
  pair-at-a-time semantics numerically — i.e., each pair is computed on
  its own pairwise-complete active domain — including the Kish `n/(n − 1)`
  finite-sample correction applied to the point estimate. (Note:
  `svyvar()` itself listwise-deletes across all requested variables when
  called with a multi-variable formula; numerical parity therefore only
  holds when oracle calls are made pair-at-a-time with `svyvar(~x + y, d)`
  per pair.)
- Dispatch across all currently supported survey design classes:
  `survey_taylor`, `survey_replicate`, `survey_twophase`,
  `survey_nonprob`, and `survey_collection` (via the standard `.id` /
  `.on_missing` reserved arguments).
- Design-based SE, the full family of opt-in uncertainty columns
  (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`), and the
  standard column-level `label` attributes required for gt integration.
- Nested `.meta` structure (`group` / `x`) matching the rest of the
  `get_*()` family, with a top-level `method = "covariance"` echoed for
  downstream consumers.
- `na.rm` control (scalar boolean) with pairwise complete-case handling
  per pair (no `na_handling` argument — pairwise is the only policy).
- Tidy, long-form output (one row per ordered variable pair) with
  `var1` / `var2` factor columns whose levels follow supply order.
- `redundant` and `diagonal` boolean controls governing which pairs are
  emitted.
- `deff` support via the Goodnight / Mood-Graybill SRS covariance-
  variance formula
  `SE_SRS(cov) = sqrt((Var(x) · Var(y) + cov^2) / (n − 1))`.

### Out

- Wide (matrix) format output. Long only.
- Polychoric covariance (`method = "polychoric"`). Deferred to a
  follow-up PR (see decisions.md HOLD 1). No `method` argument is added
  in this PR — the function is Pearson-only and has no `method`
  parameter.
- Listwise NA handling across all selected variables. Pairwise only —
  `na_handling` argument is not added.
- Covariance of non-numeric variables. Non-numeric columns are dropped
  with a warning, matching the `get_corr()` precedent.
- Wald CIs clamped to any range. Covariance is unbounded; bounds may be
  negative or cross zero and are returned as-is.
- Fisher-Z / variance-stabilising transforms on the CI. Normal-Wald on
  the SE is the only interval produced, matching `get_variance()`.
- A `get_cor_matrix()` wide-matrix wrapper.

## Architecture

- **Files touched**
  - `R/analysis-covariance.R` — created. Houses exported
    `get_covariance()`, argument validation, dispatch to the per-design
    pair helpers, multi-pair iteration, pair expansion under
    `redundant` / `diagonal`, result assembly, column labelling, and
    `name_style` application.
  - `R/analysis-covariance-helpers.R` — created. Houses the parallel
    engine: `.covariance_pair_taylor()`, `.covariance_pair_replicate()`,
    `.covariance_pair_twophase()`, `.covariance_pair_nonprob()`, and a
    dispatch wrapper `.covariance_pair_result()` that selects among
    them by design class. The engine mirrors the structure of
    `.score_variance()` / `.variance_cell()` used by `get_variance()`:
    for each pair `(x, y)` it constructs the Kish-scaled score
    `z_i = kish · (x_i − x̄)(y_i − ȳ)` on the active pairwise-complete
    domain (zero elsewhere) and runs that score through the existing
    Taylor / replicate / twophase / HT variance machinery that already
    powers `get_variance()`.

    **Replicate sub-contract.** `.covariance_pair_replicate()` accepts
    and forwards `mse`, `scale`, and `rscales` to `.svy_rep_var()`
    identically to `.replicate_variance_cell()` in `get_variance()` —
    the helper extracts these values from the `survey_replicate`
    design's `@variables` list and passes them through unchanged. No
    special-case branching for near-zero covariance or tiny-negative
    residual; the existing engine-level `max(0, v)` guard inside
    `sqrt()` handles the underflow case (same guard as `get_variance()`).

    **Pair-helper contract.** Every `.covariance_pair_{design}()` helper
    takes the same inputs and returns the same fields:
    - **Inputs**: `design` (the survey design object for the current
      design-class path), `x_col` (character scalar — name of the first
      variable in the pair), `y_col` (character scalar — name of the
      second variable), `domain` (numeric 0/1 vector of length
      `nrow(design@data)` — the pairwise-complete active-domain mask
      before Kish scaling), `na.rm` (logical scalar — echoed for
      downstream diagnostics; pairwise-complete construction of
      `domain` is done by the caller).
    - **Return**: a named list with fields
      - `covariance` — numeric scalar: the Kish-corrected point
        estimate on the pair's active domain.
      - `se` — numeric scalar: design-based SE of `covariance`.
      - `se_srs` — numeric scalar: SRS-reference SE of the covariance
        via the Goodnight / Mood-Graybill formula, used by the
        analysis layer to compute `deff`.
      - `var_x` — numeric scalar: Kish-corrected plug-in variance of
        `x_col` on the pair's active domain.
      - `var_y` — numeric scalar: Kish-corrected plug-in variance of
        `y_col` on the pair's active domain.
      - `n` — integer scalar: unweighted count of pairwise-complete
        rows with positive weight on the active domain.
      - `n_weighted` — numeric scalar: sum of weights on the active
        domain.
    - **Field semantics**: `covariance` is Kish-corrected; `var_x` and
      `var_y` are Kish-corrected plug-in variances on the pair's
      active domain (same `n/(n − 1)` scaling as `covariance`, so
      diagonal parity with `get_variance()` holds). On diagonal rows
      (`x_col == y_col`) the analysis layer calls the pair helper with
      the diagonal pair and consumes the returned `n` verbatim — `n`
      is the **pair-helper's responsibility** (per-variable non-NA
      count on the active domain when `x_col == y_col`), not a
      post-processed analysis-layer override. The roxygen block
      for `get_covariance()` must carry forward the References section
      below as `@references`.
  - `R/analysis-meta.R` — modified. Adds
    `COVARIANCE_META_KEYS <- c(FAMILY_META_KEYS, "method")` (exactly
    mirroring the `CORR_META_KEYS` pattern) and a
    `survey_covariance` meta constructor that uses this key set. The
    new constructor stamps `method = "covariance"` as a top-level key
    echoed through `.meta` for downstream consumers.
  - `R/methods-print.R` — modified. Adds a `survey_covariance` print
    method following the existing family template (e.g.
    `survey_corr`, `survey_variance`).
  - `R/methods-compat.R` — modified. Adds broom `tidy` / `glance`
    adapter for `survey_covariance` (matches the other family
    members; no new method semantics).
  - `R/analysis-helpers.R` (where `.apply_name_style()` lives) —
    modified. Extends the broom rename map with an explicit
    `covariance = "estimate"` entry (parallels `mean = "estimate"` and
    `variance = "estimate"`). No signature change.
  - `R/analysis-covariance-helpers.R` — also houses a new thin wrapper
    `.attach_covariance_labels(result, meta, conf_level, name_style)`
    that applies the column-label table documented under §Returns
    Attributes to each output column. The helper **reuses**
    `.attach_variance_labels()` logic for the shared columns (`se`,
    `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`, `n`,
    `n_weighted`) and applies the covariance-specific labels
    (`covariance`/`estimate`, `var1`, `var2`). Do **not** overload
    `.attach_variance_labels()` itself — keep the variance helper
    single-purpose.
  - `NAMESPACE` — regenerated. New export `get_covariance`.
  - `man/get_covariance.Rd` — generated.
  - `DESCRIPTION` — version bump to `0.7.2.9000`.
  - `NEWS.md` — add entry under `# surveycore (development version)`.
  - `plans/error-messages.md` — three new warning rows appended
    (CV-1 `surveycore_warning_covariance_all_na`,
    CV-2 `surveycore_warning_covariance_insufficient_n`,
    CV-3 `surveycore_warning_covariance_non_numeric`).

- **Functions added**
  - `get_covariance(design, x, group = NULL, redundant = FALSE,
     diagonal = FALSE, variance = "ci", conf_level = 0.95,
     n_weighted = FALSE, decimals = NULL, min_cell_n = 30L,
     na.rm = TRUE, label_values = TRUE, label_vars = TRUE,
     name_style = "surveycore", ..., .id = ".survey",
     .on_missing = "error")`

- **Functions modified**
  - `.apply_name_style()` — extended so its broom rename map includes
    `covariance → estimate` (alongside `mean → estimate` and
    `variance → estimate`). No signature change.
  - `R/analysis-meta.R` — registers `COVARIANCE_META_KEYS` and
    `survey_covariance` meta constructor using the shared
    `FAMILY_META_KEYS` base, mirroring `get_variance()` /
    `get_corr()`. Adds `method` to the top-level echoed keys.
  - All other existing helpers (`.apply_domain()`, `.resolve_groups()`,
    `.add_variance_cols()`, `.validate_shared_args()`,
    `.check_unsupported_class()`, `.apply_decimals()`,
    `.make_result_tibble()`, `.extract_var_meta()`,
    `.build_group_meta()`, `.apply_group_labels()`,
    `.dispatch_over_collection()`) are reused as-is, no signature
    changes.

- **Class changes**
  - `survey_covariance` — new S3 class applied to the returned
    tibble, inheriting `survey_result`, following the existing family
    convention (`survey_corr`, `survey_variance`, etc.).

## Function contracts

### `get_covariance(design, x, ...)`

- **Signature**

  ```
  get_covariance(
    design,
    x,
    group = NULL,
    redundant = FALSE,
    diagonal = FALSE,
    variance = "ci",
    conf_level = 0.95,
    n_weighted = FALSE,
    decimals = NULL,
    min_cell_n = 30L,
    na.rm = TRUE,
    label_values = TRUE,
    label_vars = TRUE,
    name_style = "surveycore",
    ...,
    .id = ".survey",
    .on_missing = "error"
  )
  ```

- **Arguments**

  | Arg | Semantics |
  |---|---|
  | `design` | A survey design object: `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`, or a `survey_collection`. (`survey_srs` dispatches through the `survey_nonprob` path.) Any other class is rejected. |
  | `x` | `<tidy-select>`. Two or more unquoted variable names. Must resolve to at least two numeric columns after non-numeric columns are dropped with a warning. If fewer than 2 numeric variables remain, an error is raised. |
  | `group` | `<tidy-select>` or `NULL`. Optional grouping variable(s); combined elementwise with any grouping set by `group_by()` on the design. `NULL` means "no grouping beyond what the design carries." Grouping follows domain-estimation semantics: covariances are estimated separately within each group using that group's own weighted means (`x̄_g`, `ȳ_g`) for centring. Matches `get_corr()` grouping behaviour. |
  | `redundant` | Logical scalar. When `FALSE` (default), emit each unordered pair once in supply order (lower-triangle). When `TRUE`, also emit the reversed pair `(y, x)` for each `(x, y)`; the output shape doubles off-diagonal pairs. Matches `get_corr()` semantics. |
  | `diagonal` | Logical scalar. When `FALSE` (default), omit self-pairs `(x, x)`. When `TRUE`, emit one self-pair per variable with `covariance = Var̂(x)` (the design-based Kish-corrected variance of the variable, **not** `1` as in `get_corr()`). The covariance matrix diagonal is not the identity; it is the variance vector. See Edge cases for details. |
  | `variance` | `NULL` or character vector whose elements are drawn from `c("se", "ci", "var", "cv", "moe", "deff")`. Selects which uncertainty columns appear in the output. Default `"ci"`. `NULL` emits no uncertainty columns. |
  | `conf_level` | Numeric scalar, strictly in `(0, 1)`. Default `0.95`. Normal-quantile based CIs (`degf = Inf`), matching `get_variance()` / `svyvar()`. |
  | `n_weighted` | Logical scalar. If `TRUE`, appends an `n_weighted` column with the sum of weights over the pair's active complete-case domain. Default `FALSE`. |
  | `decimals` | Non-negative whole number or `NULL`. Rounds all numeric output columns. Default `NULL` (no rounding). |
  | `min_cell_n` | Non-negative whole number. Minimum unweighted pairwise-complete `n` below which `surveycore_warning_small_cell` fires. Default `30L` (AAPOR). |
  | `na.rm` | Logical scalar. If `TRUE` (default), the pair's active domain uses pairwise complete cases — each pair drops only rows where either `x` or `y` is `NA`; rows where a grouping variable is `NA` are dropped from the output. If `FALSE`, NAs propagate and produce `NaN` estimates; NA group values are retained as their own group row (matching `get_corr()` / `get_means()`). No `na_handling` argument — pairwise is the only policy. Matches `svyvar()` off-diagonal pair-at-a-time semantics (not `svyvar()`'s default listwise deletion across a multi-variable formula). |
  | `label_values` | Logical scalar. If `TRUE` (default) and a grouping variable has value labels in metadata, the group column is converted to a labelled factor. Same behaviour as `get_corr()`. |
  | `label_vars` | Logical scalar. If `TRUE` (default) and variable labels are set in metadata, the `var1` / `var2` columns display variable labels instead of raw names. Falls back to raw names when a label is unset. |
  | `name_style` | `"surveycore"` (default) or `"broom"`. Under `"broom"`, the point-estimate column `covariance` is renamed to `estimate`, along with `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high`. `.apply_name_style()` must be extended so the broom map includes `covariance → estimate`. |
  | `...` | Reserved — must be empty. Its sole purpose is to force `.id` / `.on_missing` to be supplied by name when `design` is a `survey_collection`. |
  | `.id` | Character scalar. Column name added when `design` is a `survey_collection` to identify each survey. Default `".survey"`. Must be a single non-empty, non-NA character. |
  | `.on_missing` | `"error"` (default) or `"skip"`. How to handle surveys in a collection that lack one of the requested NSE variables. |

- **Returns**

  A tibble of class `c("survey_covariance", "survey_result", "tbl_df", "tbl", "data.frame")`.

  Columns, in order:

  1. `[group_cols...]` — one column per active grouping variable (from `group` argument combined with any `group_by()` on the design). Present only when grouping is active. Labelled factors when a group has value labels and `label_values = TRUE`; raw codes otherwise.
  2. `var1` — factor. Identifies the first variable in each ordered pair. Levels are in `x`-supply order (same convention as `get_corr()`).
  3. `var2` — factor. Identifies the second variable in each ordered pair. Levels are in `x`-supply order.
  4. `covariance` — numeric. The design-based Pearson covariance estimate on the pair's active domain (Kish `n/(n−1)` correction applied). `NaN` for degenerate cells; `0` for pairs where at least one variable is constant on the pair's active domain.
  5. Zero or more uncertainty columns — included only when selected via `variance`. Column names: `se`, `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`. (When `name_style = "broom"`, renamed per `.apply_name_style()`.)
  6. `n` — integer. Unweighted count of pairwise-complete rows with positive weight contributing to that row's estimate. On diagonal rows (when `diagonal = TRUE`), `n` is the per-variable non-NA count on the active domain (not a pairwise count), and is **not required to equal** the `n` reported by `get_variance(design, var)` — equality holds when the active domain is identical.
  7. `n_weighted` — numeric. Present only when `n_weighted = TRUE`. Sum of weights over the pair's active complete-case domain (per-variable on diagonal rows).

  Pair generation rules (before any filtering):

  - Let `vars` be the numeric subset of `x` in supply order.
  - Default (`redundant = FALSE`, `diagonal = FALSE`): lower-triangle-only off-diagonal pairs, `|vars| * (|vars| - 1) / 2` rows per group stratum.
  - `redundant = TRUE`, `diagonal = FALSE`: off-diagonal ordered pairs, `|vars| * (|vars| - 1)` rows per group stratum.
  - `redundant = FALSE`, `diagonal = TRUE`: lower-triangle plus the diagonal, `|vars| * (|vars| + 1) / 2` rows per group stratum.
  - `redundant = TRUE`, `diagonal = TRUE`: full `|vars|^2` per-group-stratum grid.
  - Factor-level order of `var1` / `var2` is `vars` supply order in every case.

  Attributes:

  - Every column carries a `label` attribute for gt integration. The
    full column-label table, side-by-side under
    `name_style = "surveycore"` (column name `→` label) and
    `name_style = "broom"` (renamed column name `→` label):

    | surveycore column | surveycore label | broom column | broom label |
    |---|---|---|---|
    | `var1` | `"Variable 1"` | `var1` | `"Variable 1"` |
    | `var2` | `"Variable 2"` | `var2` | `"Variable 2"` |
    | `covariance` | `"Covariance"` | `estimate` | `"Estimate"` |
    | `se` | `"SE"` | `std.error` | `"Std. error"` |
    | `var` | `"Variance of estimate"` | `var` | `"Variance of estimate"` |
    | `ci_low` | `"{conf_level_pct}% CI low"` (e.g. `"95% CI low"`) | `conf.low` | `"Conf. low"` |
    | `ci_high` | `"{conf_level_pct}% CI high"` (e.g. `"95% CI high"`) | `conf.high` | `"Conf. high"` |
    | `cv` | `"CV"` | `cv` | `"CV"` |
    | `moe` | `"Margin of error"` | `moe` | `"MOE"` |
    | `deff` | `"Design effect"` | `deff` | `"Deff"` |
    | `n` | `"N"` | `n` | `"n"` |
    | `n_weighted` | `"Weighted N"` | `n.weighted` | `"n.weighted"` |

    Group columns carry the group variable's metadata label when
    available (independent of `name_style`).
  - A `.meta` attribute with the family's nested shape:
    - `group` = named list, one entry per active grouping variable, each with `variable_label`, `question_preface`, `value_labels` (or empty list when no grouping).
    - `x` = named list, one entry per resolved numeric focal variable (in supply order), each with `variable_label`, `question_preface`, `value_labels`.
    - `design_class` — one of `"survey_taylor"`, `"survey_replicate"`, `"survey_twophase"`, `"survey_nonprob"`, or `"survey_collection"`.
    - `method` — `"covariance"` (literal string, reserved for future extension when polychoric lands).
    - `conf_level`, `name_style`, `min_cell_n`, `redundant`, `diagonal` — echoed for downstream consumers.
    - `na_rm` — echoed boolean so consumers can interpret the pairwise-complete semantics.
    - `per_survey` — **present only when** `design` is a `survey_collection` **and** `surveycore_warning_collection_meta_divergence` fires. Absent otherwise. Shape: a **named list** keyed by survey `.id` (one entry per non-skipped survey in the collection), each element a full per-survey `.meta` object with the same nested shape as the top-level `.meta` (`group`, `x`, `design_class`, `method`, `conf_level`, `name_style`, `min_cell_n`, `redundant`, `diagonal`, `na_rm`). Used by downstream consumers (e.g. gt rendering) to recover each survey's own variable labels, value labels, question prefaces, and design class when the combined top-level `.meta` reflects only the first survey.
  - Class attribute listed above.

- **Errors** — one row per named error class.

  | Condition | Error class | Registry row |
  |---|---|---|
  | `design` is not a recognized survey class | `surveycore_error_unsupported_class` | 64 |
  | `x` resolves to fewer than 2 variables (before numeric filtering) | `surveycore_error_insufficient_variables` | 44 |
  | After dropping non-numeric columns, fewer than 2 numeric variables remain | `surveycore_error_insufficient_variables` | 44 |
  | `variance` contains invalid values | `surveycore_error_invalid_variance_arg` | 45 |
  | `conf_level` not a numeric scalar strictly in `(0, 1)` | `surveycore_error_invalid_conf_level` | 45a |
  | `decimals` not a non-negative whole number or `NULL` | `surveycore_error_invalid_decimals` | 45b |
  | `name_style` not `"surveycore"` or `"broom"` | `surveycore_error_invalid_name_style` | 46 |
  | `na.rm` not `TRUE` or `FALSE` | `surveycore_error_na_rm_not_logical` | 81 |
  | `survey_collection` survey lacks a requested variable with `.on_missing = "error"` | `surveycore_error_collection_missing_var` | C5 |
  | All surveys in a collection skipped | `surveycore_error_collection_all_skipped` | C6 |
  | `.id` collides with a produced column | `surveycore_error_collection_id_collision` | C7 |
  | `.id` invalid (not a single non-empty non-NA character) | `surveycore_error_collection_invalid_id` | C13 |
  | Selected variable not present on a per-survey path | `surveycore_error_variable_not_found` | C10 |

- **Warnings** — one row per named warning class.

  | Condition | Warning class | Registry row |
  |---|---|---|
  | Any pair row has `n < min_cell_n` | `surveycore_warning_small_cell` | 49 |
  | A grouping variable has a single observed level | `surveycore_warning_single_level` | 50 |
  | Non-numeric variable silently dropped from `x` | `surveycore_warning_covariance_non_numeric` | CV-3 |
  | `variance = "cv"` requested and at least one row has `covariance = 0` | `surveycore_warning_cv_undefined` | 54 |
  | A pair is all-NA in the active domain after pairwise deletion (n = 0) | `surveycore_warning_covariance_all_na` | CV-1 |
  | A pair has fewer than 2 pairwise-complete observations (n ∈ {0, 1}) | `surveycore_warning_covariance_insufficient_n` | CV-2 |
  | (Collection) surveys skipped due to missing variable with `.on_missing = "skip"` | `surveycore_message_collection_skipped_surveys` | C9 |
  | (Collection) per-survey metadata divergence for the same variable | `surveycore_warning_collection_meta_divergence` | C11 |
  | (Collection) duplicate names repaired | `surveycore_warning_collection_duplicate_name_repaired` | C2a |
  | Option `survey.lonely.psu` triggers inside `.svy_recvar()` / `.twophasevar()` | Inherited from the engine — no additional wrap or suppression |

- **Edge cases**

  | Case | Behaviour |
  |---|---|
  | `x` selects 0 or 1 variables | Error, `surveycore_error_insufficient_variables`. |
  | `x` selects zero columns (empty tidy-select resolution) | `surveycore_error_insufficient_variables` fires **before** the non-numeric drop pass (same ordering as `get_corr()`) — the empty-selection guard runs first, so no non-numeric warning is emitted when the selection is empty. |
  | `conf_level` not a numeric scalar strictly in `(0, 1)` (e.g. `0`, `1`, `NA`, non-finite, negative, or non-numeric) | `surveycore_error_invalid_conf_level` fires (registry row 45a — already defined; no new row needed). Validated by the shared `.validate_shared_args()` helper. |
  | Negative or zero weights in the underlying design | **Not re-validated here.** `as_survey()` / `as_survey_rep()` / `as_survey_twophase()` / `as_survey_nonprob()` enforce strictly positive weights at construction time (registry rows 6, 6a). `get_covariance()` assumes positive weights and does not re-check. |
  | `x` contains one numeric and one non-numeric variable (only 1 numeric remaining) | `surveycore_warning_covariance_non_numeric` fires for the dropped non-numeric column; then `surveycore_error_insufficient_variables` fires because only 1 numeric variable remains. |
  | Empty input (0-row data frame) | Not reachable — `as_survey*` constructors reject <2 rows (registry row 4). No dedicated guard needed. |
  | Pair is all-NA in active domain (every row has at least one of the two values NA) | `covariance = NaN`, all uncertainty cols `NaN`, `n = 0L`, `n_weighted = 0`. Fires `surveycore_warning_covariance_all_na`. |
  | One variable is all-NA but the other is not | Collapses to the all-NA pair case: every row has at least one NA, so pairwise-complete set is empty. `surveycore_warning_covariance_all_na` fires. |
  | Pair has exactly 1 pairwise-complete row | `covariance = NaN`, uncertainty cols `NaN`, `n = 1L`. Fires `surveycore_warning_covariance_insufficient_n`. |
  | Pair has `n ≥ 2` but one variable is constant on the pair's active domain (zero-variance variable) | `covariance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0` (0/0 guard: return 0 when the SRS comparator is also 0). `cv` set to `NA` with `surveycore_warning_cv_undefined` if `"cv"` requested. No covariance-specific warning. |
  | Both variables constant on pair's active domain | Same as "one constant": `covariance = 0`, SE = 0, no warning. |
  | Grouping variable with a single observed level | Fires `surveycore_warning_single_level`; output has a single row per emitted pair. |
  | `na.rm = FALSE`, either variable contains NAs | NAs propagate: `covariance = NaN`, uncertainty cols `NaN`. `n` is unweighted count of in-domain rows regardless of NA status. No covariance-specific warning fires. |
  | Zero-weight rows in a `survey_nonprob` design | Zero-weight rows excluded from `n` and from the weighted means on the pair's active domain (matching `.score_variance()` behaviour and `svyvar` survey.R line 703). Strictly positive weights contribute. Zero-weight rows cannot occur in `survey_taylor` / `survey_replicate` / `survey_twophase` — validators enforce strictly positive weights. |
  | `survey_twophase`: row is in Phase 1 but not in Phase 2 | Contributes 0 to influence; excluded from `n` and `W`. Same pattern as `get_variance()`. |
  | `survey_replicate`: near-zero covariance with tiny negative replicate residual | Apply `max(0, v)` inside `sqrt()` for SE (same guard as `get_variance()`) to avoid `NaN` from floating-point underflow. |
  | CI bounds cross zero | **Not clamped.** `ci_low` and `ci_high` may have opposite signs (covariance is unbounded and can be negative). Builder must document in `@details`: Wald CI on the SE of the point estimate; bounds may cross zero; no clamping; users may post-process if desired; matches `get_variance()` / `svyvar()` semantics. |
  | `diagonal = TRUE` pair `(x, x)` | `var1 = var2 = x`. `covariance` is the design-based Kish-corrected variance of `x` on the active domain (i.e. `Var̂(x)`, **not** `1` as in `get_corr()`). `se` is derived from the same variance-of-weighted-mean-of-Kish-scaled-score machinery used by `get_variance()`. `n` on diagonal rows is the per-variable non-NA count on the active domain (not pairwise), which will equal the pairwise `n` only when every pair including this variable happens to share the same active domain. The semantic divergence from `get_corr()`'s `diagonal = TRUE` (where the diagonal is `1, se = 0`) is intentional and must be documented in `@details`. |
  | `diagonal = TRUE` with a variable that is all-NA on the active domain | Self-pair emits `covariance = NaN`, `se = NaN`, `n = 0`, and fires `surveycore_warning_covariance_all_na` (the pair `(x, x)` is all-NA when `x` is all-NA). |
  | `redundant = TRUE` output | For off-diagonal pairs, `covariance(x, y)` and `covariance(y, x)` rows have numerically identical point estimates and SEs (symmetry). Tests assert this. |
  | Mixed `redundant` / `diagonal` flags | Pair generation applies the rules listed under Returns verbatim. No special case. |
  | `design` is a `survey_collection`: all surveys lack one of the required variables | Dispatch collapses to `surveycore_error_collection_all_skipped`. |
  | `design` is a `survey_collection`: per-survey `.meta` differs | `surveycore_warning_collection_meta_divergence` fires; top-level `.meta` reflects the first survey; per-survey metadata preserved under `.meta$per_survey`. |
  | `n = 2` pair | Minimum for a finite estimate. Kish `n/(n − 1) = 2` is well-defined; `covariance` and `se` are both returned as finite reals (no covariance-specific warning, though `surveycore_warning_small_cell` will fire because `n < min_cell_n = 30`). |
  | Single-PSU-per-stratum | Behaviour is delegated to the design engine via `getOption("survey.lonely.psu")` (e.g. `"adjust"`, `"average"`, `"certainty"`, `"remove"`). No special handling in `get_covariance()`; the engine's message or behaviour is passed through unchanged. |
  | Zero-weight domain (all `w_i = 0` across the pair's active mask) | `covariance = NaN`, `se = NaN`, `n = count(active non-NA)`, `n_weighted = 0`. Fires `surveycore_warning_covariance_all_na`. (`W = 0` yields `NaN` in the weighted mean; treated identically to the all-NA-pair case.) |
  | Variance-engine-level FP underflow clip fires | When the engine applies `max(0, v)` inside `sqrt()` to guard against negative variance from floating-point underflow, `se` is set to exactly `0` (not a tiny positive value, not `NaN`). |

## Quality gates

- `get_covariance()` is numerically equivalent to the off-diagonal of
  `survey::svyvar()` on a multi-variable call for `survey_taylor`,
  `survey_replicate`, and `survey_twophase` designs within the
  project's standard tolerances (point and SE).
- `get_covariance()` is symmetric in its inputs for off-diagonal pairs:
  calling it with `(x, y)` and `(y, x)` produces identical point and
  SE values, up to numerical equivalence at the project's SE tolerance.
- Internal consistency with `get_variance()`: for a single variable
  `v`, `get_covariance(design, c(v, v), diagonal = TRUE,
  redundant = FALSE)` returns the same point estimate (and SE at the
  SE tolerance) as `get_variance(design, v)` in the same row, on the
  same active domain.
- **Diagonal parity gate.** Under `diagonal = TRUE`,
  `get_covariance(d, c(x, x))$covariance` and `$se` must numerically
  equal `get_variance(d, x)$variance` and `$se` respectively
  (tolerance: point `1e-10`, SE `1e-8`) on identical active domains.
- `get_covariance()` returns a `covariance` column that is always
  numeric: a finite real for non-degenerate pairs; exactly `0` for
  pairs where a variable is constant on the active domain; `NaN`
  otherwise — never `NA_real_`.
- `covariance` column is the estimand; `var` column (when opted in)
  is the variance of the estimate. The two are distinct columns with
  distinct meanings; neither overwrites the other.
- The pair generator emits rows in supply order; `var1` and `var2`
  factor levels match `x`-supply order.
- `redundant` and `diagonal` flags change only the rowset, never the
  per-pair point estimate or SE values.
- Dispatch covers the five listed design classes and errors for any
  other class via the existing `.check_unsupported_class()` path.
- `test_invariants(design)` holds for every constructor used in the
  test harness (reminder for tester; builder must not break the
  invariant checker).
- All output columns carry a `label` attribute.
- The `.meta` of the result has the family-standard nested shape:
  `group` (possibly empty), `x` (one entry per resolved numeric focal
  variable), `design_class`, `method = "covariance"`, and echoes of
  `conf_level`, `name_style`, `min_cell_n`, `redundant`, `diagonal`,
  `na_rm`. No `function_name` or `variable` keys — family parity.
- Name-style `"broom"` renames `covariance → estimate` (column and
  label updated consistently).
- The three new warning classes
  `surveycore_warning_covariance_all_na`,
  `surveycore_warning_covariance_insufficient_n`, and
  `surveycore_warning_covariance_non_numeric` are defined in
  `plans/error-messages.md` and fire exactly once per occurrence (per
  pair for the first two, per call for the third with a list of
  dropped variables).
- `survey.lonely.psu` behaviour is inherited from the variance engine
  — no extra cli messages are emitted by `get_covariance()` itself.
- The roxygen `@details` block for `get_covariance()` includes
  explicit notes that (a) CIs are Wald and may cross zero (covariance
  is unbounded), (b) the diagonal (`diagonal = TRUE`) returns the
  variance — not `1` — distinguishing it from `get_corr()`'s
  diagonal, and (c) NA handling is pairwise-complete per pair.
- `R CMD check --as-cran` passes with 0 errors, 0 warnings, ≤2
  pre-approved notes.

## Pipeline split

**recommended** — A new exported numerical estimator that crosses
every design type, introduces a new parallel pair engine
(`.covariance_pair_*()`), adds three new warning classes, introduces
a new `survey_covariance` result class, mutates `analysis-meta.R`,
and requires numerical-parity tests against `survey::svyvar()`
off-diagonals on three design paths plus an internal-consistency
check against `get_variance()`.

Natural seam if the builder chooses to split: the obvious split point
is Taylor + replicate in PR 1, twophase + nonprob + collection in
PR 2, matching the `get_variance()` split. A single-PR shape is also
acceptable given the function is entirely additive (no existing
functions change behaviour) and every helper it touches is scoped to
the new files. Builder may consolidate at discretion; default
recommendation is **single PR** because the total surface (two new
files, three small additions to existing files) is smaller than
`get_variance()` (which had the additional `FAMILY_META_KEYS`
refactor).

## References

The roxygen block for `get_covariance()` must carry these citations
forward as `@references` entries; see also the pair-helper contract
note under §Architecture.

- Mood, A. M., Graybill, F. A., & Boes, D. C. (1974). *Introduction
  to the Theory of Statistics* (3rd ed.). McGraw-Hill. — Source for
  the Goodnight / Mood-Graybill `SE_SRS(cov) = sqrt((Var(x) · Var(y)
  + cov^2) / (n − 1))` formula used as the SRS reference when
  computing the design effect (`deff`).
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*.
  Wiley. — Source for the Taylor linearization of influence functions
  of smooth functions of totals, which underpins the design-based SE
  of `get_covariance()` on Taylor and twophase designs.
- Cochran, W. G. (1977). *Sampling Techniques* (3rd ed.). Wiley. —
  Source for the finite-sample `n/(n − 1)` Kish correction applied to
  the point estimate (and, by the pair-helper contract, to `var_x` and
  `var_y`).
- Demnati, A., & Rao, J. N. K. (2004). Linearization variance
  estimators for survey data. *Survey Methodology*, 30, 17–26. —
  Justifies the linear-combination SE for smooth functions of totals,
  including the covariance estimator specifically.
