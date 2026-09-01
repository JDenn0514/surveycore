# Implementation plan — haven-labelled

**Version**: 2.0
**Date**: 2026-08-31
**Sources**: `spec.md` v1.0, `test-spec.md` v1.0, `decisions.md` D1–D7 (all
SETTLED), both upstream artifacts as amended on 2026-08-31 by D6
**Supersedes**: v1.0 (seven PRs), after `plan-review.md` pass 1 —
2 BLOCK, 4 REQUIRED, 4 SUGGESTED, all resolved here
**Shape decision**: D7, settled by the user on 2026-08-31 — the strip ships
as two merges and the whole-feature close-out as a third. Recorded in
`decisions.md` §D7; PR 3a restates the part that governs its own merge.
**Base**: worktree `haven-labelled`, branch `fix/haven-labelled-analysis` at
`b55a679`; the source tree it changes is `develop` at `cf6f153`
**Target**: every PR targets `develop`
**Target version**: unchanged. `spec.md` §XI gate 16 requires `DESCRIPTION`
to stay unchanged, so no PR bumps the version.

Nine PRs. Shape:
**PR 1 → PR 2 → PR 3a → PR 3b → (PR 4 ‖ PR 6) → PR 5 → PR 7 → PR 8.**

---

## HOLD-3 — RESOLVED as D6

**The conflict.** `spec.md` §VIII.1 rule 7 told the implementer to validate
`haven_class` "the way the package validates other scalar flags **and** reuse
the existing class". Those two clauses contradict each other. Measured by
grep across `R/` and `plans/error-messages.md`, every scalar-flag class in
the package names its own argument:

| Class | Site |
|---|---|
| `surveycore_error_subset_not_logical` | `plans/error-messages.md:54` |
| `surveycore_error_na_rm_not_logical` | `R/analysis-helpers.R:692` |
| `surveycore_error_sata_not_logical` | `R/core-metadata.R:2816` |
| `surveycore_error_fill_not_logical` | `R/core-metadata.R:2933` |
| `surveycore_error_reverse_coded_not_logical` | `R/core-metadata.R:3260` |

So "the way the package validates other scalar flags" **is** a new
per-argument class. There is no generic one to reuse.

**Resolution — D6, settled by the user on 2026-08-31.** Add one row,
`surveycore_error_haven_class_not_logical`:

```r
cli::cli_abort(
  c(
    "x" = "{.arg haven_class} must be {.code TRUE} or {.code FALSE}.",
    "i" = "Got {.obj_type_friendly {haven_class}}."
  ),
  class = "surveycore_error_haven_class_not_logical"
)
```

`decisions.md` §D6 records the two rejected alternatives. The upstream
artifacts are already amended to match: `spec.md` §VIII.1 rule 7, §VIII.1
error-class note, §II write surface, §IX.1a and §XI gate 13;
`test-spec.md` row D-22 and §5. PR 4 carries the new row.

---

## PR map

### PR 1: `test/haven-labelled-fixtures` — add the three labelled-column fixture builders and pin them against `haven`

Nothing else in this plan can be tested without these builders, and
`make_survey_data(with_labels = TRUE)` cannot serve, because it attaches the
label attributes without ever setting a class (`test-spec.md` §2.1). PR 2 is
the first PR to consume them, so this PR merges first.

- **Tasks**
  1. Add `make_labelled()` to `tests/testthat/helper-test-data.R`, with the
     class vector `c("haven_labelled", "vctrs_vctr", typeof(x))`.
  2. Add `make_labelled_spss()` to the same file, with the four-entry SPSS
     class vector and the optional `na_values` / `na_range` arguments.
  3. Add `make_tagged_na()` to the same file, writing the tag character into
     byte 5 of the `NA_real_` payload in little-endian order.
  4. Write the guard block in a new file
     `tests/testthat/test-labelled-fixtures.R` with rows F-1 to F-4; run it.
  5. Write rows F-5 and F-6 in the same file, each guarded with
     `skip_if_not_installed("haven")`; run them.
  6. Run `NOT_CRAN=false Rscript -e "testthat::test_local()"`; confirm the F
     rows pass and no existing block changes state.
  7. Run `air::format_package()`; confirm no diff outside the two files.

  No red-then-green cycle applies here: these tasks add test tooling, not
  behaviour. The builders are proved by F-1 to F-6, which must pass on the
  unmodified `R/`.

- **Acceptance criteria**
  - F-1, F-2 and F-4 pass (`test-spec.md` §2.2): `make_tagged_na("a")` is
    `NA`, is a double, and is not identical to `make_tagged_na("b")`.
  - F-3 passes: `haven::na_tag(make_tagged_na("a"))` returns `"a"`
    (`test-spec.md` §2.2).
  - F-5 passes: `make_labelled()` output is `identical()` to
    `haven::labelled()` output (`test-spec.md` §2.2).
  - F-6 passes: `make_labelled_spss()` output is `identical()` to
    `haven::labelled_spss()` output (`test-spec.md` §2.2).
  - `git diff --stat R/ NAMESPACE DESCRIPTION` is empty.
  - The full run `Rscript -e "devtools::test()"` reports 0 failures and 0
    errors, and the pre-existing expectation count rises only by the F rows.

- **Files touched**
  - `tests/testthat/helper-test-data.R` — modified
  - `tests/testthat/test-labelled-fixtures.R` — created

  No snapshot file: F-1 to F-6 carry no error row and no snapshot row.

- **Pipeline split**: optional — test tooling only, no new exported
  function, no numerical method change, no contract change, 2 files.

---

### PR 2: `refactor/haven-available-helper` — route the runtime `haven` check through a named binding so the unavailable branch is reachable

Delivers `spec.md` §I item 5. It must land before PR 3a, because row G-4 in
PR 3a's new analysis file needs the stub.

**It also lands after PR 1.** Row H-2 builds a tagged `NA` and carries no
`haven` guard (`test-spec.md` §4.9), so the only builder available to it is
`make_tagged_na()`, which PR 1 adds. On a branch without PR 1 the row errors
on a missing function instead of failing as a red test, so the TDD step
cannot be performed. Duplicating the byte construction inline was rejected:
`.claude/rules/engineering-preferences.md` §1 requires the fixture to exist
in one place.

- **Tasks**
  1. Write failing row H-2 in `tests/testthat/test-analysis-helpers.R`: a
     grouped call with a tagged-`NA` group column built by
     `make_tagged_na()`, availability stubbed to `FALSE` with
     `testthat::local_mocked_bindings()`. It fails now, because there is no
     binding to stub.
  2. Write failing rows H-1 and H-3 in the same file. Guard H-1 with
     `skip_if_not_installed("haven")`; H-2 and H-3 need no guard.
  3. Run the file; record the failing row identifiers in
     `implementation.md` (`test-spec.md` §4.11a).
  4. Add `.haven_available()` at the top of `R/analysis-helpers.R`, with the
     body from `spec.md` §II and a `#' @noRd` marker.
  5. Replace the inline `requireNamespace("haven", quietly = TRUE)` call at
     `R/analysis-helpers.R:243` with `haven_ok <- .haven_available()`. Leave
     the six use sites alone.
  6. Verify H-1, H-2 and H-3 pass.
  7. Confirm the seven existing tagged-`NA` blocks listed in
     `test-spec.md` §3 still pass unchanged.
  8. Run `air::format_package()`, then `Rscript -e "devtools::test()"`, then
     `devtools::check()`.

