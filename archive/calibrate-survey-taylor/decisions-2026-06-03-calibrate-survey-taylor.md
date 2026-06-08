# Decisions — calibrate-survey-taylor

Recorded during Stage 2r (methods-review resolution).

---

## JC-1 — DoF adjustment for calibrated designs

**Finding**: DOF-1 (REQUIRED, JUDGMENT_CALL)
**Decision**: Include in this spec.
**Resolution**: Add a §Degrees-of-freedom adjustment section to spec.md. Calibrated designs reduce df by `qr$rank` (not `ncol(model_matrix)`) of the stored caldata QR decomposition. For multiple accumulated caldata entries (raking), the total df reduction is the rank of the combined column space — which sequential QR projection achieves automatically. The df adjustment is applied inside the analysis functions (`.taylor_mean()`, `.taylor_mean_cell()`, `.taylor_total()`) when reporting the `df` column in output tibbles. Specifically, for each accumulated caldata entry, subtract `cd$qr$rank` from the design df before computing t-based CIs.

---

## JC-2 — All-NA outcome in `.apply_caldata_projection()`

**Finding**: DOM-1 (REQUIRED, JUDGMENT_CALL)
**Decision**: Pass-through in projection.
**Resolution**: Add to `.apply_caldata_projection()` contract: "If all entries of `u` are NA, return `u` unchanged (no projection attempted)." Implemented as: `if (all(is.na(u))) return(u)` at the top of the function body. This keeps the projection function simple and delegates NA-outcome handling to the callers' existing NA propagation logic.

---

## JC-3 — Empty `@calibration` list condition

**Finding**: DOM-4 (REQUIRED, JUDGMENT_CALL)
**Decision**: Strengthen the condition (no S7 validator).
**Resolution**: Change projection condition in `.taylor_mean()`, `.taylor_mean_cell()`, and `.taylor_total()` from `!is.null(design@calibration)` to `!is.null(design@calibration) && length(design@calibration) > 0L`. An empty list remains a valid R object but will not trigger projection, giving intuitive behavior without a validator that raises errors.

---

## JC-5 — Negative df guard behavior (R-7)

**Finding**: R-7 (REQUIRED, JUDGMENT_CALL)
**Decision**: Warn + clamp to `max(1L, df_final)`.
**Resolution**: When calibration reduces `df_final` to ≤ 0, emit `surveycore_warning_zero_df_after_calibration` and clamp `df_final = max(1L, df_final)`. CIs are still computed (potentially wide) and the user is informed. This matches the same pattern used for GLM's `df_residual <= 0` guard (row 77 in error-messages.md). An error would prevent any output from a degenerate-but-real edge case; silent clamping would hide a user-relevant condition. Warn + clamp is the right balance.

---

## JC-6 — index = NULL field in caldata (R-9)

**Finding**: R-9 (REQUIRED, JUDGMENT_CALL)
**Decision**: Keep `index = NULL` in v1, document future semantics explicitly.
**Resolution**: `as_caldata()` returns a 4-element list `c("qr", "w", "stage", "index")` where `index = NULL` always. Documentation states: "NULL means all rows in scope; future within-stratum calibration will populate this with a logical index vector." The 4-field structure is stable and forward-compatible. This is preferred over removing `index` now because the slot is part of the documented caldata format that surveywts must construct, and adding it later would be a breaking change for any surveywts code that already unpacks the 3-field version.

---

## JC-4 — Sequential raking projection: literature and quality gate

**Finding**: LIT-3 (REQUIRED, JUDGMENT_CALL)
**Decision**: Cite papers + add numerical quality gate.
**Resolution**: Add citations to spec.md:
- Kolenikov (2014) §1.5 establishes that raking's asymptotic variance equals the joint GREG variance (citing Deville & Sarndal 1992).
- Deville & Sarndal (1992) cases 2 (raking) establishes the calibration estimator's variance properties.
- RYH (2002) §2.3 eq (2.5) is the implementation formula.
Sequential QR projection over K caldata entries faithfully implements the joint GREG variance because after IPF convergence, each margin's caldata encodes part of the joint column space. Add quality gate (quality gate 10) to test-spec.md: raking-adjusted SE from `get_means()` must match `survey::rake()` output within 1e-8.
