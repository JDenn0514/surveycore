# Review — PR 5 — restrict-to-domain-coercion

**Verdict**: PASS
**Date**: 2026-09-15 17:00

Trees read: `50b9a88` (commit `ead5691`, the tree all seven gates ran on) and
`524899e` (commit `8e04236`, the comment-only follow-up and the shipping tree).

## Convergence checks

- Spec coverage: **y**. `spec.md` §Function contracts `.restrict_to_domain()`
  states four items — unchanged signature, no coercion on the read, `& !is.na(r)`
  kept, no condition raised on any route — and the design note. Each has a row in
  the audit table. The shipped body reads
  `r <- frame[[SURVEYCORE_DOMAIN_COL]]` then `converted[r & !is.na(r), ]`.
- Test coverage of spec: **y**. `test-spec.md` §5 rows 5.1 to 5.5 cover the
  Taylor, replicate, two-phase and no-marker routes. Row 5.5 covers "raises
  nothing". The nonprob route has no row of its own and needs none: it reaches
  the Taylor helper, per `archive/as-svydesign-bridge/`.
- Tolerance integrity: **y**. §Tolerances gives §5 no tolerance; every row
  asserts a class, a count or a row name with `expect_identical()`. The audit
  reports exact for all eight table rows. No row is looser.
- Scope discipline: **y**. `git diff --name-only b2fa7e1..HEAD` returns
  `R/methods-conversion.R` and `tests/testthat/test-conversion.R`. That is the
  plan's Files-touched list, with nothing added and nothing missing.
- Regression safety: **y**. Tests 11891 → 11912 (+21, the 21 expectations the
  five new blocks carry), failures 0 → 0, skips 4 → 4, warnings 256 → 256
  (the pre-existing AAPOR set, D12), check NOTEs 2 → 2, coverage 96.15% → 96.15%.
  No test outside the PR scope changed state.

Coverage floor: 96.15% against a 95% floor, no drop. `R/methods-conversion.R`
reads 99.77%; its one uncovered line, 636, sits in `.find_col_by_value()` and
carries `# nocov`. Every line of `.restrict_to_domain()` is covered, so the new
code adds no uncovered line. The "changed R/ files: 3" column is the D22
stale-ref artifact; the true changed set is one file.

CRAN cookbook: the audit table reads None, and the verdict is PASS, so there is
no classification error. Seven profile gates all carry a result and none is
skipped.

No `comprehension.md` [no such file] exists for this arc, so the comprehension check does not
apply.

