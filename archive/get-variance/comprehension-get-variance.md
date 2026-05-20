# Comprehension — get-variance

## Problem

Add `get_variance()` to the surveycore `get_*()` analysis family. Given a
survey design and one or more numeric variables selected via tidy-select, it
must compute the design-based estimate of the finite-population variance of
each variable, together with a design-based SE (and the usual opt-in
uncertainty columns: `var`, `cv`, `ci_low`, `ci_high`, `moe`, `deff`). The
estimand is `V(Y) = E[(Y - μ_Y)^2]`, estimated with Kish's `n/(n-1)`
small-sample correction so that surveycore agrees numerically with
`survey::svyvar()` across Taylor, replicate, twophase, and nonprob designs.
The function must handle grouping, the surveycore-standard domain mask, an
`na.rm` default of `TRUE`, and `survey_collection` dispatch via `.id` /
`.on_missing` — in every respect a drop-in sibling of `get_means()` whose
point-estimate column is `variance` (renamed to `estimate` when
`name_style = "broom"`).

Semantically: `get_variance()` is `get_means()` run on the centred-squared
deviations of `y`, with weights fixed (not re-normalized by the centring
step) and with an additional `n/(n-1)` scale factor. That reduction is the
backbone of `survey::svyvar.survey.design`, and it's what makes this
"variance of variance" problem tractable — for both Taylor and replicate
paths it is literally a mean of `(y - ȳ)^2 * n/(n-1)` under the design.

## Formulas

Let the population be indexed by $i = 1, \ldots, N$ and the realized sample
by $i \in s$. Let $w_i$ be the survey weight (full sample), $d_i \in \{0, 1\}$
the domain/group active indicator (from `.apply_domain()` combined with any
`group_by()` mask), and $m_i = \mathbb{1}(y_i \text{ non-NA})$ the NA mask.
Write $a_i = d_i m_i$ for the "effective" membership indicator under
`na.rm = TRUE`; under `na.rm = FALSE` set $a_i = d_i$ and let NA propagate
through the arithmetic.

Bindings to surveycore objects:

| Symbol | Binding |
|---|---|
| $y_i$ | `design@data[[y_col]][i]` |
| $w_i$ | `design@data[[design@variables$weights]][i]` (Taylor / replicate / nonprob) or calibrated weight `design@data[[phase1$weights]] / .compute_phase2_probs()` on Phase 2 rows (twophase) |
| $d_i$ | `.apply_domain(design)` combined elementwise with group combo mask |
| $a_i$ | `.mean_domain_vec(active_mask, y_col, na.rm)` — exactly the helper `get_means()` already calls |
| $n$ | `sum(a_i)` (unweighted, in-domain, non-NA) |
| $W$ | `sum(w_i * a_i)` |
| $\bar y$ | `sum(w_i * a_i * y_i) / W` |
| replicate weights | `design@data[, design@variables$repweights]` as matrix |
| cluster / strata / FPC | `.build_cluster_matrices(design@data, design@variables)` |
| two-phase `pi_{2|1,i}` | `.compute_phase2_probs(design, subset)` |

### 1. Population-variance estimator with Kish correction

Weighted Horvitz-Thompson plug-in estimator of $V(Y)$ with the finite-sample
correction that `survey::svyvar` uses:

$$
\hat V(Y) \;=\; \frac{n}{n-1} \cdot \frac{\sum_{i \in s} w_i\, a_i\, (y_i - \bar y)^2}{\sum_{i \in s} w_i\, a_i}
\;=\; \frac{n}{n-1} \cdot \frac{1}{W} \sum_{i \in s} w_i\, a_i\, (y_i - \bar y)^2.
$$

Equivalently (and this is the trick `svyvar.survey.design` uses):

$$
\hat V(Y) \;=\; \widehat{\mathrm{mean}}\!\big( z_i \big) \quad\text{where}\quad z_i \;=\; a_i \cdot (y_i - \bar y)^2 \cdot \frac{n}{n-1}.
$$

