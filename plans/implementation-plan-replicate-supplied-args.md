# Implementation plan — replicate-supplied-args

**Status**: PLAN_READY (plan review PASS at pass 3; see `plan-review.md`)
**Date**: 2026-10-07
**Revision**: 3 (plan review pass 1 and pass 2 findings applied; see
`decisions.md` §Plan review pass 1 and §Plan review pass 2)
**Issues**: #255, and the JKn half of #244
**Input state**: SPEC_READY (spec revision 2, test-spec revision 2, HOLD-1 and
D-g settled in `decisions.md`)
**PR count**: 6
**Test-spec rows**: 59, each given to exactly one PR (§Row assignment)

## HOLDs

None open on the plan. Planning choices are recorded under §Planning notes.
Plan review finding L4-6, a requested spec count change, was not applied and
is with the coordinator; `decisions.md` §Plan review pass 1 gives the reason.
No part of this plan depends on it.

## How to read this plan

- The builder reads `spec.md` and this plan. The builder never reads
  `test-spec.md`. So every task below writes out the fixture, the value, the
  list and the count it needs. A task never says "see row n" as its only
  source.
- The row ids (5.1, 6.4, T7 and so on) in the **Budget** and **Acceptance
  criteria** lines are for the tester and the reviewer. Do not put a row id
  in a `test_that()` title.
- All R code in tests follows `.claude/rules/code-style.md`.
- Every numeric `expect_equal()` carries an explicit `tolerance =`. None
  relies on the testthat default (about 1.49e-8). The values:
  - point estimate: `1e-10`;
  - standard error, variance, and every stored or `survey` scale: `1e-8`;
  - confidence bounds: `1e-6`;
  - a ratio of two standard errors: `1e-8`.
- Warnings are captured with `expect_warning(d <- ..., class = ...)`, and the
  result comes from that call's return value. No `withCallingHandlers()`, no
  `tryCatch()`, no `suppressWarnings()` round a surveycore call.
- `survey` conditions carry no class. Match them by message text with
  `fixed = TRUE`. "Exactly one `survey` warning" always means:
  `w <- testthat::capture_warnings(<call>)`, then `expect_length(w, 1L)`, then
  `expect_match(w, "<text>", fixed = TRUE)`.
- Every block that calls `survey` starts with
  `skip_if_not_installed("survey")` inside the block.
- No new block calls `test_invariants()`. Each of the three test files
  already calls it for `as_survey_replicate()` in an earlier block.
- No new block uses `testthat::expect_failure()`. Check every PR with
  `git diff origin/develop...HEAD -- tests | grep '^+[^+]' | grep -vE '^\+\s*#' | grep -cE 'suppressWarnings\(|expect_failure\('`.
  The count is 0. The check reads added code lines only (added comment
  lines are dropped before the count), so the existing
  `suppressWarnings(..., classes = "simpleWarning")` calls in
  `tests/testthat/test-conversion.R`, which muffle `survey`'s own warnings,
  do not count unless a PR rewrites their line.
- `survey::svrepdesign()` takes Fay's factor as `rho`. `fay.rho` is the
  argument of `survey::as.svrepdesign()`, which no new block calls. The
  existing Fay blocks in `tests/testthat/test-variance-replicate.R` and the
  export route in `R/methods-conversion.R` both pass `rho =`.

## Order and concurrency

```
PR 1 ── PR 2 ── PR 3 ── PR 4 ── PR 5 ── PR 6
```

The order is strictly linear. No two PRs run at the same time.

- PR 1 merges first. It carries the register rows in
  `plans/error-messages.md`, which must land no later than the first code
  change, and it adds the two predicates in `R/utils.R` that PR 3 and PR 4
  call. PR 1 and PR 2 have disjoint write surfaces, but PR 2 adds the RS-2
  call site, so its register row must already be on `develop`.
- PR 2 follows PR 1. Of the later rows, only PR 4's two refusal pins (JKn
  with `rscales = NULL` written out, and the one-row JKn frame) need the
  refusal in place. PR 3's JKn calls pass `rscales` and build either way. PR
  3 still follows PR 2, because the two share files.
- PR 3 follows PR 2 (shared `R/core-constructors.R`,
  `tests/testthat/test-constructors.R`, `tests/testthat/_snaps/constructors.md`).
- PR 4 follows PR 3. PR 4 adds the `rscales` half of the discard step that
  PR 3 starts.
- PR 5 follows PR 4. It needs PR 3's scale discard, and it shares
  `tests/testthat/test-conversion.R` with PR 4.
- PR 6 merges last. It documents what PRs 1 to 5 ship, and it writes the
  three `NEWS.md` entries.

Between PR 2 and PR 6, `?as_survey_replicate` still carries the sentence
"`rscales = NULL` leaves no jackknife factor in the variance at all", which
PR 2 makes false. PR 6 removes it. This is the same docs-last order the
as-svydesign-domain arc used.

Update each branch from `develop` before you open its PR. Branch protection
needs an up-to-date head branch.

## Shipping constraint — the run directory

Commit `fde518b` on `fix/replicate-supplied-args` force-added
`.surveycore-workspace/`. No PR diff into `develop` may contain a path under
`.surveycore-workspace/`. This bites PR 1 first, because PR 1 is the first
branch cut after that commit. Check it with
`git diff --name-only origin/develop...HEAD`. pipeline-ship reads and writes
the run directory, so this plan schedules no commit that deletes it.
pipeline-ship picks the mechanism that keeps it out of the diff.

The planning copies under `plans/` do ship, with PR 1:
`plans/spec-replicate-supplied-args.md`,
`plans/test-spec-replicate-supplied-args.md` and
`plans/decisions-replicate-supplied-args.md` (added in commit `3957966`), and
`plans/implementation-plan-replicate-supplied-args.md`.

## Standard gates (criterion G)

Every PR lists criterion **G**. It holds when all of these are true on the
PR's head commit:

1. `devtools::document()` leaves no diff in `man/` or `NAMESPACE`.
2. `devtools::test()`: 0 failures. The warning count is 256, the count of
   pre-existing AAPOR small-cell warnings on clean `develop`. The gate is "no
   new warning", not "0 warnings".
3. `devtools::run_examples()` runs clean.
4. `R CMD check --as-cran --no-manual`: read the `Status:` line. A run with
   no `Status:` line died and is not a pass (`run-gates.sh` reports such a
   run as PASS; do not trust that). 0 errors, 0 warnings. Notes: only
   `checking CRAN incoming feasibility` and the pre-existing `.git`
   hidden-file note. Any other note fails the gate.
5. `pkgdown::build_site()` builds with no errored page.
6. `covr::package_coverage()` with `NOT_CRAN=true` is 95% or more, and every
   line this PR adds to `as_survey_replicate()`, to the replicate route of
   `as_svydesign()` or to `R/utils.R` is reached. `covr` measures lines, so
   the check is line-based. Check the second part with
   `NOT_CRAN=true Rscript -e "cov <- covr::package_coverage(); z <- covr::zero_coverage(cov); print(z[z\$filename %in% c('R/core-constructors.R', 'R/methods-conversion.R', 'R/utils.R'), c('filename', 'line')])"`,
   then compare the listed lines with the lines this PR adds
   (`git diff -U0 origin/develop...HEAD -- R`). No added line is in the
   list.
7. `air format --check` passes on the `.R` files this PR changes. `air` is a
   command-line tool here, not an R package. Other files in the repository
   are not this PR's concern.
8. Snapshots change only through `testthat::snapshot_review()`, with each
   diff read. `git diff` over `tests/testthat/_snaps/` shows only the new
   entries this PR's tasks name. No existing entry changes.
9. `git diff --name-only origin/develop...HEAD` lists no path under
   `.surveycore-workspace/`. Every other path it lists is in this PR's
   **Files touched**, or sits under `plans/` or `changelog/`.
10. The `as_survey_nonprob()` function body in `R/core-constructors.R` is
    byte-identical to `develop`. Only roxygen lines above it may change, and
    only in PR 6.

## Fixtures

The builder builds these inline, in the test block that needs them. Do not
add parameters to `make_survey_data()`. Do not edit the existing helpers
`make_rep_type()` or `make_rep_fpc()` in `tests/testthat/test-conversion.R`.

| Id | Build | Replicate columns |
|---|---|---|
| F1 | `make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate", type = "jk1", seed = 15)`, then `repwt_cols <- grep("^repwt_", names(d), value = TRUE)` | `repwt_1` to `repwt_20`, so `R = 20` |
| F2 | `make_survey_data(n = 50L, n_psu = 10L, n_strata = 2L, design = "replicate", type = "brr", seed = 430L)`, then `repwt_cols` the same way | `repwt_1` to `repwt_5`, so `R = 5` |
| F3 | F1, with `repweights = tidyselect::all_of("repwt_1")` | `R = 1` |
| F4 | inline, below | `R = 8` |

