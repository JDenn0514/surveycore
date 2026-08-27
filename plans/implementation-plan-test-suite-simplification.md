# Test Suite Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the test suite's expectation count by about half with no loss of line coverage, close issue #161, and find out where the wall-time actually goes before trying to cut it.

**Closes:** #161 (Task 1). Acts on step 1 of #169.

**Architecture:** Bloat and slowness live in different files, so this plan treats them as two separate problems. Phase 1 removes repeated assertions that buy no coverage. Phase 2 attacks the small number of numerically expensive tests that dominate wall-time. Phase 0 removes a line-ending problem that makes every "is the tree clean?" check unreliable.

**Tech Stack:** R, testthat 3rd edition, covr, devtools, S7.

## Measured baseline

Every number below was measured on `test/investigate-test-count-inflation`
at `f01b73f`, with `NOT_CRAN=true`. Re-measure before trusting them again.

| Measure | Value |
|---|---|
| Package line coverage | 96.0938% |
| Passing expectations | 19,314 |
| `test_that()` blocks | 3,478 |
| Sum of test time | 806.3 s |
| `devtools::test()` wall-time | 14.25 min |
| `test_invariants()` runtime calls | 645 |
| `test_invariants()` expectations | about 10,300 (53% of the suite) |

### Finding 1 - the bloat buys no coverage

`test_invariants()` (`tests/testthat/helper-test-data.R:569-735`) holds 27
assertions and runs 645 times. Replacing it with a no-op changed package
coverage by **0.0000 points**, and not one of the 46 files in `R/` lost a
single line. The S7 validators in `R/core-classes.R` already enforce the
same invariants on construction and on every property assignment, and no
code in `R/` bypasses them through `attr()` or `unclass()`.

Note the limit of this evidence: line coverage measures whether code
**runs**, not whether results are **correct**. The experiment proves these
assertions reach no new code. It does not prove they could never catch a
regression. That is why this plan narrows the rule instead of deleting it.

### Finding 2 - the bloat is not the slowness

Time and expectation count are inversely related here:

| File | Time | Share | Expectations | Expectations/sec |
|---|---|---|---|---|
| `test-analysis-corr-latent.R` | 293.5 s | 36.4% | 126 | 0.4 |
| `test-analysis-corr-latent-variance.R` | 47.4 s | 5.9% | 86 | 1.8 |
| `test-dataset-metadata.R` | 70.6 s | 8.8% | 4,254 | 60.3 |
| `test-constructors.R` | 47.5 s | 5.9% | 2,549 | 53.7 |

Two polychoric files take **42.3%** of all test time while holding **1.1%**
of the expectations. The file with the most expectations is 140 times more
time-efficient than the slowest file.

**Consequence:** Phase 1 delivers legibility, not speed. Phase 2 delivers
speed. Do not expect either to deliver the other, and do not report Phase 1
as a performance improvement.

## Global Constraints

