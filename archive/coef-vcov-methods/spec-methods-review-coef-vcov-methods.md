## Methodology Review: coef-vcov-methods — Pass 1 (2026-06-22)

Lenses applied: 1 (Estimator Specification), 2 (Variance Estimation),
3 (Degrees of Freedom and Inference), 4 (Domain Estimation),
5 (Established Practice). Lens 6 not applicable: no literature or
comprehension.md attached.

---

### New Issues

#### Lens 1 — Estimator Specification

---

**Issue 1: `survey_freqs` within-group vcov zeros violate the multinomial
constraint**
Lens: 1, 2
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

Proportions from `get_freqs()` within a group sum to 1 by construction.
The spec (§III.6, step 3) states: "Within each group block, the matrix is
diagonal (per-variable variances on the diagonal, zeros for within-group
off-diagonal elements)." For `survey_freqs` this is categorically wrong.
The Taylor-linearization cross-level covariance for levels j and k within
group g is:

```
Cov(p_j, p_k) = (1/N_d^2) * Var_design(sum_i w_i * (I_{ij} - p_j * I_{ig})(I_{ik} - p_k * I_{ig}))
```

This is strictly negative (a unit cannot simultaneously be in level j and
level k). Setting it to zero is not an approximation — it is a structural
error. Any downstream Wald test for a categorical distribution built from
this vcov matrix will be anti-conservative.

The current per-cell SE computation (`.taylor_freq_cell`,
`.replicate_freq_cell`) passes a single-column influence matrix per level.
Cross-level covariances are never computed, so they cannot be recovered from
stored data alone.

Options:
- **[A] Compute joint vcov for `survey_freqs` blocks via multi-column
  influence matrix** — For each group block, accumulate a `p × R` influence
  matrix across all levels, call `.svy_recvar()` once to obtain the full
  `p × p` block. — Effort: high, Risk: low, Impact: statistically correct
  for composition-aware downstream work, Maintenance: new code path in
  `analysis-methods-coef-vcov.R`
- **[B] Return diagonal-only matrix with `cli::cli_warn()` documenting the
  omitted off-diagonal structure** — Effort: low, Risk: medium, Impact:
  honest representation without breaking API; downstream tools propagate
  `se^2` on diagonal, Maintenance: documentation burden
- **[C] Do nothing** — vcov() silently returns a wrong matrix; any Wald
  test using it produces incorrect p-values

**Recommendation: A** — The multinomial covariance is fundamental to
frequency tables and directly computable from the existing influence-function
machinery already in the codebase.

Source: Lumley (2010), *Complex Surveys*, §4.3; Binder (1983), ISRJ 51:279–292.

---

**Issue 2: `survey_corr` (long) off-diagonal vcov zeros — correlated pairs
share observations**
Lens: 1, 4
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

For long-format `survey_corr` results with multiple pairs (e.g., age:income,
age:bmi, income:bmi), the spec assembles vcov() with zeros for all
off-diagonal elements. But pairs sharing a variable — e.g., r(X,Y) and
r(X,Z) — have non-zero covariance through their shared marginals. The
delta-method gradient for r(X,Y) depends on {x_i}, as does r(X,Z); their
cross-pair covariance `g_XY' * Sigma_full * g_XZ` is generally non-zero.

The per-pair implementation in `.corr_pair_result()` computes a 3×3 vcov
per pair but retains no cross-pair influence product. The off-diagonal
covariance is therefore not available from stored data at vcov() call time.
The spec's support matrix (§I) lists `survey_corr (long)` as "In scope"
with no caveat, and §III.6 asserts diagonal structure with no qualification.

Options:
- **[A] Return `NA_real_` for all off-diagonal elements with a warning** —
  Mirror the approach recommended for quantiles. The diagonal is se_r^2;
  off-diagonal = NA. Add `rlang::warn()` noting that cross-pair covariances
  require joint estimation. — Effort: low, Risk: low, Impact: honest
  representation; safe for downstream use, Maintenance: low
- **[B] Compute full cross-pair vcov at vcov() call time** — Requires storing
  per-unit influence vectors per pair or access to the design. Not stored
  in the current result. — Effort: high, Risk: medium, Impact: correct,
  Maintenance: requires revisiting `analysis-corr.R`
- **[C] Do nothing** — vcov() silently implies independence between correlated
  pairs; joint tests for equality of correlations are wrong

