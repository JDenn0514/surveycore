# surveycore Testing: Package-Specific Standards

**Version:** 1.2
**Status:** Decided — extends `testing-standards.md`; read that first. This
file covers only what is specific to surveycore.

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checks | `test_invariants(design)` once per constructor per test FILE — not per block |
| Both input modes | A behavioural row runs in both modes only when the mode changes what it asserts |
| Oracle tests against `survey` | Never hand `survey` a number surveycore computed; assert the SE. Rules 2 and 3 and the per-type table apply to `svrepdesign()` only |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot |
| Layer 3 errors (constructors) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Variance numerical tolerance | Point: 1e-10, SE/variance: 1e-8, CI bounds: 1e-6 |
| Synthetic data | `make_survey_data(seed = N)` in `helper-test-data.R` |
| Real data | `nhanes_2017`, `acs_pums_wy` for numerical validation only |

## Two speeds of local test run

11 files carry a file-level `skip_on_cran()`, including the two polychoric
files that hold 42% of all test time. Skipping them halves the run.

`devtools::test()` cannot reach the fast speed. It calls
`withr::local_envvar(devtools:::r_env_vars())`, and that list sets
`NOT_CRAN = "true"` unconditionally, so the shell variable never reaches the
tests and the 11 files always run. Use `testthat::test_local()` for the fast
run — it reads the real environment.

| Run | Command | Expectations | Time | Use for |
|---|---|---|---|---|
| Fast | `NOT_CRAN=false Rscript -e "testthat::test_local()"` | fewer (skips 11 files) | shorter | The edit-run loop. Skips the 11 slow files. |
| Full | `Rscript -e "devtools::test()"` | all | longer | Before any push or PR. Runs everything. |

