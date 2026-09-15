# Audit — PR 3: test/domain-marker-type-breadth

**Verdict: PASS**

`Tree: f98e160b2c2c16df948abd28b06343c761f960e3`

Scope audited: test-spec §1 rows 1.5–1.11 and §2 rows 2.4–2.8 (twelve rows),
all in `tests/testthat/test-s7-classes.R`. Rows 1.1–1.4, E.1–E.4, 2.1–2.3 and
2.9 were merged in earlier PRs and are out of scope here; not re-audited.

## Write surface

`git diff --name-only a5b88c2..HEAD` → one file only:
`tests/testthat/test-s7-classes.R`. No `R/`, `man/`, or `NAMESPACE` path
changed. `R/core-classes.R` validator body (lines 344–373) confirmed intact
after the audit's own non-vacuity probe (see below) — `git status --porcelain
R/` prints nothing at the end of this audit.

## Per-row result table

| Row | File:line | Observed | Verdict |
|---|---|---|---|
| 1.5 | test-s7-classes.R:1836 | `expect_error(set_domain_marker(design, "double"), class = "surveycore_error_domain_not_logical")`, no snapshot. Taylor design. | PASS |
| 1.6 | test-s7-classes.R:1844 | Same shape, `type = "character"`. | PASS |
| 1.7 | test-s7-classes.R:1852 | Same shape, `type = "factor"`. | PASS |
| 1.8 | test-s7-classes.R:1860 | Same shape, `type = "list"`. | PASS |
| 1.9 | test-s7-classes.R:1868 | Builds `df` with an integer marker column, `expect_error(as_survey(df, ...), class = "surveycore_error_domain_not_logical")`, no snapshot. | PASS |
| 1.10 | test-s7-classes.R:1884 | Same `df`, `expect_error(as_survey_nonprob(df, weights = wt), class = ...)`. | PASS |
| 1.11 | test-s7-classes.R:1893 | `expect_error(design@data <- new_data, class = ...)` then `expect_false(SURVEYCORE_DOMAIN_COL %in% names(design@data))` — asserts the column is absent after the failed write, not just "still equal to some old value". | PASS |
| 2.4 | test-s7-classes.R:1941 | Replicate design, all-`NA` logical mask. `expect_no_error(..., class = "surveycore_error_domain_not_logical")` (targeted, not "no condition at all" — see note below), then `expect_true(all(is.na(...)))`. | PASS |
| 2.5 | test-s7-classes.R:1951 | Taylor design, mask carries `attr(mask, "label") <- "Inside active domain"`. `expect_no_error(class = ...)`, then asserts `is.logical(stored)` and `attr(stored, "label", exact = TRUE)` equals the original string — attribute survival is asserted directly. | PASS |
| 2.6 | test-s7-classes.R:1967 | Zero-row frame built inline (`design@data[0L, , drop = FALSE]`), no new generator parameter. `expect_no_error(class = ...)`, then `expect_identical(marked@data[[COL]], logical(0))`. | PASS |
| 2.7 | test-s7-classes.R:1980 | Same inline zero-row build, `type = "integer"`. `expect_error(class = ...)` only. | PASS |
| 2.8 | test-s7-classes.R:1989 | Two-phase design. Captures `before <- design@data[[design@variables$subset]]` (the design's own subset column, distinct from the domain marker), one-`NA` logical mask, `expect_no_error(class = ...)`, then `expect_identical(marked@data[[subset_var]], before)` plus the NA-count check on the marker column. | PASS |

## Assertion-form check: `expect_no_error(..., class = ...)`

Verified against `testthat 3.3.2` source
(`testthat:::expect_no_error`, `testthat:::expect_no_`): the `class` argument
is passed into `cnd_matcher(base_class = "error", class = class)`, so the
expectation fails only on an error inheriting the *named* class — not on any
condition. This matches the spec requirement in §2 ("assert that, and not the
absence of every condition"). All five accept-path rows in scope use this
form correctly.

## Non-vacuity probe

Temporarily replaced the validator's type-check `if` in
`R/core-classes.R:355` with `if (FALSE)` (bypassing the reject branch),
reloaded, and ran `tests/testthat/test-s7-classes.R`:

- 13 failures appeared, exactly: rows 1.1–1.4 (out of scope, already merged),
  1.5, 1.6, 1.7, 1.8, 1.9, 1.10, both assertions in 1.11, and 2.7. Every
  reject-path row in scope depends on the validator; none is vacuous.
- The five accept-path rows in scope (2.4–2.6, 2.8, plus out-of-scope
  2.1–2.3, 2.9) did **not** appear in the failure list, as expected — logical
  columns were never rejected, disabling the reject branch changes nothing
  for them.

Restored immediately: `git checkout -- R/core-classes.R`;
`git status --porcelain R/` printed nothing before and after the probe. `R/`
is clean at the end of this audit.

## Snapshot check

`git status --porcelain tests/testthat/_snaps/` — no output (no new/changed
snapshot files). `git diff a5b88c2..HEAD -- tests/testthat/_snaps/` — empty.
No snapshot exists for `surveycore_error_domain_not_logical`, consistent with
the Layer-1 rule (class-only, no snapshot).

## Helper file check

`git diff a5b88c2..HEAD -- tests/testthat/helper-test-data.R` — empty.
`set_domain_marker()` (added by an earlier PR) is read only, not edited.

## `test_invariants()` count

`grep -n "test_invariants(" tests/testthat/test-s7-classes.R` returns 7 lines,
but one (line 930-ish region) is a `test_that()` *description string*
("test_invariants() passes for survey_nonprob with zero weights"), not a
call. Actual calls: lines 177, 783, 867, 889, 936 (inside
`expect_no_error(test_invariants(obj))`), 960 — **six**, unchanged from
before this PR. No new call added by rows in scope.

## §2 ordering

Confirmed ascending in file order: 2.1 (1910) → 2.2 (1920) → 2.3 (1931) →
2.4 (1941) → 2.5 (1951) → 2.6 (1967) → 2.7 (1980) → 2.8 (1989) → 2.9 (2003).

## Targeted test run

`Rscript -e 'devtools::load_all(quiet = TRUE);
testthat::test_file("tests/testthat/test-s7-classes.R", reporter =
"summary")'` — all tests in the file pass, 0 failures, after `R/` was
restored to the merged state.

