# Ship — PR 4 — svydesign-replicate-fpc

**Branch**: fix/svydesign-replicate-fpc
**PR URL**: https://github.com/JDenn0514/surveycore/pull/249
**Merged**: 2026-09-08 22:58 UTC
**Merge commit**: 8c99271880c68e5da300985c4e935a2c23ae134d

## Timeline
- pre-existing (built before ship): branch created, commit 5b27b9b written
- 2026-09-08 pushed to origin
- 2026-09-08 PR #249 opened against develop
- 2026-09-08 CI green (all 7 checks pass)
- 2026-09-08 22:58 UTC merged (squash)

## CI gates
- codecov/patch: PASS
- macos-latest (release): PASS (6m28s)
- pkgdown: PASS (3m17s)
- test-coverage: PASS (6m26s)
- ubuntu-latest (devel): PASS (7m33s)
- ubuntu-latest (release): PASS (7m3s)
- windows-latest (release): PASS (9m40s)

## Post-merge
- [x] Plan checkbox marked (`archive/svydesign-replicate-bridge/implementation-plan-svydesign-replicate-bridge.md`, PR 4)
- [x] Branch deleted (remote via `git push origin --delete`; `--delete-branch`'s
      local step failed because `develop` is checked out in a sibling worktree
      at `C:/Users/jdennen/surveycore` — server-side merge and remote branch
      delete both completed regardless; local branch left for the coordinator)

## Notes
- Review verdict confirmed PASS before shipping (`review.md`, tree
  `b0f56dc938d7552b74206c78dcfb6485852fc250`).
- `gh pr merge 249 --squash --delete-branch` errored on the local
  worktree-conflict step (`'develop' is already used by worktree`); confirmed
  via `gh pr view 249 --json state,mergedAt,mergeCommit` that the server-side
  squash merge had already succeeded before that error.
