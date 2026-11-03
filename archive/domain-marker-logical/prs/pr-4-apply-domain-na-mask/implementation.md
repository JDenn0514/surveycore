# Implementation — PR 4 — apply-domain-na-mask

**Branch**: `fix/apply-domain-na-mask`
**Base sha verified**: `8664d86f6e0f5d302d1db7a2baf4be663e380fa1`
**Commit**: `09d97e3` (supersedes `3ab6318`; see §BLOCK 1 resolution)
**Tree**: `7bd2712a3248840dd69bf7a8a6bc1b38eb1ac079` (supersedes `939c70e`)

The worktree opened on `d4d1db2fe2de42243213d30c5bb56639906494b4`, a stale
`main` commit. `git fetch origin && git reset --hard 8664d86...` put it on the
required base. `R/core-classes.R` at that base carries the domain-marker
validator at lines 348-362, so PRs 1-3 are in.

## Write surface

- `R/analysis-helpers.R` — modified
- `tests/testthat/helper-test-data.R` — modified
- `tests/testthat/test-analysis-helpers.R` — modified
- `NEWS.md` — modified

No other path is in the commit. One side effect of the test runs was reverted
before the commit: 30 files under `tests/testthat/_snaps/` picked up
line-ending churn from `devtools::test()`, which is the known `_snaps/`
line-ending behaviour. `git status` on the commit shows the four files above
and nothing else.

## Summary

- `.apply_domain()` writes `FALSE` in place of every `NA` in the stored marker
  column. It adds no coercion — the `survey_base` validator from PR 1
  guarantees the column is logical. The column-absent branch is untouched.
- The `@return` text now states the post-change contract: a logical vector of
  length `nrow(design@data)` holding no `NA`, `TRUE` for in-domain rows and
  `FALSE` for a row whose stored marker is `FALSE` or `NA`. The block also
  records why the resolution matters.
- `make_domain_pair(class, seed)` in `helper-test-data.R` builds two designs
  from one data frame and one marker vector: `a` stores three `NA` markers,
  `b` stores `FALSE` in those three places, and `mask` is the resolved vector.
  All four concrete classes build. The `"twophase"` variant marks 97 in-domain
  rows that phase 2 excludes, so at least one `TRUE` marker sits outside
  phase 2.
- Nine new blocks in `test-analysis-helpers.R`, under a new heading
  "Category 16": six invariance blocks (`get_means()`, `get_totals()`,
  `get_freqs()`, `get_quantiles()`, `get_ratios()`, `get_corr()`), one grouped
  `get_means()` block, one all-`NA` block, and the zero-row contract block.
  No new `test_invariants()` call.
- One `NEWS.md` entry under `## Bug fixes` in the development version, naming
  issue #262.

## Red to green evidence

### Task 2 — the six invariance blocks

Before the fix, `devtools::load_all(); testthat::test_file(...)` reported all
six as errors, not as numeric disagreements. The `NA` element reaches an
arithmetic sum, and each function then tests an `NA` in an `if`:

```
-- 3. Error ('test-analysis-helpers.R:1826:3'): get_means() reads an NA marker ...
Error in `if (n_d == 0L || N_d <= 0) { ... }`: missing value where TRUE/FALSE needed
  5. +-surveycore::get_means(pair$a, y1)
  6.   +-surveycore:::.mean_cell(design, x_name, domain)
  7.     +-surveycore:::.taylor_mean_cell(design, y_col, domain)

-- 4. Error (...:1831:3): get_totals()    -- same condition
-- 5. Error (...:1836:3): get_freqs()     -- .taylor_freq_cell()
-- 6. Error (...:1841:3): get_quantiles() -- if (n_d_combo > 0L && n_d_combo < min_cell_n)
-- 7. Error (...:1849:3): get_ratios()    -- if (n_cell > 0L && n_cell < min_cell_n)
-- 8. Error (...:1857:3): get_corr()      -- if (n_d < 2L || W_d <= 0) in .vcov_pair_taylor()
```

After the fix all six pass.

### Task 3 — the grouped case

The plan predicted a phantom group row. The observed failure on the current
tree is harder than that: the call does not return at all.

```
-- 9. Error ('test-analysis-helpers.R:1865:3'): a grouped get_means() on an NA marker
Error in `if (n_d == 0L || N_d <= 0) { ... }`: missing value where TRUE/FALSE needed
  1. +-surveycore::get_means(pair$a, y1, group = group)
```

