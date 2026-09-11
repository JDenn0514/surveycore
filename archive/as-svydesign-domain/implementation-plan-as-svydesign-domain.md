# Implementation plan — as-svydesign-domain

**Status**: DRAFT
**Target version**: 1.1.0.9000
**PR range**: PR 1–5

`spec.md` line 5 says `PR range: PR 1`. That line predates the budget count and
is wrong. `test-spec.md` holds 43 rows, the bound is 12 rows per PR, so the map
needs at least four PRs. This plan uses five, because the documentation rewrite
has to land last and its criteria do not fit beside a route's criteria.

## How the work splits

The whole change is one internal helper, `.restrict_to_domain(converted)`, and
three call sites in `R/methods-conversion.R`. The split runs by route and by
concern, not by file.

| PR | Concern | Production content |
|---|---|---|
| 1 | The helper, the Taylor route, and the non-probability shape that names no replicate weights — both reach the same call site | The helper in full, plus one call site in `.as_svydesign_taylor()` |
| 2 | The marker column's edge cases and the wrapper | None. Tests only |
| 3 | The replicate route, the non-probability shape that names replicate weights, and the remaining rows of the shape PR 1 first reached | One call site in `.as_svydesign_replicate()` |
| 4 | The two-phase route | The helper's two-phase frame branch, plus one call site in `.as_svydesign_twophase()` |
| 5 | Documentation and the changelog | Roxygen only |

The five PRs run **sequentially**, one at a time, through pipeline-ship. They
share `R/methods-conversion.R` and `tests/testthat/test-conversion.R`, and that
is expected. The schema's disjoint-write-surface rule governs PRs that run at
the same time, and none of these do. The order below is a hard order: each PR
opens only after the one before it merges to `develop`.

No later PR changes behaviour an earlier PR tested.

- PR 1 ships the complete row mask, including `as.logical()` and the `NA`
  resolution. `spec.md` §`.restrict_to_domain(converted)` → Errors makes
  "raises no condition" a term of the contract, and `as.logical()` is what
  makes that true, so the helper cannot ship without it. PR 2 therefore adds
  no production code; it pins marker-column behaviour PR 1 already delivers.
- PR 4 adds the two-phase frame branch inside the helper. A logical marker on
  a Taylor object reaches the same expression before and after, so PR 1's rows
  keep passing.
- PR 5 edits roxygen only. It changes no behaviour any earlier PR tested.

## Standing constraints (every PR)

- Write surface is closed. Only these four files change across the whole arc:
  `R/methods-conversion.R`, `tests/testthat/test-conversion.R`,
  `man/as_svydesign.Rd`, `changelog/fix-as-svydesign-domain.md`. No PR touches
  a file outside its own listed surface.
- `NEWS.md` does not change. `/merge-main` drafts the release section from
  `changelog/`.
- `plans/error-messages.md` stays byte-identical to its state on `develop`.
  The arc adds no error class and no warning class.
- `NAMESPACE` does not change. The helper is internal and `.`-prefixed.
- Every branch cuts from `develop` and merges back to `develop`.
- Run the full suite before any push: `Rscript -e "devtools::test()"`.
- Measure coverage with `NOT_CRAN=true`, per
  `.claude/rules/testing-surveycore.md`.
- **Row headroom is thin on PR 2.** The bound is 12 rows and PR 2 holds 11. A
  row folded into an existing criterion during ship — a tester-found edge case,
  say — puts that PR over budget. Defer such a row to a follow-up issue rather
  than absorbing it.

## Profile gates (every PR)

Every PR in this plan carries all seven gates. For PR 1 to PR 4 the last
acceptance criterion is this list. PR 5 is the exception: its last criterion is
the structural gate instead, and its criteria 3, 6 and 7 name four of the seven
gates individually. The other three — `devtools::test()`, the coverage floor
and the CRAN cookbook scan — reach PR 5 through this section, which binds every
PR.

- [ ] devtools::document() clean
- [ ] devtools::test() all pass
- [ ] devtools::run_examples() all pass
- [ ] R CMD check --as-cran (0 err, 0 warn, notes reviewed)
- [ ] pkgdown::build_site() clean
- [ ] covr::package_coverage() ≥ 95% (target 98%)
- [ ] CRAN cookbook scan clean (see r-package-profile.md)

---

## PR map

