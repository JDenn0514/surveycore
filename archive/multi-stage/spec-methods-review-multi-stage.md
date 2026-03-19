## Methodology Review: multi-stage — Pass 1 (2026-03-12)

### New Issues

#### Lens 1 — Estimator Specification

---

**Issue 1: `.taylor_build_inputs()` `keep` filter physically removes rows before cluster matrix
building — biases stage-2+ sampsize and contradicts the full-data domain-indicator strategy**
Severity: BLOCKING
Resolution type: UNAMBIGUOUS

The spec §VI specifies:

```r
keep <- if (na.rm) !is.na(y) else NULL
mats <- .build_cluster_matrices(design@data, design@variables, keep = keep)
y    <- y[if (is.null(keep)) seq_along(y) else keep]
w    <- data[[vars$weights]][if (is.null(keep)) seq_len(nrow(data)) else keep]
```

This physically removes rows with `NA` outcomes from the cluster matrix before building
`sampsize_j_vec`. But `sampsize_j_vec` counts the unique cluster IDs in the **filtered** data,
not in the original sample. For multi-stage designs this is wrong: if a PSU originally had
10 SSUs sampled but 2 have `NA` in the outcome, the filtered data has 8 SSU IDs per PSU and
`sampsize_j_vec` = 8 instead of 10. The stage-2 FPC factor `(popsize - sampsize) / popsize`
and the within-PSU variance scale factor both use this count, introducing downward bias in SE.

This directly contradicts:
- §VII (analysis helpers): "All cell estimators use the **full dataset** (no row filtering — domain
  estimation zeros out non-domain influence). Pass `keep = NULL`."
- §VIII: "Use `mats$clusters_mat`, `mats$strata_mat`, `mats$fpcs`." — no `keep`
- §XIII: "the domain estimation cell functions already work on the full dataset with domain
  indicators, and `.build_cluster_matrices()` is called with `keep = NULL`."

The variance is also not addressed for the combination `domain filter + na.rm = TRUE` — these
interact through the same `keep` pathway and the spec provides no specification for this case.

**Fix:** In §VI, change to:

```r
keep_y <- if (na.rm) !is.na(y) else seq_along(y)
mats   <- .build_cluster_matrices(design@data, design@variables, keep = NULL)
y      <- y[keep_y]
w      <- data[[vars$weights]][keep_y]
# Subset the pre-built matrices to matching rows for variance computation:
mats$clusters_mat <- mats$clusters_mat[keep_y, , drop = FALSE]
mats$strata_mat   <- mats$strata_mat[keep_y, , drop = FALSE]
mats$fpcs$sampsize <- mats$fpcs$sampsize[keep_y, , drop = FALSE]
if (!is.null(mats$fpcs$popsize))
  mats$fpcs$popsize <- mats$fpcs$popsize[keep_y, , drop = FALSE]
```

The cluster matrices are built from the **full** data (preserving correct sampsize counts), then
the row subset for `y`, `w`, and the matrix rows are applied consistently. This matches the
analysis-helper strategy (domain indicator on full data) and the existing single-stage behavior.

Options:
- **[A]** Build cluster matrices from full data; subset matrix rows AND y/w to `keep_y` afterward.
  — Effort: low, Risk: low, Impact: correct multi-stage SE for na.rm; consistent with §VII/XIII,
  Maintenance: none
- **[B]** Adopt physical row filtering everywhere (rewrite analysis helpers too). — Effort: high,
  Risk: high (changes all variance semantics; breaks existing behavior), Maintenance: very high
- **[C] Do nothing** — silent downward bias in SE for any 2-stage design with `na.rm = TRUE`;
  oracle tests for that case will fail

**Recommendation: [A]** — Full-data cluster matrix construction with post-hoc row subset is
the only approach consistent with all three other sections of the same spec.

Source: Spec §VI lines 387–391 vs. §VII lines 422–423 vs. §XIII lines 653–657.

---

