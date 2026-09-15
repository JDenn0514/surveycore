# Review — PR 3 — test/domain-marker-type-breadth

**Verdict**: PASS
**Date**: 2026-09-14
**Tree**: `f98e160b2c2c16df948abd28b06343c761f960e3`
**Commit**: `a830880` on `test/domain-marker-type-breadth`, base `a5b88c2`

Scope reviewed: `test-spec.md` §1 rows 1.5–1.11 and §2 rows 2.4–2.8 (twelve
rows). Rows 1.1–1.4 and E.1–E.4 shipped in PR 1; rows 2.1–2.3 and 2.9 shipped
in PR 2; §3–§6 belong to PRs 4–6. None of those is reported missing here.

## Convergence checks

- Spec coverage: **y**. Each of the twelve rows maps to one named block in
  `tests/testthat/test-s7-classes.R`, and `audit.md`'s per-row table names a
  line for each. Every edge case `spec.md` §Function contracts §Edge cases
  assigns to this PR is present: the zero-row `logical(0)` accept and
  `integer(0)` reject pair, the attribute-carrying column, the generic type
  check over double, character, factor and list, the constructor route, and
  the rejected write that leaves nothing behind.
- Test coverage of spec: **y**. Every contract item has a test-spec row
  somewhere in the plan. Two observations under §Cross-consistency, neither a
  gap in this PR's scope.
- Tolerance integrity: **y**. `test-spec.md` §Tolerances puts sections 1 and 2
  outside the tolerance table — they assert classes and structure. Every
  assertion in the twelve blocks is `expect_error(class = )`,
  `expect_no_error(class = )`, `expect_identical()`, `expect_true()` or
  `expect_false()`. No tolerance was invented, applied or relaxed.
  `expect_identical()` on a character label, a `logical(0)` column, an integer
  row count and an integer `NA` count follows `testing-standards.md`.
- Scope discipline: **y**. `git diff --stat a5b88c2..HEAD` returns one path,
  `tests/testthat/test-s7-classes.R`, +132/−1. That equals the plan's PR 3
  §Files touched. `tests/testthat/helper-test-data.R` appears in no diff, so
  `set_domain_marker()` is read only. `tests/testthat/_snaps/` gains no entry
  and holds no reference to `surveycore_error_domain_not_logical`. The
  `test_invariants()` grep count is 7 at `a5b88c2` and 7 at `HEAD` — six calls
  plus one description string, unchanged, as plan criterion 7 asks.
- Regression safety: **y**. FAIL 0, WARN 256 (flat), SKIP 4 (flat), PASS
  11805 → 11825. The +20 reconciles exactly, see finding 2. No test outside
  this PR's scope changed state.

## Findings

**1. No `R/` change is committed on this branch, verified from git and not
from the three reports.** The branch carries one commit above `origin/develop`,
`a830880`, and `git show --name-only` on it lists one path,
`tests/testthat/test-s7-classes.R`. Walking every commit from `8fe3fa2`
confirms the only `R/` change in the arc's history is PR 1's `5b05a8c`, which
is merged. `git show HEAD:R/core-classes.R` holds the live validator body: the
name-lookup early return, then
`if (!is.logical(self@data[[SURVEYCORE_DOMAIN_COL]]))` raising
`surveycore_error_domain_not_logical`, with no commented-out line and no
`if (FALSE)`. The vacuity probe left no trace in the shipped tree. The working
tree agrees (`git status --porcelain` shows only the four untracked plan files
and `plans/pr-budget-calibration.md`), but the committed content is what
ships, and it is clean.

**2. The 13-failure probe count reconciles to named expectations, which is
what makes it evidence.** Two reports agreeing adds little on its own: both
probes ran on the same tree, disabled the same `if` the same way, and ran the
same file, so they share every assumption. The count is checkable
independently, and it checks out. With the reject branch disabled, exactly
these expectations flip: rows 1.1–1.4 (one each, four — out of scope but in
the same file), rows 1.5–1.8 (four), rows 1.9 and 1.10 (two), row 1.11 (two —
its `expect_error()` and its `expect_false()`, because a successful write
leaves the column present), and row 2.7 (one). 4+4+2+2+1 = 13, with nothing
left over and no accept row among them. That is the full set of reject
expectations in the file, so 13 is the right number and not merely a matching
number. Row 1.11's second failure is the useful detail: the rollback assertion
is itself non-vacuous.

**3. The four row-specific observables are genuinely asserted, read from the
diff.**

| Row | Observable | Assertion in the block |
|---|---|---|
| 1.11 | The data holds no marker column after the failed write | `expect_false(SURVEYCORE_DOMAIN_COL %in% names(design@data))` — absence, not equality with an old value |
| 2.5 | The `label` attribute survives | `expect_identical(attr(stored, "label", exact = TRUE), "Inside active domain")`, plus `expect_true(is.logical(stored))` |
| 2.8 | The design's own subset column is untouched | `before <- design@data[[design@variables$subset]]` captured before the write, then `expect_identical(marked@data[[subset_var]], before)`; the marker column is checked separately by its `NA` count. The subset column is read by name from `@variables$subset`, the same key `R/analysis-helpers.R` and four other source files use, so the block distinguishes the two columns correctly |
| 2.6 / 2.7 | `logical(0)` accepts, `integer(0)` rejects | Both build the frame inline as `design@data[0L, , drop = FALSE]`; 2.6 asserts `expect_identical(marked@data[[COL]], logical(0))` and `nrow == 0L`, 2.7 asserts the named class only, as `test-spec.md` §2 requires for a zero-row design |

