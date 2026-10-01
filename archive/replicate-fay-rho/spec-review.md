# Spec Review: replicate-fay-rho — Pass 1 (2026-09-30)

Six lens agents (sonnet), in parallel, on `spec.md` and `test-spec.md` after
METHODS_REVIEWED. Lens 5 (Engineering Level) found no issues; it judged P3 and
P4 right-sized.

Each issue carries its resolution. "Orchestrator" means settled in this
session without the user; "user" means the user chose.

### New Issues

**Issue 1: The spec is ambiguous about removing the Fay entry from the
default-scale switch** (Lens 1, REQUIRED)
"The Fay entry leaves the default-scale switch" was read by the reviewer as
"stays". Resolution (orchestrator): reword to "is deleted from", and state that
no `Fay` branch remains in the switch.

**Issue 2: The Fay `rho` print logic is specified twice** (Lens 1, SUGGESTION)
The `, rho = {rho}` suffix and the `Rho:` line are gated on the same condition
in `print()` and `summary()`. Resolution (orchestrator): accept. One inline
helper in `R/methods-print.R` (one file, so inline per code-style) builds both
pieces from `x@variables`; both methods call it.

**Issue 3: Quality gate 6 (no change to `R/variance-replicate.R`) has no
test-spec row** (Lens 2, REQUIRED)
Resolution (orchestrator): add a §6 row: `git diff` against the base shows no
change to that file.

**Issue 4: Oracle rows 2.6 and 2.7 drop the no-warning and stored-scale
assertions** (Lens 2, REQUIRED)
Resolution (orchestrator): option B. The preamble to rows 2.1 to 2.7 states
that every row asserts the stored scale against its literal and that
`svrepdesign()` raises no warning.

**Issue 5: The argument position has no test row** (Lens 2, REQUIRED) — merged
with Issue 12.
Resolution: see Issue 12.

**Issue 6: The four new message templates are not in spec.md** (Lens 3,
BLOCKING)
FR-1 to FR-3 and TP-1 point at the register; CB-4 and row 19 are inline.
Resolution (orchestrator): option A. Inline the full x/i/v templates and the
variable bindings for all four in spec.md, word for word as in the register.

**Issue 7: The new roxygen example is not given** (Lens 3, REQUIRED)
Resolution (orchestrator): option A. Write the example block in spec.md: a
small inline data frame, `type = "Fay"`, `rho = 0.5`, runnable under R CMD
check, in the style of the existing examples in that roxygen block.

**Issue 8: A 1x1 matrix or array `rho` passes the check** (Lens 4, REQUIRED)
Measured by the reviewer: `matrix(0.3)` and `array(0.3, c(1, 1, 1))` pass.
Resolution (orchestrator): add `is.null(dim(rho))` to `.is_valid_rho()`; add
matrix and array to the invalid-input rows.

**Issue 9: No test exports a filtered Fay design** (Lens 4, REQUIRED)
Resolution (orchestrator): add a row. Filter the Fay fixture, call
`as_svydesign()`, assert `$rho` and `$scale` equal the literals and the
domain SE matches surveycore's.

**Issue 10: No import row for a survey Fay object with `$rho` NA or NULL**
(Lens 4, SUGGESTION)
Resolution (orchestrator): accept; add both beside the out-of-range row.

**Issue 11: No oracle row near `rho = 1`** (Lens 4, SUGGESTION)
Resolution (orchestrator): declined. Construction at 0.999 is tested and the
oracle rows reach 0.9; an oracle at scale 1e30 tests floating point, not
this feature.

**Issue 12: `rho` is placed last, away from `type` and `scale`** (Lens 6,
REQUIRED)
Resolution (user): S11. `rho` goes after `type`, before `scale`, as in
`survey::svrepdesign()`. P1 is withdrawn. This is a breaking change for a
call that passes `scale`, `rscales`, `fpc`, `fpctype`, `mse` or
`calibration` by position; NEWS records it. Every such positional call in
`R/`, `tests/`, `vignettes/` and `README.Rmd` must be found and listed. A
test row asserts the new formal order (`names(formals(as_survey_replicate))`
against a literal).

**Issue 13: The error class names are not consistent** (Lens 6, REQUIRED)
`surveycore_error_rho_invalid` fires only for Fay, and its siblings carry
`fay_rho_`. Resolution (orchestrator): rename to
`surveycore_error_fay_rho_invalid`, in the spec, test-spec and register row
FR-2.

**Issue 14: `rho = 0` keeping `type = "Fay"` is not documented for users**
(Lens 6, SUGGESTION)
Resolution (orchestrator): accept. One sentence in `@param rho`: `type` stays
`"Fay"` at `rho = 0`, unlike `survey::as.svrepdesign()`, which relabels it
`"BRR"`.

## Summary (Pass 1)

| Severity | Count | Accepted | Declined |
|---|---|---|---|
| BLOCKING | 1 | 1 | 0 |
| REQUIRED | 9 | 9 | 0 |
| SUGGESTION | 4 | 3 | 1 |

Issue 5 is merged into Issue 12. Verdict: FAIL; route to Stage 3r (BIG mode,
more than 8 findings).

## Spec Review: replicate-fay-rho — Pass 2 (2026-09-30, delta)

Two agents (sonnet): one on the changed sections of spec.md, one on those of
test-spec.md.

- spec.md: Issues 1, 2, 6, 7, 8, 12, 13, 14 RESOLVED. The inline templates
  match the register word for word; no `surveycore_error_rho_invalid` remains;
  the example is valid R and uses only arguments in the new signature.
- test-spec.md: Issues 3, 4, 8, 9, 10, 12, 13 RESOLVED. Row 1.4a's formal
  vector matches the current formals with `rho` after `type`.
- No new issues from either agent.

Verdict: PASS (the pass needed no change to either artifact).