**Issue 2: FPC sampling-fraction columns must be constant within each stage-j parent group —
undocumented constraint**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§V Step 7 converts sampling fractions to population sizes via:

```r
as.numeric(sampsize_j_vec / fpc_vals)
```

Here `fpc_vals` is a per-row column from `data`, and `sampsize_j_vec` is also per-row.
The formula produces a per-row population size: `N_ij = n_j / f_ij`. This is algebraically
correct **only if** `fpc_vals[i]` is the stage-j sampling fraction *for the parent group
containing row i*, i.e., `f = (# sampled clusters at stage j in parent) / (# population
clusters at stage j in parent)`. This requires `fpc_vals` to be **constant within each
stage-j parent group**. If a user supplies a record-level sampling fraction (fraction of
individual records, not clusters), the formula produces wrong population sizes.

The spec also does not state that `fpc_vals` must be the **cluster-level** fraction, not the
**record-level** fraction. These differ when PSU/SSU sizes are unequal.

**Fix:** Add to §IV (FPC validation) and §V Step 7:

> "FPC columns for stage j are interpreted as the **cluster-level** sampling fraction
> (number of sampled clusters ÷ total clusters in the parent), or as the population cluster
> count. When supplied as a fraction, all rows within the same stage-j parent group must
> have the same value. Add a validation check: for each stage-j FPC column, verify that
> `fpc_vals` is constant within each `parent_j` group; emit `surveycore_error_fpc_not_constant`
> if not."

Options:
- **[A]** Add validation that FPC is constant within each parent group; add documentation of
  cluster-level interpretation. — Effort: low, Risk: low, Impact: catches user errors early,
  Maintenance: one new error class (add to error-messages.md)
- **[B]** Document constraint only; no runtime check. — Effort: very low, Risk: medium (silent
  wrong SE if user provides non-constant FPC), Maintenance: low
- **[C] Do nothing** — wrong population sizes if user provides non-constant FPC; oracle tests
  will pass only because `make_survey_data()` generates constant FPC

**Recommendation: [A]** — Runtime validation is cheap and prevents silent errors that are very
hard to debug.

Source: Standard multi-stage FPC theory (Cochran 1977, §10.3); current FPC validation rules
in §IV.

---

**Issue 3: Sampsize Step 6 `[as.character(parent_j)]` broadcast step is unexplained**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§V Step 6 shows:

```r
units_per_parent <- tapply(cluster_j, parent_j,
                           function(ids) length(unique(ids)))
sampsize_j_vec   <- as.integer(units_per_parent[as.character(parent_j)])
```

The `tapply` produces a named integer vector keyed by parent ID. The lookup
`units_per_parent[as.character(parent_j)]` broadcasts the per-parent count back to per-row,
giving each row the sample size of the parent it belongs to. This is correct but the spec
provides no explanation of why the lookup is done with `as.character()`, or that this is a
**broadcast** operation (not a scalar). A reader unfamiliar with R named-vector indexing may
implement this as a scalar (e.g., taking `unique()` before the lookup, producing a shorter
vector), breaking the matrix dimensions.

**Fix:** After the code block, add:

> "`units_per_parent` is a named integer vector keyed by parent ID (one entry per unique parent).
> The indexing `units_per_parent[as.character(parent_j)]` broadcasts this back to a per-row
> vector of length `n`: every row is assigned the count of sampled sub-clusters in its parent.
> `as.character()` is required because `tapply` names are character regardless of the input type."

Options:
- **[A]** Add the prose explanation above; optionally include a 2-PSU worked example with counts
  3, 2, 4. — Effort: low, Risk: none, Impact: prevents implementation error, Maintenance: none
- **[C] Do nothing** — relies on implementer inferring the broadcast semantics from the code;
  risk of off-by-one or dimension mismatch

**Recommendation: [A]**

Source: Spec §V Step 6, lines 314–316.

---