F4:

```r
wt <- c(2.5, 3.1, 2.8, 2.2, 3.4, 2.9, 3.6, 2.4, 3.0, 2.7)
df <- data.frame(y1 = rep(NA_real_, 10), wt = wt)
for (i in 1:8) {
  df[[paste0("repwt_", i)]] <- wt * (0.9 + i / 100)
}
repwt_cols <- paste0("repwt_", 1:8)
```

Every surveycore design in a new block is built with
`as_survey_replicate(<frame>, weights = wt, repweights = tidyselect::all_of(repwt_cols), type = <type>, ...)`.
Every `survey` design is built with
`survey::svrepdesign(weights = <frame>$wt, repweights = <frame>[, repwt_cols], type = <type>, mse = TRUE, data = <frame>, ...)`.

Common literals:

- the supplied scale is `0.6`;
- the supplied JKn `rscales` is `rep(1, R)`: `rep(1, 20)` on F1, `rep(1, 5)`
  on F2, `1` on F3;
- a supplied `rscales` that a type discards is `rep(0.5, R)`;
- Fay always gets `rho = 0.3`.

Stored `scale` literals on F1 (`R = 20`):

| Type | Literal |
|---|---|
| `"JK1"` | `19 / 20` |
| `"JK2"` | `1` |
| `"JKn"` | `1` |
| `"BRR"` | `1 / 20` |
| `"Fay"`, `rho = 0.3` | `1 / (20 * (1 - 0.3)^2)` |
| `"bootstrap"` | `1 / 19` |
| `"ACS"` | `4 / 20` |
| `"successive-difference"` | `4 / 20` |
| `"other"` | `1` |

The four types that discard a supplied `scale` with a warning: `"BRR"`,
`"JK2"`, `"ACS"`, `"successive-difference"`. The three that discard a
supplied `rscales` with a warning: `"JK2"`, `"ACS"`,
`"successive-difference"`. The eight types other than Fay: `"JK1"`, `"JK2"`,
`"JKn"`, `"BRR"`, `"bootstrap"`, `"ACS"`, `"successive-difference"`,
`"other"`.

## `survey` condition texts

Transcribed for the builder. Read on `survey` 4.5 under R 4.6.1. Before PR 1
and PR 5 write a block that calls `survey`, build a probe design on the
installed version and confirm each text the block uses. If a text differs,
stop and raise a HOLD; do not edit the text to match.

| Call | `survey` condition text |
|---|---|
| `type = "BRR"`, `scale` supplied | `type='BRR' does not use 'scale=' argument` |
| `type = "JK2"`, any call | `with type JK2 scale= and rscales= are not needed and will be ignored` |
| `type = "ACS"`, `scale` or `rscales` supplied | `with type ACS scale= and rscales= are not needed and will be ignored` |
| `type = "successive-difference"`, `scale` or `rscales` supplied | `with type successive-difference scale= and rscales= are not needed and will be ignored` |
| `type = "other"`, `scale` or `rscales` not supplied | `scale or rscales not specified, set to 1` |
| `type = "JKn"`, combined weights, no `rscales` (error) | `Must provide rscales for combined JKn weights` |
| `type = "Fay"`, `scale` supplied | none |
| `type = "JK1"`, `"JKn"`, `"bootstrap"`, `scale` supplied | none |

Pass `mse = TRUE` to both sides of every block that compares against
`survey`.

## PR map

