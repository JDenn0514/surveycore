# Methodological Review — surveywts-calibration Spec

**Date**: 2026-06-04  
**Scope**: `plans/spec-surveywts-calibration.md`  
**Method**: Eight subagents — four extractors (one per paper), four error-identification agents  
**Papers reviewed**:
- Deville & Särndal (1992), "Calibration Estimators in Survey Sampling," JASA 87:418
- Deville, Särndal & Sautory (1993), "Generalized Raking Procedures," JASA 88:423
- Rao, Yung & Hidiroglou (2002), "Estimating Equations … Using Poststratification Information," Sankhya 64
- Särndal (2007), "The Calibration Approach in Survey Theory and Practice," Survey Methodology

---

## Error 1 — CRITICAL: Wrong oracle mandated

**Location**: "Raking oracle — required contract change" section  
**Spec claim**: "The correct oracle for raking-adjusted variance is `survey::rake()`."

`survey::rake()` uses iterative cyclic projection (10-iteration ICC approximation). `survey::calibrate()` uses exact QR projection implementing D&S 1992 eq (3.4). These produce numerically different SEs — a gap of approximately 1.2×10⁻² on NHANES data, confirmed by direct numerical comparison. This is not a rounding difference; it is a genuine variance formula difference.

Surveycore's `.apply_caldata_projection()` is byte-for-byte identical to `survey`'s `greg_calibration` branch in `svyrecvar()`. The existing test comment the spec wants removed is correct: surveycore matches `survey::calibrate()`, not `survey::rake()`.

Mandating `survey::rake()` as the oracle would cause the numerical tests to fail without any code change.

**Correct oracle**: `survey::calibrate()` with the combined indicator matrix (for the Architecture A single-caldata path) or two sequential `survey::calibrate()` calls (for the existing two-caldata path). Surveycore matches `survey::calibrate()` to machine epsilon (~4.4×10⁻¹⁶).

---

## Error 2 — HIGH: "One column dropped" prose is wrong for Q ≥ 3

**Location**: Inter-package contract, lines describing the raking model matrix  
**Spec claim**: "The combined matrix … has **exactly one linear dependency** … Therefore, only **ONE column needs to be dropped** from the entire combined matrix (not one per margin). … The `+1` accounts for the fact that only one redundant column is dropped from the entire combined matrix."

**Formula immediately adjacent** (`Σ_q n_q − Q + 1`) **is correct**. The prose contradicts it.

For Q margins, the null space of the combined indicator matrix has dimension Q − 1, not 1. Each margin q satisfies Σ_j X_{q,j} = **1** (sum-to-ones), giving Q constraints that all target the same vector **1**. These collapse by transitivity into Q − 1 independent column-dependencies. Therefore Q − 1 columns must be dropped.

Verified numerically for all cases:

| Q | Example n_q | Total cols | Rank | Cols to drop |
|---|-------------|------------|------|--------------|
| 2 | 2+2 | 4 | 3 | 1 |
| 3 | 2+2+2 | 6 | 4 | 2 |
| 4 | 2+3+2+4 | 11 | 8 | 3 |

For Q = 3 (r, c, s levels): the correct model matrix has `r + c + s − 2` columns (drop one from two of the three margins). The spec's "one drop total" instruction would produce an `r + c + s − 1` matrix — rank-deficient by one, yielding an incorrect projection.

D&S&S 1993 only addresses Q = 2 explicitly ("fix v_c = 0" = one drop, which equals Q − 1 = 1 for that case). The spec's generalization to "one drop total" for all Q is not supported by any paper.

**The formula is correct; the prose in three places must be corrected.** No code changes required — the implementation uses `qr$rank` for df reduction, which counts actual rank regardless of column count.

**Corrected characterization**: For Q-way raking, Q − 1 columns must be dropped — one reference level from each of Q − 1 margins (equivalently, keep all columns of one chosen margin and drop the last column of every other margin).

Two-way concrete example (already correct in spec): `cbind(X_A, X_B[, -c])` → n × (r + c − 1).  
Three-way example to add: `cbind(X_A, X_B[, -c], X_C[, -s])` → n × (r + c + s − 2).

---

## Error 3 — MEDIUM: FPC ordering described backwards

**Location**: Quality gates section  
**Spec claim**: "FPC adjustments are incorporated into the Horvitz-Thompson variance structure (via `.svy_onestage()`) BEFORE the linearized influence function is passed to `.apply_caldata_projection()`. This ordering matches D&S 1992 eq (3.4)."

Both sentences are wrong.

**Code order** (confirmed by reading `R/variance-taylor.R`):
1. Line 276: `.maybe_apply_calibration()` — calibration projection runs **first**
2. Lines 279–285: `.svy_recvar()` → `.svy_onestage()` — FPC-weighted summation runs **second**

This matches `survey`'s `svyrecvar()` exactly (projection loop first, then `multistage()` with FPC). The code is correct.

**"Matches D&S 1992 eq (3.4)"** is also imprecise: eq (3.4) does not mandate an ordering. FPC is embedded in Δ_{kl} throughout the simultaneous expression — the paper does not decompose it into sequential steps.

**Corrected description**: The linearized influence function is first projected by `.apply_caldata_projection()` (producing calibration-adjusted residuals), then passed to `.svy_recvar()` where FPC adjustments are incorporated via `.svy_onestage()`. This is consistent with D&S 1992 eq (3.4), where calibrated residuals e_k appear inside the Δ_{kl} double-sum with FPC embedded in Δ_{kl}.

---

