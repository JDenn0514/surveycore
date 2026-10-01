# Review — PR 4 — fay-rho-import

**Verdict**: PASS
**Date**: 2026-09-30

Tree reviewed: dd70f9edfd9c23173e1016c0e29c431519454d5d (HEAD 8aa215e),
base develop d9d38ee. `git rev-parse HEAD^{tree}` agrees with the tree in
`audit.md` and in `gates/summary.txt`.

## Convergence checks

- Spec coverage: y. Spec §V has five contract items. Four are in this PR,
  and each has an audit row:
  - Fay stores `x$rho` unchanged: 4.1, 4.4, 4.6.
  - Any other type stores `NULL`, key present: 4.2 (source `$rho` 0) and
    4.3 (source `$rho` 0.3).
  - The scale stays `x$scale` and the SE does not move: 4.1, at 1e-10 and
    1e-8.
  - No new condition: the diff adds no `cli_abort()` or `cli_warn()`.

  The fifth item (a Fay rho that is `NULL` or out of range imports with no
  condition) is rows 4.5, 4.5a and 4.5b. The plan's row-assignment table
  gives them to PR 5, because they also assert
  `surveycore_error_fay_rho_unrecoverable`, which PR 5 adds. The spec also
  says the validator does not change (§Class changes), so nothing in PR 4
  blocks those rows.
- Test coverage of spec: y. Test-spec §4 has a row for every §V item,
  4.1 to 4.7.
- Tolerance integrity: y. Test-spec §Tolerances gives 1e-10 for points,
  1e-8 for SE, and 1e-8 for a stored scale. The diff has six numeric
  `expect_equal()` calls with a new or edited tolerance. The SE is at 1e-8.
  The five rho and scale values are at 1e-10. The scale row (4.1) is
  tighter than the 1e-8 that test-spec gives. That is allowed and is
  noted here. No row is looser. PR 1's STOP category does not recur.
- Scope discipline: y. `git diff --stat d9d38ee 8aa215e` shows
  `R/methods-conversion.R` and `tests/testthat/test-conversion.R` only.
  This agrees with the plan's Files touched and with `implementation.md`.
- Regression safety: y. The suite goes from 12199 to 12213 passes (+14),
  with 0 failures. Warnings stay at 256, the D12 AAPOR baseline. Skips stay
  at 4. No `_snaps/` change.

## Cross-consistency notes

- Code against spec. The new line is
  `rho <- if (identical(x$type, "Fay")) x$rho else NULL`, and it goes into
  `variables` between `mse` and `fpc`. This is the §V table. The comment
  block states the BRR `$rho` 0 and 0.3 cases, the scale rule and the
  deferred refusal. Each one agrees with §V.
- Oracle rule. Row 4.3 captures survey's bare warning with
  `expect_warning(..., "does not use 'rho=' argument", fixed = TRUE)`, so
  it matches by text and not by class. No new block calls
  `suppressWarnings()`, and no block passes `scale` to survey. Rows 4.1 and
  4.6 are round-trip rows. The SE in 4.1 compares the SE of the imported
  design against survey's SE on the source, which is a conversion-fidelity
  claim.
- The FA fixture in row 4.3 (`n = 200, n_psu = 20, n_strata = 4,
  type = "fay", seed = 15`) agrees with test-spec §Datasets. The builder
  used `data = df` because survey reads a regex `repweights` only from
  `data`. That is a fixture detail and does not change what the row
  asserts.
- Row 4.3 also asserts `expect_equal(src$rho, 0.3, tolerance = 1e-10)` on
  the source. The plan does not ask for this assertion. It proves that the
  fixture carries a non-`NULL` rho, so the `NULL` import is a real test.
- Row 4.6 (all-types block). The Fay pass exports through the scale
  inversion that PR 5 deletes, then re-imports. The assertion is
  `expect_equal()` at 1e-10, and the audit measured 0.3. After PR 5 the
  export reads the stored rho, so this assertion stays valid. PR 5 must
  keep it green.
- Comprehension alignment: y. Gotcha 2 ("rho on a non-Fay type is not
  stored") is rows 4.2 and 4.3. The import note ("store `x$rho` for Fay
  only; a Fay object can carry 1.5") is rows 4.1, 4.4 and, in PR 5, 4.5.
  The partial-matching note for `$rho` does not apply here: no element
  of an `svyrep.design` object other than `rho` starts with `rho`.
- CRAN cookbook: None, and the audit verdict is PASS, so the two agree.
- Profile gates. Every gate has a result:
  - Gate 5's first run was killed with no `Status:` line.
    `decisions.md` §"Gate note — PR 4 R CMD check killed" records this.
  - The detached re-run on the same tree is `gate-5b-check.log`. It gives
    `Status: 2 NOTEs`, and `gate-5b-00check.log` has NOTEs at lines 14
    and 37 only.
  - The NOTE for CRAN incoming feasibility is pre-approved. The NOTE for
    the hidden `.git` file is pre-existing: the Before column also has
    2 NOTEs, and the archive of as-svydesign-bridge records it.
  - No gate was skipped.
- Coverage: 96.16%, above the 95% floor, with no change from the
  baseline. `R/methods-conversion.R` is at 99.77%. The one uncovered line
  is 649. The diff for this PR touches lines 1009 to 1031 only, so no new
  line is uncovered. Rows 4.1 (Fay) and 4.2 (BRR) reach both branches of
  the new `if`.

## Decision

PASS. The builder and the tester agree on the §V contract. Every
tolerance is equal to or tighter than the test-spec value. The write
surface is the planned two files. The gates, the coverage and the warning
count are clean on tree dd70f9e. Rows 4.5, 4.5a, 4.5b and 4.7 are open by
plan and go to PR 5.
