# Comprehension — Cohen's d for `get_t_test()` and `get_pairwise()`

> **Status: deferred — no established reference.**
>
> This comprehension drafts a design-based Cohen's d without a clear
> peer-reviewed or canonical reference for the estimator under complex
> survey weights. The choice of `sd_source` options, the population-SD
> standardizer, and the decision to return a plug-in point estimate with
> no SE/CI are all surveycore-defined rather than drawn from an outside
> methodological source. Treat this as a **novel concept** until a
> reference is located, or until the feature is explicitly labelled as a
> surveycore-defined extension with no outside anchor. Do not start
> implementation work from this document in its current form.

## Problem

Add a design-based Cohen's d effect size to `get_t_test()` and
`get_pairwise()`. The addition is a single new output column, `cohens_d`,
plus a new argument `sd_source` that controls the denominator. No change
to the existing numerator (weighted mean difference) and no change to the
existing t-statistic / p-value / CI machinery. Scope is **two-sample
Cohen's d only**: paired and one-sample cases are out of scope because
`get_t_test()` currently errors on anything other than exactly two active
levels of `by` (see `R/analysis-t-test.R` step 9d, class
`surveycore_error_by_not_two_levels`).

The motivation: under a complex survey design, the usual sample-pooled SD
denominator is neither design-consistent nor aligned with the
population-level inference the t-test is making. The standardizer should
come from a design-based population SD, not a sample-pooled one. The
effect size must therefore be computed using surveycore's own variance
machinery — specifically the forthcoming `get_variance()` (spec at
`plans/spec-get-variance.md`) — not by calling `survey::svyvar()`.

Semantically: for a two-sample comparison A vs. B, Cohen's d is

$$
d \;=\; \frac{\bar y_B^{\,w} - \bar y_A^{\,w}}{\widehat{\mathrm{SD}}_{\text{src}}(Y)},
$$

where the numerator is the weighted mean difference already returned in
the `estimate` column (coefficient on the B dummy from `survey_glm()`),
and the denominator `SD_src` is a design-based population SD selected by
`sd_source`. The resulting d is a **plug-in point estimate**: no SE, no
CI, no bootstrap. CI construction for design-based d is an unsettled
methodological question and is deferred (see G6).

## Formulas

Let the outcome be $y_i$, the grouping variable $g_i$ taking values in
active levels $\{L_1, \ldots, L_k\}$ (where $k = 2$ for `get_t_test()` and
$k \ge 2$ for `get_pairwise()`), and let $w_i$ be the survey weight. Let
$d_i \in \{0,1\}$ be the surveycore domain indicator and $m_i$ the
non-NA mask on $(y_i, g_i)$; write $a_i = d_i m_i$ for the active-row
indicator. For a given pair $(A, B) \subset \{L_1, \ldots, L_k\}$, let

$$
a_i^{A} = a_i \cdot \mathbb{1}(g_i = A), \qquad
a_i^{B} = a_i \cdot \mathbb{1}(g_i = B), \qquad
a_i^{AB} = a_i^{A} + a_i^{B}.
$$

### 1. Numerator — unchanged

The numerator is the current `estimate` column of `get_t_test()`:

$$
\widehat{\Delta} \;=\; \bar y_B^{\,w} - \bar y_A^{\,w}
\;=\; \hat\beta_{\text{slope}} \quad \text{(from `survey_glm()`)}.
$$

### 2. Denominator — `sd_source` determines the SD estimand

Three options. In every case the design variance is estimated by
`get_variance(design_*, y)` and the SD is its square root.

**(a) `sd_source = "full"` (default).** SD computed on the entire design
(all $k$ active groups + any out-of-group rows the original design
contained), after applying the surveycore domain mask and NA removal on
$y$:

$$
\widehat{\mathrm{SD}}_{\text{full}}(Y) \;=\; \sqrt{\widehat V_{\text{full}}(Y)}
$$

