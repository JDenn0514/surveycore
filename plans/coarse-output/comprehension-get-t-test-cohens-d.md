# Comprehension — Cohen's d for `get_t_test()` and `get_pairwise()`

**Date**: 04/22/2026
**Domain**: statistics/survey_methods
**Taxonomy**: academic/working_paper
**Filter**: Active comments

---

## Overall Feedback

Here are some overall reactions to the document.

**Outline**

This document specifies a design-based Cohen's d extension for surveycore's `get_t_test()` and `get_pairwise()` functions. It proposes three denominator options (`sd_source`), handles the `get_pairwise()` pre-computation problem, and defers CI/SE to future work. The spec is detailed and internally careful in several places, but has significant gaps in statistical justification and some internal tensions that need resolution before implementation.

The document addresses a genuine gap — survey-weighted t-tests in srvyr/surveycore lack effect sizes, and the naive sample-pooled SD is not design-consistent. The pre-computation architecture for `get_pairwise()` (G1) is well-motivated and the edge-case inventory is thorough. However, the core statistical claims — that the three `sd_source` estimands are design-consistent, that the chosen denominators correspond to well-defined population parameters, and that `'full'` is an appropriate default — are asserted rather than derived, which is a serious problem for a spec that will govern production statistical software.

**No proof or reference that any `sd_source` option produces a design-consistent estimator of a stated population quantity**

Section 2 (Formulas/Denominator) defines three SD estimators computationally but never states what population parameter each one estimates under a complex survey design. For `'full'`, the estimand is presumably the population SD of Y across all groups combined, but this is not written down. For `'restricted'`, it is the population SD within the A∪B subpopulation — but subpopulation variance estimation under complex designs requires careful treatment of the domain indicator (Lumley 2010, §4.3), and the spec does not verify that passing a domain mask to `get_variance()` achieves this. For `'pooled_all'`, the estimand is even less clear: the formula weights by unweighted counts $n_\ell - 1$, so the resulting quantity is not the population within-group variance unless the design is self-weighting within each group. The spec cites Stata's `estat sd` and Cohen (1988) but neither reference establishes design-consistency for these specific estimators under stratified or clustered designs. Every `sd_source` option needs a formal estimand (a population quantity) and at minimum a citation or brief argument that the proposed estimator is consistent for it.

**`'pooled_all'` weighting by unweighted $n_\ell - 1$ produces a biased estimator under unequal probability sampling**

The pooled formula in Section 2(c) weights each group's design-based variance by $n_\ell - 1$ (unweighted sample count). Under unequal probability sampling — the normal case for complex surveys — this does not recover the population within-group variance. Consider a design where group A is oversampled by a factor of 10 relative to group B: the formula gives A's variance roughly 10 times the weight it deserves relative to the population. The spec explicitly rejects weighting by $W_\ell$ (weighted totals) in G7, citing ANOVA convention and Stata semantics, but ANOVA convention assumes equal or proportional sampling. The Stata `estat sd` citation is not sufficient justification here because Stata's behavior in this case is itself contested. The spec needs either (a) a formal argument that the $n_\ell - 1$ weighting is appropriate for the stated estimand despite unequal weights, or (b) acknowledgment that `'pooled_all'` targets a sample-based rather than population-based quantity, with explicit documentation of what that means for interpretation.

**The `'full'` default is statistically inappropriate when group membership is informative for variance**

Section 2(a) and A3 justify `'full'` as the default because it yields comparable effect sizes across pairs in `get_pairwise()`. This is a convenience argument, not a statistical one. When the survey design is informative — i.e., when sampling probabilities correlate with Y — the full-sample design-based SD conflates within-group variance, between-group variance, and design-induced variance components in a way that depends on the specific group composition of the sample. Two different `get_pairwise()` calls on different subsets of the same dataset would produce different `'full'` denominators, making comparability across studies impossible. The ANOVA MSE analogy cited in Section 2(a) applies when groups are balanced and the design is non-informative; neither condition is guaranteed in survey data. The spec should either restrict the `'full'` default to non-informative designs or demote it to a convenience option with a clear warning that it does not correspond to a stable population parameter when designs are informative.

**Separability assumption between numerator and denominator is unexamined**

