# Audit — PR 4 — fix/apply-domain-na-mask

**Verdict**: PASS
**Date**: 2026-09-15 13:05

Scope audited: test-spec §3, rows 3.1 to 3.9 only. Rows in §1, §2, §4, §5, §6
and §Existing blocks were not audited.

Tree: 7bd2712a3248840dd69bf7a8a6bc1b38eb1ac079 (commit `09d97e3`)

This is the current audit of tree `7bd2712`. It replaces the audit of tree
`939c70e`, which carried verdict BLOCK on two findings. Both are fixed. Rows
3.7, 3.8 and 3.9 are carried forward from that audit; `git diff
3ab6318..09d97e3` moves one file, `tests/testthat/test-analysis-helpers.R`,
and leaves all three blocks untouched.

---

## Per-Test Result Table

Section 3 states one tolerance rule: **use `expect_identical()`, not a
tolerance**. Every block uses `expect_identical()`. No tolerance was relaxed
anywhere in this PR.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 3.1 `get_means()` grouped by `group`, A vs B column by column | line 1830 — `get_means(pair$a, y1, group = group)` against the same call on `pair$b`, through `expect_domain_invariance()` | grouped by `group`, every column identical | `expect_identical()` | ✓ |
| 3.2 `get_quantiles()` grouped by `group`, A vs B | line 1838 — `get_quantiles(pair$a, y1, group = group)` against the same call on `pair$b` | grouped by `group`, every column identical | `expect_identical()` | ✓ |
| 3.3 `get_diffs()` `y1` by `group`, A vs B | line 1846 — `get_diffs(designs$a, y1, treats = group)` against the same call on `designs$b` | every column identical | `expect_identical()` | ✓ |
| 3.4 `get_t_test()` `y1` by a two-level column built inline | line 1856 — `arm`, a two-level factor built in the block from `group`, written to both designs; `get_t_test(design_a, y1, by = arm)` against the same call on `design_b` | every column identical | `expect_identical()` | ✓ |
| 3.5 `get_pairwise()` `y1` by `group` | line 1874 — `get_pairwise(designs$a, y1, by = group)` against the same call on `designs$b` | every column identical | `expect_identical()` | ✓ |
| 3.6 `survey_glm()` `y1 ~ y2` coefficient table | line 1883 — `summary(survey_glm(pair$a, y1 ~ y2))$coefficients`, converted with `as.data.frame()`, against the same for `pair$b`; rownames compared separately | coefficient table identical, fit object not compared | `expect_identical()` | ✓ |
| 3.7 grouped `get_means()` on A reports only real groups | carried, unchanged since `3ab6318` — asserts `!anyNA(result$group)`, the level set equals the in-domain levels, `sum(result$n) == sum(mask)` | no `NA` group value, all real levels | `expect_identical()` | ✓ |
| 3.8 all-`NA` marker, ungrouped `get_means()` equals the all-`FALSE` result | carried, unchanged since `3ab6318` — column-by-column identity plus `n == 0L` | same result as the all-`FALSE` marker | `expect_identical()` | ✓ |
| 3.9 zero-row design, `logical(0)` marker, `.apply_domain()` return | carried, unchanged since `3ab6318` — `expect_identical(.apply_domain(design), logical(0))` | `logical(0)`, not `NULL`, not `TRUE` | `expect_identical()` | ✓ |

Nine spec rows, nine blocks, no block outside the section. The four
out-of-scope blocks flagged last round — `get_totals()`, `get_freqs()`,
`get_ratios()` and `get_corr()` — are gone.

---

## The two BLOCKs from the previous audit

**BLOCK 1 — rows 3.3 to 3.6 absent. Cleared.** All four functions now carry a
block, and each block matches the row's stated shape. Two details I checked
rather than took on report:

- Row 3.4's `by` column is genuinely two-level and built in the block. `arm`
  is a factor with levels `control` and `treatment`, splitting 137 to 63 over
  the 200 rows. Both levels hold in-domain rows: control 103, treatment 45.
  The column is not degenerate and it is not a fixture column.