**Recommendation: A** — NA off-diagonal is honest and forward-compatible.
Matches the precedent for `survey_quantiles` already implied in the spec.

Source: Olkin & Siotani (1964), *Essays in Probability and Statistics*,
235–251 [verify]; Lumley (2010), §4.4.

---

**Issue 3: Cross-group vcov zeros are an undocumented limitation for domain
estimation**
Lens: 2, 4
Severity: BLOCKING
Resolution type: JUDGMENT CALL

The spec §III.6 step 3 states: "Across groups, all elements are 0." In
complex survey designs using Taylor linearization, domain estimates from
different groups share PSUs and strata. Two domain estimates — e.g.,
mean(age)|NE and mean(age)|South — are computed over the same full sample.
Sampled PSUs contribute to both domains when they contain units from multiple
regions; the between-domain covariance is therefore non-zero in general
(a function of the joint sampling structure).

Setting cross-group covariances to zero is correct only when groups are
mutually exclusive strata in a stratified design where no PSU crosses strata.
For domain estimation over a non-stratified grouping variable (the standard
case in surveycore), this is wrong. Any downstream Wald test or contrast
spanning groups silently uses a misspecified weight matrix.

The spec does not acknowledge this limitation anywhere: not in §III.6,
not in §VII, not in the quality gates (§VIII).

Options:
- **[A] Document as a stated limitation; add a `cli::cli_warn()` when
  `vcov()` is called on a grouped result** — State in §III.6 and §VII:
  "Cross-group covariances are structural zeros. This is exact only when
  groups define non-overlapping strata with no shared PSUs. For domain
  estimation, cross-group covariances are non-zero and are not estimated
  from stored data." Emit a `rlang::warn()` when `length(group_cols) > 0`.
  — Effort: low, Risk: low, Impact: users are informed; mirrors
  `survey::vcov.svyby()` behavior, Maintenance: low
- **[B] Implement correct cross-group covariance** — Requires storing the
  design object at vcov() time and re-estimating jointly via `svyby()`.
  Out of scope for this phase. — Effort: very high, Risk: high, Impact:
  correct, Maintenance: high
- **[C] Do nothing** — Cross-group vcov silently returns zeros; users
  performing cross-domain Wald tests get wrong results with no warning

**Recommendation: A** — Matches `survey::vcov.svyby()` convention (diagonal
only, with a warning). Documents the limitation honestly without requiring
architectural changes.

Source: Lumley (2010), §4.2; Binder (1983), ISRJ 51:279–292 [verify page].

---

**Issue 4: confint() stores `.degf(design)` df but existing `get_*()` functions
use `Inf` — numerical divergence**
Lens: 3, 5
Severity: BLOCKING
Resolution type: JUDGMENT CALL

The spec §III.1 says `.build_survey_result_attr()` stores
`df = .degf(design)`. For a Taylor design with 15 PSUs and 5 strata,
`.degf(design)` returns 10. The spec §III.8 then uses this df in the
t-distribution critical value for `confint()`.

But the existing analysis functions (`get_means()`, `get_totals()`,
`get_freqs()`, `get_ratios()`) all hardcode `degf <- Inf` and build the
`ci_low`/`ci_high` columns using the normal approximation. Confirmed at:
- `/Users/jacobdennen/surveycore/R/analysis-means.R` line 166
- `/Users/jacobdennen/surveycore/R/analysis-totals.R` line 166
- `/Users/jacobdennen/surveycore/R/analysis-freqs.R` line 173

For `level = 0.95` and `df = 10`, z = 1.960 vs t(10) = 2.228 — a 14%
difference in the half-width. A user who calls `get_means(d, age)` and
then `confint(result)` receives a CI that is materially wider than the
stored `ci_low`/`ci_high` columns from the same object with no warning.

The spec does not acknowledge this divergence anywhere. `survey::confint.svystat()`
defaults to `df = Inf` (normal approximation) and requires the user to pass
`df = degf(design)` explicitly for t-based intervals. This is the correct
convention.

Options:
- **[A] Store `df = Inf` for all non-calibrated designs** — Change
  `.build_survey_result_attr()` to store `Inf` for non-calibrated Taylor,
  replicate, and nonprob designs (store actual df only for calibrated
  Taylor designs where per-cell df is already finite). `confint()` then
  exactly matches the stored CI columns. Mirror `survey::confint.svystat()`'s
  default-to-Inf convention. — Effort: low, Risk: low, Impact: consistent
  between `confint()` and tibble CI columns; matches survey convention,
  Maintenance: must update §III.1 and §III.8
