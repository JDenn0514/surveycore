# implementation.md — PR 5, `test/replicate-oracle-jkn`

**Branch:** `test/replicate-oracle-jkn`
**Base:** `d0de848d506feb186636898fa7726efdc8337a22`
**Spec sections:** §II "Where the four new blocks go", §IV.1, §IV.2, §IV.3
("The pinned blocks"), §V.4.

---

## Write surface

| File | Action |
|---|---|
| `tests/testthat/test-variance-replicate.R` | Modified — appended one section header and one `test_that()` block |

No other file changed. Nothing under `R/`. No roxygen, so no
`devtools::document()`, no `NAMESPACE` or `man/` change.

`git diff --name-only d0de848` returns exactly one path:
`tests/testthat/test-variance-replicate.R`.

---

## Step 0 — base verification

The worktree came up on `d4d1db2fe2de42243213d30c5bb56639906494b4`, stale
`main`, as the dispatch predicted. Reset to
`d0de848d506feb186636898fa7726efdc8337a22` and verified.

The reset discarded one thing: an uncommitted modification to the tracked file
`.claude/settings.local.json` (84 insertions, 91 deletions — a reordering of
the permission allow-list and a hook path pointing at a macOS home directory).
It carried no project content. No untracked file was present in the worktree,
so nothing else was lost.

---

## Summary

- Added one section header, `# Block 24: Oracle blocks for the remaining
  replicate types`, at the end of the file. No existing `# Block N:` header
  changed number; the last existing one is still `# Block 23`. The header sits
  at line 803 with the JKn block under it, so PRs 6 to 8 append bootstrap,
  `other` and Fay beneath it without restructuring.
- Added the JKn oracle block, pinned. Both sides build from the same fixture
  (`make_survey_data(n = 200, n_psu = 20, n_strata = 4, design = "replicate",
  type = "jkn", seed = 15)`), the same weight column `wt`, the same replicate
  columns selected by the `^repwt_` prefix, and the same explicit `mse = TRUE`.
- The `rscales` literal `rep(1, n_rep)` is written out twice, once per side.
  `n_rep` is read off the fixture's selected column names, never off a design.
  No value is read off either design and passed to the other.
- The block asserts no warning on the `survey::svrepdesign()` call, `survey`'s
  stored scale against the literal `1` at `1e-8`, the point estimate bare at
  `1e-10`, and the standard-error ratio against `sqrt((n_rep - 1) / n_rep)`
  bare at `1e-8`. Three `testthat::expect_failure()` wrappers, one assertion
  each, round the standard error and the two confidence bounds.
- The block comment names issue #253 and states that a later PR deletes **four**
  lines: the three wrapper lines and the ratio assertion.

---

## Probe results

Measured on `survey` 4.5, fixture mode `jkn`, seed 15, `R = 20`.

### Probe 1 — `survey` with `rscales`, no `scale`

```
survey::svrepdesign(
  weights = d$wt, repweights = d[, repwt_cols],
  type = "JKn", mse = TRUE, rscales = rep(1, 20), data = d
)
```

| Measure | Value |
|---|---|
| Warnings raised | 0 |
| `sv$scale` | `1` |
| `sv$rscales` | `1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1` |

The call is silent, so the block asserts no warning rather than matching a
message fragment.

### Probe 2 — `survey` with no `rscales`

The same call with the `rscales` argument removed raises:

```
simpleError: Must provide rscales for combined JKn weights
```

Class chain: `simpleError` / `error` / `condition`. This refusal is the reason
JKn is the one block in the file allowed to supply `rscales` to
`svrepdesign()`.

### Probe 3 — the gap

| Quantity | Measured (17 significant digits) | Spec value | Agrees |
|---|---|---|---|
| surveycore stored scale | `0.94999999999999996` | `(R-1)/R` = 0.95 | yes |
| `survey` stored scale | `1` | `1` | yes |
| surveycore point estimate | `50.436542684160358` | — | — |
| `survey` point estimate | `50.436542684160358` | — | identical |
| surveycore SE | `0.24018678896352669` | `0.240186788963527` | yes |
| `survey` SE | `0.24642644593339988` | `0.2464264459334` | yes |
| ratio (surveycore / `survey`) | `0.97467943448099092` | `0.974679434480991` | yes |
| `sqrt(19 / 20)` | `0.97467943448089633` | `0.974679434480896` | yes |
| ratio − `sqrt(19 / 20)` | `9.4591001698063337e-14` | — | far inside 1e-8 |

Confidence bounds, for completeness:

| Side | lower | upper |
|---|---|---|
| surveycore | `49.965785228229521` | `50.907300140091195` |
| `survey` | `49.953555725292688` | `50.919529643028028` |

Each bound differs by about `1.2e-2`, a relative gap near `2.4e-4`, well above
the `1e-6` confidence-bound tolerance. The three wrapped assertions therefore
fail reliably and the three wrappers pass.

No measurement differed from the spec beyond the standard-error tolerance, so
no stop-and-report was triggered and no number in the block was adjusted to
match a moved measurement.

---

## The block's shape

Outside every wrapper:

- the `skip_if_not_installed("survey")` guard;
- the fixture, the column selection and `n_rep`;
- the `as_survey_replicate()` call with `type = "JKn"`, `mse = TRUE`,
  `rscales = rep(1, n_rep)`;
- the `expect_no_warning(sv <- survey::svrepdesign(...))` call, which carries
  both the design build and the condition assertion (an R warning raised inside
  a wrapper escapes it, §IV.3 mechanic 3);
