# Review — PR 4 — as-svydesign-domain-twophase

**Verdict**: PASS
**Date**: 2026-09-11

Branch `fix/as-svydesign-domain-twophase` at `9daf70e`, tree
`4889ae06f8dc60db7e376aa7cc122fcd180467f5`, cut from `develop` at `9625c18`,
which is `origin/develop`. The tree hash matches the one `audit.md` records and
the one `logs/pr-4-fix-summary.txt` prints. Three commits: `7533c12` the
production change, `0e15135` the tests, `9daf70e` the BLOCK fix (test file
only). The local `develop` ref is `a545505`, three commits behind; every diff
below is against `origin/develop`.

## Convergence checks

- Spec coverage: yes, for this PR's slice. All ten allocated rows plus the
  §Invariants requirement have a block on this tree, and every block passes.
- Test coverage of spec: yes. Each row maps to an entry in `spec.md`
  §`.restrict_to_domain(converted)` → Arguments, Returns and Edge cases, the
  §Route matrix two-phase line, §`as_svydesign(x)` → Warnings, or
  §`from_svydesign(x)` → On the two-phase route.
- Tolerance integrity: yes. Point 1e-10 and SE 1e-8 on every numeric
  comparison, which is `test-spec.md` §Tolerances unchanged.
- Scope discipline: yes. Two files, 336 insertions, 4 deletions.
- Regression safety: yes. FAIL 0, WARN 256, SKIP 4 before and after. Passing
  expectations move 11749 to 11800.

## Row ledger — who covers what

The new section runs from `tests/testthat/test-conversion.R:3778` to the end of
the file. Line numbers below are absolute.

| Row | Covering block (line) | Assertions the row asked for |
|---|---|---|
| B-1 | `converts a filtered two-phase design to the domain [numerical]` (3861) | parity point 1e-10 and SE 1e-8 against a hand-restricted `survey::twophase()` oracle; carries the one new `test_invariants()` call |
| B-2 | `the two-phase estimators weight differently on an unfiltered design [numerical]` (3900) | both hand computations to 1e-10, then the differ-assertion |
| B-3 | `leaves one finite probability per marked phase-2 row` (3926) | `expect_identical()` on the finite count, no row count |
| B-4 | `converts a filtered two-phase design that names no phase-2 ids` (3942) | the file's own `make_twophase()`, no error, same finite count |
| C-3 | `converts an unfiltered two-phase design unrestricted` (3964) | row counts, marker absent, all probabilities finite, no surveycore condition |
| D-2c | `converts an all-FALSE two-phase marker to no finite probability` (3988) | row count unchanged, no finite probability, `is.nan()`, no surveycore condition |
| D-5b | `converts an all-NA two-phase marker to no finite probability` (4008) | same |
| D-7 | `the marker column survives a Taylor conversion with every value TRUE` (4030) and `... a two-phase conversion with its values unchanged` (4043) | presence and all-`TRUE` on the Taylor route; presence and unchanged mixed values in the phase-1 sample frame |
| F-6 | `the round trip on a filtered two-phase design rebuilds the full phase-1 frame` (4062) | `expect_identical()` on the rebuilt row count and on the marker vector |
| G-1c | `raises no surveycore condition on a filtered two-phase design` (4302 rel. 314) | the class-pattern assertion, not `expect_no_condition()` |

I read every cited block. Each sits where the audit says it does. The section
holds 11 `test_that()` blocks for 10 rows, because D-7 is written as two
blocks, one per kind of route. No block claims a row another PR already
shipped.

## The eight points the dispatch asked me to check

**1. The BLOCK fix is sound.** `collect_surveycore_classes()` is defined once
at `tests/testthat/test-conversion.R:3836` and called by four blocks — C-3,
D-2c, D-5b and G-1c. It is the technique `test-spec.md` §G-1c prescribes, and
not `expect_no_condition()`, which appears nowhere in the section except in two
comments that say why it cannot be used. Four properties check out by reading:

- It captures **every** condition, not only warnings: the handler is registered
  on `condition`, appends each one to `seen`, and the `grep("^surveycore_",
  class(cnd))` runs over the full class vector of each. A `cli::cli_warn(class
  = "surveycore_warning_*")` therefore lands, and so would a message or a
  bare condition of that class.
