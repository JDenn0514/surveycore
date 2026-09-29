# Implementation plan — replicate-scale-jkn-bootstrap

**Status**: DRAFT
**Target version**: 1.1.0.9000
**Date**: 2026-09-28
**Issue**: #253
**Base branch**: `develop`

---

## The map in one paragraph

Five PRs. PR 1 carries the two switch lines. It also carries every edit that
keeps the suite green at that merge: the eight deleted lines in the two
oracle blocks, and the retarget of the one pre-existing block that asserts
the old bootstrap default. PR 1 carries the `as_survey_replicate()` roxygen
too, so the help page never states a value the code no longer computes. PRs
2, 3 and 4 add the test rows that are observable only after the move. PR 5
writes the release notes and runs the closing regression sweep.

## The PRs run in order, one at a time

PR 1 → PR 2 → PR 3 → PR 4 → PR 5. No two PRs run at the same time. Three
files appear in more than one write surface, and the order above is what
keeps them apart:

| File | PRs that write it | Order |
|---|---|---|
| `R/core-constructors.R` | PR 1, PR 4 | PR 1 first |
| `tests/testthat/test-constructors.R` | PR 1, PR 2, PR 3, PR 4 | PR 1, then 2, then 3, then 4 |
| `tests/testthat/test-variance-replicate.R` | PR 1, PR 4 | PR 1 first |

Open no branch for a later PR until the branch before it merges into
`develop`. Cut each branch from `develop` after that merge.

## Which PR carries the switch lines, and what ships with them

PR 1 carries `R/core-constructors.R:807` and `R/core-constructors.R:813`.

Three edits must ship in the same PR, because each one turns red the moment
the defaults move and green only after they move:

1. the six `testthat::expect_failure()` wrappers in
   `tests/testthat/test-variance-replicate.R`. A wrapper turns red when the
   assertion inside it starts to pass, so the wrappers cannot go before the
   switch and cannot stay after it;
2. the two closing ratio assertions in the same two blocks. Each asserts a
   ratio that becomes `1` after the move;
3. the block in `tests/testthat/test-constructors.R` at lines 676-692, which
   asserts the old bootstrap default.

Items 1, 2 and 3 and the two switch lines belong in one commit. Split across
two commits, neither commit passes on its own.

## The union of write surfaces

Seven files, which is `spec.md` §Files touched exactly:

- `R/core-constructors.R`
- `man/as_survey_replicate.Rd`
- `man/as_survey_nonprob.Rd`
- `tests/testthat/test-constructors.R`
- `tests/testthat/test-variance-replicate.R`
- `NEWS.md`
- `changelog/fix-replicate-scale-jkn-bootstrap.md`

No PR writes a file under `tests/testthat/_snaps/`. No PR writes
`plans/error-messages.md`. No PR writes `R/variance-replicate.R`.

## How to read three gates

Every PR below names these gates. Read them the way `test-spec.md` §How to
read three gates states.

- **Warnings from the full test run.** Clean `develop` carries many
  pre-existing small-cell warnings. The gate reads as "no new warning".
- **Formatting.** `air` is a command-line tool here and not an R package.
  Files repo-wide are already not air-clean. The gate reads as "the files
  this PR touches pass `air format --check`".
- **Coverage.** The floor is 95%, package-wide, measured with
  `NOT_CRAN=true`. Report the figure and the change against the baseline.

## Test commands

| Run | Command |
|---|---|
| Fast | `NOT_CRAN=false Rscript -e "testthat::test_local()"` |
| Full | `Rscript -e "devtools::test()"` |

Run the full command before every push.

## The mutation check

PRs 2, 3 and 4 add test blocks for behaviour that PR 1 already shipped. A
block written against shipped behaviour passes on the first run, and a block
that passes proves nothing until you show it can fail. So each of those PRs
carries a mutation check on its load-bearing blocks.

The check has four steps:

1. Edit `R/core-constructors.R:807` or `:813` back to the old value.
2. Run the new blocks. Record which assertions turn red.
3. Revert the edit.
4. Re-run and confirm green.

