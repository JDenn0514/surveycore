# Changelog: fix/twophase-approx-crosscut-strata2

**Branch:** `fix/twophase-approx-crosscut-strata2`
**Status:** Complete
**Date:** 2026-10-23
**Issue:** #341

## Summary

Refs #341. On a `method = "approx"` two-phase design whose `strata2` cuts
across the phase 1 PSUs, surveycore's standard errors differ from `survey`'s.
The difference is in the phase 1 term; the phase 2 term agrees exactly
(824686.9 on both sides for the total of `y1`). surveycore's behaviour is
kept, and this change adds a test and a source comment that record why.

When a phase 1 PSU spans several `strata2` strata, its rows carry different
phase 2 sampling fractions. `survey:::onestrat.phase1()` sums the influence
by PSU with `rowsum()`, which sorts the PSUs by factor level, and takes the
fractions with `ph2prob[!duplicated(cluster)]`, which keeps row order. The
two orders differ (`psu_1, psu_10, ...` against `psu_1, psu_2, ...`), so most
PSU totals are paired with another PSU's fraction, and `survey`'s SE depends
on row order and PSU labels. surveycore pairs each PSU's total with the mean
of its own fractions, so its SE does not. With nested strata the fractions
are constant within a PSU and the two rules agree; the existing oracle tests
cover that case.

Measured on the issue #341 fixture (survey 4.5, R 4.6.1):

| Data | `survey` total SE | `survey` mean SE | surveycore total SE | surveycore mean SE |
|---|---|---|---|---|
| fixture as is | 14981.94 | 0.8598917 | 14516.61 | 0.8599244 |
| PSUs relabelled `psu_01...` | 14809.54 | 0.8576635 | 14516.61 | 0.8599244 |
| rows shuffled | 15709.79 | 0.8683466 | 14516.61 | 0.8599244 |

Before and after this change surveycore gives the same numbers: no
estimate, standard error or interval moves.

## Files Modified

- `R/variance-twophase.R` — a comment in `.twophase_phase1_var()` at the
  PSU-level fraction, recording that the rule departs from `survey` on
  purpose
- `tests/testthat/test-variance-twophase.R` — one block asserting that the
  `get_means()` and `get_totals()` SEs on the fixture do not move when PSUs
  are relabelled or rows reversed. Swapping in `survey`'s pairing turns both
  assertions red

## Changes

- Record why the approx phase 1 variance keeps its own PSU-level phase 2
  fraction when `strata2` cuts across phase 1 PSUs, and pin that the SE does
  not depend on row order or PSU labels
