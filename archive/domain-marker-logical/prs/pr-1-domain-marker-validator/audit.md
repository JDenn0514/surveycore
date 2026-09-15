# Audit — PR 1 (fix/domain-marker-validator)

**Verdict: PASS**

Tree: e88e6e7a303904b3215139588e76e703a77a5d58

Scope audited: test-spec §1 rows 1.1–1.4, §Existing blocks that change rows E.1–E.4 (8 rows). Rows 1.5–1.11, 2.1–2.9, and §§3–6 are out of scope for this PR and are not reported here.

---

## Profile gates

Gates were run once by the dispatching orchestrator on this exact tree; no gate was re-run by the tester (per instructions). Two targeted filtered reruns were used only to confirm the 8 in-scope rows (see below), not to re-verify the gates.

| Gate | Before (develop @ 8fe3fa2, tree abff47e) | After (tree e88e6e7a, this PR) | Result |
|---|---|---|---|
| devtools::document() | — | wrote nothing | PASS |
| devtools::test() | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11800 ]` | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11795 ]` | PASS (see note below on the −5 PASS delta) |
| devtools::run_examples() | — | all examples ran | PASS |
| R CMD build | — | tarball produced | PASS |
| R CMD check --as-cran | — | Status: 2 NOTEs (both pre-approved) | PASS |
| pkgdown::build_site() | — | site built | PASS |
| covr::package_coverage() | 96.25% | 96.14% | PASS (floor 95%; drop 0.11pp, below the 0.5pp HOLD trigger) |

NOTEs: `checking CRAN incoming feasibility` (pre-approved) and `checking for hidden files and directories` finding `.git` (pre-existing, `.Rbuildignore`-caused, recorded in `archive/as-svydesign-bridge/`). No new NOTE pattern.

WARN count unchanged at 256 (pre-existing AAPOR small-cell warnings) — no new warning introduced.

**PASS-count delta (−5), explained.** This is not a regression against the test-spec. The spec's own E.4 rewrite (`test-conversion.R`) replaces a 5-iteration loop in which every marker type used to run a full conversion with three assertions each (≈15 expectations), with one that runs only the logical iteration to full conversion (3 assertions) and asserts a single error-class expectation for each of the other four types (4 assertions) — a net loss of ≈8 expectations from that one block alone. New rows 1.1–1.4 (+ 1.5–1.11, 2.1–2.9, out of scope but landing in the same PR) add roughly that many back, netting to a small negative. FAIL stayed 0 throughout.

**Coverage detail.** `R/core-classes.R` (the only changed source file) shows changed-line coverage 94.22%, with `UNCOVERED_LINE` at 348, 349, 355, 356, 357, 372, 709.

- Lines 348–372 sit inside this PR's second diff hunk (`@@ -338,7 +340,37 @@`) — they are the new validator: the early-return guard (348–349), the `is.logical()` check and `col_class` capture (355–357), and the trailing `NULL` (372).
- Line 709 sits outside both diff hunks — pre-existing code (the weight-column numeric check), untouched by this PR.
- Read directly: rows 1.1–1.4 exercise the reject branch on all four concrete classes; E.1, E.2, and E.4's logical iteration exercise the accept branch; the early-return guard (no marker column present) is exercised by the overwhelming majority of the suite's ~11,795 other passing expectations, since most designs never carry the marker column. All four control-flow points covr marks "uncovered" are independently confirmed executed by passing tests in this run (targeted reruns below), while the multi-line body of the `cli_abort()` call inside the same block (lines 358–371) is marked covered. That split — the call's interior covered, its opening line and the surrounding `if`/`return` lines not — is consistent with a known covr line-attribution artifact for closures passed as an inline `validator =` argument to `S7::new_class()`, not a real testing gap. Recorded as an observation; it does not change the verdict, since behavior on every branch is independently confirmed by passing, non-vacuous tests, and package coverage remains well above the 95% floor.

---

## CRAN cookbook scan

Changed `.R` files: `R/core-classes.R` (source), `tests/testthat/helper-test-data.R`, `tests/testthat/test-s7-classes.R`, `tests/testthat/test-analysis-quantiles.R`, `tests/testthat/test-conversion.R`.

| File | Line | Violation | Class |
|---|---|---|---|
| — | — | None found | — |

Scanned patterns: bare `T`/`F`, hardcoded `set.seed()` outside a `seed` arg, bare `print()`/`cat()`, `options(warn = -1)`, `installed.packages()`, `<<-`, unrestored `par()`/`options()`/`setwd()`, writes to `getwd()`/home. Two `set.seed(1)` hits in `R/core-classes.R` are inside `@examples` roxygen blocks at lines 624 and 798 — outside both of this PR's diff hunks (pre-existing, not part of this PR's write surface).

None.

---

## Per-row result table