Cohen's d is presented in Section 2 as a ratio of two independently computed quantities: the numerator from `survey_glm()` and the denominator from `get_variance()`. Under complex survey designs, the weighted mean difference and the design-based variance share the same weight structure, so they are not statistically independent — the plug-in ratio $\hat\Delta / \widehat{\text{SD}}$ is a ratio of correlated estimators. This matters for two reasons. First, even as a point estimate, the plug-in ratio may be substantially biased in small samples (ratio estimator bias is $O(n^{-1})$). Second, the deferral of CI/SE in G6 is partly motivated by the claim that CI construction is 'unsettled,' but the real obstacle is this correlation structure — and not acknowledging it means future CI work may be designed incorrectly. The spec should at minimum note that the numerator and denominator are correlated under complex designs and that this correlation must be accounted for in any future SE/CI work.

**Per-stratum SD computation in G3 may not isolate within-stratum variance correctly under clustered designs**

Section 3 and G3 specify that when `group` is active, the SD denominator is computed per stratum by restricting to rows with active stratum membership. For Taylor-linearization designs, restricting to a stratum subset and calling `get_variance()` on that subset changes the variance estimator's denominator degrees of freedom and may drop entire PSUs, producing a different (and potentially inconsistent) variance estimate than would be obtained from a proper subpopulation analysis. The spec says to 'reuse the same masking logic' as the t-test, but the t-test uses `survey_glm()` which handles subpopulations via the domain indicator approach — not by physically subsetting the design object. If `get_variance()` is called on a physically subsetted design, the resulting variance estimate may not be design-consistent for the within-stratum population variance. This needs explicit verification against the `get_variance()` spec, and the distinction between domain-indicator subpopulation analysis and physical subsetting must be resolved.

**G12 small-group handling for `'pooled_all'` silently drops groups without warning**

G12 states that for `'pooled_all'`, groups with $n_\ell < 2$ are 'skipped naturally' because their $(n_\ell - 1) = 0$ weight excludes them from the pooled sum. This is correct arithmetically, but it means the pooled SD is computed over a different set of groups than the user specified — silently. If group C has $n_C = 1$ and is dropped, the `'pooled_all'` denominator reflects only groups A and B, which is arguably equivalent to `'restricted'` in that case. The spec should require a warning when any group is dropped from the pooled calculation, distinct from `surveycore_warning_insufficient_n_for_d` (which G12 reserves for the `'restricted'` case). Without this warning, users have no way to know their `'pooled_all'` result is based on fewer groups than they intended.

**The `.meta$effect_size$denominator` field has an unresolved structure for `get_pairwise()` with active `group`**

Open question 2 in Section 34 resolves the `.meta` shape as a nested structure with a `denominator` field that is 'the numeric SD used, or a per-stratum/per-pair structure when `group` is active.' This is vague in a way that will cause implementation problems. For `get_pairwise()` with `group` active and `sd_source = 'restricted'`, the denominator varies by both stratum and pair — potentially $S \times \binom{k}{2}$ distinct values. The spec needs to define the exact data structure (e.g., a named list keyed by stratum × pair, a tibble, a matrix) before implementation, because downstream consumers (e.g., `tidy()` methods, citation functions) need a stable contract. Leaving this as 'a per-stratum/per-pair structure' is insufficient for a spec that is supposed to govern implementation.

**Several sections remain as stubs and the document is incomplete as a reviewable spec**

Sections 1 (Comprehension header), 9 (Gotchas), and 24 (Assumptions) are empty. While this is flagged as a partial draft, the 'Gotchas' section in particular is architecturally important — it is where implementation-level surprises that don't fit the formal structure are supposed to live, and its absence means the document has not been stress-tested against the actual codebase. More concretely, the Reference mapping in Section 23 cites specific line numbers in `R/analysis-t-test.R` (e.g., lines 736–745, 440–460, 830–850) but these cannot be verified without the source file, and if those line numbers are stale the entire integration plan may be misaligned. Before this spec is handed to an implementer, the stub sections need content and the line-number references need to be confirmed against the current codebase.

**No stated estimand for any sd_source option; design-consistency unverified**

