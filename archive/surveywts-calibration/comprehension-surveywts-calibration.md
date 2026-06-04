# Comprehension — surveywts-calibration

## Problem

The goal is to define what structure `surveywts` must hand to `surveycore` after
performing calibration (GREG-type or raking-type), and to confirm that
surveycore's existing single-QR-projection variance engine can absorb that
structure for all calibration types. The existing `as_caldata()` constructor
and `.apply_caldata_projection()` function already implement the D&S 1992
GREG variance correction. The open question is whether raking calibration can
reuse the same mechanism — it can, by D&S Result 5 — and exactly what
`surveywts` must produce for surveycore to build the required `caldata` element.
A secondary question is whether the current four-field caldata list `{qr, w,
stage, index}` is structurally sufficient, or whether surveywts needs a richer
handshake object. This comprehension establishes that the current `as_caldata()`
structure is sufficient for GREG-type calibration (where the model matrix is
explicit) but that surveywts must also supply the combined model matrix for
raking calibration — it cannot be reconstructed from calibrated weights alone.
The inter-package contract therefore requires surveywts to expose the model
matrix to surveycore, not just the g-weights.

---

## Formulas

### Notation (bound to surveycore data structures)

| Symbol | Meaning | surveycore binding |
|--------|---------|-------------------|
| `d_k` | Base sampling weight (1/π_k) | `design@data[[design@variables$weights]]` before calibration |
| `w_k` | Calibrated weight | `design@data[[design@variables$weights]]` after calibration, or `d_k * g_k` |
| `g_k` | g-weight = w_k / d_k | `as_caldata()`'s `g_weights` argument |
| `X` | n × J calibration model matrix | `as_caldata()`'s `model_matrix` argument |
| `u_k` | Linearized influence function for unit k | rows of the `u` matrix in `.apply_caldata_projection()` |
| `e_k` | Calibration residual for unit k | computed implicitly via QR projection |

### D&S 1992 eq (3.4) — variance estimator for all calibration estimators

For any calibration estimator (GREG, raking, logit, etc.), the asymptotically
valid variance estimator is:

  V̂(t_yw) = ΣΣ_{k,l∈s} (Δ_kl / π_kl)(w_k e_k)(w_l e_l)

where `e_k = y_k - x_k' B̂_ws` are the weighted-residuals from regressing `y`
on the calibration model matrix `X` with calibrated weights `w_k`. This is
equivalent (in the Taylor linearization context) to projecting the linearized
influence function `u` onto the orthogonal complement of the column space of
`sqrt(d_k) * X`, scaled by the g-weights.

### QR projection formula (current `.apply_caldata_projection()`)

Input `u` is the n × p linearization matrix. The projection step for one
caldata element is:

  u_projected = qr.resid(qr(sqrt(d) * X), u / (g * sqrt(d))) * (g * sqrt(d))

Stored in caldata as:
- `cd$qr` = `qr(sqrt(base_weights) * model_matrix)`
- `cd$w` = `g_weights * sqrt(base_weights)`

So the formula evaluates as: `qr.resid(cd$qr, u / cd$w) * cd$w`

This implements: project `u` onto the orthogonal complement of the column
space of `sqrt(d) * X` in the metric defined by `w = g * sqrt(d)`. This is
precisely the residual from regressing the scaled influence function on the
calibration covariates.

### Why this applies to raking (D&S 1992 Result 5)

Result 5 states: for any distance function F satisfying the conditions in
Section 2 (which includes the multiplicative/raking distance function
F(u) = exp(u)), the calibration estimator is asymptotically equivalent to the
GREG estimator at order O_p(n^{-1}), and the two share the same asymptotic
variance.

Therefore: the variance formula using the calibration model matrix X applies
identically to raking estimators. The model matrix X for raking on margins is
the column-bound indicator matrix of all calibration variables, exactly as
described in D&S 1992 Section 4 and D&S&S 1993 eq (6.1):