**Issue 4: Linearization applicability to non-linear estimands not stated**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§VII lists `.taylor_mean_cell()`, `.taylor_freq_cell()`, `.taylor_totals_cell()`,
`.taylor_corr_cell()`, `.taylor_quantiles_cell()`, `.taylor_ratios_cell()` — all six are updated.
But the spec never states that multi-stage variance via Taylor linearization applies to all six
via their influence functions, and that `.build_cluster_matrices()` is estimand-agnostic. A
reader might wonder whether ratios or quantiles require a separate multi-stage treatment.

**Fix:** Add one sentence to §I or §VII: "The cluster matrices and FPC structures output by
`.build_cluster_matrices()` are estimand-agnostic. Multi-stage variance applies to all
non-linear estimands (ratios, quantiles, correlations) through their existing influence
functions without further modification."

Options:
- **[A]** Add the sentence. — Effort: minimal, Risk: none, Maintenance: none
- **[C] Do nothing** — minor exposition gap; no numerical consequence

**Recommendation: [A]**

---

**Issue 5: Per-stage stratification assumed absent but not explicitly scoped out**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§V Step 5 uses the parent cluster as the implicit stratum for stage 2+, which is correct only
when the design has a single stratification variable (stage 1). The spec does not say that
per-stage stratification (e.g., `strata = c(strata1, strata2)`) is out of scope. If someone
reads the spec and tries to extend it to per-stage strata, the strata matrix construction
would silently produce wrong results.

**Fix:** Add to §I "What this phase does NOT deliver": "Per-stage stratification —
`@variables$strata` remains a single column; stage 2+ units use the parent cluster as their
implicit stratum."

Options:
- **[A]** Add the exclusion. — Effort: minimal, Risk: none, Maintenance: none
- **[C] Do nothing** — already partially stated in §I ("Per-stage stratification —") but the
  explanation is cut off; §V Step 5 rationale note is present but easy to miss

**Recommendation: [A]** — Spec already has a placeholder for this; complete it.

---

#### Lens 2 — Variance Estimation

---

**Issue 6: "No FPC → stage-1 variance only" claim lacks formal statistical justification**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§V Step 7 states:

> "`.svy_multistage()` does not recurse when `popmat = NULL`. Only stage-1 variance is
> computed. This is mathematically justified: without knowing the stage-1 sampling fraction
> (`nPSU / N_PSU`), the stage-2 contribution (which is scaled by that fraction) is
> indeterminate and assumed negligible."

The claim is correct but "indeterminate and assumed negligible" is not a precise justification.
The correct statement: the multi-stage Taylor variance formula is
`V = V_1 + (1 − f_1) * V_2`, where `f_1 = n_PSU / N_PSU` is the stage-1 sampling fraction
and `V_2` is the within-PSU variance. Without FPC, `f_1` is unknown, so `(1 − f_1) * V_2`
cannot be computed. Setting `f_1 = 0` (conservative, treating as infinite population) would
include the full `V_2`, but would require knowing `V_2`, which itself requires `popmat`.
The recursion correctly does not fire. The approximation is unbiased when `f_1` is small
(< 5–10%), and biased downward (SE underestimated) when `f_1` is large.

**Fix:** Replace the sentence with: "This is mathematically correct: multi-stage variance is
`V = V_1 + (1 − f_1) * V_2 + ...`, where each stage-k contribution is scaled by the product
of stage-1 through stage-(k-1) sampling fractions. Without stage-1 FPC, `f_1` is unknown and
all within-PSU contributions are indeterminate. The recursion does not fire and only `V_1` is
returned. This approximation is accurate when `f_1 ≪ 1` (small stage-1 sampling fraction).
Designs sampling > 20% of PSUs should supply stage-1 FPC. See Lumley (2010) §2.1."

Options:
- **[A]** Replace the sentence with the corrected justification above. — Effort: low, Risk: none,
  Impact: spec correctly characterizes the approximation's conditions, Maintenance: none
- **[C] Do nothing** — the claim is true but the approximation condition is hidden; users with
  high stage-1 sampling fractions will get no warning

**Recommendation: [A]**