Each of the three `sd_source` branches defines a computational recipe but never writes down the population parameter it targets. For `'full'`, the presumed estimand is the population SD of Y across all groups, but this is not stated. For `'restricted'`, it is the population SD within the A∪B subpopulation — a quantity that requires domain-indicator treatment under complex designs (Lumley 2010 §4.3), not physical subsetting. For `'pooled_all'`, the estimand is genuinely ambiguous: weighting by unweighted $n_\ell - 1$ does not recover the population within-group variance under unequal probability sampling. The spec cites Cohen (1988) and Stata's `estat sd` but neither establishes design-consistency for these specific estimators under stratified or clustered designs. Without a formal estimand for each option, users cannot choose among them in a principled way, and the spec cannot be evaluated for statistical correctness. Each branch needs one sentence of the form 'this estimates [population quantity] under [design assumptions],' plus a citation or brief argument that the proposed estimator is consistent for it.

**`.meta$effect_size$denominator` structure left vague for pairwise with active group**

Open question 2 in Section 34 resolves the `.meta` shape but leaves the `denominator` field as 'the numeric SD used, or a per-stratum/per-pair structure when `group` is active.' For `get_pairwise()` with `group` active and `sd_source = 'restricted'`, the denominator varies across both strata and pairs — up to $S \times \binom{k}{2}$ distinct values. Downstream consumers such as `tidy()` methods or citation helpers need a stable contract to read this field. A spec that governs implementation cannot leave the data structure as 'a per-stratum/per-pair structure'; it needs to define the exact form — a named list, a keyed tibble, or a matrix — before any implementer can write correct code. This should be resolved before the spec advances to Stage 1, not deferred further.

**Silent group-dropping in 'pooled_all' needs a warning requirement**

G12 correctly notes that groups with $n_\ell < 2$ are excluded from the `'pooled_all'` sum because their $(n_\ell - 1) = 0$ weight zeros them out. But this exclusion is silent: the pooled SD is computed over fewer groups than the user specified, with no indication. In the extreme case where all but two groups have $n_\ell < 2$, the result is effectively `'restricted'` — a completely different estimand — with no warning. The spec reserves `surveycore_warning_insufficient_n_for_d` for the `'restricted'` case only. It should also require a warning when any group is dropped from the `'pooled_all'` calculation, stating which groups were excluded and how many remained. Without this, users have no way to detect that their chosen estimand was silently replaced.

**Stub sections (header, Gotchas, Assumptions) need content before spec is implementable**

Sections 1, 9, and 24 are empty. The Gotchas section is architecturally the most consequential gap: it is where implementation-level surprises that don't fit the formal structure are supposed to live, and its absence means the spec has not been stress-tested against the actual codebase. The Reference mapping in Section 23 cites specific line numbers in `R/analysis-t-test.R` (e.g., 736–745, 440–460, 830–850) that cannot be verified without the source file; if those references are stale the entire integration plan may be misaligned. Before this document is handed to an implementer, the stub sections need substantive content and the line-number references need to be confirmed against the current codebase state.

**Recommendation**: Major revision. The spec is architecturally sound and the edge-case inventory is genuinely careful, but the core statistical claims — design-consistency of the three `sd_source` options, appropriateness of the `'full'` default, and correctness of the `'pooled_all'` weighting — are unsubstantiated. A production statistical software spec that will be cited by users in published research cannot rest on computational recipes without stated estimands and at least informal consistency arguments.

**Key revision targets**:

1. For each `sd_source` option, state the population parameter being estimated and provide a citation or first-principles argument that the proposed estimator is design-consistent for that parameter under stratified and clustered designs.
2. Either justify the $n_\ell - 1$ weighting in `'pooled_all'` for unequal-probability samples (with a reference or derivation), or document explicitly that this option targets a sample-based rather than population-based quantity and what that implies for interpretation.
3. Resolve the `'full'` default: either restrict it to non-informative designs with a runtime check, or reframe it as a convenience option with a roxygen warning that it does not correspond to a stable population SD when sampling is informative for Y.
4. Define the exact data structure of `.meta$effect_size$denominator` for the `get_pairwise()` + active `group` case, so downstream consumers have a stable contract.
5. Add a warning when `'pooled_all'` silently drops groups with $n_\ell < 2$ from the pooled calculation, and fill the stub sections (Gotchas, Assumptions) before handing the spec to an implementer.

**Status**: [Pending]

---

## Detailed Comments (19)

### 1. 'pooled_all' NaN × 0 arithmetic breaks the 'natural exclusion' claim

**Status**: [Pending]

**Quote**:
> `"pooled_all"`: groups with $n_\ell < 2$ are skipped in the pooled
>   sum (their $(n_\ell - 1) = 0$ weight already excludes them naturally
>   from both numerator and denominator — no special-casing needed).