## Error 4 — LOW: Implementation not exactly D&S 1992 eq (3.4) — asymptotically equivalent

**Location**: Inter-package contract ("Unified code path" paragraph) and as_caldata() contract  
**Spec claim** (implicit): The QR projection implements D&S 1992 eq (3.4).

D&S 1992 eq (3.4) formally requires ψ_k = w_k · e_{W,k} where e_{W,k} are residuals from the *calibrated-weight* normal equations (W = diag(w_k)):

`B̂_W = (X'WX)⁻¹X'Wu`

The surveycore formula produces w_k · ê_{D,k} — calibrated weight times *base-weight* projected residuals (D = diag(d_k)):

`B̂_D = (X'DX)⁻¹X'Du`

The step-by-step algebra of `qr.resid(cd$qr, u / cd$w) * cd$w`:

1. `u / cd$w` = `(g·d·y) / (g·√d)` = `√d·y` — g cancels in the division because u = w_cal·y
2. `qr.resid(qr(√d·X), √d·y)` = `√d·(y − X·B̂_D)` = `√d·ê_D` — D-weighted projection
3. Multiply by `cd$w = g·√d`: result = `g·d·ê_D = w_cal·ê_D`

The difference B̂_W − B̂_D is O_p(n^{−1/2}), making the two variance estimators asymptotically equivalent with O(n^{−1}) difference. This is acceptable and this implementation matches the survey R package exactly (which makes the same simplification deliberately, using base weights in the QR before `design$prob` is updated by calibration).

The spec should acknowledge this rather than implying exact equivalence to eq (3.4). One sentence is sufficient: the projection uses D-weighted (not W-weighted) normal equations, which is asymptotically equivalent to eq (3.4) and matches the survey package reference implementation.

---

## Error 5 — LOW: q_k = 1 assumption undocumented

**Location**: Inter-package contract, as_caldata() contract  
**Issue**: D&S 1992 introduces a unit-specific weighting factor q_k that modifies both the calibration equations and the variance formula. The survey package stores `w = g · sqrt(d) · sqrt(σ²)` (not `g · sqrt(d)`) when `variance = lambda` is passed to `calibrate()`. The spec makes no mention of q_k.

This is not a correctness bug for standard GREG and raking workflows (both universally use q_k = 1, which is the survey package's default). It is an incomplete contract specification.

**Risk**: A future caller using `survey::calibrate(..., variance = lambda)` for ratio-estimation calibration (D&S 1992 Example 1: q_k = 1/x_k) who naively extracts g_weights from the survey caldata object would get g·sqrt(q_k) instead of g, silently producing incorrect variance estimates.

**Recommended addition to the inter-package contract**: State explicitly that the contract assumes q_k = 1 for all units (the standard case for GREG-to-totals and raking). If calibration was performed with non-unit q_k, the caller must pre-scale model_matrix by diag(√q_k) before passing it to as_caldata(), and must extract g_weights as caldata$w / (sqrt(base_weights) · sqrt(q_k)).

---

## Minor Issues

### 6. Result 5 citation slightly overstated

**Location**: "Unified code path" paragraph  
**Spec claim**: GREG and raking "share the same asymptotic variance formula."  
**More precise**: "All calibration family members are asymptotically equivalent to the GREG; eq (3.4) is the *recommended* (not uniquely mandated) variance estimator for any member." The paper uses the word "recommended," acknowledging that using d_k instead of w_k also gives a design-consistent estimator.

### 7. D&S&S 1993 eq (6.1) citation imprecise

**Location**: Column count formula explanation  
**Issue**: The spec cites "D&S&S 1993 eq 6.1" as the source for the ANOVA dimension formula. Eq (6.1) defines the x_k indicator vector, not the parameter count. The ANOVA parameter count argument is in D&S&S 1993 Section 7 (the additive ANOVA parameterization).

### 8. Särndal (2007) provides no variance grounding

Särndal (2007) explicitly states it does not address variance estimation (Section 1.1: "for reasons of space, the important question of variance estimation is not addressed"). It cannot serve as methodological grounding for any variance claims in this spec. Its only relevant contribution is confirming the combined margin indicator structure (Section 2, Examples 4–5: "dimension of x_k being P + Q − 1 … the 'minus-one' is to avoid a singular matrix"). All variance methodology must be grounded in D&S 1992 directly.

---

## Summary

| # | Error | Severity | Code correct? | Spec correct? |
|---|-------|----------|---------------|---------------|
| 1 | Oracle: `survey::rake()` mandated; `survey::calibrate()` is the match | **Critical** | ✅ | ❌ |
| 2 | "One column dropped" wrong for Q ≥ 3; Q − 1 drops required | **High** | ✅ | ❌ (prose) |
| 3 | FPC ordering described backwards | **Medium** | ✅ | ❌ |
| 4 | Projection uses D-weights not W-weights vs. eq (3.4); asymptotically equivalent, not exact | Low | ✅ | Incomplete |
| 5 | q_k = 1 assumption undocumented | Low | ✅ | Incomplete |
| 6 | Result 5 overstated ("same formula" vs. "recommended estimator") | Cosmetic | — | Imprecise |
| 7 | D&S&S eq (6.1) citation points to wrong equation | Cosmetic | — | Imprecise |
| 8 | Särndal (2007) cited for variance methodology it does not address | Cosmetic | — | Inapplicable |

The underlying implementation (`.apply_caldata_projection()`) is correct in all cases and matches the survey package reference implementation. All errors are in the spec's description of the methodology, not in the code.
