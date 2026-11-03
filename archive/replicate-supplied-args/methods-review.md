# Methods review — replicate-supplied-args

**Verdict:** PASS (pass 1; two ADVISORY findings, both resolved by a wording
change; no formula, test row or acceptance criterion changed)

Reference checked: `survey:::svrepdesign.default`, installed survey 4.5,
R 4.6.1. Deparsed copy: `scratch/svrepdesign_default.R`.

## Lens applicability

- Lens 1 (estimator specification): not applicable. No estimator changes.
- Lens 2 (variance estimation): run. 1 ADVISORY.
- Lens 3 (degrees of freedom and inference): run. No issues. Every
  confidence-bound assertion sits in test-spec §6, where both sides use the
  normal interval at df = Inf.
- Lens 4 (domain estimation): not applicable. No domain logic changes.
- Lens 5 (established practice): run. 1 ADVISORY. The nine-type table and
  every quoted `survey` message match the installed source character for
  character.
- Lens 6 (literature cross-check): not applicable. No literature attached.

## M-1 (Lens 2, ADVISORY) — Section IV overstated why the export fix matters

For BRR, Fay, JK2, ACS and successive-difference, `survey` overrides `scale`
(and `rscales` for the last three) unconditionally. So the export-route change
moves no exported number for those five types; it removes a warning. The
numeric fix for those types is in the constructor.

**Resolution:** spec §IV "Numerical property" gains a paragraph that names
which half of the work carries the property for each group of types.

## M-2 (Lens 5, ADVISORY) — JKn + `rho` + no `rscales` diverges unstated

`survey` raises its `rho` warning and then its JKn error. The spec raises only
the error (test-spec row 5.18 asserts no warning).

**Resolution:** keep the behaviour; name it. spec §VIII and `@param rho`
state the difference, and new decision D-f records it. `survey` refuses this
input, so D7's parity rule does not reach it.
