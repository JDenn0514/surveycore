# implementation.md — PR 4, `test/replicate-oracle-jk1-jk2`

**Spec:** `spec.md` §V.2 (JK1), §V.3 (JK2), §IV.1–§IV.3 (common contract).
**Base:** `bf47f79f4f8de9aeead6ddce47a8472d89556eaf`.
**Branch:** `test/replicate-oracle-jk1-jk2`.

## Step 0 — base

`git rev-parse HEAD` read `d4d1db2fe2de42243213d30c5bb56639906494b4`, the stale
`main` the three earlier builders in this arc also met. I reset to
`bf47f79f4f8de9aeead6ddce47a8472d89556eaf` and verified.

The reset discarded one modified tracked file: `.claude/settings.local.json`
(84 insertions, 91 deletions). It is a local permission cache, not arc work.
No file under `R/`, `tests/` or `plans/` was modified before the reset.

The working tree at the start of the build carried no untracked `plans/` file
in this worktree — the five untracked `plans/` files and the modified
`plans/pr-budget-calibration.md` named in the brief live in the other checkout.
Nothing to leave alone here.

## Write surface

| Action | File |
|---|---|
| Modified | `tests/testthat/test-variance-replicate.R` |

Nothing else. `R/core-constructors.R` was edited for the power proof in task 7
and reverted with `git restore`; it does not appear in the commit.

## Summary

- Rewrote the JK1 oracle block whole. Removed the two lines computing
  `(n_rep - 1L) / n_rep` as an input, the `scale =` argument on the `survey`
  call, and the `suppressWarnings()` round that call. The block now lets
  `survey` guess its own scale, asserts the guess warning by fragment, asserts
  the warning count, and pins `survey`'s stored scale against `(R - 1) / R`.
- Rewrote the JK2 oracle block whole. Removed the `suppressWarnings()`, added
  the fragment and count assertions for `survey`'s unconditional JK2 warning,
  and gave the existing `sv$scale == 1` assertion the settled guard comment and
  the `1e-8` tolerance.
- Both blocks now pass `mse = TRUE` explicitly to `as_survey_replicate()` as
  well as to `survey::svrepdesign()`, per `spec.md` §IV.2. Neither block reads
  a property off one design and passes it to the other.
- Proved the JK1 block has power: with the constructor's JK1 default scale
  changed to `1`, the block fails on the standard error and both confidence
  bounds and passes on the point estimate, and no other block moves.
- `suppressWarnings(` now has zero hits in the file. No
  `survey::svrepdesign()` call in the file receives a `scale` argument.

## Task checklist

- [x] 1 — Probe JK1.
- [x] 2 — Probe JK2.
- [x] 3 — Rewrite the JK1 block.
- [x] 4 — Rewrite the JK2 block.
- [x] 5 — Run the single file, 0 failures.
- [x] 6 — Grep/parse audit of `scale =` and `suppressWarnings(`.
- [x] 7 — The power proof, and the revert.
- [x] 8 — `air format --check` and `git diff --name-only bf47f79`.
- [x] 9 — Ran no full suite, no `check()`, no `document()`, no `covr`.

## Probe results

Both probes ran against `survey` 4.5 on the `jk1` fixture at seed 15, with
`n = 200`, `n_psu = 20`, `n_strata = 4`. The fixture gives `R = 20` replicate
columns. Each probe built `survey::svrepdesign()` with `weights`, `repweights`,
`type`, `mse = TRUE` and `data`, and with no `scale` and no `rscales`, and
captured every warning and every message.

### Task 1 — JK1

| Quantity | Observed |
|---|---|
| Warnings raised | 1 |
| Messages raised | 0 |
| Warning text | `scale (n-1)/n not provided: guessing n=number of replicates` |
| Contains the fragment `guessing n=number of replicates` | yes |
| `sv$scale` | `0.94999999999999996` |
| `(R - 1) / R` at `R = 20` | `0.94999999999999996` |
| Agree | yes |
| `sv$rscales` | `1` throughout |