So the point estimate is a weighted mean of a derived variable `z`. This
reduction is what makes reuse of `get_means()` style scaffolding possible.

### 2. Taylor-linearization variance of $\hat V(Y)$

Treat $\hat V(Y)$ as the HT-linearised weighted mean of $z_i$. The
influence function (per-unit contribution to $\hat V$), evaluated at the
sample, is:

$$
u_i \;=\; \frac{w_i\, a_i \cdot \big( \tfrac{n}{n-1}(y_i - \bar y)^2 \;-\; \hat V(Y) \big)}{W}.
$$

Then $\mathrm{Var}(\hat V(Y))$ is estimated by plugging $u_i$ into the same
recursive stratified-clustered variance engine `get_means()` uses — i.e.,
`.svy_recvar(matrix(u_i, ncol=1), clusters, strata, fpcs, lonely.psu)`.
This is the exact construction already used inside `.vcov_pair_taylor()`
for the $c$ (i.e. $\mathrm{Var}(Y)$) diagonal, **except** that
`.vcov_pair_taylor()` uses the uncorrected (ML) form $w_i a_i (y_i - \bar y)^2 / W$
inside the influence, without the `n/(n-1)` factor. For `get_variance()`
parity with `svyvar`, the `n/(n-1)` factor must appear in the estimand
(multiply the per-row "score" $(y_i - \bar y)^2$ by $n/(n-1)$ before
centring by $\hat V$). See Gotcha 1.

Out-of-domain rows contribute $u_i = 0$, preserving correct
cluster/strata FPC assembly — the standard domain-estimation construction.

### 3. Replicate-weight variance of $\hat V(Y)$

For replicate weights $w_i^{(r)}$, $r = 1, \ldots, R$, recompute the
estimate per replicate:

$$
W^{(r)} = \sum_{i} w_i^{(r)} a_i, \qquad \bar y^{(r)} = \frac{\sum_i w_i^{(r)} a_i y_i}{W^{(r)}},
$$

$$
\hat V^{(r)}(Y) \;=\; \frac{n}{n-1} \cdot \frac{\sum_i w_i^{(r)} a_i (y_i - \bar y^{(r)})^2}{W^{(r)}}.
$$

Note $n$ (the unweighted in-domain non-NA count) is **held fixed across
replicates** — replicates perturb the weights, not the sample size. This
matches `svyvar.svyrep.design`, where `n <- NROW(x)` is fixed after
`na.rm` and the per-replicate formula multiplies by `n/(n-1)`.

Then

$$
\widehat{\mathrm{Var}}(\hat V(Y)) \;=\; \mathrm{scale} \cdot \sum_{r=1}^{R} \mathrm{rscales}_r \cdot \big(\hat V^{(r)}(Y) - \hat V^{*}(Y)\big)^2,
$$

with $\hat V^{*} = \hat V(Y)$ when `mse = TRUE` (surveycore default) and
the mean of replicate estimates otherwise — exactly `.svy_rep_var()`.

### 4. Twophase-design variance of $\hat V(Y)$

`survey` does **not** define `svyvar.twophase`. `svyvar(x, twophase_design)`
dispatches to `svyvar.survey.design`, which calls
`svymean(x*x*n/(n-1), design)`, which in turn dispatches to
`svymean.twophase` to do the actual variance work via the twophase
machinery. The structural consequence for surveycore: the point estimate of
$\hat V(Y)$ under twophase is the twophase-weighted mean of
$(y_i - \bar y)^2 \cdot n/(n-1)$, and its SE is obtained by applying
`.twophasevar()` to the twophase influence function for that derived mean.

With calibrated weights $\tilde w_i = w^{(1)}_i / \pi_{2|1,i}$ restricted to
Phase 2 rows, the two-phase influence function for $\hat V(Y)$ is (after
constructing the full-length vector with 0 on Phase 1-only rows):