Source: Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley, §2.1.

---

**Issue 7: Partial FPC semantics (Inf fill) lack statistical justification and citation**
Severity: REQUIRED
Resolution type: JUDGMENT CALL

§V Step 7 (Partial FPC semantics) states:

> "The stage-j FPC factor `f = (fpc - nPSU) / fpc` evaluates to `1.0` (no correction) when
> `fpc = Inf`. The within-PSU variance IS computed and included in the total variance (scaled
> by the stage-1 sampling fraction). The interpretation: stage-2+ sampling from an infinite
> sub-population; all within-PSU variance is retained without correction."

This is correct. However:
1. The spec does not cite that this matches `survey` package behavior for
   `svydesign(id = ~psu + ssu, fpc = ~fpc1)` (stage-1 FPC only).
2. It does not note that this is a conservative approximation — it *includes* the full within-PSU
   variance with no correction, which inflates the SE.
3. The inform message (`surveycore_inform_fpc_partial_stages`, §IV) is the right level but the
   spec does not explain *why* inform rather than warn is appropriate (the consequences are that
   variance may be slightly inflated, not biased toward zero).

Options:
- **[A]** Add: "(a) Verify and state that this matches `survey::svydesign(fpc = ~fpc1)` behavior
  for 2-stage designs. (b) Note that partial FPC inflates SE conservatively. (c) Add a
  `cli_inform()` for the partial FPC case (already in §IV — confirm message wording is
  adequate)." — Effort: low, Risk: none, Maintenance: none
- **[B]** Upgrade `cli_inform` to `cli_warn` to alert users more prominently. — Effort: low,
  Risk: low, Impact: more visible alert to a consequential assumption, Maintenance: new warning
  class (update error-messages.md)
- **[C] Do nothing** — claim is correct; citation gap is minor

**Recommendation: [A]** — Verify the `survey` package oracle and add the brief justification.
The inform level is appropriate (conservative inflation, not bias toward zero); no need to
upgrade to warn.

Source: Lumley (2010) §2.2; `survey::svydesign()` source.

---

**Issue 8: FPC = Inf arithmetic guard not documented in the spec**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§V Step 7 states `popsize_mat[, j] = Inf` for stages without FPC coverage and says "the FPC
factor evaluates to `1.0` when `fpc = Inf`". However, the spec does not note that the existing
`.svy_onestrat()` kernel must guard against `(Inf - nPSU) / Inf` evaluating to `NaN` in R
(it evaluates to `Inf/Inf = NaN` if computed naively). The existing code handles this via
`ifelse(fpc == Inf, 1, (fpc - nPSU) / fpc)`. The spec should confirm this guard is present
and relied upon — implementers must not replace it with a direct arithmetic expression.

**Fix:** Add a note after the `rep(Inf, n)` line: "Note: The variance kernel `.svy_onestrat()`
already guards `fpc = Inf` with `ifelse(fpc == Inf, 1, (fpc - nPSU)/fpc)`. This guard must
be preserved; direct arithmetic on `Inf` produces `NaN`."

Options:
- **[A]** Add the note. — Effort: minimal, Risk: none, Maintenance: none
- **[C] Do nothing** — implementer must discover this by reading `.svy_onestrat()` source

**Recommendation: [A]**

Source: `R/variance-taylor.R` `.svy_onestrat()` implementation.

---

**Issue 9: Matrix column count consistency not validated in builder return contract**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

The spec describes building `clusters_mat` (n × k), `strata_mat` (n × k), `sampsize_mat`
(n × k), and optionally `popsize_mat` (n × k). There is no stated invariant that all four
matrices have identical dimensions, and no validation step in the algorithm. If any step
mis-computes k (e.g., a 1-stage design where `k = 1` but `strata_mat` is built as n × 2),
the mismatch will produce a cryptic error inside `.svy_multistage()` rather than a
user-friendly error at the builder.

**Fix:** Add to the end of §V (after Step 7), before the return value description:

