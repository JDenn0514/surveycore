# Verification — comprehension.md, round 1

Adversarial check per `stage-0-comprehension.md` §Adversarial Verification,
2026-11-10. Four read-only checkers, one per section group, against `R/` on
`develop` at `0c0a987`. Totals: 155 OK, 11 ISSUE.

| Sections | OK | ISSUE |
|---|---|---|
| Formulas, Reference mapping, Assumptions | 42 | 1 |
| Per-function call paths | 47 | 3 |
| The joint matrix and its diagonal | 37 | 4 |
| Function-specific notes, Gotchas | 29 | 3 |

R facts were measured on R 4.6.1 ucrt, reference BLAS,
`getOption("matprod")` = "default".

## Issues

### V1 — Per-function call paths, `get_means()` cell-independent work
Claim: `as.matrix()` at `:172` and the two products at `:173`, `:175` are
cell-independent. Source: `R/analysis-means-helpers.R:173,175`; `domain` is
rebuilt per combo at `R/analysis-means.R:234`. Problem: both products depend
on `domain`, and `get_means()` makes one cell per combo. Only the
`as.matrix()` is cell-independent. (In `get_freqs()`, `denom` is shared across
the levels of a combo; in `get_means()` nothing is shared.)

### V2 — Per-function call paths, `get_means()` second caller
Claim: `get_quantiles()` reads `cell$se` and needs the per-cell SE and df.
Source: `R/analysis-quantiles-helpers.R:154-156`. Problem: it reads
`cell$mean` and `cell$se`, and never `cell$df`. The constraint is the
per-cell mean and SE.

### V3 — Per-function call paths, `get_covariance()` stored results
Claim: one pair result per combo is stored and reused. Source:
`R/analysis-covariance.R:377-378, 411, 428, 506-520`. Problem: one result is
stored per needed unordered pair (key `"i-j"`) per combo.

### V4 — Reference mapping, two-phase hoist
Claim: hoisting `.compute_phase2_probs()` is the only exact hoist on the
two-phase route. Source: `R/variance-twophase.R:91-152`
(`.twophase_phase1_var()`), `:360-378` (`.twophase_phase2_var()`),
`R/analysis-freqs-helpers.R:183-184`. Problem: `.twophasevar()` runs once per
cell and recomputes structures that depend only on the design and `subset`:
`strata_all`, `psu_all`, `nPSUfull_by_strat`, `usu_ph2`; `strata1`, `psu1`,
`n1_h` (`.count_units()`), `units2` (`.phase2_units()`), `n2_h`; and
`cal_wt = w_full / pi2_full` in each cell. Also `.compute_phase2_probs()`
runs twice per cell: in the cell and inside `.twophase_phase2_var()` at
`:377`.

### V5 — Function-specific notes, `get_ratios()` nonprob warnings
Claim: on nonprob without replicates, each cell warns three times. Source:
`R/analysis-totals-helpers.R:358-371`; `R/analysis-ratios.R:296, 317-328,
331, 347`. Problem: three times only for cells that reach the numerator and
delta calls. An empty cell, or one with an NA denominator total, warns once
and moves on at `:327`.

### V6 — Gotchas, nonprob-SRS warning count
Claim: the four dispatchers warn once per cell call. Source:
`R/analysis-freqs-helpers.R:328`, `R/analysis-means-helpers.R:388`,
`R/analysis-totals-helpers.R:370`, `R/analysis-variance-helpers.R:515`,
`R/analysis-covariance-helpers.R:572`. Problem: five dispatchers in scope
raise `surveycore_warning_nonprob_srs_fallback`. The warning also comes from
`R/analysis-corr-helpers.R:43` and `R/glm.R:341`, so not all 104 baseline
warnings come from these dispatchers.

### V7 — Gotchas, NA and empty cells
Claim: `n_g == 0L || N_d <= 0` fails with a base R error when `n_g > 0`, so
no live cell carries an NA weight. Source: `R/analysis-means-helpers.R:309,
319-322`; `R/analysis-totals-helpers.R:283, 293-303`;
`R/analysis-freqs-helpers.R:257`; `R/analysis-variance-helpers.R:40-44`.
Problem: true only on the Taylor and replicate freq/mean/total/ratio cells.
The calibrated (nonprob SRS) mean and total cells test only `n_d == 0L` and
read in-cell weights: an NA weight in the cell gives a live cell with an NA
estimate and no error. The calibrated freq cell fails earlier, at
`if (N_d > 0)` (`:257`). The variance and covariance cells use
`active = (domain > 0) & !is.na(y) & (w > 0)`, so an NA weight outside the
cell leaves the cell live. The conclusion holds for the routes that carry a
joint element; it is stated for all routes.

