# Audit — PR 5 — as-svydesign-domain-docs

**Verdict**: PASS
**Date**: 2026-09-11

Tree: `677a9f3fadf6da9fab20b9bfb42d1c709124a236`

## Scope

This PR carries no lettered test-spec row: it is a documentation-only PR
(roxygen rewrite + changelog entry). The audit is built from the eight
acceptance criteria in the dispatch, one row each, plus the seven profile
gates and the CRAN cookbook scan.

## Per-Test Result Table

| Test | Got | Expected | Pass |
|---|---|---|---|
| 1. Nine domain-section items, in order | `man/as_svydesign.Rd` §"A filtered design's domain" (lines 75–132) states, in order: (1) active domain not full sample — line 77–78; (2) how a domain arrives via `filter()`, marker column named by `SURVEYCORE_DOMAIN_COL` = `"..surveycore_domain.."` — lines 80–84; (3) restriction applies whenever column present, never-filtered carries none, converts unrestricted — lines 83–84; (4) marker stays in data, internal marker not survey data, all-`TRUE` on row-removing routes, two-phase unchanged still marks `FALSE` — lines 86–90; (5) `NA` marker counts as outside domain — line 90; (6) empty-match filter still converts, no surveycore condition, per-route outcome (0/SE 0 Taylor & nonprob-no-repl; `survey` error at estimation on replicate & nonprob-repl; `NaN` two-phase) — lines 92–101; (7) two-phase weights out via infinite probability, row count unchanged, point estimate still differs from `get_means()` for the pre-existing phase-1-weight-vs-combined-probability reason, same gap on unfiltered (58.458/58.067, 48.9245/49.20304) — lines 103–112; (8) round-trip recovery per route: new total row count, original N unrecoverable, all-`TRUE` marker travels back → prints `Domain: n of n rows`, keep original for original N; two-phase exception recovers marker at both levels, prints two counts — lines 114–125; (9) `as_tbl_svy()` hands pre-restricted `tbl_svy` to `srvyr`; `srvyr::filter()` removes rows surveycore's `filter()` marked — lines 127–131. Grep for `subset(converted, ..surveycore_domain..)` and for "answers for every row"/"represents the full stored sample"/"full stored sample" across `R/methods-conversion.R` and `man/as_svydesign.Rd`: zero hits | Nine items present, in order; no leftover hand-subset instruction; no "answers for every row"/"full sample" claim | ✓ |
| 2. `\value` section names the section and states restriction | `man/as_svydesign.Rd` line 18–19: "A filtered input returns an object restricted to the active domain; the `A filtered design's domain` section below states what that means on each route." | Sentence present, names the section | ✓ |
| 3. `document()` idempotent; `man/` diff is `as_svydesign.Rd` only | Ran `Rscript -e 'devtools::document()'` once — output was the standard `srrstats` standards banner only, no file-write message. `git status --short` afterward: one modified (`plans/pr-budget-calibration.md`, pre-existing) + four untracked `plans/*.md` (pre-existing) — no other change. `git diff --stat origin/develop...HEAD -- man/` → `man/as_svydesign.Rd \| 73 +++...` only | No change beyond the five `plans/` files; `man/` diff names only `as_svydesign.Rd` | ✓ |
| 4. Changelog file format | `changelog/fix-as-svydesign-domain.md` exists. Header: `# Changelog: fix/as-svydesign-domain`, `**Branches:**` (documented alternative to `**Branch:**` for multi-branch entries per `changelog-workflow.md` line 70), `**PRs:**`, `**Issues:**`, `**Status:** Complete`, `**Date:** 2026-09-11`, `## Summary`, `## Files Modified`, `## Changes`, `## Verification`. First Summary sentence: "Closes #245. `as_svydesign()` now returns an object restricted to the active domain: a filtered design converts to the domain and not to the full stored sample." | Format matches `changelog-workflow.md`; first sentence names the return-value change | ✓ |
| 5. `NEWS.md`/`NAMESPACE`/`plans/error-messages.md` diff empty | `git diff origin/develop...HEAD -- NEWS.md NAMESPACE plans/error-messages.md` → empty output | Empty diff | ✓ |
| 6. `run_examples()` pass; pkgdown built the reference page | Taken from gate table (not re-run): `run_examples()` PASS. `logs/pr-5/gate-6-pkgdown.log` line 38: `Reading man/as_svydesign.Rd`, line 39: `Writing \`reference/as_svydesign.html\`` — no error between | Gate PASS; line 38 reads as specified, no error after | ✓ |
| 7. `R CMD check --as-cran`: 0 err/warn, two pre-approved NOTEs | Taken from gate table: `Status: 2 NOTEs` — CRAN incoming feasibility (pre-approved), hidden files `.git` (pre-existing) | 0 errors, 0 warnings, two pre-approved NOTEs only | ✓ |
| 8. Structural grep gate | `^\.restrict_to_domain <- function` → 1 hit (line 68), one argument (`converted`). `\.restrict_to_domain(converted)` call sites → 3 hits (lines 315, 482, 528). `grep -rn "restrict_to_domain" R/` → all 4 hits in `R/methods-conversion.R` only. `r & !is.na(r)` → 1 hit (line 80). `SURVEYCORE_DOMAIN_COL %in% names(frame)` → 1 hit (line 75). `inherits(converted, "twophase2")` → 1 hit (line 69). `git diff --stat origin/develop...HEAD` → exactly 3 files: `R/methods-conversion.R`, `changelog/fix-as-svydesign-domain.md`, `man/as_svydesign.Rd`; nothing under `tests/`. Roxygen-only check (`git diff -U0 ... -- R/ \| grep added/removed lines \| exclude \`#'\` lines`) → empty output | Exact counts as specified; 3-file diff; `R/` diff is `#'`-only | ✓ |

