# Shipper — PR 3 — test/domain-marker-type-breadth

**Archive note.** Citations of `plans/{spec,test-spec,decisions,
implementation-plan}-domain-marker-logical.md` below no longer resolve:
`archive-plans.md` step 3 moved those files into this directory at archive
time. They sit beside this file under the same basenames. The
`[no such file]` marker is the citation checker's vocabulary for a path that
no longer resolves, not a statement that anything was lost.

**PR**: #274 — https://github.com/JDenn0514/surveycore/pull/274
**Base**: `develop`
**Merge strategy**: squash
**Merge commit SHA**: `8664d86f6e0f5d302d1db7a2baf4be663e380fa1`
**Commit message**: `test(classes): complete the domain marker validator's type and shape coverage (#274)`

## CI outcome

All seven checks green at merge time:

| Check | Result |
|---|---|
| codecov/patch | pass |
| macos-latest (release) | pass |
| pkgdown | pass |
| test-coverage | pass |
| ubuntu-latest (devel) | pass |
| ubuntu-latest (release) | pass |
| windows-latest (release) | pass |

Confirmed via `gh pr checks 274` immediately before merge, then
`gh pr view 274 --json state,mergeCommit,url` returned `MERGED` with the
SHA above.

## Branch deletion

`gh pr merge 274 --squash --delete-branch` half-failed as expected: the
squash merge succeeded but local branch cleanup died with
`fatal: 'develop' is already used by worktree at 'C:/Users/jdennen/surveycore'`,
because `develop` is checked out in another worktree. The remote branch
survived this failure (`git ls-remote --heads origin
test/domain-marker-type-breadth` still listed it after the merge).

Ran manually:

```
git push origin --delete test/domain-marker-type-breadth
```

Confirmed removal with a second `git ls-remote --heads origin
test/domain-marker-type-breadth`, which returned nothing.

## Plan update

Marked PR 3's checkbox `[x]` in
`plans/implementation-plan-domain-marker-logical.md` [no such file], line 304. The file
stays untracked (git status confirms it, per instruction) and was not
committed.

## Notes

- `develop` was not checked out in this worktree, per instruction — the
  merge and branch deletion were done entirely through `gh` and
  `git push --delete`, no `git checkout develop` was run here.
- No R command was run.
