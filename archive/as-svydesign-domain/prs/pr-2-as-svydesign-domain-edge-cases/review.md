# Review — PR 2 — as-svydesign-domain-edge-cases

**Verdict**: PASS
**Date**: 2026-09-10 16:05

Branch `test/as-svydesign-domain-edge-cases` at `7ee6d53`, tree
`97414b3b726c7538fcfe360d6254c64873e8b1fc`, cut from `develop` at `1674bf6`.
The tree hash matches the one `audit.md` records.

## Convergence checks

- Spec coverage: yes, for this PR's slice. All eleven allocated rows are
  covered by a block that exists on this tree and passes.
- Test coverage of spec: yes. Each of the eleven rows maps to an entry in
  `spec.md` §`.restrict_to_domain(converted)` → Edge cases, §`as_tbl_svy(x)`,
  or §`from_svydesign(x)`.
- Tolerance integrity: yes. Point 1e-10, SE 1e-8, CI bounds 1e-6, unchanged
  from `test-spec.md` §Tolerances.
- Scope discipline: yes. One file changed, 119 insertions, no deletions.
- Regression safety: yes. FAIL 0, WARN 256, SKIP 4 before and after. The
  expectation count moves 11686 to 11706.

## Row ledger — who covers what

`decisions.md` §Carry-forward into PR 2 reduced eleven rows to six pieces of
work. The reduction holds and produced no duplicate block.

| Row | Covering block (line) | Landed with |
|---|---|---|
| D-2a | `converts an all-FALSE marker to a zero-row object` (3388) | PR 1 |
| D-3 | `converts a single-TRUE marker to a one-row object` (3408) | PR 2 |
| D-4 | `treats an NA marker row as outside the domain` (3370) | PR 1 |
| D-5a | `converts an all-NA marker to a zero-row object` (3426) | PR 2 |
| D-6 | five-type loop, `integer` case (3313) | PR 1 |
| D-6a | five-type loop, `character` case (3313) | PR 1 |
| D-6b | five-type loop, `factor` case (3313) | PR 1 row count and silence; **PR 2 the probability assertion** |
| D-6c | `reads an unconvertible marker as an empty domain` (3353) | PR 1 |
| E-1 | `as_tbl_svy() inherits the restriction on a filtered Taylor design` (3445) | PR 2 |
| F-4 | `the round trip ... agrees on the numbers [numerical]` (3462) | PR 2 |
| F-5 | `the round trip ... prints n of n rows` (3486) | PR 2 |

I read `origin/develop`'s copy of the file and listed its blocks. The five
blocks PR 2 adds carry names and inputs that appear nowhere on `develop`. No
row is asserted twice.

One near-neighbour pair deserves a note, because it looks like repetition and
is not. D-5a repeats D-2a's three assertions on a different input: an all-`NA`
marker rather than an all-`FALSE` one. The two inputs reach the mask through
different halves of `r & !is.na(r)`, and `test-spec.md` §D lists them as
separate rows. Deleting either one would leave half the mask expression
unpinned. This is not the DRY violation `engineering-preferences.md` names
first.

## D-6b — the assertion PR 2 was asked to add

The added expectation, at `tests/testthat/test-conversion.R:3339-3342`:

```r
expect_true(
  is.numeric(sv$prob) && all(is.finite(sv$prob)),
  info = nm
)
```

It sits inside the five-type loop, so it runs for the `factor` case, which is
the case `spec.md` §Row mask measured as corrupt. Placement is correct.

The assertion closes the hole and is not vacuous:

- On the guarded state — `&` alone on a factor marker, an all-`NA` mask, every
  row kept, a probability vector that is neither finite nor infinite — either
  `is.numeric()` is `FALSE` or `all(is.finite())` is `FALSE`. The expectation
  fails.
- `all(is.finite(NULL))` is `TRUE`, so the probability check on its own could
  have passed on an object carrying no `prob` at all. The `is.numeric()` guard
  removes that reading, and the suite passes, which proves `sv$prob` is a real
  numeric vector on this fixture.
- The `&&` also stops a list-valued `prob` from erroring inside `is.finite()`.
  The block then reports a failure rather than an error.

The two halves PR 1 already carried — the row count and
`expect_no_condition()` — both pass on the corrupt object, which is why this
row needed finishing. It is finished.

## Test quality — would each new block fail on a regression?

| Block | Regression it catches |
|---|---|
| single-`TRUE` | The restriction stops applying: 50 rows against 1 |
| all-`NA` | `!is.na(r)` dropped: 50 rows against 0, and the mean moves off 0 |
| `as_tbl_svy()` | The wrapper undoes the restriction: 50 rows against 25 |
| round trip, numbers | The stored call is lost, so the rebuild drops clustering and stratification. The point estimate survives that and the interval does not, which is why both bounds are asserted |
| round trip, print | The marker column fails to travel back, or arrives with mixed values: `all(df[[COL]])` fails |