- **Acceptance criteria**
  - H-1 passes: with availability stubbed to `TRUE` and `haven` installed,
    the tagged-`NA` label appears as a factor level (`test-spec.md` §4.9).
  - H-2 passes: with availability stubbed to `FALSE`, the call raises no
    error, the tagged-`NA` rows carry an `NA` group, and every non-tagged
    label still resolves (`test-spec.md` §4.9).
  - H-3 passes: a grouped call with no tagged `NA` gives an identical result
    under both stub values (`test-spec.md` §4.9).
  - `.haven_available()` is a top-level function in the package namespace, so
    `local_mocked_bindings()` reaches it. H-1, H-2 and H-3 passing is the
    observable proof: none of the three can run unless the binding is
    stubbable.
  - **Verified by inspection, not by a test row or a gate**: `R/` contains
    exactly one `requireNamespace("haven"` call, and it is inside
    `.haven_available()`. Check it with
    `grep -rn 'requireNamespace("haven"' R/`, and record the output in
    `implementation.md`. The `survey` and `srvyr` calls in
    `R/methods-conversion.R` are unchanged.
  - The seven tagged-`NA` blocks in `test-spec.md` §3 pass unchanged; none is
    moved or deleted.
  - `git diff --stat DESCRIPTION NAMESPACE` is empty (`spec.md` §XI.16).

- **Files touched**
  - `R/analysis-helpers.R` — modified
  - `tests/testthat/test-analysis-helpers.R` — modified

  No snapshot file: H-1 to H-3 carry no error row and no snapshot row, so
  `tests/testthat/_snaps/analysis-helpers.md` is untouched.

- **Pipeline split**: optional — no new exported function, no numerical
  method change, no user-visible contract change, 2 files. The change is a
  named binding around a call whose behaviour is identical.

---

### PR 3a: `fix/labelled-class-strip-setter` — no `@data` write stores the `haven_labelled` class

Delivers the first half of `spec.md` §I item 1: the two strip helpers in
`R/utils.R` and the `setter` on the `data` property of `survey_base`
(`spec.md` §III Part 2). It owns **gate 8**.

**Why the strip ships as two merges — D7, settled by the user on
2026-08-31, recorded in `decisions.md` §D7.** v1.0 of this plan merged both
halves into one PR of 25 tasks and 10 files, and gave three reasons. Two of
them did not survive review; §D7 records both so they do not come back, and
they are not restated here. The shape is now:

| PR | Content | Gate |
|---|---|---|
| PR 3a | the two helpers, plus the property setter — `spec.md` §III Part 2 | gate 8 |
| PR 3b | the four constructor-entry strip calls — `spec.md` §III Part 1 | gate 9 |

The seam is the one lens 1 named: PR 3a adds the helpers and the single
route that no constructor can reach; PR 3b adds four call sites of a helper
that already exists on the branch. Each half is reviewable on its own, and
`spec.md` §X.1 names the routes that isolate each: a direct S7 construction
call and a bare `@data <-` assignment isolate Part 2; a labelled `weights`
or `fpc` column isolates Part 1.

**The intermediate state is accepted.** After PR 3a merges and before PR 3b
merges, a frame whose `weight` or `fpc` column carries the labelled class
still aborts with `vctrs_error_ptype2` (`spec.md` §III.0). That is exactly
today's behaviour on `develop`, so the intermediate state is not a
regression — it is an unfixed defect that stays unfixed for one merge. PR 3b
closes it, and gate 9 is what proves it closed.

- **Tasks**
  1. Write the failing Part-2 route rows in
     `tests/testthat/test-s7-classes.R`: S-24 to S-29 — all four exported
     class constructors called directly with a labelled frame, a bare
     `d@data <- labelled_df` assignment, an estimate after that assignment,
     and a grouped `get_quantiles()` — plus S-35 to S-37 with
     `expect_error(class = ...)` only and no snapshot
     (`test-spec.md` §4.3).
  2. Write the failing `survey_data()` rows D-1 to D-6 in
     `tests/testthat/test-utils.R`, and the failing snapshot rows T-1 and
     T-3 in `tests/testthat/test-methods-print.R` with a small tibble
     fixture.
  3. Write the failing analysis sweep in a new file
     `tests/testthat/test-labelled-analysis.R`: rows A-1 to A-31 and G-1 to
     G-6. Call `test_invariants(design)` once for each constructor this file
     exercises, in the first block that builds with it. G-4 stubs the
     `.haven_available()` binding PR 2 added.
  4. Run the affected files; record in `implementation.md` the count of
     failing tests and the identifier of every failing row
     (`test-spec.md` §4.11a). Compare against §4.11a's expected-to-fail list,
     and flag any row in the expected-to-pass list that failed.
  5. Add `.strip_labelled_class()` to `R/utils.R`, beside `survey_data()`,
     with the body from `spec.md` §II; then add
     `.strip_labelled_columns()` to the same file. The per-column body must
     call `.strip_labelled_class()`. Keep the
     `if (length(hit) == 0L) return(data)` early return and the single
     `inherits()` call per column (`spec.md` §III.6).
  6. Add the `setter` to the `data` property at `R/core-classes.R:305-308`,
     with the body and the comment from `spec.md` §III.4. Use the plain
     `self@data <- ...` form.
  7. Verify rows S-24 to S-29, S-35 to S-37, D-1 to D-6, T-1, T-3, A-1 to
     A-31 and G-1 to G-6 pass. Demonstrate that the inherited setter fires
     for `survey_twophase` at construction and on assignment, which closes
     the GAP in `spec.md` §III.4. Record the installed S7 version in
     `implementation.md`.
  8. Review the T-1 and T-3 snapshots by hand with
     `testthat::snapshot_review()`. Do not accept blind.
  9. Measure the timing of one grouped `get_quantiles()` call with three
     probabilities on the widest bundled dataset, before and after, with
     `bench::mark()` or `system.time()`. Record the ratio in
     `implementation.md`. Stop and report if the ratio exceeds about 1.05
     (`spec.md` §III.6).
  10. Add the `NEWS.md` entry for the loss of a caller's own class stacked
      above `haven_labelled`, under a `## Breaking changes` heading. Then run
      `air::format_package()`, `Rscript -e "devtools::test()"` and
      `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-s7-classes.R` passes rows S-24 to S-29 and S-35 to
    S-37 (`test-spec.md` §4.3), including a direct `survey_twophase()`
    construction — this is the observable close of the GAP in
    `spec.md` §III.4.
  - `tests/testthat/test-utils.R` passes rows D-1 to D-6
    (`test-spec.md` §4.8).
  - `tests/testthat/test-labelled-analysis.R` passes rows A-1 to A-31
    (`test-spec.md` §4.4) and G-1 to G-6 (`test-spec.md` §4.5).
  - `tests/testthat/test-methods-print.R` T-1 snapshot shows the type tokens
    `<dbl>`, `<int>` and `<chr>`; T-3 shows the design print output unchanged
    (`test-spec.md` §4.8a). Both snapshots reviewed by hand.
  - Every labelled-input-equals-plain-input comparison uses
    `expect_identical()` or `expect_equal(tolerance = 0)`
    (`test-spec.md` §6, departure 1).
  - Gate 8 (`spec.md` §XI.8): no `@data` column inherits `haven_labelled`
    after any route in `spec.md` §III.1, demonstrated for all four concrete
    design classes and after a bare `des@data <- labelled_df` assignment.
    Rows S-24 to S-26 give the four classes and the bare assignment; rows
    D-1 to D-4 give the `as_survey()` route with every attribute still
    readable.
  - A labelled `weights` column and a labelled `fpc` column still abort on
    this branch. Do not write a row asserting they succeed — that is gate 9
    and PR 3b owns it.
  - `implementation.md` records the timing ratio required by
    `spec.md` §III.6 (gate 17) and the S7 version the setter behaviour was
    confirmed against (gate 18).
  - `NEWS.md` carries 1 of the 5 entries required by `spec.md` §XI.15: the
    stacked-class loss from `spec.md` §III.3a.
  - The seven existing tagged-`NA` blocks in `test-spec.md` §3 pass
    unchanged.
  - `implementation.md` carries the red-run record from
    `test-spec.md` §4.11a: the failure count and every failing row
    identifier.
  - `git diff --stat DESCRIPTION NAMESPACE` is empty (`spec.md` §XI.16).
  - `Rscript -e "devtools::test()"` reports 0 failures and 0 errors, with no
    warning attributable to this PR. **Corrected 2026-09-01: not 0
    warnings.** The suite carries 256 by design — the AAPOR small-cell and
    `survey_nonprob` SRS-approximation notices, tracked by issue #167.
  - `devtools::check()` reports 0 errors, 0 warnings, at most the two
    pre-approved notes.