### Task 2 — JK2

| Quantity | Observed |
|---|---|
| Warnings raised | 1 |
| Messages raised | 0 |
| Warning text | `with type JK2 scale= and rscales= are not needed and will be ignored` |
| Contains the fragment `with type JK2 scale= and rscales= are not needed` | yes |
| `sv$scale` | `1` |
| Agrees with the literal `1` | yes |
| `sv$rscales` | `1` throughout |

Both fragments match with `fixed = TRUE`, so neither carries a
regular-expression metacharacter into the comparison. The JK2 fragment carries
two `=` characters, which are inert in a regular expression but would still be
compared literally here.

## The power proof (task 7)

### What changed

| Field | Value |
|---|---|
| File | `R/core-constructors.R` |
| Line | 799 |
| Before | `      JK1 = (n_rep - 1L) / n_rep,` |
| After | `      JK1 = 1,` |
| Context | the `switch(type, ...)` inside `if (is.null(scale))` in `as_survey_replicate()` |

The edit was made with the Edit tool and reverted with
`git restore R/core-constructors.R`. Nothing was retyped from memory.

### Baseline, before the change

```
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 143 ]
```

The one warning is pre-existing and unrelated: an AAPOR small-cell warning from
`get_corr()` at `test-variance-replicate.R:798`.

### With the JK1 default at `1`

```
[ FAIL 3 | WARN 1 | SKIP 0 | PASS 140 ]
```

Exactly three failures, all three inside the JK1 block:

| Line | Assertion | Actual | Expected |
|---|---|---|---|
| 145 | `expect_equal(sc_mean$se, as.numeric(survey::SE(sv_mean)), tolerance = 1e-8)` | `0.2464` | `0.2402` |
| 146 | `expect_equal(sc_mean$ci_low, confint(sv_mean)[1], tolerance = 1e-6)` | `49.954` | `49.966` |
| 147 | `expect_equal(sc_mean$ci_high, confint(sv_mean)[2], tolerance = 1e-6)` | `50.920` | `50.907` |

Still passing:

- Line 144, the point estimate,
  `expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)`. The
  scale enters the variance only, so the point estimate does not move.
- The JK1 warning-count and fragment assertions, and the JK1 stored-scale
  assertion. All three read `survey`'s side, which the surveycore constructor
  cannot reach.
- Every other block in the file. The pass count fell by exactly 3, from 143 to
  140, and no other line number appeared in the failure list.

This is the shape the plan predicted. Nothing unexpected was observed and
nothing was adjusted to make it match.

### After the revert

```
$ git status --porcelain
 M tests/testthat/test-variance-replicate.R
```

No file under `R/` appears. `grep -n "JK1 = (n_rep - 1L) / n_rep"
R/core-constructors.R` reads `799`, the original line at the original number.

The single file then ran green again, at the exact baseline numbers:

```
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 143 ]
```

`git show --stat` on the commit lists one file.

## Audit results (task 6)

Counted by parsing, not by `grep -c`, because the file carries `svrepdesign`
inside comment text. The instrument is `utils::getParseData()` filtered to
`SYMBOL_FUNCTION_CALL` tokens, plus a recursive walk of the parsed expressions
that reads each call's argument names.

| Measure | Count |
|---|---|
| `svrepdesign` call tokens | 10 |
| `svrepdesign` call expressions parsed | 10 |
| Of those, receiving a `scale` argument | 0 |
| `suppressWarnings` call tokens | 0 |
| `suppressWarnings` call expressions parsed | 0 |
| `grep 'suppressWarnings('` line hits | 0 |

All ten `svrepdesign()` calls take the identical argument set: `weights`,
`repweights`, `type`, `mse`, `data`.

Seven lines still contain the text `scale =`. None is an argument to
`svrepdesign()`:

| Line | Kind |
|---|---|
| 153 | comment inside the JK2 block, on `survey`'s JK2 behaviour |
| 310 | comment on the BRR scale formula |
| 332 | comment on `survey`'s internal BRR scale |
| 361 | `test_that()` title, successive-difference |
| 382 | `test_that()` title, ACS |
| 627 | argument to a direct `surveycore:::.svy_rep_var()` call |
| 642 | argument to a direct `surveycore:::.svy_rep_var()` call |

Lines 627 and 642 are the two pre-existing hits the plan named. They call an
internal variance routine directly and build no `survey` design, so they stay.

## The stored-scale comment

Both new assertions carry the settled string, character for character:

```
  # Guards survey's default; a failure means survey changed, not surveycore; SE/variance row, 1e-8.
```

Count by exact match, anchored at both ends:

| Point | Exact matches in the file |
|---|---|
| Base `bf47f79` | 8 |
| After this PR | 10 |

The brief says PR 7 counts 13 of 13. The three remaining come from the JKn,
bootstrap and `other` blocks in the later PRs of the arc; the Fay block refuses
before it builds and asserts no stored scale. 8 + 2 + 3 = 13.

The line is 99 characters and over the repo's 80-column limit. That is decision
S4 and is deliberate. `air format --check` does not object: `air` does not wrap
comments.

## Gate results run here

| Gate | Command | Result |
|---|---|---|
| Single file | `NOT_CRAN=true Rscript -e 'testthat::test_local(filter = "variance-replicate")'` | `FAIL 0 \| WARN 1 \| SKIP 0 \| PASS 143` |
| Format | `air format --check tests/testthat/test-variance-replicate.R` | exit 0, silent |
| Diff surface | `git diff --name-only bf47f79` | `tests/testthat/test-variance-replicate.R` |

The one warning is the pre-existing AAPOR small-cell warning at line 798,
unchanged from the base.

Per the dispatch, I ran no full suite, no `devtools::check()`, no
`devtools::document()`, no `run_examples()`, no `pkgdown` and no `covr`. The
leader runs those as detached processes.

## Notes for tester

- The blocks assert the warning count with
  `testthat::capture_warnings()` + `expect_length(x, 1L)`, then match the
  fragment with `expect_match(x, ..., fixed = TRUE)`. This is the house
  precedent, used five times in `tests/testthat/test-constructors.R` (first at
  line 3378). The alternative, a bare `expect_warning()`, matches the fragment
  but counts nothing, and `spec.md` §IV.3 requires the count.
- `fixed = TRUE` on both `expect_match()` calls. §V.2 forbids the full JK1
  warning text because it contains `(n-1)/n`, whose parentheses read as a
  regular-expression group. `fixed = TRUE` is a second guard on the same
  hazard, and it costs nothing.
- The JK1 fragment is `guessing n=number of replicates`, not `JK1`. A supplied
  `rho` on four other types raises `rho not relevant to JK1 design: ignored.`,
  because `survey` hard-codes the name. No block supplies a `rho`, so the
  branch is unreached today.
- Neither block writes that JK2's per-stratum factors belong in `rscales`. That
  wording was corrected out of the package by PR #280 and does not return here.
- Both probes were measured on `survey` 4.5. A later `survey` release can move
  a default or a message; the stored-scale assertions are the guard that turns
  that into a red line instead of a silently moved target.
- Line 798 of this file raises a pre-existing AAPOR small-cell warning from
  `get_corr()`. It predates this PR and is untouched by it.

## CRAN compliance

- [x] TRUE/FALSE used throughout — both blocks write `mse = TRUE`, no `T`/`F`
- [x] `::` used for external calls — `survey::`, `testthat::`
- [x] No bare `print()`/`cat()`
- [x] No randomness added; the fixture seed is a literal argument, `15`
- [x] No `par()` or `options()` touched
- [x] No file written; no `tempdir()` needed
- [x] No parallelism; no core count set
- [x] `devtools::document()` not run and not needed — no roxygen changed, no
      file under `R/` in the commit
- [x] No `installed.packages()`; the skip guard is
      `skip_if_not_installed("survey")`, inside each block