```r
# Assertion (internal):
stopifnot(
  NCOL(clusters_mat) == k,
  NCOL(strata_mat)   == k,
  NCOL(fpcs$sampsize) == k,
  is.null(fpcs$popsize) || NCOL(fpcs$popsize) == k,
  NROW(clusters_mat) == n
)
```

Options:
- **[A]** Add the assertion block to the spec. — Effort: low, Risk: none, Impact: clear
  error message at the source, Maintenance: none
- **[C] Do nothing** — mismatches surface as cryptic errors in the recursion kernel

**Recommendation: [A]**

---

#### Lens 3 — Degrees of Freedom and Inference

---

**Issue 10: Design degrees of freedom for multi-stage designs not documented**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

The spec adds multi-stage cluster matrix construction and updates variance computation, but
never states what the design degrees of freedom are for multi-stage designs, nor that
`.degf_taylor()` requires no changes.

The correct formula — established for stratified multi-stage designs — is:
`df = Σ_h (n_h − 1)` where `n_h` is the number of **stage-1 PSUs** in stratum h. This is
identical to the single-stage formula; stage 2+ structure is irrelevant to df. The
`.degf_taylor()` implementation (which computes this from stage-1 PSU and stratum counts)
is already correct and needs no modification. But a future maintainer reading the spec has
no way to know this.

**Fix:** Add a new §XII (or sub-section of §IX) "Design Degrees of Freedom for Multi-Stage
Designs" with the following content:

> "Design df for a multi-stage design is `Σ_h (n_h − 1)`, where `n_h` is the number of
> sampled stage-1 PSUs in stratum h. This is identical to the single-stage formula; stage 2+
> structure does not affect df. `.degf_taylor()` requires no changes. (Reference: Rust &
> Rao 1996; Kish & Frankel 1974.) When `nest = TRUE`, PSU IDs are made globally unique by
> the `interaction()` call in `.build_cluster_matrices()` Step 4 before the df count."

Options:
- **[A]** Add the section. — Effort: low, Risk: none, Impact: spec is self-contained on df,
  Maintenance: none
- **[C] Do nothing** — df formula is implicit in existing `.degf_taylor()` code; future
  maintainers must reverse-engineer it

**Recommendation: [A]**

Source: Rust, K.F. & Rao, J.N.K. (1996). Variance estimation for complex surveys using
replication techniques. *Statistical Methods in Medical Research*, 5(3), 281–310. Kish, L. &
Frankel, M.R. (1974). Inference from complex samples. *JRSS-B* 36(1):1–37.

---

**Issue 11: Lonely PSU behavior at stage 2+ not specified**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§XI edge cases include: "2-stage, single SSU per PSU | Lonely PSU at stage 2; verify
`lonely.psu` option propagates." But the spec does not define what "propagates" means or
specify the behavior.

In a multi-stage design, a "lonely PSU at stage 2" means a PSU contains only one SSU.
The `.svy_multistage()` kernel calls `.svy_onestage()` recursively at each stage; `.svy_onestage()`
applies the `getOption("survey.lonely.psu")` strategy at each level. So `lonely.psu` already
propagates to stage 2+. The spec should document this and clarify:
- Stage-2 lonely PSUs (single SSU in a PSU) are handled by the same strategy as stage-1
  lonely PSUs (single PSU in a stratum).
- Design df is unaffected by lonely PSU handling (df = stage-1 count regardless).
- "remove" strategy: zero variance contribution from the lonely unit — statistically
  conservative (SE may be underestimated for that PSU).

**Fix:** Add to §XI (or to the new df section): "The `survey.lonely.psu` option applies
recursively at all stages. A lonely stage-2 unit (single SSU within a PSU) is handled by
the same option as a lonely stage-1 PSU. Design df is unaffected. The edge case test should
verify that `getOption('survey.lonely.psu')` is respected at stage 2, not just stage 1."

Options:
- **[A]** Add the specification above and strengthen the test description. — Effort: low,
  Risk: none, Maintenance: none
