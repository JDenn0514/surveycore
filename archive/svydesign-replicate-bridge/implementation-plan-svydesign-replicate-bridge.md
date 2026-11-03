# Implementation plan — svydesign-replicate-bridge (#197, #198)

**Version:** 2.0
**Date:** 2026-09-08
**Sources:** `spec.md` v1.1, `test-spec.md` v1.1, `decisions.md` D1–D10,
`impact.md`, `plan-review.md` pass 1

Version 2.0 replaces the two pull requests of version 1.0 with five, per
decision D8. It also applies D9 and D10, findings R1 to R4, the reclassified
documentation fix, and suggestions S1, S3 and S4 from `plan-review.md`.

---

## Shape of the plan

Five pull requests, shipped one after the other.

| # | Branch | Carries | `spec.md` §I.1 rows |
|---|---|---|---|
| 1 | `fix/svydesign-replicate-bridge` | Expansion, generated names, the unconditional write | 1, 2, 3 |
| 2 | `fix/svydesign-replicate-foldin` | The fold-in, the values that pass through, the documentation surface | 6, 12 |
| 3 | `fix/svydesign-replicate-guards` | The name guards, the type guard, the empty-data guard | 4, 5, 7, 8 |
| 4 | `fix/svydesign-replicate-fpc` | The FPC drop, the empty-replicate guard | 9, 11 |
| 5 | `fix/svydesign-replicate-fay` | Fay's shrinkage factor, the full round trip | 10 |

**Why five.** D8 records the decision and the reason. Each pull request closes
one defect or one condition family, and each one's test rows can go green on
its own code. Pull request 1 removes the silent loss that issue #197 reports.
Pull request 2 removes the wrong standard error, and carries the documentation
because `spec.md` §II.3 requires the block to state the fold-in, which is not
true until that code lands. Pull request 3 carries the three refusals. Pull
requests 4 and 5 split the export route the same way: the FPC drop and the
empty-replicate guard need nothing from Fay, and the round-trip rows wait for
the last one because they need both routes finished.

**All five are sequential, never concurrent.** Every one writes
`R/methods-conversion.R` and `tests/testthat/test-conversion.R`. Each branches
from `develop` after its predecessor merges, and must not be open while its
predecessor is open. Each entry below repeats that instruction.

**Every pull request leaves the full test suite green.** A test block is
written in the pull request that makes it pass, not earlier. §Test row
allocation assigns each of the 58 rows in `test-spec.md` to exactly one pull
request, and each pull request's acceptance criteria name its own rows.

**The cost.** Five rebases on one source file instead of one. The user
accepted that cost for the reviewability (D8).

---

## PR map

### PR 1 — expansion, generated names, the unconditional write

- [x] **PR 1: `fix/svydesign-replicate-bridge`** — `from_svydesign()` expands
      the replicate matrix, resolves one name per replicate column, and writes
      every column into the design data on every conversion.

  Branch from `develop`. This is the first pull request of the five, so it has
  no predecessor.

  Carries `spec.md` §I.1 rows 1, 2 and 3, and §III.2 steps 2, 4, 5, 6, 10, 11,
  12 and 13. The guards at steps 1, 3, 7 and 8 land in PR 3; the fold-in at
  step 9 lands in PR 2.

  **Tasks** (2–5 minutes each)

  *Fixtures.*

  1. Add the `test-spec.md` §3.1 fixture (`rep_bridge_taylor`) to the fixture
     section at the top of the test file. Verify it returns a list whose `sv`
     element inherits `"survey.design"`.
  2. Add the §3.4 fixture (`rep_bridge_combined`), both recipes. Verify the
     `named = FALSE` object reports `combined.weights` `TRUE` and a zero-length
     `colnames()`, and that `survey::compressWeights()` on the `named = TRUE`
     object raises nothing.
  3. Extend the header comment index of the test file with one entry per
     section this pull request adds. Verify the index order matches the block
     order in the file.

  *Failing blocks — the cells that need no fold-in.*

  4. Open the new `test-spec.md` §6.1 oracle section and write the failing
     blocks for rows I-3 and I-4, each with its own cell C and cell D
     precondition assertions. Leave the I-1 and I-2 slots empty at the top of
     the section for PR 2. Verify both blocks fail on the current code.
  5. Put the one `test_invariants()` call for `from_svydesign()` in the I-3
     block — the first block in the file that converts a `svyrep.design` after
     this pull request. Verify the file holds exactly one such call. PR 2 moves
     it into the I-1 block, which then becomes the first such block.
  6. Write the failing blocks for rows I-5, I-6 and I-7, each with its cell A
     precondition assertions. Verify all three fail, and that I-7 fails with
     `surveycore_error_all_replicates_na` — the silent-loss defect surfacing at
     analysis time.
  7. Write the failing blocks for rows I-8 and I-9. Verify both fail: I-8 on
     twenty replicates and I-9 on four.
  8. Write the blocks for rows I-10, I-11 and I-21. Verify I-10 and I-11 pass
     on the current code, and I-21 fails.

  *Implementation.*

  9. Add the `.repwt_col_names()` helper above `.from_svydesign_replicate()`,
     from `spec.md` §II.2. Verify rows I-8 and I-9 reach their generated-name
     assertion — I-8 for twenty replicates padded to width 2, I-9 for four
     replicates unpadded. Add no direct unit test for the helper.
  10. Implement `spec.md` §III.2 steps 4 and 5: expand `x$repweights` with
      `as.matrix()`, strip the `"repweights"` class with `unclass()`, and count
      the columns.
  11. Implement step 6, the name resolution: generate names when
      `colnames(x$repweights)` has length 0, keep the source names otherwise,
      and record which branch ran. Add no check on the names — step 7 lands in
      PR 3.
  12. Implement steps 11 and 12: write one column per replicate on every
      conversion, and store the resolved names in `@variables$repweights` in
      replicate order.
  13. Confirm step 10 runs before step 11 — the base weight search must not
      reach the written replicate block — and reorder if it does not. Verify
      rows I-10, I-11 and I-21 pass.
  14. Verify rows I-3 to I-11 and I-21 pass.
  15. Run the full suite. Verify every block already in
      `tests/testthat/test-conversion.R` still passes with no edit to it, and
      that no other test file regresses.

  *Gates.*

  16. Run `air::format_package()`. Verify it produces no further diff.
  17. Run the full suite and the six profile gates in `test-spec.md` §12.
      Verify each pass condition.
  18. Run `covr::package_coverage()` with `NOT_CRAN=true`. Verify package
      coverage is at or above 95% and every new line in
      `R/methods-conversion.R` is reached, with no `# nocov` added.
  19. Run `git diff --name-only origin/develop`. Verify the list is exactly the
      two files below, that `NEWS.md` is absent, that no file under `man/`
      appears, and that neither `plans/error-messages.md` nor
      `tests/testthat/_snaps/conversion.md` appears.

  **Acceptance criteria** (all observable before merge)

  - Rows I-3, I-4, I-5, I-6, I-7, I-8, I-9, I-10, I-11 and I-21 pass — 10
    blocks. These are the only rows this pull request adds.
  - Point parity at `1e-10` and standard-error parity at `1e-8` in rows I-3 and
    I-4. This pull request adds no confidence-bound assertion: `test-spec.md`
    §6.1 gives the confidence-bound comparison to row I-1 alone, and I-1 lands
    in PR 2.
  - `expect_no_error(get_means(from_svydesign(sv), y1))` holds in row I-7 — the
    direct regression guard for the silent-loss defect.
  - Cells C and D each assert their own preconditions, and cell C fails rather
    than passes if the installed `survey` does not compress.
  - Row I-8 asserts twenty generated names zero-padded to width 2, and row I-9
    asserts four generated names unpadded. Together they are the whole check on
    `.repwt_col_names()`; no direct test of the helper exists.
  - Row I-21 asserts `d@variables$weights` is `"..surveycore_wt.."` and that
    the base weight name is not one of the replicate names.
  - Exactly one new `test_invariants()` call exists in the file, in the I-3
    block, for `from_svydesign()`.
  - Every block already in `tests/testthat/test-conversion.R` still passes, and
    no such block is edited.
  - No new `cli_abort()` or `cli_warn()` call appears in
    `R/methods-conversion.R`. This pull request adds no condition, so it adds
    no row to `plans/error-messages.md`.
  - `devtools::check()`: 0 errors, 0 warnings, at most the two pre-approved
    notes. (§VII gate 1)
  - `devtools::test()`: 0 failures and 0 warnings. (§VII gate 2)
  - `devtools::run_examples()` runs every example with no error.
  - `pkgdown::build_site()` builds with no error.
  - `covr::package_coverage()` with `NOT_CRAN=true`: at or above 95%, and 100%
    of the new lines in `R/methods-conversion.R` covered. (§VII gate 3)
  - `air::format_package()` produces no diff. (§VII gate 9)
  - `devtools::document()` leaves `NAMESPACE` unchanged and changes no file
    under `man/`. The new helper carries `@noRd`, so it generates no page.
    (§VII gate 8)
  - `git diff --name-only origin/develop` lists exactly:
    `R/methods-conversion.R`, `tests/testthat/test-conversion.R`. (§VII gate 6)
  - `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R`
    or `R/variance-replicate.R`. (§VII gate 11)
  - `git diff --name-only` does not list `NEWS.md`. (§VII gate 7)

  **Files touched**

  | File | Change |
  |---|---|
  | `R/methods-conversion.R` | The import replicate route: expansion, name resolution, the unconditional write, the step order around the base weight column; one new internal helper |
  | `tests/testthat/test-conversion.R` | Fixtures §3.1 and §3.4; 10 new blocks; header index extended |

  **Pipeline split**: recommended — the change alters numerical output and
  changes the observable contract of an exported function.

