# Decisions — pool-pvals

**Date**: 2026-04-29
**Stage**: 2r (Stage 2 resolution; methods-review BLOCK → PASS)

This file records the resolutions to all findings raised in
`methods-review.md`. Resolutions were supplied by the user; planner
applied them to `spec.md`, `test-spec.md`, and `comprehension.md`.

## BLOCKING

- **B-1 — out-of-range p-value validation** → **validate**.
  Added new error class
  `surveycore_error_pool_pvals_invalid_pvalues`. After the bind step,
  before calling `stats::p.adjust()`, the implementation must check
  that all non-NA values of pooled `p_col` satisfy `0 <= p <= 1`. On
  failure, error with a message that lists offending row identifiers
  (the `id_col` value plus row index within source).

- **B-2 — `id_col` collision** → **error**.
  Added new error class
  `surveycore_error_pool_pvals_id_col_collision`. Before binding, each
  input element is checked for a column matching `id_col`; if any
  element has it, error with a message listing offending elements and
  suggesting either renaming the column or supplying a different
  `id_col`. The check fires *before* `dplyr::bind_rows(.id = ...)` is
  called, so user data is never silently overwritten. The
  `## Decisions to make at spec review` open-question section was
  deleted from `spec.md`.

- **B-3 — upstream `get_*()` overwrite of `p_value` column** →
  **document only**.
  No upstream code changes in this PR. Roxygen `@details` includes a
  strong paragraph warning users that surveycore's `get_t_test()`,
  `get_pairwise()` (default `pval_adj = "holm"`), and `get_diffs()`
  overwrite the `p_value` column in place when `pval_adj != NULL`.
  `pool_pvals()` cannot detect this by column inspection; the warning
  class `surveycore_warning_pool_pvals_input_pre_adjusted` only catches
  a separate `p_value_adj` column. Recommended workflow: set
  `pval_adj = NULL` on every upstream call when planning to pool.

- **B-4 — PRDS / FDR vs FWER / Hochberg-Hommel docs** → **document**.
  Roxygen `@details` includes (1) a "Method choice" subsection naming
  each of the eight methods, what it controls (FDR vs FWER), what its
  dependence assumptions are (independence, PRDS, MTP_2, arbitrary),
  and a one-line recommendation; and (2) a "Default method" sentence
  justifying `method = "BH"` because survey p-values are typically
  PRDS, with a pointer to `method = "BY"` for users wanting robustness
  under arbitrary dependence.

## REQUIRED-JUDGMENT_CALL

- **RJ-1 — BH-vs-BY default** → **keep BH default**.
  PRDS caveat and BY recommendation documented in @details (B-4).

- **RJ-2 — Hochberg/Hommel independence caveat** → **include**.
  Documented in the Method choice subsection: Hochberg and Hommel
  require independence or MTP_2 dependence (not just PRDS); recommend
  Holm or Bonferroni instead when DVs are correlated and FWER control
  is desired.

## ADVISORY (all included)

- **A-1 — `"fdr"` alias** → include in @details. One-line note that
  `"fdr"` is a dispatch alias for `"BH"` per `stats::p.adjust()`
  source — they produce identical output.

- **A-2 — discrete p-values** → include. One-paragraph @details note
  that classical BH assumes continuous p-values; chi-square tests of
  small contingency tables can produce ties that violate this. Point
  users to the `DiscreteFDR` package on CRAN for that regime.

- **A-3 — out-of-scope alternatives** → include in `## Scope.Out` and a
  brief @details "See also" reference. List Storey (2002) q-values,
  Romano-Wolf (2005), and `multcomp` / `mutoss` as alternatives
  surveycore does NOT provide.

- **A-4 — small-m regime** → include. One-line @details note that BH
  and related methods become very conservative when m < 5; suggest
  Bonferroni or unadjusted-with-exploratory-framing for tiny families.

- **A-5 — cross-design pooling** → include. One-line @details note that
  when results come from different surveys / sampling frames /
  weighting schemes, the user is responsible for ensuring
  exchangeability. The function does not police this.

## REQUIRED-UNAMBIGUOUS

