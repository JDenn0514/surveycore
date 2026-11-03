# Review — PR 1 — fix/domain-marker-validator

**Verdict**: PASS
**Date**: 2026-09-14 00:00
**Tree audited**: e88e6e7a303904b3215139588e76e703a77a5d58
**Scope**: `test-spec.md` §1 rows 1.1–1.4 and §Existing blocks E.1–E.4 (8 rows).
Rows 1.5–1.11, 2.1–2.9 and §§3–6 belong to PRs 2–6 and are not judged here.

## Convergence checks

- Spec coverage: **y**. `spec.md` §Function contracts holds one contract for
  PR 1 — the `survey_base` validator. Its two ordered checks, its one error
  class and its message all appear in the shipped body, and `audit.md`'s
  per-row table binds each of the eight rows to a named block with a line
  range. The contract's edge-case table is claimed by PRs 2 and 3 in the
  plan's row ledger.
- Test coverage of spec: **y**. Every line of the contract has a test-spec
  row somewhere in the plan. No contract item is unclaimed.
- Tolerance integrity: **y**. No row in scope carries a numeric comparison.
  `test-spec.md` §Tolerances states that sections 1, 2, 5 and 6 assert
  classes and structure and take no tolerance. `audit.md` reports the same
  and relaxes nothing. E.1's retained `all.equal()` comparison is the block's
  own pre-existing assertion, unchanged by the repair.
- Scope discipline: **y**. `implementation.md` §Write surface names eight
  files; `git diff 8fe3fa2...HEAD --stat` returns those eight and no other.
  `NAMESPACE` is unchanged.
- Regression safety: **y**. FAIL is 0 before and after. The −5 PASS delta
  reconciles exactly, see note 1.

## Cross-consistency notes

**1. The −5 PASS delta reconciles to the row, with nothing left over.**
`audit.md` calls it "≈8" from E.4 and leaves the figure approximate. It is
exact. Old E.4 ran five iterations of three expectations (15); new E.4 runs
three on the logical iteration plus one error-class expectation on each of
the other four (7), so −8. Old E.3 carried `expect_no_condition()` and
`expect_identical(nrow, 0L)` (2); new E.3 carries one `expect_error()`, so
−1. Rows 1.1–1.4 add 4. −8 −1 +4 = −5, the observed delta. No expectation is
lost outside the two rewrites `test-spec.md` §Existing blocks mandates.

**2. Coverage: a covr blind spot, not a testing gap — proved from a line this
PR did not touch.** covr marks lines 348, 349, 355, 356, 357, 372 (the whole
new validator) and line 709 uncovered. Line 709 is
`if (!is.numeric(wt_col))` in the pre-existing `survey_taylor` validator,
outside both diff hunks. Nine test sites across five files assert
`surveycore_error_weights_not_numeric`, the class raised inside that `if`.
Line 709 therefore executes, and covr still calls it uncovered. The same
shape — an `if` head inside a closure passed as `validator =` to
`S7::new_class()` — gives the same false reading on the new body. Each
branch of the new body is independently proved to run:

| Branch | Proof |
|---|---|
| Reject (355–368) | Rows 1.1–1.4 pass, asserting `surveycore_error_domain_not_logical`. A grep over `R/` returns exactly one site that raises that class: `R/core-classes.R:368`. |
| Accept (372) | E.1, E.2 and E.4's logical iteration each write a logical marker and then assert something that runs only if the write completed. |
| Early return (348–349) | Every design the suite builds without a marker column takes it. |

**Which rule governs the 0.11pp drop.** The plan's PR 1 criterion 8 and
`spec.md` gate 11 set what the PR must achieve: at or above 95%. 96.14%
clears it. `r-package-profile.md` gate 7 sets what the tester must do on
measuring a drop inside the 95–98% band: raise a HOLD. The two do not
conflict — one is a PR criterion, the other a routing rule for the measuring
agent. On the routing rule the tester deviated. It wrote "below the 0.5pp
HOLD trigger", and no 0.5pp threshold exists in `r-package-profile.md`,
`artifact-schemas.md` or `signals.md`. Recorded as a process finding against
the tester. It does not change the verdict, because the question a HOLD would
have put to the user — is coverage really lost in the lines this PR added —
is answered above with direct evidence, and the answer is no. Under this
reviewer's own coverage test the check is clean: the floor is met, and no
line this PR added is untested.