- [ ] PR 1: `fix/replicate-export-ignored-args` — the register rows, the two
  shared predicates, and the export route stops passing `scale` and
  `rscales` that `survey` overrides
  - **Budget** — 6 test-spec rows | 7 criteria
    - Rows: §6 6.10; §7 7.2, 7.3, 7.4; §8 T12; §9 9.1
  - **Tasks**
    1. Add the new section to the end of `plans/error-messages.md`, exactly
       as `spec.md` §VI gives it: the heading
       `### replicate-supplied-args rows (2026-10-01)`, the intro text (issue
       #255; RS-1 is the single class for "the replicate type ignores this
       argument"; RS-2 adds a call site to an existing class; RS-3 records
       the `as_survey_nonprob()` site, which shipped without a row), the
       variable bindings line, the table with rows RS-1, RS-2 and RS-3, and
       below it the heading `**Updated trigger descriptions for existing
       rows:**` with the FR-3 note (the `rho` warning now carries the two
       classes `c("surveycore_warning_rho_ignored",
       "surveycore_warning_replicate_arg_ignored")`; trigger and message do
       not change). Commit this before any code change.
    2. Write a failing test in `tests/testthat/test-conversion.R`, title
       "as_svydesign() passes no scale or rscales for an imported ACS or
       successive-difference design". On F2, for each of `"ACS"` and
       `"successive-difference"`:
       - `expect_no_warning(src <- survey::svrepdesign(weights = df$wt, repweights = df[, repwt_cols], type = ty, mse = TRUE, data = df))`;
       - `d <- from_svydesign(src)`;
       - `expect_identical(d@variables$rscales, rep(1, 5))`. If this fails
         only because `survey` stores `rscales` as a different numeric
         type, use `expect_equal(d@variables$rscales, rep(1, 5), tolerance = 1e-10)`
         and write the reason in a comment in the block;
       - `expect_no_warning(sv <- as_svydesign(d))`;
       - the SE of `survey::svymean(~y1, sv)` equals the SE of
         `survey::svymean(~y1, src)`, `tolerance = 1e-8`.
       On `develop` the `as_svydesign()` call raises `survey`'s `not needed`
       warning, so the block fails.
    3. Write a test, title "as_svydesign() raises only survey's JK2 warning
       for a JK2 design built with no scale". On F2: build `"JK2"` with no
       `scale` and no `rscales` inside `expect_no_condition()`; convert with
       `as_svydesign()` and assert exactly one `survey` warning with the JK2
       text; the SE of `survey::svymean(~y1, sv)` equals
       `get_means(d, y1, variance = "se")$se`, `tolerance = 1e-8`.
    4. Write a test, title "as_svydesign() passes no scale for an imported BRR
       design". On F2:
       `expect_no_warning(src <- survey::svrepdesign(..., type = "BRR", ...))`;
       `d <- from_svydesign(src)`; `d@variables$scale` equals `1 / 5`,
       `tolerance = 1e-8`; `expect_no_warning(sv <- as_svydesign(d))`; the SE
       of `survey::svymean(~y1, sv)` equals the SE of
       `survey::svymean(~y1, src)`, `tolerance = 1e-8`. This block already
       passes on `develop`; it pins the BRR member of the scale set.
    5. Write a test in `tests/testthat/test-variance-replicate.R`, title
       "survey::svrepdesign() refuses JKn combined weights with no rscales".
       On F1:
       `expect_error(survey::svrepdesign(weights = d$wt, repweights = d[, repwt_cols], type = "JKn", mse = TRUE, data = d), "Must provide rscales for combined JKn weights", fixed = TRUE)`.
       A comment says the block guards `survey`'s behaviour, which
       `as_survey_replicate()` mirrors for JKn (issue #255), and that a
       failure means `survey` changed.
    6. Implement `.replicate_ignores_scale()` and
       `.replicate_ignores_rscales()` in `R/utils.R`, word for word as
       `spec.md` §II "Functions added", comment headers included. No roxygen.
       No direct test.
    7. Implement `spec.md` §IV in `.as_svydesign_replicate()` in
       `R/methods-conversion.R`: `scale_arg` and `rscales_arg` through the two
       predicates, each wrapped in `isTRUE()`, passed as `scale =` and
       `rscales =`. Rewrite the comment above the `scale` argument with the
       three facts §IV lists. Change no other argument and no other step of
       the route.
    8. Write a test in `tests/testthat/test-conversion.R`, title
       "as_svydesign() converts a replicate design that stores no type". It
       is a no-error pin: it shows through the public API that the
       `isTRUE()` wrap of task 7 keeps a `NULL` stored type from failing in
       the route. On F2, build the design with the exported constructor:

       ```r
       d <- survey_replicate(
         data = df,
         variables = list(
           weights = "wt",
           repweights = repwt_cols,
           type = NULL,
           scale = 1 / 5,
           rscales = NULL,
           fpc = NULL,
           fpctype = "fraction",
           mse = TRUE,
           rho = NULL,
           visible_vars = NULL
         )
       )
       ```

       Measured on `survey` 4.5 (plan review pass 2): with a `NULL` stored
       type, `survey::svrepdesign()` falls back to BRR, raises one warning
       with the text `type='BRR' does not use 'scale=' argument`, and
       returns a design whose `sv$scale` is `0.2` (survey's own BRR value,
       `1 / 5`). The call raises no error. The block asserts that:
       - `w <- testthat::capture_warnings(sv <- as_svydesign(d))` completes
         with no error (a bare `if ()` on `logical(0)` would fail with
         `argument is of length zero`);
       - `expect_length(w, 1L)` and
         `expect_match(w, "type='BRR' does not use 'scale=' argument", fixed = TRUE)`;
       - `expect_true(inherits(sv, "svyrep.design"))`;
       - `sv$scale` equals `0.2`, `tolerance = 1e-8`.
       Write in a comment that the BRR fallback, the warning and the `0.2`
       are `survey` 4.5 behaviour, so a failure on a later version means
       `survey` changed. Probe the installed version first, as
       §`survey` condition texts says.
    9. Confirm the existing block "as_svydesign() reproduces a replicate
       nonprob's mean and SE [numerical]" in `tests/testthat/test-conversion.R`
       passes unchanged. It sends a `survey_nonprob` bootstrap design down
       the replicate route, where the predicates return `FALSE` and the
       stored `scale` and `rscales` still pass. A `survey_nonprob` JK2
       design is out of scope (`spec.md` §I Out).
    10. In `tests/testthat/test-conversion.R`, rewrite two comments. Change
        no call and no assertion.
        - Block "as_svydesign() warns and converts for every replicate type
          carrying an FPC": the comment inside the loop says `survey` warns
          "for the types that ignore a scale". The new comment says that
          only JK2 makes `survey` warn about ignored arguments, on every
          call.
        - The comment above the block "every accepted replicate type
          crosses both conversion routes": drop the claim that `survey`
          warns for the types that ignore a scale, and the quoted text
          'with type ACS scale= and rscales= are not needed'. Say that
          `survey` reports its own simpleWarning for every JK2 design and
          for `"other"` with no `rscales`, and that only JK2 makes `survey`
          warn about ignored arguments. Do not change the block's code; PR 4
          changes it.
        Both new comments contain the words "only JK2" (any case).
    11. Verify: the new tests pass and G holds.
  - **Acceptance criteria**
    1. `plans/error-messages.md` ends with the section
       `replicate-supplied-args rows (2026-10-01)`, holding RS-1
       (`surveycore_warning_replicate_arg_ignored`), RS-2 and RS-3
       (`surveycore_error_stratified_jk_rscales_unset`) and the FR-3 note
       naming both classes. On the PR branch, before merge (a squash merge
       loses the order), the commit that adds it is not later than the first
       commit touching `R/`: with
       `reg=$(git log --reverse --format=%H origin/develop..HEAD -- plans/error-messages.md | head -1)`
       and
       `code=$(git log --reverse --format=%H origin/develop..HEAD -- R | head -1)`,
       `git merge-base --is-ancestor "$reg" "$code"` exits 0 (9.1).
    2. "as_svydesign() passes no scale or rscales for an imported ACS or
       successive-difference design" passes at the PR head, and fails
       against `develop`'s export route. Procedure: `git worktree add <tmp>
       HEAD`; in `<tmp>`, `git checkout origin/develop -- R/methods-conversion.R R/utils.R`;
       run `Rscript -e "devtools::load_all(); testthat::test_file('tests/testthat/test-conversion.R')"`;
       that block reports a failure; `git worktree remove --force <tmp>`
       (7.2).
    3. "as_svydesign() raises only survey's JK2 warning for a JK2 design built
       with no scale" passes (7.3).
    4. "as_svydesign() passes no scale for an imported BRR design" and
       "as_svydesign() converts a replicate design that stores no type" pass,
       and the existing block "as_svydesign()
       reproduces a replicate nonprob's mean and SE [numerical]" passes
       unchanged (7.4).
    5. "survey::svrepdesign() refuses JKn combined weights with no rscales"
       passes (6.10).
    6. The blocks "as_svydesign() warns and converts for every replicate type
       carrying an FPC" and "every accepted replicate type crosses both
       conversion routes" pass. In `tests/testthat/test-conversion.R`,
       `grep -c "ignore a scale"` is 0, `grep -c "with type ACS scale="` is
       0, and `grep -ci "only JK2"` is 2 or more. Every line the PR removes
       from the file is a comment:
       `git diff -U0 origin/develop...HEAD -- tests/testthat/test-conversion.R | grep '^-[^-]' | grep -vc '^-\s*#'`
       is 0 (T12).
    7. G.
  - **Files touched**
    - `plans/error-messages.md`
    - `plans/spec-replicate-supplied-args.md` (planning copy, from commit
      `3957966`)
    - `plans/test-spec-replicate-supplied-args.md` (planning copy, from
      commit `3957966`)
    - `plans/decisions-replicate-supplied-args.md` (planning copy, from
      commit `3957966`)
    - `plans/implementation-plan-replicate-supplied-args.md` (planning
      copy)
    - `R/utils.R`
    - `R/methods-conversion.R`
    - `tests/testthat/test-conversion.R`
    - `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [ ] PR 2: `fix/replicate-jkn-rscales-required` — `as_survey_replicate()`
  refuses JKn with no `rscales`
  - **Budget** — 12 test-spec rows | 7 criteria
    - Rows: §5 5.16, 5.18; §8 T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
  - **Tasks**
    1. Write a failing test in `tests/testthat/test-constructors.R`, title
       "as_survey_replicate() refuses JKn with no rscales". On F1, `"JKn"`,
       no `rscales`:
       `expect_error(..., class = "surveycore_error_stratified_jk_rscales_unset")`
       and `expect_snapshot(error = TRUE, ...)` on the same call.
    2. Write a failing test, title "as_survey_replicate() refuses JKn with no
       rscales before the rho warning". On F1, `"JKn"`, no `rscales`,
       `rho = 0.3`:
       `expect_no_warning(expect_error(..., class = "surveycore_error_stratified_jk_rscales_unset"))`.
    3. Implement `spec.md` §III step 7 in `as_survey_replicate()`: after
       `.validate_rscales()` and before the Fay/`rho` step, abort when `type`
       is `"JKn"` (written `identical(type, "JKn")`) and `rscales` is `NULL`.
       Use the class and the three-bullet template of §III "Errors" word for
       word. Do not touch `as_survey_nonprob()` or `.is_stratified_jk()`.
    4. Retarget the ten existing blocks in `tests/testthat/test-constructors.R`
       that build JKn with no `rscales`. Change nothing else in them; keep
       every assertion.
       - "as_survey_replicate() JKn and bootstrap defaults rise by R/(R-1)":
         pass `rscales = rep(1, n_rep)` to the JKn call.
       - "as_survey_replicate() scale at one and two replicate columns": pass
         `rscales = 1` to the `d_jkn_one` call.
       - "as_survey_replicate() stores an explicit scale verbatim": pass
         `rscales = rep(1, n_rep)` to the JKn call.
       - "as_survey_replicate() JKn with rscales = NULL stores scale = 1":
         delete the block. The two blocks of tasks 1 and 2 replace it.
       - "as_survey_replicate() stores both changed defaults on a two-row
         frame": pass `rscales = rep(1, n_rep)` (`n_rep` is 20) to the JKn
         call.
       - "as_survey_replicate() stores the default scale of all nine types,
         Fay with rho": the local helper gains the argument `rscales = NULL`
         and passes it on; the JKn line becomes
         `expect_equal(stored("JKn", rscales = rep(1, 20)), 1)`.
       - "as_survey_replicate() warns and discards rho for the eight other
         types": pass `rscales = rep(1, 20)` for `"JKn"` and `NULL` for the
         other types, in both calls inside the loop.
       - "as_survey_replicate() stores the rho key for every type": pass
         `rscales = rep(1, 20)` for `"JKn"` only.
       - "as_survey_replicate() raises no warning for the eight other types
         with no rho": pass `rscales = rep(1, 20)` for `"JKn"` only.
       - "as_survey_twophase() refuses a replicate phase-1 of all nine
         types": pass `rscales = rep(1, 5)` for `"JKn"` only (that frame has
         5 replicate columns).
    5. Verify: the new tests pass; the snapshot holds the JKn refusal text
       ("`type = \"JKn\"` requires `rscales`."); the nine retargeted blocks
       pass; the existing `as_survey_nonprob()` snapshots for the same class
       are unchanged; G holds.
  - **Acceptance criteria**
    1. "as_survey_replicate() refuses JKn with no rscales" passes, raising
       `surveycore_error_stratified_jk_rscales_unset`; its new snapshot entry
       shows the three bullets beginning "`type = \"JKn\"` requires
       `rscales`.", "JKn replicate weights are combined weights" and "Pass
       `rscales` with one entry per replicate column" (5.16).
    2. "as_survey_replicate() refuses JKn with no rscales before the rho
       warning" passes: the error, no warning (5.18).
    3. No block titled "as_survey_replicate() JKn with rscales = NULL stores
       scale = 1" exists (T4).
    4. The blocks "JKn and bootstrap defaults rise by R/(R-1)", "scale at one
       and two replicate columns", "stores an explicit scale verbatim" and
       "stores both changed defaults on a two-row frame" pass with every
       assertion they had on `develop` (T1, T2, T3, T5).
    5. The blocks "stores the default scale of all nine types, Fay with rho",
       "warns and discards rho for the eight other types", "stores the rho
       key for every type" and "raises no warning for the eight other types
       with no rho" pass with every assertion they had on `develop` (T6, T7,
       T8, T9).
    6. "as_survey_twophase() refuses a replicate phase-1 of all nine types"
       passes with every assertion it had on `develop` (T10). For
       criteria 4 to 6:
       `git diff -U0 origin/develop...HEAD -- tests/testthat/test-constructors.R | grep '^-[^-]' | grep -c 'expect_'`
       is 4. Three are the `expect_` lines of the deleted block
       (`expect_no_condition(`, `expect_equal(d@variables$scale, 1)`,
       `expect_null(d@variables$rscales)`). The fourth is
       `expect_equal(stored("JKn"), 1)` in the nine-type default block, which
       comes back as `expect_equal(stored("JKn", rscales = rep(1, 20)), 1)`.
       In the other eight retargeted blocks every JKn call sits on its own
       lines, so adding `rscales` removes no `expect_` line. Every other
       changed line in the nine retargeted blocks adds an `rscales` argument,
       adds the helper's `rscales = NULL` formal, or adds a trailing comma
       for one of these.
    7. G.
  - **Files touched**
    - `R/core-constructors.R`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
  - **Pipeline tier**: recommended