---

### PR 2 — the fold-in, the pass-through values, the documentation surface

- [x] **PR 2: `fix/svydesign-replicate-foldin`** — `from_svydesign()` folds the
      base weight into a factor-form replicate matrix, leaves every
      pass-through value alone, and says so in `?from_svydesign`.

  Branch from `develop` after PR 1 merges. Do not open this pull request while
  PR 1 is open.

  Carries `spec.md` §I.1 rows 6 and 12, and §III.2 step 9.

  **Tasks** (2–5 minutes each)

  *Fixtures.*

  1. Add the `test-spec.md` §3.2 fixture (`rep_bridge_taylor_flat`) to the
     fixture section. Verify it returns a list whose `sv` element inherits
     `"survey.design"` and reports one stratum.
  2. Extend the header comment index with one entry per section this pull
     request adds. Verify the index order matches the block order.

  *Failing blocks — the fold-in.*

  3. Write the failing block for row I-1 at the top of the §6.1 oracle
     section, above the I-3 block PR 1 wrote, with the cell A precondition
     assertions and the confidence-bound comparison at `1e-6`. Verify it fails
     on the standard error.
  4. Move the one `test_invariants()` call for `from_svydesign()` out of the
     I-3 block and into the I-1 block. Verify the file holds exactly one such
     call, and that it now sits in the first block of the file that converts a
     `svyrep.design` — as `test-spec.md` §10.1 requires.
  5. Write the failing block for row I-2, with the cell B precondition
     assertions and the fold-in matrix comparison at `tolerance = 1e-12`.
     Verify it fails.
  6. Write the failing block for row I-13, building the source design inside
     `suppressWarnings()` so `survey`'s own `Data look like combined weights`
     heuristic warning stays out of the assertion. Verify it fails.

  *Implementation.*

  7. Implement `spec.md` §III.2 step 9: when `isTRUE(x$combined.weights)` is
     `FALSE`, multiply the expanded matrix by `x$pweights`; otherwise leave it
     alone. Raise no condition on either branch. Verify rows I-1, I-2 and I-13
     pass.
  8. Verify rows I-3 to I-11 and I-21 still pass. Cells C and D declare
     finished weights, so the fold-in must not move their numbers.

  *The values and the names that pass through.*

  9. Write the blocks for rows I-15, I-16 and I-19. Verify all three pass:
     genuine zeros survive a JK1 and a JKn conversion, and an `NA` in the
     replicate matrix survives.
  10. Write the blocks for rows I-20 and I-26. Verify I-20 raises
      `surveycore_error_weights_nonpositive` with a class assertion and no
      snapshot, and that I-26 converts and keeps the negative value.
  11. Write the blocks for rows I-12, I-14, I-23 and I-24. Verify all four
      pass, and that I-24 shows the unrelated values gone from the column whose
      name the replicate matrix also carries.
  12. Write the blocks for rows I-17, I-18 and I-22. Verify all three pass.
      Rows I-17 and I-18 close the one- and two-replicate name widths that PR
      1's rows I-8 and I-9 leave open; they can pass in either pull request and
      they land here, with the rest of the pass-through group.

  *The documentation surface.*

  13. Rewrite the two false sentences in the `from_svydesign()` roxygen block
      so it states the three facts in `spec.md` §II.3: that the conversion
      transforms rather than preserves the replicate weights on a factor-form
      source, that it writes a generated column block on the
      `..surveycore_wt..` naming pattern when the source names no replicate
      column, and that `@variables$repweights` names those columns in replicate
      order. Keep the metadata sentence, add no `@param`, change no `@return`.
  14. Run `devtools::document()` and commit the regenerated
      `man/from_svydesign.Rd`. Verify `NAMESPACE` is unchanged and
      `man/from_svydesign.Rd` is the only changed file under `man/`.

  *Gates.*

  15. Run `air::format_package()`. Verify it produces no further diff.
  16. Run the full suite and the six profile gates in `test-spec.md` §12.
      Verify each pass condition.
  17. Run `covr::package_coverage()` with `NOT_CRAN=true`. Verify package
      coverage is at or above 95% and every new line in
      `R/methods-conversion.R` is reached, with no `# nocov` added.
  18. Run `git diff --name-only origin/develop`. Verify the list is exactly the
      three files below, that `NEWS.md` is absent, and that neither
      `plans/error-messages.md` nor `tests/testthat/_snaps/conversion.md`
      appears.

  **Acceptance criteria** (all observable before merge)

  - Rows I-1, I-2, I-12, I-13, I-14, I-15, I-16, I-17, I-18, I-19, I-20, I-22,
    I-23, I-24 and I-26 pass — 15 blocks. These are the only rows this pull
    request adds. Row I-25 has no block; `test-spec.md` §6.4 records it as a
    state that cannot be reached.
  - Point and standard-error parity holds in every oracle row, I-1 to I-4 —
    point at `1e-10` and standard error at `1e-8`. Confidence-bound parity at
    `1e-6` holds in row I-1 only. No other oracle row asserts a confidence
    bound.
  - The fold-in matrix comparison in row I-2 agrees at `1e-12`.
  - Row I-13 shows the stored column equal to the source column times the base
    weight at `1e-12`, and standard-error parity at `1e-8`.
  - Rows I-3, I-4 to I-11 and I-21, all green from PR 1, still pass unchanged.
  - Exactly one `test_invariants()` call for `from_svydesign()` exists in the
    file, and it sits in the I-1 block.
  - `surveycore_error_weights_nonpositive` still fires in row I-20, with a
    class assertion and no snapshot.
  - `man/from_svydesign.Rd` contains no sentence saying the replicate weights
    are preserved. It states three facts: that the conversion transforms rather
    than preserves the weights on a factor-form source, that it writes a
    generated replicate column block and what the naming pattern is, and that
    `@variables$repweights` names those columns in replicate order. (§VII gate
    12)
  - `devtools::document()` leaves `NAMESPACE` unchanged, and
    `man/from_svydesign.Rd` is the only changed page under `man/`. (§VII gate
    8)
  - No new `cli_abort()` or `cli_warn()` call appears in
    `R/methods-conversion.R`. This pull request adds no condition, so it adds
    no row to `plans/error-messages.md` and that file shows no diff.
  - `git diff` does not list `tests/testthat/_snaps/conversion.md`. This pull
    request adds no snapshot, and the file does not yet exist — PR 3 creates
    it.
  - `devtools::check()`: 0 errors, 0 warnings, at most the two pre-approved
    notes. (§VII gate 1)
  - `devtools::test()`: 0 failures and 0 warnings. (§VII gate 2)
  - `devtools::run_examples()` runs every example with no error.
  - `pkgdown::build_site()` builds with no error.
  - `covr::package_coverage()` with `NOT_CRAN=true`: at or above 95%, and 100%
    of the new lines in `R/methods-conversion.R` covered. (§VII gate 3)
  - `air::format_package()` produces no diff. (§VII gate 9)
  - `git diff --name-only origin/develop` lists exactly:
    `R/methods-conversion.R`, `man/from_svydesign.Rd`,
    `tests/testthat/test-conversion.R`. (§VII gate 6)
  - `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R`
    or `R/variance-replicate.R`. (§VII gate 11)
  - `git diff --name-only` does not list `NEWS.md`. (§VII gate 7)

  **Files touched**

  | File | Change |
  |---|---|
  | `R/methods-conversion.R` | The fold-in step; the `from_svydesign()` roxygen block |
  | `man/from_svydesign.Rd` | Regenerated by `devtools::document()` |
  | `tests/testthat/test-conversion.R` | Fixture §3.2; 15 new blocks; the `test_invariants()` call moved into the I-1 block; header index extended |

  **Pipeline split**: recommended — the change alters numerical output and
  restates the documented contract of an exported function.

