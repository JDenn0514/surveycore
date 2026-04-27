# Spec — get-variance

**Status**: SPEC_REVIEWED
**Target version**: 0.7.1.9000
**PR range**: PR 1–2

## Scope

### In

- A new exported analysis function `get_variance()` that estimates the
  design-based finite-population variance of one or more numeric variables
  with the Kish `n/(n-1)` correction.
- Dispatch across all currently supported survey design classes:
  `survey_taylor`, `survey_replicate`, `survey_twophase`, `survey_nonprob`,
  and `survey_collection` (via the standard `.id` / `.on_missing` reserved
  arguments).
- Design-based SE, the full family of opt-in uncertainty columns
  (`se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`), and the standard
  column-level `label` attributes required for gt integration.
- Nested `.meta` structure (`group` / `x`) matching the rest of the
  `get_*()` family.
- `na.rm` control (scalar boolean) and a new `na_handling` control
  (pairwise vs listwise) that governs multi-variable NA semantics.
- Tidy, long-form output (one row per variable) with a required `name`
  column carrying the raw variable name (or the variable label when
  `label_vars = TRUE`).

### Out

- Off-diagonal covariances (no variance/covariance matrix output). A future
  `get_covariance()` is explicitly out of scope.
- Standard-deviation estimand (callers apply `sqrt()` themselves, matching
  `survey::svyvar()`).
- Coercion of factor / character inputs to numeric. These are rejected,
  matching the `get_means()` precedent.
- A log-transformed / Satterthwaite-refined CI for small-sample variance
  inference. The normal-Wald CI (with no clamping) is the only interval
  produced.
- A `get_sd()` wrapper.

## Architecture

- **Files touched**
  - `R/analysis-variance.R` — created. Houses exported `get_variance()`,
    dispatch to design-specific cell helpers, result assembly, naming.
  - `R/analysis-variance-helpers.R` — created. Houses a single
    `.variance_cell(design, y, weights, domain, na_vec, ...)` dispatch
    wrapper and the shared score-vector helper
    `.score_variance(y, weights, domain, na_vec)` that returns the
    derived score vector
    `z_i = a_i · (y_i − ȳ_d)² · n_d/(n_d−1)`. `ȳ_d` and `n_d` are the
    domain-restricted weighted mean and unweighted count respectively.
    The cell wrapper builds the score and then delegates to the existing
    per-design mean cell helper appropriate to `class(design)`:
    `.taylor_mean_cell()` (→ `.svy_recvar()`), `.replicate_mean_cell()`
    (replicate-weight loop), `.twophase_mean_cell()` (two-phase sum), or
    `.nonprob_mean_cell()` (HT influence). The multi-variable case
    iterates over selected columns (per-variable under
    `na_handling = "pairwise"`; shared active mask under `"listwise"`),
    calls `.variance_cell()` once per variable, and row-binds the
    per-variable results.
  - `R/analysis-meta.R` — modified. Introduces a shared
    `FAMILY_META_KEYS` constant used by all `get_*()` meta constructors
    (replacing the per-function `*_META_KEYS` duplicates) and registers
    the `survey_variance` meta constructor call.
  - `R/methods-print.R` — modified. Adds a `survey_variance` print method
    following the existing family template.
  - `R/methods-compat.R` — modified. Adds broom `tidy` / `glance` adapter
    for `survey_variance` (matches the other family members; no new
    method semantics).
  - `NAMESPACE` — regenerated. New export `get_variance`.
  - `man/get_variance.Rd` — generated.
  - `DESCRIPTION` — version bump to `0.7.1.9000`.
  - `NEWS.md` — add entry under `# surveycore (development version)`.
  - `plans/error-messages.md` — already updated in this spec pass with
    new rows V-1 and V-2.

- **Functions added**
  - `get_variance(design, x, group = NULL, variance = "ci",
     conf_level = 0.95, n_weighted = FALSE, decimals = NULL,
     min_cell_n = 30L, na.rm = TRUE,
     na_handling = c("pairwise", "listwise"),
     label_values = TRUE, label_vars = TRUE,
     name_style = "surveycore", ..., .id = ".survey",
     .on_missing = "error")`

