# Ship — PR 5 — test/replicate-oracle-jkn

**Branch**: test/replicate-oracle-jkn
**PR URL**: https://github.com/JDenn0514/surveycore/pull/285
**PR number**: 285
**Merged**: 2026-09-22 21:36 UTC
**Merge commit**: bbafed090cb93a63915dd5704d1f361228e2032d
**Squash tree**: ba47cff369806d0c550db3d9ecb8f05e7f3600c1
**Base at merge**: d0de848d506feb186636898fa7726efdc8337a22
**Head commit**: 0e3127ea6b5ab5c184e6a42a4bfcf131f08f67d1
**Title**: test(variance): add the JKn oracle block, pinned against issue #253 (#285)
**Diff**: 1 file, tests/testthat/test-variance-replicate.R, +84 / -0

## Tree check

The squash commit's tree equals the audited tree. `git rev-parse
'bbafed0^{tree}'` returns `ba47cff369806d0c550db3d9ecb8f05e7f3600c1`, the same
tree `review.md` and `audit.md` record and the same as `HEAD^{tree}` on the
branch before the push. The squash of one append-only commit onto an unmoved
base preserves the tree, so the merged code is byte-for-byte the audited code
and the skipped pre-PR gate pass stands.

## Timeline

- branch and commit existed before this agent ran (0e3127e, one commit)
- 21:12 pushed to origin
- 21:13 PR 285 opened against develop
- 21:14 first check read: BLOCKED, checks not yet reported
- 21:35 CI green, merge state CLEAN (coordinator watched CI; this agent did not poll)
- 21:36 squash merged

## CI gates

All seven required checks passed. No re-run, no flake.

| Check | Result | Time |
|---|---|---|
| ubuntu-latest (devel) | PASS | 8m6s |
| ubuntu-latest (release) | PASS | 7m0s |
| macos-latest (release) | PASS | 5m12s |
| windows-latest (release) | PASS | 11m34s |
| pkgdown | PASS | 3m27s |
| test-coverage | PASS | 5m56s |
| codecov/patch | PASS | 1s |

Local gates on the same tree, from `logs/pr5/`: `document()` wrote nothing;
`devtools::test()` gave `FAIL 0 | WARN 256 | SKIP 4 | PASS 11989`;
`run_examples()`, `R CMD build` and `R CMD check --as-cran` passed with the two
pre-existing NOTEs; pkgdown skipped for scope; `covr` 96.15%, flat.

## Note for the arc

This is the first PR whose CI exercised `expect_failure()` wrappers, and they
held on all four `R CMD check` platforms. A wrapper passes only while its
assertion fails, so a platform carrying a `survey` with a different JKn default
would have turned the block red rather than green. None did. PRs 6 to 8 add
bootstrap, `other` and Fay under the same Block 24 header.

## Post-merge

- [x] Squash merged, no `--delete-branch` (worktree: develop is checked out at
      C:\Users\jdennen\surveycore, so the combined command dies in local cleanup)
- [x] Remote branch deleted — `git push origin --delete` reported `[deleted]`
- [x] Local branch deleted — `git branch -D` reported `was 0e3127e`
- [x] Worktree detached onto origin/develop at bbafed0, not `git checkout develop`
- [x] Plan checkbox marked in both copies, line 481; `cmp` reports them identical
- [x] The six `plans/` bookkeeping files left untouched, unstaged, uncommitted
