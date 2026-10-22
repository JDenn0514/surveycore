# Changelog: fix/twophase-approx-ids2

**Branch:** `fix/twophase-approx-ids2`
**Status:** Complete
**Date:** 2026-10-22
**Issue:** #334

## Summary

Refs #334. On a two-phase design with `method = "approx"` (or `"simple"`,
its alias since #333), surveycore's standard errors disagreed with
`survey::twophase(method = "approx")` built from the same inputs whenever
phase 2 drew whole phase-1 sampling units: `ids2` naming the phase-1 cluster,
or any weighted phase 1 without clusters. Point estimates agreed. On the
issue's 40-cluster, 8-stratum fixture the mean SE was 0.602 against survey's
0.745 and the total SE 9,480 against 13,120. An unclustered, stratified
phase 1 with `strata2` gave a total SE of 3,323 against 5,010.

The phase-1 term already matched. The gap was the phase-2 term.
`survey:::twophasevar()` multiplies the phase-2 score by `sqrt(pi1)` only
when some phase-1 unit holds more than one phase-2 unit; otherwise it uses
the score unscaled (`twophase()`'s `samescale`). surveycore always
multiplied, which shrank the phase-2 term by the phase-1 sampling fraction.
`.twophase_phase2_var()` now ports the `samescale` check. Designs where
phase 2 subsamples rows inside phase-1 clusters keep the scaled score and do
not change.

survey's form is the right one here. A Monte Carlo check (survey 4.5, 1,500
to 2,000 replications) put the empirical variance at 90.5M for an `ids2`
design, against 87.6M for survey's estimator and 51.3M for surveycore's old
one; for an unclustered weighted phase 1 the figures were 3.48M, 3.76M and
2.07M. The old SEs ran about 40% low in both.

Published `method = "approx"` and `"simple"` standard errors and confidence
intervals rise for these designs.

### Domains

On a filtered design surveycore now agrees with survey's zero-filled form,
`svytotal(~I(y1 * A))` and `svyratio(~I(y1 * A), ~I(A))`, to 1e-8. It does
not agree with survey's `subset()`: survey drops the rows, and
`onestrat.phase1()` pads the missing domain units with a phase-2 probability
of 1 in place of their own, so survey's `subset()` SE differs from survey's
own zero-filled one (total SE 5,047 against 5,175 on the `ids2` fixture).
surveycore keeps treating a domain as zero influence, which is the
zero-filled form, and the phase-1 term is unchanged.

## Files Modified

- `R/variance-twophase.R` — new `.twophase_same_scale()`; `.twophase_phase2_var()` leaves the phase-2 score unscaled when it holds.
- `VENDORED.md` — row for `.twophase_same_scale()`; `.twophase_phase2_var()` row records the change.
- `tests/testthat/test-variance-twophase.R` — Section 8: oracle blocks for `get_means()`, `get_totals()` and `survey_glm()` under `method = "approx"` with `ids2`, and for `get_means()` and `get_totals()` on an unclustered weighted phase 1, each unfiltered and on a domain.

## Changes

- `method = "approx"` and `"simple"` two-phase standard errors match `survey::twophase()` when phase 2 draws whole phase-1 units (`ids2` on the phase-1 cluster, or an unclustered phase 1).
- Domain blocks assert survey's zero-filled total and ratio; the domain `survey_glm()` block asserts coefficients only, because survey has no zero-filled GLM form and its `subset()` SE carries the padding above.