- **Files touched**
  - `R/utils.R` — modified (two strip helpers)
  - `R/core-classes.R` — modified (the `data` property setter)
  - `NEWS.md` — modified (1 entry)
  - `tests/testthat/test-s7-classes.R` — modified
  - `tests/testthat/test-utils.R` — modified
  - `tests/testthat/test-methods-print.R` — modified
  - `tests/testthat/_snaps/methods-print.md` — modified (T-1, T-3)
  - `tests/testthat/test-labelled-analysis.R` — created

  No `tests/testthat/_snaps/s7-classes.md`: S-35 to S-37 take
  `expect_error(class = ...)` only, because they reach the class validators
  (`test-spec.md` §4.3). No `tests/testthat/_snaps/labelled-analysis.md`:
  §4.4 and §4.5 carry no error row and no snapshot row. No
  `tests/testthat/_snaps/utils.md`: D-1 to D-6 assert stored state, not
  errors — PR 4 is the PR that writes that file.

- **Pipeline split**: recommended — a storage contract change on every
  `@data` write and a new S7 property setter.

---

### PR 3b: `fix/labelled-class-strip-constructors` — a design constructs from a frame whose design variables carry the labelled class

Delivers the second half of `spec.md` §I item 1: the strip call on entry to
each of the four constructors (`spec.md` §III Part 1). It owns **gate 9**,
and it closes the intermediate state PR 3a accepted.

The helper it calls, `.strip_labelled_columns()`, already exists on the
branch. This PR adds four call sites of it and the test file that proves the
two routes PR 3a could not reach.

- **Tasks**
  1. Write the failing storage rows S-1 to S-13 in a new file
     `tests/testthat/test-labelled-storage.R`. Call `test_invariants(design)`
     once for each of the four constructors, in the first block in the file
     that builds with it.
  2. Write the failing design-variable rows in the same file: S-14 to S-20,
     S-23b to S-23e, S-23h, and S-31 to S-33 — labelled `weights`, `fpc`,
     cluster plus stratum at both `nest` values, single design columns,
     labelled `probs`, labelled replicate weights, the two-phase phase-2
     design columns, the SRS shape, the derived-weights shape, and a tagged
     `NA` in a weight column (`test-spec.md` §4.2).
  3. Write the eight failing dual-pattern rows in the same file: S-21, S-22,
     S-23, S-23a, S-23f, S-23g, S-30 and S-34. Each takes
     `expect_error(class = ...)` **and** `expect_snapshot(error = TRUE, ...)`
     (`test-spec.md` §5).
  4. Run the file; record in `implementation.md` the failure count and every
     failing row identifier. Note in that record that S-1 to S-13 pass as
     soon as they are written, because PR 3a's setter already covers those
     routes: in this PR they are regression fences, not red tests. The rows
     that must be red here are S-14, S-15, S-16, S-19, S-23b to S-23e, S-31
     and S-32 (`test-spec.md` §4.11a).
  5. Add `data <- .strip_labelled_columns(data)` to `as_survey()`,
     immediately after `.validate_data_frame(data)` at
     `R/core-constructors.R:184`.
  6. Add the same line to `as_survey_replicate()` and to
     `as_survey_nonprob()`, each immediately after its own
     `.validate_data_frame(data)` call.
  7. Add the same line to `as_survey_twophase()`, immediately after
     `data <- phase1@data` at `R/core-constructors.R:955`.
  8. Verify rows S-1 to S-23h and S-30 to S-34 pass.
  9. Review the eight new error snapshots in
     `tests/testthat/_snaps/labelled-storage.md` by hand with
     `testthat::snapshot_review()`. Do not accept blind.
  10. Add the `NEWS.md` entry for the storage contract change. Then run
      `air::format_package()`, `Rscript -e "devtools::test()"` and
      `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-labelled-storage.R` passes rows S-1 to S-13
    (`test-spec.md` §4.1) and S-14 to S-23h, S-30 to S-34
    (`test-spec.md` §4.2).
  - Gate 9 (`spec.md` §XI.9): a design constructs and estimates correctly
    from a frame whose weight column is labelled, and from a frame whose FPC
    column is labelled, on `as_survey()` and on `as_survey_replicate()`.
    Rows S-14, S-15, S-23b, S-23c. These are the rows that isolate Part 1,
    and every one of them aborts on the branch PR 3a left.
  - S-23d and S-23e pass, so the `as_survey_nonprob()` route is confirmed
    rather than inferred (`spec.md` §III.5, evidence boundary).
  - S-21, S-22, S-23, S-23a, S-23f, S-23g, S-30 and S-34 each raise their
    named class with the dual pattern (`test-spec.md` §5). The strip must not
    launder an invalid weight, an invalid FPC value, or a non-logical
    two-phase `subset` column.
  - S-17 and S-18 still pass. They pass on the base tree as well, so they are
    a regression fence and not evidence (`test-spec.md` §4.11a).
  - Every labelled-input-equals-plain-input comparison uses
    `expect_identical()` or `expect_equal(tolerance = 0)`
    (`test-spec.md` §6, departure 1).
  - `tests/testthat/_snaps/labelled-storage.md` is committed, and every one
    of its eight blocks was read in `testthat::snapshot_review()`. None was
    accepted blind (`.claude/rules/testing-standards.md`).
  - `NEWS.md` carries the second of the 5 entries required by
    `spec.md` §XI.15: the storage contract change.
  - `implementation.md` carries the red-run record from
    `test-spec.md` §4.11a, including the note about S-1 to S-13.
  - `git diff --stat DESCRIPTION NAMESPACE man/` is empty — this PR changes
    code only, with no roxygen change (`spec.md` §XI.16).
  - `Rscript -e "devtools::test()"` reports 0 failures and 0 errors, with no
    warning attributable to this PR. **Corrected 2026-09-01: not 0
    warnings.** The suite carries 256 by design — the AAPOR small-cell and
    `survey_nonprob` SRS-approximation notices, tracked by issue #167.
  - `devtools::check()` reports 0 errors, 0 warnings, at most the two
    pre-approved notes.

- **Files touched**
  - `R/core-constructors.R` — modified (four strip-on-entry calls; code only,
    no roxygen change, so `man/` is untouched by this PR)
  - `NEWS.md` — modified (1 entry)
  - `tests/testthat/test-labelled-storage.R` — created
  - `tests/testthat/_snaps/labelled-storage.md` — created (S-21, S-22, S-23,
    S-23a, S-23f, S-23g, S-30, S-34)

- **Pipeline split**: recommended — a contract change on all four
  constructors: an input that aborts today now constructs.

---

### PR 4: `feat/survey-data-haven-class` — `survey_data(x, haven_class = TRUE)` rebuilds the labelled class on request