The switch lines at `R/core-constructors.R:807` and `:813` are **not** in the
write surface of PR 2, PR 3 or PR 4. The whole file is in PR 4's write
surface, for the `as_survey_nonprob()` `@details` roxygen and nothing else.

The mutation edit is temporary and never reaches a commit. Confirm with
`git status` before you commit: PR 2 and PR 3 show no change under `R/` at
all, and PR 4 shows no change to the switch lines.

---

## PR map

### [x] PR 1: `fix/replicate-scale-jkn-bootstrap-defaults` — move the two defaults, clear the two oracle blocks, correct the help page

- **Budget** — 5 test-spec rows (§2 rows 2.1, 2.2; §4 rows 4.1, 4.3, 4.4) |
  7 criteria
- **Tasks**
  1. Cut the branch from `develop`. Run the full suite. Record the pass
     count, the failure count and the warning count as this PR's baseline.
  2. Change `R/core-constructors.R:807` to `JKn = 1,` and
     `R/core-constructors.R:813` to `bootstrap = 1 / (n_rep - 1L),`.
  3. Run the full suite again. Confirm the red set is exactly nine
     assertions: six `expect_failure()` wrappers, two ratio assertions and
     the block at `tests/testthat/test-constructors.R:676-692`. If any other
     block turns red, stop and report it. This step is the failing-test step
     of the switch, and it also verifies test-spec row 4.4's premise.
  4. In `tests/testthat/test-variance-replicate.R`, delete the three
     `expect_failure()` wrappers in the JKn block and the three in the
     bootstrap block. The nine assertions the wrappers held stay and run
     unwrapped. Delete the closing ratio assertion in each block, with the
     comment above it. Eight lines in all, four per block.
  5. Correct each block's title and each block's opening comment. Both say
     the two sides disagree, and after step 2 they agree.
  6. In `tests/testthat/test-constructors.R`, retarget the block at lines
     676-692: the assertion moves to `1 / (n_rep - 1)` and the title states
     the new value.
  7. Run the full suite. Confirm green, and confirm the pass count against
     the step 1 baseline.
  8. Add one short comment above each changed switch line, in the style of
     the `JK2` comment at `R/core-constructors.R:800-806`. The JKn comment
     states the four facts of `spec.md` §The two switch lines. The bootstrap
     comment states the three facts there. Each comment is a pointer to
     `@param scale` and not a derivation. Keep every line inside 80 columns.
  9. Rewrite `@param scale` at `R/core-constructors.R:602-611` to carry
     F-1 to F-8 of `spec.md` §Documentation. Keep the JK2 sentences that
     PR #258 added.
  10. Add RS-1 to `@param rscales` and FP-1 to `@param fpc`.
  11. Run `devtools::document()`. Commit `man/as_survey_replicate.Rd` in the
      same commit as the roxygen change. Hand-edit no `.Rd` file.
  12. Read the rendered help page. Confirm every observable of criterion 6.
  13. Run the gates of criterion 7.
- **Acceptance criteria**
  1. The full suite passes, and it raises no warning that the step 1
     baseline did not already raise.
  2. The JKn oracle block in `tests/testthat/test-variance-replicate.R`
     passes unwrapped. It asserts `survey`'s stored scale against the
     literal `1` at `1e-8`, the point estimate at `1e-10`, the standard
     error at `1e-8` and both confidence bounds at `1e-6`, and it wraps its
     `svrepdesign()` call in `expect_no_warning()`.
  3. The bootstrap oracle block in the same file passes unwrapped. It
     asserts `survey`'s stored scale against the literal `1 / (n_rep - 1)`
     at `1e-8`, the point estimate at `1e-10`, the standard error at `1e-8`
     and both confidence bounds at `1e-6`, and it wraps its `svrepdesign()`
     call in `expect_no_warning()`.
  4. Neither of those two blocks holds a `testthat::expect_failure()` call.
     Neither holds an assertion of a standard-error ratio against
     `sqrt((n_rep - 1) / n_rep)`. Each block lost four lines. Neither
     block's title nor its opening comment says the two sides disagree.
  5. The one pre-existing block that asserted `1 / n_rep` as the stored
     bootstrap default now asserts `1 / (n_rep - 1)`, and its title states
     the new value. The diff of `tests/testthat/` holds no other changed
     line carrying the literal `1 / n_rep` or `(n_rep - 1) / n_rep`.
  6. The rendered help page for `as_survey_replicate()` carries eight facts
     in the `scale` argument, one cross-reference in the `rscales` argument
     and one clause in the `fpc` argument, as `test-spec.md` row 4.1 lists
     them. Fact 3 carries all three of its clauses, fact 5 both of its
     elements, fact 7 all three of its elements, and fact 8 all three of
     its elements. Fact 8 carries no percentage.
  7. `devtools::document()` leaves no uncommitted change under `man/` or in
     `NAMESPACE`. `R CMD check` gives 0 errors, 0 warnings and at most the
     two pre-approved notes. `air format --check` passes on every file this
     PR touches. Line coverage is at or above 95%, measured with
     `NOT_CRAN=true`.