**Feedback**:
The arithmetic here is wrong in a way that will produce a silent bug. The pooled formula is $\sum_\ell (n_\ell-1)\hat{V}_\ell / \sum_\ell (n_\ell-1)$. A singleton group contributes $n_\ell - 1 = 0$ to both sums, which looks like a clean exclusion — but G5 (cited just above this bullet) states that `get_variance()` returns `NaN` for a singleton group. In IEEE 754, `NaN * 0 = NaN`, not 0. So the 'natural exclusion' only works if the implementation never calls `get_variance()` on the singleton, or explicitly checks for `NaN` before accumulating. The claim that 'no special-casing needed' is therefore incorrect: the code must either skip groups with $n_\ell < 2$ before calling `get_variance()`, or guard against `NaN` returns before multiplying by $(n_\ell - 1)$. Rewrite the parenthetical as: 'their $(n_\ell - 1) = 0$ weight would exclude them algebraically, but since `get_variance()` returns `NaN` for singletons, the implementation must skip these groups before accumulating — `NaN * 0 = NaN` in floating-point arithmetic, so the exclusion is not automatic.'

---

### 2. Wrong warning class cited for 'restricted' insufficient-n case

**Status**: [Pending]

**Quote**:
> if either group in the pair has $n < 2$, the
>   restricted SD is `NaN`; `cohens_d = NA_real_`; emit
>   `surveycore_warning_zero_variance` (or a new
>   `surveycore_warning_insufficient_n_for_d` — needs user decision).

**Feedback**:
`surveycore_warning_zero_variance` is defined elsewhere in the spec as signaling that the data has no spread — all in-domain values are identical. A singleton group ($n < 2$) is a completely different failure: the group could have substantial population variance, but there is not enough data to estimate it. Emitting a zero-variance warning for an insufficient-n condition will mislead users into diagnosing a data problem when the real issue is sample size. The 'needs user decision' hedge makes this worse: the spec should resolve the warning class before implementation, not defer it. The open questions section (item 1) already resolves this — `surveycore_warning_insufficient_n_for_d` is the correct class. Remove the parenthetical deferral and state the decision directly: emit `surveycore_warning_insufficient_n_for_d`; do not reuse `surveycore_warning_zero_variance`.

---

### 3. Physical subsetting vs. domain-indicator approach conflated in per-stratum SD computation

**Status**: [Pending]

**Quote**:
> for each stratum $s$, restrict to rows with active stratum membership
> before applying the `sd_source` rule above. This matches how the t-test
> itself is scoped — the effect size reflects the population within that
> stratum.

**Feedback**:
The claim that this 'matches how the t-test itself is scoped' is not correct, and the mismatch has real statistical consequences. `survey_glm()` handles subpopulations via a domain-indicator approach: the full design object is retained and rows outside the domain are zeroed out, preserving PSU structure and the correct degrees of freedom for the variance estimator. 'Restrict to rows with active stratum membership' describes physical subsetting — building a smaller design object containing only those rows. Under Taylor linearization with clustering, physical subsetting drops PSUs that fall entirely outside the stratum, which changes the sandwich estimator's denominator and can produce a variance estimate that is not design-consistent for the within-stratum population. The two approaches give the same point estimate of the mean but different variance estimates. G3 says to 'reuse the same masking logic' as the t-test, but does not specify whether that means passing a domain indicator to `get_variance()` or subsetting the design object first — and these are not equivalent. The spec must resolve this explicitly: state that `get_variance()` must be called with the domain-indicator approach (full design retained, stratum mask passed as a domain indicator), and add a cross-reference to the `get_variance()` spec confirming it accepts this calling convention.

---

### 4. 'full' vs. 'restricted' collapse condition misrepresented for standalone get_t_test()

**Status**: [Pending]

**Quote**:
> When $k = 2$ (i.e., standalone `get_t_test()`), `"full"` and
> `"restricted"` collapse to the same value provided the user's design
> contains no extra rows outside those two groups. `"pooled_all"` differs
> even at $k = 2$ because it strips between-group variance.