- It muffles only what it must. `invokeRestart("muffleWarning")` fires for a
  warning and `"muffleMessage"` for a message, so `survey`'s untyped noise does
  not reach testthat. Errors get no restart, so an error still propagates and
  the block fails loudly.
- It leaves the assigned result behind. `expr` is a promise and `force(expr)`
  evaluates it in the calling block's frame, so
  `collect_surveycore_classes(sv <- as_svydesign(d))` binds `sv` in the block
  exactly as `expect_warning()` does. Each of the three swapped blocks then
  reads its pre-existing assertions off that `sv`, and every one of those
  assertions survived the fix.
- It cannot pass vacuously. With no condition, `unlist(list())` is `NULL` and
  `as.character(NULL)` is `character(0)`, which is what the blocks assert; the
  builder's recorded non-vacuity check raised a fake
  `surveycore_warning_fake` inside an assignment and got the class back with
  the assignment still landing.

The G-1c block was refactored to call the shared helper in place of its own
local closure. That is a DRY consolidation of one technique across four blocks,
not a change of claim.

**2. The frame branch lives inside the helper and nowhere else.** `git diff
origin/develop...HEAD -- R/` is 21 lines and holds three things: the helper
comment paragraph rewritten, one `inherits(converted, "twophase2")` branch at
`R/methods-conversion.R:69-73`, and the `converted <- survey::twophase(...)`
capture plus `.restrict_to_domain(converted)` at `:471-484`. The mask
expression (`r <- as.logical(...)`, `converted[r & !is.na(r), ]`, lines 79-80)
and the column-presence check (line 75) are byte-identical to `develop`. No
call site passes a frame, no call site gained a branch, and nothing reads a
`repweights` key — so `spec.md` §Out and issue #246 hold and no ninth copy of
the non-probability routing predicate exists.

Counted on the final state of the file: one definition of `.restrict_to_domain`
(line 68), taking one argument, and exactly three call sites — `:271` inside
`.as_svydesign_taylor()` (which starts at 240), `:438` inside
`.as_svydesign_replicate()` (277), `:484` inside `.as_svydesign_twophase()`
(444). `grep -rn "restrict_to_domain" R/` finds nothing outside
`R/methods-conversion.R`. The frame branch, the presence check and the mask
each appear once.

**3. B-2 is the estimator-gap row and it pins the gap rather than closing it.**
The block computes `weighted.mean(frame$y1, frame$wt)` against `get_means(d,
y1, variance = "se", min_cell_n = 1L)` and `weighted.mean(frame$y1, 1 /
sv$prob)` against `survey::svymean()`, each `expect_equal(..., tolerance =
1e-10)`, then asserts `expect_false(isTRUE(all.equal(by_phase1_weight,
by_combined_prob)))`. The audit records both values: 48.9245 and 49.20304, the
pair `spec.md` §Out names. The differ-assertion is therefore not vacuous — the
two numbers are recorded and they are 0.28 apart, far outside the
`all.equal()` default. The block contains no attempt to reconcile the two
estimators, and `spec.md` §Out keeps the gap with issue #261.

**4. B-3 and B-4.** B-3 asserts
`expect_identical(sum(is.finite(sv$prob)), marked_phase2)` where
`marked_phase2` is `sum(marker & subset)` off the design's own data; both sides
are integer, so `expect_identical()` is the right instrument. The block asserts
no row count, as `test-spec.md` §B-3 requires. B-4 calls the file's own
`make_twophase()` at line 96, and `git diff` on the test file shows zero
deleted lines — the fixture is untouched.

**5. D-7 and F-6.** Both use `expect_identical()`. D-7's two-phase half asserts
the converted marker is identical to `df[[col]][df$subset]`, then
`expect_false(all(expected))` and `expect_true(any(expected))`, so a fixture
change that made the domain full or empty fails here rather than passing
vacuously. That is stricter than the row, which asks only for presence. F-6
asserts the rebuilt row count (60) and the marker vector identity; identity
subsumes the `TRUE` count the row asks for.

**6. Tolerance integrity.** Four numeric comparisons in the section: B-1 point
at 1e-10, B-1 SE at 1e-8, B-2's two hand computations at 1e-10. Those are
`test-spec.md` §Tolerances with no deviation, and `audit.md` §Per-Test Result
Table reports the same four numbers against the same four tolerances. Nothing
is looser. Every other row uses `expect_identical()`, `expect_true()` or
`expect_false()`, which is what the same section prescribes for counts, names
and structure. The fix commit touched only condition assertions, so it could
not have moved a tolerance.