**Additional checks** (not a numbered criterion but required by dispatch):
grep of added `#'` lines in the `R/` diff for `.restrict_to_domain`, `@data`,
`@variables`, `#[0-9]+` → zero hits. The new roxygen text names no internal
helper, shows no `@` property access, and cites no issue number.

## Before/After Comparison

| Metric | Before PR (`develop` @ `d5dcca4`) | After PR (tree `677a9f3`) | Δ |
|---|---|---|---|
| tests passing | 11800 | 11800 | 0 |
| failures | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.25% | 96.25% | 0 |
| R CMD check NOTEs | 2 | 2 | 0 |

No regression. This PR adds no test and edits none — the `tests/` diff is
empty — so the test-passing count and coverage are unchanged by
construction, and the numbers above confirm rather than merely assume that.

## Profile gates

Gates were run by the orchestrator (full runner, all seven gates, one call)
on tree `677a9f3`. This audit accepts the printed summary and reruns nothing
except `devtools::document()`, the one R call the dispatch permits.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | document() wrote nothing |
| devtools::test() | PASS | [ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11800 ] |
| run_examples() | PASS | all examples ran |
| R CMD build | PASS | ./surveycore_1.1.0.9000.tar.gz |
| R CMD check --as-cran | PASS | Status: 2 NOTEs — CRAN incoming feasibility (pre-approved); hidden files `.git` (pre-existing) |
| pkgdown | PASS | site built (run, not skipped: write surface touches R/); log line 38 reads `Reading man/as_svydesign.Rd`, line 39 `Writing reference/as_svydesign.html`, no error between |
| covr | PASS | 96.25% |

Tree: `677a9f3fadf6da9fab20b9bfb42d1c709124a236`

Logs: `.surveycore-workspace/runs/2026-09-09-as-svydesign-domain/logs/pr-5/`
— only `gate-6-pkgdown.log` line 38–39 read, per criterion 6; no other log
read since no gate failed.

Covr note (as supplied): the runner's "changed R/ files: 2" line is the
stale-local-`develop` misreport; against `origin/develop` one `R/` file
changed and only its roxygen. Its one uncovered line (630) is a pre-existing
`# nocov` branch. Coverage 96.25%, unchanged.

## CRAN cookbook violations

None. `R/` diff against `origin/develop` is roxygen-comment-only (confirmed
above), so no executable-code cookbook pattern can appear in it. Scanned the
diff anyway for `T`/`F` abbreviation, `set.seed()`, bare `print()`/`cat()`,
`options(warn=-1)`, `installed.packages()`, `<<-`, unrestored
`par()`/`setwd()`, `mc.cores`/`makeCluster` — zero hits.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | None | — |

## Tolerance integrity

No numeric comparison in this PR — it adds no test. Nothing to relax or
hold.

## Git hygiene

`git status` before and after this audit shows one modified and four
untracked files under `plans/`, all pre-existing per the dispatch. Nothing
staged, committed, reverted, or edited under `plans/`. No `git add`, `git
stash`, or `git checkout` run. Only `audit.md` written. One R process run
(`devtools::document()`), per the dispatch's one-R-call allowance.

## Verdict

**PASS.** All eight acceptance-criteria rows verified directly against
`man/as_svydesign.Rd`, `R/methods-conversion.R`, `changelog/fix-as-svydesign-domain.md`,
and the git diff against `origin/develop`. `document()` is idempotent on
this tree and touches no file beyond the pre-existing `plans/` changes. The
`R/` diff is roxygen-comment-only; the `man/`, changelog, and full-repo diffs
match the claimed scope exactly (3 files, no `tests/`). All seven profile
gates pass (gate table supplied by the orchestrator, accepted per dispatch).
No CRAN cookbook violation. No before/after regression — this PR adds no
test and edits none, so passing/coverage figures are unchanged by
construction and confirmed unchanged in measurement.
