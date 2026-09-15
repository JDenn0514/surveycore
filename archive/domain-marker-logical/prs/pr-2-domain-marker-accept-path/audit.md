# Audit — PR 2: test/domain-marker-accept-path

**Verdict: PASS**

`Tree: 3776b432feb49876de146a0069b74b8d737ac4cb`

Scope audited: test-spec §2 rows 2.1, 2.2, 2.3, 2.9 only. Rows 2.4–2.8 ship
in a later PR and are not reported here. §1, §3–§6, and §Existing blocks
belong to other PRs and are out of scope for this audit.

Write surface confirmed via `git diff --name-only origin/develop...HEAD`:
`tests/testthat/test-s7-classes.R` only (+55 lines). No file under `R/`,
`man/`, `NAMESPACE`, or `tests/testthat/helper-test-data.R` changed.

---

## Per-row result table

| Row | File:Line | Observed | Verdict |
|---|---|---|---|
| 2.1 | `tests/testthat/test-s7-classes.R:1839–1847` | `test_that("survey_base validator accepts a logical marker with no NA")`. Builds a no-NA logical mask on a Taylor design from `make_all_designs(seed=7L)`, wraps `set_domain_marker(design, "logical", mask = mask)` in `expect_no_error(..., class = "surveycore_error_domain_not_logical")`, then `expect_identical()`s the stored column against `mask`. | ✓ |
| 2.2 | `tests/testthat/test-s7-classes.R:1849–1858` | `test_that("survey_base validator accepts a logical marker holding one NA")`. Same fixture with `mask[3L] <- NA`; same `expect_no_error(..., class = ...)` form; asserts exactly one `NA` survives in the stored column. | ✓ |
| 2.3 | `tests/testthat/test-s7-classes.R:1860–1868` | `test_that("survey_base validator accepts an all-NA logical marker")`. All-`NA` logical mask; same `expect_no_error(..., class = ...)` form; asserts every stored element is `NA`. | ✓ |
| 2.9 | `tests/testthat/test-s7-classes.R:1872–1889` | `test_that("survey_base validator accepts a haven_labelled logical marker")`. `skip_if_not_installed("haven")` is the first line inside the block. Builds a plain logical mask, then attaches `labels =` and `class = "haven_labelled"` via `structure()` inline in the block (no helper or new type added). Wraps the write in `expect_no_error(..., class = "surveycore_error_domain_not_logical")`. Then asserts BOTH observables: `is.logical(stored)` is `TRUE` and `class(stored)` is exactly `"logical"`, AND `!inherits(stored, "haven_labelled")`. | ✓ |

### Assertion-form check (all four rows)

All four rows use `expect_no_error(expr, class = "surveycore_error_domain_not_logical")`,
not a bare `expect_no_condition()`. Inspected the installed testthat 3.3.2
source directly (`testthat:::expect_no_`, `testthat:::cnd_matcher`): the
internal matcher requires a caught condition to inherit BOTH `"error"` and
the given `class` before it fails the expectation. A condition of any other
class (including a different validator's error, or a warning) is not
muffled and is not what this expectation tests — it would propagate as an
uncaught error/warning in its own right, not as a false pass. This matches
the row requirement exactly: "no condition of class X is raised," not "no
condition of any kind." A bare `expect_no_condition()` would have been
wrong here (256 pre-existing AAPOR warnings exist elsewhere in the suite);
this form is correct.

### Row 2.9 — haven verification

- `skip_if_not_installed("haven")` confirmed present at line 1873, inside
  the block (not file-level), per `testing-standards.md`.
- Targeted run (`Rscript -e 'devtools::test(filter = "s7-classes")'`)
  produced `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 294 ]` — SKIP is 0 in this
  filtered run, confirming `haven` is installed and this row executed its
  body rather than skipping. Baseline-vs-after full-suite SKIP also held
  flat at 4 (given in dispatch), consistent with the same conclusion.
- Both required observables are present: no `surveycore_error_domain_not_logical`
  raised, and the column reads back as plain `logical` with the
  `haven_labelled` class stripped.

### Helper file check

`git diff origin/develop...HEAD -- tests/testthat/helper-test-data.R`
produced no output — `helper-test-data.R` is untouched. Row 2.9 builds its
`haven_labelled` column inline in its own block and hands it to the
existing `set_domain_marker(design, "logical", mask = ...)` signature; no
sixth/seventh `type` value was added to the helper.

### `test_invariants()` call count

`grep -c "test_invariants(" tests/testthat/test-s7-classes.R` returns 7 —
this is the documented counting trap. Line 930 is a test **description**
string (`test_that("test_invariants() passes for survey_nonprob with zero
weights", ...)`), not a call. Actual call sites: lines 177, 783, 867, 889,
936, 960 — six calls, unchanged from the pre-existing baseline the
test-spec records (Taylor and non-probability constructors only; the
replicate/two-phase gap is a pre-existing, out-of-scope condition per the
spec). This PR's four new blocks add zero new `test_invariants()` calls.

---

## Targeted test run

Command: `Rscript -e 'devtools::test(filter = "s7-classes")'`
Log: `.surveycore-workspace/runs/2026-09-12-domain-marker-logical/prs/pr-2-domain-marker-accept-path/targeted-test-run.log`

```
ℹ Testing surveycore
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 294 ]
```

All four target rows pass; no failures in the file this PR touches.

---

## CRAN cookbook violations

Changed-file set for this PR is `tests/testthat/test-s7-classes.R` only —
zero files under `R/`. Ran the cookbook patterns from
`r-package-profile.md §CRAN cookbook scan` over the PR's diff hunk (lines
1836–1889) as the only place code changed, for completeness even though the
scan's stated scope is `R/`.