---

### PR 3 — the name guards, the type guard, the empty-data guard

- [x] **PR 3: `fix/svydesign-replicate-guards`** — `from_svydesign()` refuses
      the three source states it cannot carry, each with a typed condition.

  Branch from `develop` after PR 2 merges. Do not open this pull request while
  PR 2 is open.

  Carries `spec.md` §I.1 rows 4, 5, 7 and 8, and §III.2 steps 1, 3, 7 and 8.
  This is the first pull request to write `plans/error-messages.md` and the
  first to write `tests/testthat/_snaps/conversion.md`.

  **Tasks** (2–5 minutes each)

  *Condition table first (`code-style.md`: the table row precedes the code).*

  1. Append the new dated section to `plans/error-messages.md`, after
     `### var-extension-slot rows (2026-08-27)`: the section heading, the
     precedent paragraph and the variable-bindings paragraph, verbatim from
     `spec.md` §V.7. Verify the file still renders as one table per section.
     The bindings paragraph covers all seven bindings, including those of the
     two export rows that land later.
  2. Append rows CB-1, CB-2 and CB-5 to that section, verbatim from `spec.md`
     §V.7. Verify each of the three class names appears exactly once.
  3. Append one line to the new section recording that rows CB-3 and CB-4 land
     in the paired export pull requests, so the transient row gap between
     CB-2 and CB-5 explains itself. Verify the line sits with the table and
     names no branch name.
  4. Append the updated trigger note for row 2
     (`surveycore_error_empty_data`) from `spec.md` §V.7. Verify row 2 itself
     is unedited.

  *Fixtures.*

  5. Add the `test-spec.md` §3.5 fixture (`rep_bridge_even`). Verify it builds
     a BRR design with no error and no warning, and that its layout gives four
     PSUs in every stratum.
  6. Add the §3.6 fixture (`rep_bridge_zero_row`). Verify it reports 0 rows and
     a 0-by-0 replicate matrix, and raises nothing on the way.
  7. Extend the header comment index with one entry per section this pull
     request adds.

  *The name guards (§I.1 rows 4 and 5).*

  8. Write the failing blocks for rows C-1, C-3 and C-4. Verify all three fail.
  9. Implement §III.2 step 7, the usable-name check, and raise
     `surveycore_error_repweights_names_lost` with the `spec.md` §V.1 message.
     Verify C-1 and C-3 pass.
  10. Implement §III.2 step 8, the collision check on generated names, and
      raise `surveycore_error_repwt_name_collision` with the `spec.md` §V.2
      message, `qty()` calls included. Verify C-4 passes.

  *The type guard (§I.1 row 7).*

  11. Write the failing blocks for rows C-10 and C-12, building the
      `mrbbootstrap` source inside `suppressWarnings()`. Verify both fail.
  12. Implement §III.2 step 1, the replicate type check, as the route's first
      step, and raise `surveycore_error_replicate_type_unsupported` with the
      `spec.md` §V.5 message. Verify C-10 and C-12 pass.

  *The empty-data guard (§I.1 row 8).*

  13. Write the failing block for row C-13. Verify it fails: the current code
      returns an object and raises nothing.
  14. Implement §III.2 step 3, the row-count check, and raise
      `surveycore_error_empty_data` with the import-route message in `spec.md`
      §V.6. Verify C-13 passes.

  *Snapshots.*

  15. Add the snapshot blocks for rows C-2, C-5, C-11 and C-14, run the suite,
      and review each of the four new snapshots with
      `testthat::snapshot_review()`. This run creates
      `tests/testthat/_snaps/conversion.md` for the first time.
  16. Verify the reviewed snapshots read correctly: the collision message
      pluralizes in both numbers, and the type message names the offending type
      and all nine accepted values.
  17. Verify rows I-1 to I-24 and I-26 still pass. The four guards must refuse
      no source design that an earlier row converts.

  *Gates.*

  18. Run `air::format_package()`. Verify it produces no further diff.
  19. Run the full suite and the six profile gates in `test-spec.md` §12.
      Verify each pass condition.
  20. Run `covr::package_coverage()` with `NOT_CRAN=true`. Verify package
      coverage is at or above 95% and every new line in
      `R/methods-conversion.R` is reached, with no `# nocov` added.
  21. Run `git diff --name-only origin/develop`. Verify the list is exactly the
      four files below, that `NEWS.md` is absent, and that no file under `man/`
      appears.

  **Acceptance criteria** (all observable before merge)

  - Rows C-1, C-2, C-3, C-4, C-5, C-10, C-11, C-12, C-13 and C-14 pass — 10
    blocks. These are the only rows this pull request adds.
  - These three class names each have a class assertion and a reviewed
    snapshot: `surveycore_error_repweights_names_lost`,
    `surveycore_error_repwt_name_collision`,
    `surveycore_error_replicate_type_unsupported`.
    `surveycore_error_empty_data` also has both, on its new import-route
    trigger. Rows C-3 and C-12 carry the class assertion alone, each being a
    second trigger for a message another row snapshots.
  - Every import row green from PR 1 and PR 2 — I-1 to I-24, I-26 — still
    passes unchanged.
  - Every `cli_abort()` this pull request adds carries a `class` argument.
    (§VII gate 4)
  - The three class names CB-1, CB-2 and CB-5 name in
    `plans/error-messages.md` appear verbatim in `R/methods-conversion.R`,
    alongside `surveycore_error_empty_data`. No other new class name appears
    there yet. (§VII gate 5, part)
  - `plans/error-messages.md` shows no diff outside the appended section and
    the row 2 trigger note. Row 2's own table row is unedited.
  - `tests/testthat/_snaps/conversion.md` is a new file and holds exactly four
    snapshot blocks — C-2, C-5, C-11 and C-14. No other snapshot appears in
    it.
  - `devtools::check()`: 0 errors, 0 warnings, at most the two pre-approved
    notes. (§VII gate 1)
  - `devtools::test()`: 0 failures and 0 warnings. (§VII gate 2)
  - `devtools::run_examples()` runs every example with no error.
  - `pkgdown::build_site()` builds with no error.
  - `covr::package_coverage()` with `NOT_CRAN=true`: at or above 95%, and 100%
    of the new lines in `R/methods-conversion.R` covered. (§VII gate 3)
  - `air::format_package()` produces no diff. (§VII gate 9)
  - `devtools::document()` leaves `NAMESPACE` unchanged and changes no file
    under `man/`. (§VII gate 8)
  - `git diff --name-only origin/develop` lists exactly:
    `R/methods-conversion.R`, `plans/error-messages.md`,
    `tests/testthat/test-conversion.R`,
    `tests/testthat/_snaps/conversion.md`. (§VII gate 6)
  - `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R`
    or `R/variance-replicate.R`. (§VII gate 11)
  - `git diff --name-only` does not list `NEWS.md`. (§VII gate 7)

  **Files touched**

  | File | Change |
  |---|---|
  | `R/methods-conversion.R` | The four import guards: type, row count, usable names, generated-name collision |
  | `plans/error-messages.md` | The new dated section: heading, precedent and bindings paragraphs, rows CB-1, CB-2 and CB-5, the pending-rows note, the row 2 trigger note |
  | `tests/testthat/test-conversion.R` | Fixtures §3.5 and §3.6; 10 new blocks; header index extended |
  | `tests/testthat/_snaps/conversion.md` | New file. Four snapshots: C-2, C-5, C-11, C-14 |

  **Pipeline split**: recommended — the change adds three condition classes and
  a new trigger for a fourth, and refuses source designs the route used to
  accept.