For a two-way raking (r row levels × c column levels):
  x_k = (δ_{1-k}, ..., δ_{r-k}, δ_{·1k}, ..., δ_{·ck})'

This is a matrix with (r + c) indicator columns (one column per margin level),
with one column dropped for identifiability (D&S&S 1993 fix v_c = 0).
After dropping the redundant column: X has (r + c - 1) columns.

For a Q-way raking: X has (Σ_q n_q - Q + 1) columns, where n_q is the number
of levels in margin q. This is the dimension of the fitted additive ANOVA model.

### D&S&S 1993 eq (9.1) — residuals for raking variance

The residuals used in the variance estimator are:
  e_k = y_k - (Â_i + B̂_j)   (for two-way raking)

where Â_i and B̂_j are obtained from the sample-based calibration equations
(the additive ANOVA fit weighted by calibrated weights w_k). Importantly,
this is exactly what QR residuals from the combined indicator model matrix X
produce: regressing `y` (or `u`, the influence function) on the margin
indicator matrix X with weights w_k yields the ANOVA residuals.

This confirms: `qr.resid(qr(sqrt(d) * X), u / (g * sqrt(d))) * (g * sqrt(d))`
is exactly the correct variance correction for raking — if X is the combined
margin indicator matrix.

---

## Gotchas

**Gotcha 1: surveywts cannot reconstruct the model matrix from g-weights alone.**
The g-weights w_k / d_k tell surveycore how much each weight changed, but not
*why*. To build `as_caldata()`, surveycore needs the model matrix X. For
GREG calibration, X is the design matrix of calibration variables (easy to
supply). For raking, X is the combined indicator matrix of all margin
variables — this can be constructed from the margin structure, but requires
knowing which variables were raked on and their cell assignments. surveywts
must supply X explicitly. It cannot be recovered post-hoc from g-weights.

**Gotcha 2: Rank deficiency of the raking model matrix.**
If any margin level has zero sample observations, the corresponding indicator
column of X is all-zero and X is rank-deficient. `qr()` handles this via
pivoting — `qr$rank` will be less than `ncol(X)`. The degrees-of-freedom
reduction must use `qr$rank`, not `ncol(X)`. This is already correct in the
current implementation (JC-1 decision from prior planning).

**Gotcha 3: Separate caldata entries for sequential raking margins.**
The prior decisions (JC-4) document that each margin in a multi-way rake can
produce a separate caldata entry, and sequential QR projection over multiple
entries correctly implements the joint GREG variance. This is correct only if
the raking has converged: the g-weights used for each margin's caldata must
reflect the fully-converged IPF weights (i.e., g_k = w_k^{final} / d_k for
all k), not the intermediate weights from a single raking pass. surveywts
must pass the final converged g-weights.

**Gotcha 4: Single combined caldata vs. per-margin caldata for raking.**
Two architectures are possible: (A) surveywts produces one caldata entry with
the full combined indicator matrix X, or (B) surveywts produces K separate
caldata entries, one per margin, each using the marginal indicator matrix and
the final g-weights. Architecture A is simpler and more defensible — the
joint model matrix is what D&S 1992 prescribes. Architecture B (sequential
projection over per-margin matrices) is an approximation that is valid only
if the margins' column spaces are approximately orthogonal. For non-orthogonal
margins (which is the common case), Architecture A is strictly correct.
Architecture B was accepted in the prior planning (JC-4) based on Kolenikov
(2014) §1.5, but Kolenikov's citation actually establishes asymptotic
equivalence, which is already guaranteed by Result 5 — it does not assert
that per-margin sequential projection equals joint-matrix projection for
finite samples. This is a potential HOLD.

**Gotcha 5: The g-weights for the combined caldata entry must be final IPF weights.**
For GREG: g_k = (calibrated weight) / (base weight) = w_k / d_k.
For raking: same formula — g_k = w_k^{IPF, final} / d_k.
The model matrix X, however, is determined by the calibration *targets* (the
margin structure), not by the weights. surveywts can construct X before or
after IPF convergence — it only depends on which variables were raked and
their levels.

