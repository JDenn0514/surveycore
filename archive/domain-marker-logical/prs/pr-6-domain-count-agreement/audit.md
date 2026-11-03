# Audit — PR 6 — domain-count-agreement

**Verdict**: PASS
**Date**: 2026-09-15 19:05

Scope audited: test-spec §4 rows 4.1–4.4 and §6 rows 6.1–6.4. Eight rows, eight
new `test_that()` blocks. Rows in §1, §2, §3 and §5 shipped earlier and are not
audited here.

## Scope shape

`git diff --name-only a578b46..HEAD` lists exactly two files:

- `tests/testthat/test-methods-print.R` (+72 lines, 4 blocks, §4)
- `tests/testthat/test-analysis-helpers.R` (+76 lines, 4 blocks, §6)

No file under `R/`, `man/` or `NAMESPACE` changes. `tests/testthat/helper-test-data.R`
is unchanged, so `make_domain_pair()` is read and not edited. The diff touches no
file under `tests/testthat/_snaps/`, and `git status --porcelain R/ man/ NAMESPACE
tests/testthat/_snaps/ tests/testthat/helper-test-data.R` prints nothing on this
tree. The audit ran no edit to `R/`; the namespace probe used `assignInNamespace()`
in a throwaway R session.

`expect_snapshot` appears nowhere in the added lines, so
`tests/testthat/_snaps/methods-print.md` gains no entry. Rows 4.1 and 4.3 read the
printed line back with `capture_design_output()` and assert on the two integers
in it, as §4 requires.

`test_invariants()` call count: 3 before and 3 after in `test-methods-print.R`;
3 before and 3 after in `test-analysis-helpers.R`. No new call, per §Invariants.

## Per-Test Result Table

Tolerance column: §Tolerances makes section 4 an `expect_identical()` section
("Section 4 asserts integer counts"). Section 6 asserts counts and structure, so
no numeric tolerance applies. No tolerance was altered.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 4.1 printed n over every row (Taylor A) | `Domain: 148 of 200 rows` → n=148L, total=200L | `sum(mask)`=148L, `nrow(@data)`=200L | identical (integer) | ✓ |
| 4.2 printed n equals ungrouped `get_means()` n | printed n=148L; `get_means(a, y1)$n`=148L (typeof integer) | the two agree | identical (integer) | ✓ |
| 4.3 design B prints the identical line | `Domain: 148 of 200 rows` (A) vs the same (B) | identical, length 1 | identical (character) | ✓ |
| 4.4 two-phase line counts phase-2 rows only | `Domain: 52 of 74 Phase 2 rows`; n=52L, total=74L | `sum(mask & ph2)`=52L, `sum(ph2)`=74L; B line identical | identical (integer, character) | ✓ |
| 6.1 ungrouped `get_means()`, no marker | `result$n`=200L; marker column absent | `nrow(@data)`=200L | identical (integer) | ✓ |
| 6.2 grouped `get_means()`, no marker | one row per `group` level; `sum(n)`=200L | the levels of `group`; `nrow(@data)` | identical | ✓ |
| 6.3 printed output holds no `Domain:` line | no line matches `^Domain: `; captured output non-empty | absence of the line | n/a (structural) | ✓ |
| 6.4 assigning marker-free data raises no condition | no condition; marker still absent; `y1` written | `expect_no_condition()` | n/a (structural) | ✓ |

Measured with `testthat::test_file(..., reporter = "silent")` under
`devtools::load_all()`, both files in one session:

```
[BASE] test-methods-print.R:     blocks=125 pass=383 fail=0 err=0 skip=43
[BASE] test-analysis-helpers.R:  blocks=141 pass=340 fail=2 err=0 skip=8
    !! print.survey_result() outputs header with class and dims (failed=2)
```

The two failures are the known `load_all()`-only artifact at
`test-analysis-helpers.R:1429/1430`. They sit in a pre-existing block, they are
present on the untouched base, and the `devtools::test()` gate reports `FAIL 0` on
this tree. All eight audited blocks pass.

One earlier probe run of mine reported 166 failures in `test-methods-print.R`. That
run wrapped `test_file()` in `suppressMessages()`, which swallowed the cli stream
the print tests capture. The wrapper was removed and the run above replaces it.

## Row 4.2 — the load-bearing row

The block reads:

```r
result <- get_means(pair$a, y1)
expect_identical(domain_counts(pair$a)$n, result$n)
```

Different code computes the two sides. The left side is parsed out of the text the
print method renders — `regmatches()` on the `Domain: ` line, after
`cli::ansi_strip()`. The right side is the `n` column of an analysis call that
reaches the row mask through `.apply_domain()`. Neither side is derived from the
other, and neither is derived from `pair$mask`. The comparison is
`expect_identical()`, and both sides are integer (`as.integer()` on the left,
`typeof(get_means(...)$n) == "integer"` measured on the right), so no type
coercion loosens it.

## Row 4.4 — precondition verified on the fixture

Measured on `make_domain_pair("twophase")`, not assumed:

| Quantity | Value |
|---|---|
| `nrow(@data)` | 200 |
| `sum(ph2)` (phase-2 rows) | 74 |
| `sum(mask)` (in-domain over all rows) | 149 |
| `sum(mask & ph2)` (in-domain and in phase 2) | 52 |

52 < 149, so the whole-sample route and the phase-2 route give different numbers
and the row tells them apart. This reproduces the earlier 52/149 measurement. The
block asserts the precondition itself with
`expect_lt(sum(pair$mask & ph2), sum(pair$mask))`, so it cannot go quietly vacuous
if the fixture changes. `anyNA(ph2)` is `FALSE`, also asserted in the block.

