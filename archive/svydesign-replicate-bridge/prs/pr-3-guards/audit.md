# Audit — PR 3 — svydesign-replicate-bridge (fix/svydesign-replicate-guards)

**Verdict**: PASS
**Date**: 2026-09-08 (tester run)
**Base**: `develop` at `4c79a5b` (carries PR 1 and PR 2)
**HEAD**: `c9c93ca`

## Scope

In-scope rows for this PR: C-1, C-2, C-3, C-4, C-5, C-10, C-11, C-12, C-13,
C-14 — the four import refusals and their snapshots. Confirmed-still-hold
rows from PR 1 and PR 2: I-1 to I-24, I-26 (row I-25 is a recorded
non-reachable state, test-spec §6.4; its absence is not a finding).

Out of scope, not scored: C-6, C-7, C-15, C-16 (FPC drop / empty-replicate
guard, PR 4); C-8, C-9, C-17, C-18 (Fay shrinkage refusals, PR 5); all
E-rows and R-rows (export route and full round trip, PR 4/5).

All fixtures were built directly from `test-spec.md` §3 recipes via
individual synchronous `Rscript` calls against the merged tree
(`devtools::load_all()`, no gates). No gate command was run by this agent —
gate results below are the coordinator's, supplied in the dispatch.

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| C-1 class on partly named matrix (empty-string names) | `surveycore_error_repweights_names_lost` | same class | identical | ✓ |
| C-1 message text | "has 4 replicate weight columns but 2 usable column names" | matches CB-1 template | identical | ✓ |
| C-2 snapshot matches `_snaps/conversion.md` "rejects a partly named replicate matrix" | matches | matches | identical | ✓ |
| C-3 class on repeated-name matrix (second trigger, class only) | `surveycore_error_repweights_names_lost` | same class | identical | ✓ |
| C-4 class on generated-name collision (one collision) | `surveycore_error_repwt_name_collision` | same class | identical | ✓ |
| C-4 message singular form | "has a column named ..surveycore_repwt_2.." / "Rename the conflicting column" | singular at n=1 | identical | ✓ |
| C-5 snapshot matches `_snaps/conversion.md` "rejects one generated name..." | matches | matches | identical | ✓ |
| Collision message plural form (3 collisions, own re-derivation) | "has columns named ..., and ..." / "Rename the conflicting columns" | plural at n=3 | identical | ✓ |
| C-10 class on `subbootstrap` | `surveycore_error_replicate_type_unsupported` | same class | identical | ✓ |
| C-10/CB-5 message names offending type + all nine accepted values | `"JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", "successive-difference", and "other"` | all nine, exact set | identical | ✓ |
| C-11 snapshot matches `_snaps/conversion.md` "rejects a subbootstrap..." | matches | matches | identical | ✓ |
| C-12 class on `mrbbootstrap` (second trigger, class only) | `surveycore_error_replicate_type_unsupported` | same class | identical | ✓ |
| C-13 class on zero-row source | `surveycore_error_empty_data` | same class | identical | ✓ |
| C-14 snapshot matches `_snaps/conversion.md` "rejects a zero-row..." | matches | matches | identical | ✓ |
| Snapshot file holds exactly 4 snapshots (one per class, CB-1/CB-2/CB-5) | 4 | 4 | identical | ✓ |
| `plans/error-messages.md` diff is purely additive; Row 2 unedited | additive only, 36 lines added, 0 removed | additive only | identical | ✓ |
| `plans/error-messages.md` new section carries CB-1, CB-2, CB-5 + note that CB-3/CB-4 land later; CB-3/CB-4 absent | present as required | present as required | identical | ✓ |
| `test_invariants()` call count in `test-conversion.R` | 3 (lines 121, 754, 1157) — unchanged from PR 2 | 3, one per constructor per file | identical | ✓ |
| Guard regression check — I-1 point/SE/CI (Cell A, JKn compressed) | point/SE/CI match oracle | match | 1e-10/1e-8/1e-6 | ✓ |
| I-2 point/SE + fold-in (Cell B) | match; fold-in max abs diff 0 | match | 1e-10/1e-8/1e-12 | ✓ |
| I-3 point/SE (Cell C) | match | match | 1e-10/1e-8 | ✓ |
| I-4 point/SE (Cell D) | match | match | 1e-10/1e-8 | ✓ |
| I-5 repweights length == ncol(matrix) | TRUE | TRUE | identical | ✓ |
| I-6 all repweight names written into data | TRUE | TRUE | identical | ✓ |
| I-7 `get_means()` on converted design raises no error | no error | no error | identical | ✓ |
| I-8 zero-padded 20-replicate names (bootstrap, type check does not misfire) | matches | matches | identical | ✓ |
| I-9 unpadded 4-replicate names | matches | matches | identical | ✓ |
| I-10 base weight column name unchanged | "wt" | "wt" | identical | ✓ |
| I-11 fpc NULL, fpctype "fraction" | matches | matches | identical | ✓ |
| I-12 named finished-weight source, repweights == cols | identical | identical | identical | ✓ |
| I-13 named factor-form source, repweights == cols | identical | identical | identical | ✓ |
| I-14 compressed named source, length + data membership | TRUE/TRUE | TRUE/TRUE | identical | ✓ |
| I-15 JK1 flat design keeps genuine zeros | any(stored==0) TRUE | TRUE | n/a | ✓ |
| I-16 JKn design keeps genuine zeros | any(stored==0) TRUE | TRUE | n/a | ✓ |
| I-17 single-replicate name | `..surveycore_repwt_1..` | same | identical | ✓ |
| I-18 two-replicate names | `_1..`, `_2..` | same | identical | ✓ |
| I-19 NA in replicate column preserved | anyNA TRUE | TRUE | n/a | ✓ |
| I-20 rejects nonpositive base weight (unaffected by new guards) | class `surveycore_error_weights_nonpositive` | same class | identical | ✓ |
| I-21 base weight not confused with replicate column | `..surveycore_wt..` / not in repweights | same | identical | ✓ |
| I-22 variable labels preserved; no metadata entry for written columns | label present; no repweight entries | same | identical | ✓ |
| I-23 named columns not in `data`, still written correctly | repweights==cols; cols in data; value parity | same | identical/1e-12 | ✓ |
| I-24 stores replicate, not the unrelated same-named data column | repweights==cols; rw1 stored != unrelated -999 values | same | identical | ✓ |
| I-26 negative replicate weight preserved | any(stored<0) TRUE | TRUE | n/a | ✓ |
| Fay design (`type = "Fay"`) still converts under new type guard | no error | no error | n/a | ✓ (regression guard for PR 4/5's E-9/E-10/R-5) |

## CRAN cookbook violations

None. Scanned every line of `git diff 4c79a5b..c9c93ca -- R/methods-conversion.R`
(the only `R/` file this PR touches, 117 added lines: the type guard, the
empty-data guard, the names-usable guard, the collision guard) against all
nine patterns in `r-package-profile.md` §CRAN cookbook scan. Zero hits.
No `@importFrom` added. `NAMESPACE`, `man/`, `DESCRIPTION`, `_pkgdown.yml`
unchanged by this PR (`git diff 4c79a5b..c9c93ca` touches only
`R/methods-conversion.R`, `plans/error-messages.md`,
`tests/testthat/_snaps/conversion.md`, `tests/testthat/test-conversion.R`).

## Test organization note (not a finding)

`test-spec.md` §9 asks for the class assertion and the snapshot in separate
`test_that()` blocks. The committed blocks (e.g. "rejects a subbootstrap
replicate design", "rejects a partly named replicate matrix", "rejects one
generated name that already names a column") combine the `expect_error(class
= ...)` and `expect_snapshot(error = TRUE, ...)` calls for the same trigger
into one block instead of two. Per `decisions.md` D11, the plan's row-level
task list is advisory, not literally checkable against the merged file, and
the tester's job is to confirm each row's behaviour holds, not that block
counts or block boundaries match the plan. Both assertions are present and
both pass; this is not scored as a defect.

## Before/After Comparison

Before column is PR 2's After (`4c79a5b`), per PR 2's `audit.md` and this
run's dispatch.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11343 | 11366 | +23 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 (D12: gate reads FAIL count only; AAPOR small-cell ceiling held) |
| coverage (package) | 96.20% | 96.22% | +0.02% |
| coverage (`R/methods-conversion.R`) | 99.19% | 99.40% | +0.21% |
| R CMD check NOTEs | 2 | 2 | 0 |

No regression in tests-passing, coverage, or notes.

## Profile gates

Gates were run by the coordinator in the foreground on tree
`634f998aabb160c8369c7c11f4eaa8721a79617d`, per this run's standing
instruction (concurrent gate runs previously corrupted logs). Results as
supplied:

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | no `NAMESPACE` or `man/` drift |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11366 ]` — failures 0, warnings at the D12 ceiling of 256, not above it |
| `run_examples()` | PASS | exit 0 |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran --no-manual` | PASS | `Status: 2 NOTEs`, both pre-approved (`checking CRAN incoming feasibility`; hidden `.git`), 0 ERROR, 0 WARNING |
| `pkgdown::build_site(preview = FALSE)` | PASS | exit 0 |
| `covr::package_coverage()` | PASS | package 96.22% (rose from 96.20%); `R/methods-conversion.R` 99.40% (rose from 99.19%), 2 uncovered lines (138, 305) both pre-existing and outside this PR's added ranges (480–515, 518–537, 562–622); no `# nocov` added |
| CRAN cookbook scan | PASS | 0 hits (see above) |
| `air format --check` (PR files) | PASS | exits clean on this PR's files; `air::format_package()` cannot run here (CLI 0.11.0, not an R package, per D16) |

Logs: `gate-1-document.log` through `gate-7-covr.log`, in
`.surveycore-workspace/runs/2026-09-04-svydesign-replicate-bridge/logs/pr-3/`.

Tree: 634f998aabb160c8369c7c11f4eaa8721a79617d

## Verdict rationale

All ten in-scope rows (C-1, C-2, C-3, C-4, C-5, C-10, C-11, C-12, C-13,
C-14) fire the exact typed class test-spec.md requires, on the exact
trigger test-spec.md specifies, independently re-derived and run against the
merged tree. The four committed snapshots in `tests/testthat/_snaps/conversion.md`
match the messages this agent reproduced by running the code directly, and
the collision message pluralizes correctly in both numbers ("has a column
named" / "Rename the conflicting column" at one collision; "has columns
named" / "Rename the conflicting columns" at three, confirmed by an
independent re-derivation of the three-collision case). The type-unsupported
message names the offending type and all nine accepted values. `plans/error-
messages.md` gained a purely additive section carrying CB-1, CB-2, CB-5 with
a note that CB-3/CB-4 land later; those two rows are absent as required, and
the pre-existing Row 2 is untouched. `test_invariants()` still fires exactly
3 times across the file (once per constructor: `as_survey()`,
`as_svydesign()`, `from_svydesign()`), unchanged from PR 2.

The specific risk flagged in this run's dispatch — a guard refusing a source
design that an earlier row converts successfully — did not materialize:
every one of I-1 through I-24 and I-26 was re-run against the merged tree
and still passes at test-spec tolerance, including the bootstrap (I-8) and
Fay-type designs that pass through the new type-unsupported guard's accepted
set. CRAN cookbook scan is clean on the only `R/` file this PR touches. All
seven profile gates pass, with no new NOTE, no warning-count rise, and a
coverage rise in both the package and the touched file.

One organizational deviation from test-spec.md §9 (class assertion and
snapshot combined in one `test_that()` block rather than two, for three of
the four classes) is noted above and not scored as a defect, per D11.

## BLOCKs (if any)

None.