---

### PR 4 — the FPC drop, the empty-replicate guard

- [x] **PR 4: `fix/svydesign-replicate-fpc`** — `as_svydesign()` drops the FPC
      out loud and refuses a design that names no replicate column.

  Branch from `develop` after PR 3 merges. Do not open this pull request while
  PR 3 is open.

  Carries `spec.md` §I.1 rows 9 and 11, and §IV.2 steps 2, 5 and 6.

  **Tasks** (2–5 minutes each)

  *Condition table first.*

  1. Insert row CB-3 into the dated section of `plans/error-messages.md` that
     PR 3 created, in CB number order, verbatim from `spec.md` §V.7. Verify the
     rows read CB-1, CB-2, CB-3, CB-5.
  2. Append the updated trigger note for row 16
     (`surveycore_error_repweights_empty`) from `spec.md` §V.7. Verify row 16
     itself is unedited, and that the pending-rows note PR 3 added now names
     CB-4 only.

  *Fixtures.*

  3. Add the `test-spec.md` §3.3 fixture (`rep_bridge_sc`) to the fixture
     section. Verify it returns a `survey_replicate` design with and without an
     FPC column.
  4. Extend the header comment index with one entry per section this pull
     request adds.

  *The empty-replicate guard (§I.1 row 11).*

  5. Write the failing block for row C-15, building the §3.7 design inline with
     the exported `survey_replicate` class constructor and every `variables`
     key given a value. Verify it fails today with `survey`'s untyped
     `missing value where TRUE/FALSE needed`, and that the block carries no
     `test_invariants()` call.
  6. Implement §IV.2 step 2, the replicate count check, as the route's first
     check, and raise `surveycore_error_repweights_empty` with the export-route
     message in `spec.md` §V.6. Verify C-15 passes.
  7. Add the snapshot block for row C-16 and review the new snapshot with
     `testthat::snapshot_review()`.

  *The FPC drop (§I.1 row 9).*

  8. Write the failing blocks for rows E-3, E-4 and E-5. Verify all three fail
     today with `survey`'s `fpc is wrong length`.
  9. Write the blocks for rows E-1 and E-2, and put the one `test_invariants()`
     call for `as_survey_replicate()` in the E-1 block. Verify E-1 and E-2 pass
     on the current code, and that the file holds exactly one such call.
  10. Remove the `fpc` and `fpctype` arguments from the
      `survey::svrepdesign()` call and delete the now-unused local `fpctype`
      value. Verify E-3, E-4 and E-5 return a `svyrep.design`.
  11. Implement §IV.2 step 5: raise `surveycore_warning_replicate_fpc_dropped`
      with the `spec.md` §V.3 message when the design records an FPC column,
      once per call, before the `survey::svrepdesign()` call. Verify E-3, E-4
      and E-5 pass and E-1 still raises no warning.
  12. Write the block for row C-6. Verify it captures the result from the
      return value of the warned call, never with `tryCatch()` or
      `withCallingHandlers()`.
  13. Add the snapshot block for row C-7 and review the new snapshot. Verify it
      shows the dropped column name.
  14. Write the blocks for rows E-6 and E-7. Verify the surveycore design's
      `@data` and `@variables` are identical before and after the call, and
      that a second call warns again.
  15. Verify every import row from PR 1 to PR 3 still passes. The export
      changes must move no import number.

  *Gates.*

  16. Run `air::format_package()`. Verify it produces no further diff.
  17. Run the full suite and the six profile gates in `test-spec.md` §12.
      Verify each pass condition.
  18. Run `covr::package_coverage()` with `NOT_CRAN=true`. Verify package
      coverage is at or above 95% and every new line in
      `R/methods-conversion.R` is reached, with no `# nocov` added.
  19. Run `git diff --name-only origin/develop`. Verify the list is exactly the
      four files below, that `NEWS.md` is absent, and that no file under `man/`
      appears.

  **Acceptance criteria** (all observable before merge)

  - Rows E-1, E-2, E-3, E-4, E-5, E-6, E-7, C-6, C-7, C-15 and C-16 pass — 11
    blocks. These are the only rows this pull request adds.
  - Point parity at `1e-10` and standard-error parity at `1e-8` in rows E-2,
    E-3, E-4 and E-5, each against `get_means(d, y1)` on the same design.
  - Row E-4 expects a warning, not an error. No row expects `as_svydesign()` to
    fail on a replicate design that records an FPC.
  - Row E-1 asserts `expect_no_warning()` on a design with no FPC.
  - Row E-6 shows the surveycore design's `@data` and `@variables` identical
    before and after a warned call.
  - `surveycore_warning_replicate_fpc_dropped` and
    `surveycore_error_repweights_empty` each have a class assertion and a
    reviewed snapshot.
  - Exactly one `test_invariants()` call for `as_survey_replicate()` exists in
    the file, in the E-1 block. The §3.7 construction in C-15 and C-16 carries
    none.
  - `R/methods-conversion.R` contains no `fpc =` or `fpctype =` argument inside
    the `survey::svrepdesign()` call. (§VII gate 10)
  - Every `cli_abort()` and `cli_warn()` this pull request adds carries a
    `class` argument. (§VII gate 4)
  - Every import row green from PR 1 to PR 3 still passes unchanged.
  - `plans/error-messages.md` shows no diff outside the inserted row CB-3, the
    row 16 trigger note, and the one-line pending-rows note the insertion
    updates. Every other row of the file, and every other dated section, is
    byte-identical to `origin/develop`.
  - `tests/testthat/_snaps/conversion.md` shows no diff outside the two
    snapshot blocks this pull request adds, C-7 and C-16. The four blocks PR 3
    committed are unchanged, unreformatted, and keep their line endings.
  - `devtools::check()`: 0 errors, 0 warnings, at most the two pre-approved
    notes. (§VII gate 1)
  - `devtools::test()`: 0 failures and 0 warnings. (§VII gate 2)
  - `devtools::run_examples()` runs every example with no error.
  - `pkgdown::build_site()` builds with no error.
  - `covr::package_coverage()` with `NOT_CRAN=true`: at or above 95%, and 100%
    of the new lines in `R/methods-conversion.R` covered. (§VII gate 3)
  - `air::format_package()` produces no diff. (§VII gate 9)
  - `devtools::document()` leaves `NAMESPACE` unchanged and changes no file
    under `man/`. (§VII gate 8)
  - `git diff --name-only origin/develop` lists exactly:
    `R/methods-conversion.R`, `plans/error-messages.md`,
    `tests/testthat/test-conversion.R`,
    `tests/testthat/_snaps/conversion.md`. (§VII gate 6)
  - `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R`
    or `R/variance-replicate.R`. (§VII gate 11)
  - `git diff --name-only` does not list `NEWS.md`. (§VII gate 7)

  **Files touched**

  | File | Change |
  |---|---|
  | `R/methods-conversion.R` | The export replicate route: the replicate count check, the FPC drop warning, the `fpc` and `fpctype` arguments removed |
  | `plans/error-messages.md` | Row CB-3 inserted in number order; the row 16 trigger note; the pending-rows note updated |
  | `tests/testthat/test-conversion.R` | Fixture §3.3; 11 new blocks; header index extended |
  | `tests/testthat/_snaps/conversion.md` | Two new snapshots: C-7, C-16 |

  **Pipeline split**: recommended — the change alters what the exported design
  carries, adds a condition class and adds a new trigger for a second.

