# Ship — PR 5 — fix/svydesign-replicate-fay

**Branch**: fix/svydesign-replicate-fay
**PR URL**: https://github.com/JDenn0514/surveycore/pull/250
**Merged**: 2026-09-09 01:29 UTC
**Merge commit**: 4440de120969fea08431f02208a5d06e583da336

## Timeline
- branch already existed (builder/tester/reviewer worked in-place), pushed to origin
- PR opened against develop
- CI green — all seven checks (codecov/patch, macos-latest release, pkgdown,
  test-coverage, ubuntu-latest devel, ubuntu-latest release, windows-latest
  release) passing; mergeStateStatus CLEAN, mergeable MERGEABLE
- squash merged

## CI gates
- codecov/patch: PASS
- macos-latest (release): PASS (7m48s)
- pkgdown: PASS (3m11s)
- test-coverage: PASS (6m51s)
- ubuntu-latest (devel): PASS (8m5s)
- ubuntu-latest (release): PASS (6m17s)
- windows-latest (release): PASS (9m55s)

## Post-merge
- [x] Plan checkbox marked — `archive/svydesign-replicate-bridge/implementation-plan-svydesign-replicate-bridge.md`
      PR 5 line now `[x]`; all five PR checkboxes in the file read `[x]`
- [x] Branch deleted (remote) — `git push origin --delete fix/svydesign-replicate-fay`
      Local branch left in place per coordinator instruction (linked worktree;
      `develop` held by a sibling worktree, so `git checkout develop` and
      `--delete-branch`'s local switch fail here by design)

## Notes
- This is PR 5 of 5. `spec.md`'s twelve observable properties and thirteen
  quality gates all close as of this merge (review.md §11).
- closes #198. #197 left open deliberately (its substance shipped in PRs 1-3).