Both counts grow with every PR that adds tests — do not record exact
expectation totals or run times here; they go stale within a few merges
(issue #215). If you need current numbers, run the commands above.

Always measure coverage with `NOT_CRAN=true`. `covr` does not set the
variable, so without it the 11 files skip and coverage reads several
points lower than the true figure (issue #159). The 95% CI floor
(`testing-standards.md`) is the number that matters and does not drift.

## File mapping

Core source-to-test mapping. Analysis files (`R/analysis-*.R`) follow the
same one-to-one convention — `R/analysis-means.R` →
`tests/testthat/test-analysis-means.R`, etc.

| Source file | Test file |
|-------------|-----------|
| `R/core-classes.R` | `tests/testthat/test-s7-classes.R` |
| `R/core-metadata.R` | `tests/testthat/test-metadata-system.R` |
| `R/core-validators.R` | `tests/testthat/test-validators.R` |
| `R/core-constructors.R` | `tests/testthat/test-constructors.R` |
| `R/methods-print.R` | `tests/testthat/test-methods-print.R` |
| `R/methods-conversion.R` | `tests/testthat/test-conversion.R` |
| `R/variance-taylor.R` | `tests/testthat/test-variance-taylor.R` |
| `R/variance-replicate.R` | `tests/testthat/test-variance-replicate.R` |
| `R/variance-twophase.R` | `tests/testthat/test-variance-twophase.R` |
| `R/utils.R` | `tests/testthat/test-utils.R` |
| `R/update-design.R` | `tests/testthat/test-update-design.R` |

## `test_invariants()` — once per constructor per file

Each test FILE calls `test_invariants(design)` once for each constructor it
exercises — `as_survey()`, `as_survey_rep()`, `as_survey_twophase()`,
`as_survey_nonprob()` — in the first block that builds with it. Later blocks
in the same file do not repeat it.

Measured rationale (issue #169): the per-block rule produced 645 calls and
about 10,300 expectations — 53% of the suite — and stubbing it out moved
package coverage by 0.0000 points across all 46 files in `R/`. The S7
validators in `R/core-classes.R` enforce the same invariants on construction
and on every property assignment, and no code in `R/` bypasses them.

The helper still earns one call per constructor per file: it is the only
guard against a constructor returning a malformed object through a route the
validators do not see. `tests/testthat/test-invariants.R` keeps proving the
helper still fires.

`test_invariants()` is defined in `tests/testthat/helper-test-data.R` — read
it there for the current source. It asserts all five formal Phase 0
invariants:

1. `@data` is a data.frame
2. `@data` has >= 1 row
3. All `@variables` keys are present (never absent, may be `NULL`)
4. Named design columns exist in `@data`
5. `@metadata` is a `survey_metadata` object

## The both-modes rule — run the second mode when it changes the answer

Some surveycore functions take either a survey design object or a plain data
frame. `extract_dataset_metadata()`, `set_dataset_metadata()` and the ten
dataset-metadata wrappers are the whole current set.

Write the second mode when the mode changes what the row asserts. Skip it
when the row's answer is fixed before the function looks at `x`.

Run the row in **both** modes when it asserts:

- a value read back out of storage — a survey object keeps dataset metadata
  in `@metadata@dataset_metadata`, a data frame keeps it in one whole-object
  attribute per key, so a round trip is a different act in each mode;
- a state left behind after the call, including "the call wrote nothing";
- anything that depends on state already stored, such as the field-date pair
  check against a stored `field_end`;
- behaviour that exists in one mode only — the legacy `dates` attribute, the
  frame reader's silent drops, promotion at construction.

Run the row in **one** mode when the function raises before it reads `x`.
Every argument check in `extract_dataset_metadata()` fires before
`.get_dataset_metadata_list(x)`, and every rule 1–11 check in
`set_dataset_metadata()` fires before the same call. A frame variant of such
a row runs the identical lines with the identical arguments and cannot
disagree with the survey variant.

Keep the second mode where it already exists. This rule sets the bar for new
test rows; it is not a reason to delete passing tests. The measurement below
says the whole rule is too cheap to be worth that churn.

### Measured rationale (issue #169, step 2)

The rule was never written down repo-wide. It appeared in exactly one
test-spec — `archive/dataset-level-metadata/` §3 "Mode default" — and the
tests it produced sit almost entirely in one file.

Issue #169 called it "the other 2x multiplier". It is not one:

| Measure | Count |
|---|---|
| Mode-variant blocks in `test-dataset-metadata.R` | 102 |
| Expectations they carry | 132 |
| Share of the 9,847-expectation suite | 1.3% |
| Mode-variant blocks in every other test file | 0 |

Deleting all 102 and re-measuring:

| Run | R/ expressions reached | Package coverage |
|---|---|---|
| Baseline | 698 | 96.0938% |
| All 102 mode variants deleted | 698 | 96.0938% |

Identical expression sets, not just identical totals. Two instruments agree:
`covr::package_coverage(type = "none")` scoped to that one test file, so no
other file could mask a loss, and a full `covr::package_coverage()` run,
which held every one of the 46 per-file figures unchanged. The frame branches
stay covered because the frame-only rows keep reaching them.

`test-metadata-system.R` already works this way. It gives each of the twelve
variable-level metadata functions one data-frame block — the read path, the
write path — and runs everything else once. That file is the house norm; the
one that fans out every row is the exception.

Line coverage proves the second mode reaches no new code. It does not prove
it could never catch a regression, and the property that makes it redundant —
every abort preceding the mode branch — is a fact about today's source that
nothing enforces. At 1.3% of the suite the guard is worth more than the
saving, so the rows stay.

Measured 2026-08-27 on `develop` at `e7493f0`.

## The oracle rule — never hand `survey` a number surveycore computed

An oracle test compares a surveycore result against `survey`. It proves
something only when the two sides reach their numbers independently. Five
rules follow.

**Which rules reach which design.** Rules 1, 4 and 5 hold for every oracle
test against `survey`, whatever the design class. Rules 2 and 3 and the
per-type table below name arguments of `survey::svrepdesign()`, so they reach
replicate designs only. An author writing a Taylor or two-phase oracle applies
rules 1, 4 and 5 and reads rules 2 and 3 as the principle behind them: pass
the other side no number this side computed.

1. **Build both sides from the same inputs.** Same data frame, same weight
   column, same replicate columns, same `type`, same `mse`. Pass `mse`
   explicitly to both sides.
2. **Pass `scale` to neither side.** `survey::svrepdesign()` honours a
   supplied `scale` for JK1, JKn, bootstrap and `other`, so a block that
   passes surveycore's default in gets the same number back out. The
   comparison then cannot disagree, and a wrong default stays green. This is
   how issue #242 survived 22 releases. Read this rule with the scope
   paragraph at the end: a round-trip test is not an oracle test, and rule 2
   does not reach it.
3. **Pass `rscales` to JKn only.** `survey` refuses JKn with combined weights
   and no `rscales`. Pass the same literal to both sides. Never read `rscales`
   off the surveycore design. `survey` discards a supplied `rscales` for JK2,
   ACS and successive-difference, so a block that supplies it there gets a
   warning in place of a comparison.
4. **Assert the standard error, not the point estimate alone.** The scale
   enters the variance only. A design with a wrong scale returns the same
   point estimate, so a block that asserts the point estimate alone reports
   green on a wrong default. Assert the confidence bounds too; they inherit
   the error.
5. **Assert the condition `survey` raises. Do not silence it.** A warning from
   `svrepdesign()` is the test telling you `survey` computed the value itself.
   `suppressWarnings()` round an oracle call hides that.

Three further constraints follow from the first five.

- **Never assert one side's stored scale against the other side's.** Assert
  each against a literal. An assertion that compares the two sides to each
  other is the same round trip in a different shape.
- **A formula forbidden as an argument is still allowed as an assertion
  literal.** The two acts differ. Passing `(R-1)/R` into `svrepdesign()` sets
  the number the other side computes with, which is the round trip. Writing
  `(R-1)/R` in an `expect_equal()` states what the block claims the number is,
  and the block turns red when the number moves. So the same formula may be
  banned from a constructor call and required in an assertion in the same
  block. JK1 is the worked case.
- **Match `survey`'s conditions by message text, not by class.** Every
  condition in `svrepdesign()` is a bare `warning()` or `stop()`, so the only
  class is `simpleWarning` or `simpleError`. That class also matches the
  "Data do not look like combined weights" warning, which means the fixture is
  broken rather than that the comparison held. The message text names the
  branch; the class does not. The missing `class =` here is a property of
  `survey`, and it breaches neither house rule that could be read to require
  one. `.claude/rules/code-style.md` governs surveycore's own
  `cli::cli_abort()` and `cli::cli_warn()` calls; an oracle block writes none.
  `.claude/rules/testing-standards.md` §Assertions requires `class =` on every
  `expect_warning()`; it governs surveycore's own typed conditions, and
  `survey` supplies no class to name.

Rule 4's confidence-bound clause carries one precondition. **Both sides must
build the interval from the same distribution and the same degrees of
freedom.** They do today, and both use the normal approximation.
`survey`'s `confint()` methods for `svrepstat` and `svystat` default to
`df = Inf`, and `survey:::tconfint` takes its critical value from `qt()` at
that df, which returns the normal one. surveycore assigns `degf <- Inf`
unconditionally in each Phase 1 analysis file, and the replicate path reaches
`.degf()` through none of them. Assert the bounds only while both statements
hold. A change to degrees of freedom on either side moves every bound and
leaves the point estimate and the standard error intact — the same shape a
wrong scale produces, from a different cause.

A later PR that moves surveycore's replicate path to design-based degrees of
freedom must revisit `tests/testthat/test-variance-replicate.R` in the same
PR. Every confidence-bound assertion in the block set fails at once when it
lands, and the failure reads as a scale defect unless the reader knows this
clause.

## S7 error testing layers

- **Layer 1 — S7 class validators** (`R/00-s7-classes.R`): structural
  invariants; messages not CLI-formatted. Test with `class=` only.
- **Layer 3 — Constructor input validation** (`R/03-constructors.R`):
  user-facing `cli::cli_abort()` errors. Test with the dual pattern
  (`class=` + snapshot).

## `make_survey_data()` — synthetic data generator

Defined in `tests/testthat/helper-test-data.R`; use for all unit tests that
need a survey design object.

```r
make_survey_data <- function(
  n           = 500,    # total rows
  n_psu       = 50,     # number of PSUs
  n_strata    = 5,      # number of strata
  design      = c("taylor", "replicate", "twophase"),
  type        = "BRR",  # replicate type when design = "replicate"
  with_labels = FALSE,  # attach haven-style label attributes
  seed        = 42
) { ... }
```

Data properties: PSU sizes vary (Poisson), weights vary (lognormal), strata
sizes imbalanced. Returns a plain `data.frame` with columns `psu`, `strata`,
`fpc`, `wt`, `y1`, `y2`, `y3`; replicate designs add `repwt_1`...`repwt_R`.

**Data policy:**

| Test type | Data source |
|-----------|-------------|
| Unit tests (class, properties, error conditions) | `make_survey_data()` |
| Numerical accuracy vs. `survey` package | `nhanes_2017`, `acs_pums_wy` |
| Label/metadata roundtrip tests | `make_survey_data(with_labels = TRUE)` |

## Variance estimation numerical tolerances

Tests in `test-variance-estimation.R` compare surveycore estimates against
the `survey` package.

| Estimand | Tolerance |
|----------|-----------|
| Point estimates (mean, total, proportion) | `1e-10` |
| SE / variance | `1e-8` |
| CI bounds | `1e-6` |

Packages requiring `skip_if_not_installed()`:
- `survey` — numerical comparison tests in `test-variance-estimation.R`
- `srvyr` — conversion roundtrip tests in `test-conversion.R`
- `haven` — metadata roundtrip tests (prefer `with_labels = TRUE` when possible)

---
Worked examples (where the invariants call goes, layer examples, numerical
comparison, test-file section templates):
`.claude/references/testing-detail.md`. Read it when writing a new
surveycore test file.