where $\widehat V_{\text{full}}(Y) = \texttt{get\_variance(design, y)}$ on
the **full** design passed by the user (before pair-restriction in
`get_pairwise()`). Includes both within-group and between-group variance.
This is the default because it yields directly comparable effect sizes
across all pairs in `get_pairwise()`, matching the ANOVA convention of a
shared MSE across post-hoc contrasts.

**(b) `sd_source = "restricted"`.** SD computed on the 2-group subset
$\{i : g_i \in \{A, B\}\}$:

$$
\widehat{\mathrm{SD}}_{\text{restr}}(Y) \;=\; \sqrt{\widehat V_{\text{restr}}(Y)}
$$

where $\widehat V_{\text{restr}}(Y)$ calls `get_variance()` on a
design restricted to rows with $a_i^{AB} = 1$ (via the surveycore domain
mask). Includes within-group and between-group variance of just $A$ and
$B$. Appropriate when the two groups are treated as standalone
populations rather than as levels of a larger factor, or when
`get_pairwise()` is used for pre-specified contrasts whose comparability
across pairs is not required.

**(c) `sd_source = "pooled_all"`.** Pooled within-group SD across all
$k$ active groups (ANOVA root-MSE analog). Within-group variance only —
no between-group contribution:

$$
\widehat V_{\text{pooled}}(Y) \;=\;
\frac{\sum_{\ell=1}^{k} (n_\ell - 1) \cdot \widehat V_\ell(Y)}{\sum_{\ell=1}^{k} (n_\ell - 1)},
\qquad
\widehat{\mathrm{SD}}_{\text{pooled}}(Y) \;=\; \sqrt{\widehat V_{\text{pooled}}(Y)},
$$

where $\widehat V_\ell(Y) = \texttt{get\_variance(design\_}\ell\texttt{, y)}$
on the single-group subset $\{i : g_i = L_\ell\}$ and
$n_\ell = \sum_i a_i \cdot \mathbb{1}(g_i = L_\ell)$ is the unweighted
in-domain non-NA count for group $\ell$. Weighting by $n_\ell - 1$ (not
by $W_\ell$) matches classical ANOVA convention and mirrors Stata's
`estat sd` semantics after a survey-design mean comparison.

When $k = 2$ (i.e., standalone `get_t_test()`), `"full"` and
`"restricted"` collapse to the same value provided the user's design
contains no extra rows outside those two groups. `"pooled_all"` differs
even at $k = 2$ because it strips between-group variance.

### 3. Per-stratum behaviour when `group` is active

When `group` is specified (subgroup stratification), the t-test already
runs per stratum. The SD denominator is computed **per stratum** as well:
for each stratum $s$, restrict to rows with active stratum membership
before applying the `sd_source` rule above. This matches how the t-test
itself is scoped — the effect size reflects the population within that
stratum.

### 4. Integration in `get_pairwise()` — pre-compute once

`get_pairwise()` restricts the design to each pair via the domain mask
before calling `get_t_test()` (see `R/analysis-t-test.R:736–745`). By the
time `get_t_test()` executes, the design it sees is already the 2-group
subset, so naively computing SD inside `get_t_test()` from its own
argument would always yield `"restricted"` regardless of the user's
`sd_source`.

Resolution: `get_pairwise()` computes the SD denominator **once per
stratum** on the original (pre-restriction) design, then passes the
scalar to each `get_t_test()` call via an internal argument (e.g.
`.sd_override`). Concretely:

- `"full"`: one `get_variance()` call per stratum on the full design,
  result reused across all $\binom{k}{2}$ pairs.
- `"restricted"`: one `get_variance()` call per (stratum × pair),
  computed fresh for each pair.
- `"pooled_all"`: $k$ single-group `get_variance()` calls per stratum,
  combined via the pooled formula, result reused across all pairs.