**Feedback**:
The parenthetical '(i.e., standalone `get_t_test()`)' implies that standalone calls routinely satisfy the collapse condition. They do not. Section 2(a) explicitly says `'full'` operates on 'the full design passed by the user (before pair-restriction in `get_pairwise()`),' including 'any out-of-group rows the original design contained.' Users typically pass a complete survey design object and specify two groups via arguments — the design almost always contains other rows. The collapse is a special case, not the default. Rewrite as: 'When $k = 2$ and the user's design contains only rows belonging to those two groups, `"full"` and `"restricted"` produce identical estimates. In general they differ whenever the design contains out-of-group rows, which is common even in standalone `get_t_test()` calls.'

---

### 5. 'full' default attributed to ANOVA MSE convention, but 'full' includes between-group variance

**Status**: [Pending]

**Quote**:
> This is the default because it yields directly comparable effect sizes
> across all pairs in `get_pairwise()`, matching the ANOVA convention of a
> shared MSE across post-hoc contrasts.

**Feedback**:
The ANOVA post-hoc convention (Tukey HSD, Scheffé, Bonferroni) uses the pooled within-group MSE — the residual mean square from the one-way model — as the shared denominator. The `'full'` estimator is described two sentences earlier as including 'both within-group and between-group variance,' which is the total variance of Y, not the ANOVA MSE. The spec itself labels `'pooled_all'` as the 'ANOVA root-MSE analog' in Section 2(c), directly contradicting the attribution here. The comparability argument is a legitimate practical reason to prefer `'full'` as the default, but it should not be dressed up as ANOVA convention. Rewrite as: 'This is the default because it yields directly comparable effect sizes across all pairs in `get_pairwise()` — the denominator is fixed across all contrasts. Note that this denominator includes between-group variance and does not match the ANOVA MSE convention; `"pooled_all"` is the closer ANOVA analog.'

---

### 6. Naive-integration failure for 'pooled_all' is not the same as collapse to 'restricted'

**Status**: [Pending]

**Quote**:
> The naive integration — compute SD inside `get_t_test()` on the design
> it receives — silently reduces `"full"` and `"pooled_all"` to
> `"restricted"` when called from `get_pairwise()`, because the design has
> already been restricted via the domain mask.

**Feedback**:
The `'full'` collapse is correct: a pair-restricted design makes the full-sample SD equal to the pair-restricted SD. But `'pooled_all'` does not collapse to `'restricted'` in general. Under naive integration, `'pooled_all'` on a pair-restricted design produces a two-group pool (groups A and B only). `'restricted'` is a single `get_variance()` call on the A∪B union domain — a different quantity from a two-group pool, which combines two separate within-group variance estimates. These coincide only when $k = 2$ and the design contains no extra rows. For $k > 2$, the naive-integration failure for `'pooled_all'` is: k-group pool becomes two-group pool, not `'restricted'`. Conflating the two obscures what the actual bug is and what the fix must address. Rewrite the second clause as: 'silently reduces `"full"` to `"restricted"` and reduces `"pooled_all"` from a $k$-group pool to a two-group pool — which equals `"restricted"` only when $k = 2$.'

---

### 7. Override mechanism precedence rule unspecified when both .sd_override and sd_source are supplied

**Status**: [Pending]

**Quote**:
> For standalone `get_t_test()`, no override is passed; `get_t_test()`
> computes the SD itself per `sd_source` on the design the user provided.

**Feedback**:
The spec establishes two code paths in `get_t_test()` but never states the precedence rule when both `.sd_override` and `sd_source` are non-NULL. A test harness or future maintainer constructing the internal call directly could supply both, and the behavior is undefined. The fix is one sentence: when `.sd_override` is non-NULL, `get_t_test()` uses it exclusively and ignores `sd_source`. Add that sentence here, and add a companion note in G9 confirming that the public API of `get_t_test()` does not expose `.sd_override` to users.

---

### 8. Internal override via dotted argument is not actually hidden from users

**Status**: [Pending]

**Quote**:
> Use an unexported
> argument convention — e.g., a `.sd_override` dotted arg — and document
> it as internal in the roxygen. Users never call it directly.

**Feedback**:
R has no enforcement mechanism for 'internal-only' formal arguments. Any user who calls `formals(get_t_test)` or uses tab-completion will see `.sd_override` and can call it directly, bypassing `sd_source` entirely. Roxygen tagging does not prevent this. The standard pattern for truly internal communication between two functions in the same package is either a separate unexported helper that both call, or passing state through a named list that is never part of the user-facing signature. The spec should pick one of these patterns. Rewrite as: 'Route the pre-computed SD through an unexported helper function called by both `get_pairwise()` and `get_t_test()`, keeping `.sd_override` out of the user-facing signature of `get_t_test()` entirely' — a dotted argument in a public function's formals is not hidden.