- **[B] Store actual df and document the divergence** — `confint()` uses
  t-distribution; tibble columns use normal. Add a spec note warning users.
  — Effort: low, Risk: medium (silent inconsistency remains for small
  designs), Impact: t-based CIs are arguably more conservative and correct
  for small samples, Maintenance: explain divergence in every vignette
- **[C] Do nothing** — Same object yields two different CI values from
  `ci_low`/`ci_high` columns vs `confint()` with no warning

**Recommendation: A** — Consistency between representations of the same CI
is more important than automatic t-distribution use. Survey's convention
(Inf default, explicit df optional) is the right model to follow.

Source: `/Users/jacobdennen/surveycore/R/analysis-means.R` line 166;
`survey::confint.svystat()` default `df = Inf`; spec §III.1.

---

#### Lens 2 — Variance Estimation

---

**Issue 5: Woodruff-derived SE in vcov() diagonal — confint() round-trip is
inconsistent unless df values match**
Lens: 1, 3
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec §VI (`get_quantiles()`) clarifies that when `variance = "se"` is
requested for quantile results, the `se` column contains a Woodruff-derived
quantity: `se_q = (ci_high - ci_low) / (2 * z_crit)`, where `z_crit` was
computed using the Woodruff df. The spec then places `se_q^2` on the
diagonal of vcov(), and `confint.survey_result()` constructs CIs as
`coef ± qt(1-(1-level)/2, df_attr) * SE`. If `df_attr` (stored in the
attribute) equals the df used in the Woodruff construction, the formula
round-trips algebraically:

```
confint lower = qhat - qt(0.975, df_ww) * [(ci_high - ci_low) / (2 * qt(0.975, df_ww))]
             = qhat - (ci_high - ci_low) / 2   [= Woodruff lower]
```

But if `df_attr` ≠ df used in Woodruff construction (which is the case
under Issue 4 — `.degf(design)` vs `Inf`), the CI from `confint()` is
neither the Woodruff interval nor a statistically principled alternative.

Additionally, the original scope matrix (§I) stated `vcov()` returns
NA-filled for quantiles. §VI later overrides this without adequate
justification. Placing `se_q^2` on the diagonal asserts the squared
Woodruff half-width *is* the variance, which does not hold for skewed
distributions where the Woodruff CI is asymmetric.

Options:
- **[A] Store `df = df_used_in_woodruff` specifically for quantile results**
  — Add class-specific df logic in `.build_survey_result_attr()` or at the
  `get_quantiles()` attribute-attachment site, ensuring the Woodruff df and
  the confint df are the same. `confint()` then exactly reproduces Woodruff
  bounds. — Effort: medium, Risk: low, Impact: statistically valid and
  consistent, Maintenance: must keep the two df values in sync
- **[B] Keep NA on the diagonal of vcov() for quantiles (revert to original
  scope table)** — `confint()` returns NA for quantile results; users rely
  on the stored `ci_low`/`ci_high` Woodruff bounds. — Effort: low,
  Risk: low, Impact: statistically honest; `confint()` non-functional for
  quantiles via this path, Maintenance: none
- **[C] Document in the spec and roxygen that `confint()` on quantile
  results only round-trips to Woodruff bounds when df values are consistent**
  — Effort: low, Risk: medium, Impact: quantile confint remains functional
  but requires careful df management by the user, Maintenance: ongoing
  documentation burden
- **[D] Do nothing** — df mismatch silently produces neither the Woodruff
  interval nor a principled alternative; no warning fires

**Recommendation: A** — Storing the Woodruff df explicitly for quantile
results is the only option that makes `confint()` both functional and
statistically valid for this class. Resolve Issue 4 first to establish the
df-storage policy.

Source: Woodruff (1952), *JASA* 47(260):635–646; spec §I (original NA claim)
vs §VI (override); `/Users/jacobdennen/surveycore/R/analysis-quantiles-helpers.R`
line 213.

---

**Issue 6: `<<-` caching operator is self-contradictory and writes to the
wrong environment**
Lens: 2
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §III.6 says:

