# Ship — PR 6 — test/replicate-oracle-bootstrap

**Branch**: test/replicate-oracle-bootstrap
**PR URL**: https://github.com/JDenn0514/surveycore/pull/286
**PR number**: 286
**Merged**: 2026-09-22 22:45:09 UTC
**Merge commit**: f1270827867c7712ba14159aa5660158e43864ac
**Squash tree**: a8455700b9ae18c642daad8c5911799eb020ce4d
**Base at merge**: bbafed090cb93a63915dd5704d1f361228e2032d
**Head commit**: e4d8657f0df9cf7ffc340dfb28346fc3de5019b7
**Title**: test(variance): add the bootstrap oracle block, pinned against issue #253 (#286)
**Diff**: 1 file, tests/testthat/test-variance-replicate.R, +81 / -0

## Tree check

The squash commit's tree equals the audited tree. `git rev-parse
'f127082^{tree}'` returns `a8455700b9ae18c642daad8c5911799eb020ce4d`, the same
tree `review.md` and `audit.md` record and the same as `HEAD^{tree}` on the
branch before the push. The squash of one append-only commit onto an unmoved
base preserves the tree, so the merged code is byte-for-byte the audited code
and the skipped pre-PR gate pass stands. `git diff --numstat f127082~1
f127082` confirms the merged delta on `develop`: `81 0
tests/testthat/test-variance-replicate.R`.

## Timeline

- branch and commit existed before this agent ran (e4d8657, one commit)
- 22:30 `git fetch origin develop` re-read origin/develop, still at bbafed0,
  1 ahead / 0 behind, so `gh pr update-branch` was not needed
- 22:31 pushed to origin
- 22:32 PR 286 opened against develop
- 22:33 first check read: BLOCKED, checks not yet reported
- 22:44 CI green, merge state CLEAN (coordinator watched CI; this agent did not
  poll)
- 22:45 squash merged

## CI gates

All seven required checks passed. No re-run, no flake.

| Check | Result | Time |
|---|---|---|
| ubuntu-latest (devel) | PASS | 7m28s |
| ubuntu-latest (release) | PASS | 7m29s |
| macos-latest (release) | PASS | 4m53s |
| windows-latest (release) | PASS | 9m38s |
| pkgdown | PASS | 3m27s |
| test-coverage | PASS | 5m58s |
| codecov/patch | PASS | 0s |

Local gates on the same tree: `document()` wrote nothing; `devtools::test()`
gave `FAIL 0 | WARN 256 | SKIP 4 | PASS 11996`, which is +7 over PR 5's 11989
and the same delta the JKn block produced; `run_examples()`, `R CMD build` and
`R CMD check --as-cran` passed with the two pre-existing NOTEs; pkgdown skipped
for scope, NAMESPACE diff empty; `covr` 96.15%, flat.

Failures stay at 0 even though six assertions in the file now fail by design,
because each is consumed by its own `expect_failure()` wrapper and the wrapper
is what passes.

## Note for the arc

**This PR completed the pinned pair, and its shape was verified by three
independent instruments** — a `utils::getParseData()` parse plus AST walk, an
awk comment-stripper plus paren-depth walker, and a character-level R lexer —
because a malformed `expect_failure()` wrapper produces a green suite that no
gate can catch. All three agreed: 3 wrappers per block, 1 assertion each, 1
unwrapped ratio assertion each, and all 6 wrappers in the file confined to the
two pinned blocks.

Two facts a later reader needs:

- **Counting this file textually gives the wrong answer.**
  `grep -c "expect_failure"` returns 12 against 6 real calls, because both
  pinned blocks discuss their own wrappers in comments. Parse or strip comments
  before auditing these counts.
- **The bootstrap and JKn blocks differ from `survey` by the same scale
  factor.** surveycore stores `1/R` for bootstrap where `survey` stores
  `1/(R-1)`, so surveycore's SE is low by `sqrt((R-1)/R)` — the 2.53% the JKn
  block also carries. The ratio assertion's residual is bit-identical to the
  JKn block's at `9.459100169806334e-14`; that is structural, not a copied
  constant, because both blocks use seed 15. Issue #253 corrects both defaults
  and deletes four lines from each block.

CI exercised the wrappers on all four `R CMD check` platforms for the second
time. A platform carrying a `survey` with a different bootstrap default would
have turned the block red rather than green. None did. PRs 7 to 9 add `other`,
Fay, and the rule's exceptions section.

## Post-merge

- [x] Squash merged, no `--delete-branch` (worktree: develop is checked out at
      C:\Users\jdennen\surveycore, so the combined command dies in local cleanup)
- [x] Merge confirmed by `gh pr view 286 --json state,mergeCommit`, not by exit
      code: `state` reads `MERGED`
- [x] Remote branch deleted — `git push origin --delete` reported `[deleted]`
- [x] Local branch deleted — `git branch -D` reported `was e4d8657`
- [x] Worktree detached onto origin/develop at f127082, not `git checkout develop`
- [x] Plan checkbox marked in both copies, line 548, with the Edit tool; `cmp`
      reports them identical. Three PR boxes remain unchecked, matching the
      three PRs that follow
- [x] The six `plans/` bookkeeping files left untouched, unstaged, uncommitted,
      apart from the one checkbox the coordinator asked for
