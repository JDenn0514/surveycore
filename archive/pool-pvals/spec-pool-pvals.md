# Spec — pool-pvals

**Status**: READY (Stage 3r resolved; spec-review BLOCK → PASS)
**Target version**: 0.8.3.9000
**PR range**: PR 1 (single-PR feature)

## Scope

### In

- A new exported function `pool_pvals()` that takes a list of result tibbles
  produced by surveycore analysis functions (`get_diffs()`, `get_t_test()`,
  `get_pairwise()`, `get_anova()`, `clean.survey_glm_fit()`, or any future
  `get_*()` carrying a `p_value` column), row-binds them, and applies a
  single global `stats::p.adjust()` correction across the pooled family.
- The function is generic over result type — it operates on any list of
  tibbles that share a `p_value` column (or a user-specified column name),
  regardless of which surveycore analysis produced them.
- A new exported S3 print method `print.survey_pooled_pvals()` for the
  `survey_pooled_pvals` class returned by `pool_pvals()`. The method
  prints a header summarizing the adjustment method, family size, and
  significance count, delegates the body to tibble's print, and prints
  a footer noting how many p-values were excluded as NA. The header
  uses `cli` formatting per surveycore convention.
- A `survey_pooled_pvals` S3 class extending `tbl_df` / `tbl` /
  `data.frame` (i.e., the result IS a tibble, just with an additional
  class). Class hierarchy: `c("survey_pooled_pvals", "tbl_df", "tbl",
  "data.frame")`. The class carries a `.meta` attribute (described
  below).
- Roxygen `@details` block, organized with visual sub-headers
  (`## Method choice`, `## Default method`, `## Recommended workflow`,
  `## Statistical caveats`, `## Limitations`, `## See also`) for
  readability. Required subsections:
  1. **Method choice** — for each of the eight `stats::p.adjust.methods`
     values, state what error rate it controls (FDR vs FWER), what its
     dependence assumptions are (independence, PRDS, MTP_2, arbitrary),
     and a one-line recommendation. State that Hochberg and Hommel
     require independence or MTP_2 dependence (not just PRDS); recommend
     Holm or Bonferroni instead when DVs are correlated and FWER control
     is desired. Mention "Bonferroni's inequality" by name.
  2. **Default method justification** — explain that `method = "BH"` is
     the default because survey p-values across DVs are typically PRDS;
     point users to `method = "BY"` when robustness under arbitrary
     dependence is required.
  3. **Recommended workflow** — set `pval_adj = NULL` on every upstream
     `get_*()` call when planning to pool, so within-call adjustment is
     not produced and `pool_pvals()` applies the global correction once.
     Note that attributes carried on input tibbles (e.g.,
     `variable_label` from `get_diffs()` results) are NOT preserved; this
     matches `dplyr::bind_rows()` default behavior. Users who need
     attribute preservation must re-attach after pooling.
  4. **Statistical caveat about double-adjustment** — including the
     upstream in-place overwrite issue: surveycore's `get_t_test()`,
     `get_pairwise()` (default `pval_adj = "holm"`), and `get_diffs()`
     overwrite the `p_value` column in place when `pval_adj != NULL`;
     `pool_pvals()` cannot detect this by column inspection alone — the
     `surveycore_warning_pool_pvals_input_pre_adjusted` warning class
     only fires when a separate `p_value_adj` column is present.
  5. **Worked NA-denominator example** — with pooled p-values
     `(0.01, 0.02, 0.05, NA, NA)` and `method = "BH"`, the denominator
     is `n = 3` (not 5); adjusted values are `(0.03, 0.03, 0.05, NA, NA)`.
  6. **Column-shape user-owned risk** — column shapes and the semantic
     coherence of any `group` column must be checked by the user; the
     function does not validate semantic coherence across input
     elements.
  7. **Cross-design pooling caveat** — when results come from different
     surveys, sampling frames, or weighting schemes, the user is
     responsible for ensuring exchangeability across the pool.
  8. **Small-m regime** — BH and related step-up methods become very
     conservative when m < 5; suggest Bonferroni or
     unadjusted-with-exploratory-framing for tiny families.
  9. **`"fdr"` alias note** — `"fdr"` is a dispatch alias for `"BH"`
     per `stats::p.adjust()` source; the two produce identical output.
  10. **Discrete p-value caveat** — classical BH assumes continuous
      p-values; chi-square tests of small contingency tables can produce
      ties that violate this. Point users to the `DiscreteFDR` package
      on CRAN for that regime.
  11. **Collection workflow note** — users with results from a
      collection-dispatched `get_*()` call (a single tibble carrying a
      `.id` / `.survey` column) should split into per-`.id` tibbles via
      `dplyr::group_split()` before passing to `pool_pvals()`.
  12. **See also (out-of-scope alternatives)** — Storey (2002) q-values,
      Romano-Wolf (2005) bootstrap stepdown, and the `multcomp` /
      `mutoss` packages provide multiplicity machinery surveycore does
      not implement.