Delivers `spec.md` §I item 6, and the documentation half of item 1: the
`@return` contract text on `survey_data()` and on the four constructors.

**Why the constructor `@return` text lives here, not in PR 3b.** The required
paragraph in `spec.md` §VIII.1 names `survey_data(x, haven_class = TRUE)` as
the supported read-back route. Shipping that sentence before the argument
exists would document an argument the package does not have.

- **Tasks**
  1. Write the failing `haven_class` rows D-7 to D-16 in
     `tests/testthat/test-utils.R`: the default fence D-7, the class-vector
     rows D-9 to D-13 asserted whole with `expect_identical()` rather than
     `inherits()`, and the round-trip rows D-14 to D-16. None of these rows
     may use `skip_if_not_installed("haven")`.
  2. Write the failing rows D-17 to D-21 in the same file, each guarded by
     the package the row hands the result to, and each write row using
     `withr::local_tempfile()`.
  3. Write the failing dual-pattern rows D-22 and D-23 in the same file, and
     the failing snapshot row T-2 in
     `tests/testthat/test-methods-print.R`.
  4. Run both files; record the failing row identifiers in
     `implementation.md`. Rows D-7 to D-23 are expected to fail with
     "unused argument" (`test-spec.md` §4.11a).
  5. Add `.restore_haven_class()` to `R/utils.R`, with the body from
     `spec.md` §II. Write the class chain with base R; do not call
     `haven::labelled()` or `haven::labelled_spss()`.
  6. Add `haven_class = FALSE` to the `survey_data()` signature after `x`;
     validate it as a length-one logical with the class settled by D6,
     `surveycore_error_haven_class_not_logical`; apply
     `.restore_haven_class()` to every column when `haven_class` is `TRUE`
     and return `@data` unchanged when it is `FALSE`.
  7. Verify rows D-7 to D-23 and T-2 pass. Review the new snapshots in
     `tests/testthat/_snaps/utils.md` and
     `tests/testthat/_snaps/methods-print.md` by hand with
     `testthat::snapshot_review()`.
  8. Write the `@param haven_class` and `@return` text for `survey_data()`
     per `spec.md` §VIII.1, including the printed-token sentence and the one
     sentence about `haven::write_sav()` on a tagged `NA`; then add the
     `@return` paragraph from `spec.md` §VIII.1 to `as_survey()`,
     `as_survey_replicate()`, `as_survey_twophase()` and
     `as_survey_nonprob()`, each naming its own return class.
  9. Add the `surveycore_error_haven_class_not_logical` row to
     `plans/error-messages.md`, in the scalar-flag group beside the four
     existing per-argument flag classes; add the `NEWS.md` entry for the new
     argument.
  10. Run `devtools::document()` and confirm `man/` is in sync; then
      `devtools::run_examples()`, `air::format_package()`,
      `Rscript -e "devtools::test()"` and `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-utils.R` passes rows D-7 to D-23
    (`test-spec.md` §4.8, "The `haven_class` argument").
  - Rows D-9 to D-13 assert the whole class vector with
    `expect_identical()`, including the four-entry SPSS chain
    (`test-spec.md` §4.8, note on D-9 to D-13).
  - Gate 11 (`spec.md` §XI.11): `survey_data(x, haven_class = TRUE)` returns
    columns whose class chain is exactly the chain the import produced, SPSS
    variant included, with `haven` not installed. Observable proof: rows D-8
    to D-15 carry no `skip_if_not_installed("haven")` and pass.
  - No test asserts an error for "`haven` is not installed" under
    `haven_class = TRUE` (`test-spec.md` §4.8). Its presence would mean the
    wrong implementation route was taken.
  - D-22 raises the class recorded in `plans/error-messages.md`, with the
    dual pattern (`test-spec.md` §5).
  - D-23 still raises `surveycore_error_not_survey_object`, dual pattern
    (`test-spec.md` §5).
  - T-2 snapshot shows the type token `<hvn_lbl>` (`test-spec.md` §4.8a).
  - Every new snapshot block in `tests/testthat/_snaps/utils.md` and
    `tests/testthat/_snaps/methods-print.md` was read in
    `testthat::snapshot_review()`; none accepted blind.
  - Gate 1 (`spec.md` §XI.1): `devtools::document()` runs clean and `man/` is
    committed in sync with the roxygen source.
  - Gate 3 (`spec.md` §XI.3): `devtools::run_examples()` clean.
  - `NEWS.md` carries the third of the five entries required by
    `spec.md` §XI.15: the new `haven_class` argument.
  - `git diff --stat DESCRIPTION NAMESPACE` is empty — `survey_data()` gains
    an argument, not an export (`spec.md` §XI.16).

- **Files touched**
  - `R/utils.R` — modified (`.restore_haven_class()`, `survey_data()`)
  - `R/core-constructors.R` — modified (roxygen `@return` only)
  - `plans/error-messages.md` — modified (one row; see D6)
  - `NEWS.md` — modified (1 entry)
  - `man/survey_data.Rd` — regenerated
  - `man/as_survey.Rd` — regenerated
  - `man/as_survey_replicate.Rd` — regenerated
  - `man/as_survey_twophase.Rd` — regenerated
  - `man/as_survey_nonprob.Rd` — regenerated
  - `tests/testthat/test-utils.R` — modified
  - `tests/testthat/test-methods-print.R` — modified
  - `tests/testthat/_snaps/methods-print.md` — modified (T-2)
  - `tests/testthat/_snaps/utils.md` — modified (D-22, D-23)

- **Pipeline split**: recommended — a new argument on an exported function,
  a contract change on `survey_data()`, and a new error class.

---

### PR 5: `fix/from-svydesign-metadata` — the `survey`-package conversion routes capture haven-style metadata instead of storing an empty object

Delivers `spec.md` §I item 2, and it carries call sites 6 and 7 of the seven
in `spec.md` §III.0.

- **Tasks**
  1. Write the failing rows C-0 to C-4 in
     `tests/testthat/test-conversion.R`, every block guarded with
     `skip_if_not_installed("survey")`.
  2. Write the failing rows C-5 to C-9 in the same file; add
     `skip_if_not_installed("srvyr")` to C-8.
  3. Run the file; record the failing row identifiers in
     `implementation.md` (`test-spec.md` §4.11a).
  4. Replace `R/methods-conversion.R:382` and `:427` with
     `data <- .strip_labelled_columns(as.data.frame(x$variables))`.
  5. Replace `metadata = survey_metadata()` with
     `metadata = .extract_haven_metadata(data)` in
     `.from_svydesign_taylor()` and in `.from_svydesign_replicate()`.
  6. Replace `metadata = survey_metadata()` with
     `metadata = phase1_sc@metadata` in `.from_svydesign_twophase()`.
  7. Verify rows C-0 to C-9 pass.
  8. Add the second sentence of the `@return` boundary text from
     `spec.md` §XII.2 to `as_svydesign()` and to `as_tbl_svy()`, naming
     `survey_data(x, haven_class = TRUE)` as the supported route.
  9. Run `devtools::document()` and confirm `man/` is in sync; then
     `air::format_package()`, `Rscript -e "devtools::test()"` and
     `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-conversion.R` passes rows C-0 to C-9
    (`test-spec.md` §4.7).
  - Gate 10 (`spec.md` §XI.10): `@metadata@value_labels` is populated on
    every route that builds a design from a frame carrying a `labels`
    attribute, `from_svydesign()` included. Observable proof: rows C-3, C-5
    and C-6 return the labels from `extract_val_labels()`.
  - C-0 passes: a `get_means(label_vars = TRUE)` call over a design produced
    by `from_svydesign()` shows the variable label, not the raw column name
    (`test-spec.md` §4.7).
  - C-2 matches `survey::svymean()` at the default tolerances — point 1e-10,
    standard error 1e-8 (`test-spec.md` §6).
  - C-4 succeeds: `from_svydesign()` on a source frame whose weight column is
    labelled. This aborts before this PR (`test-spec.md` §4.7).
  - Every block in the file is guarded with
    `skip_if_not_installed("survey")`, and C-8 additionally with
    `skip_if_not_installed("srvyr")` (`test-spec.md` §4.7).
  - `devtools::document()` clean, `man/as_svydesign.Rd` and
    `man/as_tbl_svy.Rd` in sync (`spec.md` §XI.1).
  - `git diff --stat DESCRIPTION NAMESPACE` is empty (`spec.md` §XI.16).

