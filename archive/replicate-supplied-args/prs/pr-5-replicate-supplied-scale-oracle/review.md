# Review — PR 5 — replicate-supplied-scale-oracle

> Archive note: the spec, test-spec, decisions and implementation-plan documents for this request moved from plans/ into this directory at archive time (2026-10-14). Each citation of their plans/ path is marked [no such file].

**Verdict**: PASS
**Date**: 2026-10-13 11:39

Branch `test/replicate-supplied-scale-oracle`, HEAD `4d4bf23`, tree `117bc78`
(`git rev-parse 'HEAD^{tree}'` equals the audit's tree line). Diff against
`origin/develop` `2c46f62`. No comprehension.md exists, so Step 6 does not
apply.

## Convergence checks

- Spec coverage: y. PR 5 is a test-only PR. It carries spec §IV "Numerical
  property" for a design built with an explicit `scale` (row 7.1), and the
  §III discard behaviour seen through an independent `survey` oracle (rows
  6.1 to 6.9).
  - All 10 budget rows (6.1 to 6.9, 7.1) and criteria 1 to 5 have rows in
    the audit table.
  - The nine block titles equal the plan's task 2 titles, 9 of 9 by parse.
    The 7.1 title equals task 3. No title carries a row id.
  - The per-type scale literals in the blocks equal the plan's F1 table
    (`19 / 20` aside, which is a ratio literal only) and the F2 list in
    task 3: 0.6 for the four kept types; `1 / 20`, `1 / (20 * (1 - 0.3)^2)`,
    `1`, `4 / 20`, `4 / 20` on F1; `1 / 5`, `1 / (5 * (1 - 0.3)^2)`, `1`,
    `4 / 5`, `4 / 5` on F2.
  - Conditions match the plan tables. surveycore: the class-typed warning
    for BRR, JK2, ACS and successive-difference; `expect_no_warning()` for
    the other five. `survey`: `capture_warnings()` then `expect_length(w,
    1L)` then `expect_match(..., fixed = TRUE)` for BRR, JK2, ACS,
    successive-difference and `other`; `expect_no_warning()` for JK1, JKn,
    bootstrap and Fay. Every text is the plan's text character for
    character. Two texts are split with `paste()` over two literals; the
    joined strings are the plan's.
- Test coverage of spec: y for this PR's scope. §IV "Numerical property"
  says "with or without an explicit `scale`". Row 7.1 covers "with". The
  "without" half is carried by rows 7.3 and T11, which shipped in PRs 1 and
  4. §IV "Conditions" (JK2 and `other` warn on export, ACS and
  successive-difference do not) is asserted per type in 7.1.
- Tolerance integrity: y. A parse of the 10 new blocks (`parse()` and a
  call walk, not `grep`) finds 61 `expect_equal()` call sites. Every one
  names `tolerance =`. The values are 1e-10 on the mean, 1e-8 on the SE,
  each stored scale and each SE ratio, and 1e-6 on each bound. These are
  the test-spec §11 values. None uses the testthat default. The audit
  reports the same values on every row. No row is looser or tighter.
- Scope discipline: y. `git diff --name-only origin/develop...HEAD` lists
  the two Files touched plus `plans/implementation-plan-replicate-supplied-args.md` [no such file]
  and `plans/pr-budget-calibration.md`, from leader commit `0e4da06`, which
  G9 allows. No `.surveycore-workspace/` path. `git rev-parse HEAD:R` equals
  `origin/develop:R` (`5d2ff11`). The diff removes no test line, so no
  existing block changed.
- Regression safety: y. Full suite `FAIL 0 | WARN 256 | SKIP 4 | PASS 12712`
  against 12580 after PR 4. The +132 equals 85 expectations in the nine
  oracle blocks plus 47 in block 7.1; I checked the sum and the per-type
  split (5 each for seven types, 6 for JK2 and `other`). The warning count
  holds at 256, so no surveycore warning escapes a new block.

Oracle rule checks (`.claude/rules/testing-surveycore.md`), by parse:

- Rule 1: both sides use the same frame, weight column, 20 replicate
  columns, type and `mse = TRUE` in all nine blocks.
- Rule 2: the nine blocks pass the literal `0.6` to both sides. test-spec
  §3 "How these blocks sit with the oracle rule" and plan task 2 sanction
  this, and each block carries the required comment. The audit's defect
  run shows each block is independent: with surveycore's stored scale
  forced to the defect value, the mean stays green and the SE and both
  bounds go red on all nine types.
- Rule 3: `rscales` reaches `svrepdesign()` in the JKn block only, as the
  literal `rep(1, 20)`.
- Rule 4: every block asserts the SE and both bounds. The bound comment
  points to the Block 24b header, which states the normal-approximation
  precondition (file lines 1050-1055).
- Rule 5: no `survey` warning is silenced. `suppressWarnings`,
  `expect_failure`, `withCallingHandlers`, `tryCatch` and
  `test_invariants`: 0 each in the 10 new blocks. The plan's added-line
  count check reads 0.
- Each stored scale is asserted against a literal, never against the other
  side's scale, 9 of 9.
- Block 7.1 is a round-trip test (it calls no `svrepdesign()`). Its comment
  says so, which matches the rule file's scope paragraph.

## Profile gates, CRAN cookbook and coverage

- Gate 5: `gate-5-check.log` line 93 reads `Status: 1 NOTE`; the note is
  `checking CRAN incoming feasibility` (line 14), pre-approved.
- Gate 2: `gate-2-test.log` line 3025, as above.
- Gate 7: `COVERAGE_PCT=96.18`, unchanged and above the 95% floor. The PR
  adds no line under `R/`, so no new line can be uncovered.
- Gate 6 (pkgdown): SKIPPED — scope. The write surface is `tests/` and
  `plans/` only, which meets r-package-profile.md §pkgdown skip condition.
  `NAMESPACE` is unchanged, so the hard no-skip rule does not apply.
- Gates 1, 3 and 4: clean per logs. G7 (`air`): exit 0 on both changed
  files. G8: no `_snaps/` change. G10: `R/` subtree hash unchanged.
- CRAN cookbook table: None, and the audit verdict is PASS. Consistent.

## Size

The PR adds 678 lines for 10 rows (67.8 per row). The size comes from the
plan's own task text, not from scope beyond the plan:

- Task 2 fixes one block per type, nine blocks, each with its own title.
  Each block must build F1, build both sides, assert six or seven values
  and its conditions, and carry the five-line rule 2 comment the task
  requires. The four kept blocks also build a no-`scale` design for the
  ratio. That is about 63 lines a block, 572 lines in all, plus a 16-line
  section header.
- Task 3 is one 90-line looped block.

No line in the diff does work the plan does not name. A shared helper
could have cut the nine blocks to about a third of their size. The plan's
one-block-per-type shape, with fixed titles, rules that out for this PR.

## Cross-consistency notes

implementation.md and audit.md agree on the commits, the write surface,
the probe results, the parse counts, the defect run and the `air` result.

Non-blocking findings:

1. The nine oracle-block titles run 90 to 113 characters, over the
   80-column limit in `code-style.md`. The plan fixes the titles word for
   word, and `air format --check` passes because it does not rewrap
   strings. This is the same accepted breach as S4/S5 in
   `archive/replicate-oracle-tests/`.
2. In block 7.1, `expect_length(w, 1L)` carries no `info = ty`, unlike the
   other assertions in the loop. A JK2 or `other` failure on the count
   will not name the type. Cosmetic.
3. DRY: the nine oracle blocks repeat the F1 build and the four-assertion
   estimate set nine times. The plan asks for this shape (see §Size). A
   later refactor of the file could fold them into one helper.

## Decision

PASS. All 10 budget rows are present and pass with the test-spec §11
tolerances, every oracle block can fail on the SE and both bounds under the
issue #255 defect, the write surface equals the plan, `R/` is unchanged,
and every gate is clean with warnings held at 256 and coverage at 96.18%.