## CRAN cookbook violations

None. No `R/` file changed on this branch since baseline `a5b88c2`. As a
secondary check, the added lines of `tests/testthat/test-s7-classes.R`
(the diff against `a5b88c2`) were scanned for the cookbook patterns
(bare `T`/`F`, `print()`/`cat()`, `set.seed()`, `options(warn = -1)`,
`installed.packages()`, `<<-`, unrestored `par()`/`setwd()`,
`mc.cores`/`makeCluster` > 2): zero hits in the changed region (lines
1800–2020). The file's pre-existing `set.seed()` calls (lines 58, 71, 188,
383, 400, 1467, 1479, 1492, 1502) sit outside the diff and outside `R/`, so
they are not scan targets regardless.

## Profile gates (reused from dispatch — not re-run per instructions)

| Gate | Before (`a5b88c2`) | After (`f98e160`, this PR) | Δ |
|---|---|---|---|
| devtools::document() | clean | clean — document() wrote nothing | 0 |
| devtools::test() | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11805` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11825` | +20 expectations, 0 new failures, warnings flat |
| devtools::run_examples() | pass | pass | 0 |
| R CMD build | pass | pass | 0 |
| R CMD check --as-cran | 2 NOTEs (pre-approved: CRAN incoming feasibility, `.git` hidden-file finding) | 2 NOTEs, same two | 0 |
| pkgdown::build_site() | clean | clean | 0 |
| covr::package_coverage() | 96.14% | 96.14% | 0 |

Coverage is flat, not a gap: rows in scope exercise an S7 `validator =`
closure, and `covr` cannot attribute execution inside one (control case:
`R/core-classes.R:709`, a pre-existing validator guard nine passing tests
reach, also reads uncovered). The governing floor is 95%; 96.14% clears it
with room. The gate log's "changed R/ files" column names
`R/core-classes.R` — that is stale, produced by a local `develop` ref
pinned at `8fe3fa2` in this worktree; the true changed-file set on this
branch is zero files under `R/`, confirmed directly above.

Gates were not re-run in this audit (instructed not to, given the memory
constraint); the table above is the dispatch-supplied Before/After pair,
corrected per the coordinator's follow-up to use 11805 as the baseline PASS
count.

## Verdict rationale

All twelve rows in scope assert the required class with the required form
(class-only for rejects, targeted `expect_no_error(class=)` for accepts, no
snapshot on Layer 1), cover their row-specific observable (rollback leaves no
column, label attribute survives, two-phase subset column is untouched,
zero-row cases built inline), passed a genuine dependency probe against the
validator, and leave no trace in `_snaps/`, the helper file, or `R/`. No
cookbook violation. No regression in tests-passing or coverage. Gates clean.

**PASS.**