$$
u_i \;=\; \tilde w_i \cdot a_i \cdot \frac{\tfrac{n}{n-1}(y_i - \bar y)^2 - \hat V(Y)}{W},
\qquad W = \sum_i \tilde w_i a_i, \quad n = \sum_i a_i,
$$

then $\widehat{\mathrm{Var}}(\hat V(Y)) = \texttt{.twophasevar}(u, \text{design}, \text{lonely.psu})$,
which dispatches to `"simple"` / `"approx"` / `"full"` per
`@variables$method`. Twophase Phase 2 rows only contribute (both to $n$ and
to $W$); Phase 1-only rows have $u_i = 0$.

### 5. Nonprob / survey_srs estimator

For `survey_nonprob` (and `survey_srs` when it inherits from the nonprob
path — it uses `.calibrated_mean_cell()`): point estimate is the same as
(1). Its SE uses the HT linearisation for a single-stage SRS-with-weights
design, matching `svydesign(ids = ~1, weights = ~w)`:

$$
\widehat{\mathrm{Var}}(\hat V(Y)) \;=\; \frac{n}{n-1} \cdot \sum_{i \in s} \Big( \frac{w_i\, a_i \cdot (\tfrac{n}{n-1}(y_i - \bar y)^2 - \hat V(Y))}{W} \Big)^2.
$$

This mirrors `.calibrated_mean_cell()`'s construction with the outer
$n/(n-1)$ factor pulled from the variance-of-mean formula.

### 6. How domain / grouping specialise the above

- `d_i` (and hence $a_i$) multiplicatively masks every term: the weighted
  mean, the squared deviation, and the influence function.
- $W$ and $n$ are **recomputed for the domain only** — the domain mean $\bar y$
  is the in-domain weighted mean, and $\hat V(Y)$ is the in-domain variance
  with its own $n_d / (n_d - 1)$ correction.
- Cluster / strata / FPC structure is built from the **full dataset**
  before domain filtering (design property, not a sample property). This
  matches `.taylor_mean_cell()` and `.vcov_pair_taylor()`.
- The domain mean $\bar y$ and thus the centering used in the
  score $(y_i - \bar y)^2$ is plugged-in (not a separately estimated quantity
  whose variance feeds back into the variance of $\hat V$). This is the
  same approximation `svyvar.survey.design` uses — Taylor linearisation
  treats $\bar y$ as a known constant in the score function, reusing the
  influence-function-of-a-weighted-mean construction.
- Replicate path: $\bar y^{(r)}$ is re-estimated per replicate, so the
  variability of $\bar y$ is implicitly captured by the replicate spread.
- Twophase path: same plug-in approximation; the two-phase engine already
  propagates Phase 1 and Phase 2 contributions via the influence vector.

## Gotchas

### G1. `n/(n-1)` vs ML form — the headline numerical divergence from `.vcov_pair_taylor()`

`.vcov_pair_taylor()` uses
`a = sum(w * cx^2) / W_d` (no `n/(n-1)` factor) and its influence function
is `w * pair_mask * (cx^2 - a) / W_d`. This is the ML / plug-in form. The
surveycore correlation path uses ML on both numerator and denominator, so
the ratio matches `survey::svyvar(...)` only in the limit. That's
**fine for `get_corr()`** (where the correction cancels in the ratio),
but it is **wrong for `get_variance()`**.

`get_variance()` must apply `n/(n-1)` to the estimand AND to the influence
score. Specifically, use

```
score_i = a_i * ( (n / (n - 1)) * (y_i - ybar)^2 )
V_hat   = sum(w * score) / W
infl_i  = w * a_i * (score_i - V_hat) / W
```

