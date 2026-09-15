# Implementation — PR 5 — restrict-to-domain-coercion

**Archive note.** The run-directory path cited below no longer resolves: the
run directory is gitignored and was not archived. That decisions log IS in
this directory, as `decisions.md` and `decisions-domain-marker-logical.md`,
which are identical. The `[no such file]` marker is the citation checker's
vocabulary for an unresolvable path, not a statement that the log is lost.

**Branch**: `fix/restrict-to-domain-coercion`
**Commit**: `ead56911daa5bb0d7546831782996592e56daa9a`
**Tree**: `50b9a88eb887d975eb7175feff43f04441f1925c`

## Base sha

The worktree opened on `d4d1db2fe2de42243213d30c5bb56639906494b4` — a stale
`main` commit, the failure mode the brief warned about. Ran
`git fetch origin && git reset --hard b2fa7e1d3a13909cc91493bbe00fad7e0eddbb55`
and verified `HEAD` is now `b2fa7e1d3a13909cc91493bbe00fad7e0eddbb55`.

Base sanity check passed. `R/core-classes.R:365` carries the domain-marker
validator and its class `surveycore_error_domain_not_logical`.
`R/analysis-helpers.R:493` carries `stored[is.na(stored)] <- FALSE`.

## Write surface

- `R/methods-conversion.R` — modified
- `tests/testthat/test-conversion.R` — modified

No other file changed. `git status` after the run listed those two and nothing
else.

## Summary

- Removed the `as.logical()` coercion from `.restrict_to_domain()` and kept the
  `r & !is.na(r)` guard.
- Rewrote the design note above the helper. It now records that the class
  validator guarantees the type at the write, and that `!is.na(r)` is still
  load-bearing because the validator forbids a non-logical column but not `NA`.
- Corrected two test comments in `tests/testthat/test-conversion.R` that
  described the removed coercion and were left false by the change.
- Added five regression blocks, one per scenario, each calling
  `skip_if_not_installed("survey")` inside the block. All five pass both before
  and after the production change.
- Raised one HOLD: the domain restriction does not run at all on a two-phase
  design built with `method = "approx"`.

## `.restrict_to_domain()` — before and after

Before:

```r
  r <- as.logical(frame[[SURVEYCORE_DOMAIN_COL]])
  converted[r & !is.na(r), ]
```

After:

```r
  r <- frame[[SURVEYCORE_DOMAIN_COL]]
  converted[r & !is.na(r), ]
```

The rest of the body is untouched: the class-dependent frame read and the
early return on the missing name are both unchanged.

## Design note — old and new

Old (removed):

```
# as.logical() before the mask. Nothing in the package guarantees the marker
# column is logical and no validator checks its type; code in this repository
# already writes an integer one. `&` alone errors on a character column and
# returns an all-NA mask on a factor one. With as.logical() first, a logical,
# integer, double, character or FALSE/TRUE factor column all select the same
# rows. `!is.na(r)` reads NA as outside the domain, and absorbs the NA that
# as.logical() returns for a value it cannot convert.
```

New:

```
# No coercion before the mask. The survey_base validator rejects a marker
# column of any type but logical, on construction and on every later write to
# @data, so a design that reaches a conversion route carries a logical column
# and can carry nothing else (issue #262). An earlier revision called
# as.logical() here. That turned a wrong column type into a silently wrong
# row set where the validator now raises
# `surveycore_error_domain_not_logical` at the write.
#
# `!is.na(r)` stays, and is still load-bearing. The validator forbids a
# non-logical column; it does not forbid NA. A logical marker can hold NA,
# and an NA in an index vector selects a phantom row of NAs. The guard reads
# an NA marker as outside the domain, which is the reading .apply_domain()
# gives it on the analysis side.
```

The other four paragraphs of the note are unchanged.

## Scenario 3 — the two counts, measured

The brief predicted `sum(mask & subset)` = 52 against `sum(mask)` = 149 on the
shipped `make_domain_pair("twophase")` fixture. The measurement contradicts
both the brief and the frozen planning documents, and does so for a reason
neither anticipated.

Fixture facts: 200 rows, `sum(mask)` = 149, `sum(subset)` = 74,
`sum(mask & subset)` = 52.

| Design | Converted class | `length(prob)` | Finite probabilities |
|---|---|---|---|
| `make_domain_pair("twophase")$a` (`method = "approx"`) | `twophase` | 74 | **74** |
| Same frame and marker, `method = "full"` | `twophase2` | 74 | **52** |