> "The assembled matrix is stored in `attr(object, ".survey_result")$var`
> using `attr(object, ".survey_result") <<- ...` (local deep copy, not
> mutating the caller's object). The cached value is re-used on subsequent
> calls if `attr(object, ".survey_result")$var` is non-`NULL`."

This is self-contradictory: `<<-` inside `vcov.survey_result(object, ...)`
assigns to the **enclosing environment** (the package namespace or calling
frame), not back to the caller's binding. `object` is a local copy (R passes
by value). The spec's own next paragraph correctly acknowledges "vcov()
cannot mutate the caller's object in place" and concludes "the cache exists
for the lifetime of the return value chain within a single R expression."

If the cache lifetime is only within a single expression, `<<-` is
simultaneously wrong (writes to the wrong location) and useless (the function
call is already complete before any second call could benefit). The
`se`-to-variance conversion is O(p) and negligible in cost.

Fix: Remove the caching language entirely. Compute the matrix fresh on each
call. Replace the caching paragraph with: "The matrix is computed from the
`se` column on each call via `se^2` squaring. No caching is performed."

Options:
- **[A] Remove caching; compute vcov fresh on each call** — Effort: low,
  Risk: low, Impact: eliminates a broken mechanism with no performance cost
  for realistic p, Maintenance: none
- **[B] Implement a genuine environment-based cache** — Use a package-level
  `local({cache <- list()})` keyed on object identity. Effort: high,
  Risk: medium (memory leak for long sessions), Impact: speedup only for
  very large p (unlikely in practice), Maintenance: ongoing eviction logic
- **[C] Keep `<<-` as written** — Silently pollutes calling frame or package
  namespace; cache is never used by a subsequent call

**Recommendation: A** — se^2 squaring is trivial; option B complexity is
not justified.

Source: Chambers (2008), *Software for Data Analysis*, §5.1; R Language
Definition §3.5.1.

---

**Issue 7: Within-group cross-variable zeros for multi-variable means are
an undocumented approximation**
Lens: 2, 5
Severity: REQUIRED
Resolution type: JUDGMENT CALL

The spec §III.6 step 3 states that within each group block the matrix is
diagonal (off-diagonal zeros). For `get_means(d, c(age, income), group = region)`,
estimates mean(age)|NE and mean(income)|NE are computed from the same PSUs
in the same stratum. Their linearized influence functions u_age and u_income
share the same cluster structure, so Cov(mean(age), mean(income)) within
NE is generally non-zero. `survey::vcov.svystat()` for a multi-variable
`svymean(~api00 + api99, dclus1)` returns a full non-diagonal matrix.

The current per-cell implementation computes each variable's SE independently,
so cross-variable covariances within a group are never estimated. The spec
does not document this as a limitation.

For all currently supported classes, `estimate_cols` has length 1, so this
is latent. But the spec (§III.6 step 5) explicitly describes the multi-column
case, asserting zero off-diagonal, which will be wrong when any class with
multiple estimate columns is added.

Options:
- **[A] Add a documentation note to §III.6 and the quality gate** — State
  explicitly that within-group cross-variable covariances are structural
  zeros (not computed) and that users requiring full cross-variable joint
  covariance should use `survey::svymean()` with `cbind()`. Restrict
  the multi-column block description to a future extension with a DEFERRED
  label. — Effort: low, Risk: low, Impact: honest, Maintenance: none
- **[B] Implement joint vcov for multi-variable blocks** — Requires calling
  `svymean()` jointly or building a multi-column influence matrix in the
  Taylor path. — Effort: high, Risk: medium, Impact: correct cross-variable
  covariance, Maintenance: ongoing
- **[C] Do nothing** — Approximation is undocumented; future multi-column
  class would silently produce a wrong vcov

**Recommendation: A** — Accurate documentation at zero implementation cost.
The issue is latent for all current classes; defer joint estimation.

Source: Lumley (2010), §2.3; `survey::vcov.svystat()` observed on APICLUS1.

---

**Issue 8: §I scope matrix and §VI quantile section are contradictory**
Lens: 2
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The §I support matrix states for `survey_quantiles`: "`vcov()` returns
NA-filled matrix (Woodruff CIs do not produce a full vcov)." But §VI
(`get_quantiles()` sub-section) states: "The note in the scope matrix above
about NA-filled matrix is incorrect — the matrix will be diagonal (as for
all other cases)."

Both sections cannot be correct. This contradiction will cause builder
confusion about which behavior to implement. The resolution depends on Issue 5
(Woodruff SE validity): if Issue 5 resolves to Option B (revert to NA), §VI
must be corrected to match §I. If it resolves to Option A (df alignment),
§I must be corrected to match §VI.