For standalone `get_t_test()`, no override is passed; `get_t_test()`
computes the SD itself per `sd_source` on the design the user provided.

### 5. Output column and attributes

New column in both `survey_t_test` and `survey_pairwise` tibbles:

| Column | Type | Label attribute |
|---|---|---|
| `cohens_d` | double | `"Cohen's d"` |

Per the user, `d_denominator` is **not** a column. It is recorded as an
attribute on the column or in `.meta` as `meta$effect_size$denominator`,
along with `meta$effect_size$sd_source` (`"full"` / `"restricted"` /
`"pooled_all"`) for reproducibility and citation. Also in `.meta`:
`meta$effect_size$estimator = "cohens_d"`.

No `name_style = "broom"` remap is required — broom does not define a
canonical name for design-based Cohen's d. Keep `cohens_d` under both
styles.

## Gotchas

### G1. Pre-computation, not per-pair, for `"full"` and `"pooled_all"` in `get_pairwise()`

The naive integration — compute SD inside `get_t_test()` on the design
it receives — silently reduces `"full"` and `"pooled_all"` to
`"restricted"` when called from `get_pairwise()`, because the design has
already been restricted via the domain mask. The spec must require
`get_pairwise()` to compute SD on the original design before the
pair-restriction loop and to pass it into `get_t_test()` via an internal
override. Standalone `get_t_test()` still needs to compute SD locally
per `sd_source` — so both code paths coexist.

### G2. `get_variance()` not yet built

The denominator calls `get_variance(design, y)` and returns a tidy data
frame where each row is one variable. As of this spec, `get_variance()`
is under active development (see `plans/spec-get-variance.md`,
`plans/comprehension-get-variance.md`). The Cohen's d spec should treat
it as an abstract dependency: describe the mathematical call, but do
not block on its landing. The implementation plan will be finalized
after `get_variance()` merges.

### G3. Per-stratum SD requires sub-design construction

For `group`-active calls, each stratum needs its own restricted design
before `get_variance()` can be invoked. The existing machinery in
`get_t_test()` already builds per-stratum masks (see `active_mask`
construction at `R/analysis-t-test.R:222–235`). The Cohen's d
computation must reuse the same masking logic — not invent a second
path — to guarantee that the SD and the t-test operate on identical
row sets.

### G4. Zero-variance variable

If the SD estimator returns 0 (all in-domain $y$ values are identical,
or all but one are), Cohen's d is $\Delta / 0$ — `Inf`, `-Inf`, or
`NaN` depending on sign of $\Delta$. Spec decision: return
`NA_real_` for `cohens_d` and emit
`surveycore_warning_zero_variance` (new warning class). Do not let `Inf`
propagate. Policy applies independently per row (per stratum × per
pair).

### G5. Numerical stability near zero variance

Replicate-weight variance estimates can produce small negative numerical
residuals for near-constant variables. `get_variance()` already handles
this defensively (`sqrt(max(0, v))` — see comprehension G8). Cohen's d
inherits this safety; no additional guard is needed beyond the
zero-variance rule in G4.

### G6. CI for design-based Cohen's d is deferred

The literature does not settle on a CI construction for design-based
Cohen's d. Three candidates exist (delta method, replicate bootstrap,
report point estimate only); none has a clear canonical form in the
survey-methodology literature. Spec decision: emit point estimate only,
document the gap in the roxygen, and leave CI work for a follow-up. No
`cohens_d_ci_low` / `cohens_d_ci_high` columns.

### G7. `"pooled_all"` degrees-of-freedom weighting

The pooled formula weights by $n_\ell - 1$ (unweighted counts), not by
$W_\ell$ (weighted totals). This is deliberate and matches the
classical ANOVA convention. It also matches the Stata `estat sd`
convention for survey-design post-hoc pairwise comparisons. Do **not**
"upgrade" to weighted pooling without a user decision — it changes the
estimand.

### G8. Sign convention

