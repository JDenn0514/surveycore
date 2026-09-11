# Audit — PR 1: as-svydesign-domain-taylor

Verdict: **PASS**

Tree: a2f6baac6d514b1cc33739cdd66831e394425333
HEAD: a65674e0511ebc76a99d9d52fd3164418337de09 (branch `fix/as-svydesign-domain-taylor`, rebased onto develop @ 24220af)

BLOCK cycles: 1 (raised on tree `c6a71a2d...` over row C-1, resolved on this
tree by a one-block test fix). This audit supersedes the prior BLOCK.

## Scope

Audited rows only, per dispatch: A-1, A-4, A-5, A-6, C-1, D-1, D-8, F-1, F-2,
F-3, G-1a. All eleven rows live in `tests/testthat/test-conversion.R`, in the
"Domain restriction on the Taylor route" section (line 3053 onward).

Marker-column-type test blocks (integer, character, factor, `NA`, all-`FALSE`)
seen in the same section belong to later PRs (the D-2/D-5/D-6 group). Noted,
not audited here, per instruction.

## Re-audit of C-1 (this cycle)

`git diff 478b09d..a65674e` is exactly one file, `tests/testthat/test-
conversion.R`, one hunk:

```diff
 test_that("as_svydesign() converts an unfiltered Taylor design unrestricted", {
   skip_if_not_installed("survey")
   d <- make_taylor()
-  sv <- as_svydesign(d)

+  # No marker column means no indexing step, so nothing at all fires here.
+  # The filtered case has the same requirement and no pre-existing condition
+  # to tolerate either.
+  expect_no_condition(sv <- as_svydesign(d))
   expect_identical(nrow(sv$variables), nrow(survey_data(d)))
   expect_false(surveycore::SURVEYCORE_DOMAIN_COL %in% names(sv$variables))
 })
```

- The missing assertion is now present: `expect_no_condition()` wraps the
  conversion call. `expect_no_condition()` is testthat's assertion that no
  condition of any kind — message, warning, or error — is signaled during
  the wrapped expression; it fails the test if any is. This is a real check,
  not a no-op: any warning or message raised on this path would now fail
  the block, where before the change it would have passed silently.
- The two previously-passing assertions (row count via `expect_identical()`,
  column absence via `expect_false()`) are byte-identical to the prior tree,
  unmoved and unreordered relative to each other — only the new line was
  inserted above them.
- Nothing else in the file moved: `git diff 478b09d..a65674e --stat` shows
  1 file changed, 4 insertions, 1 deletion — all four in this one block.

C-1 now asserts all three things the row specifies: one row per design row,
marker column absent, and no condition raised. **C-1: ✓**

## Profile gates (this tree, `a2f6baa`)

Not rerun — orchestrator-supplied results accepted per dispatch instruction
(low-memory machine; do not run gates).

| Gate | Result | Detail |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11686 |
| `devtools::run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran` | PASS | 2 NOTEs — CRAN incoming feasibility, pre-existing `.git` hidden-file NOTE — both pre-approved |
| `pkgdown::build_site()` | **SKIPPED — scope** | Passed on the prior tree (`2e14b3b`-derived). Only change since is one test file; pkgdown builds from `R/`, `vignettes/`, `README`, `_pkgdown.yml`, all byte-identical between the two trees, so a rerun reads nothing that changed. Skip judged justified. |
| `covr` | PASS | 96.25% package |

`covr` changed-file note: `run-gates.sh`'s changed-file list is computed
against local `develop` pinned at `a545505` (stale — another worktree has
`develop` checked out), not `origin/develop`. Against `origin/develop` this
PR changes exactly one R file, `R/methods-conversion.R`. Its sole uncovered
line is 571, a pre-existing defensive `return(NULL)` in `.find_col_by_value`,
outside all three of this PR's diff hunks — not a coverage gap this PR
introduces. Recorded as a measurement artifact, not a finding.

Targeted confirmation run (permitted by dispatch), this session:
`NOT_CRAN=true Rscript -e 'devtools::test(filter = "conversion")'` →
`FAIL 0 | WARN 0 | SKIP 0 | PASS 676`. Matches the expected 676/0 (675 on
the prior tree, +1 for the new assertion — consistent with exactly one
assertion added, no other test disturbed).