Either way, the contradiction must be resolved before implementation. This
is a blocker for the quantile code path.

Options:
- **[A] Resolve Issue 5 first; update whichever section is inconsistent with
  the chosen resolution** — Effort: low, Risk: low, Impact: spec is
  self-consistent, Maintenance: none

**Recommendation: A** — This is a direct dependency on Issue 5.

Source: Spec §I (survey_quantiles row) vs spec §VI (get_quantiles()
sub-section).

---

**Issue 9: Per-cell df variation for calibrated Taylor designs — scalar df
in attribute may be wrong for some cells**
Lens: 2
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec stores a single scalar `df = .degf(design)` in the attribute.
But the existing `get_means()` implementation computes per-cell df when
calibration is active (confirmed at
`/Users/jacobdennen/surveycore/R/analysis-means.R` line 238 and 261).
For a calibrated Taylor design with many groups, different cells can have
different effective df. A single scalar df applied uniformly in `confint()`
will be incorrect for cells whose actual df differs from `.degf(design)`.

Options:
- **[A] Store per-row df vector (`df = numeric(p)`) in the attribute** —
  `confint()` uses `df[i]` for parameter i. — Effort: medium, Risk: low,
  Impact: correct CIs for calibrated multi-group Taylor designs,
  Maintenance: attribute layout change
- **[B] Store scalar `min(per-cell df)` — conservative** — Effort: low,
  Risk: low (conservative, not wrong), Impact: slightly wider CIs than
  needed for well-powered cells, Maintenance: none
- **[C] Keep scalar `.degf(design)` and document the limitation** —
  Effort: low, Risk: low for non-calibrated designs (current majority),
  Impact: calibrated multi-group results get slightly incorrect CIs

**Recommendation: A** — The per-cell df is already computed in the existing
`get_*()` functions; threading it through adds minimal cost and fixes a
real accuracy issue for calibrated designs.

Source: `/Users/jacobdennen/surveycore/R/analysis-means.R` lines 238, 261.

---

#### Lens 3 — Degrees of Freedom and Inference

---

**Issue 10: df from `.degf()` is integer for replicate designs; spec
declares `numeric(1)`**
Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §II attribute layout declares `df = numeric(1)`. But `.degf()`
in the replicate branch returns `max(1L, ncol(rep_mat) - 1L)` — an integer
literal. The Taylor branch uses `max(1, ...)` with a double literal and
returns numeric. Verified in
`/Users/jacobdennen/surveycore/R/analysis-helpers.R` lines 991–995.

In practice `qt()` handles integer df correctly. The risk is defensive code
checking `is.double()` or `typeof() == "double"`, or serialisation
round-trips (e.g., `saveRDS`) that preserve integer type while the caller
expects double.

Fix: In `.build_survey_result_attr()`, store `df = as.numeric(.degf(design))`
rather than `df = .degf(design)`.

Options:
- **[A] Add `as.numeric()` coercion in `.build_survey_result_attr()`** —
  Effort: low, Risk: low, Impact: guarantees the declared type contract,
  Maintenance: none
- **[B] Coerce inside `.degf()` itself** — Also fixes type for all existing
  callers of `.degf()`. — Effort: low, Risk: low, Impact: broader fix,
  Maintenance: none
- **[C] Do nothing** — type is integer for replicate designs; downstream
  `is.double(df)` checks will silently fail

**Recommendation: A** — Coerce at the attribute-construction boundary to
avoid changing `.degf()` semantics for existing callers.

Source: `/Users/jacobdennen/surveycore/R/analysis-helpers.R` lines 977–1005.

---

**Issue 11: No guard for `df ≤ 0` in `confint()`**
Lens: 3
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §VII edge-case table has no entry for `df ≤ 0`. `.degf()` applies
`max(1, ...)` internally, but the spec §VI documents that `get_diffs()`
attaches the `.survey_result` attribute manually — a path that bypasses
`.build_survey_result_attr()`. If any future manual attachment provides
`df = 0`, then `qt(p, df = 0)` returns `NaN` with a base-R warning (not
an error) and `confint()` silently fills the matrix with `NaN`. Verified:
`qt(0.975, df = 0)` → `NaN` (Warning: NaNs produced).

Fix: Add a validation guard at the top of `confint.survey_result()`:

```r
if (is.finite(df) && df <= 0) {
  cli::cli_abort(
    c("x" = "Design degrees of freedom must be > 0 (got {df})."),
    class = "surveycore_error_invalid_df"
  )
}
```

Also add an edge-case row to §VII: "`df ≤ 0` → throws
`surveycore_error_invalid_df`."

Options:
- **[A] Add guard in `confint.survey_result()`** — Catches all construction
  paths including manual attribute attachment. — Effort: low, Risk: low,
  Impact: converts silent NaN into a diagnostic error, Maintenance: none
- **[B] Add guard in `.build_survey_result_attr()`** — Catches most
  paths but misses `get_diffs()` manual attachment. — Effort: low, Risk:
  medium, Impact: incomplete coverage
- **[C] Do nothing** — silent NaN-filled CI matrix from designs with 1 PSU
  per stratum

**Recommendation: A** — Guard in `confint()` covers all construction paths.

Source: R console verification — `qt(0.975, df=0)` → NaN; spec §VI
`get_diffs()` manual attribute attachment.

---

**Issue 12: `confint()` column label formula — `paste0()` claim of matching
`stats::confint` is imprecise at extreme levels**
Lens: 3
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec §III.8 says column names "follow `stats::confint` convention" and
gives `paste0(100 * (1 - level) / 2, " %")`. For `level = 0.999`, this
yields `"99.95 %"` while `stats:::format_perc(a, 3)` yields `"100 %"` (due
to rounding to 3 significant digits). The divergence only occurs at unusual
levels; for all common values (0.80, 0.90, 0.95, 0.99) both formulas agree.

Fix: Remove the words "following `stats::confint` convention" and replace
with: "matching `stats::confint.default()` for all standard confidence levels
(0.80, 0.90, 0.95, 0.99); the `paste0` formula is canonical for this
implementation."

Options:
- **[A] Remove the misleading conformance claim; keep the `paste0` formula**
  — Effort: low, Risk: low, Impact: no behavioral change; eliminates
  misleading claim, Maintenance: none
- **[B] Switch to `stats:::.format_perc(a, 3)` for full conformance** —
  Risk: depends on an unexported internal function (namespace fragility)
- **[C] Do nothing** — misleading conformance claim remains

**Recommendation: A** — `paste0` formula is preferable to depending on an
unexported `stats:::` function.

Source: R console verification; `stats::confint.default` source.

---

**Issue 13: df prose example in §III.8 cites wrong tail probability**
Lens: 3
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

Section §III.8 states: "When `df` is `Inf`, `stats::qt(level/2, df = Inf)`
degrades to `stats::qnorm(level/2)`." For `level = 0.95`, `qt(0.475, Inf) = -0.063`
— the lower tail near zero, not the upper-tail critical value used in the
formula. The CI formula correctly uses `qt(1 - (1 - level)/2, df)`.
Verified: `qt(0.95/2, Inf)` = −0.063; `qt(0.975, Inf)` = 1.96.

An implementer copying the illustrative function call from the prose into a
test will get a wrong critical value.

Fix: Replace the sentence with: "When `df` is `Inf`,
`stats::qt(1 - (1 - level)/2, df = Inf)` equals
`stats::qnorm(1 - (1 - level)/2)`. No special-casing needed."

Options:
- **[A] Correct the tail probability in the prose** — Effort: trivial,
  Risk: none, Impact: eliminates misleading example, Maintenance: none
- **[B] Do nothing** — prose contradicts the formula block

**Recommendation: A** — trivial fix.

Source: R console verification.

---

#### Lens 4 — Domain Estimation

---

**Issue 14: `survey_diffs` `coef()` names omit the reference category**
Lens: 1, 4
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §III.5 naming table states for `survey_diffs`: row identifier is
"treatment level from the treatment column," example name `"Treatment_A"`.
`get_diffs()` computes pairwise contrasts: `E[Y | treatment=A] - E[Y |
treatment=ref]`. The name `"Treatment_A"` does not encode the reference
level. Two different `get_diffs()` calls with different reference levels
produce identical `coef()` names for different quantities.

The correct naming convention encodes the full contrast:
`"Treatment_A - Control"` (using ` - ` as the separator, distinct from
the `:` group separator). This matches `emmeans` convention and is
self-documenting.

Fix: Update the naming table row for `survey_diffs`:
- Row identifier: `"treatment_level - reference_level"`
- Example name (ungrouped): `"Treatment_A - Control"`
- Example name (grouped): `"region_A:Treatment_A - Control"`