An interactive run on the same fixture shows the reach of the defect: the
`FALSE`-marker design returns three group rows (`n = 45, 59, 44`), and the
`NA`-marker design returns nothing, because `.taylor_mean_cell()` aborts on the
phantom row's `NA` count. After the fix the grouped call returns the three real
levels, carries no `NA` group, and `sum(result$n)` equals `sum(pair$mask)`.

### Task 4 — the all-NA case

```
-- 10. Error ('test-analysis-helpers.R:1879:3'): an all-NA marker names the same ...
Error in `if (n_d == 0L || N_d <= 0) { ... }`: missing value where TRUE/FALSE needed
  1. +-surveycore::get_means(design_na, y1)
```

After the fix the all-`NA` result matches the all-`FALSE` result column by
column, and `n` is `0L`.

### Task 5 — the zero-row contract row

This row passes on the current tree, before the fix. It is a contract row, not
a failing-first row, as the plan says. A zero-row slice of the marker column is
already `logical(0)`, and `logical(0)[is.na(logical(0))] <- FALSE` leaves it
`logical(0)`, so the row holds on both sides of the change.

## Final `.apply_domain()` body

```r
.apply_domain <- function(design) {
  if (SURVEYCORE_DOMAIN_COL %in% names(design@data)) {
    stored <- design@data[[SURVEYCORE_DOMAIN_COL]]
    stored[is.na(stored)] <- FALSE
    stored
  } else {
    rep(TRUE, nrow(design@data))
  }
}
```

Sub-assignment, not `stored & !is.na(stored)`. Sub-assignment changes the three
`NA` elements and nothing else, so a marker column carrying a `label`
attribute — legal under the spec's edge-case table — returns with that
attribute intact, exactly as the old body returned it.

## Gate 13

Command: `grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R`

```
R/analysis-helpers.R
R/analysis-t-test.R
R/glm-anova.R
```

Three files, as the criterion requires.

## Test runs

Final targeted run, `devtools::test(filter = 'analysis-helpers', reporter = 'summary')`:

```
analysis-helpers: ...............................................................................................................................................................................................................................................W..W..........................................................................
```

No Failed section. The two `W` marks are the pre-existing AAPOR small-cell
warnings at `test-analysis-helpers.R:1475` and `:1498`.

Wider runs, for the record:

- The 14 test files that name `SURVEYCORE_DOMAIN_COL` or `set_domain_marker()`
  ran together: no failure.
- One full `devtools::test()` run: exit 0, no Failed section, 256 warnings, all
  of them the pre-existing AAPOR small-cell warning that clean `develop` also
  emits.

`devtools::document()` ran. `NAMESPACE` did not move — `.apply_domain()` is
`@noRd`, and no `man/*.Rd` file changed.

## Task checklist

- [x] 1. `make_domain_pair(class, seed)` added to `helper-test-data.R`;
      returns `a`, `b`, `mask`; builds `"taylor"`, `"replicate"`,
      `"twophase"`, `"nonprob"`; the `"twophase"` variant marks rows outside
      phase 2.
- [x] 2. Six invariance blocks written, run red, recorded.
- [x] 3. Grouped `get_means()` block written, run red, recorded.
- [x] 4. All-`NA` block written, run red, recorded.
- [x] 5. Zero-row contract block written; passes on the pre-fix tree.
- [x] 6. `.apply_domain()` resolves `NA` to `FALSE`; no coercion; the
      column-absent branch is unchanged.
- [x] 7. `@return` rewritten to the post-change contract.
- [x] 8. All nine blocks pass. No new `test_invariants()` call.
- [x] 9. One `NEWS.md` entry under `## Bug fixes`, naming #262.

## Signals raised

None. No HOLD.

## Notes for tester

- `make_domain_pair()` builds a 200-row design (`n_psu = 10`, `n_strata = 2`)
  and marks about 74% of rows in-domain, so no cell in the six blocks falls
  under `min_cell_n = 30` and no AAPOR warning fires from the new blocks. A
  grouped call on the `"twophase"` variant does cross that floor — its
  in-domain phase-2 cells hold 19, 17 and 16 rows.
