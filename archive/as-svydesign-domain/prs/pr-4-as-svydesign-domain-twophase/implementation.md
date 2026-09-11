# Implementation — PR 4 — as-svydesign-domain-twophase

**Branch**: `fix/as-svydesign-domain-twophase`
**HEAD**: `9daf70e334d075e7e118c299231e217b79bca8c4`
**Tree**: `4889ae06f8dc60db7e376aa7cc122fcd180467f5`
**Base**: `9625c1866d861855b1f31e9b70a8f13318b70e8f` (= `origin/develop`, verified
before any read or write)

## Write surface

- `R/methods-conversion.R` — modified: the two-phase frame branch inside
  `.restrict_to_domain()`, one call site in `.as_svydesign_twophase()`, and the
  helper's comment paragraph rewritten to name all three classes
- `tests/testthat/test-conversion.R` — modified: one new section

`git diff --stat origin/develop...HEAD` names those two files and nothing else.
`NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION`, `plans/error-messages.md` and
`tests/testthat/_snaps/` are byte-identical to `develop`. `devtools::document()`
ran and wrote nothing — the helper is `@noRd` and this PR changes no roxygen.
The five planning files under `plans/` stay uncommitted and unstaged; each
commit stages by explicit path.

Three commits: `7533c12` (fix), `0e15135` (test) and `9daf70e` (the BLOCK fix).

## Summary

- `.restrict_to_domain()` now derives the marker frame from the converted
  object's class: `converted$phase1$sample$variables` when
  `inherits(converted, "twophase2")`, `converted$variables` otherwise. The
  helper keeps one argument, one column-presence check, one mask expression and
  one `[` call. No call site gained a frame argument.
- `.as_svydesign_twophase()` assigns the object `survey::twophase()` builds to
  `converted` and returns `.restrict_to_domain(converted)`, mirroring the Taylor
  and replicate call sites. The signature is unchanged and the dispatch in
  `as_svydesign()` is untouched, so no branch reads the weight shape and no
  ninth copy of the non-probability routing predicate exists.
- The frame branch was needed twice over: a two-phase object carries no
  `converted$variables` at all, and its phase-1 sample holds only the phase-2
  rows — 29 against 60 in `@data` on the fixture — so the `@data`-side vector
  raises a bare `logical subscript too long`.
- On this route `[` removes no row. Measured on the fixture: 29 phase-2 rows,
  14 of them marked, 29 rows after the restriction and 14 finite probabilities.
  The test blocks assert the count of finite probabilities and, in that block,
  no row count.
- The helper's comment paragraph now names `survey.design2`, `svyrep.design`
  and `twophase2`, says where each keeps its frame, and records that the
  two-phase route applies the domain by setting an infinite probability rather
  than by removing a row.
- `tests/testthat/test-conversion.R` gains two fixtures and **11** new
  `test_that()` blocks under a new
  `# ── Domain restriction on the two-phase route ──` heading, plus exactly one
  new `test_invariants()` call. No existing block changed.

## Block and call counts

Counted from the diff, not by eye:

| Count | Command | Result |
|---|---|---|
| New `test_that()` blocks | `git diff -U0 tests/... \| grep -c "^+test_that("` | 11 |
| New `test_invariants()` calls | `git diff -U0 tests/... \| grep -c "^+  test_invariants("` | 1 |
| `test_invariants(` in the file, `develop` → HEAD | `grep -c` | 6 → 7 |

The file's `test_invariants(` count rises by exactly one. Six of those seven
occurrences are calls and one is a comment at line 2293 that names the helper;
both the before and the after count include it, so the rise is a real call.

The 11 blocks:

1. filtered two-phase parity against a hand-restricted oracle — carries the new
   `test_invariants()` call
2. the estimator gap on an unfiltered design
3. one finite probability per marked phase-2 row
4. the file's own two-phase builder, filtered
5. an unfiltered two-phase design converts unrestricted
6. an all-`FALSE` marker
7. an all-`NA` marker
8. the marker survives a Taylor conversion, all `TRUE` (cross-check)
9. the marker survives a two-phase conversion with its values unchanged
10. the round trip rebuilds the full phase-1 frame and the marker
11. no condition with a `^surveycore_` class on an ordinary domain

Blocks 5, 6, 7 and 11 each assert that no condition with a `^surveycore_`
class fires.

## Task checklist

- [x] 1. Base sha confirmed: `git rev-parse HEAD` returned
  `9625c1866d861855b1f31e9b70a8f13318b70e8f`, equal to `origin/develop`, before
  any read or write
