# Audit — PR 5 — replicate-scale-release-notes

> **On the `[no such file]` marker below.** The test-spec it cites sat in the
> plans directory while the arc was in flight. Archiving moved it in beside
> this file, under the same name, so the path in the citation no longer
> resolves although the document is right here. The marker is the closer of
> the two the citation checker accepts; neither can say "archived under a
> different path". Nothing was lost.

**Verdict**: PASS
**Date**: 2026-09-29 00:00

Scope: `plans/test-spec-replicate-scale-jkn-bootstrap.md` [no such file] §4, rows 4.5 and 4.6.
This PR writes prose only. `git diff dde0f8a..HEAD --stat` gives two files:
`NEWS.md` (+22) and `changelog/fix-replicate-scale-jkn-bootstrap.md` (+141, new).

## Per-Test Result Table

Row 4.5 — suite regression. Swept by file name against the arc base `076bafe`
(`d11d1f8^`), not by commit range, because every PR merged by squash.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 4.5 files changed under `tests/` arc-wide | `test-constructors.R`, `test-variance-replicate.R`, `test-nonprob-bootstrap-variance.R`, `test-analysis-corr.R` | the two named files plus the two added by erratum E-2 | exact | ✓ |
| 4.5 files changed under `tests/testthat/_snaps/` | 0, at each of the five arc commits `d11d1f8`, `e727001`, `5e7a7f9`, `dde0f8a`, `b8feb11` | 0 | exact | ✓ |
| 4.5 no other test file touched | none | none | exact | ✓ |
| 4.5 E-2 files are the retargeted identity blocks | both blocks now pin the divergence: `test-analysis-corr.R` asserts the Fisher-z half-width ratio against `sqrt((n_rep - 1) / n_rep)`; `test-nonprob-bootstrap-variance.R` likewise retargeted | retargeted, not deleted | n/a | ✓ |

Row 4.6 — release notes, six elements in `NEWS.md`.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 4.6 (1) both changed types with both new values | "defaults `scale` to `1` for `type = "JKn"` and to `1/(R-1)` for `type = "bootstrap"`" | both types, both values | exact | ✓ |
| 4.6 (2) direction and size of the move | "rises by `1/sqrt((R-1)/R)` … 2.6% on a 20-replicate design" | rise, sized | exact | ✓ |
| 4.6 (3) explicit `scale` reproducing the old numbers | "Pass `scale = (R-1)/R` for `"JKn"`, or `scale = 1/R` for `"bootstrap"`" | both values | exact | ✓ |
| 4.6 (4) reason `as_survey_nonprob()` keeps `1/R` | "`survey` has no non-probability design class and so is not an oracle for one" | reason present | exact | ✓ |
| 4.6 (5) issue number | `(#253)` | `#253` | exact | ✓ |
| 4.6 (6) one clause separating the two changes | JKn: "That is a formula error", `(R-1)/R` is the unstratified factor, Wolter 2007 ch. 4 cited. Bootstrap: "aligns surveycore with that convention; it does **not** mean an older `1/R` number was wrong" | both halves, Wolter cited, no-defect clause | exact | ✓ |
| 4.6 one entry, not two | 1 new bullet | 1 | exact | ✓ |
| 4.6 entry sits under the bug-fix heading | `## Bug fixes` spans NEWS.md:115–368; the entry starts at :148 | bug-fix heading | exact | ✓ |
| 4.6 does not claim issue #243 | no `#243` in the entry | absent | exact | ✓ |
| 4.6 #242's entry present and unmodified | diff is 22 additions, 0 deletions; the JK2/#242 bullet is byte-identical | present, unmodified | exact | ✓ |
| 4.6 one file under `changelog/` for this work | `changelog/fix-replicate-scale-jkn-bootstrap.md`, the only `A` entry arc-wide | 1 | exact | ✓ |

Changelog entry (`changelog/fix-replicate-scale-jkn-bootstrap.md`), required
elements from the dispatch.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| branch | `fix/replicate-scale-jkn-bootstrap-defaults` and four successors | present | n/a | ✓ |
| status | Complete | present | n/a | ✓ |
| date | 2026-09-29 | present, today | n/a | ✓ |
| PR numbers | #293, #296, #297, #298, and this one — matching the four squash commits `d11d1f8 (#293)`, `e727001 (#296)`, `5e7a7f9 (#297)`, `dde0f8a (#298)` | the arc's PRs | exact | ✓ |
| issue numbers | #253 (also #243, #255 named as owners of deferred gaps) | #253 | exact | ✓ |
| summary with before/after table | four-column table: JKn `(R-1)/R`→`1`, bootstrap `1/R`→`1/(R-1)`, plus `survey` and `as_survey_nonprob()` columns | table present and true | exact | ✓ |
| changed files list | nine files, matching the sweep exactly | matches the tree | exact | ✓ |
| verification list | eight bullets: stored defaults, both oracle blocks, the `Inf`/`NaN` one-column case, cross-constructor, two-phase, suite counts, check/pkgdown/covr, `_snaps/` | present | n/a | ✓ |
| the E5 window | own section: JKn with `rscales = NULL` now carries no jackknife factor at all; `survey` refuses the input; issue #255 owns the closure | recorded | n/a | ✓ |
| clears **one** of the two sanctioned exceptions | "This clears one of the two … not both. The other is the Fay block … Issue #243 owns it." | one, not both | exact | ✓ |