- **Files touched**
  - `R/methods-conversion.R` — modified
  - `man/as_svydesign.Rd` — regenerated
  - `man/as_tbl_svy.Rd` — regenerated
  - `tests/testthat/test-conversion.R` — modified

  No snapshot file: §4.7 carries no error row and no snapshot row, so
  `tests/testthat/_snaps/conversion.md` is untouched.

- **Pipeline split**: recommended — a contract change on three conversion
  routes: `@metadata` moves from empty to populated, and the stored columns
  change shape.

---

### PR 6: `fix/set-val-labels-labelled` — `set_val_labels()` accepts a column carrying the labelled class, in both input modes

Delivers `spec.md` §I item 3. One line of production code. The survey-object
mode is already fixed by PR 3a's setter; this PR closes the data-frame mode,
which is never stripped.

Its only prerequisite is PR 3a: it calls `.strip_labelled_class()`, which PR
3a adds, and its survey-object rows need PR 3a's setter. Its write surface is
disjoint from PR 4's, so the two run at the same time.

- **Tasks**
  1. Write failing row M-1 in `tests/testthat/test-metadata-system.R`, in
     both the survey-object mode and the data-frame mode.
  2. Write failing row M-2 in both modes, with
     `expect_warning(result <- ..., class = ...)` plus a snapshot.
  3. Write failing row M-3 in both modes.
  4. Write rows M-4 to M-9 in the survey-object mode only, per the Modes
     column of `test-spec.md` §4.6 and the both-modes rule in
     `.claude/rules/testing-surveycore.md`.
  5. Run the file; record the failing row identifiers in
     `implementation.md` (`test-spec.md` §4.11a).
  6. Change `R/core-metadata.R:3672` to
     `unique_vals <- .strip_labelled_class(unique(var[!is.na(var)]))`.
  7. Verify rows M-1 to M-9 pass.
  8. Review the M-2 warning snapshot by hand with
     `testthat::snapshot_review()`.
  9. Run `air::format_package()`, `Rscript -e "devtools::test()"`,
     `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-metadata-system.R` passes rows M-1 to M-9
    (`test-spec.md` §4.6).
  - M-1 and M-3 pass in both input modes; M-4 to M-9 run in the
    survey-object mode only, matching the Modes column of
    `test-spec.md` §4.6.
  - M-2 raises `surveycore_warning_missing_labels` with the class assertion
    and a reviewed snapshot (`test-spec.md` §5).
  - M-9 passes: `set_val_labels()` on a plain column is unchanged
    (`test-spec.md` §4.6).
  - `git diff --stat DESCRIPTION NAMESPACE man/` is empty — no roxygen
    changes in this PR (`spec.md` §XI.16).
  - `Rscript -e "devtools::test()"` reports 0 failures and 0 errors, with no
    warning attributable to this PR. **Corrected 2026-09-01: not 0
    warnings.** The suite carries 256 by design — the AAPOR small-cell and
    `survey_nonprob` SRS-approximation notices, tracked by issue #167.

- **Files touched**
  - `R/core-metadata.R` — modified
  - `tests/testthat/test-metadata-system.R` — modified
  - `tests/testthat/_snaps/metadata-system.md` — modified (M-2)

- **Pipeline split**: recommended — a contract change: an input that
  currently aborts now succeeds, in both input modes. The change is one line,
  but the behaviour is user-visible.

---

### PR 7: `feat/polychoric-whole-valued-doubles` — a whole-valued, finite double with at most 10 distinct values classifies as ordinal

Delivers `spec.md` §I items 4 and 7. It is the last PR that changes package
source. The whole-feature close-out is PR 8, not this PR.

- **Tasks**
  1. Write the failing classification rows P-1 to P-18f in
     `tests/testthat/test-analysis-corr-latent.R`, including both cardinality
     boundaries and the dual pattern on every error row. P-18a and P-18b are
     the highest-value rows in the section: without the finiteness guard the
     call returns a fabricated correlation of about -0.056 instead of
     raising.
  2. Write the failing numerical rows P-19 to P-23 in the same file at the
     stated tolerances; then the polyserial rows Y-1 to Y-14, with the dual
     pattern on Y-3 and Y-4 and the breaking change named in their block
     descriptions, `skip_if_not_installed("polycor")` on Y-12, and the
     snapshot row E-1.
  3. Write the failing row G-7 in
     `tests/testthat/test-labelled-analysis.R`.
  4. Run the affected files; record in `implementation.md` the failure count
     and every failing row identifier. **Corrected 2026-09-01: P-18a and
     P-18b PASS on the base**, for the wrong reason — the base refuses every
     whole-valued double and never reaches a finiteness test, so the pass is
     not evidence the guard exists. The superseded wording said they fail on the
     base tree for the right reason by accident, per
     `test-spec.md` §4.11a.
  5. Replace `R/analysis-corr-latent.R:55-63` with the `is.double` branch
     from `spec.md` §VI.3, including `all(is.finite(non_na))` before the
     `trunc()` test; replace the contradicting comment at the old
     `R/analysis-corr-latent.R:60-62` with the replacement comment in
     `spec.md` §VI.3; update the header comment block at
     `R/analysis-corr-latent.R:33-40`, where `"integer_ordinal"` and
     `"continuous"` no longer mean what it says.
  6. Verify rows P-1 to P-23, Y-1 to Y-14, E-1 and G-7 pass. Run the four
     existing correlation test files; confirm **290 tests, 825 expectations**,
     0 failures, 0 errors, 0 skips. Corrected 2026-09-01: 246 / 718 is the
     PRE-change baseline, and confirming it on the merged tree would read as
     a regression (`test-spec.md` §4.12).
  7. Review every new snapshot by hand with `testthat::snapshot_review()`.
     The two files carrying a file-level `skip_on_cran()` write snapshots for
     the first time (`test-spec.md` §4.12).
  8. Rewrite `@param x` for `get_corr()` at `R/analysis-corr.R:49-57` per
     `spec.md` §VI.7: add whole-valued doubles to the ordinal set, state the
     false positive in the user's terms, state that in-band missing codes
     must be recoded to `NA` first, and add that a pair of ordinal columns
     raises the mixed-types error. Then update the Condition text of rows
     PC-1, PC-2 and PC-3 in `plans/error-messages.md` per `spec.md` §VI.8,
     changing no class name and no message template.
  9. Add the two remaining `NEWS.md` entries: the polychoric acceptance of
     whole-valued doubles, and the polyserial breaking change from
     `spec.md` §VI.6 under a `## Breaking changes` heading naming the
     affected pair shape.
  10. Run `devtools::document()` and confirm `man/get_corr.Rd` is in sync;
      then `air::format_package()`, `Rscript -e "devtools::test()"` and
      `devtools::check()`.