`set_domain_marker()`'s default mask is
`rep(c(TRUE, FALSE), length.out = nrow(design@data))`, which is `logical(0)` on
a zero-row frame and `integer(0)` after the helper's `as.integer()`. The pair
therefore reaches the two shapes with no new helper argument, as
`testing-standards.md` requires for edge-case data.

**4. Rows 1.9 and 1.10 exercise the constructor route, not an assignment.**
Both build a plain `df` from `make_survey_data()`, write
`df[[SURVEYCORE_DOMAIN_COL]] <- rep(c(1L, 0L), length.out = nrow(df))`, and
then wrap the constructor call itself — `as_survey(df, ids = psu, weights = wt,
strata = strata, fpc = fpc, nest = TRUE)` and
`as_survey_nonprob(df, weights = wt)`. No design object is built first. That is
the spec's edge case "a data frame that already carries a non-logical marker,
passed to a constructor": no Layer 3 check reads this column, so the Layer 1
error is what the caller sees, and both blocks pass.

**5. §2 reads 2.1 to 2.9 ascending, and the single deletion is the seam.**
Block order in the file: no-`NA` (2.1), one `NA` (2.2), all `NA` (2.3),
replicate all `NA` (2.4), `label` attribute (2.5), `logical(0)` (2.6),
`integer(0)` (2.7), two-phase (2.8), `haven_labelled` (2.9). The diff's only
deleted line is
`# PR 3 inserts rows 2.4-2.8 here, between row 2.3 above and row 2.9 below.`,
the marker PR 2 left. Nothing else was removed.

**6. `expect_no_error(..., class = )` is targeted — confirmed against the
installed source, not the audit's word.** `testthat 3.3.2`'s `expect_no_()`
builds `cnd_matcher(base_class = "error", class = class)` and calls `fail()`
only when a caught condition matches both. The 256 pre-existing AAPOR warnings
cannot fail these blocks, and an unrelated error propagates rather than turning
into a silent pass. This matches `test-spec.md` §2's instruction to assert the
absence of the named class and not the absence of every condition.

**7. Gates and coverage.** All seven profile gates carry a result and none was
skipped — `--skip-pkgdown` was not used, so `r-package-profile.md`'s pkgdown
skip condition does not apply. `R CMD check --as-cran` reports the same two
NOTEs before and after (`CRAN incoming feasibility`, pre-approved by
`r-package-conventions.md`; the pre-existing `.git` hidden-file note, which
`.Rbuildignore` causes and which this PR cannot touch). No new NOTE pattern, so
no escalation. Coverage is 96.14% before and after, flat and above the 95%
floor, with no drop and therefore no HOLD condition in the 95–98% band. This PR
adds zero lines under `R/`, so no new line's coverage can have dropped. [[D21]]
explains why the validator closure reads uncovered at all; [[D22]] explains the
gate log's "changed R/ files: 1" column, and `git diff --name-only
a5b88c2..HEAD` independently gives zero `R/` files. The CRAN cookbook table
reads "None", consistent with a PASS audit.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every fact I can check against the
tree: the write surface and its +132/−1, the block line numbers (1836, 1844,
1852, 1860, 1868, 1884, 1893, 1941, 1951, 1967, 1980, 1989, with 2.9 at 2003),
the probe's 13 failures, the untouched helper, the empty `_snaps/` delta, and
the invariant count. Two immaterial differences:

- `audit.md` §Non-vacuity probe and §Assertion-form check call the in-scope
  accept rows "five". They are four — 2.4, 2.5, 2.6 and 2.8. The audit's
  per-row table lists the correct twelve, and its acceptance-criteria mapping
  is right, so this is a narration slip and not a coverage claim.
- `implementation.md` reports row 2.7 failing "at line 1983" where `audit.md`
  places the block at 1980. Those are the failing expectation and the block
  head; they agree.

Two observations on `test-spec.md`, recorded for the arc rather than charged to
this PR:

- `spec.md` §Edge cases states that a one-column logical matrix passes, with an
  explicit instruction not to reject the matrix shape. No test-spec row builds
  one. `test-spec.md` §2 sets its own bar — "one accept row per branch of the
  check" — and a matrix takes the same branch as row 2.1, so this is inside the
  plan's stated coverage rule rather than outside it. No package code writes
  such a column.
- The same table names an ordered factor, a complex vector and a raw vector.
  Row 1.7 writes an unordered factor. The spec's own claim there is that the
  check is generic, and rows 1.5–1.8 prove genericity over four storage types.

Neither observation reaches this PR's twelve rows, and neither changes the
verdict.

## Decision

All twelve in-scope rows are present, each in its own block, each asserting the
form `test-spec.md` requires, and all twelve pass. The +20 expectation delta
reconciles row by row to exactly the assertions added, so no block skipped. The
probe count of 13 reconciles to the full set of reject expectations in the
file, which makes it evidence rather than a coincidence between two reports.
The validator body at the branch tip is intact and the branch's only commit
touches one test file, so nothing dangerous was left behind by the vacuity
check. The write surface equals the plan's single file, the helper and the
snapshots are untouched, and the seven profile gates each carry a clean result
with coverage flat above the floor. **PASS.**