- **Files touched**
  - `R/core-constructors.R`
  - `man/as_survey_replicate.Rd`
  - `tests/testthat/test-variance-replicate.R`
  - `tests/testthat/test-constructors.R`
- **Pipeline tier**: recommended — it moves two published default values and
  touches four files.

---

### [x] PR 2: `fix/replicate-scale-stored-default-tests` — the stored defaults and their first five edges

- **Budget** — 5 test-spec rows (§1 rows 1.1, 1.2, 1.3, 1.4, 1.5) |
  7 criteria
- **Tasks**
  1. Cut the branch from `develop` after PR 1 merges. Run the full suite and
     record the baseline counts.
  2. Write the block for row 1.1 beside the existing per-type blocks at
     `tests/testthat/test-constructors.R:597-692`. Run it and confirm it
     passes.
  3. Mutation-check row 1.1: set `R/core-constructors.R:807` back to
     `(n_rep - 1L) / n_rep` and confirm the JKn assertions turn red. Set
     `:813` back to `1 / n_rep` and confirm the bootstrap assertions turn
     red. Revert both edits and re-run.
  4. Write the block for row 1.2. Run it. Confirm it passes.
  5. Write the block for row 1.3. Run it. Confirm it passes.
  6. Mutation-check row 1.3 the same way as step 3. The infinite value at
     one replicate column is the assertion that matters here: it exists only
     at the new default. Revert and re-run.
  7. Write the block for row 1.4. Run it. Confirm it passes. This row
     asserts behaviour that both defaults share, so it takes no mutation
     check.
  8. Write the block for row 1.5. Run it. Confirm it passes.
  9. Confirm `git status` shows no change under `R/`.
  10. Run the full suite and the gates of criteria 6 and 7.
- **Acceptance criteria**
  1. A block asserts that `type = "JKn"` with 20 replicate columns and no
     `scale` stores `1`, and that `type = "bootstrap"` on the same frame
     stores `1 / (n_rep - 1)`. It asserts each stored value **not** equal to
     its old value, asserts each greater than its old value, and asserts the
     ratio of the stored default to the old value equals
     `n_rep / (n_rep - 1)` at `1e-8`, for both types. Neither construction
     raises a condition.
  2. A block asserts that `type = "JKn"` with a non-uniform `rscales` vector
     of the right length stores `scale` equal to `1`, and stores the vector
     element for element.
  3. A block asserts three constructions: `type = "bootstrap"` with two
     columns stores `1`; `type = "bootstrap"` with one column stores `Inf`,
     asserted both with `expect_true(is.infinite(...))` and against the
     literal `Inf`, and raises no condition; `type = "JKn"` with one column
     stores `1`. Each value is asserted against its own literal.
  4. A block asserts that an explicit `scale` is stored verbatim for both
     changed types.
  5. A block asserts that `type = "JKn"` with `rscales = NULL` and no
     `scale` stores `scale` equal to `1`, stores `rscales` as `NULL`, and
     raises no condition.
  6. `tests/testthat/test-constructors.R` calls `test_invariants()` four
     times, once per constructor, which is the count before this PR. The new
     blocks add no call.
  7. The full suite passes with no new warning. No file under
     `tests/testthat/_snaps/` changes. `air format --check` passes on the
     touched file. Line coverage is at or above 95% with `NOT_CRAN=true`.
