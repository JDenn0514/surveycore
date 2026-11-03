# Review — PR 1 fay-rho-constructor

**Verdict**: STOP
**Category**: tolerance-integrity
**Branch**: feature/fay-rho-constructor, HEAD 025ae7d, base develop 0691dbd
**Tree**: 9e2900fcd62ae6bfed66bff001e2cd180ed3da59 (confirmed with `git rev-parse HEAD^{tree}`)

## Why STOP

One new assertion is looser than `test-spec.md` §Tolerances allows, and
`audit.md` reports it at the specified tolerance.

- `tests/testthat/test-constructors.R:1005`, row 1.2:
  `expect_equal(stored("Fay", rho = 0.3), 1 / (n_rep * (1 - 0.3)^2))`.
- The line has no `tolerance =`. The package uses testthat edition 3
  (`DESCRIPTION`), so the default is `sqrt(.Machine$double.eps)`, about
  1.49e-8.
- `test-spec.md` §Tolerances fixes "Stored scale against its literal: 1e-8".
  `implementation-plan.md` line 23 gives the builder the same value.
- `audit.md` Per-test table row 1.2 reports tolerance 1e-8. The audit's own
  Observations section says the line uses the default, about 1.5e-8. So the
  table row misreports the tolerance in force.

The reviewer rule maps a looser tolerance to STOP. The measured difference is
0, so the value is right. The defect is the assertion's strength and the
audit's report of it.

The eight other lines of that block use the default too. They are
pre-existing, and the plan task 4 said they do not change, so they are not a
finding here. The Fay line is a changed line with a new expected value, so
§Tolerances applies to it.

Secondary, not a STOP by itself: row 1.1's `expect_equal(d@variables$rho, 0.3)`
also uses the default, and the audit reports it as 1e-10. No test-spec
category names a stored `rho` (it is not a point estimate), so no rule is
breached. The audit report is still wrong for that row.

## What must change before resume

Either of these:

1. Builder: add `tolerance = 1e-8` to the Fay line at
   `tests/testthat/test-constructors.R:1005`. Tester: re-run the filtered
   `constructors` test and correct audit rows 1.1 and 1.2 to the tolerance
   the code actually uses. No other gate is affected by a tolerance argument.
2. User: record an explicit override in `decisions.md` that accepts the
   default tolerance on that line.

## Checks

| # | Check | Result |
|---|---|---|
| 1 | Convergence: spec contracts in PR 1 scope have audit rows | Clean. Signature, check order, FR-1/FR-2/FR-3 templates and bindings, `as.double(unname(rho))`, Fay scale, switch without `Fay`, `rho` key position all match spec §II/§III in the diff |
| 1b | Test-spec covers the spec contracts | Clean for PR 1 rows 1.1, 1.2, 1.4a, 1.5, 1.7, 1.10, 1.11, 6.1, 6.8, 6.9, 6.14 |
| 1c | Write surface matches plan | Clean. 9 files in `git diff --stat 0691dbd...HEAD`, the same 9 as plan PR 1 Files touched |
| 2 | Tolerance integrity | **STOP**: row 1.2 Fay line, see above |
| 3 | Scope discipline, no unflagged regression | Clean. Suite 12100 to 12129 pass, 0 fail, 256 warnings unchanged. The one deleted block ("scale yields no rho") and its snapshot entry are the plan's task 12 deletion |
| 4 | CRAN cookbook and profile gates | Clean. Audit shows None; all 10 gates have a result; the second NOTE (hidden `.git`) is the plan's criterion G4 note. The air gate for `test-constructors.R` reads as "the PR's own lines" per D16 of the bridge arc; the audit shows no air hunk on a PR line |
| 5 | Coverage floor | 96.15%, unchanged from baseline. One new line uncovered: `R/core-constructors.R:902`, the `"a value of length 0"` arm. Plan PR 2 task 4 assigns its test (`rho = numeric(0)` snapshot, row 1.9) by name. The gap is a planned split, closed by the next PR on the same file, so I do not treat it as an unplanned coverage loss. The orchestrator must not ship the arc if PR 2 drops that snapshot |
| 6 | Comprehension alignment | Clean. Each gotcha and assumption in `comprehension.md` maps to a test-spec row or to test-spec §Gotchas out of scope |
| 7 | Audit verdict | PASS, but see check 2 |

## Other notes (not findings)

- Register rows FR-1 to FR-3 in `plans/error-messages.md` are byte-identical
  to the planning copy. The builder changed one intro sentence so it does not
  claim TP-1 is present; `implementation.md` records it.
- Three new test titles pass 80 characters (audit observation). `air` does
  not rewrap strings, so gate G7 does not see them.

## Pass 2 — f8f78d8 (tree a11fe29e6efdef378603fc922820d5968aa3e4f2)

**Verdict**: PASS

- Delta `git diff 025ae7d f8f78d8`: one file, `tests/testthat/test-constructors.R`,
  6 insertions and 2 deletions. The nine-type block's Fay line gains
  `tolerance = 1e-8`. The row 1.1 `rho` line gains `tolerance = 1e-10`.
  No other line changed. The tree hash matches the one the coordinator gave.
- Row 1.2 now meets `test-spec.md` §Tolerances (stored scale 1e-8). The pass 1
  STOP is resolved. Row 1.1's `rho` is tighter than the default, which is
  allowed.
- The corrected audit rows 1.1 and 1.2 name the tolerance the code sets and
  say what the line used on 025ae7d. The audit Tree line reads a11fe29.
- The eight pre-existing lines keep the default tolerance. `decisions.md`
  records the user's choice, so they are not a finding.
- The write surface is still the 9 files in the plan. The delta adds no file,
  no snapshot and no assertion, so checks 1, 3, 4, 5 and 6 of pass 1 stand.
- Expectation counts: pass 1 audit line 50 records 815 constructors
  expectations. The f8f78d8 run records PASS 799. Adding a tolerance argument
  cannot change how many expectations run, so the 16-count gap comes from
  how the two runs differ (filter, `NOT_CRAN`, skips), not from this delta.
  The full-gate re-run must show 12129 passing, 0 failures and 256 warnings.
- Scope of this verdict: tree a11fe29 only. The gate table in `audit.md` shows
  the 025ae7d run. The full gates re-running now must reproduce those results
  on a11fe29 before the PR ships. A gate result that differs voids this PASS.