- Package line coverage must not fall below **95%**, and should not fall
  from 96.0938% at all. Measure with `NOT_CRAN=true` (issue #159).
- Never loosen a numerical tolerance to make a smaller fixture pass. Point
  estimates 1e-10, SE/variance 1e-8, CI bounds 1e-6, `polycor` parity 1e-6.
  If a shrunk fixture misses tolerance, keep the original fixture.
- Feature branches cut from `develop` and merge back to `develop`.
- Conventional Commits: `test:`, `chore:`, `docs:`, `refactor:`.
- Run `air::format_package()` before opening a PR.
- Do not delete `tests/testthat/test-invariants.R`. Those 6 meta-tests are
  what keep `test_invariants()` itself honest.

## File Structure

| File | Responsibility | Phase |
|---|---|---|
| `.gitattributes` | Stop CRLF rewrites of snapshot files | 0 |
| `tests/testthat/test-*.R` | Drop surplus `test_invariants()` calls | 1 |
| `.claude/rules/testing-surveycore.md` | Record the narrowed rule | 1 |
| `tests/testthat/test-analysis-corr-latent.R` | Share polychoric fixtures | 2 |
| `tests/testthat/test-analysis-corr-latent-variance.R` | Share polychoric fixtures | 2 |
| `.claude/rules/testing-surveycore.md` | Two-speed local workflow | 2 |

---

## Phase 0 - Housekeeping

### Task 1: Stop snapshot files churning on every test run

**Closes issue #161.**

Running the suite rewrites all 38 `tests/testthat/_snaps/*.md` files with
CRLF endings and **zero** content change. This is why a checkout sits dirty
after any test run, and it makes "the tree is clean" meaningless as a gate.
Issue #161 records the wider cost: any `git add -A` after a test run commits
the churn, and the pipeline's scoped snapshot guard reads it as a violation
until someone checks `numstat` and sees `0 0`.

**Correction to issue #161 - the stated blocker does not exist.** The issue
says to do this only when no feature branch is open, because a renormalize
commit would rewrite ~38 files and collide with feature PRs. Measured on
this branch: `git add --renormalize tests/testthat/_snaps/` stages
**0 files**. The index blobs are already LF - `git ls-files --eol` reports
`i/lf` for every snapshot. There is no 38-file commit, this task never
touches `_snaps/`, and it can land at any time. Update #161 to say so.

Two further details confirmed here:

- `_snaps/` is flat - 38 `.md` files, no subdirectories, no other file
  types - so the issue's `_snaps/*.md` glob is sufficient.
- Root cause context: `core.autocrlf = true` in the local git config, with
  `.gitattributes` carrying only `*.sh text eol=lf` from #157. The explicit
  rule makes the behaviour deterministic rather than dependent on that
  setting.

**Files:**
- Modify: `.gitattributes`

**Interfaces:**
- Produces: a repository where `git status` after a test run is empty, so
  later tasks can use a clean tree as a real signal.

- [ ] **Step 1: Confirm the churn is line endings only**

Run:

    Rscript -e "devtools::test()" > /dev/null 2>&1
    git diff --stat tests/testthat/_snaps/ | tail -1
    git diff --ignore-cr-at-eol --numstat tests/testthat/_snaps/ | wc -l

Expected: the first command reports about 38 changed files; the second
reports `0`. Zero means no content changed.

- [ ] **Step 2: Inspect the current .gitattributes**

Run:

    cat .gitattributes

- [ ] **Step 3: Add snapshot normalization**

Append to `.gitattributes`:

    # testthat snapshots are written LF and must stay LF, or every test run
    # shows all of _snaps/ as modified with no content change. (issue #161)
    tests/testthat/_snaps/*.md text eol=lf

- [ ] **Step 4: Renormalize and confirm it stages nothing**

Run:

    git checkout -- tests/testthat/_snaps/
    git add --renormalize tests/testthat/_snaps/
    git diff --cached --numstat | wc -l

Expected: `0`. The index is already LF, so renormalize is a no-op. This is
the step that proves issue #161's "wait for a quiet moment" constraint does
not apply. A non-zero count here means the premise changed - stop and
re-read #161 before committing.

- [ ] **Step 5: Prove the fix**

Run:

    Rscript -e "devtools::test()" > /dev/null 2>&1
    git status --porcelain tests/testthat/_snaps/ | wc -l

Expected: `0`. Before the fix this was 38.

- [ ] **Step 6: Commit**

Run:

    git add .gitattributes
    git commit -m "chore: keep testthat snapshots LF so test runs stop dirtying the tree (#161)"

- [ ] **Step 7: Update issue #161**

Post a comment recording that `git add --renormalize` stages 0 files
because the index is already LF, so the "do this only when no feature
branch is open" constraint does not apply. Then close it with the PR.

---

## Phase 1 - Remove assertions that buy no coverage

### Task 2: Narrow test_invariants() to one call per constructor per file

560 blocks call `test_invariants()`. The narrowed rule keeps the **first**
block in each file for each constructor it exercises, and drops the call
from the rest. Expect roughly 80-120 surviving calls, down from 645.

Three blocks must keep their call regardless, because deleting it would
leave them with no expectation at all:

- `test-s7-classes.R` - "survey_nonprob validator accepts single positive weight among zeros"
- `test-s7-classes.R` - "survey_nonprob validator accepts mix of zeros and NAs with one positive"
- `test-update-design.R` - "update_design() validate=TRUE result passes test_invariants()"

**Files:**
- Modify: `tests/testthat/test-*.R` (about 20 files carry calls)
- Do not modify: `tests/testthat/helper-test-data.R`, `tests/testthat/test-invariants.R`

**Interfaces:**
- Consumes: a clean tree from Task 1.
- Produces: `test_invariants()` unchanged in signature and behaviour, simply
  called from fewer places. `tests/testthat/test-invariants.R` keeps working
  untouched.

- [ ] **Step 1: Record the before numbers**

Run:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('passed:', sum(r\$passed), 'failed:', sum(r\$failed), 'time:', round(sum(r\$real),1), 's\n')"

Expected: `passed: 19314 failed: 0 time: 806.3 s` (small drift is fine).
Write the numbers down; Step 6 compares against them.

- [ ] **Step 2: Write the rewrite script**

Create `data-raw/narrow-invariants.R`. It parses each test file, decides
which blocks keep the call, and rewrites the rest. It edits by line number
from the parse data, so it never disturbs surrounding code.

```r
# One-shot maintenance script for the test_invariants() narrowing.
# Keeps the first block per (file, constructor); strips the call elsewhere.
dir <- "tests/testthat"
files <- list.files(dir, pattern = "^test-.*[.]R$", full.names = TRUE)

KEEP_ALWAYS <- c(
  "survey_nonprob validator accepts single positive weight among zeros",
  "survey_nonprob validator accepts mix of zeros and NAs with one positive",
  "update_design() validate=TRUE result passes test_invariants()"
)
CONSTRUCTORS <- c(
  "as_survey", "as_survey_rep", "as_survey_twophase", "as_survey_nonprob"
)

fn_names <- function(e) {
  out <- character(0)
  rec <- function(x) {
    if (is.call(x)) {
      f <- x[[1L]]
      if (is.name(f)) out <<- c(out, as.character(f))
      for (i in seq_along(x)) {
        if (!is.null(x[[i]])) try(rec(x[[i]]), silent = TRUE)
      }
    }
  }
  try(rec(e), silent = TRUE)
  out
}

total_removed <- 0L
for (f in files) {
  if (basename(f) == "test-invariants.R") next
  lines <- readLines(f)
  ex <- tryCatch(parse(f, keep.source = TRUE), error = function(e) NULL)
  if (is.null(ex)) next

  seen <- character(0)
  drop <- integer(0)
  for (i in seq_along(ex)) {
    e <- ex[[i]]
    if (!is.call(e) || !identical(as.character(e[[1L]])[1L], "test_that")) {
      next
    }
    nm <- tryCatch(as.character(e[[2L]])[1L], error = function(x) "")
    fns <- fn_names(e)
    if (!("test_invariants" %in% fns)) next
    if (nm %in% KEEP_ALWAYS) next

    ctor <- intersect(CONSTRUCTORS, fns)
    key <- if (length(ctor) == 0L) "none" else ctor[1L]
    if (!(key %in% seen)) {
      # First block for this constructor in this file: keep the call.
      seen <- c(seen, key)
      next
    }
    # Later block: strip the call.
    sr <- attr(ex, "srcref")[[i]]
    rng <- sr[1L]:sr[3L]
    hit <- rng[grepl("^[[:space:]]*test_invariants[(]", lines[rng])]
    drop <- c(drop, hit)
  }
  if (length(drop)) {
    writeLines(lines[-drop], f)
    total_removed <- total_removed + length(drop)
    cat(sprintf("%-42s removed %d\n", basename(f), length(drop)))
  }
}
cat("TOTAL REMOVED:", total_removed, "\n")
```

- [ ] **Step 3: Run it**

Run:

    Rscript data-raw/narrow-invariants.R

Expected: a per-file tally and a total in the 450-560 range.

- [ ] **Step 4: Check no block was emptied**

Run:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('failed:', sum(r\$failed), 'skipped:', sum(r\$skipped), '\n')"

Expected: `failed: 0`. `skipped` must stay at 4. A rise in `skipped` means a
block lost its last expectation - restore that one call by hand.

- [ ] **Step 5: Confirm coverage did not move**

Run:

    NOT_CRAN=true Rscript -e "cat(covr::percent_coverage(covr::package_coverage()), '\n')"

Expected: `96.0938`. **This is the gate.** Any drop means a call was
reaching code nothing else does; restore calls until coverage returns.

- [ ] **Step 6: Record the after numbers**

Run:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('passed:', sum(r\$passed), 'time:', round(sum(r\$real),1), 's\n')"

Expected: roughly 9,000-11,000 passing expectations, down from 19,314. Time
should be near 806 s - unchanged. That is the correct result, not a failure.

- [ ] **Step 7: Delete the one-shot script and commit**

Run:

    rm data-raw/narrow-invariants.R
    air format .
    git add -A
    git commit -m "test: narrow test_invariants() to one call per constructor per file"

### Task 3: Update the rule that mandated the old behaviour

The rule in `.claude/rules/testing-surveycore.md` requires the call in every
constructing block. Leaving it unchanged guarantees the calls grow back.

**Files:**
- Modify: `.claude/rules/testing-surveycore.md`

**Interfaces:**
- Consumes: the narrowed suite from Task 2.

- [ ] **Step 1: Find the current wording**

Run:

    grep -n "test_invariants" .claude/rules/testing-surveycore.md

- [ ] **Step 2: Replace the Quick Reference row**

Old:

    | Invariant checks | `test_invariants(design)` required as **first** assertion in every constructor test block |

New:

    | Invariant checks | `test_invariants(design)` once per constructor per test FILE - not per block |

- [ ] **Step 3: Replace the section body**

Replace the `test_invariants() - required in every constructor test`
section with:

```markdown
## `test_invariants()` - once per constructor per file

Each test FILE calls `test_invariants(design)` once for each constructor it
exercises - `as_survey()`, `as_survey_rep()`, `as_survey_twophase()`,
`as_survey_nonprob()` - in the first block that builds with it. Later blocks
in the same file do not repeat it.

Measured rationale (issue #169): the per-block rule produced 645 calls and
about 10,300 expectations - 53% of the suite - and stubbing it out moved
package coverage by 0.0000 points across all 46 files in `R/`. The S7
validators in `R/core-classes.R` enforce the same invariants on construction
and on every property assignment, and no code in `R/` bypasses them.

The helper still earns one call per constructor per file: it is the only
guard against a constructor returning a malformed object through a route the
validators do not see. `tests/testthat/test-invariants.R` keeps proving the
helper still fires.
```

- [ ] **Step 4: Commit**

Run:

    git add .claude/rules/testing-surveycore.md
    git commit -m "docs: narrow the test_invariants() rule to one call per constructor per file"

---

## Phase 2 - Cut wall-time where it actually goes

### Task 4: Find out whether the polychoric implementation is the bottleneck

**This task replaces an earlier "share polychoric fixtures" task, which was
checked and found void.** All 25 `make_latent_taylor()` calls in
`test-analysis-corr-latent.R` use a **different seed** - 11, 40, 41, 42, 43,
60 through 160 - so no two blocks share a fixture. The distinct seeds look
deliberate: each block tests a different data realization, so a pass is not
an artefact of one draw. Sharing would reduce test independence and save
nothing, because the expensive step re-runs per block regardless.

The expensive step is `get_corr(method = "polychoric")` - the
maximum-likelihood fit - not fixture construction. That raises a sharper
question: **33 seconds for one polychoric fit at `n = 300` is very slow.**
`polycor::polychor()` on a 6x7 table that size normally returns in well
under a second. If surveycore's `.corr_polychoric_mle()` is the reason, the
fix belongs in `R/`, not in the tests - and it would speed up every user
call to `get_corr(method = "polychoric")`, not just the suite.

Settle that before touching any test.

**Files:**
- Read only: `R/analysis-corr.R`, `R/analysis-corr-helpers.R`
- Create if the hypothesis holds: a new issue describing the slow path

**Interfaces:**
- Produces: a decision. Either Phase 2 stays a test-shrinking exercise
  (Task 5), or it becomes an implementation-performance issue that dwarfs it.

- [ ] **Step 1: Benchmark surveycore against polycor on identical data**

Run with nothing else competing for CPU:

```r
library(surveycore)
set.seed(87L)
n <- 300L
df <- data.frame(
  id = 1:n,
  wt = 1,
  o1 = factor(sample(1:6, n, replace = TRUE), levels = 1:6, ordered = TRUE),
  o2 = factor(sample(1:7, n, replace = TRUE), levels = 1:7, ordered = TRUE)
)
d <- as_survey(df, weights = wt)

t_sc <- system.time(
  r <- get_corr(d, x = c(o1, o2), method = "polychoric")
)[["elapsed"]]
t_pc <- system.time(
  oracle <- polycor::polychor(df$o1, df$o2)
)[["elapsed"]]

cat("surveycore:", round(t_sc, 2), "s\n")
cat("polycor:   ", round(t_pc, 2), "s\n")
cat("ratio:     ", round(t_sc / max(t_pc, 1e-3), 1), "x\n")
cat("estimates: ", r$r[[1L]], "vs", oracle, "\n")
```

- [ ] **Step 2: Decide from the ratio**

- **Ratio under about 3x:** polychoric fitting is simply expensive at this
  table size. Keep Phase 2 as written - go to Task 5 and shrink the fixture.
- **Ratio above about 10x:** the implementation is the bottleneck. Stop
  here. Open an issue against `R/analysis-corr.R` with these numbers, and
  treat Task 5 as a small interim measure rather than the fix.

#### RESULT - measured 2026-08-26, on a quiet CPU

**The implementation is the bottleneck, by two orders of magnitude.**

| Fixture | surveycore | `polycor` | Ratio |
|---|---|---|---|
| 6x7 table, n = 300 (the 33 s block) | 36.09 s | 0.22 s | **164x** |
| 3x3 table, n = 200 (control) | 4.39 s | 0.03 s | **146x** |

The estimates agree to 6.4e-12, so this is purely a speed defect, not a
correctness one. The ratio holds at both table sizes, so it is a constant
factor in the implementation - not a scaling effect of wide tables.

Profile of the 6x7 fit, by self-time:

| Entry | self % | total % |
|---|---|---|
| `pbivnorm::pbivnorm` | 16.8 | 84.3 |
| `replace` | 13.7 | 13.7 |
| `unique` | 11.4 | 14.4 |
| `simplify2array` | 8.7 | 28.4 |
| `.corr_bivnorm_cdf` | 7.8 | 94.0 |
| `.corr_polychoric_loglik` | 4.6 | 93.5 |

Only about 17% of the time is the actual numerical work. The rest is R-level
plumbing around it.

**Root cause.** `.corr_bivnorm_cdf()` (`R/analysis-corr-latent.R:340`) is
scalar-only - its `if (is.na(a) || is.na(b) || ...)` guards require length-1
input. `.corr_polychoric_loglik()` (`R/analysis-corr-latent.R:395-418`) calls
it four times per cell inside a nested `for` loop over `k_x` by `k_y` cells.

For a 6x7 table that is 42 cells x 4 calls = **168 separate scalar calls into
`pbivnorm`'s Fortran routine per log-likelihood evaluation**, and the
optimiser evaluates the likelihood many times per fit. `pbivnorm` is
vectorised - it is built to take whole vectors in one call.

**The fix, for the separate PR.** The four calls per cell only ever read from
the `(k_x + 1)` by `(k_y + 1)` grid of threshold pairs - 56 distinct values
for a 6x7 table, not 168. Evaluate that whole grid in **one** vectorised
`pbivnorm` call per `rho`, then form each cell probability by differencing
four entries of the resulting matrix. That removes both the repeated Fortran
entry cost and the redundant recomputation, since each threshold pair is
currently recomputed by up to four neighbouring cells.

The same loop appears a second time at `R/analysis-corr-latent.R:709-712`.
Fix both, or extract one shared helper.

**Filed as issue #177.** That issue carries the benchmark, the profile, the
root cause, and the suggested vectorisation, along with the tolerances any
fix must hold.

**Consequence for this plan:** Task 5 is now a small interim measure, not the
fix. Do not spend effort shrinking test fixtures to work around a defect that
belongs in `R/`. If #177 lands first, re-measure before doing Task 5 at all -
it may become unnecessary.

- [ ] **Step 3: If the implementation is slow, profile the hot path**

```r
Rprof(tmp <- tempfile(), interval = 0.01)
invisible(get_corr(d, x = c(o1, o2), method = "polychoric"))
Rprof(NULL)
print(head(summaryRprof(tmp)$by.self, 15))
```

Record the top self-time entries in the new issue. Likely suspects are a
per-cell loop, repeated `pmvnorm`-style bivariate normal integration, or a
threshold search that re-derives values it already has.

- [ ] **Step 4: Do not change `R/` under this plan**

This plan's write surface is tests and rules. If Step 2 says the
implementation is at fault, that is a separate PR with its own numerical
tolerances to protect. Record it and move on to Task 5.

### Task 5: Shrink the two slowest polychoric cases

Two blocks cost 66 s between them. Polychoric fitting scales with table size
and row count, so a smaller table is much cheaper. Shrink only where the
property under test survives at the same tolerance.

**Files:**
- Modify: `tests/testthat/test-analysis-corr-latent.R`

**Interfaces:**
- Consumes: the shared fixtures from Task 4.

- [ ] **Step 1: Read the two blocks**

Run:

    grep -n "6x7 ordinal pair runs without error" -A 25 tests/testthat/test-analysis-corr-latent.R
    grep -n "matches polycor on 4x5 equal wt" -A 25 tests/testthat/test-analysis-corr-latent.R

- [ ] **Step 2: Shrink the 6x7 block only**

Only one of the two is safe to touch. This was checked:

| Block | Time | Verdict |
|---|---|---|
| 6x7 ordinal pair (line 623) | 33.1 s | **Shrinkable.** Asserts only `expect_no_error()` and `is.finite()`. Nothing pins the table size. |
| 4x5 `polycor` parity (line 179) | 32.9 s | **Leave alone.** Its comment pins the fixture to a spec fixture - `rho = -0.3, n = 800, k_x = 4, k_y = 5, seed = 2` - matching PR 1's primitives test at 1e-6. Shrinking breaks a documented link to the spec. |

Halving Phase 2's headline saving is the correct outcome here. Do not
"recover" it by shrinking the parity fixture.

- [ ] **Step 3: Shrink the 6x7 case**

The block at `tests/testthat/test-analysis-corr-latent.R:623` builds its own
frame inline. Reduce the level counts:

```r
# before
o1 = factor(sample(1:6, n, replace = TRUE), levels = 1:6, ordered = TRUE),
o2 = factor(sample(1:7, n, replace = TRUE), levels = 1:7, ordered = TRUE)

# after - 5x6 exercises the same wide-table path for fewer threshold
# parameters. This block asserts "runs without error", not a table size.
o1 = factor(sample(1:5, n, replace = TRUE), levels = 1:5, ordered = TRUE),
o2 = factor(sample(1:6, n, replace = TRUE), levels = 1:6, ordered = TRUE)
```

If that is not enough, reduce `n <- 300L` as well. Nothing in the block
depends on the row count either.

- [ ] **Step 4: Re-run and compare**

Run:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test(filter = 'analysis-corr-latent')); cat('failed:', sum(r\$failed), 'TOTAL:', round(sum(r\$real),1), 's\n')"

Expected: `failed: 0` and a total below Task 4's. If the shrunk case fails,
restore the original size - the size mattered after all.

- [ ] **Step 5: Confirm full-suite coverage is untouched**

Run:

    NOT_CRAN=true Rscript -e "cat(covr::percent_coverage(covr::package_coverage()), '\n')"

Expected: `96.0938`.

- [ ] **Step 6: Commit**

Run:

    air format .
    git add tests/testthat/test-analysis-corr-latent.R
    git commit -m "test(analysis): shrink the widest polychoric fixtures to cut fit time"

### Task 6: Write down the two-speed local workflow

11 test files carry a file-level `skip_on_cran()`, including both polychoric
files. So `NOT_CRAN=true` runs everything (806 s) and a plain run skips
those files (about 400 s). That is already a 2x lever, available today at no
risk - it just is not written down anywhere.

**Files:**
- Modify: `.claude/rules/testing-surveycore.md`

- [ ] **Step 1: Confirm the two speeds**

Run:

    Rscript -e "r <- as.data.frame(devtools::test()); cat('plain - passed:', sum(r\$passed), 'skipped:', sum(r\$skipped), 'time:', round(sum(r\$real),1), 's\n')"
    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('NOT_CRAN - passed:', sum(r\$passed), 'skipped:', sum(r\$skipped), 'time:', round(sum(r\$real),1), 's\n')"

Expected: the plain run is roughly half the time with far more skips.

- [ ] **Step 2: Add the section**

```markdown
## Two speeds of local test run

11 files carry a file-level `skip_on_cran()`, including the two polychoric
files that hold 42% of all test time.

| Run | Command | Use for |
|---|---|---|
| Fast | `devtools::test()` | The edit-run loop. Skips the 11 slow files. |
| Full | `NOT_CRAN=true devtools::test()` | Before any push or PR. Runs everything. |

Always measure coverage with `NOT_CRAN=true`. Without it, the 11 files skip
and coverage reads about 93.7% instead of about 96.1% (issue #159).
```

- [ ] **Step 3: Commit**

Run:

    git add .claude/rules/testing-surveycore.md
    git commit -m "docs: record the fast and full local test workflows"

---

---

## Phase 3 - Close the loop on the issues

### Task 7: Report back on #169 and #161

Do this **after** Tasks 2, 3 and 6 are committed, so the comment describes
work that exists rather than work that is planned.

#169 does **not** get closed by this plan. It asks for four investigation
steps; this plan answers step 1 and deliberately leaves step 2 unmeasured.
Left alone, the issue keeps its stale figures - "6 assertions", "about 18% of
the expectation count" - and keeps asking for an experiment that has already
run. The cost of that is someone spending a 20-minute coverage pass to
re-derive a known answer.

**Files:**
- No files. This task posts comments and closes one issue.

**Interfaces:**
- Consumes: the measured after-numbers from Task 2 Step 6 and Task 6 Step 1.

- [ ] **Step 1: Collect the real after-numbers**

Do not copy the predictions from this plan. Read the actual values:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('passed:', sum(r\$passed), 'failed:', sum(r\$failed), 'skipped:', sum(r\$skipped), 'time:', round(sum(r\$real),1), 's\n')"
    NOT_CRAN=true Rscript -e "cat(covr::percent_coverage(covr::package_coverage()), '\n')"

- [ ] **Step 2: Comment on #169**

Substitute the bracketed values with what Step 1 actually printed.

```markdown
## Step 1 is done - here is what it measured

**The figures in the issue body are stale.** `test_invariants()` now holds
**27** assertions, not 6, spanning `helper-test-data.R:569-735`. It runs
**645** times, not 588 - some call sites sit inside helpers that run
repeatedly.

So its real contribution is about **10,300 expectations, 53% of the suite** -
roughly three times the ~18% the issue estimates.

**It buys no coverage.** Replacing it with a no-op and re-running `covr`:

| Run | Coverage |
|---|---|
| Baseline | 96.0938% |
| `test_invariants()` stubbed | 96.0938% |
| Difference | **0.0000 points** |

Identical to four decimal places, and not one of the 46 files in `R/` lost a
line. The S7 validators in `R/core-classes.R` already enforce the same
invariants on construction and on every property assignment, and nothing in
`R/` bypasses them via `attr()` or `unclass()`.

Caveat worth keeping: line coverage measures whether code **runs**, not
whether results are **correct**. This proves the assertions reach no new
code. It does not prove they could never catch a regression. That is why the
rule was narrowed rather than deleted.

## What changed

- `test_invariants()` is now called once per constructor per test file, not
  per block. Expectations fell from 19,314 to [ACTUAL PASSED].
- `.claude/rules/testing-surveycore.md` records the narrowed rule and the
  two-speed local test workflow.
- Coverage held at [ACTUAL COVERAGE]%.
- Runtime is [ACTUAL TIME]s, essentially unchanged - see below.

## The headline assumption in this issue was wrong

The issue reasons that trimming expectations would buy legibility but not
speed. That is correct, and understated: **bloat and wall-time live in
different files entirely.**

| File | Time | Share | Expectations |
|---|---|---|---|
| `test-analysis-corr-latent.R` | 293.5 s | 36.4% | 126 |
| `test-analysis-corr-latent-variance.R` | 47.4 s | 5.9% | 86 |
| `test-dataset-metadata.R` | 70.6 s | 8.8% | 4,254 |

Two polychoric files take **42% of all test time** for **1.1%** of the
expectations. Chasing the expectation count for speed would have been the
wrong lever entirely.

That led to **#177**: `get_corr(method = "polychoric")` is about 164x slower
than `polycor::polychor()`, because `.corr_bivnorm_cdf()` is scalar-only and
gets called four times per cell inside a nested loop. That is a defect in
`R/`, and fixing it is worth roughly ten times every test edit here.

## Still open on this issue

1. **Step 2 - the both-modes rule. Not measured.** It is the other 2x
   multiplier. It needs its own stub-and-measure experiment, exactly like
   the one above. Trimming it on suspicion would repeat the mistake this
   issue was raised to avoid.
2. **Step 3 - the dual pattern. Deliberately left alone.**
   `expect_error(class = )` and `expect_snapshot(error = TRUE)` test
   different things - the condition class and the rendered message - and
   snapshots have caught message regressions in this repo before. The 522
   snapshot calls stay.
3. **Separate concern:** `test-dataset-metadata.R` holds 4,254 expectations,
   22% of the suite, in one 4,277-line file. Worth its own issue.

Keeping this open for step 2.
```

- [ ] **Step 3: Close #161 once the fix is on develop**

The `.gitattributes` fix is verified but sits on a feature branch. Close
#161 only after the PR merges, so the tracker never claims a fix that is not
on `develop`.

    gh issue close 161 --comment "Fixed on develop. A full test run now leaves 0 snapshot files modified, down from 38."

- [ ] **Step 4: No commit**

This task changes no files. Nothing to commit.

## Final verification

- [ ] **Full suite passes**

Run:

    NOT_CRAN=true Rscript -e "r <- as.data.frame(devtools::test()); cat('failed:', sum(r\$failed), 'skipped:', sum(r\$skipped), 'passed:', sum(r\$passed), 'time:', round(sum(r\$real),1), 's\n')"

Expected: `failed: 0`, `skipped: 4`.

- [ ] **Coverage held**

Run:

    NOT_CRAN=true Rscript -e "cat(covr::percent_coverage(covr::package_coverage()), '\n')"

Expected: `96.0938`, and never below the 95% floor.

- [ ] **Tree is clean after a test run** (proves Task 1)

Run:

    git status --porcelain | wc -l

Expected: `0`.

- [ ] **R CMD check clean**

Run:

    Rscript -e "devtools::check()"

Expected: 0 errors, 0 warnings, at most 2 pre-approved notes.

## Expected outcome

| Measure | Before | Target | Confidence |
|---|---|---|---|
| Passing expectations | 19,314 | about 9,000-11,000 | High - measured |
| Coverage | 96.0938% | 96.0938% - unchanged | High - measured |
| Dirty files after a run | 38 | 0 | High - measured |
| Fast-loop time | not documented | about 400 s | High - measured |
| Full-suite time | 806 s | about 770 s from Task 5 alone | Low - see below |

The expectation drop comes entirely from Phase 1 and buys legibility, not
speed. Report the two separately.

**Phase 2's saving is now much smaller than first drafted, and honest about
it.** The original plan assumed shared fixtures (void - every seed differs)
and assumed both 33-second blocks could shrink (only one can - the other is
pinned to a spec fixture). What remains under this plan's write surface is
one block worth about 33 s, so roughly 806 s becomes roughly 770 s.

**Task 4 has now run, and the answer is issue #177.** The polychoric fit is
164x slower than `polycor` because of scalar `pbivnorm` calls in a nested
loop. The two latent files hold 341 s of the 806 s suite. Fixing #177 is
worth roughly ten times every test edit in this plan combined, and it speeds
up user calls to `get_corr(method = "polychoric")` as well.

So the speed ranking is:

1. **#177** - up to about 341 s, in a separate PR against `R/`.
2. **Task 6** - about 400 s off the edit-run loop, no code change, available
   today.
3. **Task 5** - about 33 s, and possibly unnecessary once #177 lands.

## Deliberately not in this plan

Issue #169 lists four investigation steps. This plan acts on step 1 and
leaves two others alone, on purpose:

- **The both-modes rule (issue step 2) - not measured yet.** Test-spec
  conventions run most behavioural rows in both survey-object and data-frame
  mode, a 2x multiplier. Whether the two modes share a code path after
  argument resolution has not been tested. It needs its own stub-and-measure
  experiment, exactly like the one run for `test_invariants()`. Do not trim
  it on suspicion.
- **The dual pattern (issue step 3) - leave it.** `expect_error(class = )`
  and `expect_snapshot(error = TRUE)` test different things: the condition
  class and the rendered message. Message regressions have been caught by
  snapshots in this repo before. The 522 snapshot calls stay.

A third item is out of scope but worth its own issue: `test-dataset-metadata.R`
holds 4,254 expectations - 22% of the suite - in one 4,277-line file. That is
a legibility problem this plan does not address.

## Open questions for the maintainer

1. **Is one call per constructor per file the right level?** The measured
   floor is zero - coverage is identical either way. One per constructor per
   file is a judgement call that keeps a cheap guard against a malformed
   constructor result. Zero is defensible on the evidence; this plan chooses
   the conservative option.
2. **Is the `polycor` parity suite worth 42% of test time?** It is a genuine
   oracle test against an independent implementation, which is valuable. The
   alternative is moving it to a nightly or on-demand lane rather than
   shrinking it.
3. **Phase 2 targets one file.** If `test-analysis-corr-latent.R` must keep
   its current cost, the realistic full-suite floor is about 700 s, and the
   fast-loop workflow in Task 6 becomes the main lever.