- **Files touched**
  - `tests/testthat/test-constructors.R`
- **Pipeline tier**: recommended — the blocks pin the two numerical values
  that PR 1 moved, and they are the arc's main proof.

---

### [x] PR 3: `fix/replicate-scale-frame-and-type-tests` — the frame, the refusals, the nine-type table and the two-phase inheritance

- **Budget** — 4 test-spec rows (§1 rows 1.6, 1.7, 1.8, 1.9) | 8 criteria
- **Tasks**
  1. Cut the branch from `develop` after PR 2 merges. Run the full suite and
     record the baseline counts.
  2. Write the block for row 1.6: the one-row frame for each changed type,
     then the four refusals. Run it. Confirm it passes.
  3. Write the block for row 1.7. Read the nine values from `test-spec.md`
     §What this work changes and transcribe them. Write no value of your
     own. Run the block. Confirm it passes.
  4. Mutation-check row 1.7: set each switch line back in turn and confirm
     that exactly one of the nine assertions turns red each time. Revert and
     re-run.
  5. Write the two blocks for row 1.8: frame 1 with the all-`NA` outcome
     column, frame 2 with the mixed zero-weight column. Build each frame
     inline. Run both blocks. Confirm they pass.
  6. Write the block for row 1.9. Build a replicate frame, add a logical
     `subset` column to it inline, then build one `survey_replicate` per
     changed type with no `scale` and one `survey_twophase` over each.
     Assert the stored `phase1` scale against its own literal per type. Run
     the block. Confirm it passes. The block adds **no**
     `test_invariants()` call: `tests/testthat/test-constructors.R` already
     calls it once for `as_survey_twophase()`, and
     `.claude/rules/testing-surveycore.md` sets one call per constructor per
     file.
  7. Mutation-check row 1.9: set each switch line back in turn and confirm
     that the matching two-phase assertion turns red each time. Revert and
     re-run. This is the step that proves the copy at
     `R/core-constructors.R:1151` carries the value and does not recompute
     it.
  8. Confirm `git status` shows no change under `R/` and no change under
     `tests/testthat/_snaps/`.
  9. Run the full suite and the gates of criteria 7 and 8.
- **Acceptance criteria**
  1. A block asserts that a one-row frame stores `1` for `type = "JKn"` and
     `1 / (n_rep - 1)` for `type = "bootstrap"`, which are the same two
     values the 20-column frame stores.
  2. The same block asserts four refusals by `class =` and adds no snapshot:
     a zero-row frame raises `surveycore_error_empty_data`; a `repweights`
     selection of zero columns raises `surveycore_error_repweights_empty`;
     an all-zero weight column raises `surveycore_error_weights_all_zero`;
     an `rscales` of the wrong length raises
     `surveycore_error_rscales_length`.
  3. A block builds one design per `type` on one frame with no `scale` and
     asserts nine stored values, one per type, against the nine values in
     `test-spec.md` §What this work changes.
  4. A block on a frame whose outcome column is `NA` in every row asserts
     that both designs build, that the stored `scale` is `1` for JKn and
     `1 / (n_rep - 1)` for the bootstrap, that the stored `rscales` is the
     supplied vector unchanged, and that neither construction raises a
     condition.
  5. A block on a frame whose weight column mixes zeros with positive values
     asserts that both constructions raise
     `surveycore_error_weights_nonpositive`, by `class =` and with no
     snapshot. No `scale` is asserted on that frame.
  6. A block builds a `survey_twophase` design over a replicate `phase1`
     for each changed type and asserts the stored `phase1` scale: `1` for
     `type = "JKn"` and `1 / (n_rep - 1)` for `type = "bootstrap"`, each
     against its own literal at `1e-8`, never one against the other.
     Neither two-phase construction raises a condition.
  7. `tests/testthat/test-constructors.R` still calls `test_invariants()`
     four times. No file under `tests/testthat/_snaps/` changes.
  8. The full suite passes with no new warning. `air format --check` passes
     on the touched file. Line coverage is at or above 95% with
     `NOT_CRAN=true`.
