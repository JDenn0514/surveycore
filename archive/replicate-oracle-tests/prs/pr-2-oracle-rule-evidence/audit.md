# Audit — PR 2 — oracle-rule-evidence

**Verdict**: PASS
**Date**: 2026-09-22 00:00

Branch `docs/oracle-rule-evidence` at `c4c23f20c3c056add324eaa8fecdf6611b5aba42`.
Base `70bfe5495c1362284d13d3a56ec07c12e6ea1eff`. Diff read commit-to-commit
(`git diff 70bfe54 HEAD`), so the six untracked/modified `plans/` bookkeeping
files are out of scope.

Rows allocated to this PR: §6 rows 6.7, 6.9, 6.12, 6.13, 6.14, 6.17. Tally:
**6 of 6 pass.**

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 6.7 — rule covers the replicate constructor, not the non-probability one | Delivered §What the rule covers: "It does not cover `as_survey_nonprob()`: `survey` has no non-probability design class, so it cannot be an oracle for one (`plans/issue-cleanup.md` D1)." The covered side is stated at two sites: "The rule covers tests that prove surveycore's variance correct by an independent comparison against `survey`." and, in the carried-forward scope paragraph, "Rules 2 and 3 and the per-type table below name arguments of `survey::svrepdesign()`, so they reach replicate designs only." | both halves stated, with the reason | exact text | ✓ |
| 6.9 — per-type table present, matches test-spec §7 | Table at `.claude/rules/testing-surveycore.md` lines 245–257. **9 data rows**: BRR, Fay, JK1, JK2, JKn, bootstrap, ACS, successive-difference, other. Version named in the lead-in: "measured on `survey` 4.5 under R 4.6.1". All 27 cells of `Default scale` / `A supplied scale` / `A supplied rscales` are character-identical to §7. §7's fifth column, `Condition on a bare call`, is not carried — see Notes. | present, matches §7 on what `survey` does with a supplied `scale` and `rscales` | exact text | ✓ |
| 6.12 — the conversion carve-out names the two blocks and keeps them | Delivered: "It does not cover a round-trip test." Both blocks named — "`as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]`" and "`from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]`" — followed by "Both are correct and both stay." Also gives the discriminator: "an oracle test asks \"is surveycore's number right\", a round-trip test asks \"did the conversion carry the number across\"." | present, both blocks named, both kept | exact text | ✓ |
| 6.13 — the table is a snapshot of `survey` 4.5; probe before writing a block | Delivered: "**The per-type table is a snapshot.** It records `survey` 4.5. Before you write a new block, build a probe design on your installed version and read back what it does with a supplied `scale` and `rscales` for your type." | present | exact text | ✓ |
| 6.14 — check the `survey` version before calling a red block a regression | Delivered: "**Read a failure against the `survey` version first.** When an oracle block turns red, check the installed `survey` version against the one the table records before you treat the failure as a surveycore regression. A changed default on the oracle side moves the target and produces the same red." | present | exact text | ✓ |
| 6.17 — `tests/testthat/test-conversion.R` unchanged; both named titles exist | `git diff --name-only 70bfe54 HEAD -- tests/testthat/test-conversion.R` → 0 lines. Blob identical: `git rev-parse 70bfe54:… HEAD:…` both `b3a1251fe6e349d88a566698ba0a1947032b42f4`. Titles matched with `grep -F` on the full `test_that("…", {` string: line 239 and line 567, both EXACT. | 0 changes, both titles present | byte-exact | ✓ |

### Title check, character by character

Matched by fixed-string search on the whole `test_that()` opener, not by gist:

- `test_that("as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]", {` — `tests/testthat/test-conversion.R:239`, EXACT.
- `test_that("from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]", {` — `tests/testthat/test-conversion.R:567`, EXACT.

The delivered file wraps both titles across two lines inside a bullet; the
unwrapped strings are identical to the file. Note the near neighbour at line 538
is the **Taylor** round trip, which the carve-out does not name and must not.

## Branch measurements taken by the tester