Options:
- **[A] Use `"treatment - reference"` format** — Effort: low, Risk: low,
  Impact: unambiguous self-documenting names; no backward compat cost
  since this is a new method, Maintenance: low
- **[B] Keep bare treatment level name; note reference is in `meta()`** —
  Effort: none, Risk: low for single-result use, Risk: medium when results
  are combined, Maintenance: none
- **[C] Do nothing** — ambiguous coef() names for diffs results

**Recommendation: A** — `"Treatment_A - Control"` is self-documenting at
zero backward-compatibility cost.

Source: `emmeans` naming conventions; `survey::svycontrast` [verify].

---

**Issue 15: Zero-row result — `0×0` matrix dimnames construction
underspecified**
Lens: 4
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §VII states: "Zero-row result: `coef()` returns `named numeric(0)`;
`vcov()` returns a `0×0` named matrix; `confint()` returns a `0×2` named
matrix." The spec does not define what "named" means for a `0×0` matrix.

In R, `matrix(numeric(0), nrow=0, ncol=0)` with `dimnames=list(NULL, NULL)`
is distinct from `dimnames=list(character(0), character(0))`. Code that
calls `rownames(vcov(result))` returns `NULL` vs `character(0)`, which
behave differently in `c()` concatenation and `match()` lookups. The quality
gate (§VIII) does not test the zero-row case.

Fix: Add an implementation note to §VII:
- `0×0` matrix: `matrix(numeric(0), nrow=0, ncol=0, dimnames=list(character(0), character(0)))`
- `0×2` confint matrix: `matrix(numeric(0), nrow=0, ncol=2, dimnames=list(character(0), c("2.5 %", "97.5 %")))`

Add a quality gate entry: "`coef()` and `vcov()` on a zero-row result return
`named numeric(0)` and a `0×0` matrix with `character(0)` dimnames."

Options:
- **[A] Add explicit construction notes to §VII and a quality gate test** —
  Effort: low, Risk: low, Impact: prevents NULL-vs-character(0) bugs,
  Maintenance: none
- **[B] Do nothing** — implementation will likely produce a matrix that works
  in practice but may have NULL dimnames

**Recommendation: A** — Two sentences in §VII and one quality gate item;
zero cost.

Source: R language definition; `matrix()` documentation; `dimnames`
semantics for 0-dimension arrays.

---

**Issue 16: Group-major ordering not verified against `get_diffs()` internal
row order**
Lens: 4
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec §III.5 guarantees group-major ordering of `coef()`. But §VI states
that `get_diffs()` constructs its result tibble without going through
`.make_result_tibble()` and attaches the `.survey_result` attribute manually.
The spec does not require that `get_diffs()` produce its rows in group-major
order before the attribute is attached.

If `get_diffs()` internally produces treatment-major order, then `coef()` on
a grouped diffs result will violate the group-major guarantee and `vcov()`'s
block-diagonal assembly will be misaligned.

Options:
- **[A] Add a row-ordering requirement to §VI for `get_diffs()`** — State:
  "The result tibble rows must be in group-major order before the attribute
  is attached. If `get_diffs()` currently produces a different row order,
  reorder before attaching." — Effort: low, Risk: low, Impact: ordering
  guarantee is airtight, Maintenance: low
- **[B] Make `coef()` sort the tibble into group-major order at read time**
  — Effort: medium, Risk: low, Impact: robust against any future
  get_* that doesn't follow the convention, Maintenance: low
- **[C] Do nothing** — get_diffs() may silently violate the coef() ordering
  guarantee

**Recommendation: A** — One sentence in §VI is the minimal fix.

Source: Spec §III.5 ordering guarantee; spec §VI get_diffs() special case.

---

#### Lens 5 — Established Practice

---

**Issue 17: `coef()` ordering is group-major; `survey::svyby` uses
variable-major order**
Lens: 5
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec §III.5 "Order" section states: "Group-major. For groups A, B, C
and variables x, y: the order is A:x, A:y, B:x, B:y, C:x, C:y."

`survey::svyby()` produces variable-major order: all groups for the first
variable, then all groups for the second. Running
`svyby(~api00 + api99, ~stype, dclus1, svymean)` produces `names(coef(.))` =
`"E:api00", "H:api00", "M:api00", "E:api99", "H:api99", "M:api99"`.