- [x] 2. Failing test first. The parity block ran before the production change
  and failed on both expectations, for the right reason: mean 49.2 against
  57.2, SE 1.549 against 1.585. The oracle is a two-phase object built straight
  from `survey::twophase()` over the same frame, indexed by `[` with a mask read
  from its own `phase1$sample$variables` marker column, `NA` read as `FALSE`
- [x] 3. The single new `test_invariants()` call sits in that first block, for
  `as_survey_twophase()`. No other block in this PR calls it
- [x] 4. The frame branch is inside `.restrict_to_domain()` and nowhere else.
  The mask expression and the `[` call are unchanged from `develop`
- [x] 5. One call in `.as_svydesign_twophase()`, on the object it has just
  built, immediately before returning it
- [x] 6. The parity block passes. Every two-phase call in the new section either
  wraps in `suppressWarnings()`, as the file's existing two-phase blocks do, or
  goes through `collect_surveycore_classes()`, which muffles the same
  conditions and inspects them first. No `expect_no_condition()` appears
  anywhere in the new section
- [x] 7. The estimator-gap block, written out in full. On the unfiltered design
  it reproduces `get_means()` with `weighted.mean(frame$y1, frame$wt)` and
  `survey::svymean()` with `weighted.mean(frame$y1, 1 / sv$prob)`, both to
  1e-10, then asserts the two hand answers differ with
  `expect_false(isTRUE(all.equal(...)))`. Measured 48.9245 against 49.20304,
  the pair `spec.md` §Out records. The block pins the gap; it does not close it
- [x] 8. `expect_identical(sum(is.finite(sv$prob)), marked_phase2)` where
  `marked_phase2` is `sum(marker & subset)` off the design's own data. That
  block asserts no row count
- [x] 9. The file's own `make_twophase()` builder, which names no phase-2
  cluster identifier, converts filtered with no error and gives the same
  finite-probability count. The fixture is unchanged
- [x] 10. Unfiltered two-phase: the phase-1 full frame holds one row per design
  row, the phase-1 sample holds one row per phase-2 row, the marker column is
  absent, every probability is finite
- [x] 11. All-`FALSE` and all-`NA` markers, one block each. Row count unchanged,
  `expect_false(any(is.finite(sv$prob)))`, and
  `expect_true(is.nan(coef(sm)[["y1"]]))`
- [x] 12. Marker survival on both kinds of route, and the round trip. The
  two-phase block asserts the converted marker is `expect_identical()` to the
  design's marker over the phase-2 rows, and that it is neither all `TRUE` nor
  all `FALSE`. The round trip rebuilds 60 phase-1 rows with the original
  60-value marker, both with `expect_identical()`
- [x] 13. The condition assertions use `collect_surveycore_classes()`, a
  `withCallingHandlers` collector defined once at the top of the section and
  called by four blocks (see §BLOCK fix). Each asserts
  `expect_identical(classes, character(0L))`. PR 3's
  `expect_no_warning(expect_warning(...))` idiom is not used on this route
- [x] 14. Every `get_means()` call in the new section passes `min_cell_n = 1L`.
  The phase-2 sample holds 29 rows and the domain 14, both under the default
  threshold of 30
- [x] 15. Two new fixtures, `make_twophase_ids2()` and
  `make_filtered_twophase()`. `as_survey_twophase()`'s signature was read from
  `R/core-constructors.R:958` rather than guessed; the phase-2 cluster
  identifier is `ids2 = psu`
- [x] 16. `devtools::test(filter = "conversion")` run repeatedly; the full suite
  run once, in the foreground, redirected to `.test-full.log`, which was deleted
  before the first commit. No `devtools::check()`, no `covr`, no `pkgdown`. One
  R process at a time throughout
- [x] 17. `devtools::document()` run once; `git status` shows no `man/` and no
  `NAMESPACE` change. `air format --check` exits 0 on both files
- [x] 18. This file

## Measurements

| Run | Result |
|---|---|
| `devtools::test(filter = "conversion")`, before the production change | FAIL 2, PASS 760 |
| `devtools::test(filter = "conversion")`, after | FAIL 0, WARN 0, SKIP 0, PASS 787 |
| `devtools::test()` (full, once) | FAIL 0, WARN 256, SKIP 4, PASS 11797 |
| `air format --check` on both files | exit 0 |
| `devtools::document()` | no `man/` or `NAMESPACE` change |

The 256 warnings are the pre-existing AAPOR small-cell count that clean
`develop` already carries (`archive/svydesign-replicate-bridge/` D12). This PR
adds none.