`get_t_test()` already defines `estimate = mean_B - mean_A` with
`B` being the second factor level after coercion (see step 9e,
`R/analysis-t-test.R:328–343`). Cohen's d inherits the same sign: a
positive d means B's mean exceeds A's. Spec should state this
explicitly so downstream consumers don't re-sign.

### G9. `get_pairwise()` override mechanism — internal, not exported

The override arg from `get_pairwise()` → `get_t_test()` is an internal
plumbing detail, not part of the public API. Use an unexported
argument convention — e.g., a `.sd_override` dotted arg — and document
it as internal in the roxygen. Users never call it directly.

### G10. Interaction with `na.rm`

`na.rm` currently only gates behaviour at the t-test level (NA rows in
$x$ or $by$ are always excluded; see step 9 and `R/analysis-t-test.R:49–51`).
The SD denominator must honour the same rule: rows with NA in $y$ are
excluded from `get_variance()`. Since `get_variance()` has its own
`na.rm` semantics (per `plans/spec-get-variance.md`), the call site
should pass `na.rm = TRUE` unconditionally, matching the t-test's fixed
behaviour.

### G11. Replicate-design behaviour

Replicate-weight designs are treated identically to Taylor designs.
Because Cohen's d is a **point estimate only** (no CI — see G6), there
is no need to recompute d per replicate. The SD denominator comes from
`get_variance()`, which already handles replicate designs natively via
its replicate-weight variance path; Cohen's d inherits that result
transparently as a scalar transform. No replicate-weight sandwich is
constructed for d itself.

### G12. Small-group / single-stratum SD

If a group has $n_\ell < 2$, `get_variance()` returns `NaN` for that
group (per `get_variance()` comprehension G5). Propagation rules:

- `"full"`: variance is computed on the full design; a single lonely
  group does not invalidate the estimate.
- `"restricted"`: if either group in the pair has $n < 2$, the
  restricted SD is `NaN`; `cohens_d = NA_real_`; emit
  `surveycore_warning_zero_variance` (or a new
  `surveycore_warning_insufficient_n_for_d` — needs user decision).
- `"pooled_all"`: groups with $n_\ell < 2$ are skipped in the pooled
  sum (their $(n_\ell - 1) = 0$ weight already excludes them naturally
  from both numerator and denominator — no special-casing needed).

### G13. Column labels — don't forget

Per `project_column_labels.md` memory, every `get_*()` output sets
column-level `label` attributes for gt integration. Add `cohens_d`
→ `"Cohen's d"` to the `col_labels` lists in both
`R/analysis-t-test.R:440–460` (t-test) and `:830–850` (pairwise).

## Reference mapping

| Reference | Specific mapping |
|---|---|
| `R/analysis-t-test.R` lines 90–487 (`get_t_test()`) | Host function. The new logic inserts: (a) validation of `sd_source`, (b) SD computation after step 9e (statistics extraction), (c) new `cohens_d` field in `row_list`, (d) column-label addition in step 14. |
| `R/analysis-t-test.R` lines 588–878 (`get_pairwise()`) | Host function. The new logic inserts: (a) validation of `sd_source`, (b) pre-loop SD computation per stratum and per sd_source (one-time for `"full"` / `"pooled_all"`, per-pair for `"restricted"`), (c) `.sd_override` forwarding to `get_t_test()`, (d) column-label addition. |
| `R/analysis-t-test.R:736–745` (domain-mask restriction in pair loop) | Motivates G1. Confirms that `get_t_test()`'s view of the design is already pair-restricted; SD cannot be computed inside `get_t_test()` when called from `get_pairwise()` without an override. |
| `plans/spec-get-variance.md` + `plans/comprehension-get-variance.md` | Abstract dependency. The `get_variance()` contract (tidy data frame, one row per variable, `variance` column) is the call site for every branch of §2. G2 flags this as the scheduling constraint. |
| Stata `svy: mean ...; estat sd` | Canonical source for "use the design-adjusted population SD" for standardizers on survey-weighted mean comparisons. Drives the `"full"` default and the `"pooled_all"` ANOVA-style formula. |
| Cohen (1988) *Statistical Power Analysis* §2.2 | Classical definition of d with pooled SD. Under complex designs the pooled SD is replaced by the design-based SD via the reduction in §2; the standardized-difference form is unchanged. |
| `project_column_labels.md` memory entry | G13. Ensures gt-friendly output. |