- **Acceptance criteria**
  - `tests/testthat/test-analysis-corr-latent.R` passes rows P-1 to P-23
    (`test-spec.md` §4.10) and Y-1 to Y-14 (`test-spec.md` §4.11).
  - Gate 12 (`spec.md` §XI.12): `get_corr(method = "polychoric")` raises
    `surveycore_error_polychoric_requires_ordinal` on a column containing
    `Inf` and on one containing `-Inf`. Rows P-18a, P-18b, P-18f.
  - P-18c, P-18d and P-18e succeed: `NA` and `NaN` do not make a scale
    continuous, and they do not count toward the distinct-value limit
    (`test-spec.md` §4.10).
  - P-3 succeeds at exactly 10 distinct values and P-4 raises at exactly 11
    (`test-spec.md` §4.10).
  - P-19 matches the ordered-factor form at 1e-10; P-22 gives the negative
    of the unreversed pair at 1e-10 (`test-spec.md` §4.10).
  - Y-11 matches the ordered-factor form at 1e-10; Y-12 is within 1e-6 of
    `.hand_polyserial_twostep()` and within 5e-3 of
    `polycor::polyserial()`; Y-14 gives the negative of Y-11
    (`test-spec.md` §4.11).
  - Y-3 and Y-4 raise `surveycore_error_polyserial_requires_mixed_types`
    with the dual pattern, and their block descriptions record the breaking
    change (`test-spec.md` §4.11).
  - Y-10 is unchanged — **corrected 2026-09-01: it does not "succeed"**. The
    pair raises an untyped base error on every tree in this series; what the
    row pins is that it does not cross the ordinal/continuous boundary. The
    finiteness guard keeps an `Inf`-carrying
    column continuous, so the pair stays ordinal plus continuous
    (`test-spec.md` §4.11).
  - G-7 passes in `tests/testthat/test-labelled-analysis.R`
    (`test-spec.md` §4.5).
  - E-1 snapshot shows the column class as a plain numeric type
    (`test-spec.md` §5).
  - Gate 13 (`spec.md` §XI.13), the Condition-text half: rows PC-1, PC-2 and
    PC-3 in `plans/error-messages.md` describe the conditions the code now
    raises on. No PC row added, no PC row removed, no class name changed. PR
    8 confirms the whole-feature row count.
  - Gate 14 (`spec.md` §XI.14): no comment in `R/analysis-corr-latent.R`
    contradicts the code it documents. The `is.double` to `continuous`
    comment is gone and the header return-value list is updated.
  - `test-spec.md` §4.12 confirmed: the four existing correlation test files
    report **290 tests, 825 expectations**, 0 failures, 0 errors, 0 skips —
    corrected 2026-09-01 from the pre-change baseline of 246 / 718. Any
    failure is reported, not patched over by relaxing the block.
  - Every new snapshot reviewed with `testthat::snapshot_review()`; none
    accepted blind (`test-spec.md` §4.12).
  - `NEWS.md` carries the fourth and fifth of the five entries required by
    `spec.md` §XI.15. PR 8 counts them.
  - `devtools::document()` clean, `man/get_corr.Rd` in sync
    (`spec.md` §XI.1); `air format --check` produces no diff attributable to
    this feature (`spec.md` §XI.7); `Rscript -e "devtools::test()"` reports 0
    failures and 0 errors, with no warning attributable to this feature —
    256 warnings, unchanged from baseline (`spec.md` §XI.2).
  - `git diff --stat DESCRIPTION NAMESPACE` is empty (`spec.md` §XI.16).

- **Files touched**
  - `R/analysis-corr-latent.R` — modified
  - `R/analysis-corr.R` — modified (roxygen `@param x`)
  - `plans/error-messages.md` — modified (PC-1, PC-2, PC-3 Condition text)
  - `NEWS.md` — modified (2 entries)
  - `man/get_corr.Rd` — regenerated
  - `tests/testthat/test-analysis-corr-latent.R` — modified
  - `tests/testthat/test-labelled-analysis.R` — modified (G-7 only)
  - `tests/testthat/_snaps/analysis-corr-latent.md` — created or modified

  G-7 needs no snapshot file for `test-labelled-analysis.R`: it asserts
  success, not an error (`test-spec.md` §4.5).

- **Pipeline split**: recommended — a numerical behaviour change with a
  documented breaking change and an overturned earlier design decision.

---

### PR 8: `chore/haven-labelled-close-out` — the whole-feature verification pass

Carries no behaviour change. It exists because five checks in `spec.md` §XI
are properties of the **whole feature**, and none of them can be verified
until every other PR has landed. v1.0 loaded them onto PR 7, whose stated
goal is scoped to ordinality; D7 separates them.

It also carries the one `NEWS.md` edit that only makes sense at the end. PR
3a and PR 7 each add an entry under a `## Breaking changes` heading, so after
both merge the file holds two such headings. This PR merges them into one and
puts the five entries in their final order.

Branch from `develop` after PR 7 merges.

- **Tasks**
  1. Confirm every PR from 1 to 7 has merged into `develop`; branch from
     that commit.
  2. Group the five `NEWS.md` entries: the two breaking changes under a
     single `## Breaking changes` heading, the other three under the feature
     heading. Remove the duplicate heading the separate PRs left behind.
     Count the entries.
  3. Run `git diff cf6f153 -- plans/error-messages.md`. Confirm a net **+1**
     row across the whole feature — the D6 row and nothing else — and that
     no PC row was added or removed.
  4. Run `git diff cf6f153 -- DESCRIPTION NAMESPACE`. Confirm it is empty.
  5. Run `devtools::document()`; confirm `man/` is in sync and the run
     produces no diff.
  6. Run `Rscript -e "devtools::test()"` as the whole-suite pass, then
     `devtools::run_examples()`.
  7. Run `R CMD check --as-cran --no-manual`; record the note list.
  8. Run `pkgdown::build_site()`.
  9. Run `covr::package_coverage()` with `NOT_CRAN=true`; record the figure.
  10. Run `air::format_package()`; confirm no diff. Record every figure from
      tasks 3 to 9 in `implementation.md`. If any gate fails, stop and report
      it; do not widen this PR to fix it.

  `cf6f153` is the base commit of the source tree, named in this plan's
  header and in `test-spec.md` §4.11a. Use it rather than `develop`, because
  by the time this PR opens `develop` already carries the feature.

- **Acceptance criteria**
  - **The six profile gates, verbatim from `test-spec.md` §8:**
    - `document` — `devtools::document()` clean, `man/` committed in sync.
    - `test` — `Rscript -e "devtools::test()"`: 0 failures, 0 errors, 0
      warnings.
    - `run_examples` — `devtools::run_examples()` clean.
    - `R CMD check --as-cran` — 0 errors, 0 warnings, at most the two
      pre-approved notes from
      `.claude/rules/r-package-conventions.md`.
    - `pkgdown` — `pkgdown::build_site()` clean.
    - `covr` — `covr::package_coverage()` with `NOT_CRAN=true` at or above
      96.09%; floor 95%.
  - Gate 4 (`spec.md` §XI.4): `R CMD check --as-cran --no-manual` reports 0
    errors, 0 warnings, at most the two pre-approved notes.
  - Gate 5 (`spec.md` §XI.5): `pkgdown::build_site()` clean.
  - Gate 6 (`spec.md` §XI.6): the recorded coverage figure is at or above
    96.09%, measured with `NOT_CRAN=true`. Without that variable eleven
    files skip and the figure reads about 93.7%.
  - Gate 7 (`spec.md` §XI.7): `air format --check .` produces no diff
    **attributable to this feature**. Measured 2026-09-01: 35 files flagged,
    0 attributable. The package-wide no-diff form has never held.
  - Gate 15 (`spec.md` §XI.15): `NEWS.md` carries five entries for this
    feature — the storage contract change, the new `haven_class` argument,
    the polychoric acceptance of whole-valued doubles, the polyserial
    breaking change, and the loss of a caller's own stacked class. The count
    is 5, and the two breaking changes sit under one `## Breaking changes`
    heading.
  - Gate 16 (`spec.md` §XI.16): `git diff cf6f153 -- DESCRIPTION NAMESPACE`
    is empty for the whole feature.
  - Gate 13, the count half: `git diff cf6f153 -- plans/error-messages.md`
    shows a net +1 row, which confirms the D6 row is the only row added and
    that the PC edits changed Condition text only.
  - `implementation.md` records every figure above, so the close-out is a
    record and not a claim.