**Sensitivity check.** With the two-phase call site disabled — the
`.restrict_to_domain(converted)` line replaced by `converted`, then restored by
hand, no `git stash` — the conversion suite reports FAIL 8 across five of the
eleven new blocks: the parity block, the finite-probability count, the
file's-own-builder block, and both empty-domain blocks. The same eight failures
cover the frame branch, because without it
`SURVEYCORE_DOMAIN_COL %in% names(converted$variables)` is `FALSE` on a
`twophase2` object and the helper returns the object un-indexed. The remaining
six blocks pin properties that hold on both sides of the change.

**The file's own builder passed.** `make_twophase()` names no phase-2 cluster
identifier, and a filtered conversion through it raises no error and gives the
same finite-probability count. The fixture was not changed.

## CRAN compliance self-check

`TRUE`/`FALSE` written out; `::` on every external call; no bare `print()` or
`cat()`; no randomness added, so no `seed =` argument is due; no `par()` or
`options()` touched; no file written; no parallel code; `devtools::document()`
run; no `installed.packages()`.

## BLOCK fix — 2026-09-11, commit `9daf70e`

Classification: contract-miss. Three blocks — "converts an unfiltered
two-phase design unrestricted", "converts an all-FALSE two-phase marker to no
finite probability" and "converts an all-NA two-phase marker to no finite
probability" — wrapped the conversion in a bare `suppressWarnings()` and
asserted only row counts, marker presence, finite-probability counts and
`is.nan()`. `suppressWarnings()` discards a surveycore warning as readily as
`survey`'s, so a stray `surveycore_`-classed condition out of the helper's
no-marker or empty-domain path would have passed all three unnoticed, against
`spec.md` §`.restrict_to_domain(converted)` Errors and Warnings.

What changed, in `tests/testthat/test-conversion.R` only:

- The `withCallingHandlers` collector moved out of the last block into
  `collect_surveycore_classes()`, defined once after the two fixtures at the
  top of the section. It returns the surveycore classes among every condition
  the call signals, `character(0)` when there are none, and evaluates the
  expression in the calling block, so
  `collect_surveycore_classes(sv <- as_svydesign(d))` leaves `sv` behind as
  `expect_warning()` does.
- The three blocks each replace `sv <- suppressWarnings(as_svydesign(d))` with
  that call plus `expect_identical(classes, character(0L))`. Every existing
  assertion stays.
- The last block calls the shared helper instead of its own local copy. Four
  blocks now share one collector.
- No `expect_no_condition()` and no `expect_no_warning(expect_warning(...))`
  on this route. The `suppressWarnings()` on the `survey::svymean()` calls
  stays: the claim is about the conversion, not about estimation.

The block count is unchanged at 11; the fix adds three expectations and no
`test_that()`. Measurements after the fix: `devtools::test(filter =
"conversion")` FAIL 0, WARN 0, SKIP 0, PASS 790 (was 787).
`air format --check` exits 0. The full suite was not re-run, per the
re-dispatch instruction.

Non-vacuity check on the shared collector: run on a function that raises
`cli::cli_warn(class = "surveycore_warning_fake")` inside an assignment, it
returns `"surveycore_warning_fake"` and the assignment still lands in the
caller. So the three new expectations can fail.

## Signals raised

None. No HOLD.

## Notes for tester

- The parity oracle is a `survey::twophase()` call written out in the block
  rather than a `get_means()` comparison. `get_means()` cannot be the reference
  on this route: the two estimators weight differently and disagree on an
  unfiltered design as well. Block 2 measures that disagreement rather than
  working around it.
- `sv$variables` is `NULL` on a `twophase2` object, not an empty frame. That is
  why the un-branched helper returned the object unchanged instead of raising:
  `names(NULL)` is `NULL`, so the presence check was simply `FALSE`.
- The fixture design raises no condition at all, in either direction.
  `survey`'s untyped single-PSU warning from `[.twophase` does not fire on a
  domain this wide. The collector block therefore passes on an empty condition
  list; it is written to tolerate that warning rather than to require it.
- `surveytidy` is installed on this machine. No block in the new section uses
  it — every marker is written by hand, because a two-phase design's marker has
  to reach `@data` at the phase-1 level for the phase-1 sample to carry it.
- Block 9 asserts `expect_false(all(expected))` and `expect_true(any(expected))`
  so that a fixture change which made the domain all-`TRUE` or empty would fail
  here rather than pass vacuously.
