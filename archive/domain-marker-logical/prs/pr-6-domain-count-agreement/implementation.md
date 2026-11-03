# Implementation — PR 6 — test/domain-count-agreement

**Branch**: `test/domain-count-agreement`
**Commit**: `ce0c89d63ca4417a3d1fb975e69a54359e7651b8`
**Tree**: `40117b04b851f4b3c6b3fd4d44f364a0a5f796ec`
**Base verified**: `a578b46a66358a2846e8c8adaf7ea4bcd868e9fc`

## Base sha

The worktree opened on `d4d1db2fe2de42243213d30c5bb56639906494b4`, a stale
commit, exactly as the brief warned. I ran `git fetch origin` and
`git reset --hard a578b46a66358a2846e8c8adaf7ea4bcd868e9fc`, then confirmed
`git rev-parse HEAD` returns the base sha.

All four preconditions are present on that base:

| Precondition | Evidence |
|---|---|
| The domain-marker validator | `R/core-classes.R:352` — `# ── Domain marker column must be logical ──` |
| `.apply_domain()` resolves `NA` | `R/analysis-helpers.R:493` — `stored[is.na(stored)] <- FALSE` |
| No `as.logical()` in `.restrict_to_domain()` | `grep as.logical R/methods-conversion.R` returns one comment line (64) and no call |
| `make_domain_pair()` | `tests/testthat/helper-test-data.R:1159` |

## Write surface

- `tests/testthat/test-methods-print.R` — modified (append-only, +69 lines)
- `tests/testthat/test-analysis-helpers.R` — modified (append-only, +73 lines)

`git diff --name-only a578b46a66358a2846e8c8adaf7ea4bcd868e9fc HEAD`:

```
tests/testthat/test-analysis-helpers.R
tests/testthat/test-methods-print.R
```

Nothing under `R/`, nothing under `man/`, no `NAMESPACE` change, and
`tests/testthat/helper-test-data.R` is untouched — `make_domain_pair()` is
read, not edited. `tests/testthat/_snaps/` gains no entry: a test run dirtied
`tests/testthat/_snaps/analysis-helpers.md` with line-ending churn, and I
reverted that file with `git checkout --` before staging. `git status` is
clean apart from the two files above.

## Summary

- Four blocks in `test-methods-print.R` (section 57) read the printed domain
  line back and assert on the two numbers in it. Two local readers do the
  work: `domain_line()` strips ANSI from the message stream and keeps the one
  line starting `Domain: `; `domain_counts()` parses `n` and `total` out of
  it with `regexec()`. Neither writes a snapshot.
- The Taylor blocks cover scenarios 1 to 3: the line reports 148 TRUE markers
  over 200 rows; that 148 is identical under `expect_identical()` to the `n`
  column of an ungrouped `get_means(pair$a, y1)` (both `integer`); and design
  `b`, which stores the same marker with `NA` written as `FALSE`, prints a
  byte-identical line.
- The two-phase block covers scenario 4. It asserts the phase-2 mask holds no
  `NA`, asserts the in-domain-and-in-phase-2 count is strictly smaller than
  the whole-sample in-domain count (so a line counting the whole sample would
  fail), then pins both numbers and the `a`/`b` identity.
- Four blocks in `test-analysis-helpers.R` (category 17) cover scenarios 5 to
  8 on a Taylor design straight from `as_survey()` with no marker column at
  all: ungrouped `get_means()` reports `n` equal to `nrow(design@data)`;
  grouped `get_means()` gives one row per level of `group` and its `n` sums
  to the row count; the printed output holds no line starting `Domain: `; and
  assigning a data frame with no marker column to `@data` raises no
  condition.
- Neither file gains a `test_invariants()` call.

## Measurements

### The two-phase precondition holds

Measured on this tree with `make_domain_pair("twophase")`:

| Quantity | Measured |
|---|---|
| Rows in the design | 200 |
| In-domain markers overall | 149 |
| In-domain markers inside phase 2 | 52 |
| Phase-2 rows | 74 |
| Printed line, design `a` | `Domain: 52 of 74 Phase 2 rows` |
| Printed line, design `b` | `Domain: 52 of 74 Phase 2 rows` |