## Assumptions

### A1. Scope — two-sample only

Paired Cohen's d and one-sample Cohen's d are **out of scope** because
`get_t_test()` errors on anything other than 2 active levels
(`surveycore_error_by_not_two_levels`). Adding those effect-size
branches presupposes adding the corresponding t-test branches, which is
not part of this plan. Follow-up work can extend the same `sd_source`
machinery to paired/one-sample tests once those branches exist.

### A2. `sd_source` option names are final

After iteration with the user, the three values are `"full"`,
`"restricted"`, `"pooled_all"`. The earlier candidate `"subset"` was
renamed to `"restricted"` for clarity. `"pooled_all"` is ANOVA-style
within-group pooling across all $k$ active groups, not an all-pairs
pooling.

### A3. Default is `"full"`

Matches ANOVA MSE convention; yields comparable effect sizes across all
pairs in `get_pairwise()`; is the most stable (estimated from the most
data) of the three. Changing the default would require a user
decision — do not re-litigate without one.

### A4. `cohens_d` is the only new column; denominator metadata lives in attributes / `.meta`

Per the user: only `cohens_d` in the tibble body; denominator details in
`.meta$effect_size`. Keeps the tibble flat and preserves broom-style
column-count compatibility.

### A5. No CI, no SE for Cohen's d in this plan

Documented methodological gap, not an oversight (G6). Roxygen for the
`cohens_d` column must say so.

### A6. `get_variance()` must exist before implementation can proceed

The implementation plan cannot be finalized until `get_variance()`
lands on `develop`. The spec can be written and reviewed against the
abstract `get_variance()` contract.

### A7. Per-stratum SD when `group` is active

Confirmed with user. Alternative (one design-wide SD reused across
strata) is rejected — inconsistent with how the t-test itself is scoped.

### A8. Zero-variance returns `NA_real_`, warns

Confirmed with user. Do not return `Inf` or `NaN` for `cohens_d`. Warning
class `surveycore_warning_zero_variance` is new and must enter
`plans/error-messages.md` before implementation.

### A9. Override arg from pairwise to t-test is internal plumbing

Not part of the public API. The name (`.sd_override` or similar) and
structure (scalar vs. data frame keyed by stratum) are implementation
details to be decided in the spec, not the comprehension.

## Open questions (to resolve in Stage 1 spec)

1. **Small-group warning class (G12)** — **Resolved:** new class
   `surveycore_warning_insufficient_n_for_d`. Distinct from
   `surveycore_warning_zero_variance` (which signals a constant-y situation,
   not a thin-group situation). Both classes must enter
   `plans/error-messages.md` before implementation.
2. **`.meta$effect_size` shape** — **Resolved:** nested. Fields accessible as
   `.meta$effect_size$estimator` (`"cohens_d"`),
   `.meta$effect_size$sd_source` (`"full"` / `"restricted"` / `"pooled_all"`),
   and `.meta$effect_size$denominator` (the numeric SD used, or a
   per-stratum/per-pair structure when `group` is active). Matches the
   existing nested `.meta` convention (see `project_analysis_meta_structure`).
3. **Override arg name** — **Deferred.** Not decided at the comprehension
   stage; resolve during Stage 1 spec when the pairwise/t-test integration
   plumbing is locked in. Candidate names (`.sd_override`, `.sd_denominator`)
   remain on the table.
