# Audit — PR 2: as-svydesign-domain-edge-cases

**Verdict: PASS**

Tree: `97414b3b726c7538fcfe360d6254c64873e8b1fc`
Branch: `test/as-svydesign-domain-edge-cases` @ `7ee6d53`

## Profile gates

Gates were run by the dispatching agent (memory-constrained host); this
audit accepts the printed summary and does not re-run them.

| Gate | Result | Detail |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; NAMESPACE/man/ unchanged |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11706 |
| `devtools::run_examples()` | PASS | 0 Error lines, 0 Execution halted |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran` | PASS | 2 NOTEs (CRAN incoming feasibility; pre-existing `.git` hidden-file note) |
| `pkgdown` | SKIPPED — scope | Write surface is one test file (`tests/testthat/test-conversion.R`); touches none of `R/`, `vignettes/`, `README`, `_pkgdown.yml`, `DESCRIPTION`, per `r-package-profile.md` skip condition |
| `covr::package_coverage()` | PASS | 96.25% |

WARN 256 is the pre-existing AAPOR small-cell warning baseline (D12 in the arc's decisions), not a new regression.

## Per-row result table

All eleven claimed rows are satisfied by blocks in
`tests/testthat/test-conversion.R` on this tree (lines 3053-3506). Per the
dispatch instruction, authorship (whether the block landed with PR #1 or this
PR) is not part of the verdict — only whether the block exists and passes.

| Row | Test block (line) | Assertion required | Assertion present | Pass |
|---|---|---|---|---|
| D-2a | 3388 "converts an all-FALSE marker to a zero-row object" | 0 rows, no condition, svymean = 0 / SE 0 | `expect_no_condition`, `nrow==0`, `coef==0` (1e-10), `SE==0` (1e-8) | ✓ |
| D-3 | 3408 "converts a single-TRUE marker to a one-row object" | 1 row, no condition | `expect_no_condition`, `nrow==1L` | ✓ |
| D-4 | 3370 "treats an NA marker row as outside the domain" | row count = count of TRUE (NA rows absent) | `expect_identical(nrow, sum(mask, na.rm=TRUE))` | ✓ |
| D-5a | 3426 "converts an all-NA marker to a zero-row object" | 0 rows, no condition (equiv. D-2a) | `expect_no_condition`, `nrow==0`, plus the D-2a-equivalent svymean checks | ✓ |
| D-6 | 3313 "selects the same rows for every marker column type" — `integer` case | 1 row per `1`, no condition | loop: `expect_no_condition`, `expect_identical(nrow, sum(mask))` at `nm="integer"` | ✓ |
| D-6a | same loop — `character` case ("TRUE"/"FALSE") | no condition, row count via `expect_identical` | `expect_no_condition`, `expect_identical(nrow, sum(mask))` at `nm="character"` | ✓ |
| D-6b | same loop — `factor` case, `factor(mask, levels=c(FALSE,TRUE))` | row count **and** every probability finite, no condition | `expect_no_condition`; `expect_identical(nrow, sum(mask))`; `expect_true(is.numeric(sv$prob) && all(is.finite(sv$prob)))` — see note below | ✓ |
| D-6c | 3353 "reads an unconvertible marker as an empty domain" | 0 rows, no condition | `expect_no_condition`, `expect_identical(nrow, 0L)` | ✓ |
| E-1 | 3445 "as_tbl_svy() inherits the restriction on a filtered Taylor design" | `tbl_svy`, one row per marked row | `expect_true(inherits(ts,"tbl_svy"))`, `expect_identical(nrow(ts$variables), sum(mask))` | ✓ |
| F-4 | 3462 "the round trip … agrees on the numbers [numerical]" | point, SE, both CI bounds agree | `expect_equal` mean (1e-10), se (1e-8), ci_low/ci_high (1e-6) | ✓ |
| F-5 | 3486 "the round trip … prints n of n rows" | marker column all-TRUE in rebuilt data, `Domain: n of n rows` printed | `expect_true` column present, `expect_true(all(...))`, `grepl` on captured print output | ✓ |

## D-6b — closer look, as requested

The row-spec text: "the row asserts the row count **and** that every
probability in the converted object is finite" — guarding against the
measured failure where an uncoerced factor marker produced an all-`NA` mask,
an object that kept every row, and a probability vector "neither finite nor
infinite."

The actual block (`tests/testthat/test-conversion.R:3313-3347`) is a shared
loop over five marker types (`logical`, `integer`, `double`, `character`,
`factor`). For every type, including `factor`, it runs three checks per
iteration:

```r
expect_no_condition(sv <- as_svydesign(d))
expect_identical(nrow(sv$variables), sum(mask), info = nm)
expect_true(is.numeric(sv$prob) && all(is.finite(sv$prob)), info = nm)
```

This is not the row-count-and-no-condition-only pattern the dispatch warned
about — the third line is the named property itself, present and combined
into one `expect_true()` so a list-valued `prob` (the corrupt state) fails
here rather than throwing inside `is.finite()`. On the guarded-against state
(all-`NA` mask from `&`, all rows kept, non-numeric/non-finite `prob`), both
`is.numeric(sv$prob)` and `all(is.finite(sv$prob))` would be `FALSE` or the
expression would short-circuit to `FALSE`, so this assertion would fail on
that state. D-6b is fully satisfied, not half-satisfied.

## CRAN cookbook violations

None. `git diff --name-only origin/develop...HEAD` shows one changed file,
`tests/testthat/test-conversion.R`; no `R/` file is touched by this PR, so
there is nothing to scan.

## Before/After comparison

Before column is the "immediately before this PR" baseline in the dispatch
(previous PR in the arc, PR #1, already merged to this branch's parent).

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11686 | 11706 | +20 |
| tests failing | 0 | 0 | 0 |
| coverage | 96.25% | 96.25% | 0 |
| R CMD check notes | 2 | 2 | 0 |

No regression in tests-passing or coverage. The four `covr`-reported
uncovered lines in `R/analysis-means-helpers.R` and `R/methods-conversion.R`
are pre-existing defensive branches unrelated to this PR's one-file test-only
diff, per the dispatch note on the stale local `develop` ref.

## Tolerance integrity

All numeric comparisons found in the eleven audited rows use exactly the
test-spec's tolerances: point 1e-10, SE 1e-8, CI bounds 1e-6. No tolerance
was found looser than specified, and no hand-computed expected value was
found where an oracle (`survey::svymean()`) was available and unused.

## Verdict

**PASS.** All eleven claimed rows are present, correctly asserted, and
passing. Profile gates clean (pkgdown justifiably skipped). No CRAN cookbook
violations (no `R/` files changed). No regression before/after. Tolerances
match the test-spec exactly.