Do **not** "fix" `.vcov_pair_taylor()` to adopt this form — `get_corr()`
still needs the ML form. Instead, introduce a parallel helper
`.vcov_var_taylor()` (or reuse the `z_i` = mean-as-a-function reduction and
call `.taylor_mean_cell()` on `z`). The spec should make this split
explicit, because a single helper cannot serve both consumers without
breaking one of them.

### G2. Single-PSU-per-stratum (`lonely.psu` option) for the variance-of-variance

`getOption("survey.lonely.psu", "remove")` governs the engine; it's
inherited unchanged by `.svy_recvar()` inside any `get_variance()`
implementation. The gotcha: **`svyvar()` can trigger `lonely.psu`
warnings even when `svymean()` on the same design does not**, because the
derived quantity $(y_i - \bar y)^2$ is far more leveraged than $y_i$ by a
single lonely PSU. Spec decision: surface the lonely-PSU behaviour through
the option as the family already does; do not trap or emit extra warnings
beyond what `.svy_recvar()` already emits via cli.

### G3. Replicate-weight DoF

`get_means()` uses `degf = Inf` (normal approximation). `survey::svyvar`
does likewise — CIs and `deff` on variance estimates are constructed with
normal quantiles, not Satterthwaite-adjusted t's. Follow `get_means()`
precedent and use `Inf`. (This is distinct from `get_quantiles()` which
does use the design df.)

### G4. Twophase — Phase 1 vs Phase 2 contributions

Two rules to get right:

- $n$ (in `n/(n-1)`) counts **Phase 2 in-domain non-NA rows only**. Phase
  1-only rows are *never* part of $n$ or $W$ — they contribute zero
  influence by construction of the full-length $u_i$ vector.
- The phase-1 centring in `.twophase_phase1_var()` is applied to the
  *influence* $u_i$, not to the raw $y$. So the two-phase machinery is
  agnostic to the fact that $u_i$ was built from a squared deviation — it
  just sees a full-length influence vector. Implementation can reuse
  `.twophasevar(u, design, lonely.psu)` directly, following the same
  pattern as `.twophase_mean_cell()`.

### G5. Domain masking at zero weight / all-NA / single-observation domain

- `n_d = 0`: return `mean = NaN`, `se = NaN`, `n = 0L`, `n_weighted = 0`,
  fire `surveycore_warning_empty_domain` or `surveycore_warning_all_na`
  depending on cause. The request asks for an **`NaN` return, not `NA`**,
  for "all-NA variable" (see Edge cases in request.md).
- `n_d = 1`: $n/(n-1) = \infty$ and the numerator is exactly 0, giving
  $0 \cdot \infty = \text{NaN}$. Return `NaN` for both point and SE, `n = 1L`,
  and fire a warning (`surveycore_warning_insufficient_n`, new class —
  see G6). This matches the request's "single non-NA observation → `NaN`"
  edge.
- `n_d = 2`: $n/(n-1) = 2$. This is the minimum case where the estimator
  is defined. Does not warn.

### G6. New warning classes — what needs to enter `plans/error-messages.md`

Existing family classes largely apply (`surveycore_warning_small_cell`,
`surveycore_warning_single_level`, `surveycore_error_non_numeric_variable`,
`surveycore_error_wrong_variable_count` if single-var mode, the shared-arg
validations, etc.). New rows likely needed:

- `surveycore_warning_variance_all_na` — `"All values of {.field {var}} are {.code NA}. Returning {.code NaN}."` (analogous to `surveycore_warning_all_na_freqs`)
- `surveycore_warning_variance_insufficient_n` — `"{.field {var}} has {n} non-NA observation{?s} in the active domain; variance requires at least 2. Returning {.code NaN}."`
- `surveycore_warning_zero_variance` — optional; currently the request says "no warning" for constant variable. Confirm with user. If we keep no-warning behaviour, this row is **not** needed.

The request should be validated with the user on whether the two warnings
above should be separate classes or rolled into existing ones. The
comprehension flags this but does not decide.