- **[C] Do nothing** — existing code is correct; test requirement is vague

**Recommendation: [A]**

Source: `R/variance-taylor.R` `.svy_onestage()` lines 50–70 (lonely PSU handling).

---

**Issue 12: t-distribution vs. normal approximation for CIs not stated for multi-stage**
Severity: ADVISORY
Resolution type: JUDGMENT CALL

The spec does not state whether multi-stage CI bounds use a t-distribution with design df
or a normal approximation. The current code uses `stats::qt(p, df = degf)` where
`.degf()` currently returns `Inf` for all `survey_taylor` designs (normal approximation).
This is not documented anywhere in the spec.

Options:
- **[A]** Add to the proposed df section: "Confidence intervals for Taylor series designs
  currently use normal approximation (t with df = Inf). Design-based df-adjusted CIs are
  planned for a future phase. No changes to CI computation are required in this phase."
  — Effort: minimal, Risk: none, Maintenance: none
- **[C] Do nothing** — CI methodology is silent in the spec; normal approx is fine for now
  but undocumented

**Recommendation: [A]** — Brief documentation prevents future confusion.

Source: `R/analysis-helpers.R` lines 702–710 (`.degf()` returns Inf for all Taylor designs).

---

#### Lens 4 — Domain Estimation

_(Issue 1 covers domain-estimation root cause; additional sub-issues here.)_

**Issue 1** (Lens 4 aspect) is fully captured under Issue 1 (Lens 1/2 above) — the `keep`
parameter in `.taylor_build_inputs()` is the root cause of all domain-estimation variance
conflicts. No separate Lens 4 issues are needed once Issue 1 is resolved.

Confirming the fix from Issue 1 also resolves:
- Domain + `na.rm = TRUE` interaction: cluster matrices built from full data, so domain
  indicators and na.rm row-filter are applied orthogonally to `y`/`w` only.
- Missing test case for domain + na.rm in multi-stage (§XI): add this combination as an
  explicit edge case test.

**Action (no new issue number):** Add to §XI edge case tests: "2-stage with domain AND
`na.rm = TRUE` | `filter()` applied before `get_means(..., na.rm = TRUE)` on a variable
with NAs; verify SE wider than SRS (domain estimation) and matches `survey` oracle."

---

#### Lens 5 — Established Practice and Literature

---

**Issue 13: Stage-2+ stratum assignment (parent cluster as pseudo-stratum) lacks citation**
Severity: REQUIRED
Resolution type: UNAMBIGUOUS

§V Step 5 states: "SSUs within a given PSU are treated as unstratified (they all belong to
the same 'stratum' = that PSU). This matches `survey` package behavior for
`svydesign(id = ~psu + ssu, strata = ~stratum)`."

The `survey` package does exactly this — stage-j strata are the stage-(j-1) clusters — but
the spec does not cite the statistical principle. This approach follows standard multi-stage
sampling theory: units at stage j are sampled from within their stage-(j-1) cluster; there
is no cross-cluster stratification at stage j+. Setting `strata_mat[, j] = clusters_mat[, j-1]`
embeds this assumption.

**Fix:** Add to §V Step 5: "This reflects standard multi-stage sampling theory (Cochran 1977,
§10.3; Kish 1965, §6.3): stage-j units are sampled within their parent cluster, with no
cross-cluster stratification. Each PSU acts as its own implicit stratum for stage-2+ sampling."

Options:
- **[A]** Add the citation. — Effort: minimal, Risk: none, Maintenance: none
- **[C] Do nothing** — claim is correct; citation gap is minor

**Recommendation: [A]**

Source: Cochran, W.G. (1977). *Sampling Techniques*, 3rd ed., §10.3. Kish, L. (1965).
*Survey Sampling*, §6.3.

---

**Issue 14: FPC detection heuristic edge case (exactly 1.0) not documented**
Severity: ADVISORY
Resolution type: UNAMBIGUOUS