`n` in the print block is read off the rebuilt design rather than written as a
literal. That makes the `Domain: n of n rows` grep insensitive to the row count
on its own, but the same block asserts every marker value is `TRUE`, and a lost
restriction gives a mixed column. The block fails on the regression it names.

## Scope discipline

`git diff --name-only origin/develop...HEAD` reports one path,
`tests/testthat/test-conversion.R`. Checked individually and each reports zero
changed files: `R/`, `NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION`,
`plans/error-messages.md`, `changelog/`, `_pkgdown.yml`,
`tests/testthat/_snaps/`. The plan's PR 2 entry lists one file touched, and one
file changed.

Budget: 11 rows against a bound of 12, 8 criteria against a bound of 8. Inside
both.

The expectation delta corroborates the write surface. The six pieces of work
add 5 + 2 + 4 + 2 + 4 + 3 = 20 expectations, and the suite total moves by
exactly +20.

## The two gate notes

**pkgdown SKIPPED — scope.** Allowed. `r-package-profile.md` permits the skip
when the write surface touches none of `R/`, `vignettes/`, `README`,
`_pkgdown.yml` or `DESCRIPTION`, and this one touches none of them. The hard
rule that forbids a skip when exports change does not bite: the `NAMESPACE`
diff is empty. The skip is logged in the audit's gate table with the required
wording.

**The covr changed-file list.** It names `R/analysis-means-helpers.R` and
`R/methods-conversion.R`. Both are artifacts of the runner, not of this PR.
`run-gates.sh` diffs against the local `develop` ref, which sits at `a545505`
because `develop` is checked out in another worktree, while `origin/develop` is
at `1674bf6`. The two named files are PR 0's and PR 1's, already merged. I
confirmed the real diff against `origin/develop` is one test file. The four
uncovered lines are identical to the ones the `pr-1-fix` run reported, so
nothing regressed.

## Profile gates

| Gate | Result | Verified against |
|---|---|---|
| `devtools::document()` | PASS | `logs/pr-2/gate-1-document.log`; `git status` shows no change under `man/` or `NAMESPACE` |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11706 |
| `devtools::run_examples()` | PASS | `logs/pr-2/gate-3-examples.log` |
| `R CMD build` | PASS | `logs/pr-2/gate-4-build.log` |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` |
| pkgdown | SKIPPED — scope | see above |
| covr | 96.25% | `COVERAGE_PCT=96.25` |
| CRAN cookbook scan | None | no `R/` file changed, so the scan has nothing to read |

The two NOTEs are `checking CRAN incoming feasibility` and the `.git`
hidden-file note. Both appear on the PR 0 and PR 1 runs of this arc at the same
count. No new NOTE pattern, so nothing escalates.

The four skips sit in `test-glm-anova-numerical.R`, `test-glm-anova.R` and
`test-srr-compliance.R`. None is in `test-conversion.R`, so `survey`, `srvyr`
and `surveytidy` were all installed and every row of this PR ran rather than
skipped.

Coverage: 96.25%, above the 95% floor. It equals the `pr-1-fix` figure and sits
above the 96.24% baseline. No drop, and this PR adds no production line to
leave uncovered.

## Cross-consistency notes

`implementation.md` and `audit.md` describe the same system. Both name commit
`7ee6d53`, one changed file and 119 insertions, one extended block and five new
ones. The audit's per-row table cites line numbers 3313, 3353, 3370, 3388,
3408, 3426, 3445, 3462 and 3486; I read the file and each block sits at the
cited line. The builder's local figure, 696 passing under
`devtools::test(filter = "conversion")`, and the tester's full-suite figure,
11706, are different measurements of the same tree and do not conflict.

One process deviation, recorded and accepted. The tester did not run the gates;
the dispatching session ran them and the audit accepts the printed summary.
`audit.md` states this in its gate section. I read the logs under `logs/pr-2/`
independently and every figure the audit reports matches its log. Every gate has
a result, and the one skip is the documented scope skip. This is not a test-skip
integrity violation.

## Decision

PASS. All eleven rows are covered, none twice. The D-6b probability assertion
sits inside the loop that reaches the factor case, and it fails on the corrupt
state the spec measured. The write surface is one test file. The tolerances are
the test-spec's own. Coverage holds at 96.25% with no regression in tests,
warnings or skips.

## Housekeeping for the shipper, not a verdict item

The worktree carries an uncommitted edit to `plans/pr-budget-calibration.md`,
which is PR 1's ledger row from the previous ship. It is not in this PR's
commit. Keep it out of PR 2's commit.