### G7. `na.rm = TRUE` interacts with multi-variable mode differently than `svyvar()`

`svyvar.survey.design` uses **listwise** deletion when $x$ is
multi-column: any row with an NA in *any* of the $x$ columns is excluded
from $n$. This is correct for a multivariate variance-covariance matrix,
but surveycore's `get_variance()` returns a **per-variable** diagonal
estimate (one row per variable, no off-diagonals). Listwise deletion would
be wrong here — each row's per-variable $n$ should reflect the non-NA rows
for **that** variable, not the intersection across all requested variables.
Use **pairwise (per-variable) NA removal** for `get_variance()`, matching
`get_freqs()`'s multi-var behaviour. State this explicitly in the spec.

### G8. Constant (zero-variance) variable — numerical stability

If all in-domain non-NA `y_i` are identical, $\bar y = y_i$ everywhere and
$(y_i - \bar y)^2 \equiv 0$. Then $\hat V = 0$, the influence vector is
$u_i \equiv 0$, and the variance engine returns exactly 0 for SE. No
`0/0` pathologies — denominators $W$ and $n-1$ remain strictly positive
as long as $n \ge 2$ and all weights positive. Request explicitly specifies
"zero-variance (constant) variable → `0` with `se = 0`, no warning".
Implementation note: use `sqrt(max(0, v))` defensively for replicate paths,
since a tiny negative residual from replicate subtraction is possible for a
near-constant variable.

### G9. `deff` for variance — what does it mean, and is `survey`'s analog the right one?

`survey::svyvar(..., deff = TRUE)` is not a supported argument; `svyvar`'s
design-effect is only wired through `svymean(x^2, ..., deff = TRUE)` via
the reduction. The family `deff` column for `get_variance()` should
compute the design effect of the derived mean $\hat z = \hat V$ — i.e.,
`deff = var(V_hat) / var_srs(z)` where `var_srs(z)` uses the same
`.taylor_mean_cell()`-style SRS variance of the score variable $z_i = a_i
(y_i - \bar y)^2 n/(n-1)$, matching how `.add_variance_cols()` derives
`deff` in the rest of the family. Spec this out rather than leaving it to
builder discretion.

### G10. Factor / character input silently dropped by `svyvar()`?