### V8 — Joint matrix, condition 1: multistage designs (MISSED CONDITION)
Claim: a clean column's diagonal gets the factor `H / H_ok`, or Inf when
`H_ok = 0`; strata with NA rows drop from `H_ok`. Source:
`R/variance-taylor.R:172-189` (recursion per first-stage cluster), `:134`,
`:142-143`. R (scratchpad `verify/v3.R`): two-stage design with fpc,
4 strata x 3 PSUs, one NA in one row of PSU 1. Stack diagonal: clean col a =
NaN, clean col b = Inf. Single-column: 24.97 and 29.65. Same data one-stage:
ratio 4/3. Problem: in a multistage design with fpc, each first-stage
cluster's sub-recursion has its own `nstrat` / `nokstrat`. One NA row makes
`nokstrat = 0` in that PSU, so every clean column in the stack becomes Inf,
or NaN where it is zero in that PSU, even when stage-1 `H_ok > 0`.

### V9 — Joint matrix, condition 1: NaN, not only Inf
Claim: Inf when `H_ok = 0`; for means, every clean cell gets Inf. Source:
`R/variance-taylor.R:136-143`: `(0 * nstrat) / 0` is NaN. Problem: a clean
column whose summed contribution is zero gets NaN. The outcome is Inf or NaN.

### V10 — Joint matrix, condition 1: `"average"` baseline
Claim: on its own, a clean column has `H_ok = H`. Source:
`R/variance-taylor.R:79, 134`. R (`verify/v2.R`): with `"average"` and one
lonely stratum, the stack/single ratio was 4, not 5. Problem: under
`"average"` a lonely stratum is all-NA for every column, so a clean column
alone has `H_ok = H - L` (L lonely strata). The gap is
`(H - L) / H_ok_stack`.

### V11 — Joint matrix, condition 1: calibration not covered
Claim: the reachable cases (all `na.rm = FALSE`) include `get_totals()` and
`get_ratios()`. Source: `R/calibration.R:386-388` (passes through only an
all-NA `u`), `:434` `qr.resid(cd$qr, u / cd$w)`, `:271` (LINPACK `qr()`).
R: `qr.resid()` with one NA in y errors "NA/NaN/Inf in foreign function call
(arg 5)". Problem: on a calibrated Taylor design, the totals case and the
numerator-NA ratios case (NA on some rows) abort in the projection before any
variance call, so they are reachable only on uncalibrated designs. The means
case (all-NA `u`) passes Guard 1 and is reachable either way. Read from code
and base R; no calibrated design was run end to end.

## Notes from checkers (OK, but worth the spec's attention)

- Replicate route: `.svy_rep_vcov()` (`t(d*r) %*% d * scale`,
  `R/variance-replicate.R:73`) and `.svy_rep_var()` (`sum(d^2 * r) * scale`,
  `:46`) agree only in exact arithmetic. The comment at
  `R/analysis-helpers.R:1208-1210` overstates this. Keep the per-cell
  replicate SE on `.svy_rep_var()`.
- `lonely.psu = "fail"`: both a stacked and a single call abort with
  `surveycore_error_lonely_psu` on `nPSU` alone.
- Condition 6 cites `R/analysis-methods-coef-vcov.R:383-391`, which is
  roxygen. The overrides are at `R/analysis-variance.R:296-303` and
  `R/analysis-covariance.R:397-409`.
- `get_ratios()` on nonprob without replicates warns
  `surveycore_warning_nonprob_srs_fallback` once per `.total_cell()` call.
- Later-stage recursion runs only when `popmat` is non-NULL and there is more
  than one cluster column (`R/variance-taylor.R:172-190`).

## NA replicate weights (open question, settled)

Nothing in `R/` rejects an NA in a replicate weight column:
- `survey_replicate` class: `R/core-classes.R:758-774` checks `is.numeric()`
  only.
- `.validate_repweights()` (`R/core-validators.R:290-337`), called at
  `R/core-constructors.R:1153`: existence and numeric only.
- `as_survey_nonprob()` (`R/core-constructors.R:2095-2126`) does not call
  `.validate_repweights()`; the `survey_nonprob` validator has no replicate
  check.
- The "no NA" text at `R/core-constructors.R:862` is about `rscales`
  (`R/core-validators.R:397-414`).

Today one NA anywhere makes every `get_freqs()` replicate total NA
(`R/analysis-freqs-helpers.R:118-119`): `survey_replicate` aborts with
`surveycore_error_all_replicates_na` (`R/variance-replicate.R:29-34`);
`survey_nonprob` warns `surveycore_warning_domain_replicates_na` and returns
an NA cell (`R/analysis-helpers.R:1303-1325`). A subset sum over the cell's
rows would return finite values for cells without the NA row, which changes
results and conditions.

## R facts (open questions, settled)