- [ ] PR 3: `fix/replicate-scale-discard` — `as_survey_replicate()` discards a
  supplied `scale` for BRR, JK2, ACS and successive-difference, with the new
  warning
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §5 5.1, 5.2, 5.3, 5.4, 5.6, 5.10, 5.12, 5.13, 5.20, 5.24, 5.25,
      5.28
  - **Tasks**
    1. Write a failing test in `tests/testthat/test-constructors.R`, title
       "as_survey_replicate() discards a supplied scale for BRR, JK2, ACS and
       successive-difference". On F1, for each of the four types: build with
       `scale = 0.6` inside
       `expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored")`;
       build `d_plain` with no `scale` inside `expect_no_warning()`;
       `d@variables$scale` equals the F1 literal for the type
       (`1 / 20`, `1`, `4 / 20`, `4 / 20`), `tolerance = 1e-8`;
       `expect_identical(d@variables, d_plain@variables)`.
    2. Write a failing test, title "as_survey_replicate() warns for a supplied
       BRR scale equal to the default". On F1, `"BRR"`, `scale = 1 / 20`:
       `expect_warning(class = "surveycore_warning_replicate_arg_ignored")`.
    3. Write a failing test, title "as_survey_replicate() discards a
       non-numeric scale without checking it". On F1, for each of the four
       types `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`, with
       `scale = "a"`:
       `expect_no_error(expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored"))`;
       `d@variables$scale` equals the F1 literal for the type (`1 / 20`,
       `1`, `4 / 20`, `4 / 20`), `tolerance = 1e-8`.
    4. Write a failing snapshot test, title "as_survey_replicate() discard
       warning names scale alone". On F1, `"BRR"`, `scale = 0.6`:
       `expect_snapshot(d <- as_survey_replicate(...))`. The snapshot shows
       the one-argument text: "`scale` has no effect for this replicate type
       and was ignored.", "For type \"BRR\", the design stores the type's own
       value, as `survey::svrepdesign()` does.", "Remove `scale` from the
       call."
    5. Write a failing test, title "as_survey_replicate() never checks a
       discarded scale". On F1, loop over the five values `NA_real_`, `Inf`,
       `-1`, `0`, `rep(0.6, 20)`. For each value:
       - for each of the four types `"BRR"`, `"JK2"`, `"ACS"`,
         `"successive-difference"`: the type with `scale = <value>` inside
         `expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored")`,
         and `d_plain` with no `scale`; `d@variables$scale` equals the F1
         literal for the type (`1 / 20`, `1`, `4 / 20`, `4 / 20`),
         `tolerance = 1e-8`; `expect_identical(d@variables, d_plain@variables)`;
       - `"Fay"` with `rho = 0.3` and `scale = <value>` inside
         `expect_no_condition()`; the stored scale equals
         `1 / (20 * (1 - 0.3)^2)`, `tolerance = 1e-8`.
    6. Write a failing test, title "as_survey_replicate() discards a supplied
       scale at one replicate column". On F3: `"BRR"`, `"ACS"` and
       `"successive-difference"`, each with `scale = 0.6`, each warns with
       `surveycore_warning_replicate_arg_ignored` and stores `1`, `4`, `4`
       respectively, `tolerance = 1e-8`; `"JKn"` with `rscales = 1` builds
       inside `expect_no_condition()` and stores `1`, `tolerance = 1e-8`.
    7. Write a failing test, title "as_survey_replicate() discards a supplied
       scale on an all-NA outcome frame". On F4, `"JK2"`, `scale = 0.6`:
       warns with `surveycore_warning_replicate_arg_ignored`; the stored
       scale equals `1`, `tolerance = 1e-8`;
       `expect_true(all(is.na(d@data$y1)))`.
    8. Write tests that already pass and must keep passing:
       - title "as_survey_replicate() keeps a supplied scale for JK1, JKn,
         bootstrap and other": on F1, `"JK1"`, `"bootstrap"`, `"other"`, and
         `"JKn"` with `rscales = rep(1, 20)`, each with `scale = 0.6` inside
         `expect_no_warning()`; the stored scale equals `0.6`,
         `tolerance = 1e-8`;
       - title "as_survey_replicate() raises no warning on any type when
         scale and rscales are not supplied": on F1, all nine types, no
         `scale`, no `rscales`, except `"JKn"` gets `rscales = rep(1, 20)`
         and `"Fay"` gets `rho = 0.3`; `expect_no_warning()` for each;
       - title "as_survey_replicate() treats an explicit NULL scale and
         rscales as not supplied": on F1, each of the four discarding types
         with `scale = NULL, rscales = NULL` written out;
         `expect_no_warning()` for each;
       - title "as_survey_replicate() builds JKn with rscales and stores
         scale 1": on F1, `"JKn"`, `rscales = rep(1, 20)`, inside
         `expect_no_condition()`; the stored scale equals `1`,
         `tolerance = 1e-8`.
    9. Implement `spec.md` §III step 9 in `as_survey_replicate()`, the
       `"scale"` half only: build `ignored` with the `"scale"` condition
       (`.replicate_ignores_scale(type) && !identical(type, "Fay") && !is.null(scale)`);
       when `ignored` has length 1 or more, raise one `cli::cli_warn()` with
       class `surveycore_warning_replicate_arg_ignored` and the three-bullet
       template of §III "Warnings" word for word, with its bindings
       (`{ignored}`, `{n_ignored}` = `length(ignored)`, `{type}`); then set
       `scale <- NULL`. The step sits after the Fay/`rho` step and before the
       default-scale `switch()`. Do not add the `"rscales"` condition in this
       PR; PR 4 adds it. Write the template in full now, plural markers
       included, so PR 4 changes only the condition list.
    10. Confirm the existing block "as_survey_replicate() discards a supplied
        scale for Fay with no warning" passes unchanged.
    11. Verify: the new tests pass, the one new snapshot entry is reviewed,
        and G holds.
  - **Acceptance criteria**
    1. "as_survey_replicate() discards a supplied scale for BRR, JK2, ACS and
       successive-difference" passes for all four types (5.1).
    2. "as_survey_replicate() warns for a supplied BRR scale equal to the
       default" passes, and "as_survey_replicate() discards a non-numeric
       scale without checking it" passes for all four warning types (5.3,
       5.4).
    3. "as_survey_replicate() discard warning names scale alone" passes, and
       its new snapshot entry shows the singular text ("has no effect",
       "was ignored", "the type's own value") (5.6).
    4. "as_survey_replicate() never checks a discarded scale" passes for all
       five values on the four warning types and on Fay (5.28).
    5. "as_survey_replicate() keeps a supplied scale for JK1, JKn, bootstrap
       and other" and "as_survey_replicate() builds JKn with rscales and
       stores scale 1" pass (5.10, 5.20).
    6. "as_survey_replicate() raises no warning on any type when scale and
       rscales are not supplied", "as_survey_replicate() treats an explicit
       NULL scale and rscales as not supplied", and the existing block
       "as_survey_replicate() discards a supplied scale for Fay with no
       warning" pass (5.12, 5.13, 5.2).
    7. "as_survey_replicate() discards a supplied scale at one replicate
       column" and "as_survey_replicate() discards a supplied scale on an
       all-NA outcome frame" pass (5.24, 5.25).
    8. G.
  - **Files touched**
    - `R/core-constructors.R`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
  - **Pipeline tier**: recommended

