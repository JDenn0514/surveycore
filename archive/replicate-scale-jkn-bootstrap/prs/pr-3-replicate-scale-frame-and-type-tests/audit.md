# Audit — PR 3 — replicate-scale-frame-and-type-tests

**Verdict**: PASS
**Date**: 2026-09-29 00:00

Rows judged: §1 rows 1.6, 1.7, 1.8, 1.9. Row 1.6 judged under erratum E-7
(SETTLED): a two-row frame replaces the impossible one-row frame, and the
single-row refusal becomes a fifth refusal, `class =` only.

Write surface: `tests/testthat/test-constructors.R` only, +260 / -0.
No file under `tests/testthat/_snaps/` changed. `test_invariants()` appears
4 times, unchanged.

Gates were run in the foreground by the orchestrator. This tester ran no
gate, per the dispatch. The Got column below reports what the blocks assert
and what the run reported, not a second execution.

## Per-Test Result Table

### Row 1.6 — frame shape does not reach the default (block at line 865; refusals at line 903)

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| two-row frame builds, JKn stored scale | `1` | `1` | default 1e-10 | ✓ |
| two-row frame builds, bootstrap stored scale | `1 / (n_rep - 1L)`, `n_rep = 20L` | `1 / 19` | default 1e-10 | ✓ |
| frame is the smallest buildable | `expect_identical(nrow(small), 2L)` | 2 rows | exact | ✓ |
| neither construction raises a condition | `expect_no_condition()` on both | no condition | n/a | ✓ |
| refusal 1 — zero-row frame | `surveycore_error_empty_data` | same | n/a | ✓ |
| refusal 2 — zero repweight columns | `surveycore_error_repweights_empty` | same | n/a | ✓ |
| refusal 3 — all-zero weight column | `surveycore_error_weights_all_zero` | same | n/a | ✓ |
| refusal 4 — wrong-length `rscales` | `surveycore_error_rscales_length` | same | n/a | ✓ |
| refusal 5 (E-7) — single-row frame, `type = "bootstrap"` | `surveycore_error_single_row` | same | n/a | ✓ |
| all five by `class =`, no new snapshot | 5 `expect_error(class =)`, 0 snapshots | §Error-path pattern | n/a | ✓ |
| frames built inline | both blocks build `data.frame()` inline | inline | n/a | ✓ |

Refusal 5 uses `type = "bootstrap"`, so it is not a duplicate of the
pre-existing JK1 single-row block. The comment in the block says so.

### Row 1.7 — the nine-type default table (block at line 977)