---

### PR 5 — Fay's shrinkage factor, the full round trip

- [x] **PR 5: `fix/svydesign-replicate-fay`** — `as_svydesign()` recovers Fay's
      shrinkage factor from the recorded scale, refuses a scale that yields
      none, and the full round trip returns the estimate it started with.

  Branch from `develop` after PR 4 merges. Do not open this pull request while
  PR 4 is open.

  Carries `spec.md` §I.1 row 10, and §IV.2 steps 1, 3, 4 and 7. It is the last
  of the five, so it completes quality gates 5 and 13 and observable properties
  3, 8, 9 and 11.

  **Tasks** (2–5 minutes each)

  *Condition table first.*

  1. Insert row CB-4 into the dated section of `plans/error-messages.md`, in CB
     number order, verbatim from `spec.md` §V.7. Verify the rows read CB-1 to
     CB-5 in order, and remove the pending-rows note, which now names nothing.
  2. Extend the header comment index with one entry per section this pull
     request adds.

  *Failing blocks — Fay.*

  3. Write the failing block for row E-9, on the §3.5 fixture PR 3 added.
     Verify it fails today with `survey`'s
     `With type='Fay' you must supply the correct rho`.
  4. Write the failing blocks for rows C-8 and C-17, each building its own
     design as `test-spec.md` §9 describes: C-8 through
     `as_survey_replicate(type = "Fay", scale = 0.1)` on four replicate
     columns, C-17 through the exported `survey_replicate` class constructor
     with no `scale` key. Verify both fail.

  *Implementation.*

  5. Implement `spec.md` §IV.2 step 4's recovery: derive the shrinkage factor
     from the recorded scale and the replicate count, and pass it to
     `survey::svrepdesign()` for the Fay type only. Verify E-9 passes and
     reports the source scale at `1e-10`.
  6. Implement the four refusal conditions in §IV.2 step 4 and raise
     `surveycore_error_fay_rho_unrecoverable` with the `spec.md` §V.4 message,
     building the scale text so both the recorded and the missing case render.
     Verify C-8 and C-17 pass and neither branch carries `# nocov`.
  7. Add the snapshot blocks for rows C-9 and C-18 and review both new
     snapshots. Verify C-9 shows the recorded scale and C-18 shows that no
     scale was recorded.
  8. Write the block for row E-10. Verify the constructor's default scale
     recovers a shrinkage factor of 0 at `1e-10` and the design converts.

  *Pass-through and the full round trip.*

  9. Write the block for row E-8. Verify it raises no warning and matches at
     `1e-10` and `1e-8`.
  10. Write the blocks for rows R-1, R-2 and R-3. Verify point at `1e-10`, SE
      at `1e-8` and both confidence bounds at `1e-6` in R-1, point and SE in
      R-2, and an identical replicate count in R-3.
  11. Write the blocks for rows R-4 and R-5. Verify R-4 warns with the class
      and returns to a design that matches at `1e-10` and `1e-8`, and that R-5
      reproduces the source Fay standard error at `1e-8`.
  12. Verify every row from PR 1 to PR 4 still passes, and that no run of the
      suite produces `survey`'s
      `With type='Fay' you must supply the correct rho`.

  *Gates.*

  13. Run `air::format_package()`. Verify it produces no further diff.
  14. Run the full suite and the six profile gates in `test-spec.md` §12.
      Verify each pass condition.
  15. Run `covr::package_coverage()` with `NOT_CRAN=true`. Verify package
      coverage is at or above 95% and every new line in
      `R/methods-conversion.R` is reached, with no `# nocov` on either arm of
      the Fay refusal.
  16. Verify quality gate 5 is now complete: all five class names in the
      `plans/error-messages.md` dated section appear verbatim in
      `R/methods-conversion.R`, alongside the two reused names, and no other
      new class name appears there.
  17. Run `git diff --name-only origin/develop`. Verify the list is exactly the
      four files below, that `NEWS.md` is absent, and that no file under `man/`
      appears.

  **Acceptance criteria** (all observable before merge)

  - Rows E-8, E-9, E-10, R-1, R-2, R-3, R-4, R-5, C-8, C-9, C-17 and C-18 pass
    — 12 blocks. These are the only rows this pull request adds. With them the
    suite holds all 58 rows in `test-spec.md`.
  - The recovered shrinkage factor in row E-9 equals 0.3 at `1e-10`, and the
    rebuilt scale equals the source scale at `1e-10`.
  - The recovered shrinkage factor in row E-10 equals 0 at `1e-10`.
  - Round-trip parity: point at `1e-10` and standard error at `1e-8` in rows
    R-1, R-2, R-4 and R-5; both confidence bounds at `1e-6` in row R-1 only.
  - `surveycore_error_fay_rho_unrecoverable` has a class assertion and a
    reviewed snapshot on each of its two reachable arms — C-8 with C-9 for the
    out-of-range scale, C-17 with C-18 for the missing scale.
  - The `survey::svrepdesign()` call passes the shrinkage factor on the Fay
    branch, and no run of the suite produces `survey`'s
    `With type='Fay' you must supply the correct rho`. (§VII gate 13)
  - Every `cli_abort()` this pull request adds carries a `class` argument.
    (§VII gate 4)
  - Every row green from PR 1 to PR 4 still passes unchanged.
  - All five new class names in the `plans/error-messages.md` dated section now
    appear verbatim in `R/methods-conversion.R`, alongside the two reused names
    `surveycore_error_empty_data` and `surveycore_error_repweights_empty`. No
    other new class name appears there. (§VII gate 5, complete)
  - `plans/error-messages.md` shows no diff outside the inserted row CB-4 and
    the removal of the one-line pending-rows note. Every other row of the file,
    and every other dated section, is byte-identical to `origin/develop`.
  - `tests/testthat/_snaps/conversion.md` shows no diff outside the two
    snapshot blocks this pull request adds, C-9 and C-18. The six blocks PR 3
    and PR 4 committed are unchanged, unreformatted, and keep their line
    endings.
  - `devtools::check()`: 0 errors, 0 warnings, at most the two pre-approved
    notes. (§VII gate 1)
  - `devtools::test()`: 0 failures and 0 warnings. (§VII gate 2)
  - `devtools::run_examples()` runs every example with no error.
  - `pkgdown::build_site()` builds with no error.
  - `covr::package_coverage()` with `NOT_CRAN=true`: at or above 95%, and 100%
    of the new lines in `R/methods-conversion.R` covered, with no `# nocov` on
    either arm of the Fay refusal. (§VII gate 3)
  - `air::format_package()` produces no diff. (§VII gate 9)
  - `devtools::document()` leaves `NAMESPACE` unchanged and changes no file
    under `man/`. (§VII gate 8)
  - `git diff --name-only origin/develop` lists exactly:
    `R/methods-conversion.R`, `plans/error-messages.md`,
    `tests/testthat/test-conversion.R`,
    `tests/testthat/_snaps/conversion.md`. (§VII gate 6)
  - `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R`
    or `R/variance-replicate.R`. (§VII gate 11)
  - `git diff --name-only` does not list `NEWS.md`. (§VII gate 7)

  **Files touched**

  | File | Change |
  |---|---|
  | `R/methods-conversion.R` | The export replicate route: the Fay shrinkage factor recovery and its four refusal conditions |
  | `plans/error-messages.md` | Row CB-4 inserted in number order; the pending-rows note removed |
  | `tests/testthat/test-conversion.R` | 12 new blocks; header index extended |
  | `tests/testthat/_snaps/conversion.md` | Two new snapshots: C-9, C-18 |

  **Pipeline split**: recommended — the change alters what the exported design
  carries, adds a condition class and completes the numerical contract of the
  export route.

