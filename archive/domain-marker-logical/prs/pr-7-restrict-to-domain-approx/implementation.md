# PR 7 — `fix/restrict-to-domain-approx` — implementation

Issue: #276. Branch: `fix/restrict-to-domain-approx`.

## Base sha

The worktree opened on `d4d1db2fe2de42243213d30c5bb56639906494b4`, which is
not the expected base. As instructed, I ran `git fetch origin` and
`git reset --hard 19d6fdab3430ebbb2faf5fdd254b23058962ce0b`. HEAD then read
`19d6fdab3430ebbb2faf5fdd254b23058962ce0b`.

Sanity checks on that base, both passed:

- `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returned nothing.
- `tests/testthat/helper-test-data.R` defines `make_domain_pair()`, and its
  `"twophase"` variant ships `method = "approx"`.

## Write surface

Modified, three files, nothing else:

- `R/methods-conversion.R`
- `tests/testthat/test-conversion.R`
- `NEWS.md`

Created: none. Deleted: none. `NAMESPACE` and `man/` are untouched —
`.restrict_to_domain()` is internal and carries `#' @noRd`, and the only
roxygen-adjacent edit is to plain `#` comments above that tag, so
`devtools::document()` produces no diff.

## Summary

- `.restrict_to_domain()` now sends both two-phase classes to the
  `phase1$sample$variables` branch. The branch body is unchanged, because
  both classes keep the frame in the same place.
- The class test matches the shape already used at
  `R/methods-conversion.R:719` in `from_svydesign()`:
  `inherits(x, "twophase2") || inherits(x, "twophase")`.
- One new test block in `tests/testthat/test-conversion.R` converts the
  `make_domain_pair("twophase")` design, which is `method = "approx"`, and
  asserts the finite-probability count. The expected value is computed from
  the fixture as `sum(pair$mask & df$subset)`.
- The design note above the helper is corrected: it said the helper serves
  three classes and named only `twophase2` as keeping the frame at
  `phase1$sample$variables`.
- One `NEWS.md` entry under `## Bug fixes` in the development version.

## Before / after of `.restrict_to_domain()`

Before:

```r
  frame <- if (inherits(converted, "twophase2")) {
    converted$phase1$sample$variables
  } else {
    converted$variables
  }
```

After:

```r
  frame <- if (
    inherits(converted, "twophase2") || inherits(converted, "twophase")
  ) {
    converted$phase1$sample$variables
  } else {
    converted$variables
  }
```

Nothing below the `frame` assignment changed.

## Failing then passing, with the numbers

Command, foreground, no background job:

```
Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-conversion.R", reporter="summary")'
```

**Before the fix**, one failure, the new block:

```
── 1. Failure ('test-conversion.R:4255:3'): as_svydesign() restricts an approx t
Expected `sum(is.finite(sv$prob))` to be identical to `in_domain_and_phase2`.
Differences:
  `actual`: 74
`expected`: 52
```

74 and 52 are the two numbers issue #276 measured. 74 is the unrestricted
phase-2 count; 52 is the count of rows that are both in-domain and in phase
2.

**After the fix**, the whole file passes: no failures under `load_all()`
(10 blocks skip with "On CRAN", which is the documented effect of
`NOT_CRAN` being unset), and no failures and no skips under `NOT_CRAN=true`.

### One correction to the block, made between the two runs

My first draft asserted that the restriction removes no row on this route,
copying the claim from the neighbouring `method = "full"` block. That is
false for `method = "approx"`. Measured:

| class | row count after the restriction | finite probabilities |
|---|---|---|
| `twophase2` (`method = "full"`) | 74 — every row kept, excluded rows get `Inf` | 52 |
| `twophase` (`method = "approx"`) | 52 — excluded rows removed | 52 |