- **Files touched**
  - `tests/testthat/test-constructors.R`
- **Pipeline tier**: recommended — row 1.7 pins all nine published defaults
  in one block, so a later edit to any of them turns it red.

---

### [x] PR 4: `fix/replicate-scale-nonprob-divergence` — the infinite scale in the engine, the two constructors, and the nonprob help page

- **Budget** — 4 test-spec rows (§2 row 2.3; §3 rows 3.1, 3.2; §4 row 4.2) |
  7 criteria
- **Tasks**
  1. Cut the branch from `develop` after PR 3 merges. Run the full suite and
     record the baseline counts.
  2. Probe the installed `survey` on both frames of row 2.3 before you write
     the block. Read back the stored scale, the standard error and the
     bounds, and read back any condition `survey` raises. Record the
     version. If `survey` raises a condition, match it by message text,
     assert it, and report the finding. Silence nothing.
  3. Write the frame A block of row 2.3 in
     `tests/testthat/test-variance-replicate.R`. Assert the premise first,
     then the conclusion. Run it. Confirm it passes.
  4. Write the frame B block of row 2.3. Assert the premise first, then the
     conclusion. Run it. Confirm it passes.
  5. Mutation-check row 2.3: set `R/core-constructors.R:813` back to
     `1 / n_rep` and confirm both blocks turn red, because a finite scale
     produces neither the infinite nor the `NaN` outcome. Revert and re-run.
  6. Write the block for row 3.1 in `tests/testthat/test-constructors.R`.
     Run it. Confirm it passes.
  7. Write the block for row 3.2 in the same file. Run it. Confirm it
     passes.
  8. Mutation-check row 3.2: set `:813` back and confirm the ratio assertion
     turns red. Revert and re-run.
  9. Confirm `git status` shows no change to the switch lines.
  10. Add D1's note to the `as_survey_nonprob()` `@details` paragraph at
      `R/core-constructors.R:1306-1311`. It carries the four elements of
      `spec.md` §`as_survey_nonprob()` roxygen. Keep the existing Wu (2022)
      and Chen et al. (2021) citation. Its percentage is 2.5% and not 2.6%.
  11. Run `devtools::document()`. Commit `man/as_survey_nonprob.Rd` in the
      same commit as the roxygen change.
  12. Read the rendered help page and confirm criterion 5.
  13. Run the full suite and the gates of criteria 6 and 7.
- **Acceptance criteria**
  1. A block on frame A asserts the premise first: a design built on the
     same frame with an explicit `scale = 1` has a standard error that is
     finite and greater than zero. It then asserts that the default-scale
     design has an infinite standard error and two infinite confidence
     bounds, with `expect_true(is.infinite(...))`. `survey` on the same
     frame and the same arguments reaches the same outcome, asserted the
     same way and against its own literal, never against the other side.
     `expect_no_warning()` wraps the `svrepdesign()` call. Neither estimate
     raises a condition.
  2. A block on frame B asserts the premise first: the explicit-`scale = 1`
     design has a standard error of exactly `0`, asserted with
     `expect_equal(..., 0, tolerance = 0)`. It then asserts that the
     default-scale design has a `NaN` standard error and two `NaN`
     confidence bounds, with `expect_true(is.nan(...))`. `survey` reaches
     the same outcome, asserted the same way and against its own literal,
     never against the other side. `expect_no_warning()` wraps
     the `svrepdesign()` call. Both blocks call the surveycore estimator
     with `variance = c("se", "ci")` and `min_cell_n = 1L`.
  3. A block asserts that `as_survey_replicate()` and `as_survey_nonprob()`
     store the same JKn `scale` on one frame, that each equals `1`, and that
     the two designs return the same mean at `1e-10` and the same standard
     error at `1e-8`.
  4. A block asserts that the replicate design stores `1 / (n_rep - 1)` for
     the bootstrap and the nonprob design stores `1 / n_rep`, each against
     its own literal at `1e-8`, and that the ratio of the nonprob standard
     error to the replicate standard error equals
     `sqrt((n_rep - 1) / n_rep)` at `1e-8`.
  5. The rendered help page for `as_survey_nonprob()` carries four elements:
     `survey`'s bootstrap value `1 / (R - 1)`; `as_survey_replicate()` as
     the constructor that matches it; the reason this constructor keeps
     `1 / R`, which is that `survey` has no non-probability design class;
     and the size of the divergence, which is a fall of 2.5% at `R = 20`. A
     rendered 2.6% there is a defect to report. The Wu (2022) and Chen et
     al. (2021) citation is still on the page.
  6. `tests/testthat/test-constructors.R` calls `test_invariants()` four
     times and `tests/testthat/test-variance-replicate.R` calls it once,
     which are the counts before this PR. `devtools::document()` leaves no
     uncommitted change under `man/` or in `NAMESPACE`.
  7. The full suite passes with no new warning. No file under
     `tests/testthat/_snaps/` changes. `R CMD check` gives 0 errors, 0
     warnings and at most the two pre-approved notes. `air format --check`
     passes on every file this PR touches. Line coverage is at or above 95%
     with `NOT_CRAN=true`.
