# Gate record — PR 1 `docs/oracle-rule-core`

**Branch**: `docs/oracle-rule-core` at `1879a34b06b9dc02969d407eb8e36e31726bea7d`
**Base**: `7800ea9730acdcf03ae33dc24bb9a008a8920e33`
**Tree**: `git rev-parse 'HEAD^{tree}'` — recorded below
**Run by**: the leader, not the tester. This machine has ~1.8 GB free and a
memory watchdog kills R gate processes; overlapping runs have corrupted whole
log sets here.

## The R gates are not re-run for this PR, and that is a measurement

`git diff --name-status 7800ea9 HEAD` lists exactly one path:

```
M	.claude/rules/testing-surveycore.md
```

Two facts make every R gate identical to the baseline:

1. **The file is not in the package.** `.Rbuildignore` carries the line
   `^\.claude$`, so `R CMD build` excludes the whole directory. Gates 4, 5 and
   6 cannot see the change.
2. **No test reads the file at run time.** `grep -rn "\.claude" tests/` returns
   four hits, in `test-constructors.R`, `test-glm-anova-numerical.R`,
   `test-metadata-system.R` and `test-validators.R`. Every one is a comment
   citing a rule. None opens a file. So `R/` and `tests/` are byte-identical to
   the baseline tree, and gates 1, 2, 3 and 7 would run identical code over
   identical inputs.

Re-running them would measure machine noise, not this PR. The baseline figures
below therefore stand as this PR's figures.

## Gate results

| Gate | Result | Source |
|---|---|---|
| `devtools::document()` | PASS — wrote nothing | baseline; `R/` and `man/` byte-identical |
| `devtools::test()` | PASS — `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11941 ]` | baseline; `tests/` byte-identical |
| `run_examples()` | PASS — all examples ran | baseline; no roxygen change |
| `R CMD build` | PASS | baseline; `.Rbuildignore` excludes `^\.claude$` |
| `R CMD check --as-cran --no-manual` | PASS — 2 NOTEs, both pre-existing | baseline; see `baseline.md` §The two NOTEs |
| pkgdown | SKIPPED — scope | no `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or `DESCRIPTION` change |
| `covr` | PASS — 96.15% | baseline; no source line added or removed |

Baseline logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/baseline/`

## Standing gates this PR still has to be measured against

These are not inferable from the baseline. The tester measures them on the
branch:

1. `git diff --name-only` lists one file and no third file.
2. `air format --check .claude/rules/testing-surveycore.md` passes.
3. `tests/testthat/test-conversion.R` is unchanged.
4. Nothing under `R/` changed; no roxygen changed.
