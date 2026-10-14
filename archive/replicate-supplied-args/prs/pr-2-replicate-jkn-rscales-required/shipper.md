# Shipper - PR 2 - replicate-jkn-rscales-required

**Status**: PR opened (not merged; leader watches CI and merges)
**Date**: 2026-10-07

## Opened PR

- PR: #312 https://github.com/JDenn0514/surveycore/pull/312
- Base: develop (9e9f09e). Head: fix/replicate-jkn-rscales-required (c5d7621).
- Title: fix(constructors): refuse JKn with no rscales in as_survey_replicate()
- Body says "Part of #255 (PR 2 of 6)", not "Closes".
- Review verdict read: PASS.

## Gates

- G9: `git diff --name-only origin/develop...HEAD` lists five paths, none under .surveycore-workspace/:
  R/core-constructors.R, plans/implementation-plan-replicate-supplied-args.md,
  plans/pr-budget-calibration.md, tests/testthat/_snaps/constructors.md,
  tests/testthat/test-constructors.R.
- Push: fast-forward f2aba10..c5d7621. No new commits. No force push.

## Not done by design

- No merge. No auto-merge. No plan edit. No CI check.

## HOLDs

None.

## Note

The Write tool was not available. The PR body and this file were written with heredocs.