- Row 3.6 compares the coefficient table and not the fit object.
  `summary()$coefficients` is a 2-by-4 numeric matrix. It holds neither the
  call nor the design, which is the reason §3 names the cleaned table.

**BLOCK 2 — rows 3.1 and 3.2 called ungrouped. Cleared.** Both now pass
`group = group` and both still route through `expect_domain_invariance()`, so
the comparison stays column by column.

---

## The three checks the coordinator asked for

### `with_factor_group()` cannot mask a real difference

The helper (line 1824) writes `factor(pair$b@data$group)` onto both designs.
Measured on the fixture:

| Check | Result |
|---|---|
| `group` column class as built | `character`, values `A`, `B`, `C` |
| `pair$a@data$group` identical to `pair$b@data$group` before pinning | TRUE |
| `factor(pair$b@data$group)` identical to `factor(pair$a@data$group)` | TRUE |
| Levels pinned | `A`, `B`, `C` — every level in the data |

The helper writes the same vector to both designs, and that vector already
matched between them. `make_domain_pair()` builds `a` and `b` from one data
frame and changes one column, the marker. So the pinning cannot hide a
difference between A and B in `group`: there was none to hide, in either
direction.

What it does change is one indirect detection channel. Without pinning,
`get_diffs()` and `get_pairwise()` derive the factor themselves, and a
regression in `.apply_domain()` could have shown up as a divergent level set
rather than as a number. Pinning closes that channel. It does not weaken the
blocks, because both still go red under a regressed helper on the numbers
alone — measured below. The helper silences the coercion warning and nothing
else.

### The `survey_glm()` block loops over real columns

The vacuity risk I named last round — `expect_domain_invariance()` passing on
a zero-column input with one name comparison and an empty loop — does not
apply here. Measured on `as.data.frame(summary(survey_glm(pair$a, y1 ~ y2))$coefficients)`:

| Measure | Value |
|---|---|
| Source class | `matrix`, `array`, 2 by 4 |
| Columns after `as.data.frame()` | 4 — `Estimate`, `Std. Error`, `t value`, `Pr(>|t|)` |
| Rows | 2 — `(Intercept)` and `y2` |
| Any zero-length column | FALSE |

The loop runs four times over two-element numeric columns. The block also
asserts `expect_identical(rownames(coefs_a), rownames(coefs_b))` before the
helper call, which covers the row dimension the helper's loop does not read.

### The builder's red-under-regression claim — spot-checked, it holds

I restored the pre-PR `.apply_domain()` body in the loaded namespace with
`assignInNamespace()` — no file was edited, and `git status --porcelain R/`
prints nothing — then re-ran `tests/testthat/test-analysis-helpers.R`:

| Block | Result under a regressed `.apply_domain()` |
|---|---|
| 3.1 `get_means()` grouped | Error |
| 3.2 `get_quantiles()` grouped | Error |
| 3.3 `get_diffs()` | Error |
| 3.4 `get_t_test()` | Error |
| 3.5 `get_pairwise()` | Error |
| 3.6 `survey_glm()` | Error |
| 3.7 grouped `get_means()`, real groups | Error |
| 3.8 all-`NA` marker | Error |
| 3.9 zero-row `logical(0)` | Passes — expected |

Eight of the nine go red. I recorded the pass/error state per block and did
not capture each error message, so I neither confirm nor dispute the builder's
specific wording `variable lengths differ (found for '(weights)')`. The claim
that matters — every new block fails without the fix — holds.

Row 3.9 passing is correct and was already settled in the previous audit. It
reads the mask from a design built out of `pair$b`, whose marker holds no
`NA`, so the old body returns `logical(0)` too. §3 asks 3.9 to pin the
length-zero contract, not the `NA` resolution.

---

## Checks carried forward, unchanged

`git diff 3ab6318..09d97e3` moves one test file and no file under `R/`, so
these results stand from the audit of tree `939c70e`:

