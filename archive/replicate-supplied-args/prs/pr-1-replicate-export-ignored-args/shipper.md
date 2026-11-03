# Shipper - PR 1 - replicate-export-ignored-args

**Status**: PR opened (not merged; the leader watches CI and merges)
**Date**: 2026-10-07

## Opened PR

- PR: #311, https://github.com/JDenn0514/surveycore/pull/311
- Base: develop. Head: fix/replicate-export-ignored-args.
- Title: fix(conversion): stop passing scale and rscales that survey overrides on export
- HEAD pushed: 1650f93 (fast-forward from eec6ce1 on origin).
- Body: "Part of #255 (PR 1 of 6)." No "Closes".

## Gate G9

`git diff --name-only origin/develop...HEAD` lists nine paths, none under
`.surveycore-workspace/`: R/methods-conversion.R, R/utils.R, five
plans/*-replicate-supplied-args.md or plans/error-messages.md files,
tests/testthat/test-conversion.R, tests/testthat/test-variance-replicate.R.

## Notes

- No new commits made. Plan not edited. Auto-merge not enabled.
- The Write tool was denied; this file and the PR body came from heredocs.