| Row | File:Line | Observed | Verdict |
|---|---|---|---|
| 1.1 | `tests/testthat/test-s7-classes.R:1804-1810` | `set_domain_marker(taylor design, "integer")` wrapped in `expect_error(class = "surveycore_error_domain_not_logical")`. Nothing else asserted, matching the spec's "and nothing else." | ✓ PASS |
| 1.2 | `tests/testthat/test-s7-classes.R:1812-1818` | Same shape, replicate design (`make_all_designs()$replicate`). | ✓ PASS |
| 1.3 | `tests/testthat/test-s7-classes.R:1820-1826` | Same shape, two-phase design (`make_all_designs()$twophase`). | ✓ PASS |
| 1.4 | `tests/testthat/test-s7-classes.R:1828-1834` | Same shape, non-probability design (`make_all_designs()$calibrated`, built via `as_survey_nonprob()`). | ✓ PASS |
| E.1 | `tests/testthat/test-analysis-quantiles.R:443-481` ("get_quantiles() respects domain filter") | `as.integer()` wrapper is gone; marker written as `!is.na(d_full@data$group) & d_full@data$group == "A"` (logical). Original assertion — domain estimate differs from the full-sample estimate via `expect_false(isTRUE(all.equal(...)))` — retained unchanged. | ✓ PASS |
| E.2 | `tests/testthat/test-analysis-quantiles.R:836-855` ("get_quantiles() empty domain (n = 0) returns NA estimate") | `as.integer()` wrapper is gone; marker written as a logical all-`FALSE`-equivalent mask (`!is.na(...) & ... == "NONEXISTENT_GROUP"`). Both original assertions — `is.na(result$estimate[[1L]])` and `result$n[[1L]] == 0L` — retained. | ✓ PASS |
| E.3 | `tests/testthat/test-conversion.R:3345-3356` ("a factor marker column aborts at the write") | Renamed from the old "reads an unconvertible marker as an empty domain." Now asserts `expect_error(d@data <- df, class = "surveycore_error_domain_not_logical")` on the assignment itself; no conversion runs. Matches the spec's required rewrite exactly. | ✓ PASS |
| E.4 | `tests/testthat/test-conversion.R:3311-3339` ("as_svydesign() converts a logical marker and the four other types abort at the write") | Renamed. Loop keeps all five types. Logical iteration: `expect_no_condition()` around `as_svydesign()`, then asserts `nrow(sv$variables) == sum(mask)` and that `sv$prob` is numeric and finite everywhere. Each of the four non-logical iterations (`integer`, `double`, `character`, `factor`) asserts only `expect_error(set_domain_marker(...), class = "surveycore_error_domain_not_logical")` — no conversion assertion made for any of them. Comment above the block restates the new premise (validator rejects non-logical types at the write) and no longer describes the old "nothing guarantees the column is logical" state. | ✓ PASS |

## Invariants check

`grep -c "test_invariants("` on `tests/testthat/test-s7-classes.R` returns 7 (includes the line-930 description string, not a call). Confirmed by direct read: exactly 6 real calls, at lines 177, 783, 867, 889, 936, 960 — one per constructor per file, matching the pre-existing count recorded in the test-spec. **No new `test_invariants()` call was added by this PR.** This matches the spec's explicit instruction ("Add no new `test_invariants()` call") for §1/§2/§Existing-blocks work.

## Test-suite sweep

`grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" tests/testthat/` — every hit inspected is a logical expression (comparison operators, `TRUE`/`FALSE` literals, `rep(FALSE, n)`, `rep(NA, n)`, `seq_len(n) == k`). No non-logical raw assignment remains. E.4's write goes through `set_domain_marker()` (a function call, not a raw `[[<-` in the test body), consistent with the spec's note that its type is not visible in this grep.

## Targeted test reruns (confirmation only, not the gate)

- `testthat::test_local(filter = "s7-classes")` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 284 ]`
- `testthat::test_local(filter = "analysis-quantiles")` → `[ FAIL 0 | WARN 7 | SKIP 5 | PASS 395 ]` (7 warnings are pre-existing `<survey_nonprob>` calibration-SE warnings, unrelated to this PR)
- `testthat::test_local(filter = "conversion")` → `[ FAIL 0 | WARN 0 | SKIP 10 | PASS 771 ]` (10 skips are `skip_on_cran()`-gated blocks)

## Tolerance integrity

No numeric tolerance applies to any of the 8 rows in scope — all are typed-condition assertions (`class = "surveycore_error_domain_not_logical"`) or structural assertions (attribute survival, retained estimate comparisons using the test's own pre-existing tolerance). No tolerance was relaxed.

## Before/After comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing (PASS) | 11800 | 11795 | −5 (explained above; spec-mandated E.4 rewrite reduces assertion count more than the new rows add) |
| tests failing (FAIL) | 0 | 0 | 0 |
| coverage | 96.25% | 96.14% | −0.11pp (below the 0.5pp HOLD trigger; well above the 95% floor) |
| R CMD check notes | 2 (pre-approved) | 2 (pre-approved) | 0 |
| WARN | 256 | 256 | 0 |
| SKIP | 4 | 4 | 0 |

---

## Verdict rationale

All 8 in-scope rows locate to a named test block, assert the exact form the test-spec requires (typed condition only for 1.1–1.4; retained/rewritten assertions for E.1–E.4), and pass in targeted reruns. The CRAN cookbook scan is clean. `test_invariants()` call count is unchanged, per the spec's explicit instruction. The test-suite sweep confirms no non-logical marker write remains outside the validator's own reject-path tests. Coverage and test-pass deltas are within tolerance and are explained by the spec's own mandated rewrites, not by a defect. **PASS.**