- One runnable `@examples` block demonstrating multi-DV pooling.
- `@references` block citing Benjamini & Hochberg (1995), Benjamini &
  Yekutieli (2001), Holm (1979), Hochberg (1988), and Hommel (1988).

### Out

- Hierarchical FDR procedures (Benjamini-Bogomolov 2014, Yekutieli 2008).
- Excel writing, formatting, color coding.
- Multi-DV support inside `get_diffs()` itself.
- Method or default changes to existing `pval_adj` arguments in any
  `get_*()` function. In particular, no upstream code changes to
  `get_t_test()`, `get_pairwise()`, or `get_diffs()` to suppress in-place
  `p_value` overwrite. The double-adjustment hazard is documented in
  `@details`; detection is out of scope for v1.
- A `survey_collection`-aware variant. Direct support for
  `survey_collection` dispatch results (a single tibble with
  `.id` / `.survey` column from collection-dispatched `get_*()` calls)
  is **not** provided in v1. Users with collection results should split
  into per-`.id` tibbles via `dplyr::group_split()` and pass the
  resulting list to `pool_pvals()`. Documented in `@details` (see Scope
  §11) but not automated.
- Re-fitting, recomputation of SEs / dfs / test statistics.
- Surfacing an `n` argument for `stats::p.adjust()`.
- Storey (2002) q-value estimation, Romano-Wolf (2005) bootstrap
  stepdown, `multcomp` / `mutoss` functionality. Documented in
  `@details` "See also" with pointers, but not provided.
- Preservation of input-tibble attributes (e.g., `variable_label` from
  `get_diffs()` results) across the bind. Documented in `@details`
  (Recommended workflow); users who need attribute preservation must
  re-attach after pooling.

## Architecture

- **Files touched**:
  - `R/analysis-pool-pvals.R` (new) — defines `pool_pvals()` and
    `print.survey_pooled_pvals()`.
  - `R/analysis-helpers.R` (modified) — adds three private helpers:
    `.validate_pval_adjustment_method()`, `.is_plain_list()`, and
    `.validate_list_columns()`.
  - `R/analysis-diffs.R` (modified) — refactors the inline
    `pval_adj` validation block to call
    `.validate_pval_adjustment_method()`.
  - `R/analysis-t-test.R` (modified) — refactors the inline
    `pval_adj` validation block in `get_pairwise()` to call
    `.validate_pval_adjustment_method()`.
  - `tests/testthat/test-analysis-pool-pvals.R` (new).
  - `man/pool_pvals.Rd` (regenerated by roxygen).
  - `man/print.survey_pooled_pvals.Rd` (regenerated by roxygen).
  - `_pkgdown.yml` (new section "Post-hoc / multiplicity correction"
    listing `pool_pvals` and `print.survey_pooled_pvals`).
  - `plans/error-messages.md` (6 new error rows + 2 new warning rows;
    already added in Stage 3r).
  - `NEWS.md` (entry under 0.8.3.9000).
  - `NAMESPACE` (regenerated; adds `pool_pvals` export and the
    `print.survey_pooled_pvals` S3 method registration).
- **Functions added**: `pool_pvals()` (exported);
  `print.survey_pooled_pvals()` (exported S3 method);
  `.validate_pval_adjustment_method()`, `.is_plain_list()`,
  `.validate_list_columns()` (private).