---

## Ordering and the shared write surface

Five sequential pull requests, in the order 1, 2, 3, 4, 5. Each branches from
`develop` after its predecessor merges, and none is open while its predecessor
is open. No file has two concurrent writers.

| File | PR 1 | PR 2 | PR 3 | PR 4 | PR 5 |
|---|---|---|---|---|---|
| `R/methods-conversion.R` | Expansion, names, the write, the helper | The fold-in; the roxygen block | The four import guards | The export count check, the FPC drop | The Fay recovery and its refusals |
| `man/from_svydesign.Rd` | — | Regenerated | — | — | — |
| `plans/error-messages.md` | — | — | New section; CB-1, CB-2, CB-5; row 2 note | CB-3; row 16 note | CB-4 |
| `tests/testthat/test-conversion.R` | 10 blocks, 2 fixtures | 15 blocks, 1 fixture | 10 blocks, 2 fixtures | 11 blocks, 1 fixture | 12 blocks |
| `tests/testthat/_snaps/conversion.md` | — | — | Created; 4 snapshots | 2 snapshots | 2 snapshots |

Notes on the shared files.

- **`R/methods-conversion.R`.** Every pull request rebases on the merged
  predecessor. The guards land after the core fix, which is safe: PR 3's four
  guards refuse only source states no PR 1 or PR 2 row builds, and task 17 of
  PR 3 verifies that. PR 4's FPC drop lands before PR 5's Fay recovery, which
  reverses `spec.md` §IV.2 steps 4 and 5; that too is safe, because the
  fixtures are disjoint — E-3, E-4 and E-5 use BRR, bootstrap and JKn and never
  Fay, and E-9 and E-10 carry no FPC — so no block exercises two of the
  reordered conditions at once.