## Per-Test Result Table

| Row | Test block | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|---|
| A-1 | "converts a filtered Taylor design to the domain [numerical]" (L3082) | point + SE match `get_means()`; row count = `sum(mask)` | point 1e-10, SE 1e-8 | as specified | ✓ |
| A-4 | "converts a filtered plain-shaped nonprob to the domain [numerical]" (L3150) | `survey::SE(sm)` vs `sc$se` direct comparison, `tolerance = 1e-8`; plus second oracle cross-check against Taylor route; marker presence + all-TRUE assertions present | real oracle parity, not a ratio | SE 1e-8 | ✓ |
| A-5 | "converts a filter()-marked Taylor design to the domain [numerical]" (L3103) | point + SE match `get_means()` on `surveytidy::filter()`-marked design | point 1e-10, SE 1e-8 | as specified | ✓ |
| A-6 | "converts a filtered nhanes design to the domain [numerical]" (L3122) | point + SE match `get_means()` on `nhanes_2017` | point 1e-10, SE 1e-8 | as specified | ✓ |
| C-1 | "converts an unfiltered Taylor design unrestricted" (L3204) | row count identical, marker column absent, `expect_no_condition()` on the call | all three assertions the row specifies | — | ✓ |
| D-1 | "converts an all-TRUE marker to every row [numerical]" (L3217) | row count = full; point + SE match `get_means()` | point 1e-10, SE 1e-8 | ✓ |
| D-8 | "leaves the input design unchanged" (L3236) | input row count and marker column identical before/after; two calls give identical converted row counts | structural, `expect_identical()` | ✓ |
| F-1 | "the round trip on a filtered Taylor design recovers the design variables" (L3260) | `@variables[c("ids","strata","weights")]` identical between filtered and unfiltered round trip | `expect_identical()` | ✓ |
| F-2 | "the restriction leaves the converted object's stored call unchanged" (L3285) | `deparse(filtered$call)` identical to `deparse(unfiltered$call)` | `expect_identical()` | ✓ |
| F-3 | "the round trip on an unfiltered Taylor design names ids, strata and weights" (L3272) | `rebuilt@variables$ids/strata/weights` identical to known names | `expect_identical()` | ✓ |
| G-1a | "as_svydesign() raises no condition on a filtered Taylor design" (L3297) | `expect_no_condition(sv <- as_svydesign(make_filtered_taylor()))` | `expect_no_condition()` exactly as row specifies | ✓ |

**11 of 11 rows pass, all at the tolerances the test-spec specifies.**

## CRAN cookbook scan

Changed `R/` file across the whole PR (unchanged from prior cycle — this
cycle's commit touches only the test file): `R/methods-conversion.R`, the
`.restrict_to_domain()` addition and its two call sites.

None. No `T`/`F` abbreviation, no hardcoded `set.seed()`, no bare
`print()`/`cat()`, no `options(warn = -1)`, no `installed.packages()`, no
`<<-`, no unrestored `par()`/`options()`/`setwd()`, no home-directory write,
no `mc.cores`/`makeCluster` over 2.

## Before/After Comparison Table

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11606 | 11686 | +80 |
| tests failing | 0 | 0 | 0 |
| WARN | 256 (pre-existing AAPOR) | 256 | 0 |
| coverage (package) | 96.24% | 96.25% | +0.01% |
| `R CMD check` NOTEs | 2 (pre-approved) | 2 (pre-approved) | 0 |

No regression in tests-passing or coverage. Coverage delta is well inside
tolerance and does not trigger the HOLD or BLOCK coverage thresholds.

## Verdict rationale

PASS. All eleven audited rows now have a test block asserting exactly what
the row specifies, at the specified tolerance, and all pass. The one BLOCK
raised this arc (row C-1, missing "raises no condition" assertion) was
resolved by a single, correctly-scoped test-only edit that adds the missing
assertion without touching or weakening the two assertions already
verified. `pkgdown` is logged as a justified scope-skip, not a gap. CRAN
cookbook scan is clean. No before/after regression.