One frame, one design per `type`, no `scale`, `n_rep` pinned at `20L`.
Nine assertions, each against its own literal. Values checked against
test-spec §What this work changes and its following paragraph.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| `JK1` | `(n_rep - 1L) / n_rep` | `(R - 1) / R` | default 1e-10 | ✓ |
| `JK2` | `1` | `1` | default 1e-10 | ✓ |
| `JKn` (changed) | `1` | `1` | default 1e-10 | ✓ |
| `BRR` | `1 / n_rep` | `1 / R` | default 1e-10 | ✓ |
| `Fay` | `1 / n_rep` | `1 / R` (surveycore's own; #243 owns the gap) | default 1e-10 | ✓ |
| `bootstrap` (changed) | `1 / (n_rep - 1L)` | `1 / (R - 1)` | default 1e-10 | ✓ |
| `ACS` | `4 / n_rep` | `4 / R` | default 1e-10 | ✓ |
| `successive-difference` | `4 / n_rep` | `4 / R` | default 1e-10 | ✓ |
| `other` | `1` | `1` | default 1e-10 | ✓ |
| nine assertions, no value compared to another value | each vs a literal expression in `n_rep` | nine literals | n/a | ✓ |

No assertion in this block reads one stored scale against another.

### Row 1.8 — the content of the frame (blocks at line 1013 and line 1055)

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| Frame 1 shape | 10 rows, 8 replicate columns, inline | ≥4 rows, ≥3 columns, inline | n/a | ✓ |
| Frame 1 — `1 / (n_rep - 1)` is neither 1 nor Inf | `1 / 7` | neither | n/a | ✓ |
| Frame 1 — outcome NA in every row | `expect_true(all(is.na(d_jkn@data$y1)))` | all NA | n/a | ✓ |
| Frame 1 — JKn builds, stored scale | `1` | `1` | default 1e-10 | ✓ |
| Frame 1 — bootstrap builds, stored scale | `1 / (n_rep - 1L)` = `1 / 7` | `1 / (R - 1)` | default 1e-10 | ✓ |
| Frame 1 — neither raises a condition | `expect_no_condition()` on both | no condition | n/a | ✓ |
| Frame 1 — stored `rscales` unchanged, both types | `expect_equal(..., rsc)` twice | supplied vector | default 1e-10 | ✓ |
| Frame 2 shape | 6 rows, 4 replicate columns, inline | ≥4 rows, ≥3 columns, inline | n/a | ✓ |
| Frame 2 — weight column mixes zeros with positives | `c(0, 3.1, 2.8, 0, 3.4, 2.9)` | mixed | n/a | ✓ |
| Frame 2 — JKn refused | `surveycore_error_weights_nonpositive` | same | n/a | ✓ |
| Frame 2 — bootstrap refused | `surveycore_error_weights_nonpositive` | same | n/a | ✓ |
| Frame 2 — no stored `scale` asserted | 0 `scale` assertions in the block | none | n/a | ✓ |
| Frame 2 — `class =` only, no snapshot | 2 `expect_error(class =)`, 0 snapshots | §Error-path pattern | n/a | ✓ |

The zero-weight refusal class is distinct from row 1.6's wholly-zero column:
`surveycore_error_weights_nonpositive` here, `surveycore_error_weights_all_zero`
there. Both blocks say so in a comment.

### Row 1.9 — the two-phase copy (block at line 1613)

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| frame carries a logical `subset` column | `df$in_phase2 <- rep(c(TRUE, FALSE), ...)` | logical | n/a | ✓ |
| JKn two-phase builds, no condition | `expect_no_condition()` | no condition | n/a | ✓ |
| bootstrap two-phase builds, no condition | `expect_no_condition()` | no condition | n/a | ✓ |
| `phase1$type` carried, JKn | `"JKn"` | `"JKn"` | exact | ✓ |
| `phase1$type` carried, bootstrap | `"bootstrap"` | `"bootstrap"` | exact | ✓ |
| `phase1$scale`, JKn | `1` | `1` | **1e-8, written** | ✓ |
| `phase1$scale`, bootstrap | `1 / (n_rep - 1L)` = `1 / 19` | `1 / (R - 1)` | **1e-8, written** | ✓ |
| each against its own literal, never one against the other | two separate `expect_equal()` vs literals | two literals | n/a | ✓ |

The tolerance row 1.9 names is `1e-8`, and both assertions carry
`tolerance = 1e-8` in the source. No tolerance in this PR was changed,
widened, or omitted where the row names one.

## Tolerance integrity

- Row 1.9 names `1e-8`. Both of its scale assertions write it. Measured, not
  inferred: the two `tolerance = 1e-8` occurrences are the only tolerance
  arguments the diff adds.
- Rows 1.6, 1.7 and 1.8 name no tolerance. Their assertions are bare
  `expect_equal()`, which is the settled house form beside the 16
  pre-existing stored-scale assertions in the same file. No BLOCK.
- Structural assertions use `expect_identical()`; numeric ones use
  `expect_equal()`, per `testing-standards.md` §Assertions.

## CRAN cookbook violations

None. The PR changes no file under `R/` — the `R` subtree hash is identical
to base at `164f0348ba796fb5af5192b8b8cd6a3d260f0099`. The scan was run over
the added lines of the one changed file anyway: zero hits for `T`/`F` as
logicals, `<<-`, `installed.packages(`, `options(warn = -1`, `setwd(`,
`mc.cores`, `makeCluster`, and bare `print(`/`cat(`.

## Before/After Comparison

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12028 | 12065 | +37 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0.00% |
| R CMD check notes | 2 | 2 | 0 |

Coverage holds. The 95% floor is clear by 1.15 points. The 98% target is not
met before or after; this PR neither causes nor widens that gap, and it adds
no line under `R/`.

## Profile gates

Run in the foreground by the orchestrator. Concurrent heavy R runs corrupt
each other's `.Rcheck` trees on this host, so this tester ran none.
Logs: `.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-3/`.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing, base and PR |
| devtools::test() | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12065`; the 256 are the pre-existing AAPOR small-cell warnings, so the gate reads "no new warning" |
| devtools::run_examples() | PASS | base and PR |
| R CMD build | PASS | |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — the pre-approved pair, `CRAN incoming feasibility` and hidden files/directories. Same two as base. A third would block; there is none |
| pkgdown | SKIPPED | test-only PR: no roxygen, `man/` or `NAMESPACE` change. CI runs it. Justified skip under `r-package-profile.md` |
| covr | 96.15% | no drop vs base 96.15%; floor 95% clear. The log's "changed R/ files: 1" is a stale local `develop` ref artifact — the `R` subtree hash is byte-identical to base, and the 3 uncovered lines are pre-existing |
| CRAN cookbook scan | PASS | no `R/` file changed; scan of the added test lines found 0 hits |

Tree: 238d54252846e5db73b623fa9114703a3bffd65c

## Notes for the reviewer

1. **Row 1.6 was judged under erratum E-7**, which the orchestrator settled
   and recorded in `decisions.md`. A one-row frame cannot be built:
   `.validate_data()` raises `surveycore_error_single_row` at
   `R/core-validators.R:109`, ahead of the scale switch, and
   `tests/testthat/test-constructors.R` has pinned that refusal since PR #76.
   The block uses two rows and asserts the single-row refusal as a fifth
   refusal. Criterion 2 was judged as five refusals, not four.
2. **One class-only assertion has no snapshot anywhere behind it.**
   `surveycore_error_weights_all_zero` raised by `as_survey_replicate()` is
   on no snapshot in the repository; the message text is recorded for
   `as_survey()` only. The test-spec §Error-path pattern authorises the gap,
   issue #291 owns it, and closing it here would change a file under
   `tests/testthat/_snaps/`, which row 4.5 forbids. Naming it here is the
   report the test-spec asks for.
3. **Mutation evidence is builder-reported and not re-run.** JKn reverted
   reddens the two-row assertion, exactly one of the nine-type assertions,
   and the two-phase JKn assertion; the bootstrap revert reddens the
   matching three, non-overlapping. Read as written, each of the four rows
   would turn red on a wrong default, because every one asserts the stored
   `scale` against a literal rather than against another stored value.

## BLOCKs

None.

## HOLDs

None.