`make_domain_pair("twophase")` ships `method = "approx"`.
`survey::twophase(method = "approx")` returns class `c("twophase",
"survey.design")`. `.restrict_to_domain()` branches on
`inherits(converted, "twophase2")`, which is `FALSE` for that object, so it
falls to `converted$variables` — and an `approx` two-phase object carries no
`$variables` at all. `names(NULL)` is `NULL`, the name test fails, and the
helper returns the object unrestricted. The restriction is a silent no-op on
that route.

So the two numbers in contention are 74 (observed, `approx`) and 52 (the
correct in-domain-and-in-phase-2 count, which the `full` route produces). 149
never appears.

The gap is pre-existing: the archived `as-svydesign-domain` arc that added the
helper exercised `method = "full"` alone.

Scenario 3 therefore rebuilds the two-phase design from the fixture's own frame
and marker with `method = "full"`, derives `sum(mask & subset)` from the
fixture rather than hardcoding 52, and asserts acceptance criterion 2 exactly.
Its comment names the `approx` gap and points at the HOLD. No assertion in the
PR pins the defect.

`tests/testthat/helper-test-data.R` was not edited, as instructed.

## Grep outputs

Criterion 5 — Gate 1:

```
$ grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/
(no output, exit 1)
```

Criterion 6 — Gate 13:

```
$ grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R
R/analysis-helpers.R
R/analysis-t-test.R
R/glm-anova.R
```

Exactly the three expected files.

Criterion 7 — the old design note:

```
$ grep -rn "no validator checks its type" R/
(no output, exit 1)
```

## Test runs

Targeted run only. No `devtools::check()`, `R CMD check`, `R CMD build`,
`covr`, `pkgdown`, `run_examples()` or full `devtools::test()` was run, per the
gate policy.

Pre-change run (task 2), with the `as.logical()` line temporarily restored:
the whole file passed with 0 failures, and all five new blocks passed. They are
regression rows, as the plan expected.

Post-change run, `NOT_CRAN=true`:

```
FILE: test-conversion.R | PASS 802 | FAIL 0 | WARN 0 | SKIP 0 | ERROR 0
```

The five new blocks, all passing, none skipped:

| Block | Expectations |
|---|---|
| `as_svydesign() keeps only the marked rows of a logical Taylor marker` | 3 |
| `as_svydesign() drops an NA marker row on the Taylor route` | 5 |
| `as_svydesign() drops an NA marker row on the replicate route` | 5 |
| `as_svydesign() voids rather than removes the excluded two-phase rows` | 4 |
| `as_svydesign() keeps every row of a design with no marker column` | 4 |

## `devtools::document()`

Run. `NAMESPACE` did not move and no file under `man/` changed — `git status`
after the run still listed only the two files in the write surface.
`.restrict_to_domain()` is internal and carries `#' @noRd`, and no roxygen
content changed in this PR.

## Formatting and snapshot hygiene

`air format --check` passes on both files. The base copy of
`tests/testthat/test-conversion.R` was already air-clean, and the appended
section left one surplus blank line, which air's own output removed.

No churn under `tests/testthat/_snaps/`. The working tree held only the two
files in the write surface at commit time.

## Task checklist

- [x] 1. Five conversion test blocks, one per scenario, each with
      `skip_if_not_installed("survey")` inside the block.
- [x] 2. All five pass against the pre-change tree. Recorded above.
- [x] 3. `as.logical()` removed from `.restrict_to_domain()`; `r & !is.na(r)`
      kept.
- [x] 4. Design note rewritten; "no validator checks its type" is gone from
      `R/`.
- [x] 5. All five pass after the change. No new `test_invariants()` call added.

## Signals raised

**HOLD** — appended to
`.surveycore-workspace/runs/2026-09-12-domain-marker-logical/decisions.md` [no such file].

`.restrict_to_domain()` does not restrict a two-phase design built with
`method = "approx"`, because the helper's class test names `twophase2` only.
`as_svydesign()` returns the full stored sample where the caller asked for the
domain. The fix is one line — widening the class test — but it is a
behavioural change to a conversion route that PR 5's task list does not
authorise and the arc's `spec.md` does not mention. The decision needed:
widen the class test in this PR, or open an issue and defer.

The rest of PR 5 is complete and committed.

## Notes for tester

- Scenario 3 builds its own `method = "full"` two-phase design from
  `make_domain_pair("twophase")`'s frame and marker rather than using the
  fixture's design object. The reason is the HOLD above, and the block's
  comment states it.
- The new blocks use `rownames()` on the converted frame as the observable for
  "which rows survived". A row-count assertion alone passes on an object that
  kept the wrong rows of the right number.
- The run above set `NOT_CRAN=true`, so nothing skipped. Without it,
  `test-conversion.R` skips 10 blocks that carry `skip_on_cran()`. None of the
  10 is new in this PR.
