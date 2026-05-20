# Comprehension — pool-pvals

## Problem

The user wants `pool_pvals()`: a post-hoc adjuster that takes a list of result
tibbles (each carrying a `p_value` column produced by `get_diffs()`,
`get_t_test()`, `get_pairwise()`, `get_anova()`, or
`clean.survey_glm_fit()`), row-binds them into a single family, and applies
`stats::p.adjust()` once across the entire pool. The motivating workflow is
multi-DV analysis: the analyst tests several outcomes within the same study,
each generating its own contrasts, and a multiplicity correction must be
applied across the union of hypotheses (the family) rather than inside each
call. The within-call `pval_adj` argument on existing `get_*()` functions
corrects only within a single call's contrast set; cross-call correction
needs a separate primitive. This is a generic table-shape function — it does
not depend on which surveycore analysis produced the input.

## Formulas

**Benjamini-Hochberg (1995).** Given m independent (or PRDS) p-values
p_(1) ≤ p_(2) ≤ … ≤ p_(m) testing null hypotheses H_(1)…H_(m), let

  k = max { i : p_(i) ≤ (i / m) · α }

and reject H_(1)…H_(k). The procedure controls FDR = E[V/max(R,1)] ≤ (m_0/m) · α
≤ α, where V is the number of false rejections and R is the total number of
rejections. Equivalently, the BH-adjusted p-value at rank i is

  p̃_(i) = min_{j ≥ i} ( m · p_(j) / j ),

and the analyst rejects H_(i) at level α iff p̃_(i) ≤ α.

**Symbol → argument binding for `pool_pvals()`:**

| Symbol     | Binding                                                              |
|------------|----------------------------------------------------------------------|
| m          | `length(na.omit(pooled[[p_col]]))` — the size of the pooled family   |
| p_(i)      | i-th order statistic of the pooled `p_col` after `bind_rows()`       |
| α          | not stored; the analyst applies the threshold downstream             |
| p̃_(i)     | written to `new_col` (default `"p_value_adj"`)                       |
| family     | rows of the bound tibble, indexed by `id_col` (default `".source"`)  |
| method     | `method` argument, dispatched verbatim to `stats::p.adjust()`        |

For other methods the formulas are the standard Holm / Hochberg / Hommel /
Bonferroni / BY / none from `stats::p.adjust()`; surveycore does not
re-implement them.

## Gotchas

- **Empty list** (`length(results) == 0`) — error
  `surveycore_error_pool_pvals_empty`. No silent return of an empty tibble.
- **Single-element list** (`length(results) == 1`) — legal; for all
  eight `stats::p.adjust.methods` values, m = 1 returns the input
  unchanged (identity). Useful for canonicalizing column shape; do not
  warn.
- **All-NA pooled p-values** — `stats::p.adjust()` returns all NAs; emit
  `surveycore_warning_pool_pvals_no_pvalues_available` and still return the
  bound tibble with an all-NA `new_col`.
- **Some-NA pooled p-values** — pass through to `stats::p.adjust()`; by
  default `n = sum(!is.na(p))`. Document this denominator choice; do not
  surface an `n` argument in v1.
- **Heterogeneous columns across list elements** — `dplyr::bind_rows()`
  NA-fills missing columns, which is the desired behavior; document it.
- **Pre-existing `new_col` in any input** (the within-call `pval_adj` case):
  if `strip_within_adj = FALSE`, rename the incoming column to
  `paste0(new_col, "_within")` and warn
  (`surveycore_warning_pool_pvals_input_pre_adjusted`). Detection runs per
  list element; renaming must happen before `bind_rows()` so survivors stack.
- **Unnamed list** — `id_col` defaults to integer index (1, 2, …) coerced
  to character; named list uses names verbatim. Mixed (some named, some not)
  follows `dplyr::bind_rows()` semantics — empty names become `""`.
- **Method not in `stats::p.adjust.methods`** — error
  `surveycore_error_pool_pvals_invalid_method` before any binding work.
- **`p_col` missing in any element** — error
  `surveycore_error_pool_pvals_missing_pcol` listing offending element
  names/indices.
- **Zero-row tibble in input** — legal; contributes no rows to the family;
  `bind_rows()` handles. No warning.
- **Non-list input** (single tibble, vector) — error
  `surveycore_error_pool_pvals_not_list`. Tibbles are lists in R, so the
  check must guard via `inherits(results, "data.frame")` first.
- **Single-PSU / design pathologies** — out of scope; `pool_pvals()` only
  reads p-values, never re-fits.

## Reference mapping

- **Benjamini & Hochberg (1995), §3, eq. (1)** → default `method = "BH"`;
  the canonical FDR-controlling procedure cited in the surveycore SOP.
- **`stats::p.adjust` help, §Methods** → `method` validated against
  `stats::p.adjust.methods`; no surveycore-side method table maintained.
- **`stats::p.adjust` help, §`n` argument** → m equals
  `sum(!is.na(p))` by default; we do not expose `n` in v1 (YAGNI per
  engineering-preferences §3).
- **`dplyr::bind_rows()` `.id` argument** → behavior model for `id_col`,
  including character-coerced integer indices for unnamed lists.
- **surveycore `get_diffs(pval_adj = ...)`, `get_pairwise(pval_adj = "holm")`**
  → these stay unchanged; `pool_pvals()` operates one layer up. Recommended
  workflow: pass `pval_adj = NULL` to upstream calls when the user intends
  to pool, so within-call adjustment is not produced and the
  pre-adjusted-input warning never fires.
- **adlgraphs `export_treatment_effects()`** → style reference for the list
  loop / `bind_rows()` pattern only; that function does not pool, so its
  semantics are explicitly not copied.
- **Benjamini & Yekutieli (2001)** → ground for `method = "BY"`; the
  primary procedure controls FDR under positive regression dependency
  (PRDS); a conservative modification (eq. 2.10 of Benjamini-Yekutieli
  2001) extends to arbitrary dependence structures.

## Assumptions

- **Family is pre-specified.** The user has decided the contents of
  `results` before looking at any p-value. Inclusion is not result-dependent;
  exploratory subgroup tests are excluded from the pool and reported
  uncorrected per the SOP. `pool_pvals()` cannot police this; document it.
- **Inputs are raw p-values.** BH assumes uniform-under-null inputs. When
  `new_col` already exists in an input tibble, double-adjustment is
  statistically invalid: an adjusted p-value is no longer uniform under H_0,
  so re-applying BH does not compose into FDR control over any meaningful
  family. Hence the rename-and-warn behavior; `strip_within_adj = TRUE`
  shifts responsibility to the user.
- **Equal weighting of hypotheses.** `stats::p.adjust()` treats every
  pooled p-value as one member of the family. Differential importance,
  hierarchical structure, and weighted FDR are out of scope (Benjamini-
  Bogomolov 2014, Yekutieli 2008 — flagged in request §Out of scope).
- **Independence or PRDS for BH/FDR; arbitrary dependence acceptable for
  Holm, Bonferroni, BY.** Multi-DV survey p-values are typically PRDS but
  not independent. Document method choice; do not enforce.
- **No re-fitting.** `pool_pvals()` reads `p_col` and writes `new_col`.
  It does not re-compute SEs, dfs, or test statistics. If the user mixed
  estimators (Wald + likelihood-ratio + Rao-Scott) in one pool, that is the
  user's call; we do not warn.