- `expect_equal(sv$scale, 1, tolerance = 1e-8)` under the pinned comment;
- `expect_equal(sc_mean$mean, coef(sv_mean)[["y1"]], tolerance = 1e-10)` — the
  point estimate agrees exactly (§IV.3 mechanic 2);
- the ratio assertion, `sc_mean$se / as.numeric(survey::SE(sv_mean))` against
  `sqrt((n_rep - 1) / n_rep)` at `1e-8`.

Inside a wrapper — three `testthat::expect_failure()` calls, one assertion
each (§IV.3 mechanic 1):

| Wrapper | Assertion | Tolerance |
|---|---|---|
| 1 | `sc_mean$se` against `as.numeric(survey::SE(sv_mean))` | `1e-8` |
| 2 | `sc_mean$ci_low` against `confint(sv_mean)[1]` | `1e-6` |
| 3 | `sc_mean$ci_high` against `confint(sv_mean)[2]` | `1e-6` |

Tolerances compose inside a wrapper (§IV.3 mechanic 4), so the wrapped
assertions carry the same values they would carry bare.

**Title.** `get_means() JKn SE disagrees with survey::svymean() — issue #253`.
It names the disagreement, names the issue, and claims no match. The file's
usual "X matches Y" shape would assert the opposite of what the block proves.

---

## Conventions followed

1. The stored-scale comment is the exact 99-character string, unshortened and
   unrewrapped. Exact-match count across the repository rises from 10 to 11.
2. `mse = TRUE` passes explicitly to both sides, the same literal.
3. Line 174, `expect_equal(sc@variables$scale, 1)` in the JK2 block, is
   untouched — verified by reading it back after the edit.
4. Tolerances taken from `.claude/rules/testing-surveycore.md`: point `1e-10`,
   SE and variance `1e-8`, confidence bounds `1e-6`.

---

## Task checklist

- [x] 1. Probe JKn — the `rscales` build is silent, `sv$scale` reads `1`; the
      build with no `rscales` is refused with
      `Must provide rscales for combined JKn weights`.
- [x] 2. Probe the gap — every number matches the spec to at least thirteen
      significant figures.
- [x] 3. Write the block — both sides from the same inputs, the `rscales`
      literal written twice, nothing read off one design and handed to the
      other.
- [x] 4. The shape — three wrappers, one assertion each; point estimate, stored
      scale, ratio, design call and no-warning assertion all outside.
- [x] 5. The block comment names issue #253 and states the four-line deletion
      count.
- [x] 6. The title names the disagreement and issue #253 and claims no match.
- [x] 7. Single-file run: `NOT_CRAN=true Rscript -e
      'testthat::test_local(filter = "variance-replicate")'` →
      `[ FAIL 0 | WARN 1 | SKIP 0 | PASS 150 ]`. The one warning is
      pre-existing, from block 23 at line 798 (AAPOR small-cell guidance in
      `get_corr()`), and is unrelated to this PR. A silent-reporter run
      confirms the new block ran as a block: 7 expectations, 0 failed, 0
      skipped, 0 errors, 0 warnings.
- [x] 8. `air format --check tests/testthat/test-variance-replicate.R` exits 0.
      `git diff --name-only d0de848` lists one path.
- [x] 9. No full suite, no `devtools::check()`, no `document()`, no
      `run_examples()`, no `pkgdown`, no `covr`.

---

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `type = "JKn"` block under a new `# Block 24:` header at the end; no existing header renumbered | met — headers read 10, 11, 12, 16, 22, 23, 24 |
| 2 | Same `rscales` literal to both sides, written twice, neither read off a design | met — `rep(1, n_rep)` at the constructor and at `svrepdesign()` |
| 3 | Exactly one `svrepdesign()` call receives `rscales`, and it is in this block | met — the other `rscales =` hits are one `as_survey_nonprob()` call (line 229, unchanged) and two `.svy_rep_var()` calls (lines 628, 643, unchanged) |
| 4 | Asserts no warning on the design build; asserts `survey`'s stored scale against `1` at `1e-8` with its comment | met |
| 5 | Three wrappers, one assertion each; point estimate, stored scale, ratio, design call and no-warning assertion outside | met |
| 6 | One unwrapped ratio assertion against `sqrt((R - 1) / R)` at `1e-8`, and it passes | met — measured difference `9.46e-14` |
| 7 | Comment names issue #253 and the four-line count; title names the disagreement and issue #253 and claims no match | met |
| 8 | 0 failures; diff lists one file; `air format --check` passes | met |

---

## HOLDs raised

None.

---

## Notes for tester

- The single-file run reports one warning, at `test-variance-replicate.R:798`,
  in block 23's `get_corr()` call. It is pre-existing on `d0de848` and is one
  of the AAPOR small-cell warnings that clean `develop` already carries. This
  PR neither adds nor removes it.
- The block does not add a `test_invariants()` call. Spec §IV.4 allocates the
  file's single call to the first block, `get_means() replicate SE matches
  survey::svymean() — BRR design`, where it already sits at line 31 from an
  earlier PR in this arc. A second call would breach the one-per-constructor
  -per-file rule.
- `as_survey_replicate()` accepts `rscales` directly; the stratified-jackknife
  guard that demands an explicit `rscales` lives on `as_survey_nonprob()`, not
  on the replicate constructor. surveycore therefore accepts a JKn design with
  no `rscales` today, where `survey` refuses one. Spec §V.4 records that issue
  #255 adds the refusal and that this PR does not.
- The three `expect_failure()` wrappers are load-bearing in a direction that is
  easy to misread: each one turns **red** when the assertion inside it starts
  to **pass**. When issue #253 corrects the JKn default, all three wrappers and
  the ratio assertion fail at once — four lines, by design.