- **`tests/testthat/test-conversion.R`.** New sections append at the end of the
  file, in `test-spec.md` row order. The one exception is row I-1: PR 1 opens
  the §6.1 oracle section with I-3 and I-4 and leaves the I-1 and I-2 slots
  empty, and PR 2 fills them at the top of that section. That is what lets the
  single `test_invariants()` call for `from_svydesign()` end up in the I-1
  block, as `test-spec.md` §10.1 requires. PR 1 holds the call in the I-3
  block, and PR 2 moves it — task 4 of PR 2.
- **`plans/error-messages.md`.** PR 3 creates the dated section and adds a
  one-line note that CB-3 and CB-4 land in the paired export pull requests, so
  the transient gap between CB-2 and CB-5 explains itself in the file. PR 4
  inserts CB-3 and narrows that note to CB-4; PR 5 inserts CB-4 and removes
  the note.
- **`tests/testthat/_snaps/conversion.md`.** The file does not exist on
  `develop`, and `tests/testthat/test-conversion.R` holds no
  `expect_snapshot()` call today. PR 3 creates it through
  `testthat::snapshot_review()`. There are no existing line endings to keep and
  no existing blocks to leave alone, so the no-reformat criterion first applies
  in PR 4.

---

## Gate map — `spec.md` §VII

| Gate | Check | Which pull requests must satisfy it |
|---|---|---|
| 1 | `R CMD check` clean | All five |
| 2 | Full test suite passes | All five |
| 3 | Coverage at or above 95%; 100% of new lines covered | All five, each for its own new lines |
| 4 | Every new condition typed | PR 3 for its four; PR 4 for its two; PR 5 for its one. PRs 1 and 2 add no condition |
| 5 | Condition table matches the code | Fills in over three pull requests: PR 3 for CB-1, CB-2, CB-5 and `surveycore_error_empty_data`; PR 4 for CB-3 and `surveycore_error_repweights_empty`; PR 5 for CB-4. **The gate completes only at PR 5**, and PR 5 task 16 is the check that closes it |
| 6 | Write surface holds | All five, each against its own file table. The union across the five equals the five files in the gate exactly |
| 7 | `NEWS.md` untouched | All five |
| 8 | Only the documented page regenerates | PR 2 changes `man/from_svydesign.Rd` and nothing else under `man/`. PRs 1, 3, 4 and 5 change nothing under `man/` |
| 9 | Formatting clean | All five |
| 10 | The FPC arguments are gone from the export call | PR 4 |
| 11 | No class change leaked in | All five |
| 12 | The docstring no longer states the false contract | PR 2 |
| 13 | Fay reaches `survey` with a shrinkage factor | PR 5 |

## Profile gates — `test-spec.md` §12

All five pull requests run all six gates before opening, and each of the six is
a standalone acceptance criterion on each of the five.

| Gate | Command | Pass condition |
|---|---|---|
| document | `devtools::document()` | No change to `NAMESPACE`. In PR 2 the only changed file under `man/` is the page for `from_svydesign()`; in PRs 1, 3, 4 and 5 no file under `man/` changes at all |
| test | `Rscript -e "devtools::test()"` | 0 failures and 0 warnings |
| run_examples | `devtools::run_examples()` | Every example runs with no error |
| R CMD check --as-cran | `R CMD check --as-cran --no-manual` | 0 errors, 0 warnings, at most the two pre-approved notes |
| pkgdown | `pkgdown::build_site()` | Builds with no error |
| covr | `NOT_CRAN=true Rscript -e "covr::package_coverage()"` | Package coverage at or above 95%; every new line in the conversion source reached |

Use `NOT_CRAN=false Rscript -e "testthat::test_local()"` for the edit-and-run
loop. Always measure coverage with `NOT_CRAN=true`.

---

## Scheduling coverage — `spec.md` §I.1