- **Files touched**
  - `R/core-constructors.R`
  - `man/as_survey_nonprob.Rd`
  - `tests/testthat/test-variance-replicate.R`
  - `tests/testthat/test-constructors.R`
- **Pipeline tier**: recommended — it touches four files, it documents a
  divergence between two exported constructors, and row 2.3 is the only row
  that drives the variance engine with an infinite scale.

---

### [x] PR 5: `fix/replicate-scale-release-notes` — the migration note, the changelog entry and the closing sweep

- **Budget** — 2 test-spec rows (§4 rows 4.5, 4.6) | 5 criteria
- **Tasks**
  1. Cut the branch from `develop` after PR 4 merges.
  2. Add one entry to `NEWS.md` under the existing `## Bug fixes` heading,
     beside #242's entry at lines 135-146. Keep #242's entry. Write the new
     entry so a later PR appends to it rather than opening a second
     migration note. It carries the six elements of `spec.md` §The
     migration note. Take the factor and the percentage from behaviour
     rule 6 and compute neither.
  3. Create `changelog/fix-replicate-scale-jkn-bootstrap.md` on the pattern
     of `changelog/fix-jk2-default-scale.md`.
  4. Run the closing sweep for row 4.5. Compare the working tree against the
     commit `develop` sat at before PR 1. List every changed file under
     `tests/`. Confirm the list holds two files and no third, and that no
     file under `tests/testthat/_snaps/` is in it.
  5. Run the full suite, `R CMD check`, `pkgdown::build_site()` and
     `covr::package_coverage()` with `NOT_CRAN=true`.
- **Acceptance criteria**
  1. `NEWS.md` carries one entry for this work under the bug-fix heading,
     and it carries six elements: both changed types with both new values;
     the direction and the size of the move; the explicit `scale` values
     that reproduce the old numbers; the reason `as_survey_nonprob()` keeps
     `1 / R`; the issue number `#253`; and one clause separating the two
     changes — the JKn move corrects a formula error and cites Wolter, and
     the bootstrap move aligns surveycore with `survey`'s convention and
     does not mean an older `1 / R` number was wrong. The entry does not
     claim to cover issue #243. #242's own entry is still there.
  2. One file exists under `changelog/` for this work. `test-spec.md` row
     4.6 asserts that the file exists; the ten elements below come from
     `spec.md` §The changelog entry and from no test-spec row. The file
     carries a branch, a status, a date, the PR numbers, the issue numbers,
     a summary with the measured before-and-after table, the changed files
     and a verification list. It records the E5 window, and it records that
     this work clears one of the two sanctioned exceptions in
     `.claude/rules/testing-surveycore.md` and not both.
  3. Across the whole arc, the only changed files under `tests/` are
     `tests/testthat/test-constructors.R` and
     `tests/testthat/test-variance-replicate.R`. No file under
     `tests/testthat/_snaps/` changed. A changed snapshot is a finding to
     report and not a snapshot to accept.
  4. The full suite passes with no new warning. `R CMD check` gives 0
     errors, 0 warnings and at most the two pre-approved notes.
     `pkgdown::build_site()` runs clean.
  5. Line coverage is at or above 95%, measured with `NOT_CRAN=true`, and
     the report states the figure and the change against the baseline.