- **`expect_domain_invariance()` compares column by column** and never
  compares two result objects whole, as §3 requires. Its body did not change.
- **The `"twophase"` fixture precondition holds.** Measured on
  `make_domain_pair("twophase")`: 200 rows, 74 in phase 2, 149 in domain, and
  **97 `TRUE` marker rows outside phase 2**. PR 3's row 4.4 can tell the two
  print routes apart — they give 52 and 149. `make_domain_pair()` also builds
  cleanly for `"taylor"`, `"replicate"` and `"nonprob"`.
- **CRAN cookbook scan: none.** The PR's only changed `R/` file is
  `R/analysis-helpers.R`, and this commit does not touch it. All nine patterns
  in `r-package-profile.md` §CRAN cookbook scan return zero hits.
- **No new `test_invariants()` call.** That is what §Invariants requires.

---

## Before/After Comparison

Taken from the dispatch baseline for tree `7bd2712`. I re-ran no gate.

| Metric | Before PR (`8664d86`) | After PR (`7bd2712`) | Δ |
|---|---|---|---|
| tests passing | 11825 | 11891 | +66 |
| tests failing | 0 | 0 | 0 |
| tests warning | 256 | 256 | 0 |
| tests skipped | 4 | 4 | 0 |
| coverage | 96.14% | 96.15% | +0.01% |
| R CMD check notes | 2 | 2 | 0 |

Coverage sits in the 95–98% band and it rose, so there is no HOLD and no BLOCK
on coverage. `R/analysis-helpers.R` reads 97.26%; its uncovered lines are 953,
959, 960, 1108 and 1154, none of them in `.apply_domain()`.

---

## Profile gates

All seven ran in the foreground on tree `7bd2712` before dispatch. I re-ran
none, per the low-memory watchdog rule.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing |
| devtools::test() | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11891`; warnings flat against the baseline, per the spec's "no new warning" reading |
| devtools::run_examples() | PASS | clean |
| R CMD build | PASS | tarball produced |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — CRAN incoming feasibility (pre-approved), and the `.git` hidden file (pre-existing, caused by `.Rbuildignore`, outside this PR's reach) |
| pkgdown | PASS | clean |
| covr | 96.15% | +0.01% against the baseline; above the 95% floor |
| CRAN cookbook scan | PASS | no violations in `R/analysis-helpers.R` |

Full logs:
`.surveycore-workspace/runs/2026-09-12-domain-marker-logical/gates/pr-4-r2/`

Tree: 7bd2712a3248840dd69bf7a8a6bc1b38eb1ac079

Targeted runs I made, both in the foreground: one inspection script over the
fixture, the `arm` column and the coefficient table; and one
`testthat::test_file("tests/testthat/test-analysis-helpers.R")` under a
deliberately regressed `.apply_domain()`. No file under `R/` was edited;
`git status --porcelain R/` prints nothing.

---

## BLOCKs

None. The two BLOCKs raised against tree `939c70e` are cleared. This is the
PR's first PASS and its second audit, so one BLOCK cycle of the three was
used.

---

## Notes carried forward, not blocking

1. `make_domain_pair()` writes three `NA` elements where the §Fixture helpers
   contract says "exactly one", and one of the three (row 130) sits where the
   mask would otherwise be `FALSE` rather than `TRUE`. Three `NA` rows assert
   strictly more than one, and `sum(mask)` stays the in-domain count that PR
   3's rows 5.2 and 5.3 will read. PR 3 reads this helper without changing it,
   so a later reader needs to know the count is three.
2. `with_factor_group()` closes one indirect detection channel — a divergent
   factor level set under a regression. The blocks stay red on the numbers
   alone, so nothing is lost, but a later reader should not treat those two
   blocks as level-set cover.
3. The builder's report of two failures at `test-analysis-helpers.R:1429` and
   `:1430` (`print.survey_result()` header) matches what I saw in my own
   `Rscript` probe last round. The coordinator settled it: the full
   `devtools::test()` gate reports `FAIL 0` on this tree and names no failure
   at those lines. I did not re-investigate.