**3. The carried HOLD did not arise, verified against the diff.**
`decisions.md` §Open left open whether S7 runs a parent validator for a
subclass, and forbade copying the check into the four subclass validators.
`git diff 8fe3fa2...HEAD -- R/core-classes.R` returns two hunks: the roxygen
sentence on the `data` property, and the `validator =` argument on
`survey_base`. No subclass validator is edited. Rows 1.1–1.4 build
`make_all_designs()$taylor`, `$replicate`, `$twophase` and `$calibrated`;
`$calibrated` comes from `as_survey_nonprob()`, so all four concrete classes
are covered, and all four pass. The assumption is now settled by this
package's own classes.

**4. Gate 4 holds byte for byte.** The `cli::cli_abort()` call splits each
bullet across a `paste0()` pair. Concatenated, the `"x"` bullet reads
`Domain column {.field {SURVEYCORE_DOMAIN_COL}} must be logical, not {.cls {col_class}}.`
and the `"i"` bullet reads
`{.fn surveytidy::filter} writes this column as a logical mask; {.code TRUE} marks a row inside the active domain.`
Both match row 103 at `plans/error-messages.md:149` character for character.
The row carries the class and sits beside row 101, the other validator row.
Row 102 sits in an earlier table at line 122, so "after 101 and 102" is met
as placed.

**5. Nothing from `spec.md` §Out was implemented.** The validator tests
`is.logical()` and nothing else. It does not coerce, does not read
`@variables`, and does not check length, `NA` count or attributes.
`R/analysis-helpers.R`, `R/methods-conversion.R` and
`R/analysis-corr-latent.R` are untouched, so the four `as.logical()` calls
the spec protects — including the load-bearing one at line 1776 — are intact.

**6. Advisory, outside PR 1's scope — a stale comment for PR 5.**
`tests/testthat/test-conversion.R:3296-3298` still reads "as.logical() is what
makes the claim hold for a marker column that is not logical". That block is
not one of the four E-rows, writes no marker column, and the coercion the
comment describes still exists on this tree, so the comment is not yet false.
PR 5 removes that coercion and rewrites the design note above
`.restrict_to_domain()`. `spec.md` §Scope names only the note in `R/`, so no
PR entry claims this test comment. Carry it into PR 5. It is not a finding
against this PR.

**7. Two minor observations, neither blocking.** Gate 12 (`air format
--check`) has no row in `audit.md` §Profile gates. It is not one of the
profile's seven gates, and `implementation.md` §Notes for tester records the
result — four touched R files clean, and `helper-test-data.R` already not
air-clean on `develop` at a line this PR does not touch, which matches the
gate reading set in `archive/as-svydesign-bridge/` D16. Separately, the two
deliberate non-logical writes in E.3 and E.4 use single-bracket assignment
and so fall outside gate 3's grep pattern by construction. Every hit the
sweep does return writes a logical vector, which is what the gate asks.

## Decision

All eight in-scope rows trace to a named block that asserts the form
`test-spec.md` requires and passes. The write surface equals the plan's eight
files exactly, no subclass validator was edited, and nothing from `spec.md`
§Out was built. The seven profile gates each carry a result, the CRAN
cookbook scan is clean, and the test-count and coverage deltas are both
explained — the first exactly, the second by a covr line-attribution artifact
demonstrated on a pre-existing line that nine tests prove executes. The one
process deviation, the tester's invented 0.5pp coverage trigger, is recorded
for the run's decisions log and does not touch the shipped behaviour.
**PASS.**
