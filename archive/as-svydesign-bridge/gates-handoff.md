# Profile gate results — PR 1, as-svydesign-bridge

The orchestrator ran every gate. Do not re-run any of them. This machine
kills concurrent and memory-hungry R processes; see §Why you run no gate.

**Branch**: `fix/as-svydesign-bridge`
**HEAD**: `e45aee204814f37cd832a178a79f7c82424fdebb`
**Tree**: `424da65a0e7df17d4e9ea4d45a2a58197feb196d`
**Runner**: `bash .claude/scripts/run-gates.sh` — one call, all seven gates
**Log directory**: `.surveycore-workspace/runs/2026-09-08-as-svydesign-bridge/logs`
**Script exit**: 0. `ALL GATES PASS`.

## Gate summary, copied verbatim

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | no NAMESPACE/man drift |
| devtools::test() | PASS | [ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11595 ] |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | ./surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran | PASS | Status: 2 NOTEs |
| pkgdown | PASS | site built |
| covr | PASS | 96.24%; changed R/ files: 1, uncovered lines in them: 1 |

Per-gate logs: `logs/gate-1-document.log` through `logs/gate-7-covr.log`.

## Before column — the dispatch baseline

Measured on `40700e3`, which is `origin/develop` and this branch's base.

| Gate | Before | After |
|---|---|---|
| `devtools::test()` | FAIL 0, WARN 256, SKIP 4, PASS 11538 | FAIL 0, WARN 256, SKIP 4, PASS 11595 |
| `R CMD check` | 0 errors, 0 warnings, 1 note | 0 errors, 0 warnings, 2 notes |
| coverage | **not measured** | 96.24% |

Three things about that table, so you do not read any of them as a regression.

1. **PASS rose by 57 and WARN did not move.** The 256 warnings are
   pre-existing AAPOR small-cell warnings on `develop`. Archived decision D12
   records that a "0 warnings" gate is unmeetable here, so the gate reads as
   "no NEW warning". The count is identical Before and After, so no new
   warning arrived.

2. **The note count went 1 to 2, and neither note is new.** The Before run
   used `devtools::check()` on the source directory; the After run used
   `R CMD build` then `R CMD check --as-cran` on the tarball, so the two runs
   do not report an identical note set by construction. The two After notes:

   - `checking CRAN incoming feasibility` — pre-approved in
     `.claude/rules/r-package-conventions.md`.
   - `checking for hidden files and directories`, naming `.git` — **also
     present in the Before run.** `.Rbuildignore` carries `^\.github$` and no
     `^\.git$` entry, so `R CMD build` packs the worktree's `.git` file. It is
     a pre-existing repository defect, it is outside this PR's write surface,
     and this PR neither caused it nor can fix it. Do not BLOCK on it. It is
     not on the pre-approved list, so the rule as written allows two notes and
     this run has two — one pre-approved, one pre-existing and environmental.

3. **Coverage has no Before figure.** Both baseline attempts were killed by
   the low-memory watchdog at 2.06 GB free. The last measured package figure
   is 96.0938% on `develop` at `e7493f0`, from
   `.claude/rules/testing-surveycore.md` — a reference four commits old, not a
   baseline. The After figure, 96.24%, is above the 95% floor in
   `.claude/rules/testing-standards.md`, which is the gate that decides this
   PR. Judge the floor, not the delta: no trustworthy delta exists.

## The one uncovered line in a changed file

`covr` reports `R/methods-conversion.R` at 99.76% with one uncovered line,
`R/methods-conversion.R:525`. Read before judging it: line 525 is the
`return(NULL)` early exit of `.find_col_by_value()`, a pre-existing helper
that already carries a `# nocov` comment reading
"callers always pass non-NULL". It sits outside this PR's three diff hunks,
which cover roughly lines 30-104, 133-174 and 434-441. No line this PR added
is uncovered.

## Why you run no gate

This machine held 2.06 GB free of 14.67 GB during this run, and three other
git worktrees are live with other sessions' R processes in them. In the
previous pipeline run seven background gate processes were killed for low
memory, and two testers each started a second `run-gates.sh` while the first
was inside `R CMD check`, whose `R CMD build` deleted the `.Rcheck` tree the
first was checking and corrupted the whole log set.

So: run no gate from the table above. `R CMD check`, `devtools::check()`,
`covr::package_coverage()`, `pkgdown::build_site()`, `devtools::run_examples()`
and an unfiltered `devtools::test()` are all forbidden to you.

You MAY run filtered test commands for row-by-row verification, for example
`Rscript -e 'devtools::test(filter = "conversion")'`. Constraints: one R
process at a time, foreground only, never with `&`, never with
`run_in_background`, and never two at once. Redirect output to a log and read
the tail.

If a scenario cannot be verified without a forbidden gate, say so in
`audit.md` and cite the gate log above instead. Do not emit BLOCK because you
were not permitted to re-run a gate that already passed.