- **R-1 — citations** → applied. `@references` block now cites:
  - Benjamini & Hochberg (1995) `\doi{10.1111/j.2517-6161.1995.tb02031.x}`
  - Benjamini & Yekutieli (2001) `\doi{10.1214/aos/1013699998}`
  - Holm (1979) — *Scandinavian Journal of Statistics*, no DOI cited
  - Hochberg (1988) `\doi{10.1093/biomet/75.4.800}`
  - Hommel (1988) `\doi{10.1093/biomet/75.2.383}`
  Bonferroni 1936 is bibliographically thorny and not commonly cited
  inline; omitted, but "Bonferroni's inequality" is mentioned by name
  in the Method choice subsection.

- **R-2 — BY characterization** → applied to `comprehension.md`
  §Reference mapping. The BY entry now reads: "primary procedure
  controls FDR under positive regression dependency (PRDS); a
  conservative modification (eq. 2.10 of Benjamini-Yekutieli 2001)
  extends to arbitrary dependence structures."

- **R-3 — m = 1 identity wording** → applied to `spec.md` edge-case row
  and `comprehension.md` §Gotchas. Both now state "for all eight
  `stats::p.adjust.methods` values, m = 1 returns the input unchanged.
  No warning."

- **R-4 — NA-denominator worked example** → applied to spec.md
  `@details` requirements. The worked example reads: "With pooled
  p-values `(0.01, 0.02, 0.05, NA, NA)` and `method = 'BH'`, the
  denominator is `n = 3` (not 5); adjusted values are
  `(0.03, 0.03, 0.05, NA, NA)`."

- **R-5 — column-shape and group-column user-owned risk** → applied to
  spec.md `@details` requirements. Two short notes — column shapes and
  `group` column semantics must be checked by the user; the function
  does not validate semantic coherence.

---

# Stage 3r — Spec review resolutions (2026-04-29)

This section records the resolutions to the findings raised in
`spec-review.md` (verdict BLOCK → PASS). Resolutions were supplied
by the user; planner applied them to `spec.md`, `test-spec.md`, and
`plans/error-messages.md`.

## BLOCKING

- **SB-1 — `_col` suffix on argument names** → **keep `p_col`,
  `new_col`, `id_col` as-is**. The `_col` suffix is genuinely
  informative (signals "names a column, not a bare expression"). The
  spec-reviewer's recommendation to rename was overreach. A
  clarifying sentence was added to spec.md `## Function contracts §
  Arguments` noting that these arguments take character column-name
  strings, not bare names or NSE expressions. No rename.

- **SB-2 — leading-dot output column name** → **rename `.source` →
  `source`**. The default value of the `id_col` argument changes from
  `".source"` to `"source"` everywhere in spec.md and test-spec.md.

- **SB-3 — attribute preservation** → **document non-preservation**.
  Added to spec.md `## Function contracts § Returns`: attributes
  carried on input tibbles (e.g., `variable_label` from `get_diffs()`
  results) are NOT preserved; this matches `dplyr::bind_rows()`
  default behavior. Users who need attribute preservation must
  re-attach after pooling. Documented in `@details` "Recommended
  workflow" and as an explicit Scope.Out item.

- **SB-4 — improve `not_list` error message** → **applied** in
  `plans/error-messages.md` (row PP-2). The message now includes a
  remediation hint: `"Wrap a single result in {.code list()} (e.g.,
  {.code pool_pvals(list(get_diffs(...)))}). For multiple results,
  supply a named or unnamed list."`

## REQUIRED-UNAMBIGUOUS

- **SR-1 — extract method validation to shared helper** → **applied**.
  New private helper `.validate_pval_adjustment_method(method,
  arg_name = "method", call = rlang::caller_env(), class =
  "surveycore_error_invalid_pval_adj")` added to
  `R/analysis-helpers.R`. The `class` argument is parameterized so
  callers can choose:
  - `pool_pvals()` calls with
    `class = "surveycore_error_pool_pvals_invalid_method"`.
  - `get_diffs()` and `get_pairwise()` call with the default
    `class = "surveycore_error_invalid_pval_adj"` (preserves their
    existing error class and message text).
  Files-touched expanded: `R/analysis-helpers.R` (modified),
  `R/analysis-diffs.R` (modified), `R/analysis-t-test.R` (modified).
  The refactor is observably equivalent; existing snapshots for
  `pval_adj` invalid-method errors in
  `tests/testthat/_snaps/test-analysis-diffs.md` and
  `tests/testthat/_snaps/test-analysis-t-test.md` must continue to
  pass without update.