- **Functions modified**: `get_diffs()` and `get_pairwise()` are
  refactored to use `.validate_pval_adjustment_method()`. Their
  observable behavior, error class, and message text on the validation
  path are unchanged; only the implementation moves to a shared helper.
- **Class changes**: new S3 class `survey_pooled_pvals` extending
  `tbl_df` / `tbl` / `data.frame`. No new S7 classes.

## Function contracts

### `pool_pvals(results, method = "BH", p_col = "p_value", new_col = "p_value_adj", id_col = "source", strip_within_adj = FALSE)`

- **Signature**:
  ```
  pool_pvals(
    results,
    method = "BH",
    p_col = "p_value",
    new_col = "p_value_adj",
    id_col = "source",
    strip_within_adj = FALSE
  )
  ```

- **Arguments**:
  - `results` — a list (named or unnamed) of tibbles / data frames.
    Each element must contain a column named per `p_col`. List length
    must be `>= 1`. List elements may have heterogeneous column sets;
    missing columns are NA-filled on bind. A bare tibble is **not**
    acceptable input (a single result must be wrapped in `list(x)`).
  - `method` — character scalar; one of `stats::p.adjust.methods`
    (`"holm"`, `"hochberg"`, `"hommel"`, `"bonferroni"`, `"BH"`,
    `"BY"`, `"fdr"`, `"none"`). Default `"BH"`. Validated via the
    shared private helper `.validate_pval_adjustment_method()` against
    `stats::p.adjust.methods`.
  - `p_col` — character scalar (column-name string, **not** a bare
    name or NSE expression); name of the column holding raw p-values
    to be pooled. Default `"p_value"`. Must exist in every list
    element.
  - `new_col` — character scalar (column-name string); name of the
    output column where pooled-adjusted p-values are written. Default
    `"p_value_adj"`.
  - `id_col` — character scalar (column-name string); name of the
    source-identifier column added to the bound output. Default
    `"source"`. Filled from list names; for unnamed elements the
    integer index is coerced to character (matching
    `dplyr::bind_rows(.id = ...)` semantics).
  - `strip_within_adj` — logical scalar. If `FALSE` (default) and any
    input contains a column named per `new_col`, that column is renamed
    to `paste0(new_col, "_within")` per element before binding, and a
    warning is emitted. If `TRUE`, any pre-existing `new_col` column is
    silently dropped from each element before binding; no warning.

  *Note on argument naming*: `p_col`, `new_col`, and `id_col` take
  character column-name strings, not bare names or NSE expressions.
  The `_col` suffix is intentional and signals "this argument names a
  column".

- **Returns**: an object of S3 class `c("survey_pooled_pvals",
  "tbl_df", "tbl", "data.frame")` — a tibble with an additional class
  tag. Shape:

  - One row per row across all input list elements (sum of input
    `nrow`), in input list order, in within-element order.
  - **Column ordering**: (1) the union of original input columns (in
    input-union order, NA-filled where absent); (2) `id_col` (default
    `"source"`); (3) `new_col` (default `"p_value_adj"`); (4)
    `paste0(new_col, "_within")` if applicable (i.e., if
    `strip_within_adj = FALSE` and at least one input had a
    pre-existing `new_col`).
  - Original columns retain their input values; `new_col` holds
    `stats::p.adjust(pooled_p, method)` over the pooled vector with
    NAs preserved positionally.
  - **Type coercion**: if `p_col` (or any other shared column) has
    different types across input elements (integer, double, factor,
    character), `dplyr::bind_rows()` coerces to the common supertype
    (typically numeric for integer/double; character for factor). This
    is `dplyr::bind_rows()` default behavior; surveycore does not
    customize it.
  - **Attribute preservation**: attributes carried on input tibbles
    (e.g., `variable_label` from `get_diffs()` results) are NOT
    preserved on the output; this matches `dplyr::bind_rows()` default
    behavior. Users who need attribute preservation must re-attach
    after pooling.
  - **`.meta` attribute**: a list-shaped attribute named `.meta` is
    attached to the output. Required keys:
    - `method` — the value passed to `method` (e.g., `"BH"`).
    - `family_size` — `m`, the number of non-NA p-values in the pool.
    - `n_total` — total rows after bind (including NA p-values).
    - `n_na` — number of NA p-values in the pool.
    - `n_significant_05` — count of `new_col < 0.05` (informational;
      excludes NAs).
    - `id_col` — the value passed to `id_col` (so `print` can find it).
    - `p_col` — the value passed to `p_col`.
    - `new_col` — the value passed to `new_col`.