- **Functions modified**
  - `.apply_name_style()` — extended so its broom rename map includes
    `variance → estimate` (parallels `mean → estimate` already present
    for `get_means()`). No signature change.
  - `R/analysis-meta.R` — refactored to introduce a shared
    `FAMILY_META_KEYS` constant consumed by every `get_*()` meta
    constructor (replacing per-function `*_META_KEYS` duplicates); all
    existing callers are updated mechanically, no behavioral change.
  - All other existing helpers (`.apply_domain()`, `.resolve_groups()`,
    `.add_variance_cols()`, `.validate_shared_args()`,
    `.check_unsupported_class()`, `.build_cluster_matrices()`,
    `.svy_recvar()`, `.svy_rep_var()`, `.twophasevar()`,
    `.compute_phase2_probs()`, `.apply_decimals()`,
    `.make_result_tibble()`, `.extract_var_meta()`,
    `.build_group_meta()`, `.apply_group_labels()`,
    `.dispatch_over_collection()`, and the per-design mean cell helpers
    `.taylor_mean_cell()` / `.replicate_mean_cell()` /
    `.twophase_mean_cell()` / `.nonprob_mean_cell()`) are reused as-is,
    no signature changes.

- **Class changes**
  - `survey_variance` — new S3 class applied to the returned tibble,
    inheriting `survey_result`, following the existing family convention
    (`survey_mean`, `survey_corr`, etc.).

## Function contracts

### `get_variance(design, x, ...)`

