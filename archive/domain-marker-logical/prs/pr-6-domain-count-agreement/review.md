# Review — PR 6 — domain-count-agreement

**Verdict**: PASS
**Date**: 2026-09-15 19:30

Tree `40117b04b851f4b3c6b3fd4d44f364a0a5f796ec`, commit `ce0c89d`, base
`a578b46`. Test-only PR: two files, +142 lines, append-only.

## Convergence checks

- Spec coverage: **y**. This PR changes no production file, and it is not
  required to. `implementation-plan.md` PR 6 states "No production file
  changes." Its eight rows validate two spec contracts that shipped earlier:
  the printed domain line against the analysis count (`spec.md` §PR map,
  PR 3's stated behaviour), and the column-absent branch of `.apply_domain()`
  (`spec.md` §Function contracts, `.apply_domain()` §Edge cases, "No domain
  column").
- Test coverage of spec: **y** for this PR's surface. One spec edge case has
  no test row anywhere in the arc — see §Observation 3. It belongs to PR 2
  and PR 3, both merged, and it is recorded, not charged to PR 6.
- Tolerance integrity: **y**. `test-spec.md` §Tolerances makes §4 an
  `expect_identical()` section and applies no numeric tolerance to §6.
  `audit.md` reports `identical` on rows 4.1 to 4.4, 6.1 and 6.2, and
  `n/a (structural)` on 6.3 and 6.4. No row is looser than the test-spec. I
  read the eight blocks in the diff: every numeric comparison is
  `expect_identical()`, and no `tolerance =` argument appears.
- Scope discipline: **y**. `git diff --name-only a578b46..HEAD` returns
  exactly `tests/testthat/test-analysis-helpers.R` and
  `tests/testthat/test-methods-print.R`, which is the plan's Files touched
  list, file for file. `git diff --name-only a578b46..HEAD -- R/ man/
  NAMESPACE` returns zero files. `tests/testthat/helper-test-data.R` is
  unchanged. No file under `tests/testthat/_snaps/` is in the diff.
  `git status --porcelain R/ man/ NAMESPACE tests/` prints nothing.
- Regression safety: **y**. `devtools::test()` reads `FAIL 0` before and
  after; passes rise 11912 to 11935 (+23); warnings hold at 256 and skips at
  4. The two `test-analysis-helpers.R:1429/1430` failures appear under
  `devtools::load_all()` only, sit on the untouched base, and are settled.

## Acceptance criteria, one at a time

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Rows 4.1 and 4.3 pass; line reads `Domain: n of N`; no snapshot; `_snaps/methods-print.md` gains no entry | Met | Two blocks in the diff at `test-methods-print.R` section 57. Row 4.1 asserts `counts$n == sum(pair$mask)` (148L) and `counts$total == nrow(pair$a@data)` (200L). Row 4.3 asserts `domain_line(pair$a)` identical to `domain_line(pair$b)`. `expect_snapshot` appears in no added line; the diff touches no `_snaps/` file. |
| 2 | Row 4.2: printed `n` and ungrouped `get_means()` `n` identical | Met | `expect_identical(domain_counts(pair$a)$n, result$n)`, both integer, both 148L. The two sides come from different code — see §The finding. |
| 3 | Row 4.4: two-phase line reports phase-2 counts; design B identical | Met | The block asserts `counts$n == sum(pair$mask & ph2)` (52L), `counts$total == sum(ph2)` (74L), `anyNA(ph2)` false, and the A/B line identity. It also asserts its own precondition with `expect_lt(sum(pair$mask & ph2), sum(pair$mask))`, so it cannot go vacuous in silence. |
| 4 | Rows 6.1 and 6.2 pass | Met | Two blocks in `test-analysis-helpers.R` category 17. Row 6.1 asserts the marker column is absent and `result$n == nrow(design@data)` (200L). Row 6.2 asserts one row per `group` level and `sum(result$n) == nrow(design@data)`. |
| 5 | Row 6.3: no `Domain:` line | Met | `expect_false(any(grepl("^Domain: ", out)))`, with `expect_gt(length(out), 0L)` first, so an empty capture cannot pass the row. |
| 6 | Row 6.4: the assignment raises no condition | Met | `expect_no_condition(design@data <- new_data)`, plus two read-back assertions. |
| 7 | No `R/`, `man/` or `NAMESPACE` change; `helper-test-data.R` unchanged | Met | The two `git diff --name-only` runs above. |
| 8 | Gates 2, 5 to 12, gate 13 and the CRAN cookbook scan | Met | `gates/pr-6/summary.log` reads ALL GATES PASS on tree `40117b0`. I re-ran the three source greps, which are reads and not test runs: gate 1 returns nothing; gate 2 returns the two `R/analysis-t-test.R` writes, both logical, unchanged from the base; gate 13 returns exactly `R/analysis-helpers.R`, `R/analysis-t-test.R` and `R/glm-anova.R`. Gate 5 is vacuous — the PR adds no `cli::cli_abort()`. `air format --check` exits 0 on both files (`implementation.md` §Test runs). |

`test_invariants()` count: 3 in `test-methods-print.R` and 3 in
`test-analysis-helpers.R`, on the base and on this tree. I counted both with
`git show a578b46:<file> | grep -c` against `grep -c` on the tree. The audit's
3 to 3 figure is confirmed. No new call, per `test-spec.md` §Invariants.

## The finding: the plan's ordering rationale is wrong for three of four rows

`implementation-plan.md` §Why six PRs and not three says the §4 rows "land
after PR 4, which changes the count they compare against". The tester's
non-vacuity probe shows that only row 4.2 moves when `.apply_domain()` is
reverted to its pre-#275 body. Rows 4.1, 4.3 and 4.4 pass unchanged.

**I confirmed the mechanism by reading the source, not by re-running the
probe.** `.print_domain_info()` at `R/methods-print.R:171-186` computes
`sum(x@data[[SURVEYCORE_DOMAIN_COL]], na.rm = TRUE)`. It reads `@data` and
`x@variables$subset` directly and calls `.apply_domain()` nowhere. Its
`na.rm = TRUE` already gave an `NA` marker the reading that #275 gave the
analysis side. So the printed count was correct before #275 and is correct
after it, and three of the four rows cannot move.

**This is a defect in the plan's rationale, not in the tests.** Three reasons.

1. **The ordering conclusion is right for a second reason the plan states
   elsewhere.** §Fixture ownership records that `make_domain_pair()` is added
   by PR 4 and read by PR 5 and PR 6. All eight of PR 6's rows take their
   fixture from that helper, so PR 6 must follow PR 4 whatever the print
   method reads. The wrong reason sits beside a right one in the same
   document.
2. **The three rows assert a real property.** Design A carries three `NA`
   markers. A print method that summed the column unguarded would render
   `Domain: NA of 200` and fail row 4.1's regex; one that counted `NA` as
   in-domain would render 151 and fail rows 4.1 and 4.3. Row 4.4 pins the
   two-phase route, which counts over `x@variables$subset` and is the only
   other branch of the method. The rows constrain the print method's own `NA`
   handling. That is not the property the plan named, and it is worth
   holding.
3. **Row 4.2 alone carries the count-agreement contract, and it carries it.**
   The left side is parsed out of rendered text after `cli::ansi_strip()`; the
   right side is the `n` column of `get_means()`, which reaches the mask
   through `.apply_domain()`. Neither side reads `pair$mask`, and neither is
   derived from the other. Both are integer, so `expect_identical()` cannot be
   loosened by coercion. Under the pre-#275 helper the analysis side aborts
   with "missing value where TRUE/FALSE needed", so the row could not have
   passed before PR 4. It is the arc's one point of contact between the two
   paths, and it is a genuine cross-check.

**Nothing is missing as a result.** The wrong rationale concealed no gap. I
checked the one place where a gap could hide: whether the two-phase analysis
count agrees with the two-phase printed count, which no row compares.
`.twophase_mean_cell()` at `R/analysis-means-helpers.R:221-271` sets
`n_d <- as.integer(sum(domain[subset]))` — the in-domain count among phase-2
rows, the same quantity `.print_domain_info()` prints for that class. The two
routes agree by construction, and row 4.4 asserts the printed side against the
same expression (`sum(pair$mask & ph2)`) that the analysis side computes. A
second cross-check on the two-phase class would add a second instrument, not a
second property. Recorded as §Observation 1, not as a missing row.

**Route: log it, as D23 and D25 were logged.** The repair is one sentence in
`implementation-plan.md` §Why six PRs and not three: replace "which changes the
count they compare against" with "which adds the fixture all eight rows read,
and which row 4.2 compares the printed count against". That edit belongs to a
plan revision, and this arc is frozen. No test changes, and no artifact of this
PR changes.

## Row 4.4's arithmetic

The tester's figures are 200 rows, 74 phase-2 rows, 149 in-domain over all
rows, 52 in-domain and in phase 2. I derived the same numbers from
`make_domain_pair()` at `tests/testthat/helper-test-data.R:1215-1226` without
running it:

- `stored` starts all `TRUE`; `seq(2, 200, by = 4)` sets 50 elements `FALSE`,
  leaving 150.
- Rows 3, 47 and 130 take `NA`. Rows 3 and 47 were `TRUE`, row 130 was already
  `FALSE`, so the resolved mask holds 148 `TRUE` — the Taylor figure.
- The two-phase branch flips one row outside phase 2 back to `TRUE`, giving
  149. That is the whole-sample count the printed line must not report.
- 74 minus 52 leaves 22 phase-2 rows out of domain, against about 18 from the
  every-fourth rule plus the `NA` rows. The two counts are consistent, and the
  gap between 149 and 52 is far wider than either route's rounding.

The row is meaningful: a print method that counted the whole sample would
report `149 of 200`, and both asserted numbers would fail.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every measured figure: the same
two files, the same counts 148/200 and 52/74/149/200, the same block and
expectation totals, the same two pre-existing `load_all()` failures, the same
`test_invariants()` count. The audit reports +72 and +76 added lines where the
diff reads +69 and +73; the difference is the blank lines at each join, and the
file list and the block count match. Not a finding.

`audit.md` records the §4 non-vacuity result as an observation and states
plainly that "a claim that all four rows failed before #275 is wrong for three
of them". The tester did not hide the contradiction with the plan. The audit's
PASS is consistent with it, because the plan's acceptance criteria 1 to 3 ask
what the rows assert, not what they would have failed at an earlier commit.
Task 4 in the plan does make the wider claim ("would have failed before PR 4"),
and the builder ticked it. The builder's own §Measurements states the narrower
truth for the count-agreement block. A ticked task box over a wrong plan
sentence is a documentation defect, and it routes the same way as the finding
above.

## CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None". Seven profile gates each
carry a result and all read PASS. The eight audited blocks carry no
`skip_if_not_installed()`, and the file-level skips behind SKIP 4 are
pre-existing and allowed by `r-package-profile.md`. The gate run was not
repeated here, per the standing low-memory instruction, and the logs are at
`gates/pr-6/`.

Coverage: 96.15% after, 96.15% before, above the 95% floor and flat. The PR
adds no line under `R/`, so no new line can be uncovered. The summary log's
"changed R/ files: 3" is the D22 stale-ref artifact; `git diff --name-only
a578b46..HEAD -- R/` returns zero files, which settles it.

## Observations, none of them a finding against this PR

1. **No row compares the two-phase printed count against a two-phase analysis
   count.** `test-spec.md` §4 gives the cross-check to row 4.2 on the Taylor
   class alone. The two routes agree by construction, as shown above. A future
   row would be cheap and would pin the agreement on the class where the print
   method takes its second branch.
2. **`make_domain_pair()` writes three `NA` markers, where `test-spec.md`
   §Fixture helpers describes one.** Two of the three would otherwise be
   `TRUE`. The wider difference strengthens §4 and §6. The helper shipped with
   PR 4 and this PR may only read it.
3. **One spec edge case has no test row in the arc.** `spec.md` §Function
   contracts, the validator's §Edge cases, says a one-column logical matrix and
   a logical vector carrying any other class attribute both pass. No row in
   `test-spec.md` §2 asserts the matrix shape. The shipped body at
   `R/core-classes.R:355` is a bare `!is.logical(...)` test, so the stated
   behaviour follows from the code by inspection. The gap belongs to PR 2 and
   PR 3, both merged with a PASS review. Recorded for the archive.
4. **`capture_cli_lines()` in `test-analysis-helpers.R` duplicates
   `capture_design_output()` in `test-methods-print.R`.** A function defined in
   one test file is not visible in another, so the copy is forced inside this
   PR's write surface. Promoting one of them to `helper-test-data.R` is a later
   change.

## Does the arc close?

With PR 6 merged, every one of the 46 rows in `test-spec.md` §1 to §6 and
§Existing blocks is claimed by exactly one PR, shipped, and audited. The row
ledger's counts — 8, 4, 12, 9, 5, 8 — sum to 46, which equals the test-spec
total. Nothing in §1 to §6 stays unproven.

`spec.md`'s three stated behaviours all hold:

- The write of a non-logical marker aborts on all four concrete classes, and a
  logical write does not (PRs 1 to 3).
- An `NA` marker and a `FALSE` marker return the same numbers from every
  analysis function in §3 (PR 4).
- The printed domain count agrees with the count the analysis functions use
  (row 4.2, this PR), and the conversion routes still read an `NA` marker as
  outside the domain (PR 5).

Two carried items, both recorded and neither a defect in this PR:

- **Issue #276.** `.restrict_to_domain()` tests only the `twophase2` class, so
  a `method = "approx"` two-phase design converts unrestricted. Deferred to its
  own PR by D25. It is out of scope here: `.print_domain_info()` reads `x@data`
  and `x@variables$subset` and builds no `survey` object, so the defect is
  invisible to every row in this PR. Row 5.3 proved the `NA` reading on a
  `method = "full"` design, which is the contract `spec.md` states.
- **The plan's ordering sentence**, above. A documentation repair for the plan
  revision, in the shape of D23 and D25.

## Decision

PASS. The write surface matches the plan file for file, all eight acceptance
criteria are met with evidence, no tolerance moved, the gates are clean, and
coverage holds above the floor with no new `R/` line to cover. The one
contradiction the tester surfaced is between the plan's stated reason for the
PR order and the measured behaviour of three rows. The rows assert a real
property, the ordering conclusion holds on the fixture dependency the plan
records elsewhere, and row 4.2 carries the count-agreement contract on its own.
That is a documentation finding for the plan revision, not a defect in the code
or the tests, so it does not block the merge.