| Row | Change | PR | Tasks |
|---|---|---|---|
| 1 | Expand `x$repweights` to a full matrix | 1 | 10 |
| 2 | Generate names when `survey` supplies none, and store them | 1 | 9, 11, 12 |
| 3 | Write one column per replicate on every conversion | 1 | 12, 13 |
| 4 | Error when no usable, distinct name per column | 3 | 8, 9, 15 |
| 5 | Error when a generated name is already a column | 3 | 8, 10, 15 |
| 6 | Fold the base weight in when the source reports factors | 2 | 3, 5, 6, 7 |
| 7 | Error on a replicate type surveycore does not accept | 3 | 11, 12, 15 |
| 8 | Error on a source design with zero rows | 3 | 13, 14, 15 |
| 9 | Stop passing `fpc` and `fpctype`; warn when one is recorded | 4 | 8, 10, 11, 12, 13 |
| 10 | Recover Fay's shrinkage factor and pass it | 5 | 3, 5, 6, 7 |
| 11 | Error when the design names no replicate column | 4 | 5, 6, 7 |
| 12 | Update the roxygen block and regenerate the `man/` page | 2 | 13, 14 |

## Scheduling coverage — `spec.md` §VI observable properties

| Property | PR | Rows that show it |
|---|---|---|
| 1 Import parity | 1 and 2 | I-3 and I-4 in PR 1; I-1 and I-2 in PR 2. True only after PR 2 |
| 2 Export parity | 4 | E-2, E-3, E-4, E-5 |
| 3 Round-trip parity | 5 | R-1, R-2, R-4, R-5 |
| 4 No silent loss | 1 | I-5, I-6, I-7 |
| 5 No silent renaming | 2 | I-12, I-14, I-23 |
| 6 The export drop is loud | 4 | E-3, E-4, E-5, C-6, C-7 |
| 7 The export drop is not destructive | 4 | E-6, E-7 |
| 8 Every accepted type converts in both directions | 2, 3, 4 and 5 | Import half: I-15 and I-16 in PR 2; C-10, C-11 and C-12 in PR 3. Export half: E-3, E-4 and E-5 in PR 4; E-9 and E-10 in PR 5. True only after PR 5 |
| 9 A Fay design keeps its scale | 5 | E-9, R-5 |
| 10 Stored columns match the source matrix | 2 | I-2, I-13, I-23, I-24 |
| 11 A degenerate design is refused | 3 and 4 | Import half in PR 3: C-13, C-14. Export half in PR 4: C-15, C-16. True only after PR 4 |
| 12 The generated columns add no metadata | 2 | I-22 |

### Property 8 on the export route — why five rows cover nine types (D9)

`test-spec.md` §7 reaches five of the nine accepted types on the export route:
BRR at E-3, bootstrap at E-4, JKn at E-5, Fay at E-9 and E-10, and the §3.3
fixture's default at E-1 and E-2. JK2, ACS, successive-difference and `"other"`
reach it in no row. They need none. The export route branches on type in
exactly two places, and each branch has a row.

| Branch | `spec.md` reference | Types | Row |
|---|---|---|---|
| `scale = NULL`, no shrinkage factor | §IV.2 step 3 | BRR | E-3 |
| `scale = NULL`, shrinkage factor passed | §IV.2 step 4 | Fay | E-9, E-10 |
| `scale` passed, no shrinkage factor | §IV.2 step 3, the else arm | The other seven | E-4, E-5 |

The four unexercised types run the lines E-4 and E-5 already reach. A row
parametrized over all nine types would add no coverage and would reopen a
document that froze at SPEC_READY. `test-spec.md` does not change.

## Test row allocation

Each of the 58 rows in `test-spec.md` belongs to exactly one pull request.

| Group | PR 1 | PR 2 | PR 3 | PR 4 | PR 5 |
|---|---|---|---|---|---|
| Import — oracle (§6.1) | I-3, I-4 | I-1, I-2 | — | — | — |
| Import — structure (§6.2) | I-5 to I-11 | I-22 | — | — | — |
| Import — named columns (§6.3) | — | I-12, I-13, I-14, I-23, I-24 | — | — | — |
| Import — edge cases (§6.4) | I-21 | I-15, I-16, I-17, I-18, I-19, I-20, I-26 | — | — | — |
| Export (§7) | — | — | — | E-1 to E-7 | E-8, E-9, E-10 |
| Full round trip (§8) | — | — | — | — | R-1 to R-5 |
| Conditions (§9) | — | — | C-1 to C-5, C-10 to C-14 | C-6, C-7, C-15, C-16 | C-8, C-9, C-17, C-18 |
| Block count | 10 | 15 | 10 | 11 | 12 |
| Snapshots | 0 | 0 | 4 | 2 | 2 |

Block counts sum to 58 and snapshot counts to 8.

Two allocation choices are worth naming.

- **Row I-1 waits for PR 2 (D10).** `test-spec.md` §5 builds cell A with
  `combined.weights = FALSE` — the factor form — and §6.1 has I-1 assert
  standard-error parity at `1e-8`. Until the fold-in lands, the route stores
  replication factors and surveycore's variance reads them as finished weights,
  which moves the standard error. `spec.md` §III.1 measures that move at 8% on
  a 40-row JKn design. Cells C and D declare finished weights, so I-3 and I-4
  need no fold-in and belong to PR 1.
- **Rows I-17 and I-18 sit in PR 2.** They close the one- and two-replicate
  name widths. They could pass in PR 1 as well, and they land in PR 2 with the
  rest of the pass-through group. PR 1's verify clause for
  `.repwt_col_names()` rests on rows I-8 and I-9, the twenty-replicate padded
  case and the four-replicate unpadded case.

Row I-25 has no block in any pull request. `test-spec.md` §6.4 records it as a
state that cannot be reached.

---

## Carried forward — not scheduled here

These are named so a reader does not read the absence as an oversight.

- **`NEWS.md`.** `spec.md` §I.2 puts it out of scope. None of the five pull
  requests touches it. One direct commit to `develop` adds the entries after
  all five merge.
- **The `as_svydesign()` roxygen block.** `spec.md` §II.1 and gate 8 admit one
  changed page under `man/`, `man/from_svydesign.Rd`. So the new FPC drop
  warning ships without a mention in `?as_svydesign`. The condition itself
  names the dropped column, the alternative and the reason, so a caller who
  triggers it is told what happened. Raise the documentation gap as its own
  issue after PR 5 merges.
- **The three follow-up findings in `spec.md` §IX.1** — the `survey_metadata()`
  claim in `code-style.md`, a construction-time warning for a replicate FPC,
  and a positivity check for replicate weight columns. Each is its own issue.
- **The `..surveycore_wt..` overwrite** in `spec.md` §III.7. Pre-existing
  behaviour of all three import routes; belongs to whichever issue takes on the
  manufactured column names.