## Acceptance criteria — all eight

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Rows 5.1, 5.2, 5.4 pass; each converted object holds only the `TRUE` rows, `sum(mask)` rows for 5.2 and 5.4, the `NA` rows absent | Met | Three blocks in `tests/testthat/test-conversion.R`. Each asserts `nrow == sum(pair$mask)` AND `rownames == as.character(which(pair$mask))`, so a right count over wrong rows fails. 148 of 200 on both routes. Row 5.4 also pins `nrow(repweights)`. |
| 2 | Row 5.3: the two-phase conversion keeps every row, and the finite-probability count equals `sum(mask)` | Met, against the D25 correction | The block asserts `nrow(phase1$sample$variables) == sum(subset)` = 74 and `sum(is.finite(prob)) == sum(mask & subset)` = 52. The criterion's own figure, `sum(mask)` = 149, is unreachable on this route for any implementation: the route also voids rows outside phase 2. D25 records the correction, and the tester reproduced 149 / 74 / 52 independently. `expect_lt(in_domain_and_phase2, sum(pair$mask))` proves on the data that the two candidate expectations are different numbers. |
| 3 | Row 5.5: a no-marker design converts with every row kept and no condition | Met | `expect_no_condition(sv <- as_svydesign(d))`, plus `nrow` and `rownames` against the source frame, plus a guard that the column is absent to begin with. |
| 4 | Each of the five blocks calls `skip_if_not_installed("survey")` inside the block | Met | Line 2 of each of the five blocks in the diff. `test-conversion.R` carries no file-level skip. |
| 5 | Gate 1: `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returns nothing | Met | Re-run at review time: no output, exit 1. |
| 6 | Gate 13: the source sweep returns exactly three files | Met | Re-run: `R/analysis-helpers.R`, `R/analysis-t-test.R`, `R/glm-anova.R`. |
| 7 | "no validator checks its type" is gone from `R/`, and the new note records two facts | Met | Re-run grep: no output, exit 1. The note at `R/methods-conversion.R:60-72` states both facts. See judgment 2 for the accuracy check. |
| 8 | Gates 2 and 5 to 12 and the cookbook scan are clean | Met | `gates/pr-5/summary.log`, tree `50b9a88`: seven gates PASS, `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11912`, 2 pre-approved NOTEs, covr 96.15%. Gate 2's source sweep returns the two `R/analysis-t-test.R` writers, both logical, both unedited. This PR adds no `cli::cli_abort()`, so gate 5 is vacuous and holds. `document()` wrote nothing. |

## Cross-consistency notes

`implementation.md` and `audit.md` describe the same work on the same tree.
Both name `50b9a88`; `git rev-parse ead5691^{tree}` confirms it. Both report the
same fixture figures (200 rows, `sum(mask)` 149, `sum(subset)` 74,
`sum(mask & subset)` 52) and the same `approx` contrast, 74 against 52. The
builder's block table lists 21 expectations over five blocks, and gate 2 shows a
+21 PASS delta. The two artifacts disagree nowhere.

The audit's one open observation — the two-phase block's comment named a HOLD
rather than an issue number — is closed by commit `8e04236`, which the audit
predates. The comment now reads "filed as issue #276". Issue #276 is open on
GitHub and carries the measurement and the one-line fix.

**The shipping tree is not the gated tree, and that is acceptable here.** A tree
the gates did not run on needs an explicit equivalence argument, so here it is.
`git diff ead5691..8e04236` rewrites two lines inside one `#` comment block above
a `test_that()` call in `tests/testthat/test-conversion.R`. It changes no R
expression, no roxygen line, and no file under `R/`, `man/` or `_snaps/`. That
rules out gates 1, 3, 4, 5, 6 and 7 by construction — coverage is measured over
`R/`, and `R CMD check` does not read a comment in a test file. Gate 2 is the one
gate a test file can move, and the orchestrator re-ran that file: 0 failures.
`air format --check` is the one remaining reader of the text; `air` does not
reflow a comment, and I measured the two new lines at 74 and 57 characters,
inside the 80 bound. So `524899e` is gate-equivalent to `50b9a88`.

## The four judgments

**1. Deferring issue #276, and whether the test comment is candid.** The defer is
the right call, and the comment is candid rather than a dressing-up.

The comment states the mechanism in full: the fixture ships `method = "approx"`,
the helper tests `inherits(converted, "twophase2")`, an `approx` object fails
that test, it carries no `$variables`, and the helper "returns it unrestricted".
It then says the gap is a defect of its own, gives the issue number, and says no
assertion here pins it. A reader learns the defect, its cause, and where to
follow it. Nothing in the block reads as covering the `approx` route.

On shipping a PR that edits a function while knowingly leaving a no-op in it: the
two sit on different lines and have different causes. The no-op is in the class
test at the top of the helper, which decides where the frame lives. This PR
changes the read of the marker column further down. The `approx` route returns
early at the name test and never reaches the changed line, so this PR can make
the defect neither better nor worse. The defect predates the arc —
`archive/as-svydesign-domain/` added the helper and exercised `method = "full"`
alone. Folding the one-line widening into PR 5 would put a behavioural change to
a conversion route, plus a `NEWS.md` entry, inside a frozen task list with no
test-spec row to audit it against, and `method = "simple"` is a third value
nobody has measured. D25's reasoning holds, and I do not disagree with it.

One residual, non-blocking. The design note in `R/methods-conversion.R` is
confident about the helper and says nothing about #276, and the only pointer
lives in a test-file comment. The next reader of the helper meets the confident
note first. Criterion 7 asks for two facts and the note delivers exactly those,
so this is not a miss against the plan. The #276 PR should add the pointer where
the defect is.

**2. The replacement design note.** It states both required facts, and both are
accurate.