- The six blocks and the all-`NA` block compare through a local helper,
  `expect_domain_invariance()`, defined in the same file above them. Its body
  is one `expect_identical()` on `names()` and one `expect_identical()` per
  column, with `info = nm`. It never compares two result objects whole: the
  `.meta` attribute records the call that built each result, so two results
  from two designs can never match as objects even when every number agrees.
- `tests/testthat/helper-test-data.R` fails `air format --check` on this
  branch, and did so at the base commit too. The offending block is
  `.hand_polyserial_twostep()` near line 1562, which this PR does not touch.
  Running `air format` on the file reformats only that block. That reformat was
  reverted, per the rule that a reformat-only change stays in its own commit.
  The code this PR adds is air-clean.
- Running the suite rewrites the line endings of every file under
  `tests/testthat/_snaps/`. Those rewrites are reverted in this commit and are
  not a change this PR makes.

## BLOCK 1 resolution

A replacement builder made two scoped corrections in the main checkout, on
top of `3ab6318`. `R/analysis-helpers.R`, `tests/testthat/helper-test-data.R`
and `NEWS.md` did not move — `git status --porcelain R/` printed nothing at
every step. Only `tests/testthat/test-analysis-helpers.R` changed.

### Deleted

The four out-of-scope invariance blocks: `get_totals()`, `get_freqs()`,
`get_ratios()`, `get_corr()`. Each reads the row mask through the same
one-line `.apply_domain()` call as `get_means()` and holds no `NA`-sensitive
logic of its own, so none reaches a path `get_means()` does not reach. No
evidence appeared for keeping any of the four.

### Changed

`get_means()` and `get_quantiles()` now run **grouped by `group`**. Grouping
is the case the PR exists for: an ungrouped call cannot produce the phantom
group combination. Both keep `expect_domain_invariance()` and the
column-by-column form; only the call changed.

### Added

Four blocks, all column by column through `expect_domain_invariance()`:

- `get_diffs(y1, treats = group)`
- `get_t_test(y1, by = arm)` — `arm` is a two-level factor built inside the
  block from `group` and written to both designs' `@data`
- `get_pairwise(y1, by = group)`
- `survey_glm(y1 ~ y2)` — compares `summary(fit)$coefficients` as a data
  frame, column by column, plus one `expect_identical()` on the row names

One local helper, `with_factor_group(pair)`, sits beside
`expect_domain_invariance()`. `get_diffs()` and `get_pairwise()` coerce a
character column to a factor and warn when they do; the helper hands both
designs the factor already, so the two blocks read one fixed level order and
raise no incidental warning. The `get_t_test()` block builds its factor
inline for the same reason.

Block count stays at nine. No new `test_invariants()` call.

### Red to green evidence for the four added blocks

`.apply_domain()` was replaced in the loaded namespace with its pre-fix body
(`assignInNamespace()`); `R/` was never edited. All four blocks failed:

```
### get_diffs:    RED -- variable lengths differ (found for '(weights)')
### get_t_test:   RED -- variable lengths differ (found for '(weights)')
### get_pairwise: RED -- variable lengths differ (found for '(weights)')
### survey_glm:   RED -- variable lengths differ (found for '(weights)')
```

The `NA` marker elements index `design@data` to `NA` rows, so the model frame
and the weight vector disagree in length and the fit aborts. With the shipped
`.apply_domain()` all four pass.

### Test run

`devtools::load_all(); testthat::test_file("tests/testthat/test-analysis-helpers.R", reporter = "summary")`

All nine Category 16 blocks pass. Two warnings, both pre-existing AAPOR
small-cell warnings at `:1475` and `:1498`; the new blocks add none.

Two failures appear in this run, at `:1429` and `:1430`, in
`print.survey_result() outputs header with class and dims`. They are an
artifact of `devtools::load_all()`, not of this PR. The block is untouched by
both builders, and a one-line probe outside the test suite reproduces it: under
`load_all()` the result prints as a plain tibble, so `survey_means` never
appears in the output. The prior builder's `devtools::test(filter = ...)` run
on the same tree reported no failure.

### Formatting

`air format --check tests/testthat/test-analysis-helpers.R` passes.

### Commit

- Commit: `09d97e32618cfc3aa53ef906a302edbdfa924cb6`
- Tree: `7bd2712a3248840dd69bf7a8a6bc1b38eb1ac079`