**Gotcha 6: Intercept column in the model matrix.**
If the calibration model includes an intercept (total calibration), the
intercept column (all-1s) must be included in X. For post-stratification
(calibration on known cell counts), the full cell indicator matrix includes an
implicit intercept. For raking on margins, the combined margin matrix already
spans the intercept (since summing all row indicators gives a vector of 1s).
surveywts must ensure X has full column rank or accept that qr$rank < ncol(X).

**Gotcha 7: The `@calibration` slot property type is `NULL | list`.**
The current S7 class definition uses `S7::new_property(default = NULL)` with no
class constraint on the `calibration` property. This is intentional — it
allows any list structure. A stricter typed property would complicate the
surveywts interface. The validator for acceptable caldata shape lives in
`.apply_caldata_projection()`, not in the S7 class validator.

**Gotcha 8: What happens when surveywts calibrates AFTER `as_survey()`?**
The current design requires `@calibration` to be assigned after design
construction: `design@calibration <- list(as_caldata(...))`. There is no
`calibration =` parameter in `as_survey()` or `as_survey_replicate()`. The
request.md asks for `as_survey()` to accept a `calibration =` parameter.
This is a non-trivial constructor change because the calibration data's
`base_weights` must equal the design's weight column. If the user passes
calibration data built with different base weights, the projection is wrong.
The constructor must validate that `length(caldata$w)` equals `nrow(data)`.

**Gotcha 9: Replicate-weight designs and calibration.**
For replicate-weight designs (BRR, jackknife, bootstrap), the calibration
correction via QR projection is applied to the *influence function* u, which
does not directly apply in the replicate variance framework (the variance is
computed from replicate-to-full-sample differences, not Taylor linearization).
For replicate designs, the calibration correction is typically applied by
using calibrated weights for each replicate — i.e., the replicate weights
themselves should already incorporate the calibration adjustment. The QR
projection approach applies only to Taylor series variance.  The request.md
asks for calibration on `survey_replicate` as well; the appropriate path
there may be different (calibration-adjusted replicate weights, not QR
projection of an influence function).

**Gotcha 10: Near-zero denominator in the QR projection.**
The projection formula `u / cd$w` divides the influence function by `g * sqrt(d)`.
If any `g_k` or `d_k` is near zero, this creates numerical blow-up. The current
`as_caldata()` already checks for near-zero `g_weights * sqrt(base_weights)`.
The bound is `.Machine$double.eps^0.5 ≈ 1.5e-8`. For very small base weights
(e.g., oversampled rare groups with d_k ≈ 0.001), `sqrt(d_k) ≈ 0.032`, and
g_k = 1.0 would give w = 0.032, well above the threshold. This check is
adequate.

---

## Reference mapping

- **D&S 1992, Section 3 / eq (3.4)** → The variance estimator formula that
  surveycore implements via `qr.resid()`. All downstream design decisions about
  the QR projection flow from this equation.

- **D&S 1992, Result 5** → Justification for using a single QR-based variance
  correction for all calibration types, including raking. This is the
  foundational result that allows one code path for GREG and raking.

- **D&S 1992, Section 4 / eq (4.1) / Figure "two-way table" x_k definition** →
  Defines the model matrix X for raking on marginal counts. This is what
  surveywts must produce and pass as `model_matrix` to `as_caldata()`.

- **D&S&S 1993, Section 4 / eq (4.7)** → Confirms that the same variance
  formula (4.7) = D&S 1992 eq (3.4) applies to the generalized raking
  estimator, making the variance formula universal.

- **D&S&S 1993, Section 9 / eq (9.1)** → Confirms that the ANOVA residuals
  from the additive model fit on the combined margin indicator matrix are the
  correct residuals for the variance estimator. This is what QR projection on
  the combined X produces.