`svyvar.survey.design` will coerce a factor to numeric via `model.frame`
(and error if it can't). surveycore's precedent in `get_means()` is to
**reject** non-numeric input with `surveycore_error_non_numeric_variable`,
and the request confirms this is the desired surveycore behaviour. So the
numerical-parity oracle tests should pre-coerce or pre-filter inputs to
numeric on both sides — do **not** test surveycore's error path against
`svyvar()`'s silent coercion.

### G11. `subset == 0` rows in survey package — zero-weight row semantics

`svyvar.survey.design` excludes rows where `weights(design, "sampling") == 0` from
`n` (see line 703 of survey.R). surveycore weights are strictly positive by
validator (S7 `surveycore_error_weights_nonpositive`), so this case cannot
arise via constructor-built designs. But `survey_nonprob` validators
accept zero weights (row 101 in error-messages.md allows `>= 0`). Safest:
define $n = \sum_i a_i \cdot \mathbb{1}(w_i > 0)$ to match survey and to
guard numerical stability when a nonprob weight column happens to contain
zeros. Tests with `survey_nonprob` + zero weights should confirm parity.

### G12. Column labels for gt — don't forget

Per `project_column_labels.md` memory entry, every family output sets
column-level `label` attributes for gt integration. The `variance`
column should get a label like `"Variance"` (or the focal variable label
when known), `se` → `"SE"`, `ci_low` / `ci_high` with the conf-level
interpolated, etc. Follow the template in `.add_variance_cols()` and in
whichever helper `get_means()` uses to set the point-estimate label.

## Reference mapping

| Reference | Specific mapping |
|---|---|
| `survey::svyvar.survey.design` (survey.R:696–730) | Defines the **estimand** including the `n/(n-1)` factor and the reduction "variance = mean of centred-squared, with Kish scale". Drives the point-estimate formula in §1 and the Taylor-path reduction in §2. |
| `svyvar.survey.design` reliance on `svymean(...)` | Confirms the engine re-use: `get_variance()` Taylor path should be implemented as a call to the same stratified/clustered `.svy_recvar()` engine `get_means()` uses, on the derived score. |
| `svyvar.svyrep.design` (surveyrep.R:766–831) | Defines the **replicate-weight variance** — per-replicate recomputation of $\bar y^{(r)}$ and the Kish-corrected estimate, fed to `svrVar`. Drives §3 and Gotcha G3. Confirms that `n` (sample size) is frozen across replicates. |
| Absence of `svyvar.twophase` in survey | Confirms that under twophase, `get_variance()` should **not** invent its own phase-1/phase-2 decomposition — it should build the influence vector from the score and hand to `.twophasevar()`, mirroring how `svymean.twophase` handles derived means. Drives §4. |
| Lumley (2010) *Complex Surveys* §2.4 | Justifies Taylor linearisation of plug-in estimators: the variance of $\hat V(Y)$ is the variance of the HT total of its influence function. Equation (2.12) corresponds to our §2 formula. |
| `surveycore::.vcov_pair_taylor` (variance-taylor.R:339) | Structural **template** for the Taylor path: how to build the influence-matrix + feed into `.svy_recvar()`, including domain masking via `pair_mask` and safe handling of `x_safe` for out-of-domain rows. `get_variance()` replaces `pair_mask` → single-variable $a_i$, and the 3x3 infl matrix → 1-column infl vector; crucially, adds the `n/(n-1)` factor that `.vcov_pair_taylor()` omits (Gotcha G1). |
| `surveycore::.build_cluster_matrices`, `.svy_recvar` | Reused verbatim; no change required. |
| `surveycore::.svy_rep_var` (variance-replicate.R:26) | Reused verbatim for replicate path (§3). |
| `surveycore::.twophasevar`, `.compute_phase2_probs` (variance-twophase.R:24, 322) | Reused verbatim for twophase path (§4). Influence vector construction mirrors `.twophase_mean_cell()`. |
| `surveycore::.apply_domain`, `.resolve_groups`, `.mean_domain_vec` | Reused verbatim for domain / grouping / NA handling — exact same semantics as `get_means()`. |
| `surveycore::.calibrated_mean_cell` (analysis-means-helpers.R:242) | Template for nonprob path (§5): same HT form, with an outer `n/(n-1)` and a different score. |
| `surveycore::.add_variance_cols`, `.make_result_tibble`, `.apply_name_style`, `.apply_decimals` | Reused verbatim for result assembly. `name_style = "broom"` remap: add `variance` → `estimate`. |
| `plans/error-messages.md` rows 43, 45, 45a, 45b, 46, 49, 50, 54, 81, 64 | All reused. New rows G6 introduces (if accepted) should be added with IDs after the `A-*` / `C-*` block — propose `V-1`, `V-2`. |

## Assumptions

### A1. Point-estimate column name

The request fixes `variance` as the column name (not `var`, which is already
used for the optional variance-as-uncertainty column in `.add_variance_cols()`).
This is a minor design break from `svyvar` (whose printed column is labelled
`"variance"` via `attr(v, "statistic")`) but matches the surveycore naming
pattern (`mean`, `total`, `pct`, `corr`, `ratio`, ..., all short and
unambiguous). No conflict with the opt-in `var` column — they have different
semantics (estimand vs uncertainty of estimand). Spec should be crystal
clear about this.

### A2. `survey::svyvar` silently converts factor inputs via `model.frame`

surveycore rejects non-numeric input at the `get_*()` call site. The
numerical-parity tests must pre-coerce on both sides, or select numeric
columns only, or compare against a numeric-only svyvar call.

### A3. `(n/(n-1))` uses unweighted $n$, not weighted $W$

The Kish `n/(n-1)` correction is a **sample-size** correction (unweighted
count of in-domain non-NA rows in the **estimation** set), not a weighted
correction. `svyvar.survey.design` computes
`n <- sum((weights != 0) & (rowSums(is.na(x)) == 0))`, confirming: unweighted
count, non-NA in any of the focal columns, weight strictly positive. For
surveycore's per-variable mode, $n$ is the per-variable non-NA count in
the active domain with positive weight.

### A4. Single-vs-multi-var in `x`

Unlike `get_means()` (single variable only, errors on `length(x) != 1`),
`get_variance()` accepts one or more numeric variables via tidy-select
(matching `get_freqs()`'s input API). Output is one row per variable. No
`names_to` / `values_to` arguments are needed (variance has no category
dimension). The variable name lives in the `name` column (per request) —
not as a column named after the variable — because with multiple variables
a single column-name convention would clash.

### A5. No off-diagonal covariances

The request is explicit: "tidy variances only; no off-diagonals". This is
a meaningful restriction from `svyvar.survey.design`, which when called
with a multi-column `x` returns a $p \times p$ covariance matrix with
off-diagonals. `get_variance()` returns only the diagonals. Any future
`get_covariance()` is out of scope for this plan.

### A6. No standard-deviation estimand

Request is explicit. Callers take `sqrt(meta(result) / result$variance)`
themselves, just as they would with `survey::svyvar`.

### A7. `conf_level` normal approximation for CI bounds

Consistent with `get_means()`, CI bounds use the normal approximation
(`degf = Inf`). `conf_level = 0.95` gives `z = 1.959964`, applied to the
design SE. Note: a variance estimate's sampling distribution is
asymptotically normal but **right-skewed** at finite $n$ — the normal-based
CI can dip below zero. Spec should **not** clamp to zero silently
(that would be wrong inference); it should mention the behaviour in the
docstring. An optional log-CI refinement is out of scope.

### A8. `deff` denominator

Per G9, the SRS comparator for `deff` is the SRS variance of the score
$z_i = a_i (y_i - \bar y)^2 n/(n-1)$, not the SRS variance of $y_i$.
This matches how `survey` computes `deff` for `svyvar` internally (via
`svymean(x^2 * n/(n-1))`). Spec should codify this and the test-spec
should include a numerical parity test.

### A9. Design effect for nonprob

`survey_nonprob` reports deff just like the rest of the family; the SRS
comparator is the same unweighted sample-SRS variance of $z$ with the
nonprob weights ignored. Follow the `.calibrated_mean_cell()` precedent.

### A10. `label_values` / `label_vars` — accepted for API uniformity

`get_variance()` output has no categorical value cells and no stacked
variable-name column (variable names go in the `name` column as raw names
or with the variable label substituted if `label_vars = TRUE`). Accept
both arguments for API uniformity; `label_vars = TRUE` substitutes the
variable-label-if-present for the `name` column value. `label_values` has
no visible effect (same as `get_means()`).

### A11. `n` column semantics

`n` is the unweighted count of in-domain, non-NA rows with positive weight
used to compute the variance for each variable's row. When two variables
are requested, their `n` values can differ (pairwise deletion — Gotcha G7).
`n_weighted = sum(w_i * a_i * 1(w_i > 0))` when opted in.

### A12. Empty `x` (tidy-select matches 0 columns)

Follows the precedent of `get_means()` `surveycore_error_wrong_variable_count`
vs `get_freqs()` (which allows 0 and returns 0 rows with a warning? — check
in spec). The request implies at least one numeric variable is required; if
tidy-select resolves to 0 variables, error with
`surveycore_error_wrong_variable_count` (reusing row 138 family behaviour).