**7. Scope.** `git diff --stat origin/develop...HEAD`:

```
 R/methods-conversion.R           |  21 ++-
 tests/testthat/test-conversion.R | 319 +++++++++++++++++++++++++++++++++++++++
```

That is the plan's Files touched line for PR 4, exactly. The test file's diff
is one hunk appended at the end with zero deleted lines, so no existing block
changed — which matches `test-spec.md` §Existing rows whose assertions change,
"None". `git diff origin/develop...HEAD -- tests/testthat/_snaps` is empty.
`NAMESPACE`, `man/`, `NEWS.md`, `DESCRIPTION` and `plans/error-messages.md` are
byte-identical to `origin/develop`. The worktree carries one modified and four
untracked files under `plans/`; they are the arc's planning artifacts, outside
every PR's write surface, and the shipper keeps them out of the commit. Not
scope creep.

`test_invariants(`: 6 on `origin/develop`, 7 on this branch. The one new call
is in the B-1 block, for `as_survey_twophase()`, which is the constructor the
file carried no call for. None was added for the other three constructors and
none in B-2, B-3 or B-4, per `test-spec.md` §Invariants and the plan's
criterion 7.

**8. Gates.** All seven ran in one unkilled call on tree `4889ae0` and all
seven passed. The two memory-watchdog kills recorded in `decisions.md` §PR 4
gate run belong to the earlier tree `d9d7a16` and are superseded: the summary
this audit accepts comes from `logs/pr-4-fix/`, whose `Tree:` line equals
`git rev-parse HEAD^{tree}`.

## Profile gates

| Gate | Result | Verified against |
|---|---|---|
| `devtools::document()` | PASS | `logs/pr-4-fix/gate-1-document.log`; `man/` and `NAMESPACE` diffs empty |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11800 |
| `devtools::run_examples()` | PASS | `logs/pr-4-fix/gate-3-examples.log` |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | `logs/pr-4-fix/gate-5-check.log`, `Status: 2 NOTEs` |
| pkgdown | PASS | run, not skipped; the write surface touches `R/` |
| covr | 96.25% | `logs/pr-4-fix-summary.txt` |
| CRAN cookbook scan | None | one `R/` file, 21 lines, no pattern matches |

No gate was skipped, so no skip needs a justification. The two NOTEs are
`checking CRAN incoming feasibility`, which is pre-approved, and the `.git`
hidden-file NOTE, which is not new — it appears at the same count in every
check log of this run, and `archive/as-svydesign-bridge/` records
`.Rbuildignore` as its cause. No new NOTE pattern, so nothing escalates.

The cookbook scan covers `R/` only. The `<<-` in the new test helper is in
`tests/`, outside the scan's scope, and it assigns into the closure's own
`seen` list rather than a global. `R/` holds no `<<-` this PR added.

Coverage: 96.25%, above the 95% floor, equal to the PR 1, PR 2 and PR 3
figures, and above the 96.24% baseline. Nothing dropped. The summary's
`changed R/ files: 2, uncovered lines in them: 4` is the stale-local-ref
misreport: `run-gates.sh` diffs against the local `develop` ref at `a545505`,
which still lists PR 0's `R/analysis-means-helpers.R`. Against `origin/develop`
this PR changes one `R/` file, at 99.77%, and its only uncovered line is 586 —
the `} # nocov — callers always pass non-NULL` early return inside
`.find_col_by_value()`, a helper this PR does not touch. The five production
lines the PR adds run on every two-phase conversion in the suite, so no new
line is uncovered. The builder's sensitivity check corroborates it: with the
call site replaced by `converted`, eight expectations fail across five of the
eleven new blocks.

The four skips sit in `test-glm-anova-numerical.R`, `test-glm-anova.R` and
`test-srr-compliance.R`. None is in `test-conversion.R`, so `survey` was
installed and all eleven new blocks ran.

## Cross-consistency notes

`implementation.md` and `audit.md` describe the same system. Both name the same
base, the same tree, two files, one new call site, eleven blocks, one new
`test_invariants()` call and the same ten rows. Three notes, none a verdict
item:

- **B-4 pins one half of its row in the audit and not in the suite.**
  `test-spec.md` §B-4 asks that the conversion "returns a two-phase object and
  raises no error". The block asserts `expect_no_error()` and the
  finite-probability count; it does not assert the returned object's class. The
  audit's reproduction measured it — `class = c("twophase2","survey.design")` —
  so the claim is verified, and the class is forced by the S7 dispatch in
  `as_svydesign()`, which this PR does not touch. The finite-count assertion
  alone would not discriminate a different class. One `expect_s3_class()` would
  close it. PR 5 adds no test block, so this stays a known state rather than a
  task.
- The estimator-gap pair `spec.md` §Out records for the unfiltered design is
  "48.9 against 49.203". The block measures 48.9245 against 49.20304, which is
  the same pair at more digits. No disagreement.
- `min_cell_n = 1L` reaches the section's one `get_means()` call, per
  carry-forward item 5 from the PR 3 review. The suite's warning total holds at
  256.

One process deviation, recorded and accepted, as on PRs 2 and 3. The tester did
not run the gates; the dispatching session ran them and `audit.md` states that
it accepts the printed summary. I read `logs/pr-4-fix-summary.txt` and the
check log, and every figure the audit reports matches.

## Decision

PASS. The production change is 21 lines: one frame branch inside the helper,
one call site, and a comment. The helper keeps one argument, one presence
check, one mask and one `[` call, and the file now holds exactly three call
sites, one per route. All ten rows are covered at the test-spec's own
tolerances, none twice, and the §Invariants requirement is met with exactly one
new call. The BLOCK fix replaced three bare `suppressWarnings()` calls with a
shared collector that captures every condition, muffles only warnings and
messages, leaves the assignment in the caller, and cannot pass vacuously — the
technique §G-1c prescribes, applied to four blocks. Scope, snapshots, coverage
and all seven gates are clean.

## Carry-forward into PR 5

1. **The plan's roxygen line numbers are stale.** PR 5 task 2 names
   `R/methods-conversion.R:88-100` for the `@section A filtered design's
   domain:` block and task 3 names `:43-50` for `@return`. On this tree the
   section is at **143-155** and `@return` is at **98-105**. The helper's
   comment grew across PRs 1, 3 and 4, which moved everything below it. Read
   the block by its tag, not by its line number.
2. **The section still documents the defect as intended.** Lines 144-155 say
   "The converted object represents the full stored sample and not the active
   domain" and tell the caller to run `subset(converted,
   ..surveycore_domain..)`. Both claims are false on all five routes now. PR 5
   criterion 1 depends on both sentences going.
3. **Criterion 8's counts, read on this tree.** One definition of
   `.restrict_to_domain` at line 68, one argument, three call sites at 271,
   438 and 484 — `.as_svydesign_taylor()`, `.as_svydesign_replicate()`,
   `.as_svydesign_twophase()` in that order. The frame branch (69-73), the
   presence check (75) and the mask (79-80) each appear once, all inside the
   helper. `grep -rn "restrict_to_domain" R/` returns nothing outside
   `R/methods-conversion.R`. `git diff --stat origin/develop...HEAD` for PR 5
   must show no change under `tests/`.
4. **What the helper comment now carries, and what it does not.** The comment
   at 37-50 names all three classes and says where each keeps its frame, and a
   new paragraph records that the two-phase route sets an infinite probability
   rather than removing a row. That covers the first half of
   `spec.md` §Documentation contract item 7. It does **not** mention the
   estimator gap, the second half of item 7. PR 5 takes that from `spec.md`
   §Out and from the B-2 block's own comment at
   `tests/testthat/test-conversion.R:3893-3899`; the measured numbers are
   58.458 against 58.067 filtered and 48.9245 against 49.20304 unfiltered.
   `spec.md` says to state the difference and to cite no issue number in
   user-facing documentation.
5. **The two-phase round trip is the exception item 8 needs.** F-6 measures it
   on this tree: the rebuilt design carries all 60 phase-1 rows and the
   original mixed marker, so it prints two different counts where the other
   four routes print the same number twice.
6. **One state no row asserts, carried from the PR 3 review and unchanged.**
   `spec.md` says the stored call survives the restriction on every route;
   F-2 pins it on the Taylor route only. The helper has one body and one
   operator, so the claim is pinned once. PR 5 adds no test block, so this
   stays open for a later reader.
7. **Ledger.** Tester BLOCKs for PR 4: 1. Reviewer BLOCKs: 0.