- [x] **PR 1: `fix/as-svydesign-domain-taylor`** — the restriction helper, and
  the Taylor route restricted to the active domain.

  **This PR changes two routes, not one.** `as_svydesign()` dispatches a
  `survey_nonprob` design that names no replicate weights into
  `.as_svydesign_taylor()` (`R/methods-conversion.R:169`, and `spec.md`
  §Route matrix row 5). That is the function this PR edits, so merging it
  changes what both shapes return. Row A-4 therefore sits in this PR rather
  than in PR 3: the PR tests every route whose behaviour it changes. The
  stricter warning row G-2 stays in PR 3 with the rest of that shape's rows.

  - **Budget** — 11 test-spec rows | 8 criteria
    - Rows: §A A-1, A-4, A-5, A-6 | §C C-1 | §D D-1, D-8 | §F F-1, F-2, F-3 |
      §G G-1a
  - **Tasks**
    1. Cut `fix/as-svydesign-domain-taylor` from `develop`.
    2. Write a failing test for row A-1: a Taylor design from the file's
       existing fixture, a domain marked by hand under `SURVEYCORE_DOMAIN_COL`,
       and `survey::svymean()` on the converted object against `get_means()` on
       the filtered design. Confirm it fails on the current behaviour.
    3. Implement `.restrict_to_domain(converted)` in `R/methods-conversion.R`,
       under the existing `# ── Internal helpers ──` heading at line 12. One
       argument. The helper reads the marker column off `converted$variables`,
       returns `converted` unchanged when the column is absent, and otherwise
       indexes with `[`. The two-phase frame branch is PR 4's task.
    4. Implement the row mask inside the helper: coerce with `as.logical()`
       first, then mask with `r & !is.na(r)`, per `decisions.md` D9.
    5. Call the helper once in `.as_svydesign_taylor()`, on the object the
       route has just built, immediately before returning it. The input design
       `x` is not touched.
    6. Verify A-1 passes.
    7. Write failing tests for rows A-5 and A-6: the same comparison with a
       marker produced by `surveytidy::filter()`, and the same comparison on a
       Taylor design built on `nhanes_2017`. Each block carries its own
       `skip_if_not_installed()`. Verify both pass with no further code change.
    8. Write a test for row A-4: a filtered non-probability design that names
       no replicate weights, which reaches the call site this PR just added.
       The block captures the pre-existing
       `surveycore_warning_nonprob_srs_conversion` with
       `expect_warning(sv <- ..., class = ...)` and reads the result off the
       return value. Add the two marker assertions from test-spec §A. Verify
       it passes with no further code change.
    9. Write tests for rows C-1 and D-1: an unfiltered Taylor design converts
       exactly as it does today, and an all-`TRUE` marker converts to the same
       row count. Verify.
    10. Write a test for row D-8: the input design's row count and marker
        column are identical before and after the call, and a second call
        returns the same row count. Verify.
    11. Write tests for rows F-1, F-2 and F-3: the round trip's `@variables`
        values, the unfiltered round-trip baseline, and the stored call. These
        are the guard on the choice of `[` over `subset()`. Verify.
    12. Write a test for row G-1a: `expect_no_condition()` on a filtered Taylor
        conversion. Verify.
    13. Run `devtools::document()`, then the full suite, then
        `devtools::check()`. Open the PR against `develop`.
  - **Acceptance criteria**
    1. On a filtered Taylor design, `survey::svymean()` on the converted object
       agrees with `get_means()` on the filtered design to point 1e-10 and
       SE 1e-8, on the file's fixture (A-1), on a marker produced by
       `surveytidy::filter()` (A-5), and on `nhanes_2017` (A-6). The same
       agreement holds on a filtered non-probability design that names no
       replicate weights — the second shape this call site serves — with
       `surveycore_warning_nonprob_srs_conversion` captured off the call and
       the result read from the return value (A-4).
    2. An unfiltered Taylor design converts to one row per design row, and the
       marker constant is not a name of the converted object's variables (C-1).
    3. An all-`TRUE` marker converts to one row per design row, and the
       estimate matches `get_means()` at the same tolerances (D-1).
    4. The input design's row count and marker column are identical before and
       after the call, and a second call returns the same row count (D-8).
    5. The round trip on a filtered Taylor design gives `@variables` values for
       `ids`, `strata` and `weights` identical to the round trip on the same
       design unfiltered (F-1), and the unfiltered round trip names all three
       (F-3).
    6. The converted object's stored call deparses identically for the filtered
       and the unfiltered design (F-2).
    7. `as_svydesign()` on a filtered Taylor design raises no condition (G-1a).
    8. All seven profile gates pass.
  - **Files touched** — `R/methods-conversion.R`,
    `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended. The same call on the same input now returns
    a different object and a different point estimate, which is a contract
    change and a numerical change.

- [x] **PR 2: `test/as-svydesign-domain-edge-cases`** — pin the marker column's
  edge cases, the wrapper, and the rest of the round trip.

  - **Budget** — 11 test-spec rows | 8 criteria
    - Rows: §D D-2a, D-3, D-4, D-5a, D-6, D-6a, D-6b, D-6c | §E E-1 |
      §F F-4, F-5
  - **Branch prefix note.** This PR adds tests only, so
    `.claude/rules/github-strategy.md` gives it the `test/` prefix rather than
    `fix/`. Every other PR in this map uses the prefix that rule assigns as
    well.
  - **Tasks**
    1. Cut `test/as-svydesign-domain-edge-cases` from `develop`, after PR 1
       merges.
    2. Write tests for rows D-2a and D-5a: an all-`FALSE` marker and an
       all-`NA` marker on the Taylor route each give a zero-row object and a
       silent conversion, and `survey::svymean()` on the result answers 0 with
       a standard error of 0. Verify.
    3. Write a test for row D-3: a marker with exactly one `TRUE` gives one
       row, and the conversion raises nothing. Verify.
    4. Write a test for row D-4: a logical marker holding `NA` in some rows
       gives one row per `TRUE`, compared with `expect_identical()` against the
       count of `TRUE` values. Verify.
    5. Write tests for rows D-6, D-6a, D-6b and D-6c, each building its marker
       column inline: integer `0`/`1`, character `"TRUE"`/`"FALSE"`, a factor
       with levels `FALSE` and `TRUE`, and a factor with unrelated levels. Each
       asserts the row count and that the conversion raises no condition. D-6b
       also asserts every probability in the converted object is finite.
       Verify. If any row fails, report it as a finding and do not relax it.
    6. Write a test for row E-1: `as_tbl_svy()` on a filtered Taylor design
       returns a `tbl_svy` whose variables carry one row per marked row.
       Verify.
    7. Write tests for rows F-4 and F-5: the round trip's point estimate,
       standard error and both confidence bounds, and the rebuilt design's
       all-`TRUE` marker column plus its `Domain: n of n rows` print line.
       Verify.
    8. Run the full suite and `devtools::check()`. Open the PR against
       `develop`.
  - **Acceptance criteria**
    1. An empty domain on the Taylor route gives a zero-row object and a silent
       conversion, and `survey::svymean()` then answers 0 with a standard error
       of 0. The all-`NA` marker gives the same (D-2a, D-5a).
    2. A single-`TRUE` marker gives one row and a silent conversion (D-3).
    3. A logical marker holding `NA` gives a row count identical to the count
       of `TRUE` values (D-4).
    4. An integer marker and a character marker each select the same rows a
       logical marker selects, and neither raises a condition (D-6, D-6a).
    5. A `FALSE`/`TRUE` factor marker selects one row per `TRUE` value, raises
       no condition, and every probability in the converted object is finite. A
       factor with unrelated levels gives zero rows and raises no condition
       (D-6b, D-6c).
    6. `as_tbl_svy()` on a filtered Taylor design returns a `tbl_svy` with the
       domain row count (E-1).
    7. The round trip on a filtered Taylor design agrees with the converted
       object on the point estimate at 1e-10, the standard error at 1e-8 and
       both confidence bounds at 1e-6 (F-4). The rebuilt design carries an
       all-`TRUE` marker column and prints `Domain: n of n rows` (F-5).
    8. All seven profile gates pass, and `git diff --stat` against `develop`
       shows no file outside `tests/` changed.
  - **Files touched** — `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended. The PR meets all four `optional` criteria
    on paper — no new export, no new error class, no contract change, one file
    — but its whole content is test content, so the tester stage is the PR. Do
    not drop it.