None.

---

## Profile gates

Gates were run once, upstream of this audit, per the no-rerun instruction
(memory-pressure watchdog; overlapping `run-gates.sh` runs previously
corrupted a log set). Transcribed from the dispatch:

| Gate | Result | Detail |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11805 ]` |
| `devtools::run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `./surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | Status: 2 NOTEs (both pre-approved/pre-existing) |
| `pkgdown::build_site()` | PASS | site built |
| `covr::package_coverage()` | PASS | 96.14% |

`Tree: 3776b432feb49876de146a0069b74b8d737ac4cb`
Logs: `.surveycore-workspace/runs/2026-09-12-domain-marker-logical/gates/pr-2`

**NOTE review:** `CRAN incoming feasibility` (pre-approved,
`r-package-conventions.md`) and `hidden files and directories` for `.git`
(pre-existing, `.Rbuildignore`-caused, previously recorded against earlier
PRs). No new NOTE pattern appears.

**Coverage-log caveat (per dispatch):** the coverage log's "changed R/
files" column names `R/core-classes.R` — that is stale, computed against a
locally out-of-date `develop` ref (`8fe3fa2`). The correct changed set from
`origin/develop...HEAD` is zero files under `R/`, confirmed independently
above. Coverage held flat at 96.14% because `covr` cannot attribute
execution inside an S7 validator closure; this PR's four rows exercise
validator code, so a flat figure is the expected outcome and not a gap.

---

## Before/After comparison

Baseline: `develop` @ `5b05a8c` (PR 1 merged).

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11795 | 11805 | +10 |
| tests failing | 0 | 0 | 0 |
| warnings | 256 | 256 | 0 |
| skips | 4 | 4 | 0 |
| coverage | 96.14% | 96.14% | 0 |
| R CMD check NOTEs | 2 (pre-approved/pre-existing) | 2 (same two) | 0 |

+10 expectations matches four new `test_that()` blocks: three single-
assertion-pair rows (2.1 uses two assertions, 2.2 two, 2.3 two) plus 2.9's
four assertions — 2+2+2+4 = 10. No regression in any metric.

---

## Tolerance integrity

No numeric tolerance applies to these four rows — all four assert class
membership / absence of a named error class and structural properties
(`is.logical`, `inherits`, `sum(is.na(...))`). No tolerance was invented,
relaxed, or applied.

---

## Verdict

**PASS.** All four in-scope rows (2.1, 2.2, 2.3, 2.9) are present, use the
correct `expect_no_error(..., class = ...)` assertion form (not a bare
`expect_no_condition()`), pass on targeted run, and leave the helper file,
`test_invariants()` call count, and coverage/warning/skip counts unchanged
from baseline. No CRAN cookbook violations. No profile-gate regression.