---

### 9. Claim that replicate and Taylor designs are 'identical' conflates variance of Y with variance of the mean

**Status**: [Pending]

**Quote**:
> Replicate-weight designs are treated identically to Taylor designs.
> Because Cohen's d is a **point estimate only** (no CI — see G6), there
> is no need to recompute d per replicate. The SD denominator comes from
> `get_variance()`, which already handles replicate designs natively via
> its replicate-weight variance path; Cohen's d inherits that result
> transparently as a scalar transform.

**Feedback**:
The argument conflates two distinct quantities. The Cohen's d denominator requires an estimate of the *population variance of Y* — the spread of individual values around the population mean. Under replicate designs, `get_variance()` may return the *sampling variance of the weighted mean estimator* — the uncertainty in $\bar{y}^w$ due to sampling. These are completely different: one is $\text{Var}(Y)$, the other is $\text{Var}(\bar{y}^w) \approx \text{Var}(Y)/n$. If `get_variance()` returns the latter, then `sqrt(get_variance())` is the standard error of the mean, not the SD of Y, and the Cohen's d denominator is off by a factor of roughly $\sqrt{n}$. The spec needs to state explicitly what `get_variance()` returns — population variance of Y, or sampling variance of the mean — and confirm that the replicate-weight path returns the same estimand as the Taylor path. This is not a scheduling issue; it is a correctness question that must be answered before the formula in Section 2 can be evaluated.

---

### 10. ANOVA convention for n_ell - 1 weighting does not transfer to unequal-probability sampling

**Status**: [Pending]

**Quote**:
> Weighting by $n_\ell - 1$ (not
> by $W_\ell$) matches classical ANOVA convention and mirrors Stata's
> `estat sd` semantics after a survey-design mean comparison.

**Feedback**:
In classical ANOVA, $n_\ell - 1$ weighting is justified because each group's sample variance is an unbiased estimator of a common $\sigma^2$ under simple random sampling, and the chi-squared decomposition makes the pooled estimator minimum-variance unbiased. Neither condition holds here: $\hat{V}_\ell$ is a design-based estimator incorporating survey weights, and under unequal probability sampling the $n_\ell - 1$ weights do not recover the population within-group variance. Consider a two-group case where group A has $n_A = 100$ observations with weight 1 and group B has $n_B = 100$ with weight 10: the formula assigns equal weight to each group's variance, but group B represents 10× as many population units. G7 acknowledges this changes the estimand but frames it as a deliberate ANOVA-convention choice without stating what estimand the $n_\ell - 1$ weighting actually targets in a survey context. The Stata citation cannot serve as a statistical justification — Stata's behavior in this specific scenario is not documented here. Add one sentence: 'This estimator targets the unweighted (sample-based) pooled within-group variance, not the population within-group variance; it is appropriate when the goal is descriptive comparability rather than population inference.'

---

### 11. CI deferral justified as 'unsettled' when the real obstacle is a specific covariance term

**Status**: [Pending]

**Quote**:
> The literature does not settle on a CI construction for design-based
> Cohen's d. Three candidates exist (delta method, replicate bootstrap,
> report point estimate only); none has a clear canonical form in the
> survey-methodology literature.

**Feedback**:
Calling CI construction 'unsettled' overstates the difficulty and will mislead future implementers. The delta method for a ratio estimator $\hat\Delta / \widehat{\text{SD}}$ is standard survey statistics (Lumley 2010 §2.4; Wolter 2007 §6.3), and replicate-weight bootstrap CIs for nonlinear statistics are well-established. The real obstacle is specific: the numerator comes from `survey_glm()` and the denominator from `get_variance()`, and their joint covariance is not currently tracked across those two functions. That is an implementation gap, not a methodological open question. Rewrite the first two sentences as: 'Constructing a CI for $d$ requires propagating uncertainty through the ratio $\hat\Delta / \widehat{\text{SD}}$; under complex designs the numerator and denominator share the same weight structure and are correlated, so the delta-method cross-covariance term is non-trivial. No survey-methodology reference provides a canonical closed-form expression for this covariance in the stratified-clustered case, and the joint distribution across `survey_glm()` and `get_variance()` is not currently tracked; this is deferred to a future spec.' Also, 'report point estimate only' is not a CI method — it is the absence of one. Remove it from the list of candidates and restructure as: two CI methods exist but are deferred for the stated reason; therefore the output is point estimate only.