- **Errors** (validation precedence):

  Validation runs in the following explicit numbered order. Earlier
  checks fire before later ones; user data is never bound before all
  pre-bind checks pass.

  1. Non-list / data.frame guard — `surveycore_error_pool_pvals_not_list`
     (also fires for atomic vectors and `NULL`).
  2. Empty list check — `surveycore_error_pool_pvals_empty`.
  3. Method validation (delegated to
     `.validate_pval_adjustment_method()`) —
     `surveycore_error_pool_pvals_invalid_method`.
  4. Per-element `p_col` presence —
     `surveycore_error_pool_pvals_missing_pcol`.
  5. Per-element `id_col` collision check —
     `surveycore_error_pool_pvals_id_col_collision`.
  6. Per-element `new_col` detection: rename to
     `paste0(new_col, "_within")` (warn) or drop silently per
     `strip_within_adj`.
  7. `dplyr::bind_rows(.id = id_col)` step.
  8. Pooled `p_col` range check —
     `surveycore_error_pool_pvals_invalid_pvalues` (NA values exempt).
  9. `stats::p.adjust()` step.
  10. All-NA pool warning check —
      `surveycore_warning_pool_pvals_no_pvalues_available`.

  | Class | Condition |
  |---|---|
  | `surveycore_error_pool_pvals_not_list` | `results` is not a list, OR is itself a `data.frame`/tibble. The data-frame check fires first because tibbles are lists in R. |
  | `surveycore_error_pool_pvals_empty` | `length(results) == 0` |
  | `surveycore_error_pool_pvals_invalid_method` | `method` is not a single string in `stats::p.adjust.methods`. The shared helper `.validate_pval_adjustment_method()` parameterizes the error class so it can be reused by `get_diffs()` and `get_pairwise()` (which raise `surveycore_error_invalid_pval_adj`). |
  | `surveycore_error_pool_pvals_missing_pcol` | One or more list elements lack a column matching `p_col`; message must list offending element names or integer indices |
  | `surveycore_error_pool_pvals_id_col_collision` | One or more list elements already contain a column matching `id_col`; message must list offending element names or integer indices and suggest renaming the column or supplying a different `id_col`. Validation runs *before* `dplyr::bind_rows(.id = ...)` is called so user data is never silently overwritten |
  | `surveycore_error_pool_pvals_invalid_pvalues` | After binding (and after `id_col` and `p_col` validation), one or more non-NA values of pooled `p_col` are outside `[0, 1]`. Message must list offending row identifiers (the `id_col` value plus the row index within source). Validation runs *after* the bind step and *before* `stats::p.adjust()` is called |

- **Warnings**:

  | Class | Condition |
  |---|---|
  | `surveycore_warning_pool_pvals_input_pre_adjusted` | `strip_within_adj = FALSE` and at least one input element already contains `new_col`; message names which elements |
  | `surveycore_warning_pool_pvals_no_pvalues_available` | After binding, every value of `p_col` is `NA`; output is still returned with all-NA `new_col` |