`[` on the `approx` class removes the excluded rows rather than voiding
them. The block now asserts `52` for all three of
`sum(is.finite(sv$prob))`, `length(sv$prob)` and
`nrow(sv$phase1$sample$variables)`, and the comment records the difference
between the two classes. All three of those read `74` before the fix, so
each of them separates the two states.

## Is the `else` branch now dead for two-phase?

Yes for two-phase, and it is still needed. Both classes
`survey::twophase()` can return — `twophase2` for `method = "full"` and
`twophase` for `method = "approx"` — now satisfy the first branch, so no
two-phase object can reach the `else`. The `else` still carries the Taylor
and replicate routes: `survey.design2` and `svyrep.design` objects keep the
frame at `converted$variables`, and the two nonprob shapes convert through
those same two routes. I did not delete it.

## The five #277 rows

All five still pass, in both runs. They are the blocks under the section
header `── The marker reaches the conversion routes uncoerced (#262) ──` in
`tests/testthat/test-conversion.R`:

1. `as_svydesign() keeps only the marked rows of a logical Taylor marker`
2. `as_svydesign() drops an NA marker row on the Taylor route`
3. `as_svydesign() drops an NA marker row on the replicate route`
4. `as_svydesign() voids rather than removes the excluded two-phase rows`
5. `as_svydesign() keeps every row of a design with no marker column`

Row 4 is the `method = "full"` claim, so acceptance criterion 2 — "the
`method = "full"` behaviour is unchanged" — is pinned by a passing
assertion and not only by the absence of a failure.

I edited one comment inside row 4. Its last paragraph said the `approx`
gap was "a defect of its own, filed as issue #276, and deliberately not
pinned by an assertion here", which this PR makes false. The replacement
says the block rebuilds with `method = "full"` because the fixture ships
`"approx"`, and points at the new block. No assertion in row 4 changed.

## Grep

```
$ grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/
grep-exit=1
```

No match, as required by acceptance criterion 4.

## Other checks

- `air format --check R/methods-conversion.R tests/testthat/test-conversion.R`
  — no output, both files clean.
- `git status --porcelain` after the runs showed only the three files of the
  write surface. No `_snaps/` line-ending churn appeared, so there was
  nothing to revert.
- No `devtools::check()`, `R CMD check`, `R CMD build`, `covr`, `pkgdown`,
  `run_examples()` or full `devtools::test()` was run, per the gate policy.

## Task checklist

- [x] 1. Failing test written first, `skip_if_not_installed("survey")`
      inside the block, expected count derived from the fixture, failure
      observed and recorded (74 vs 52).
- [x] 2. `.restrict_to_domain()` class test widened to both two-phase
      classes; branch body unchanged.
- [x] 3. Test re-run, passes.
- [x] 4. `else` branch checked: dead for two-phase, still live for Taylor
      and replicate, not deleted.
- [x] 5. Design note above the helper corrected.
- [x] 6. One `NEWS.md` entry under `## Bug fixes`, naming #276 and the
      measured symptom.
- [x] 7. Whole `test-conversion.R` re-run; the five #277 rows pass.

## HOLDs

None.

## Notes for tester

- The new block's assertions on `length(sv$prob)` and
  `nrow(sv$phase1$sample$variables)` describe `[` on survey's `twophase`
  class, which removes rows. If a future `survey` release makes that class
  behave like `twophase2` and void rows instead, those two assertions move
  and `sum(is.finite(sv$prob))` does not. Measured against `survey` 4.4-2.
- Under `devtools::load_all()` with `NOT_CRAN` unset, 10 blocks in this file
  skip with "On CRAN". The `NOT_CRAN=true` run covers them.

## Commit

Commit: `ca2dd6aa1f4abf602dfdf8466e2bb9e9d9600568`
Tree: `180cd477c90b594e88c75033eff66a00224457b0`
Branch: `fix/restrict-to-domain-approx`, on top of
`19d6fdab3430ebbb2faf5fdd254b23058962ce0b`. Not pushed. No PR opened.