---

### 12. Sign convention underspecified — factor-level ordering rule not stated

**Status**: [Pending]

**Quote**:
> `get_t_test()` already defines `estimate = mean_B - mean_A` with
> `B` being the second factor level after coercion (see step 9e,
> `R/analysis-t-test.R:328–343`). Cohen's d inherits the same sign: a
> positive d means B's mean exceeds A's. Spec should state this
> explicitly so downstream consumers don't re-sign.

**Feedback**:
The sign of d equals the sign of the numerator (the denominator is always positive), so the algebra is fine. The problem is 'B being the second factor level after coercion' — the spec does not say what coercion rule is applied. Factor-level ordering in R depends on the `levels()` attribute, which can be alphabetical (default for `factor()`), appearance order, or user-specified. If a user passes a character vector or a factor with non-default levels, 'second factor level after coercion' may not match their intuitive A/B labeling, and a sign flip in d is a substantive error for downstream consumers. The same issue applies to the numerator formula in Section 2, where the sign convention is stated without specifying the reference-level rule. Both places should say: 'A is the first and B is the second level as ordered by [specific rule, e.g., `factor(..., levels = sort(unique(...)))`]; users passing character vectors should be aware that level order defaults to alphabetical.'

---

### 13. na.rm = TRUE hardcoded when user-facing na.rm argument may exist

**Status**: [Pending]

**Quote**:
> Since `get_variance()` has its own
> `na.rm` semantics (per `plans/spec-get-variance.md`), the call site
> should pass `na.rm = TRUE` unconditionally, matching the t-test's fixed
> behaviour.

**Feedback**:
If `get_t_test()` and `get_pairwise()` expose an `na.rm` argument to users, hardcoding `na.rm = TRUE` in the `get_variance()` call creates a silent inconsistency: a user who passes `na.rm = FALSE` expecting NA propagation gets NA-propagating mean differences but NA-excluding SDs, mixing two different effective sample sizes in the same Cohen's d. The justification — 'matching the t-test's fixed behaviour' — is circular: the t-test's 'fixed behaviour' is described as 'NA rows in x or by are always excluded,' which is a pre-filtering step, not a user-controlled parameter. The spec needs to either confirm that `na.rm` is not user-facing in these functions (in which case hardcoding is fine), or thread the user-supplied value through to `get_variance()`. Rewrite as: 'the call site should pass the same `na.rm` value received by `get_t_test()` / `get_pairwise()`' and add a note clarifying whether those functions expose `na.rm` to users.

---

### 14. Scope exclusion of paired tests incorrectly attributed to surveycore_error_by_not_two_levels

**Status**: [Pending]

**Quote**:
> Paired Cohen's d and one-sample Cohen's d are **out of scope** because
> `get_t_test()` errors on anything other than 2 active levels
> (`surveycore_error_by_not_two_levels`). Adding those effect-size
> branches presupposes adding the corresponding t-test branches, which is
> not part of this plan.

**Feedback**:
The argument is circular and partly wrong. A paired t-test on two groups has exactly two active levels — the error guard `surveycore_error_by_not_two_levels` would not fire. The real reason paired Cohen's d is out of scope is that `get_t_test()` does not implement paired tests at all, which is a different limitation from the one cited. An implementer reading this section would incorrectly conclude that the existing guard already prevents paired inputs, when in fact a paired two-group call might pass the level check and reach the Cohen's d code path with undefined behavior. The one-sample case is correctly excluded by the guard (fewer than two levels). Rewrite: 'Paired and one-sample Cohen's d are out of scope because the corresponding test branches do not yet exist in `get_t_test()`. Note that `surveycore_error_by_not_two_levels` guards against the one-sample case (fewer than two levels) but would not prevent a paired two-group call from reaching the Cohen's d code path; paired inputs must be explicitly excluded until the paired test branch is implemented.'

---

### 15. get_variance() interface contract not specified despite being the dependency for all sd_source branches

**Status**: [Pending]

**Quote**:
> The Cohen's d spec should treat
> it as an abstract dependency: describe the mathematical call, but do
> not block on its landing. The implementation plan will be finalized
> after `get_variance()` merges.

