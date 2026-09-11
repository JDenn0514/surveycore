# Shipper — PR 0 — nonprob-domain-se-correction

**Date:** 2026-09-10
**Branch:** `fix/nonprob-domain-se-correction`
**Review verdict read:** PASS (`review.md`)

## Actions taken this dispatch

1. Verified working tree: clean apart from the four untracked `plans/*.md`
   arc artifacts (`decisions-`, `implementation-plan-`, `spec-`,
   `test-spec-as-svydesign-domain.md`). Left untracked, per instruction.
2. Confirmed the two commits ahead of `origin/develop`:
   - `3a9b2c8` — fix(analysis): base the calibrated domain SE on the full
     sample size
   - `45bbeb6` — docs(changelog): add the entry for the calibrated domain SE
     fix
3. Pushed `fix/nonprob-domain-se-correction` to `origin`.
4. Opened PR #263 against `develop`:
   https://github.com/JDenn0514/surveycore/pull/263

## Not done in this dispatch (by design)

- No merge. No CI polling. Leader monitors CI and will instruct merge.
- No test suite, `devtools::check()`, `covr`, or `pkgdown` run — all seven
  gates already passed on tree `34b15df1bd90b6611df9c48bfb42dfa03eaa4e98`
  per `audit.md`.
- `NEWS.md` untouched.
- Neither commit amended.

## Status

PR open, CI not yet observed. Merge is pending a leader instruction.

## Merge record (2026-09-10)

- **Instruction:** Leader confirmed CI 7/7 passing, `mergeState=CLEAN`,
  `mergeable=MERGEABLE`, and instructed squash merge.
- **Command:** `gh pr merge 263 --squash --subject "fix(analysis): base the
  calibrated domain SE on the full sample size (#263)"` — no `--delete-branch`
  flag, per leader instruction (avoids the worktree-checkout failure on local
  cleanup).
- **Squash commit message:** `fix(analysis): base the calibrated domain SE on
  the full sample size (#263)`
- **Verification:** `gh pr view 263 --json state,mergeCommit` returned
  `state=MERGED`, `mergeCommit.oid=d2962332f6d9bbbcbc71f14c8092b508325e95fb`.
- **Merge commit SHA:** `d2962332f6d9bbbcbc71f14c8092b508325e95fb`
- **Remote branch delete:** run separately —
  `git push origin --delete fix/nonprob-domain-se-correction` — succeeded
  (`- [deleted] fix/nonprob-domain-se-correction`).
- **CI cycles:** one. `develop` did not move during review/ship, so no
  `update-branch` was required.

## Status

Merged. PR #263 closed as `MERGED`. Remote feature branch deleted. No local
`develop` checkout or pull performed in this worktree (per leader instruction
— `develop` is checked out in the main checkout).