- **Files touched**
  - `NEWS.md` — modified (heading consolidation and entry order; no new
    entry)

  No snapshot file: this PR adds no test row.

- **Pipeline split**: optional — no new exported function, no numerical
  method change, no contract change, 1 file.

---

## Sequencing

Shape:
**PR 1 → PR 2 → PR 3a → PR 3b → (PR 4 ‖ PR 6) → PR 5 → PR 7 → PR 8.**

### May run concurrently

| Pair | Why it is safe |
|---|---|
| PR 4 and PR 6 | Disjoint write surfaces. PR 4 touches `R/utils.R`, `R/core-constructors.R`, `plans/error-messages.md`, `NEWS.md`, five `man/*.Rd` pages, `tests/testthat/test-utils.R`, `tests/testthat/test-methods-print.R` and two snapshot files. PR 6 touches `R/core-metadata.R`, `tests/testthat/test-metadata-system.R` and `tests/testthat/_snaps/metadata-system.md`. No file appears in both. Both consume `.strip_labelled_class()` from PR 3a; neither edits `R/utils.R`'s strip helpers. |
| PR 5 and PR 6 | Also disjoint, and PR 5's only ordering constraint is PR 4. So PR 5 may open as soon as PR 4 merges, even while PR 6 is still open. |

### Must run in order

| Constraint | Reason |
|---|---|
| PR 1 before PR 2 | Row H-2 needs a tagged `NA` and carries no `haven` guard, so its only builder is `make_tagged_na()` from PR 1. Without PR 1 the row errors on a missing function rather than failing as a red test. |
| PR 1 and PR 2 before PR 3a | PR 3a's new analysis file calls `make_labelled()`, `make_labelled_spss()` and `make_tagged_na()` from PR 1. Row G-4 stubs the `.haven_available()` binding from PR 2. |
| PR 3a before PR 3b | PR 3b's four constructor-entry calls call `.strip_labelled_columns()`, which PR 3a adds to `R/utils.R`. Both also edit `NEWS.md`. |
| PR 3a before PR 4 | Both edit `R/utils.R`, `tests/testthat/test-utils.R`, `tests/testthat/test-methods-print.R` and its snapshot file. PR 4's rows D-8 to D-16 read a frame that PR 3a's setter has already normalised. |
| PR 3b before PR 4 | Both edit `NEWS.md` and `R/core-constructors.R` — PR 3b the code, PR 4 the roxygen. |
| PR 3a before PR 5 and PR 6 | Both call the strip helpers PR 3a adds to `R/utils.R`. PR 6's survey-object mode is fixed by PR 3a's setter, so M-1 in that mode cannot pass earlier. |
| PR 4 before PR 5 | PR 5's `@return` boundary note on `as_svydesign()` and `as_tbl_svy()` names `survey_data(x, haven_class = TRUE)`, which PR 4 creates. |
| PR 4 before PR 7 | Both edit `plans/error-messages.md`. |
| PR 3a before PR 7 | Both edit `tests/testthat/test-labelled-analysis.R`; PR 7 adds row G-7 to the file PR 3a creates. |
| Everything before PR 8 | PR 8 carries the whole-feature gates — the coverage floor, `R CMD check --as-cran`, `pkgdown`, the `NEWS.md` five-entry count, the `DESCRIPTION` and `NAMESPACE` diff, and the `plans/error-messages.md` row count. None can be verified until every other PR has landed. |

### Files touched by more than one PR

These are the reason the chain is mostly linear. No two PRs in the list below
may run at the same time.

| File | PRs, in order |
|---|---|
| `R/utils.R` | PR 3a → PR 4 |
| `R/core-constructors.R` | PR 3b (code) → PR 4 (roxygen only) |
| `NEWS.md` | PR 3a → PR 3b → PR 4 → PR 7 → PR 8 (headings and order only) |
| `plans/error-messages.md` | PR 4 → PR 7 |
| `tests/testthat/test-utils.R` | PR 3a → PR 4 |
| `tests/testthat/test-methods-print.R` | PR 3a → PR 4 |
| `tests/testthat/_snaps/methods-print.md` | PR 3a → PR 4 |
| `tests/testthat/test-labelled-analysis.R` | PR 3a → PR 7 |

`NEWS.md` cannot sit in a single PR: `spec.md` §XI.15 names five entries and
each one becomes true in a different PR, so each PR carries its own, and PR 8
groups them. `plans/error-messages.md` is split for the same reason — PR 4
adds the flag class row, PR 7 corrects the three PC Condition rows, and PR 8
counts the net change.

---

## Write-surface coverage

Every file in `spec.md` §II is scheduled. Nothing is left over.

| `spec.md` §II write surface | PR |
|---|---|
| `R/utils.R` — two strip helpers | PR 3a |
| `R/utils.R` — `.restore_haven_class()`, `survey_data()` argument | PR 4 |
| `R/core-classes.R` — the `data` property setter (Part 2) | PR 3a |
| `R/core-constructors.R` — strip on entry to four constructors (Part 1) | PR 3b |
| `R/core-constructors.R` — `@return` contract text | PR 4 |
| `R/core-metadata.R` — `.validate_val_labels()` local strip | PR 6 |
| `R/methods-conversion.R` — strip, metadata capture, `@return` note | PR 5 |
| `R/analysis-corr-latent.R` — the `is.double` branch and its comments | PR 7 |
| `R/analysis-helpers.R` — `.haven_available()` and its call site | PR 2 |
| `R/analysis-corr.R` — `@param x` wording | PR 7 |
| `plans/error-messages.md` — PC-1, PC-2, PC-3 Condition text | PR 7 |
| `plans/error-messages.md` — the `haven_class` flag row (D6) | PR 4 |
| `NEWS.md` — stacked-class loss | PR 3a |
| `NEWS.md` — storage contract | PR 3b |
| `NEWS.md` — the `haven_class` argument | PR 4 |
| `NEWS.md` — polychoric acceptance; polyserial breaking change | PR 7 |
| `NEWS.md` — the five entries grouped and counted | PR 8 |
| `man/survey_data.Rd`, `man/as_survey*.Rd` (four) | PR 4 |
| `man/as_svydesign.Rd`, `man/as_tbl_svy.Rd` | PR 5 |
| `man/get_corr.Rd` | PR 7 |
| `DESCRIPTION`, `NAMESPACE` | none — unchanged, checked in every PR |

Test files are not in `spec.md` §II. They come from `test-spec.md` §4 and
follow the mapping in `.claude/rules/testing-surveycore.md` §File mapping.
Two new test files: `tests/testthat/test-labelled-analysis.R`, created by PR
3a, and `tests/testthat/test-labelled-storage.R`, created by PR 3b. A third,
`tests/testthat/test-labelled-fixtures.R`, is created by PR 1; it tests the
fixture builders in `tests/testthat/helper-test-data.R`, following the
existing precedent of `tests/testthat/test-invariants.R`, which tests
`test_invariants()` from the same helper file.