**Feedback**:
Treating `get_variance()` as an abstract dependency is reasonable for scheduling, but the section provides no interface contract — no required signature, return type, or design-consistency guarantee. Every branch of Section 2 depends entirely on what `get_variance()` computes, and without a stub contract the spec cannot be evaluated for correctness. This is not a scheduling issue: if `get_variance()` returns the sampling variance of the mean rather than the population variance of Y (see comment on G11), the Cohen's d formula is wrong regardless of when `get_variance()` lands. At minimum, state: the required call signature, what population quantity the return value estimates, and that the domain-indicator calling convention (not physical subsetting) must be supported. Add a concrete interface stub after 'describe the mathematical call.'

---

### 16. NaN case for zero-variance requires Δ = 0, not just 'depending on sign of Δ'

**Status**: [Pending]

**Quote**:
> Cohen's d is $\Delta / 0$ — `Inf`, `-Inf`, or
> `NaN` depending on sign of $\Delta$. Spec decision: return
> `NA_real_` for `cohens_d` and emit
> `surveycore_warning_zero_variance` (new warning class). Do not let `Inf`
> propagate.

**Feedback**:
In IEEE 754, `NaN` arises from `0/0`, not from the sign of $\Delta$ in general. The phrase 'depending on sign of $\Delta$' implies all three outcomes are driven by sign, but `NaN` is driven by $\Delta = 0$ exactly — a distinct condition. An implementer could write a guard that catches only `Inf` and `-Inf`, missing the `NaN` path entirely. Rewrite the parenthetical as '`Inf` if $\Delta > 0$, `-Inf` if $\Delta < 0$, or `NaN` if $\Delta = 0$ exactly' and update the rationale to 'Do not let `Inf` or `NaN` propagate.'

---

### 17. n_ell formula ambiguous about whether NA removal is encoded in the domain indicator

**Status**: [Pending]

**Quote**:
> $n_\ell = \sum_i a_i \cdot \mathbb{1}(g_i = L_\ell)$ is the unweighted
> in-domain non-NA count for group $\ell$.

**Feedback**:
The prose gloss says 'in-domain non-NA count,' which requires both $a_i = 1$ and $y_i$ not missing. But Section 2(a) describes the full design as used 'after applying the surveycore domain mask and NA removal on y,' treating these as separate operations — suggesting $a_i$ encodes domain membership but not necessarily NA removal. If $a_i$ does not encode NA removal, the formula overcounts by including observations with missing $y_i$, producing incorrect weights in the pooled variance denominator. Add after the formula: 'Here $a_i$ is the combined domain-and-non-NA indicator, so $a_i = 1$ only when observation $i$ is in the active domain and $y_i$ is not missing.'

---

### 18. 'restricted' call count understated — one call per pair likely means two

**Status**: [Pending]

**Quote**:
> - `"restricted"`: one `get_variance()` call per (stratum × pair),
>   computed fresh for each pair.

**Feedback**:
Whether `'restricted'` requires one or two `get_variance()` calls per (stratum × pair) depends on the estimand. If the denominator is a single call on the A∪B union domain (treating both groups as one), that is the overall SD of the restricted design — not a pooled within-group SD. If it is a pooled combination of $\hat{V}_A$ and $\hat{V}_B$ separately, two calls are needed. The spec elsewhere defines `'restricted'` as including 'within-group and between-group variance of just A and B,' which is consistent with a single union-domain call — but that is a different quantity from the pooled formula used in `'pooled_all'`. The bullet should state explicitly whether one call (union domain) or two calls (per-group, then pooled) is intended, and reconcile that choice with the formula in Section 2(b).

---

### 19. Stub sections need content before the spec is implementable

**Status**: [Pending]

**Quote**:
> The Cohen's d spec should treat
> it as an abstract dependency: describe the mathematical call, but do
> not block on its landing.

**Feedback**:
Sections 1 (Comprehension header), 9 (Gotchas), and 24 (Assumptions) are empty. The Gotchas section is the most consequential gap: it is where implementation-level surprises that don't fit the formal structure are supposed to live, and its absence means the spec has not been stress-tested against the actual codebase. The Reference mapping in Section 23 cites specific line numbers in `R/analysis-t-test.R` (e.g., 736–745, 440–460, 830–850) that cannot be verified without the source file; if those references are stale the entire integration plan may be misaligned. Before this document is handed to an implementer, the stub sections need substantive content and the line-number references need to be confirmed against the current codebase state.

---