- **Edge cases** (behavior fully specified):
  - **Empty list** (`length(results) == 0`) — error
    `surveycore_error_pool_pvals_empty`. No silent return.
  - **Single-element list** — legal. For all eight
    `stats::p.adjust.methods` values, `m = 1` returns the input
    unchanged. No warning.
  - **Zero-row tibble in input** — legal. Contributes no rows to the
    pooled family. No warning.
  - **All-NA pooled `p_col`** — warning
    `surveycore_warning_pool_pvals_no_pvalues_available`; bound tibble
    is still returned with all-NA `new_col`.
  - **Some-NA pooled `p_col`** — passed through to `stats::p.adjust()`,
    which uses `n = sum(!is.na(p))` by default. `new_col` is NA where
    input `p_col` was NA. No warning. Documented in `@details`.
  - **Heterogeneous columns across list elements** —
    `dplyr::bind_rows()` NA-fills missing columns; the union of all
    input columns appears in the output. No warning.
  - **Heterogeneous `p_col` types across list elements** —
    `dplyr::bind_rows()` coerces to the common supertype. Documented
    in Returns.
  - **Pre-existing `new_col` in any element**, `strip_within_adj =
    FALSE` — rename the incoming column to `paste0(new_col,
    "_within")` per element before binding; emit
    `surveycore_warning_pool_pvals_input_pre_adjusted` once
    listing offending elements. The rename happens at the per-element
    level so every survivor stacks; rows from elements without the
    column carry `NA` in the renamed column.
  - **Pre-existing `new_col`**, `strip_within_adj = TRUE` — silently
    drop the column from each offending element before binding; no
    warning; `paste0(new_col, "_within")` does not appear in output.
  - **Unnamed list / mixed-named list** — `id_col` follows
    `dplyr::bind_rows(.id = ...)` semantics: integer-coerced-to-character
    indices for unnamed elements; element names verbatim for named
    elements; empty string `""` for elements with empty names in a
    mixed list.
  - **Method not in `stats::p.adjust.methods`** — error
    `surveycore_error_pool_pvals_invalid_method`. Validated before any
    list iteration or bind work.
  - **`p_col` missing in any element** — error
    `surveycore_error_pool_pvals_missing_pcol`. Message lists offending
    element identifiers (names or 1-based indices).
  - **Non-list input (single tibble, atomic vector, NULL)** — error
    `surveycore_error_pool_pvals_not_list`. The tibble case must be
    guarded explicitly because tibbles are lists in R; check
    `inherits(results, "data.frame")` first and reject before the
    `is.list()` test. Helper `.is_plain_list()` encapsulates this
    guard.
  - **`id_col` collision** — at least one input element already has a
    column whose name matches `id_col`. Error
    `surveycore_error_pool_pvals_id_col_collision`. Validation runs
    before `dplyr::bind_rows(.id = ...)` is called so user data is
    never silently overwritten.
  - **Pooled `p_col` contains values outside `[0, 1]`** — error
    `surveycore_error_pool_pvals_invalid_pvalues`. Validation runs
    after bind, before `stats::p.adjust()`. NA values are exempt from
    the range check.

### `print.survey_pooled_pvals(x, n = 10, ...)`

- **Signature**:
  ```
  print.survey_pooled_pvals(x, n = 10, ...)
  ```

- **Arguments**:
  - `x` — a `survey_pooled_pvals` object.
  - `n` — integer; passed through to tibble's print method to control
    how many rows are shown. Default `10`.
  - `...` — additional arguments passed to tibble's print method.

- **Returns**: `invisible(x)`.

- **Behavior**:
  - Prints a header line (using `cli` formatting) summarizing key
    `.meta` fields, e.g.:
    `<survey_pooled_pvals: method = "BH", family_size = 12, 3 significant at α = 0.05>`
  - Delegates the body to tibble's print via `print(NextMethod())` so
    that all standard tibble formatting (column types, truncation,
    alignment) is preserved.
  - If `attr(x, ".meta")$n_na > 0`, prints a footer line such as
    `# 2 p-values were NA and excluded from the family`.
  - Returns `invisible(x)`.

### Private helpers (in `R/analysis-helpers.R`)

The following private helpers are added to `R/analysis-helpers.R`.
None are exported. All are documented inline with `@keywords internal`
+ `@noRd`.

- **`.validate_pval_adjustment_method(method, arg_name = "method", call = rlang::caller_env(), class = "surveycore_error_invalid_pval_adj")`**
  Validates `method` against `stats::p.adjust.methods`. The `class`
  argument is parameterized so callers can pass their own class:
  - `pool_pvals()` calls with
    `class = "surveycore_error_pool_pvals_invalid_method"`.
  - `get_diffs()` and `get_pairwise()` call with the default
    `class = "surveycore_error_invalid_pval_adj"` (preserves their
    existing error class and message text).
  The `arg_name` parameter renders the argument name in the error
  message (e.g., `pval_adj` for `get_diffs()` / `get_pairwise()`,
  `method` for `pool_pvals()`). The `call =` argument is propagated
  via `rlang::caller_env()` so the error appears to originate from the
  caller, not the helper.