- **D&S&S 1993, Section 9, last paragraph** → Notes that the same software used
  to solve the calibration equations (i.e., fit the additive model) can be
  used to compute the residuals needed for variance estimation. This is exactly
  what `qr()` on the combined X achieves.

- **Prior decisions (JC-1, JC-4, JC-5)** → df reduction via `qr$rank`;
  sequential raking projection accepted for multi-margin raking; negative df
  clamping with warning.

- **survey package internals (greg_calibration)** → The survey package's
  `calibrate()` implementation stores `$qr` and `$w` in `$postStrata$greg_calibration`,
  applying exactly `qr.resid(qr, x/w) * w`. This is the reference
  implementation confirming surveycore's `.apply_caldata_projection()` formula.

---

## Assumptions

**Assumption 1: surveywts will produce the model matrix X explicitly.**
The inter-package contract requires surveywts to pass `model_matrix` to
`as_caldata()`. This is not a zero-cost requirement: surveywts must preserve
the model matrix after calibration convergence, not just the calibrated weights.
For GREG calibration, X is the design matrix of the calibration variables
(always available from the data). For raking, X is the combined margin indicator
matrix, which surveywts can construct from its own margin structure before or
after IPF. This assumption is reasonable and must be documented as the contract.

**Assumption 2: The "combined matrix" architecture is chosen over "per-margin" architecture.**
The comprehension recommends Architecture A (single caldata entry with the
combined X) over Architecture B (separate caldata entries per margin). This
matches D&S 1992 exactly and avoids the numerical question of whether
per-margin sequential projection is accurate for non-orthogonal margins.
However, Architecture B (the existing JC-4 approach) is what the prior planning
accepted — and it has the practical advantage of being more incremental (each
margin can be passed separately). This is a potential HOLD (see below).

**Assumption 3: Calibration on `survey_replicate` uses calibrated replicate weights, not QR projection.**
For replicate designs, the appropriate calibration correction is implemented
at the replication level, not through QR projection of a Taylor influence
function. The request to support calibration on `survey_replicate` may require
a separate mechanism. This assumption must be surfaced and documented.

**Assumption 4: Only between-PSU (stage = 0) calibration is in scope.**
The existing `as_caldata()` validates `stage = 0L` and rejects anything else.
Within-PSU calibration is deferred to a future version via the `index = NULL`
slot. This assumption is inherited from the prior design (JC-6) and remains
correct.

**Assumption 5: `as_survey()` `calibration =` parameter accepts the same caldata list structure as `design@calibration <- list(as_caldata(...))`.**
The request asks for a `calibration =` parameter on `as_survey()`. The simplest
implementation is that this parameter takes a pre-built caldata list (output of
`as_caldata()`). surveywts would call `as_caldata()` then pass the result to
`as_survey(..., calibration = list(cal))`. The alternative (surveywts passes
raw materials and `as_survey()` calls `as_caldata()`) would couple the
constructor more tightly to the calibration logic and is not preferred.

---

## Potential HOLD signals (for spec phase)

**HOLD-1 (Architecture A vs B for raking)**
The prior planning (JC-4) accepted per-margin sequential caldata entries
(Architecture B). This comprehension identifies that Architecture A (single
caldata entry with combined X) is theoretically exact, while Architecture B
is an approximation whose accuracy depends on margin orthogonality. The spec
must take a documented position: recommend Architecture A to surveywts
(produce the combined model matrix), allow Architecture B as a backward-
compatible fallback for cases where producing the combined matrix is difficult.
This is a judgment call for the user if they want to retain B.

**HOLD-2 (Replicate designs)**
The appropriate calibration correction for `survey_replicate` is qualitatively
different from the Taylor case. The request asks for it but the mechanism may
need to be a separate code path. The spec phase should document which replicate
types support QR-based calibration (none, in principle) versus calibrated
replicate weights (potentially all).