Factual claims checked against the merged tree, not against the prose.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| code matches the stated new defaults | `R/core-constructors.R:851` `JKn = 1`; `:861` `bootstrap = 1 / (n_rep - 1L)` | `1` and `1/(R-1)` | exact | ✓ |
| table's "before" column | at `076bafe`: `JKn = (n_rep - 1L) / n_rep`, `bootstrap = 1 / n_rep` | `(R-1)/R` and `1/R` | exact | ✓ |
| "other seven types unchanged" | the arc diff of `R/core-constructors.R` changes exactly two switch lines | two lines | exact | ✓ |
| "both old defaults multiplied the variance by `(R-1)/R`" | JKn `((R-1)/R)/1 = (R-1)/R`; bootstrap `(1/R)/(1/(R-1)) = (R-1)/R` | equal | 1e-8 | ✓ |
| NEWS.md rise figure | 2.6%; `1/sqrt(19/20) = 1.02597835208515420` | 2.6%, not 2.5% | exact | ✓ |
| `?as_survey_nonprob` fall figure | `man/as_survey_nonprob.Rd:124-125` "smaller … by a factor of `sqrt((R - 1)/R)`, a fall of 2.5% at `R = 20`" | 2.5%, not 2.6% | exact | ✓ |
| no percentage on the replicate help page | `man/as_survey_replicate.Rd` holds neither "2.5%" nor "2.6%" | absent (row 4.1 fact 8) | exact | ✓ |
| changelog's measured SE ratio | claimed 0.97467943448089656 against `sqrt(19/20)`; computed `sqrt(19/20) = 0.97467943448089633` | agreement at the SE row | 1e-8 | ✓ |
| "the variance engine is untouched" | arc diff under `R/` lists `R/core-constructors.R` only | `R/variance-replicate.R` unchanged | exact | ✓ |
| "no error class and no warning class added; `plans/error-messages.md` unchanged" | neither file appears in the arc sweep; no new `class =` in the code diff | unchanged | exact | ✓ |
| "`@variables` keeps all nine keys" | `R/core-constructors.R:870-880` — `weights`, `repweights`, `type`, `scale`, `rscales`, `fpc`, `fpctype`, `mse`, `visible_vars` | nine | exact | ✓ |
| E5's "variance path reads a `NULL` `rscales` as `rep(1, R)`" | `R/variance-replicate.R:92` and `:210` — `if (!is.null(vars$rscales)) vars$rscales else rep(1L, n_rep)` | true | exact | ✓ |
| "eight lines gone, six assertions unwrapped" | the arc diff of `test-variance-replicate.R` deletes six `testthat::expect_failure(` calls and two `sqrt((n_rep - 1) / n_rep)` ratio assertions | 6 + 2 | exact | ✓ |
| no `expect_failure()` call left in the two oracle blocks | the two remaining textual hits, `:812` and `:869`, are comments recording the history — read, not counted with `grep -c` | 0 calls | exact | ✓ |

## Before/After Comparison

Baseline from the dispatch (base `dde0f8a`, gates run in the foreground by the
orchestrator). No gate was re-run here and no pre-PR tree was reconstructed.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 12100 (FAIL 0, WARN 256, SKIP 4) | 12100 (FAIL 0, WARN 256, SKIP 4) | 0 — prose-only PR |
| coverage | 96.15% | 96.15% | 0.00% |
| R CMD check notes | 2 (pre-approved) | 2, the same two | 0 |

Coverage clears the 95% floor and did not move, so neither the HOLD rule nor
the BLOCK rule applies.

## Profile gates

I ran no gate. The orchestrator ran all seven in the foreground; logs at
`.surveycore-workspace/runs/2026-09-23-replicate-scale-jkn-bootstrap/gates/pr-5/`.
The table below transcribes that run.

| Gate | Result | Notes |
|---|---|---|
| devtools::document() | PASS | wrote nothing, at base and at PR 5 |
| devtools::test() | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 12100`, identical to base. The 256 are pre-existing AAPOR small-cell warnings; the gate reads as "no new warning" |
| devtools::run_examples() / build | PASS | both |
| R CMD check --as-cran | PASS | 0 errors, 0 warnings, 2 NOTEs — the same two pre-approved ones. `^changelog$` is in `.Rbuildignore` and already holds 108 tracked files, so the added file raises no NOTE |
| pkgdown | PASS | site built, with the new changelog entry |
| covr | 96.15% | no change against the base |
| CRAN cookbook scan | PASS | the PR modifies no file under `R/`, so the scan has no surface |

Tree: 44ccbad187069650beb9bb411bec5ba4236d4f68

## CRAN cookbook violations

None. The PR's modified file list is `NEWS.md` and
`changelog/fix-replicate-scale-jkn-bootstrap.md`; nothing under `R/` changed.

## Notes for the reviewer, no finding attached

- Row 4.5's file list was widened by erratum E-2 from two files to four. Both
  extra files, `test-nonprob-bootstrap-variance.R` and `test-analysis-corr.R`,
  hold blocks that asserted the two constructors agree numerically on a
  bootstrap design — the identity this work deliberately breaks — and both were
  retargeted to pin the divergence. Not a finding.
- The changelog reports the suite at `12005 → 12100` across the whole arc. The
  dispatch supplied a baseline at `dde0f8a` only, where the count is already
  12100, so the `12005` figure at the arc base `076bafe` is unverified here. The
  same holds for the per-PR coverage claim at the three earlier merges. Neither
  is checkable without running a gate, which this dispatch forbids. No claim
  measurable from the tree was found false.
- The test-spec's §Error-path pattern asks the report to name its second
  bullet: `as_survey_replicate()` raising `surveycore_error_weights_all_zero`
  is asserted by `class =` with no snapshot behind it anywhere. The gap is
  pre-existing, issue **#291** owns it, and closing it here would have changed
  a file under `tests/testthat/_snaps/`, which row 4.5 forbids.

## BLOCKs

None.
