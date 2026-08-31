# Decisions — var-extension-slot

## 2026-08-27 — PR scope: Proposal A only
- **Question**: Should this PR ship both Proposal A (extension slot) and
  Proposal B (`measure`), or just Proposal A now?
- **Resolution**: Proposal A only. `measure` is independent, not
  time-sensitive, and is deferred to a separate future request.
- **Why**: keeps this PR minimal and focused on beating the frozen-property
  deadline; avoids bundling an unrelated design decision (inferred vs.
  required `measure`, whether analysis functions should act on it) into a
  time-sensitive PR.

## 2026-08-27 — Slot shape: flat named list, no namespacing
- **Question**: What shape should the Proposal A extension slot take?
- **Resolution**: A flat named list per variable
  (`set_var_extra(design, col = list(role = "free_text"))`), not namespaced
  by package.
- **Why**: simplest shape; matches the issue's own preference for a slot
  that never needs revision. Namespacing solves a collision problem with no
  demonstrated instance yet.

## 2026-08-28 — Plan-review Pass 1 resolution (batch, Auto Mode)
- **Question**: How to resolve the 15 findings (0 blocking, 3 required, 12
  suggestion) from the 5-lens plan review?
- **Resolution**: Resolved all 15 directly, in one pass, without a
  per-issue `AskUserQuestion` prompt for each. Edits applied to
  `implementation-plan.md` (→ v1.1) and additively to `test-spec.md` (→
  v1.1, one new §Class/foundation table, no other change). Full itemized
  resolution is recorded in `plan-review.md` §Resolution.
- **Why**: every finding had exactly one reasonable fix with no genuine
  design trade-off to weigh (missing test coverage, a misnamed file path,
  a wording inconsistency, an under-scheduled test class) — none of them
  met the HOLD bar ("methodology genuinely ambiguous, user must make a
  judgment call") from `signals.md`. Auto Mode was active for this
  session, which directs making the reasonable call on this class of
  finding rather than pausing for confirmation on each one.

## HOLD — tester — 2026-08-28 09:47

**Where**: PR 1 (var-extension-slot), profile gate 7
(`covr::package_coverage()`), re-validation run after the BLOCK fix commits
(`6f09bc4`, `b6643e7`)
**What**: `covr::package_coverage()` cannot produce a coverage percentage —
the R subprocess it launches to run the instrumented test suite segfaults
(exit code 139) every time, in a clean, exclusive, uncontended environment
(verified via `ps -W` immediately before each attempt — no other R process
running). Reproduced 3 times across two full gate-script runs and one
direct diagnostic run with `clean = FALSE`. The identical test suite runs
clean under `devtools::test()` (0 failures, 10008 passed, twice) and under
`R CMD check --as-cran`'s own `testthat.R` execution (169s, OK, twice), so
the crash is specific to covr's line-tracing instrumentation, not a defect
surfaced by the tests themselves. No `Rout.fail` content was recoverable
(R crashed before flushing output); the segfault is opaque even with
`clean = FALSE`.
**Why I can't decide**: None of the tester's enumerated BLOCK triggers
match this ("R CMD check has ERROR/WARNING" — it doesn't; "pkgdown
errored" — it didn't; "coverage dropped below 95%" — no percentage was
ever produced, so there is nothing to compare to 95%). The closest defined
signal is the tester's HOLD trigger for a reference tool erroring instead
of returning a numerical result. Separately, no coverage baseline
percentage was included in this PR's dispatch at all (only
`devtools::test()` and `devtools::check()` baselines were given), which
independently triggers the Step 4 "no baseline provided → HOLD" rule for
this one metric.
**Options**:
  - Treat this as a pre-existing environment/tooling limitation (covr vs.
    this R 4.6.1 / package-size combination) unrelated to this PR's code,
    and accept the audit's other 6 clean gates plus the full per-test-spec
    table as sufficient for a PASS, with coverage gate marked
    environment-blocked.
  - Investigate the covr crash directly (e.g. bisect test files, try an
    older/newer covr build, run under a debugger) before any verdict — out
    of scope for the tester role, which runs gates rather than debugging
    tooling.
**What I need**: A decision on how to score profile gate 7 when the tool
itself crashes rather than returning a number below or above 95% — and,
separately, a coverage baseline for the Before column so future PRs on
this feature branch can compare deltas.

## HOLD RESOLVED — user — 2026-08-28 09:50
- **Resolution**: Accept the covr segfault as an environment-blocked
  limitation for this PR. All other profile gates are clean (devtools::test
  0 failures/10008 passed, devtools::document clean, R CMD build clean,
  R CMD check --as-cran 0 errors/2 pre-approved NOTEs, pkgdown builds
  clean, CRAN cookbook scan clean, all 79 test-spec scenarios pass). No
  further bisection performed before shipping.
- **Independent verification performed by the coordinator** (beyond the
  tester's 3 reproductions): confirmed NOT pre-existing — `covr` runs
  cleanly on `develop` (96.11% coverage, no crash) in the same environment.
  Confirmed the crash is triggered by content in
  `tests/testthat/test-metadata-system.R` specifically — instrumenting the
  new source files alone with zero tests run does not crash
  (`covr::package_coverage(type = "none", code = "TRUE")` succeeds), but
  running that one test file under covr instrumentation reproduces the
  segfault. Ruled out the `textConnection()`-payload test as the sole
  trigger (disabling it via `skip()` did not stop the crash). Exact
  triggering line not isolated — no R-catchable error or flushed output is
  produced before the process dies, even with
  `covr::package_coverage(clean = FALSE)`.
- **Follow-up**: tracked in
  https://github.com/JDenn0514/surveycore/issues/184 — bisect the
  remaining `var_extra` test blocks under covr, consider `skip_on_covr()`
  once root-caused.
- **Why**: `devtools::test()`, `R CMD check --as-cran`'s own test
  execution, and pkgdown all independently and repeatedly exercise the
  identical code and confirm correctness; only the coverage *measurement*
  tool crashes. Continued bisection has diminishing returns given the
  segfault's opacity (no stack trace, no R-level error to work from) and
  the PR is otherwise fully verified against test-spec.md and spec.md.

## BLOCK RESOLVED — coordinator — 2026-08-28 10:20
- **Resolution**: Reviewer's BLOCK (review.md, 2026-08-28 10:15) routed to
  the planner for two documentation-parity gaps, neither affecting shipped
  behavior. Fixed directly by the coordinator rather than a full planner
  re-dispatch, given the mechanical, low-risk nature of the edits:
  1. Added the "same variable named twice" edge case row to
     `test-spec-var-extension-slot.md`'s `set_var_extra()` edge-case table
     (spec.md already had it; the test already existed and passed via
     implementation-plan.md task 49.1 — test-spec.md was just incomplete).
  2. Added `tests/testthat/test-utils.R` and `man/survey_metadata.Rd` to
     `implementation-plan-var-extension-slot.md` PR 1's Files-touched list
     (builder correctly used test-utils.R per existing sibling convention;
     the plan simply hadn't anticipated it).
  Committed as `114b94c`. No builder rework or re-test needed — re-dispatching
  the reviewer only, to confirm convergence against the corrected docs.

## SHIPPED — 2026-08-29 00:22 UTC
- PR 1 (var-extension-slot) merged via PR #185, squash commit `fca4366`.
  All 5 required CI checks green (macos-latest, ubuntu-latest release/devel,
  windows-latest, pkgdown). Coverage percentage unmeasurable due to the
  covr segfault above; shipped with explicit user approval per the HOLD
  RESOLVED entry, follow-up tracked in issue #184.