- **SR-2 — explicit validation precedence** → **applied** to spec.md
  `## Function contracts § Errors` as a numbered list of 10 steps
  (non-list guard → empty list → method → per-element pcol → per-
  element id_col collision → new_col rename/drop → bind_rows →
  range check → p.adjust → all-NA warning).

- **SR-3 — output column ordering** → **applied** to spec.md
  `## Function contracts § Returns`: union of original input columns
  in input-union order; then `id_col`; then `new_col`; then
  `paste0(new_col, "_within")` if applicable.

- **SR-4 — `bind_rows()` type coercion** → **documented** in
  spec.md Returns: heterogeneous types are coerced to common
  supertype (typically numeric for integer/double; character for
  factor) per `bind_rows()` default behavior.

- **SR-5 — explicit dual-pattern test syntax** → **applied** to
  test-spec.md. The dual-pattern syntax block is shown once at the
  top of the error-tests section, then parameterized over the six
  error classes.

## REQUIRED-JUDGMENT_CALL (resolved)

- **SJ-1 — function name** → **keep `pool_pvals()`**, do not rename
  to `get_pooled_pvals()`. `_pkgdown.yml` gets a new section titled
  "Post-hoc / multiplicity correction" (separate from the `get_*`
  analysis family) listing `pool_pvals` and the new
  `print.survey_pooled_pvals` method.

- **SJ-2 — return type** → **return S3 class
  `survey_pooled_pvals`** (NOT plain tibble). This is a meaningful
  expansion of the contract. Specifically:
  - **Class hierarchy**: `c("survey_pooled_pvals", "tbl_df", "tbl",
    "data.frame")`. The result IS a tibble, just with an additional
    class.
  - **`.meta` attribute**: a list-shaped attribute with keys
    `method`, `family_size`, `n_total`, `n_na`, `n_significant_05`,
    `id_col`, `p_col`, `new_col`.
  - **Print method**: new exported S3 method
    `print.survey_pooled_pvals(x, n = 10, ...)` — prints a `cli`-
    formatted header line summarizing key `.meta` fields, delegates
    the body to tibble's print via `print(NextMethod())`, and prints
    a footer noting `n_na` excluded NA p-values when relevant.
  - **Architecture impact**: `R/analysis-pool-pvals.R` defines both
    `pool_pvals()` and `print.survey_pooled_pvals()`. NAMESPACE
    exports both. `_pkgdown.yml` lists both in the new Post-hoc
    section. test-spec.md gains `inherits()` checks, `.meta`
    structure tests, and print snapshot tests.
  - **Wording**: all "plain tibble" / "no S3 class" language in the
    spec is replaced with the survey_pooled_pvals (S3 subclass of
    tibble) framing.

- **SJ-3 — `_within` rename vs drop** → **keep current rename + warn
  behavior**. No change to spec; confirmed intact after the other
  edits.

- **SJ-4 — collection workflow** → **document as out-of-scope for
  v1**. Spec.md `## Scope.Out` adds an explicit exclusion: direct
  support for `survey_collection`-dispatch results (a single tibble
  with `.id` / `.survey` column) is not provided. The `@details`
  block has a "Collection workflow" subsection telling users to use
  `dplyr::group_split()` to convert a collection-dispatched result
  into a list before passing to `pool_pvals()`.

- **SJ-5 — extract list/column-existence helpers** → **applied**.
  Two private helpers added to `R/analysis-helpers.R`:
  - `.is_plain_list(x)` — returns `is.list(x) && !inherits(x,
    "data.frame")`.
  - `.validate_list_columns(results, col_names, id_col)` — iterates
    the list and returns the offending element identifiers (names
    or 1-based indices) for use in error messages.

## ADVISORY (resolved)

- **SA-1 — group `@details` subsections with visual headers** →
  **applied**. Spec.md `## Scope.In` notes the `@details` block is
  organized with visual sub-headers (`## Method choice`, `## Default
  method`, `## Recommended workflow`, `## Statistical caveats`,
  `## Limitations`, `## See also`).

