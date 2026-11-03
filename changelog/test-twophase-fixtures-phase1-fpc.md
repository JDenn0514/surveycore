# Changelog: test/twophase-fixtures-phase1-fpc

**Branch:** `test/twophase-fixtures-phase1-fpc`
**Status:** Complete
**Date:** 2026-10-29
**Issues:** follow-up to #350 (#339, #340)

## Summary

#350 added `surveycore_warning_twophase_full_no_fpc`. 30 existing blocks built
a weighted `method = "full"` design with no phase-1 `fpc` and were changed to
assert the warning. This branch gives those fixtures a phase-1 `fpc` instead,
so the warning is expected only where a block is checking it. Eight blocks
raise it now, down from 36: six in `test-constructors.R` (one per phase-1
shape, one showing it fires at construction and not from an estimate, and the
message snapshot), the dedicated `from_svydesign()` block in
`test-conversion.R`, and one parity block in `test-variance-twophase.R`.

That parity block is kept on purpose. It is the only check that the no-`fpc`
`"full"` variance, the one the warning describes, matches
`survey::twophase()`. It now compares means, totals and the GLM, where the
block it replaces compared means only. Its phase 1 is unclustered, so the
units are rows, and rows per stratum are unequal: with an `fpc`, survey 4.5's
`Dcheck_multi_subset` misread of n_h (#332) would make `survey` an invalid
oracle, so this block has to stay without one.

**No behaviour changes.** Test files only.

## Files Modified

- `tests/testthat/test-variance-twophase.R` — Section 7's `"full"` builders
  give phase 1 an `fpc` on both sides. Every stratum keeps five clusters, so
  `survey` stays a valid oracle. The `"approx"` `ids2` builder, which shared
  the phase-1 builder, now builds its own no-`fpc` phase 1, unchanged from
  before. The unclustered block becomes the one no-`fpc` parity block. The
  "full method with a phase-1 fpc" block is removed: with the builders
  carrying an `fpc` it duplicated the `strata2` means and totals blocks
  exactly (same data, design and `survey` object)
- `tests/testthat/test-conversion.R` — every `survey::twophase(method =
  "full")` builder gains `fpc = list(~fpc, ...)`. The 13 warning assertions
  from #350 are removed, and the two `expect_no_warning(from_svydesign(sv))`
  claims are restored. The dedicated warning block builds its own no-`fpc`
  object. The expression-`probs2` block sets its phase-2 probability to the
  realised fraction in each stratum (see below)
- `tests/testthat/test-constructors.R` — the weights-only phase-1 block gains
  an `fpc`; the `survey_nonprob` phase-1 block uses `method = "approx"`,
  because `as_survey_nonprob()` takes no `fpc`; a new block covers the
  weighted, unclustered, unstratified shape, which the weights-only block
  used to assert

## The expression-probs2 fixture

`make_twophase_frame()` draws phase 2 as a Bernoulli 40% sample, so the
realised fraction per stratum runs from 0.34 to 0.52. The block declared
`probs2 = 1/w2 = 0.4` with `strata2 = strata`, which describes a fixed-size
stratified draw at exactly 0.4. Against a without-replacement phase 1 those
contradictory probabilities give a negative variance of a total (-5.2e6).
Both packages compute the same negative value: `survey` reports `NaN` and
surveycore clamps it to 0, so the oracle could not compare them. The block now
uses each stratum's realised fraction, and still exercises an expression
`probs2`.

## Correction to #350

The #350 PR body said the `test-conversion.R` oracle fixture has unequal PSU
counts per stratum. It does not: all eight strata hold five PSUs.

## Verification

The full suite has 0 failures, and its warnings are the same set of file and
message pairs as on `develop` before #350: 369, none of them the new warning.