- **Files touched**
  - `NEWS.md`
  - `changelog/fix-replicate-scale-jkn-bootstrap.md`
- **Pipeline tier**: optional — no exported function changes, no number
  moves, no contract changes, and the PR writes two files.

---

## Row coverage — every test-spec row lands once

20 rows, 5 PRs, no row in two PRs.

| Row | PR |
|---|---|
| §1 1.1 | PR 2 |
| §1 1.2 | PR 2 |
| §1 1.3 | PR 2 |
| §1 1.4 | PR 2 |
| §1 1.5 | PR 2 |
| §1 1.6 | PR 3 |
| §1 1.7 | PR 3 |
| §1 1.8 | PR 3 |
| §1 1.9 | PR 3 |
| §2 2.1 | PR 1 |
| §2 2.2 | PR 1 |
| §2 2.3 | PR 4 |
| §3 3.1 | PR 4 |
| §3 3.2 | PR 4 |
| §4 4.1 | PR 1 |
| §4 4.2 | PR 4 |
| §4 4.3 | PR 1 |
| §4 4.4 | PR 1 |
| §4 4.5 | PR 5 |
| §4 4.6 | PR 5 |

## Budget check

| PR | Rows | Bound 12 | Criteria | Bound 8 |
|---|---|---|---|---|
| PR 1 | 5 | inside | 7 | inside |
| PR 2 | 5 | inside | 7 | inside |
| PR 3 | 4 | inside | 8 | inside |
| PR 4 | 4 | inside | 7 | inside |
| PR 5 | 2 | inside | 5 | inside |

## Why the map is five PRs and not one

`spec.md` §Header estimates one PR. The test-spec holds 20 rows and the row
bound is 12, so one PR is not available. The split follows the ordering
constraint and the write surface:

- PR 1 is the smallest change that leaves the suite green. It cannot shrink:
  removing any of its four edits leaves a red suite at the merge.
- PR 2 and PR 3 split §1 by criteria count. §1 holds nine rows, and nine
  rows in one PR needs more than eight criteria to stay observable at the
  row level. PR 3 takes row 1.9 because §1's later rows land there, because
  the block goes in `tests/testthat/test-constructors.R`, which is already
  PR 3's whole write surface, and because the row asserts a changed default
  and so must merge after PR 1.
- PR 4 groups the three rows that compare two things against each other —
  surveycore against `survey` at an infinite scale, and the two constructors
  against each other — with the help-page note that documents the second
  comparison.
- PR 5 holds the prose that can only be written once the numbers are final.

## Rules that bind every PR

- `.claude/rules/code-style.md` — 80-column lines, `air` formatting, `class=`
  on every condition surveycore raises. This work raises no new condition.
- `.claude/rules/testing-surveycore.md` — the oracle rule in all five parts
  for rows 2.1, 2.2 and 2.3; `test_invariants()` once per constructor per
  file; point `1e-10`, SE `1e-8`, CI bounds `1e-6`.
- `.claude/rules/r-package-conventions.md` — run `devtools::document()`
  before committing a roxygen change; `R CMD check` gives 0 errors, 0
  warnings and at most the two pre-approved notes.
- `.claude/rules/github-strategy.md` — every branch cuts from `develop` and
  merges back to `develop` with a squash. Commit messages follow
  Conventional Commits.
- Do not count constructs in `tests/testthat/test-variance-replicate.R` with
  `grep -c`. That file discusses its own constructs in comments and titles,
  so a textual count reads high. Read the blocks.
- If any PR needs a condition class that `spec.md` does not name, stop and
  raise a HOLD. Invent no class.