For single-variable grouped results (all current classes, since every class
has `length(estimate_cols) == 1`), both orderings are identical. The
divergence is latent until a multi-estimate-column class is added. The spec
explicitly describes the multi-column case in §III.5 and §III.6 step 5 and
locks in the group-major contract. Any downstream code written to survey
convention will break.

Fix: Change §III.5 "Order" to variable-major — "for groups A, B, C and
variables x, y: A:x, B:x, C:x, A:y, B:y, C:y" — or explicitly document
the intentional deviation with rationale.

Options:
- **[A] Adopt variable-major order, matching `survey::svyby` exactly** —
  Effort: low (spec text only), Risk: low, Impact: future multi-column
  extensions are drop-in compatible with survey, Maintenance: none
- **[B] Keep group-major order with documented rationale** — Effort: low,
  Risk: medium (users migrating from survey may be surprised),
  Impact: group-major is arguably more natural for row-wise tibble data,
  Maintenance: must document in every vignette
- **[C] Do nothing** — ordering contract is locked in for the wrong order
  relative to survey convention

**Recommendation: A** — Variable-major matches `survey::svyby` at zero
implementation cost; single-column results (all current classes) are
unaffected either way.

Source: `survey::svyby()` + `coef.svyby()` observed output; survey
package 4.4.x.

---

**Issue 18: `SE.default()` does not forward `...` to `vcov()`**
Lens: 5
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec §III.4 specifies:

```r
SE.default <- function(object, ...) sqrt(diag(vcov(object)))
```

`survey::SE.default()` is `function(object, ...) sqrt(diag(vcov(object, ...)))` —
it forwards `...` to `vcov()`. When `surveycore::SE` masks `survey::SE`,
any user calling `SE(some_object, some_vcov_arg = TRUE)` on an object whose
`vcov()` method uses `...` will silently lose those arguments.

In practice `vcov.svystat()` ignores `...` so this is dormant for all current
survey objects. The fix is one character.

Fix: Change the spec to `SE.default <- function(object, ...) sqrt(diag(vcov(object, ...)))`.

Options:
- **[A] Add `...` forwarding** — Effort: trivial, Risk: none, Impact: full
  parity with `survey::SE.default()`, Maintenance: none
- **[B] Do nothing** — dormant for current vcov methods

**Recommendation: A** — Trivial fix; eliminates a latent masking defect.

Source: `survey::SE.default` source.

---

**Issue 19: `vcov.survey_result()` should emit a warning matching
`survey::vcov.svyby()`**
Lens: 5
Severity: ADVISORY
Resolution type: JUDGMENT CALL

`survey::vcov.svyby()` always emits:
`warning("Only diagonal elements of vcov() available")`. This is a signal
to downstream tools (e.g., `car::linearHypothesis`, `msm::deltamethod`)
that off-diagonal elements are structural zeros, not computed covariances.

The spec §III.6 specifies no warning. Users who pipe `vcov(get_means(...))`
into a delta-method function expecting a real covariance matrix receive
incorrect results with no diagnostic. This is particularly important given
that Issue 3 establishes cross-group zeros are wrong, and Issue 7
establishes within-group cross-variable zeros are an approximation.

Options:
- **[A] Emit `cli::cli_warn()` when vcov() is called on a grouped result
  or a multi-row ungrouped result** — Effort: low, Risk: low (warnings are
  suppressible), Impact: matches survey convention; downstream tools that
  branch on this warning will work correctly, Maintenance: add to test spec
- **[B] Do nothing** — diverges from `survey::vcov.svyby()` convention

**Recommendation: A** — The warning is the minimum correctness signal that
aligns with established survey package practice and protects users from
silent misuse.

Source: `survey::vcov.svyby()` source; observed warning "Only diagonal
elements of vcov() available."

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 8 |
| ADVISORY | 7 |

**Total issues:** 19

**Assessment:** The methods themselves (`coef()`, `SE()`, `confint()` formula)
are sound for independent estimators, but the spec's core architectural
decision — assembling `vcov()` from per-row `se^2` with block-diagonal zeros
— is statistically incorrect for three supported result classes (`survey_freqs`,
`survey_corr`, and grouped results with complex designs), and the df-storage
policy creates a numerical divergence between `confint()` output and the
pre-computed `ci_low`/`ci_high` columns in the same result tibble. The
blocking issues must be resolved before implementation begins; the required
issues should be resolved in the same pass to avoid architectural rework.