1. `nrow(df[rows, NULL, drop = FALSE]) == sum(rows)` is TRUE for a logical
   `rows` with no NA (3 == 3; all FALSE gives 0). With an NA in `rows`, nrow
   is 3 and `sum(rows)` is NA.
2. `identical(sqrt(max(0, NaN)), sqrt(pmax(0, NaN)))` is TRUE. The same holds
   for NA.
3. `crossprod()` with a NaN or Inf column leaves the finite columns
   unchanged: over 200 seeds, `[1, 1]` and the finite 3x3 block were
   identical to the finite-only result (0 mismatches). Also identical for a
   finite column with values near overflow (1e308).
4. `.svy_recvar()` stack diagonal was `identical()` to the single-column
   results under remove, adjust, average and certainty, one-stage and
   two-stage with fpc, with a lonely stratum, when every column is finite.

---

# Round 2 (sign-off), 2026-11-10

Two checkers on the revised comprehension.md.

| Scope | OK | ISSUE |
|---|---|---|
| V1 to V7 revisions, new claims, citations of this file | 18 | 0 |
| Condition 1 rewrite (V8 to V11), plus three cases run in R | 14 | 3 |

## Correction to round 1

§NA replicate weights above says one NA makes every `get_freqs()` replicate
total NA. Wrong: one NA in replicate column r makes only column r NA in every
cell (`0 * NA`). `.svy_rep_var()` drops it (`R/variance-replicate.R:28,
35-38`) and aborts only when every replicate is NA (`:29-34`). The fix-3
conclusion stands: a subset sum over the cell's rows would keep a replicate
that the full product drops, so it is exact only when
`all(is.finite(rep_mat))`.

## Round-2 issues (fixed in comprehension.md by the orchestrator)

- W1: the variance/covariance NA-weight case does not give a stack/single
  mismatch. An NA weight inside any cell aborts with a base R error; outside
  every cell, all live columns are NA on that row and the stack equals the
  singles.
- W2: the Inf-weight case is not "the four joint functions". `get_freqs()`
  and grouped means/totals/ratios abort; ungrouped calls agree.
- W3: missed case. `Inf` / `-Inf` in numeric `x` reaches the stack in
  `get_means()` and `get_totals()` on uncalibrated designs and gives the
  mismatch. On calibrated designs it aborts in `qr.resid()`.

## R runs (round 2)

Frame: 4 strata x 3 PSUs x 2 rows, n = 24, groups A/B alternating (row 2 is
group B, stratum 1). `as_survey(..., ids = psu, strata = st, weights = w,
nest = TRUE)`. R 4.6.1 ucrt, reference BLAS. Scripts were piped to
`R --no-echo` and not saved (`Rscript -e` with multi-line code segfaulted,
exit 139).

- a1/a2, NA base weight, uncalibrated. Row in a cell: `get_variance()` and
  `get_covariance()` fail with "missing value where TRUE/FALSE needed" for
  every group / `na.rm` combination. Row outside every cell (NA `x` with
  `na.rm = TRUE`, or NA group): single `.svy_recvar()` 0.01879626 and
  0.4414899; stack diagonal `identical()` TRUE. With that weight zeroed:
  0.02632682 and 0.3719307. `get_variance()` CI for A [0.298, 0.836] against
  [0.249, 0.885] with a finite weight; `get_covariance()` B
  [-0.904, -0.171] against [-1.075, 0.0005].
- b/b2, Inf base weight: accepted by `as_survey()`. `get_means(x)` NaN;
  grouped: base R error at `if (n_d == 0L || N_d <= 0)`. `get_totals(x)`
  Inf with `.vcov` 182.1667. `get_freqs(f)`: base R error. `get_ratios()`
  NaN. Inf in `x`, `na.rm = TRUE`, grouped: means A se^2 0.04872819 against
  `.vcov` diag Inf; totals 31.14489 against 41.52652.
- Uncalibrated `get_totals(group = g, na.rm = FALSE)`, NA in `x[2]`: clean
  cell A `.vcov` diag 41.52652 against se^2 31.14489 (ratio 4/3).
- c, calibrated (`as_caldata(w, g_w, model.matrix(~ z, d))`), NA in `x[2]`,
  `na.rm = FALSE`: `get_means(group = g)` A se^2 0.03740842, `.vcov` diag
  Inf. `get_totals()`: "NA/NaN/Inf in foreign function call (arg 5)" in
  `qr.resid()`. `get_ratios()` same error, at call 2 (numerator NA) or call
  1 (denominator NA). Control `na.rm = TRUE`: se^2 equals `.vcov` diag.
- c2, calibrated, Inf in `x`: `get_means()` and `get_totals()` abort in
  `qr.resid()`.

Round 2 ends the verification (cap: 2 fix rounds). The orchestrator applied
the three round-2 fixes directly; they correct the case list and do not move
the conclusion.
