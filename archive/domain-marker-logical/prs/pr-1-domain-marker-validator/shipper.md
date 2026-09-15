# Ship — PR 1 — domain-marker-validator

**Archive note.** Citations of `plans/{spec,test-spec,decisions,
implementation-plan}-domain-marker-logical.md` below no longer resolve:
`archive-plans.md` step 3 moved those files into this directory at archive
time. They sit beside this file under the same basenames. The
`[no such file]` marker is the citation checker's vocabulary for a path that
no longer resolves, not a statement that anything was lost.

**Branch**: fix/domain-marker-validator
**PR URL**: https://github.com/JDenn0514/surveycore/pull/272
**Merged**: 2026-09-14
**Merge commit**: 5b05a8c775f2896bd83bc1b1a38cd85cd6ffbdc3

## Timeline
- branch existed already (builder-created, seven commits, tree e88e6e7)
- pushed to origin
- PR #272 opened against develop
- CI green on all required checks
- merged via `gh pr merge --squash`

## CI gates
- ubuntu-latest (release) [required]: PASS
- ubuntu-latest (devel): PASS
- windows-latest (release): PASS
- macos-latest (release): PASS
- pkgdown: PASS
- test-coverage: PASS
- codecov/patch: FAIL — not a required check. Cause settled: covr cannot
  attribute execution inside an S7 `validator =` closure, so the new
  validator body reads as 0% even though every test that exercises it
  passes (see review.md note 2, which proves the same blind spot on a
  pre-existing line, 709, outside this PR's diff). User approved merging
  with this check red.

## Post-merge
- [x] Plan checkbox marked — `plans/implementation-plan-domain-marker-logical.md` [no such file]
      line 131, PR 1, marked `[x]` (file left untracked, not committed)
- [x] Branch deleted (local + remote)
  - `gh pr merge 272 --squash --delete-branch` half-failed on local cleanup:
    `fatal: 'develop' is already used by worktree at 'C:/Users/jdennen/surveycore'`
    (this session runs in a worktree; develop is checked out elsewhere)
  - Merge itself landed; confirmed via `gh pr view 272 --json state` → `MERGED`
  - Remote branch deleted manually: `git push origin --delete fix/domain-marker-validator`
  - No local `fix/domain-marker-validator` branch existed in this worktree to delete
  - `git checkout develop` was not run in this worktree (checked out elsewhere);
    tip confirmed instead via `git fetch origin develop` → `8fe3fa2..5b05a8c`