- [x] **PR 3: `fix/as-svydesign-domain-replicate-nonprob`** — the replicate
  route and both non-probability shapes restricted to the active domain.

  - **Budget** — 11 test-spec rows | 8 criteria
    - Rows: §A A-2, A-3 | §C C-2, C-4, C-5 | §D D-2b, D-2d | §E E-2 |
      §G G-1b, G-2, G-3
    - Row A-4 moved to PR 1, which ships the call site that shape reaches.
      PR 3 keeps the rest of that shape's rows.
    - Row G-3 is new. It closes the one gap the plan review raised: this PR
      adds the restriction to `.as_svydesign_replicate()`, the function that
      fires `surveycore_warning_replicate_fpc_dropped`, and no row put a
      filtered FPC-bearing design through it.
  - **Tasks**
    1. Cut `fix/as-svydesign-domain-replicate-nonprob` from `develop`, after
       PR 2 merges.
    2. Write a failing test for row A-2: a filtered BRR replicate design, and
       `survey::svymean()` on the converted object against `get_means()` on the
       filtered design. Confirm it fails.
    3. Call `.restrict_to_domain()` once in `.as_svydesign_replicate()`, on the
       object the route has just built, immediately before returning it. Add no
       branch on the weight shape and no second copy of the routing predicate;
       both non-probability shapes reach an existing call site through the
       dispatch already in `as_svydesign()`.
    4. Verify A-2 passes.
    5. Write a test for row A-3: the same comparison on a filtered
       non-probability design that names replicate weights, which reaches this
       PR's call site. Rows A-2 and A-3 each add the two marker assertions
       from test-spec §A. Verify.
    6. Write tests for rows C-2, C-4 and C-5: three unfiltered shapes convert
       exactly as they do today, and each tolerates only the condition its
       shape already raises. Verify.
    7. Write tests for rows D-2b and D-2d: an all-`FALSE` marker on the
       replicate route gives zero rows and a silent conversion, and
       `survey::svymean()` then errors with `All replicates contained NAs`,
       asserted by message and with no `class =` and no snapshot. Both
       non-probability shapes give zero rows and raise nothing beyond the SRS
       warning. Verify.
    8. Write a test for row E-2: `as_tbl_svy()` on a filtered non-probability
       design that names no replicate weights returns a `tbl_svy` with the
       domain row count, and the block captures the SRS warning. Add no second
       snapshot of that message. Verify.
    9. Write tests for rows G-1b and G-2. Verify.
    10. Write a test for row G-3: a filtered replicate design that carries an
        FPC column raises `surveycore_warning_replicate_fpc_dropped` exactly
        once and nothing else. Capture with
        `expect_warning(sv <- ..., class = ...)` and read the result off the
        return value. Add no snapshot. Verify.
    11. Run the full suite and `devtools::check()`. Open the PR against
        `develop`.
  - **Acceptance criteria**
    1. **The parity claim.** On a filtered replicate design and on a filtered
       non-probability design that names replicate weights,
       `survey::svymean()` on the converted object agrees with `get_means()`
       on the filtered design to point 1e-10 and SE 1e-8 (A-2, A-3).
    2. **The marker claim, which is a separate assertion on the same two
       rows.** test-spec §A gives A-2 and A-3 two marker assertions beyond the
       parity comparison: the marker column is a name of the converted
       object's variables, and every value in it is `TRUE` (A-2, A-3).
    3. Three unfiltered shapes — replicate carrying no FPC, non-probability
       with replicate weights, non-probability without — each convert to one
       row per design row, carry no marker column, and raise no condition
       beyond the one that shape already raises (C-2, C-4, C-5).
    4. An empty domain on the replicate route gives zero rows and a silent
       conversion, and `survey::svymean()` then errors with `All replicates
       contained NAs`. Both non-probability shapes give zero rows and raise
       nothing beyond the SRS warning (D-2b, D-2d).
    5. `as_tbl_svy()` on a filtered non-probability design that names no
       replicate weights returns a `tbl_svy` with the domain row count, and the
       existing snapshot file gains no entry (E-2).
    6. A filtered replicate design and a filtered non-probability design that
       names replicate weights each raise no condition (G-1b). The shape naming
       no replicate weights raises `surveycore_warning_nonprob_srs_conversion`
       exactly once and nothing else (G-2).
    7. A filtered replicate design that carries an FPC column raises
       `surveycore_warning_replicate_fpc_dropped` exactly once and no other
       condition, and `tests/testthat/_snaps/` gains no entry (G-3).
    8. All seven profile gates pass.
  - **Files touched** — `R/methods-conversion.R`,
    `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended. Two more routes change what the converted
    object estimates over.

- [x] **PR 4: `fix/as-svydesign-domain-twophase`** — the two-phase route, which
  applies the domain by zero-weighting and removes no row.

  - **Budget** — 10 test-spec rows | 8 criteria
    - Rows: §B B-1, B-2, B-3, B-4 | §C C-3 | §D D-2c, D-5b, D-7 | §F F-6 |
      §G G-1c
  - **Tasks**
    1. Cut `fix/as-svydesign-domain-twophase` from `develop`, after PR 3
       merges.
    2. Write a failing test for row B-1: a two-phase design that names a
       phase-2 cluster identifier, built with `make_survey_data()`, with a
       marker set by hand. Compare `survey::svymean()` on the converted object
       of the filtered design against `survey::svymean()` on the converted
       object of the same unfiltered design, indexed by hand from its own
       phase-1 sample variables with `NA` read as `FALSE`. Confirm it fails.
    3. Add the single new `test_invariants()` call for `as_survey_twophase()`
       in the B-1 block, per test-spec §Invariants. Add none for the other
       three constructors and none in B-2, B-3 or B-4.
    4. Add the two-phase frame branch inside `.restrict_to_domain()`: for a
       two-phase object the marker frame is `converted$phase1$sample$variables`,
       and for every other class it stays `converted$variables`. The helper
       keeps one argument. No call site gains a frame argument and no call site
       gains a copy of the branch.
    5. Call the helper once in `.as_svydesign_twophase()`, on the object the
       route has just built, immediately before returning it.
    6. Verify B-1 passes. Keep the existing `suppressWarnings()` treatment the
       file's other two-phase blocks use, and do not use
       `expect_no_condition()` anywhere on this route.
    7. Write tests for rows B-2, B-3 and B-4. B-3 asserts the count of finite
       probabilities against the count of marked phase-2 rows and asserts no
       row count. B-4 uses the file's own two-phase builder, which names no
       phase-2 cluster identifier; if it fails, report the failure and do not
       change the fixture. Verify.
    8. Write a test for row C-3: an unfiltered two-phase design converts as it
       does today and carries no marker column. Verify.
    9. Write tests for rows D-2c and D-5b: an all-`FALSE` marker and an all-`NA`
       marker each leave the row count unchanged, leave no finite probability,
       and raise no surveycore condition. Assert the estimate with
       `expect_true(is.nan(...))`. Verify.
    10. Write tests for rows D-7 and F-6: the marker column survives into the
        converted object on the Taylor route with every value `TRUE` and into
        the two-phase phase-1 sample variables with its mixed values, and the
        two-phase round trip rebuilds the full phase-1 frame with the marker
        intact. Verify.
    11. Write a test for row G-1c: capture every condition the call signals,
        and assert that no element of any condition's class vector matches
        `^surveycore_`. Verify.
    12. Run the full suite and `devtools::check()`. Open the PR against
        `develop`.
  - **Acceptance criteria**
    1. On a filtered two-phase design that names a phase-2 cluster identifier,
       `survey::svymean()` on the converted object equals the same call on the
       hand-restricted converted object of the unfiltered design, to point
       1e-10 and SE 1e-8 (B-1).
    2. On the same design unfiltered, both hand computations reproduce their
       two estimators to 1e-10 and the two answers differ, so the row fails if
       the pre-existing gap moves (B-2).
    3. The count of finite probabilities in the converted object equals the
       count of marked phase-2 rows, asserted with `expect_identical()` and
       with no row-count assertion (B-3). The file's own two-phase builder,
       which names no phase-2 cluster identifier, converts and raises no error
       (B-4).
    4. An unfiltered two-phase design converts to one row per design row,
       carries no marker column, and raises only the untyped condition from
       `survey` that it raises today (C-3).
    5. An all-`FALSE` marker and an all-`NA` marker each leave the row count
       unchanged, leave no finite probability, raise no surveycore condition,
       and give a `NaN` estimate (D-2c, D-5b).
    6. The marker column is a name of the converted object's data on the Taylor
       route with every value `TRUE`, and a name of the two-phase phase-1
       sample variables with its values unchanged (D-7). The two-phase round
       trip rebuilds the full phase-1 row count and the mixed marker, both
       asserted with `expect_identical()` (F-6).
    7. No condition whose class matches `^surveycore_` fires on a filtered
       two-phase conversion (G-1c). And, separately,
       `tests/testthat/test-conversion.R` gains exactly one
       `test_invariants()` call, for `as_survey_twophase()`, in the B-1 block:
       the file's count of `test_invariants(` rises by one. That second half
       comes from test-spec §Invariants, not from a lettered row, so it does
       not count against the 43-row ledger.
    8. All seven profile gates pass.
  - **Files touched** — `R/methods-conversion.R`,
    `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended. The third route changes what the converted
    object estimates over, and its mechanism differs from the other four.

- [x] **PR 5: `docs/as-svydesign-domain`** — rewrite the roxygen section that
  documents the old behaviour as intended, and add the changelog entry.

  - **Budget** — 0 test-spec rows | 8 criteria
    - Rows: none. `test-spec.md` holds no row for this PR, and that is not a
      gap. The PR changes roxygen and adds a changelog file. The suite reaches
      that surface through `devtools::document()`,
      `devtools::run_examples()` and `R CMD check`, which criteria 3, 6 and 7
      below assert. The PR adds no test block and edits none.
  - **Tasks**
    1. Cut `docs/as-svydesign-domain` from `develop`, after PR 4 merges.
    2. Rewrite the `@section A filtered design's domain:` block at
       `R/methods-conversion.R:88-100`. State the nine items of
       `spec.md` §Documentation contract → The `@section` block, in that order.
       Name no internal helper and show no `@` property access.
    3. Add the one sentence to `@return` at `R/methods-conversion.R:43-50`: a
       filtered input returns an object restricted to the active domain, and
       the sentence points at the `A filtered design's domain` section.
    4. Change nothing else in the roxygen. `as_tbl_svy()`'s own block stays
       untouched, so item 9 lives inside `as_svydesign()`'s section and names
       `as_tbl_svy()` from there.
    5. Run `devtools::document()` to regenerate `man/as_svydesign.Rd`. Never
       hand-edit that file.
    6. Write `changelog/fix-as-svydesign-domain.md` in the flat format the
       directory uses. Lead with the change to what the function returns: a
       filtered design now converts to the domain and not to the full sample.
    7. Count the helper's definition, its argument and its call sites in
       `R/methods-conversion.R` with `grep`, and confirm the mask expression,
       the column-presence check and the frame-selection branch each appear
       once. This reads the arc's final state; report a second copy as a
       finding rather than deleting it here.
    8. Run `devtools::run_examples()`, the full suite, `devtools::check()` and
       `pkgdown::build_site()`. Open the PR against `develop`.
  - **Acceptance criteria**
    1. `man/as_svydesign.Rd` states the nine items of `spec.md` §Documentation
       contract, in order, and neither `R/methods-conversion.R` nor
       `man/as_svydesign.Rd` still tells the caller to subset the returned
       object by hand or says the converted object answers for every row.
    2. `man/as_svydesign.Rd`'s value section carries the new sentence about a
       filtered input, and it names the `A filtered design's domain` section.
    3. A second `devtools::document()` run leaves the working tree clean, and
       `git status` shows no `man/*.Rd` file changed other than
       `as_svydesign.Rd`.
    4. `changelog/fix-as-svydesign-domain.md` exists, matches the format of the
       entries already in `changelog/`, and its first line names the change to
       what `as_svydesign()` returns.
    5. `NEWS.md`, `NAMESPACE` and `plans/error-messages.md` are byte-identical
       to their state on `develop`, checked with `git diff`.
    6. `devtools::run_examples()` passes and `pkgdown::build_site()` builds the
       `as_svydesign` reference page with no error.
    7. `R CMD check --as-cran` gives 0 errors, 0 warnings and the pre-approved
       notes only.
    8. **The structural gate, read on the final state of the file.**
       `R/methods-conversion.R` holds exactly one definition of
       `.restrict_to_domain`, that definition takes one argument, and exactly
       three call sites call it — one each in `.as_svydesign_taylor()`,
       `.as_svydesign_replicate()` and `.as_svydesign_twophase()`. The mask
       expression, the column-presence check and the frame-selection branch
       each appear once in the file, inside the helper. No call site passes a
       frame. Counted with `grep`. This is `spec.md` §Quality gates' structural
       bullet, and PR 5 is the first point at which the final state exists.
       `git diff --stat` against `develop` also shows no change under `tests/`.
  - **Files touched** — `R/methods-conversion.R` (roxygen only),
    `man/as_svydesign.Rd`, `changelog/fix-as-svydesign-domain.md`
  - **Pipeline tier**: optional. The PR adds no exported function, adds no
    error class, changes no contract — it describes behaviour PRs 1 to 4
    already shipped — and touches three files.

---

## Quality gates, mapped to the PRs that satisfy them

Each row is a gate from `spec.md` §Quality gates.

| Gate | Satisfied by |
|---|---|
| One row per marked row on Taylor, replicate and both non-probability shapes; finite-probability count equals the marked count on two-phase | PR 1 (A-1, A-4, D-1), PR 3 (A-2, A-3), PR 4 (B-3) |
| `survey::svymean()` on a converted filtered design answers the domain estimate, on all five shapes | PR 1 (A-1, A-4, A-5, A-6), PR 3 (A-2, A-3), PR 4 (B-1) |
| An unfiltered design converts exactly as it does today | PR 1 (C-1), PR 3 (C-2, C-4, C-5), PR 4 (C-3) |
| The stored call is the same expression before and after the restriction | PR 1 (F-2) |
| The round trip on a filtered Taylor design names `ids`, `strata` and `weights` | PR 1 (F-1, F-3) |
| The restriction raises no condition the unfiltered design does not raise; on two-phase, no surveycore condition | PR 1 (G-1a), PR 3 (G-1b, G-2, G-3), PR 4 (G-1c) |
| The marker column stays in the converted object's data on every route | PR 1 (A-4), PR 3 (A-2, A-3), PR 4 (D-7) |
| The marker column's type does not change the outcome | PR 2 (D-6, D-6a, D-6b, D-6c) |
| The input design is unchanged by the call | PR 1 (D-8) |
| One helper, one argument, three call sites, no duplicated mask or branch | Built by PR 1 (helper, call site 1), PR 3 (call site 2), PR 4 (frame branch, call site 3). **Asserted** by PR 5, criterion 8, which counts the final state |
| `plans/error-messages.md` byte-identical to `develop` | Every PR; asserted explicitly in PR 5, criterion 5 |
| `devtools::document()`, `devtools::check()` and the coverage floor hold | Every PR, through the profile gates |

## Row ledger

All 43 rows of `test-spec.md`, each claimed once.

| Section | Row | PR |
|---|---|---|
| A | A-1 | 1 |
| A | A-2 | 3 |
| A | A-3 | 3 |
| A | A-4 | 1 |
| A | A-5 | 1 |
| A | A-6 | 1 |
| B | B-1 | 4 |
| B | B-2 | 4 |
| B | B-3 | 4 |
| B | B-4 | 4 |
| C | C-1 | 1 |
| C | C-2 | 3 |
| C | C-3 | 4 |
| C | C-4 | 3 |
| C | C-5 | 3 |
| D | D-1 | 1 |
| D | D-2a | 2 |
| D | D-2b | 3 |
| D | D-2c | 4 |
| D | D-2d | 3 |
| D | D-3 | 2 |
| D | D-4 | 2 |
| D | D-5a | 2 |
| D | D-5b | 4 |
| D | D-6 | 2 |
| D | D-6a | 2 |
| D | D-6b | 2 |
| D | D-6c | 2 |
| D | D-7 | 4 |
| D | D-8 | 1 |
| E | E-1 | 2 |
| E | E-2 | 3 |
| F | F-1 | 1 |
| F | F-2 | 1 |
| F | F-3 | 1 |
| F | F-4 | 2 |
| F | F-5 | 2 |
| F | F-6 | 4 |
| G | G-1a | 1 |
| G | G-1b | 3 |
| G | G-1c | 4 |
| G | G-2 | 3 |
| G | G-3 | 3 |

Totals: PR 1 holds 11 rows, PR 2 holds 11, PR 3 holds 11, PR 4 holds 10, PR 5
holds 0. The sum is 43, which is the row count of `test-spec.md`. No row is
unclaimed and no row is claimed twice.