| # | Check | Result |
|---|---|---|
| 1 | `git diff --name-only 70bfe54 HEAD` | one entry: `.claude/rules/testing-surveycore.md`. No second or third file. `--stat`: 1 file changed, 54 insertions, 0 deletions. |
| 2 | `air format --check .claude/rules/testing-surveycore.md` | exit 0, no output. `air` is a CLI here; the gate reads as "the file this PR touches passes". |
| 3 | `tests/testthat/test-conversion.R` unchanged | confirmed by blob hash, see row 6.17. |
| 4 | Nothing under `R/`, no roxygen change | `git diff --name-only 70bfe54 HEAD -- R/ man/ NAMESPACE DESCRIPTION vignettes/` → 0 lines. |
| 5 | `git diff --check` (whitespace errors) | clean, exit 0. |
| 6 | Line length of added lines | longest added line is 78 characters; the 80-character limit holds. |
| 7 | Cross-reference in the added text | `plans/issue-cleanup.md` exists and carries "### D1 — Oracle scope: `as_survey_replicate()` only" at line 73, so the citation resolves. |

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11941 (`FAIL 0 \| WARN 256 \| SKIP 4`) | 11941 — carried, `tests` subtree byte-identical | 0 |
| coverage | 96.15% | 96.15% — carried, `R` and `tests` subtrees byte-identical | 0 |
| R CMD check notes | 2 | 2 — carried | 0 |

## Profile gates

Not run by the tester, by dispatch instruction: this host holds about 2.2 GB
free and a memory watchdog kills R gate processes. The results below are copied
from `gates.md` (run by the leader) and `baseline.md`, tree
`e9a6c808f228388175b1b6892e7372d39e3e2fb8`.

The carry-forward rests on a measurement the tester re-checked: the only
differing path is `.claude/rules/testing-surveycore.md`, the `R`, `tests`,
`man`, `NAMESPACE` and `DESCRIPTION` subtrees are byte-identical base to head,
and `.Rbuildignore` carries `^\.claude$`, so `R CMD build` excludes the changed
file from the tarball and no test opens it at run time.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; no roxygen in the diff |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11941 ]` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran --no-manual` | PASS | 2 NOTEs: `checking CRAN incoming feasibility` (pre-approved) and `checking for hidden files and directories` (pre-existing, `.git`, not on the pre-approved list, present on the clean baseline tree — read gate 5 as "2 NOTEs, and these two") |
| pkgdown | SKIPPED — scope | `NAMESPACE` diff empty, so the hard rule does not bite; the diff touches no `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or `DESCRIPTION` |
| `covr` | PASS | 96.15%, above the 95% floor, flat |
| CRAN cookbook scan | PASS | no `.R` file in the write surface |

Baseline logs: `.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/baseline/`

No gate could move on this tree. I name no gate for a re-run.

Tree: 51b1aee208097c6452bc58d86f750c0a0c7011bb

## CRAN cookbook violations

None. The write surface is one Markdown file; no `.R` file changed.

## Notes — not BLOCKs

1. **Row 6.9, the fifth column.** The test-spec §7 table carries five columns;
   the delivered table carries four. `Condition on a bare call` is absent. Row
   6.9 defines the table it asks for as "the per-type table of what `survey`
   does with a supplied `scale` and `rscales`", and every cell inside that scope
   matches §7 exactly, so the row passes on its own terms. The conditions
   material lives in rule 5 and in §3.1's per-block fragments, so nothing in the
   rule text points at the missing column. Flagged for the reviewer, who holds
   the spec and can say whether the fifth column was required.
2. **No table cell probed.** I ran no `Rscript` probe. All 27 in-scope cells are
   character-identical to test-spec §7, which is the reference the row names, so
   a probe would have measured the oracle a second time and told me nothing
   about this PR. I report no cell I believe wrong.
3. **`tests/testthat/test-variance-replicate.R` still breaches the rule** — the
   JK1 block passes `scale`, and the JK1 and JK2 blocks wrap the `survey` call
   in `suppressWarnings()`. Outside this PR's write surface; PR 4 closes both.
   Not counted against this PR.
4. **Rows 6.10 and 6.15 are absent by design** (PR 9, the sanctioned-exceptions
   subsection). The text added here introduces no expectation total and no run
   time, so it does not pre-empt 6.10.
5. **The file uses CRLF line terminators.** Pre-existing for the whole file, not
   introduced by this diff.

## BLOCKs

None.