- **`.is_plain_list(x)`** — returns logical scalar. `TRUE` iff
  `is.list(x) && !inherits(x, "data.frame")`. Used by `pool_pvals()`
  to guard against single-tibble input.

- **`.validate_list_columns(results, col_names, id_col)`** — iterates
  over the list, checks each element for the presence of each name in
  `col_names` (presence check) and the absence of `id_col` (collision
  check). Returns a named list with two character vectors:
  `missing_pcol` (offending element identifiers — names if available,
  otherwise 1-based indices coerced to character) and `id_collision`
  (same shape). The caller decides which error to raise based on the
  return value.

## Quality gates

- All gotchas from `comprehension.md` are covered above by an
  explicit error class, warning class, or edge-case behavior row.
- No new entries in `DESCRIPTION` `Imports` or `Suggests`. Implementation
  uses only `stats`, `dplyr`, `cli`, and `rlang`, all currently in
  Imports.
- `_pkgdown.yml` adds a new "Post-hoc / multiplicity correction"
  section listing `pool_pvals` and `print.survey_pooled_pvals`.
  `pool_pvals` is **not** placed in the `get_*` analysis family.
- All six error classes and both warning classes are added to
  `plans/error-messages.md` (rows PP-1 through PP-8) **before** any
  code is written; their class names and message templates are the
  source of truth for the implementation.
- The shared validation helper `.validate_pval_adjustment_method()` is
  added in `R/analysis-helpers.R` and is the single source of truth for
  `stats::p.adjust.methods` validation across `pool_pvals()`,
  `get_diffs()`, and `get_pairwise()`. The refactor of `get_diffs()`
  and `get_pairwise()` must preserve their existing error class
  (`surveycore_error_invalid_pval_adj`) and message text exactly; this
  is verified by re-running the existing test snapshots in
  `tests/testthat/_snaps/test-analysis-diffs.md` and
  `tests/testthat/_snaps/test-analysis-t-test.md` without updates.
- `@references` block on `pool_pvals` cites all five primary sources:
  - Benjamini, Y. and Hochberg, Y. (1995). Controlling the False
    Discovery Rate: A Practical and Powerful Approach to Multiple
    Testing. *Journal of the Royal Statistical Society, Series B*
    57(1), 289–300. `\doi{10.1111/j.2517-6161.1995.tb02031.x}`
  - Benjamini, Y. and Yekutieli, D. (2001). The control of the false
    discovery rate in multiple testing under dependency. *Annals of
    Statistics* 29(4), 1165–1188. `\doi{10.1214/aos/1013699998}`
  - Holm, S. (1979). A simple sequentially rejective multiple test
    procedure. *Scandinavian Journal of Statistics* 6(2), 65–70.
  - Hochberg, Y. (1988). A sharper Bonferroni procedure for multiple
    tests of significance. *Biometrika* 75(4), 800–802.
    `\doi{10.1093/biomet/75.4.800}`
  - Hommel, G. (1988). A stagewise rejective multiple test procedure
    based on a modified Bonferroni test. *Biometrika* 75(2), 383–386.
    `\doi{10.1093/biomet/75.2.383}`
  Bonferroni 1936 is bibliographically thorny; surveycore omits the
  inline citation but mentions "Bonferroni's inequality" by name in
  the `@details` Method choice subsection.
- `@examples` block runs without error in a fresh `library(surveycore)`
  session and demonstrates pooling across at least two DVs.

## Pipeline split

`recommended` — although the change ships in a single PR, it adds a
new exported function, a new exported S3 print method, a new S3
class, modifies two existing files (`R/analysis-diffs.R`,
`R/analysis-t-test.R`) for the shared-validator refactor, and touches
six functional / configuration files in total. The Stage 3r
resolutions expanded the contract scope (S3 class with `.meta`
attribute, print method, shared validator) past the
`optional` threshold.