- [ ] PR 4: `fix/replicate-rscales-discard` — `as_survey_replicate()`
  discards a supplied `rscales` for JK2, ACS and successive-difference
  - **Budget** — 12 test-spec rows | 8 criteria
    - Rows: §5 5.5, 5.7, 5.8, 5.9, 5.11, 5.14, 5.15, 5.17, 5.19, 5.21, 5.27;
      §8 T11
  - **Tasks**
    1. Write a failing test in `tests/testthat/test-constructors.R`, title
       "as_survey_replicate() discards a supplied rscales for JK2, ACS and
       successive-difference". On F1, for each of the three types: build with
       `rscales = rep(0.5, 20)` inside
       `expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored")`;
       build `d_plain` with no `rscales`; `expect_null(d@variables$rscales)`;
       `expect_identical(d@variables, d_plain@variables)`;
       `get_means(d, y1, variance = "se")$se` equals the same from `d_plain`,
       `tolerance = 1e-8`.
    2. Write a failing snapshot test, title "as_survey_replicate() discard
       warning names scale and rscales together". On F1, `"JK2"`,
       `scale = 0.6`, `rscales = rep(0.5, 20)`:
       `expect_snapshot(d <- as_survey_replicate(...))`. The snapshot shows
       this text, copied from the JK2 render in `spec.md` §III "Warnings":

       ```
       ! `scale` and `rscales` have no effect for this replicate type and were ignored.
       i For type "JK2", the design stores the type's own values, as `survey::svrepdesign()` does.
       v Remove `scale` and `rscales` from the call.
       ```
    3. Write a failing snapshot test, title "as_survey_replicate() discard
       warning names rscales alone". On F1, `"ACS"`, `rscales = rep(0.5, 20)`
       and no `scale`: `expect_snapshot(d <- as_survey_replicate(...))`. The
       snapshot shows this text, derived from the `spec.md` §III template
       with `ignored = "rscales"`, `n_ignored = 1` and `type = "ACS"`:

       ```
       ! `rscales` has no effect for this replicate type and was ignored.
       i For type "ACS", the design stores the type's own value, as `survey::svrepdesign()` does.
       v Remove `rscales` from the call.
       ```

       The template fixes every word. With one entry in `ignored`, both
       plural markers in the "!" bullet take the singular ("has", "was"),
       and `{cli::qty(n_ignored)}value{?s}` gives "value".
    4. Write a failing test, title "as_survey_replicate() raises one discard
       warning for scale and rscales together". On F1, for each of the three
       types, `scale = 0.6` and `rscales = rep(0.5, 20)`:
       `w <- testthat::capture_warnings(d <- as_survey_replicate(...))`;
       `expect_length(w, 1L)`; the stored scale equals the F1 literal
       (`1`, `4 / 20`, `4 / 20`), `tolerance = 1e-8`;
       `expect_null(d@variables$rscales)`.
    5. Write a failing test, title "as_survey_replicate() discards scale and
       rscales by the closed type sets". On F1, for each of the nine types,
       `scale = 0.6` and `rscales = rep(0.5, 20)` in the same call; Fay also
       gets `rho = 0.3`. "Warns" means
       `expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored")`;
       "none" means `expect_no_warning(d <- ...)`. Stored scale with
       `tolerance = 1e-8`; stored `rscales` with `expect_identical()` for
       `rep(0.5, 20)` and `expect_null()` for `NULL`.

       | Type | Condition | Stored `scale` | Stored `rscales` |
       |---|---|---|---|
       | `"JK1"` | none | `0.6` | `rep(0.5, 20)` |
       | `"JK2"` | warns | `1` | `NULL` |
       | `"JKn"` | none | `0.6` | `rep(0.5, 20)` |
       | `"BRR"` | warns | `1 / 20` | `rep(0.5, 20)` |
       | `"Fay"` | none | `1 / (20 * (1 - 0.3)^2)` | `rep(0.5, 20)` |
       | `"bootstrap"` | none | `0.6` | `rep(0.5, 20)` |
       | `"ACS"` | warns | `4 / 20` | `NULL` |
       | `"successive-difference"` | warns | `4 / 20` | `NULL` |
       | `"other"` | none | `0.6` | `rep(0.5, 20)` |

    6. Write tests that pin behaviour already in place, and must keep
       passing:
       - title "as_survey_replicate() keeps a supplied rscales for JK1, JKn,
         BRR, Fay, bootstrap and other": on F1, each of `"JK1"`, `"JKn"`,
         `"BRR"`, `"bootstrap"`, `"other"`, and `"Fay"` with `rho = 0.3`,
         with `rscales = rep(0.5, 20)` inside `expect_no_warning()`;
         `expect_identical(d@variables$rscales, rep(0.5, 20))`;
       - title "as_survey_replicate() builds JK2 with no rscales and raises
         nothing": on F1, `"JK2"`, no `scale`, no `rscales`, inside
         `expect_no_condition()`; `expect_null(d@variables$rscales)`; the
         stored scale equals `1`, `tolerance = 1e-8`;
       - title "as_survey_replicate() checks rscales length before discarding
         it": on F1, `"JK2"`, `rscales = c(1, 1)`:
         `expect_no_warning(expect_error(..., class = "surveycore_error_rscales_length"))`;
       - title "as_survey_replicate() checks rscales values before discarding
         them": on F1, `"ACS"`, `rscales = c(NA_real_, rep(1, 19))`:
         `expect_no_warning(expect_error(..., class = "surveycore_error_rscales_na"))`;
       - title "as_survey_replicate() refuses JKn with rscales = NULL passed
         explicitly": on F1, `"JKn"`, `rscales = NULL` written out:
         `expect_error(class = "surveycore_error_stratified_jk_rscales_unset")`;
       - title "as_survey_replicate() refuses a one-row JKn frame before the
         JKn refusal": on `F1[1, ]`, `"JKn"`, no `rscales`:
         `expect_error(class = "surveycore_error_single_row")`.
    7. Implement the `"rscales"` half of `spec.md` §III step 9: add the
       condition `.replicate_ignores_rscales(type) && !is.null(rscales)`,
       which appends `"rscales"` to `ignored` after `"scale"`; after the
       warning, set `rscales <- NULL` when `"rscales"` is in `ignored`. The
       warning template does not change.
    8. Retarget the block "every accepted replicate type crosses both
       conversion routes" in `tests/testthat/test-conversion.R`: change the
       line `rs <- if (ty %in% c("JK2", "JKn")) rep(1, 5L) else NULL` to
       `rs <- if (identical(ty, "JKn")) rep(1, 5L) else NULL`, so `rscales`
       goes to `"JKn"` only and no longer to `"JK2"`. PR 1 already rewrote
       the comment above the block; leave it. Change no other line and keep
       every assertion.
    9. Confirm the existing block "as_survey_replicate() refuses five frames
       before the scale switch" passes unchanged.
    10. Verify: the new tests pass, the two new snapshot entries are
        reviewed, and G holds.
  - **Acceptance criteria**
    1. "as_survey_replicate() discards a supplied rscales for JK2, ACS and
       successive-difference" passes for all three types (5.5).
    2. "as_survey_replicate() discard warning names scale and rscales
       together" and "as_survey_replicate() discard warning names rscales
       alone" pass; their two new snapshot entries hold the two three-line
       texts written out in tasks 2 and 3, word for word (5.7, 5.8).
    3. "as_survey_replicate() raises one discard warning for scale and
       rscales together" passes for all three types (5.9).
    4. "as_survey_replicate() discards scale and rscales by the closed type
       sets" passes for all nine types (5.27).
    5. "as_survey_replicate() keeps a supplied rscales for JK1, JKn, BRR,
       Fay, bootstrap and other" and "as_survey_replicate() builds JK2 with
       no rscales and raises nothing" pass (5.11, 5.21).
    6. "as_survey_replicate() checks rscales length before discarding it",
       "as_survey_replicate() checks rscales values before discarding them",
       "as_survey_replicate() refuses JKn with rscales = NULL passed
       explicitly" and "as_survey_replicate() refuses a one-row JKn frame
       before the JKn refusal" pass, and the existing block "refuses five
       frames before the scale switch" passes (5.14, 5.15, 5.17, 5.19).
    7. "every accepted replicate type crosses both conversion routes" passes
       (T11). Its two halves are checked this way:
       - the code: in `tests/testthat/test-conversion.R`,
         `grep -c 'c("JK2", "JKn")) rep(1, 5L)'` is 0 and
         `grep -c 'identical(ty, "JKn")) rep(1, 5L)'` is 1; and in
         `git diff -U0 origin/develop...HEAD -- tests/testthat/test-conversion.R | grep '^-[^-]'`
         the only removed line is the old `rs <-` line, so no assertion
         moved;
       - the conditions: the block raises no surveycore warning, which G
         item 2 checks (a JK2 discard warning would lift the suite's
         warning count above 256).
    8. G.
  - **Files touched**
    - `R/core-constructors.R`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
    - `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended

- [ ] PR 5: `test/replicate-supplied-scale-oracle` — oracle blocks against
  `survey` for a supplied scale, and export parity on all nine types
  - **Budget** — 10 test-spec rows | 5 criteria
    - Rows: §6 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9; §7 7.1
  - **Tasks**
    1. Probe first. On the installed `survey`, build each `survey` design the
       blocks below use and read back its warnings and `sv$scale`. Confirm
       every text in §`survey` condition texts. If one differs, raise a HOLD.
    2. Write nine oracle blocks in `tests/testthat/test-variance-replicate.R`,
       one per type. Each block, on F1:
       - starts with `skip_if_not_installed("survey")`;
       - builds the surveycore side `sc` and the `survey` side `sv` from F1,
         the same weight column, the same 20 replicate columns, the same
         `type`, `mse = TRUE` on both, and `scale = 0.6` on both;
       - computes `sc_mean <- get_means(sc, y1, variance = c("se", "ci"))` and
         `sv_mean <- survey::svymean(~y1, sv, na.rm = TRUE)`;
       - asserts `sc_mean$mean` against `coef(sv_mean)[["y1"]]`,
         `tolerance = 1e-10`; `sc_mean$se` against
         `as.numeric(survey::SE(sv_mean))`, `tolerance = 1e-8`;
         `sc_mean$ci_low` against `confint(sv_mean)[1]` and `sc_mean$ci_high`
         against `confint(sv_mean)[2]`, `tolerance = 1e-6`;
         `sc@variables$scale` against the literal, `tolerance = 1e-8`; and
         `sv$scale` against the same literal, `tolerance = 1e-8`. Assert each
         side's scale against the literal, never against the other side's
         scale;
       - asserts the conditions in the tables below. No
         `suppressWarnings()` anywhere.

       A comment in each block states why passing the literal `0.6` to both
       sides is allowed under oracle rule 2 of
       `.claude/rules/testing-surveycore.md`: `0.6` is a caller literal
       written in the block, not a value read off a design, and it equals
       none of the nine defaults at `R = 20`. For JK1, JKn, bootstrap and
       `other`, `survey` keeps a supplied scale, so each side computes with
       `0.6` independently, and the block turns red if surveycore drops or
       alters it. For BRR, Fay, JK2, ACS and successive-difference, `survey`
       discards it and computes its own, so the block turns red if
       surveycore keeps `0.6`, which is the defect issue #255 reports.
       `rscales` goes to the `survey` side for JKn only (rule 3).

       Types where both packages keep the scale:

       | Type | Extra arguments, both sides | Conditions | Scale literal | Extra assertion |
       |---|---|---|---|---|
       | `"JK1"` | none | `expect_no_warning()` round each constructor | `0.6` | SE of `sc` divided by the SE of a surveycore design built the same way with no `scale` equals `sqrt(0.6 / (19 / 20))`, `tolerance = 1e-8` |
       | `"JKn"` | `rscales = rep(1, 20)`, written as a literal on each side | `expect_no_warning()` round each constructor | `0.6` | ratio to the design with `rscales = rep(1, 20)` and no `scale` equals `sqrt(0.6 / 1)`, `tolerance = 1e-8` |
       | `"bootstrap"` | none | `expect_no_warning()` round each constructor | `0.6` | ratio equals `sqrt(0.6 / (1 / 19))`, `tolerance = 1e-8` |
       | `"other"` | none (no `rscales`) | surveycore: `expect_no_warning()`. `survey`: exactly one warning, text `scale or rscales not specified, set to 1` | `0.6` | ratio equals `sqrt(0.6 / 1)`, `tolerance = 1e-8` |

       Types where both packages discard the scale:

       | Type | Extra arguments, both sides | surveycore condition | `survey` condition | Scale literal |
       |---|---|---|---|---|
       | `"BRR"` | none | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `type='BRR' does not use 'scale=' argument` | `1 / 20` |
       | `"Fay"` | `rho = 0.3` | `expect_no_warning()` | `expect_no_warning()` | `1 / (20 * (1 - 0.3)^2)` |
       | `"JK2"` | none | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type JK2 scale= and rscales= are not needed and will be ignored` | `1` |
       | `"ACS"` | none | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type ACS scale= and rscales= are not needed and will be ignored` | `4 / 20` |
       | `"successive-difference"` | none | `expect_warning(class = "surveycore_warning_replicate_arg_ignored")` | exactly one warning, text `with type successive-difference scale= and rscales= are not needed and will be ignored` | `4 / 20` |

       Titles: "get_means() SE matches survey::svymean() with a supplied scale
       kept — <type>" for the first four, and "get_means() SE matches
       survey::svymean() with a supplied scale discarded — <type>" for the
       last five, with `<type>` the type name.
    3. Write a test in `tests/testthat/test-conversion.R`, title
       "as_svydesign() reproduces get_means() for all nine types built with a
       supplied scale". On F2, for each of the nine types: build with
       `scale = 0.6`; `"JKn"` also gets `rscales = rep(1, 5)`; `"Fay"` also
       gets `rho = 0.3`.
       - The constructor warns with `surveycore_warning_replicate_arg_ignored`
         for `"BRR"`, `"JK2"`, `"ACS"`, `"successive-difference"`, and raises
         nothing (`expect_no_warning()`) for the other five.
       - Convert with `as_svydesign()`. Conditions: for `"JK2"`, exactly one
         `survey` warning with the JK2 text; for `"other"`, exactly one
         `survey` warning, text `scale or rscales not specified, set to 1`;
         for the other seven, `expect_no_warning()`.
       - `survey::svymean(~y1, sv)` against
         `get_means(d, y1, variance = "se")`: estimate `tolerance = 1e-10`,
         SE `tolerance = 1e-8`.
       - `sv$scale` equals `0.6` for `"JK1"`, `"JKn"`, `"bootstrap"`,
         `"other"`; `1 / 5` for `"BRR"`; `1 / (5 * (1 - 0.3)^2)` for `"Fay"`;
         `1` for `"JK2"`; `4 / 5` for `"ACS"` and `"successive-difference"`;
         each `tolerance = 1e-8`.
    4. Verify: the ten new blocks pass, and G holds.
  - **Acceptance criteria**
    1. The four blocks "get_means() SE matches survey::svymean() with a
       supplied scale kept — JK1 / JKn / bootstrap / other" pass, each with
       its SE ratio literal (6.1, 6.2, 6.3, 6.4).
    2. The five blocks "get_means() SE matches survey::svymean() with a
       supplied scale discarded — BRR / Fay / JK2 / ACS /
       successive-difference" pass (6.5, 6.6, 6.7, 6.8, 6.9).
    3. Each of the nine oracle blocks asserts the estimate, the SE, both
       bounds and both stored scales against literals with the tolerances
       above, and none of the nine calls `suppressWarnings()` or
       `testthat::expect_failure()`:
       `git diff origin/develop...HEAD -- tests | grep '^+[^+]' | grep -vE '^\+\s*#' | grep -cE 'suppressWarnings\(|expect_failure\('`
       is 0. The check reads added code lines only: two existing comments in
       `tests/testthat/test-variance-replicate.R` name `expect_failure()`,
       and an added comment may name it too (6.1 to 6.9).
    4. "as_svydesign() reproduces get_means() for all nine types built with a
       supplied scale" passes for all nine types (7.1).
    5. G.
  - **Files touched**
    - `tests/testthat/test-variance-replicate.R`
    - `tests/testthat/test-conversion.R`
  - **Pipeline tier**: recommended

- [ ] PR 6: `fix/replicate-rho-class-and-docs` — the `rho` warning gains the
  second class; roxygen, `NEWS.md` and the changelog record the whole change
  - **Budget** — 7 test-spec rows | 7 criteria
    - Rows: §5 5.22, 5.23, 5.26; §9 9.2, 9.3, 9.4, 9.5
  - **Tasks**
    1. Write a failing test in `tests/testthat/test-constructors.R`, title
       "as_survey_replicate() rho warning carries the replicate_arg_ignored
       class". On F1, for each of the eight types other than Fay, `rho = 0.3`,
       `"JKn"` also with `rscales = rep(1, 20)`:
       `expect_warning(d <- ..., class = "surveycore_warning_replicate_arg_ignored")`;
       then a second, identical call inside
       `expect_warning(..., class = "surveycore_warning_rho_ignored")`;
       `expect_null(d@variables$rho)`.
    2. Write a snapshot test, title "as_survey_replicate() raises the rho
       warning before the discard warning". On F1, `"BRR"`, `rho = 0.3`,
       `scale = 0.6`: `expect_snapshot(d <- as_survey_replicate(...))` shows
       two warnings, the `rho` warning first; then
       `w <- testthat::capture_warnings(d <- as_survey_replicate(...))`,
       `expect_length(w, 2L)`; the stored scale equals `1 / 20`,
       `tolerance = 1e-8`.
    3. Write a test, title "as_survey_replicate() raises the rho warning and
       one discard warning for scale, rscales and rho together". On F1, for
       each of `"JK2"`, `"ACS"`, `"successive-difference"`, with
       `scale = 0.6`, `rscales = rep(0.5, 20)` and `rho = 0.3`:
       `w <- testthat::capture_warnings(d <- as_survey_replicate(...))`;
       `expect_length(w, 2L)`;
       `expect_match(w[[1L]], "applies only to", fixed = TRUE)` (the `rho`
       warning comes first);
       `expect_match(w[[2L]], "have no effect for this replicate type", fixed = TRUE)`
       (one discard warning, plural, naming both arguments); the stored
       scale equals the F1 literal (`1`, `4 / 20`, `4 / 20`),
       `tolerance = 1e-8`; `expect_null(d@variables$rscales)`;
       `expect_null(d@variables$rho)`.
    4. Implement `spec.md` §III step 8's class change: the `rho` warning's
       `cli::cli_warn()` gets
       `class = c("surveycore_warning_rho_ignored", "surveycore_warning_replicate_arg_ignored")`.
       Its message does not change. The existing snapshot of the `rho`
       warning on BRR alone must stay byte-identical.
    5. Write the roxygen in `R/core-constructors.R` for
       `as_survey_replicate()`. `@param scale` states each of these facts.
       The wording around them is yours, but each fact carries the required
       literal given in the table after this task, taken from `spec.md`.
       Existing facts stay unless this list contradicts them:
       1. `"JK1"`, `"JKn"`, `"bootstrap"` and `"other"` store a supplied
          `scale` as given.
       2. For `"BRR"`, `"JK2"`, `"ACS"` and `"successive-difference"`, a
          supplied `scale` is ignored with a warning, and the design stores
          the type's own value. `survey::svrepdesign()` does the same.
       3. For `"Fay"`, a supplied `scale` is ignored with no warning, as
          `survey::svrepdesign()` does (existing fact; keep it).
       4. The warning class is `surveycore_warning_replicate_arg_ignored`.
       5. surveycore warns only when the caller supplies `scale` or
          `rscales`. `survey::svrepdesign()` warns on every `"JK2"` call, even
          when the caller supplies neither. Reason: a warning that fires when
          the caller passed nothing tells the caller nothing, and unasserted
          warnings hide new ones.
       6. Remove the sentence "`rscales = NULL` leaves no jackknife factor in
          the variance at all". In its place: `"JKn"` requires `rscales`, and
          `rscales = NULL` is refused, as `survey::svrepdesign()` refuses it
          for combined weights.
       7. Keep the sentence "Pass `scale` explicitly to reproduce numbers
          published before these two defaults moved".

       `@param rscales` states each of these facts:
       1. Required for `"JKn"`; `NULL` is refused.
       2. For `"JK2"`, `"ACS"` and `"successive-difference"`, a supplied
          `rscales` is ignored with the same warning, and the design stores
          `NULL`, which the variance treats as `rep(1, R)`.
          `survey::svrepdesign()` forces `rep(1, R)` for these types.
       3. For the other five types, a supplied `rscales` is stored as given.
       4. The length and value checks run on a supplied `rscales` for every
          type, including the three that ignore it.

       `@param rho` states that for `"JKn"` with no `rscales` the refusal
       fires and no `rho` warning is raised, where `survey::svrepdesign()`
       raises both. It may add that the `rho` warning also carries the class
       `surveycore_warning_replicate_arg_ignored`.

       Required literals. Each is a plain-text phrase from `spec.md` §III
       "Roxygen facts" or §V, with no code markup inside it, so it survives
       the conversion to Rd. Check each in the joined Rd text (see task 11).
       Matching ignores case. Where no literal fits, the reviewer ticks the
       named checklist item.

       | Fact | Entry | Required literal in the Rd | Reviewer checklist item |
       |---|---|---|---|
       | scale 1 | `@param scale` | `as given` | the phrase sits in `scale` and names JK1, JKn, bootstrap, other |
       | scale 2 | `@param scale` | `the type's own value` | — |
       | scale 3 | `@param scale` | `discarded with no warning` (already present; keep it) | — |
       | scale 4 | `@param scale` | `surveycore_warning_replicate_arg_ignored` | — |
       | scale 5 | `@param scale` | `warns on every` | R5a: the reason is stated (a warning that fires when the caller passed nothing tells the caller nothing) |
       | scale 6 | `@param scale` | `combined weights`; and `leaves no jackknife factor` is absent | — |
       | scale 7 | `@param scale` | `reproduce numbers published before these two defaults moved` (already present; keep it) | — |
       | rscales 1 | `@param rscales` | `required for` | — |
       | rscales 2 | `@param rscales` | `the variance treats as` | — |
       | rscales 3 | `@param rscales` | none fits | R3: the entry says the other five types store a supplied `rscales` as given |
       | rscales 4 | `@param rscales` | `including the three that ignore it` | — |
       | rho | `@param rho` | `raises both` | — |

       On `develop`, only `discarded with no warning` and `reproduce numbers
       published before these two defaults moved` are present in
       `man/as_survey_replicate.Rd`. The others are new.
    6. Write the roxygen for `as_survey_nonprob()`: one sentence, in the
       `type` entry for `"JK2"` or in `@param rscales` (your choice), stating
       that `as_survey_replicate()` accepts `"JK2"` with no `rscales`, as
       `survey::svrepdesign()` does, and that `as_survey_nonprob()` keeps the
       refusal because `survey` has no non-probability design class and so
       is not the reference for this constructor. Change no code line of
       `as_survey_nonprob()`. Required literal in
       `man/as_survey_nonprob.Rd`: `non-probability design class`. Reviewer
       checklist item N1: the sentence says `as_survey_replicate()` accepts
       `"JK2"` with no `rscales`, as `survey::svrepdesign()` does.
    7. Run `devtools::document()`. Commit the regenerated
       `man/as_survey_replicate.Rd` and `man/as_survey_nonprob.Rd`.
    8. Write `NEWS.md`, in the development section. Under the existing
       `## Breaking changes` heading, two entries:
       1. `as_survey_replicate()` now ignores a supplied `scale` for `"BRR"`,
          `"JK2"`, `"ACS"` and `"successive-difference"`, and a supplied
          `rscales` for `"JK2"`, `"ACS"` and `"successive-difference"`, as
          `survey::svrepdesign()` does. It stores the type's own value and
          warns with `surveycore_warning_replicate_arg_ignored`. A caller who
          passed one of these gets the standard error `survey` computes,
          which differs from the one surveycore returned before. Nothing
          changes when the caller supplies neither, and surveycore then
          raises no warning, unlike `survey` for `"JK2"`. `"Fay"` already
          ignored `scale` with no warning. The `rho` warning,
          `surveycore_warning_rho_ignored`, now also carries the new class.
          (#255)
       2. `as_survey_replicate(type = "JKn")` now requires `rscales` and
          refuses `rscales = NULL` with
          `surveycore_error_stratified_jk_rscales_unset`, as
          `survey::svrepdesign()` refuses combined JKn weights without it.
          Before this change the design built with `rep(1, R)` and left the
          jackknife factor out of the variance. To migrate, pass `rscales`
          with one entry per replicate column, for example
          `(n_h - 1) / n_h`, where `n_h` is the number of PSUs in the stratum
          the replicate drops a PSU from. `"JK2"` with no `rscales` still
          builds. (#255, #244)

       Under the existing `## Bug fixes` heading, one entry:
       3. `as_svydesign()` no longer passes `scale` to
          `survey::svrepdesign()` for `"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` and
          `"successive-difference"`, or `rscales` for `"JK2"`, `"ACS"` and
          `"successive-difference"`. `survey` computes those values itself.
          The exported design computes the same numbers, and `survey` no
          longer warns about the ignored arguments for `"ACS"` and
          `"successive-difference"`. It still warns for every `"JK2"`
          design. (#255)
    9. Confirm the two existing blocks
       "surveycore_error_stratified_jk_rscales_unset fires for JK2 with
       rscales = NULL" and "surveycore_error_stratified_jk_rscales_unset fires
       for JKn with rscales = NULL" pass with their snapshots byte-identical.
    10. Write `changelog/fix-replicate-supplied-args.md`, a new file at that
        flat path. One entry covers the whole arc. Follow the format of
        `changelog/fix-as-svydesign-domain.md`:
        - title `# Changelog: fix/replicate-supplied-args`;
        - a header block with **Branches:** (the six branch names of this
          plan), **PRs:** (the five earlier PR numbers, and "this PR"),
          **Issues:** #255, #244, **Status:** Complete, **Date:**;
        - `## Summary`: what `as_survey_replicate()` now does with a supplied
          `scale`, `rscales` and `rho`, the JKn refusal, and the export-route
          change, using the facts of the three `NEWS.md` entries;
        - `## Files Modified`: the eleven files of `spec.md` §II, one line
          each;
        - `## Changes`: one bullet per PR;
        - `## Verification`: the oracle tolerances (estimate 1e-10, SE 1e-8,
          bounds 1e-6) and the final suite and coverage figures from this
          PR's gate run.
    11. Check the documentation with line breaks removed. Roxygen and Rd both
        wrap text, so a plain `grep` misses a phrase split across two lines.
        This checkout has `core.autocrlf=true`, so `R/` and `man/` files end
        each line with `\r\n`; the join must turn both characters into
        spaces, or a `\r` stays inside a wrapped phrase. On `develop`,
        `leaves no jackknife factor` is wrapped across lines 79 and 80 of
        `man/as_survey_replicate.Rd`, so a join that keeps `\r` reports it
        absent when it is present. Define:

        ```bash
        rd_text() { tr '\r\n' '  ' < "$1" | tr -s ' '; }
        roxy_text() { grep "^#'" R/core-constructors.R | sed "s/^#' *//" | tr '\r\n' '  ' | tr -s ' '; }
        ```

        Then:
        - `rd_text man/as_survey_replicate.Rd | grep -c "leaves no jackknife factor"`
          is 0, and `roxy_text | grep -c "leaves no jackknife factor"` is 0;
        - for each required literal of task 5,
          `rd_text man/as_survey_replicate.Rd | grep -ci "<literal>"` is 1;
        - `rd_text man/as_survey_nonprob.Rd | grep -ci "non-probability design class"`
          is 1.

        Use `grep -ci`, not `grep -ciF`: `-F` aborts with exit 134 in this
        Git Bash. No required literal contains a regex metacharacter
        (`. * [ ] ^ $ \ + ? ( ) { } |`), so each matches as plain text with
        no escaping. Quote each literal in double quotes; the apostrophe in
        `the type's own value` needs no escape there. The output of
        `rd_text` and `roxy_text` is one line, so each count is 0 or 1.
        Before relying on the absence check, run it once against the
        `develop` copy of `man/as_survey_replicate.Rd`
        (`git show origin/develop:man/as_survey_replicate.Rd > <tmp>`, then
        `rd_text <tmp>`); it must count 1 there.
    12. Verify: the new tests pass, the one new snapshot entry is reviewed,
        `devtools::document()` leaves no diff, the task 11 checks give the
        counts it names (with lines joined by `tr '\r\n' '  '`, on both the
        roxygen source and the Rd), and G holds.
  - **Acceptance criteria**
    1. "as_survey_replicate() rho warning carries the replicate_arg_ignored
       class" passes for all eight types (5.22).
    2. "as_survey_replicate() raises the rho warning before the discard
       warning" passes: two warnings, `rho` first in the new snapshot entry,
       stored scale `1 / 20`; the existing `rho`-on-BRR snapshot entry is
       unchanged. "as_survey_replicate() raises the rho warning and one
       discard warning for scale, rscales and rho together" passes for JK2,
       ACS and successive-difference (5.23).
    3. In the task 11 checks on `man/as_survey_replicate.Rd`, with lines
       joined by `tr '\r\n' '  '`: the phrase `leaves no jackknife factor`
       counts 0 in both the Rd and the roxygen source (and 1 in the
       `develop` copy of the Rd); each of the eleven required literals of task 5 counts 1; and
       the reviewer ticks checklist items R5a and R3 (9.2).
    4. In the task 11 check on `man/as_survey_nonprob.Rd`, the literal
       `non-probability design class` counts 1, and the reviewer ticks
       checklist item N1; the two existing `as_survey_nonprob()` refusal
       blocks pass with byte-identical snapshots (9.3, 5.26).
    5. `NEWS.md`'s development section holds the two Breaking-changes entries
       (one citing #255, one citing #255 and #244, the latter telling the
       caller to pass `rscales` with one entry per replicate column, with
       `(n_h - 1) / n_h` as the example) and the one Bug-fixes entry for
       `as_svydesign()` citing #255 (9.4).
    6. `changelog/fix-replicate-supplied-args.md` exists with the headings
       `## Summary`, `## Files Modified`, `## Changes` and
       `## Verification`, and names issues #255 and #244.
    7. G, including `devtools::document()` leaving no diff (9.5).
  - **Files touched**
    - `R/core-constructors.R`
    - `man/as_survey_replicate.Rd` (generated)
    - `man/as_survey_nonprob.Rd` (generated)
    - `NEWS.md`
    - `changelog/fix-replicate-supplied-args.md` (new)
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/_snaps/constructors.md`
  - **Pipeline tier**: recommended

## Row assignment

59 rows. Each appears once.

| PR | Rows | Count |
|---|---|---|
| 1 | 6.10, 7.2, 7.3, 7.4, T12, 9.1 | 6 |
| 2 | 5.16, 5.18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10 | 12 |
| 3 | 5.1, 5.2, 5.3, 5.4, 5.6, 5.10, 5.12, 5.13, 5.20, 5.24, 5.25, 5.28 | 12 |
| 4 | 5.5, 5.7, 5.8, 5.9, 5.11, 5.14, 5.15, 5.17, 5.19, 5.21, 5.27, T11 | 12 |
| 5 | 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 7.1 | 10 |
| 6 | 5.22, 5.23, 5.26, 9.2, 9.3, 9.4, 9.5 | 7 |

By section: §5 rows 5.1 to 5.28 (28), §6 rows 6.1 to 6.10 (10), §7 rows 7.1
to 7.4 (4), §8 rows T1 to T12 (12), §9 rows 9.1 to 9.5 (5).

New snapshot entries, by PR, and no others: PR 2 the JKn refusal; PR 3 the
BRR scale-only warning; PR 4 the JK2 two-argument warning and the ACS
`rscales`-only warning; PR 6 the BRR `rho`-plus-scale pair.

## Planning notes

**P-1. The discard step lands in two halves.** `spec.md` §III step 9 holds
both the `scale` and the `rscales` conditions. Together, their tests and the
retarget they force come to 24 rows, twice the PR budget. PR 3 lands the
`scale` condition with the full warning template. PR 4 adds the `rscales`
condition. Between the two merges, a JK2, ACS or successive-difference call
that supplies `rscales` stores it and gets no `rscales` warning, as on
`develop`. A reviewer of PR 3 should read the missing `rscales` condition as
planned, not as an omission.

**P-2. Each retarget lands with the behaviour that breaks it.** `spec.md` §X
requires this, and the plan keeps it: T1 to T10 land in PR 2 with the JKn
refusal, and T11's code change lands in PR 4 with the `rscales` discard,
because its loop passes `rscales` to JK2. T11's comment names an ACS `survey`
warning that stops firing in PR 1, so PR 1 rewrites that comment and leaves
the code to PR 4. The row T11 stays with PR 4; PR 1's criterion 6 checks the
comment. T12 lands in PR 1, the PR whose export change makes its comment
stale. The two predicates land in `R/utils.R` in PR 1 with one call site
each, as `spec.md` §II places them. The second call site of
`.replicate_ignores_scale()` arrives in PR 3, and the second call site of
`.replicate_ignores_rscales()` arrives in PR 4.

**P-3. Three blocks from plan review attach to existing criteria.** Plan
review pass 1 asked for three test blocks that no test-spec row names. Each
attaches to the criterion nearest its subject, so no row count moves:
- the block for a replicate design that stores no type (finding L4-3) pins
  the `isTRUE()` wrap round the export-side predicates, and attaches to PR 1
  criterion 4 with row 7.4, the other export-side predicate pin;
- the existing block "as_svydesign() reproduces a replicate nonprob's mean
  and SE [numerical]" (finding L4-5) is named, not written, and attaches to
  PR 1 criterion 4 too;
- the block for JK2, ACS and successive-difference with `scale`, `rscales`
  and `rho` together (finding L4-1, a `spec.md` §III edge case) attaches to
  PR 6 criterion 2 with row 5.23, the other two-warning ordering row.

**P-4. `survey::svrepdesign()` takes `rho`, not `fay.rho`.** Plan review
finding L3-9 said `survey` takes `fay.rho`. That is the argument of
`survey::as.svrepdesign()`. `survey::svrepdesign()` takes `rho`: the export
route passes `rho = rho_arg` (`R/methods-conversion.R`, the
`survey::svrepdesign()` call in `.as_svydesign_replicate()`), and the
existing Fay oracle blocks in `tests/testthat/test-variance-replicate.R`
pass `rho = rho`. The plan keeps `rho = 0.3` on the `survey` side and states
the difference under §How to read. The F4 half of the finding is applied:
F4 now defines `repwt_cols`.