Issue #276 (`.restrict_to_domain()` does not restrict an `approx` two-phase design)
is not reachable from this row: the print method reads `x@data` and
`x@variables$subset` and builds no `survey` object. Not treated as a finding.

## Non-vacuity probe against the pre-#275 helper

The claim under test: rows 4.1–4.4 fail before PR 4 (#275), which made
`.apply_domain()` resolve a stored `NA` marker to `FALSE`.

Method: read the exact pre-#275 body out of commit `b2fa7e1`, install it over the
loaded namespace with `assignInNamespace(".apply_domain", pre275, ns = "surveycore")`,
then re-run both test files in the same session. No file under `R/` was edited;
`git status --porcelain R/` prints nothing.

```
--- .apply_domain reverted to pre-#275 ---
[PRE275] test-methods-print.R:    blocks=125 pass=381 fail=0 err=1 skip=43
    !! the printed domain count equals an ungrouped get_means() n (error)
[PRE275] test-analysis-helpers.R: blocks=141 pass=275 fail=2 err=8 skip=8
    !! the six §3 function rows, plus 3.7 and 3.8 (error)  [PR 4 rows, control group]
```

Result:

- **Row 4.2 depends on #275.** Under the old helper `get_means(pair$a, y1)` aborts
  with "missing value where TRUE/FALSE needed", so the block errors. It is the only
  §4 row that compares the print count against the analysis count, and the only §4
  row the revert moves.
- **Rows 4.1, 4.3 and 4.4 do not depend on #275.** They pass unchanged under the
  old helper. Measured directly: with the old helper installed, `pair$a` still
  prints `Domain: 148 of 200 rows`. The print method computes its count from
  `@data` and never calls `.apply_domain()`.
- The eight §3 rows from PR 4 all break under the revert. That is the control: the
  probe does install a working pre-#275 helper, and the revert is visible to every
  row that reads the mask.

Rows 4.1, 4.3 and 4.4 are not vacuous — they constrain how the print method itself
handles an `NA` marker. Design A carries three `NA` elements, so a method that
summed the column unguarded would print `Domain: NA of 200` and fail row 4.1's
regex, and a method that counted `NA` as in-domain would print 151 and fail rows
4.1 and 4.3. What they do not do is pin agreement between the printed count and the
analysis count; row 4.2 alone does that.

This matches the test-spec, which writes 4.1, 4.3 and 4.4 as assertions on the
printed line and gives the cross-check to 4.2. Recorded as an observation, not a
finding: a claim that all four rows failed before #275 is wrong for three of them.

## Observations (no action required of this PR)

1. `make_domain_pair()` (PR 4, `helper-test-data.R`) makes designs A and B differ in
   **three** marker elements — rows 3, 47 and 130 — not the one element test-spec
   §Fixture helpers describes. Two of the three would otherwise be `TRUE`; the third
   was already `FALSE`. The wider difference strengthens §4 and §6 rather than
   weakening them. This PR may only read the helper, so nothing is asked of it here.
2. `test-analysis-helpers.R` defines `capture_cli_lines()`, which duplicates
   `capture_design_output()` in `test-methods-print.R`. A function defined in one
   test file is not visible in another, so the copy is forced; the builder states
   that in a comment above it. Promoting either one to `helper-test-data.R` would
   remove the copy, and that is a later change.
3. The §4 helpers `domain_line()` and `domain_counts()` sit beside their blocks at
   the foot of `test-methods-print.R` rather than at the top of the file. Both are
   used in that file only, which is the house rule's single-file case.

## Before/After Comparison

Before comes from the dispatch baseline (`a578b46`); After comes from the gate run
on `40117b0`.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11912 | 11935 | +23 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 (pre-existing AAPOR small-cell) |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0 |
| R CMD check notes | 2 | 2 | 0 |
| changed files under `R/` | — | 0 | — |

Coverage is flat, the expected reading for a test-only PR whose rows run over code
earlier PRs already covered. 96.15% clears the 95% floor, so no HOLD is due on
coverage.

## Profile gates

The gates ran before dispatch and were not re-run here, per the standing low-memory
instruction. Logs:
`.surveycore-workspace/runs/2026-09-12-domain-marker-logical/gates/pr-6/`

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | clean; wrote nothing |
| devtools::test() | PASS | `FAIL 0 / WARN 256 / SKIP 4 / PASS 11935` |
| devtools::run_examples() | PASS | unchanged from base |
| R CMD build | PASS | unchanged from base |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — the pre-approved pair |
| pkgdown::build_site() | PASS | clean |
| covr | 96.15% | 0.00 against baseline; above the 95% floor |
| CRAN cookbook scan | PASS | no violations |

The 256 test warnings read as "no new warning": clean `develop` already emits them
(test-spec §Profile gates, note 2).

Tree: 40117b04b851f4b3c6b3fd4d44f364a0a5f796ec

## CRAN cookbook violations

None.

Scanned the added lines of both changed `.R` files for every pattern in
`r-package-profile.md` §CRAN cookbook scan: bare `T`/`F`, `set.seed()`, bare
`print()`/`cat()` at statement start, `options(warn = -1)`, `installed.packages()`,
`<<-`, unrestored `par()`/`options()`/`setwd()`, writes to `getwd()` or the home
directory, and more than two cores. Zero hits. The PR changes no file under `R/`,
so the scan's main surface is empty; the two test files were scanned anyway. Width
control uses `withr::local_options()`, which restores on exit, and `withr` is
already in `Suggests`.

## BLOCKs

None.

## HOLDs

None.