- Fact one: "The `survey_base` validator rejects a marker column of any type but
  logical, on construction and on every later write to `@data`". True as stated,
  and true for every route that reaches this helper. All three call sites are
  `as_svydesign()` routes that pass `data = x@data` from a validated design into
  `survey::svydesign()`, `survey::svrepdesign()` or `survey::twophase()`, none of
  which retypes a column.
- Fact two: "`!is.na(r)` stays, and is still load-bearing. The validator forbids
  a non-logical column; it does not forbid `NA`." True, and rows 5.2 and 5.4
  exercise it on live data.

On the question you raised — #276 shows the helper reachable in a state nobody
tested, so does that weaken fact one? It does not. The untested `approx` route
fails the name test and returns before the marker line runs. Fact one is a claim
about the type of the column at the line that reads it, and every path that
reaches that line comes from a validated `@data`. #276 is a routing defect, not a
typing hole.

One point the note does not make and does not need to: `as.logical()` also
stripped the attributes off a legal logical column. `spec.md` allows a logical
column that carries a label, and allows a one-column logical matrix. Neither
changes the selected rows, because `r & !is.na(r)` builds the index either way.

**3. Five regression rows for a change whose point is that behaviour does not
move.** That is the right surface, and I find nothing missing.

A removal that claims "nothing moves" can be proved two ways: run the rows on
both trees, and show the rows can fail. Both were done. The builder ran all five
against the pre-change tree with the coercion restored. The tester replaced the
helper in the loaded namespace with two breaks and re-ran. Every row fails under
at least one break. Row 5.5 is the interesting one: it cannot fail under "return
`converted` unchanged", because that is the right answer for a design with no
marker, and it fails under "always drop row 1". The probe therefore proves each
row is non-vacuous against the break its own route can suffer.

The rows also assert `rownames()` and not row counts alone, so a helper that
keeps the right number of wrong rows fails. That is the failure a count-only
regression row would miss.

The other half of the removal's premise — that a non-logical column can no longer
reach this helper — is proved in PR 1 by blocks E.3 and E.4, which assert
`surveycore_error_domain_not_logical` at the write. PR 5 correctly does not
restate it, and it rewrote the two older comments in the same file that still
credited `as.logical()` for the claim.

**4. Forward coupling to PR 6.** Row 4.4 is safe. Nothing in this PR or in #276
undermines it.

The printed domain line comes from `.print_domain_info()` in
`R/methods-print.R:170-185`. On a two-phase design it reads `x@data`, masks it
with `x@data[[x@variables$subset]]`, and counts `TRUE` markers among those rows
with `na.rm = TRUE`. It builds no `survey` package object, so `method` is
invisible to it: `approx` and `full` print the same line. #276 lives entirely on
the conversion side.

Row 4.4's stated premise also holds. `make_domain_pair()` sets
`stored[outside_phase2[1L]] <- TRUE`, so at least one in-domain row sits outside
phase 2, and the two counting routes give different numbers — 52 of 74 phase-2
rows, against 149 of 200 for the whole-sample route. `na.rm = TRUE` means design
A and design B print the identical line, which is the second half of the row.

Two small things to hand PR 6's builder, neither a defect:

- The literal is `Domain: {n} of {N} Phase 2 rows` for a two-phase design and
  `Domain: {n} of {N} row{?s}` otherwise, and `n` passes through `{.val }`.
  Criterion 1 already says to assert the numbers and write no snapshot.
- `make_domain_pair()` writes `NA` into three rows, where `test-spec.md`
  §Fixture helpers describes one. The helper is PR 4's shipped work, and PR 6 may
  not edit it. Rows 4.x derive their counts from `mask`, so three `NA` rows change
  no expectation. PR 5's rows 5.2 and 5.4 handle it the same way, by asserting
  that every `NA` row is absent.

## Decision

Every check is clean: five spec rows claimed and delivered, all eight acceptance
criteria met, a write surface of exactly the two planned files, exact comparisons
throughout with no tolerance touched, seven profile gates green, coverage flat at
96.15% with no uncovered new line, and a cookbook table that reads None under a
PASS audit. The one deviation from the plan text — row 5.3's expected count — is
D25's documented correction of a defective test-spec preamble, and it tightens the
assertion rather than relaxing it. The shipping tree differs from the gated tree
by two comment lines, and the equivalence argument above covers that gap.

PASS.