This agrees with the brief's figures — 52 against 149 on 200 rows. The row is
meaningful: 97 in-domain rows sit outside phase 2, so a line that counted the
whole sample would report 149, not 52.

Taylor fixture, for the record: 148 TRUE markers over 200 rows; printed line
`Domain: 148 of 200 rows`; `get_means(pair$a, y1)$n` is `148L`.

### The print blocks would have failed before #275

I re-measured by rebinding `.apply_domain()` in the loaded namespace to its
pre-#275 body, taken from `git show b2fa7e1^:R/analysis-helpers.R`:

```r
.apply_domain <- function(design) {
  if (SURVEYCORE_DOMAIN_COL %in% names(design@data)) {
    design@data[[SURVEYCORE_DOMAIN_COL]]
  } else {
    rep(TRUE, nrow(design@data))
  }
}
```

`get_means(pair$a, y1)` under that body does not return a wrong number. It
aborts:

```
PRE-275 get_means ERRORED: missing value where TRUE/FALSE needed
```

So the count-agreement block (scenario 2) could not have passed before #275 —
the fixture's marker holds three `NA` values, and the pre-#275 helper handed
them to the indexing path. The three `NA` markers also mean design `a` and
design `b` were not one design before #275, so scenario 3 rested on nothing.

## Test runs

Both runs are `Rscript -e 'devtools::load_all(); testthat::test_file(...)'`
in the foreground. No `devtools::check()`, `covr`, `run_examples()` or full
`devtools::test()` ran.

| File | Blocks | Pass | Fail | Error | Skip | Warn |
|---|---|---|---|---|---|---|
| `test-methods-print.R` | 125 | 383 | 0 | 0 | 43 | 0 |
| `test-analysis-helpers.R` | 141 | 340 | 2 | 0 | 8 | 2 |

The four new print blocks carry 3, 2, 2 and 6 expectations and none is
skipped. The four new helper blocks carry 2, 3, 2 and 3 expectations and none
is skipped.

`air format --check` exits 0 on both files.

## Task checklist

- [x] 1. The first group of print blocks, fixture from `make_domain_pair()`,
      asserting on the numbers in the printed line and not on a whole-method
      snapshot.
- [x] 2. The count-agreement block as its own block, `expect_identical()`.
- [x] 3. The two-phase block: phase-2 counts only, and design `b` identical.
- [x] 4. Print blocks run; they pass on this tree and could not have passed
      before #275 (see Measurements).
- [x] 5. The no-marker group in `test-analysis-helpers.R`.
- [x] 6. They run and pass. No new `test_invariants()` call in either file.

## Signals raised

None. No HOLD.

## Notes for tester

- **Two failures in `test-analysis-helpers.R` are pre-existing on the base
  and are not mine.** They sit in the block
  `print.survey_result() outputs header with class and dims` at lines 1429
  and 1430 — `any(grepl("survey_means", out))` and `any(grepl("×", out))`
  both return `FALSE`. I proved they predate this PR: I copied my version
  aside, ran `git checkout --` on the file, and re-ran the base file. Base
  reads 137 blocks / 330 pass / 2 fail; my version reads 141 blocks / 340
  pass / 2 fail. Same two failures, +4 blocks, +10 passing expectations. The
  block reads a tibble header out of `capture.output()`, so the cause looks
  like a console-width or unicode setting in this shell, not a code defect.
- The two warnings the helper file reports are the pre-existing AAPOR
  small-cell warnings in blocks at lines 1475 and 1498. My blocks raise none.
- `domain_line()` and `domain_counts()` sit at the end of
  `test-methods-print.R`, after `capture_design_output()` at line 979, so
  they can reuse it. `test-analysis-helpers.R` cannot: a function defined in
  one test file is not visible in another, so that file carries a four-line
  `capture_cli_lines()` of its own. Editing `helper-test-data.R` to share one
  copy was outside this PR's write surface.
- The print method writes the domain line to the **message** stream
  (`cli::cli_text()`), not to stdout. A reader capturing `type = "output"`
  gets an empty result.
- Scenario 4 is unaffected by issue #276. `make_domain_pair("twophase")`
  builds `method = "approx"`, and `.restrict_to_domain()` does not restrict
  such a design, but the print method reads `x@data` and `x@variables$subset`
  directly and never builds a `survey` object, so `method` is invisible to
  it.