### Snapshot files and the PR that reviews each

Every PR that adds a dual-pattern row, a warning-plus-snapshot row or a
snapshot row owns the matching `_snaps/*.md` file, and carries a task to read
it in `testthat::snapshot_review()`. Blind `snapshot_accept()` is forbidden
by `.claude/rules/testing-standards.md`.

| PR | Test file it writes | Snapshot file | Rows |
|---|---|---|---|
| PR 1 | `test-labelled-fixtures.R` | none needed | F-1 to F-6 carry no error or snapshot row |
| PR 2 | `test-analysis-helpers.R` | none needed | H-1 to H-3 carry no error or snapshot row |
| PR 3a | `test-s7-classes.R` | none needed | S-35 to S-37 take `class=` only, no snapshot (`test-spec.md` §4.3) |
| PR 3a | `test-utils.R` | none needed | D-1 to D-6 assert stored state, not errors |
| PR 3a | `test-methods-print.R` | `_snaps/methods-print.md` — modified | T-1, T-3 |
| PR 3a | `test-labelled-analysis.R` | none needed | A and G rows assert success |
| PR 3b | `test-labelled-storage.R` | `_snaps/labelled-storage.md` — created | S-21, S-22, S-23, S-23a, S-23f, S-23g, S-30, S-34 — eight dual-pattern rows |
| PR 4 | `test-utils.R` | `_snaps/utils.md` — modified | D-22, D-23 |
| PR 4 | `test-methods-print.R` | `_snaps/methods-print.md` — modified | T-2 |
| PR 5 | `test-conversion.R` | none needed | C-0 to C-9 carry no error or snapshot row |
| PR 6 | `test-metadata-system.R` | `_snaps/metadata-system.md` — modified | M-2 warning snapshot |
| PR 7 | `test-analysis-corr-latent.R` | `_snaps/analysis-corr-latent.md` | P and Y dual-pattern rows, E-1 |
| PR 7 | `test-labelled-analysis.R` | none needed | G-7 asserts success |
| PR 8 | none | none needed | adds no test row |

---

## Quality-gate assignment

All 18 gates from `spec.md` §XI are assigned, each to one row, each to a PR
that can make it true.

| Gate | Where it is made true and verified |
|---|---|
| 1 — `document()` clean, `man/` in sync | PR 4, PR 5, PR 7 (the three PRs with roxygen changes); the whole-feature sync is verified in PR 8 |
| 2 — `devtools::test()` 0 failures | every PR; the whole-suite run is verified in PR 8 |
| 3 — `run_examples()` clean | PR 4; re-run in PR 8 |
| 4 — `R CMD check --as-cran` | PR 8 (each PR also runs `devtools::check()` before it opens) |
| 5 — `pkgdown::build_site()` | PR 8 |
| 6 — `covr` at or above 96.09%, floor 95%, with `NOT_CRAN=true` | PR 8 |
| 7 — `air format --check .` no **attributable** diff | every PR; verified in PR 8. Package-wide: 35 files flagged, 0 attributable, and the no-diff form has never held |
| 8 — no `@data` column inherits `haven_labelled`, four classes plus bare assignment | **PR 3a** — the setter is what makes it true. Rows S-24 to S-26 and D-1 to D-4 |
| 9 — a design constructs and estimates from a labelled weight column and a labelled FPC column | **PR 3b** — the four constructor-entry calls are what make it true. Rows S-14, S-15, S-23b, S-23c |
| 10 — `@metadata@value_labels` populated on every route, `from_svydesign()` included | PR 5 |
| 11 — `haven_class = TRUE` returns the exact import class chain, with `haven` absent | PR 4 |
| 12 — polychoric raises on `Inf` and `-Inf` | PR 7 |
| 13 — PC-1, PC-2, PC-3 Condition text correct; exactly one row added, none removed | PR 7 writes the Condition text; PR 8 confirms the whole-feature net +1 row with `git diff cf6f153 -- plans/error-messages.md` |
| 14 — no comment in `R/analysis-corr-latent.R` contradicts its code | PR 7 |
| 15 — `NEWS.md` carries the five entries | written by PR 3a (1), PR 3b (1), PR 4 (1), PR 7 (2); grouped and counted in PR 8 |
| 16 — `DESCRIPTION` and `NAMESPACE` unchanged | checked in every PR; the whole-feature `git diff` is run in PR 8 |
| **17 — the §III.6 timing ratio** | **Recorded, not pass-or-fail. PR 3a's `implementation.md`**, because PR 3a adds the setter that costs the time. Report and stop if the ratio exceeds about 1.05. |
| **18 — the S7 version the setter behaviour was confirmed against** | **Recorded, not pass-or-fail. PR 3a's `implementation.md`**, beside the demonstration that the inherited setter fires for `survey_twophase`. |

---

## Breaking changes and their `NEWS.md` entries

Two user-visible behaviour changes. Each ships with its entry in the same PR
that makes it true. PR 8 puts both under one `## Breaking changes` heading.

| Change | Source | PR | `NEWS.md` heading |
|---|---|---|---|
| A caller's own class stacked above `haven_labelled` is lost, because the whole class vector goes | `spec.md` §III.3a | PR 3a | `## Breaking changes` |
| A polyserial pair of a whole-valued small double and an ordinal column now raises `surveycore_error_polyserial_requires_mixed_types` where it previously returned a number | `spec.md` §VI.6, row 3 | PR 7 | `## Breaking changes`, naming the affected pair shape |

The three remaining entries required by gate 15 are not breaking: the storage
contract change (PR 3b), the new `haven_class` argument (PR 4), and the
polychoric acceptance of whole-valued doubles (PR 7).

---

## Standing rules for every PR

From `.claude/rules/`. Repeated here so no PR has to look them up.

- Branch from `develop`; merge back to `develop` with a squash commit in
  Conventional Commits form.
- The edit-run loop is
  `NOT_CRAN=false Rscript -e "testthat::test_local()"`.
  `devtools::test()` cannot reach that speed, because it forces
  `NOT_CRAN=true`.
- The full run before any push is `Rscript -e "devtools::test()"`.
- Measure coverage with `NOT_CRAN=true`, or eleven files skip and the figure
  reads about 93.7% instead of 96.09%.
- Run `devtools::document()` before committing any file that changes roxygen
  content; commit `man/` and `NAMESPACE` in sync.
- Run `devtools::check()` before opening the PR.
- Run `air::format_package()` before opening the PR; keep any
  reformat-only commit separate from the functional change.
- `haven` stays in `Suggests`. Read label attributes with base R
  (`attr(col, "label", exact = TRUE)`, `attr(col, "labels", exact = TRUE)`)
  and write the class back with base R. Never call `haven::var_label()`,
  `haven::labelled()` or `haven::labelled_spss()` in `R/`.
- `test_invariants(design)` runs once per constructor per test FILE, in the
  first block in that file that builds with it.
- Every `cli_abort()` and `cli_warn()` carries a `class=`, and the class
  exists in `plans/error-messages.md`.
- Every snapshot a PR writes is read in `testthat::snapshot_review()` before
  the PR opens. Never `snapshot_accept()` blind.
- Record the red run in the PR's `implementation.md`: the failure count and
  every failing row identifier, per `test-spec.md` §4.11a. The red run
  happens on the pre-change tree at the start of the PR, which is what §4.11a
  asks for; no scratch worktree is needed as long as the record is written
  before the source edits land.