§V Step 7 uses `any(fpc_vals > 1, na.rm = TRUE)` to distinguish population-size columns
(values > 1) from sampling-fraction columns (values ≤ 1). If all values in a column are
exactly `1.0` (a 100% census at that stage), they are classified as sampling fractions.
The conversion `sampsize_j_vec / 1.0 = sampsize_j_vec` gives `popsize = sampsize`, which
is correct (FPC = 0, no correction). But the classification path is unintuitive — a user
supplying a population size of 1 (impossible unless N=1) would also hit this branch.
The existing validation (`surveycore_error_fpc_smaller_than_n`, §IV row 4) catches
`popsize < sample_size`, but a `popsize = 1` passed as a fraction=1.0 bypasses this.

**Fix:** Add a note to §IV FPC validation: "FPC values of exactly `1.0` are treated as a
100% sampling fraction (complete enumeration at that stage; no FPC correction applied). A
population size of exactly 1 cannot be represented as an integer FPC column."

Options:
- **[A]** Add the documentation note. — Effort: minimal, Maintenance: none
- **[C] Do nothing** — edge case is extremely unlikely in practice; numerically harmless

**Recommendation: [A]** — One sentence closes the gap.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 7 |
| ADVISORY | 6 |

**Total issues:** 14

| # | Title | Lens | Severity | Type |
|---|---|---|---|---|
| 1 | `keep` in `.taylor_build_inputs()` biases multi-stage sampsize; contradicts §VII/XIII | 2,4 | BLOCKING | UNAMBIGUOUS |
| 2 | FPC fraction must be constant within stage-j parent — undocumented constraint | 1 | REQUIRED | UNAMBIGUOUS |
| 3 | Sampsize Step 6 `[as.character(parent_j)]` broadcast step unexplained | 1 | REQUIRED | UNAMBIGUOUS |
| 4 | Linearization applicability to non-linear estimands not stated | 1 | ADVISORY | UNAMBIGUOUS |
| 5 | Per-stage stratification assumed absent but not scoped out in §I | 1 | ADVISORY | UNAMBIGUOUS |
| 6 | "No FPC → stage-1 only" claim lacks formal statistical justification | 1,5 | REQUIRED | UNAMBIGUOUS |
| 7 | Partial FPC semantics (Inf fill) lack citation and survey oracle verification | 2,5 | REQUIRED | JUDGMENT CALL |
| 8 | FPC = Inf arithmetic guard not mentioned in spec | 2 | ADVISORY | UNAMBIGUOUS |
| 9 | Matrix column count consistency not validated in builder | 2 | ADVISORY | UNAMBIGUOUS |
| 10 | Design df for multi-stage not documented; `.degf_taylor()` changes not addressed | 3 | REQUIRED | UNAMBIGUOUS |
| 11 | Lonely PSU behavior at stage 2+ not specified | 3,5 | REQUIRED | UNAMBIGUOUS |
| 12 | t-distribution vs. normal approximation for CIs not stated | 3 | ADVISORY | JUDGMENT CALL |
| 13 | Stage-2+ stratum = parent cluster assignment lacks citation | 5 | REQUIRED | UNAMBIGUOUS |
| 14 | FPC detection heuristic edge case (exactly 1.0) not documented | 5 | ADVISORY | UNAMBIGUOUS |

**Assessment:** The core algorithm and mathematical approach are sound — the spec correctly
extends cluster matrices from 1 column to k columns, the `.svy_multistage()` kernel is
correctly described as already correct, and the FPC semantics (Inf for partial, NULL for no
FPC) match the `survey` package. One blocking issue exists: the `keep` parameter in
`.taylor_build_inputs()` physically filters rows before cluster matrix construction, biasing
stage-2 sampsize and contradicting the full-data domain-indicator strategy stated in three
other sections of the same spec. Seven required issues are primarily documentation and
justification gaps (df treatment, lonely PSU, FPC justifications, citations). Oracle tests
for the na.rm=TRUE multi-stage path would fail as written.