- **Signature**

  ```
  get_variance(
    design,
    x,
    group = NULL,
    variance = "ci",
    conf_level = 0.95,
    n_weighted = FALSE,
    decimals = NULL,
    min_cell_n = 30L,
    na.rm = TRUE,
    na_handling = c("pairwise", "listwise"),
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
  | `x` | `<tidy-select>`. One or more unquoted numeric variable names. Must resolve to at least one numeric column. Non-numeric columns cause an error (no silent drop, matching `get_means()`). |
  | `group` | `<tidy-select>` or `NULL`. Optional grouping variable(s); combined elementwise with any grouping set by `group_by()` on the design. `NULL` means "no grouping beyond what the design carries." Grouping follows domain-estimation semantics: the variance is estimated separately within each group using that group's own weighted mean ȳ_g for centering (not a full-sample mean). Matches `get_means()` grouping behavior. |
  | `variance` | `NULL` or character vector whose elements are drawn from `c("se", "ci", "var", "cv", "moe", "deff")`. Selects which uncertainty columns appear in the output. Default `"ci"`. `NULL` emits no uncertainty columns. |
  | `conf_level` | Numeric scalar, strictly in `(0, 1)`. Default `0.95`. Normal-quantile based CIs (`degf = Inf`), matching `get_means()` precedent and `survey::svyvar()`. |
  | `n_weighted` | Logical scalar. If `TRUE`, appends an `n_weighted` column with the sum of weights over in-domain, non-NA, positive-weight rows used in each row's estimate. Default `FALSE`. |
  | `decimals` | Non-negative whole number or `NULL`. Rounds all numeric output columns (`variance`, `se`, `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`, `n_weighted`). Default `NULL` (no rounding). |
  | `min_cell_n` | Non-negative whole number. Minimum unweighted in-domain non-NA `n` below which `surveycore_warning_small_cell` fires. Default `30L` (AAPOR). |
  | `na.rm` | Logical scalar. If `TRUE` (default), NA observations in any focal variable are excluded from that variable's per-row calculations, and rows where any grouping variable is `NA` are excluded from the output. If `FALSE`, NA focal values propagate (produces `NaN` estimates) and NA group values are collected into their own group row (matching `get_means()` / `get_freqs()` semantics). |
  | `na_handling` | `"pairwise"` (default) or `"listwise"`. Interacts with `na.rm`: when `na.rm = TRUE`, controls which rows are treated as non-NA for each focal variable. `"pairwise"`: each focal variable's `n` reflects its own complete-case set (each row in the output uses that variable's own non-NA rows). `"listwise"`: one shared complete-case set — rows with `NA` in *any* of the selected focal variables are excluded from *every* variable's per-row calculation, and every output row shares the same `n`. When `na.rm = FALSE`, `na_handling` is ignored. `match.arg()` is used; unknown values fall through to an arg-matching error. |
  | `label_values` | Logical scalar. If `TRUE` (default) and a grouping variable has value labels in metadata, the group column is converted to a labelled factor. Same behavior as `get_means()`. |
  | `label_vars` | Logical scalar. If `TRUE` (default) and variable labels are set in metadata, the `name` column shows variable labels instead of raw names. Falls back to raw names when a label is unset. |
  | `name_style` | `"surveycore"` (default) or `"broom"`. Under `"broom"`, the point-estimate column `variance` is renamed to `estimate` (matching the family's treatment of the point-estimate column — same as `get_means()`'s `mean → estimate`), along with `se → std.error`, `ci_low → conf.low`, `ci_high → conf.high`. `.apply_name_style()` must be extended so the broom map includes the `variance → estimate` entry. |
  | `...` | Reserved (unused) for reserved named-only control args. |
  | `.id` | Character scalar. Column name added when `design` is a `survey_collection` to identify each survey. Default `".survey"`. Must be non-empty, non-NA, length 1. |
  | `.on_missing` | `"error"` (default) or `"skip"`. How to handle surveys in a collection that lack one of the requested NSE variables. |

- **Returns**

  A tibble of class `c("survey_variance", "survey_result", "tbl_df", "tbl", "data.frame")`.

  Columns, in order:

  1. `[group_cols...]` — one column per active grouping variable (from `group` argument combined with any `group_by()` on the design). Present only when grouping is active. Labelled factors when a group has value labels and `label_values = TRUE`; raw codes otherwise.
  2. `name` — character (or labelled character when `label_vars = TRUE` and a variable label exists). Identifies the focal variable that each row summarizes. Always present (even when `x` selects a single variable).
  3. `variance` — numeric. The design-based point estimate of the population variance (Kish `n/(n-1)` correction applied). `NaN` for degenerate cells; `0` for zero-variance (constant-within-domain) variables.
  4. Zero or more uncertainty columns — included only when selected via `variance`. Column names: `se`, `var`, `ci_low`, `ci_high`, `cv`, `moe`, `deff`. (When `name_style = "broom"`, renamed per `.apply_name_style()`.)
  5. `n` — integer. Unweighted count of in-domain, non-NA rows with positive weight contributing to that row's estimate. Under active grouping, reflects only rows in the current group's domain (per-variable under `na_handling = "pairwise"`; shared across variables under `na_handling = "listwise"`).
  6. `n_weighted` — numeric. Present only when `n_weighted = TRUE`. Under `na_handling = "pairwise"`, each variable reports its own `sum(w · a)` over its own complete-case set. Under `na_handling = "listwise"`, all variables share the intersected `sum(w · a)`.

  Attributes:

  - Every column carries a `label` attribute for gt integration. `variance` → `"Variance"`, `se` → `"SE"`, `var` → `"Variance of estimate"`, `ci_low` / `ci_high` → conf-level-interpolated `"95% CI low"` / `"95% CI high"` (or equivalent for other `conf_level` values), `cv` → `"CV"`, `moe` → `"Margin of error"`, `deff` → `"Design effect"`, `n` → `"N"`, `n_weighted` → `"Weighted N"`, `name` → `"Variable"`. Group columns carry the group variable's metadata label when available.
  - A `.meta` attribute with the family's nested shape — **no `function_name` or `variable` keys** (family parity: `get_means()` / `get_freqs()` do not carry them):
    - `group` = named list, one entry per active grouping variable, each with `variable_label`, `question_preface`, `value_labels` (or empty list when no grouping)
    - `x` = named list, one entry per focal variable, each with `variable_label`, `question_preface`, `value_labels`
    - `design_class` — one of `"survey_taylor"`, `"survey_replicate"`, `"survey_twophase"`, `"survey_nonprob"`, or `"survey_collection"` (when dispatched through `.dispatch_over_collection()`)
    - `conf_level`, `name_style`, `min_cell_n` — echoed for downstream consumers
    - `na_handling` — echoed so consumers can interpret per-row `n`
  - Class attribute listed above.

- **Errors** — one row per named error class.

  | Condition | Error class | Registry row |
  |---|---|---|
  | `design` is not a recognized survey class | `surveycore_error_unsupported_class` | 64 |
  | `x` resolves to 0 columns | `surveycore_error_wrong_variable_count` | 138 |
  | A selected `x` column is non-numeric | `surveycore_error_non_numeric_variable` | 43 |
  | `variance` contains invalid values | `surveycore_error_invalid_variance_arg` | 45 |
  | `conf_level` not a numeric scalar strictly in `(0, 1)` | `surveycore_error_invalid_conf_level` | 45a |
  | `decimals` not a non-negative whole number or `NULL` | `surveycore_error_invalid_decimals` | 45b |
  | `name_style` not `"surveycore"` or `"broom"` | `surveycore_error_invalid_name_style` | 46 |
  | `na.rm` not `TRUE` or `FALSE` | `surveycore_error_na_rm_not_logical` | 81 |
  | `na_handling` not `"pairwise"` or `"listwise"` | *(handled by `match.arg()`)* | — (consistent with row 18 pattern) |
  | `survey_collection` survey lacks a requested variable with `.on_missing = "error"` | `surveycore_error_collection_missing_var` | C5 |
  | All surveys in a collection skipped | `surveycore_error_collection_all_skipped` | C6 |
  | `.id` collides with a produced column | `surveycore_error_collection_id_collision` | C7 |
  | `.id` invalid | `surveycore_error_collection_invalid_id` | C13 |
  | Selected variable not present on a per-survey path | `surveycore_error_variable_not_found` | C10 |

- **Warnings** — one row per named warning class.

  | Condition | Warning class | Registry row |
  |---|---|---|
  | Any row has `n < min_cell_n` | `surveycore_warning_small_cell` | 49 |
  | A grouping variable has a single observed level | `surveycore_warning_single_level` | 50 |
  | `variance = "cv"` cell has estimate 0 or negative (variance ≤ 0 case — only possible when variance = 0 under the estimand; still fires per family rule) | `surveycore_warning_cv_undefined` | 54 |
  | A focal variable is all-NA in the active domain under `na.rm = TRUE` | `surveycore_warning_variance_all_na` | V-1 |
  | A focal variable has fewer than 2 non-NA rows in the active domain | `surveycore_warning_variance_insufficient_n` | V-2 |
  | (Collection) surveys skipped due to missing variable with `.on_missing = "skip"` | `surveycore_message_collection_skipped_surveys` | C9 |
  | (Collection) per-survey metadata divergence for the same variable | `surveycore_warning_collection_meta_divergence` | C11 |
  | (Collection) duplicate names repaired | `surveycore_warning_collection_duplicate_name_repaired` | C2a |
  | Option `survey.lonely.psu` triggers inside `.svy_recvar()` | Inherited from the engine — no additional wrap or suppression |

- **Edge cases**

  | Case | Behavior |
  |---|---|
  | `x` selects 0 columns | Error, `surveycore_error_wrong_variable_count`. |
  | `x` resolves to a matrix column (e.g., `cbind(a, b)` stored as a matrix-typed column) | Rejected via the existing non-numeric path. Tidy-select resolves the selection to a single column; the per-column numeric-vector check fails for matrix columns and fires `surveycore_error_non_numeric_variable`. No new error class required. |
  | `x` selects 1 column, single-row input | Not reachable — `as_survey*` constructors reject <2 rows (registry row 4). Documented here only to affirm no guard is needed downstream. |
  | Active domain empty for a given row (0 in-domain non-NA observations, post-group-split) | `variance = NaN`, `se = NaN`, any CI / moe / cv / deff columns `NaN`, `n = 0L`, `n_weighted = 0`. Algorithmic warning condition: `if n_d == 0L && sum(!is.na(x[active_mask])) == 0L && sum(active_mask) > 0L` → fire `surveycore_warning_variance_all_na` (rows are present in the domain but every value of `x` is NA). Otherwise silent — the active domain is empty because filtering/grouping removed all rows, not because `x` is pathologically NA. |
  | Variable is all-NA in the active domain (`na.rm = TRUE`) | `variance = NaN`, all uncertainty cols `NaN`, `n = 0L`. Fires `surveycore_warning_variance_all_na`. |
  | Variable has exactly one non-NA observation in the active domain | `variance = NaN`, all uncertainty cols `NaN`, `n = 1L`. Fires `surveycore_warning_variance_insufficient_n`. |
  | Variable is constant (zero variance) in the active domain, `n >= 2` | `variance = 0`, `se = 0`, `ci_low = ci_high = 0`, `moe = 0`, `deff = 0` (0/0 guard: return 0 when SRS comparator is also 0), `cv` set to `NA` with `surveycore_warning_cv_undefined` (family rule). `n` and `n_weighted` populated normally. No variance-specific warning. |
  | Grouping variable with a single observed level | Fires `surveycore_warning_single_level`; output has a single row per variable. |
  | `na.rm = FALSE`, variable contains NAs | NAs propagate: `variance = NaN`, uncertainty cols `NaN` for rows whose focal variable has any NA contribution. `n` is unweighted count of in-domain rows regardless of NA status. No variance-specific warning fires. |
  | `na_handling = "listwise"`, some rows NA in one variable | Each output row's `n` reflects the intersection complete-case set. Fires `surveycore_warning_variance_all_na` if that intersection is empty; `surveycore_warning_variance_insufficient_n` if size ≤ 1. |
  | `na_handling = "pairwise"`, per-variable `n`s differ | Each row uses its own variable's complete-case `n`. No extra warning about mismatched `n`s. |
  | `survey_nonprob` with zero weights in the focal domain | Zero-weight rows excluded from `n` and from the weighted mean (matching `svyvar` survey.R line 703). Strictly positive non-zero weights contribute. Zero-weight rows cannot occur in `survey_taylor` / `survey_replicate` / `survey_twophase` designs — their validators enforce strictly positive weights. This edge case applies only to `survey_nonprob`. |
  | `survey_twophase`: row is in Phase 1 but not in Phase 2 | Contributes 0 to influence; excluded from `n` and `W`. |
  | `survey_replicate`: near-zero variance with tiny negative replicate residual | Use `max(0, v)` inside the `sqrt()` of the SE calculation to avoid `NaN` from floating-point underflow in an otherwise-zero variance. |
  | CI bounds fall below 0 (variance near 0 with wide SE) | **Not clamped.** `ci_low` may be negative. **Builder must document this explicitly in the roxygen `@details` section** of `get_variance()`: CIs use the normal-Wald approximation on the SE of the variance estimate; when the true variance is near zero with wide SE, `ci_low` can be negative; bounds are not clamped; users may clamp at `0` if desired; this matches `survey::svyvar()`. |
  | `design` is a `survey_collection`: all surveys lack the variable | Dispatch collapses to `surveycore_error_collection_all_skipped`. |
  | `design` is a `survey_collection`: per-survey `.meta` differs | `surveycore_warning_collection_meta_divergence` fires; top-level `.meta` reflects the first survey; per-survey metadata preserved under `.meta$per_survey`. |

## Quality gates

- `get_variance()` is numerically equivalent to `survey::svyvar()` on a single numeric variable for Taylor, replicate, and twophase designs within the project's standard tolerances (point and SE).
- `get_variance()` returns a strictly positive `variance` for every non-degenerate non-constant variable with `n ≥ 2`; `0` for constants with `n ≥ 2`; `NaN` otherwise — never `NA_real_`.
- `variance` column is the estimand; `var` column (when opted in) is the variance-of-the-estimate. The two are distinct columns with distinct meanings; neither overwrites the other.
- Dispatch covers the five listed design classes and errors for any other class via the existing `.check_unsupported_class()` path.
- `test_invariants(design)` holds for every constructor used in the test harness.
- All output columns carry a `label` attribute.
- The `.meta` of the result has the family-standard nested shape: `group` (possibly empty), `x` (one entry per focal variable), and echoes of `conf_level`, `name_style`, `min_cell_n`, `na_handling`, and `design_class`. **No `function_name` or `variable` keys** — those are intentionally omitted to match `get_means()` / `get_freqs()`.
- Name-style `"broom"` renames `variance` → `estimate` (column and label updated consistently).
- The two new warning classes `surveycore_warning_variance_all_na` and `surveycore_warning_variance_insufficient_n` are defined in `plans/error-messages.md` and are fired exactly once per variable-edge-case occurrence.
- `survey.lonely.psu` behavior is inherited from the variance engine — no extra cli messages are emitted by `get_variance()` itself.
- The roxygen `@details` block for `get_variance()` includes an explicit note that `ci_low` may be negative when the point estimate is near zero (builder requirement, per the CI edge-case row above).
- `R CMD check --as-cran` passes with 0 errors, 0 warnings, ≤2 pre-approved notes.

## Pipeline split

**recommended** — A new exported numerical estimator that crosses every design type, adds two new warning classes, introduces a new `survey_variance` result class, mutates `analysis-meta.R`, and requires numerical parity tests against `survey::svyvar()` on three design paths. Single-PR implementation would exceed a reviewable surface area.

Natural seam for the builder: split into two PRs.

- **PR 1 — feature/get-variance-core**: Owns `R/analysis-variance.R`, `R/analysis-variance-helpers.R` (the single `.variance_cell()` wrapper + `.score_variance()`), the `analysis-meta.R` refactor to `FAMILY_META_KEYS`, the `survey_variance` print method, and the broom adapter including the `variance → estimate` entry in `.apply_name_style()`. Implements Taylor and replicate dispatch paths inside `.variance_cell()` via delegation to `.taylor_mean_cell()` / `.replicate_mean_cell()`. Ships the full public API (the `na_handling` argument, the multi-variable iteration, result assembly, `.meta` shape, column labels) and numerical parity tests against `svyvar()` for `survey_taylor` and `survey_replicate` designs.
- **PR 2 — feature/get-variance-twophase-nonprob-collection**: **Does NOT re-author any helper from PR 1.** Only extends `.variance_cell()` to cover `survey_twophase` and `survey_nonprob` (delegating to the existing twophase/nonprob mean cell helpers) and adds `survey_collection` dispatch wiring (which is mostly free via `.dispatch_over_collection()`). Adds twophase and nonprob numerical parity tests plus collection-dispatch edge-case coverage (`C5`–`C11`). If a shared helper needs to change between PR 1 and PR 2, the change lands in PR 1 and is consumed (not copied) by PR 2.
