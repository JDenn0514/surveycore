# Review — PR 3 — svydesign-replicate-bridge (`fix/svydesign-replicate-guards`)

**Verdict**: PASS
**Date**: 2026-09-08 17:05

Scope judged: `spec.md` §I.1 rows 4, 5, 7 and 8 — in §III.2 terms, steps 1, 3,
7 and 8, the four import refusals. Steps 2, 4, 5, 6, 9, 10, 11, 12 and 13
landed in pull requests 1 and 2 and are re-checked here only for regression.
All of `spec.md` §IV, the export route, belongs to pull requests 4 and 5 and is
not scored. Rows CB-3 and CB-4 of `plans/error-messages.md` belong to those two
pull requests; their absence here is required, not a gap.

Tree reviewed: `634f998aabb160c8369c7c11f4eaa8721a79617d`. This equals the tree
`audit.md` names, verified with `git rev-parse 'HEAD^{tree}'`. HEAD `c9c93ca`.
`git merge-base HEAD origin/develop` is `4c79a5b`, the stated base, and
`origin/develop` sits at that commit, so `git diff origin/develop` is the whole
pull request.

## Convergence checks

- Spec coverage: **y**. All four guards are in the diff, each with a committed
  block. Step 1 (§V.5) has R-24 and R-25; step 3 (§V.6, import message) has
  R-26; step 7 (§V.1) has R-27 for the empty-string state and R-28 for the
  repeated-name state, which are the two states §III.2 step 7 says reach it;
  step 8 (§V.2) has R-29 at one collision and R-30 at three. The four §III.5
  branch rows — Type error, Empty data error, Name error, Collision error — and
  the four §III.6 rows that name them all have a block.
  `plans/error-messages.md` carries CB-1, CB-2, CB-5 and the row 2 trigger
  note. `audit.md` has a Per-Test row for every one.
- Test coverage of spec: **y**. `test-spec.md` gives this pull request C-1 to
  C-5 and C-10 to C-14, and each has a committed block: C-1/C-2 to R-27, C-3 to
  R-28, C-4/C-5 to R-29, C-10/C-11 to R-24, C-12 to R-25, C-13/C-14 to R-26.
  R-30, the three-collision plural check, is more than `test-spec.md` asks for.
  Row IDs are not in the committed blocks (D11), so I judged the behaviour each
  in-scope row describes.
- Tolerance integrity: **y**. See below.
- Scope discipline: **y**. See below.
- Regression safety: **y**. `FAIL 0` before and after, `WARN 256` before and
  after, `SKIP 4` before and after, `PASS 11343` to `11366`. The test file diff
  is 216 insertions and 0 deletions, so no block from pull request 1 or 2 was
  edited, and no skip was added to reach a pass.
- Comprehension alignment: **y**. The one gotcha this pull request owns —
  "Generated names can collide", `comprehension.md` §Gotchas — lands as step 8,
  row CB-2 and blocks R-29 and R-30. The other gotchas belong to pull requests
  1, 2, 4 and 5; each is either already in the code or deferred with a row in
  `test-spec.md`. No assumption in §Assumptions is touched by these four
  guards.
- `audit.md` verdict: PASS.

## The `cli::qty()` deviation is a spec erratum — record it as such

`spec.md` §V.2 and row CB-2 write the collision message with bare
`{qty(n_collisions)}`. The code uses `{cli::qty(n_collisions)}`. **The builder
is right and the spec text is wrong.** I decided this by rendering both forms,
not from the builder's account.

The spec's form cannot work from inside the package. Rendered in a function
whose environment chains to `baseenv()`, which is what a namespace with no
`cli` import gives:

```
classes: rlib_error_3_0, rlib_error, error, condition
msg: ! Could not evaluate cli `{}` expression: `qty(n_collisions)`.
     Caused by error in `qty(n_collisions)`: could not find function "qty"
```

The condition that reaches the caller is an untyped `rlib_error_3_0`, so
`expect_error(class = "surveycore_error_repwt_name_collision")` could never
pass. `r-package-conventions.md` requires `::` for every external call and
forbids `@importFrom`, so the namespaced form is the only one available;
`R/analysis-corr-latent.R:1721` and `R/survey-collection.R:660` already write
it that way. And §V.2's own warning is what bites: without a quantity in the
bullet, `cli_abort()` throws before the typed condition exists.

The rendered text is identical, because `qty()` emits no characters. Measured
on both numbers:

| Collisions | `"i"` bullet | `"v"` bullet |
|---|---|---|
| 1 | "The design data already has a column named `..surveycore_repwt_2..`." | "Rename the conflicting column in the design data, then convert again." |
| 3 | "The design data already has columns named ..., ..., and ...." | "Rename the conflicting columns in the design data, then convert again." |

Both carry class `surveycore_error_repwt_name_collision`, and the `"v"` bullet
has no double space at either number.

`plans/error-messages.md` row CB-2 stays verbatim to `spec.md` §V.7, bare
`qty()` and all. That is the right call for the table, which is a copy of the
spec — but it means the erratum now sits in two documents.

**Correction for the archive.** In `spec.md` §V.2's code block and in row
CB-2's template, `{qty(n_collisions)}` should read `{cli::qty(n_collisions)}`.
The prose in §V.2 that explains why the quantity is required is correct as it
stands. This is a spec correction, not a builder deviation.

## Message correctness — read from the snapshot file, not the audit

`tests/testthat/_snaps/conversion.md` is new in commit `c9c93ca` and holds
exactly four snapshots, one per class.

| Class | Snapshot check |
|---|---|
| `surveycore_error_replicate_type_unsupported` | Names the offending type (`"subbootstrap"`) and all nine accepted values in `as_survey_replicate()`'s declared order: `"JK1", "JK2", "JKn", "BRR", "Fay", "bootstrap", "ACS", "successive-difference", and "other"`. Matches §V.5 |
| `surveycore_error_empty_data` | "The survey design has no rows." — the route's own message from §V.6, not row 2's `{.arg data}` template. Row 2's text does not appear |
| `surveycore_error_repweights_names_lost` | "has 4 replicate weight columns but 2 usable column names" — plural on both nouns, and the two numbers are the ones the fixture creates. Matches §V.1 |
| `surveycore_error_repwt_name_collision` | Singular at one collision: "has a column named ..surveycore_repwt_2..." and "Rename the conflicting column". Matches §V.2 |

The plural arm has no snapshot, by design: `test-spec.md` §9 gives each class
one snapshot. R-30 pins it with `expect_match(msg, "has columns named")` and
`expect_match(msg, "conflicting\\s+columns")`, and I reproduced both strings
independently in the table above. So the message is checked at both numbers,
and a garbled plural could not pass.

## Each guard's trigger and the step order

Read from `R/methods-conversion.R:479-622`, against §III.2.

| Step | Line | Trigger in the code | Matches spec |
|---|---|---|---|
| 1 | 480-513 | `!isTRUE(rep_type %in% accepted)`, before `data <- ...` | y — the route's first statement, no column work precedes it |
| 3 | 517-535 | `nrow(data) == 0L`, immediately after the data read | y |
| 7 | 561-583 | `usable <- rep_cols[!is.na(rep_cols) & nzchar(rep_cols)]`; `n_names <- length(unique(usable))`; `n_names != n_rep` | y — character for character with §III.2 step 7 |
| 8 | 590-620 | `if (names_generated) { collisions <- rep_cols[rep_cols %in% names(data)] ... }` | y — generated branch only |

No guard fires too early or too broadly.

- The type check is the route's first executable statement, so nothing is
  expanded for a design it refuses.
- Step 8 reads `names_generated`, the local pull request 1 set at
  `length(colnames(x$repweights)) == 0L`. When `survey` supplied the names the
  whole check is skipped, which is what §III.2 step 8 requires: those names are
  meant to name existing columns, and step 11 overwrites them. Row I-12's and
  I-24's designs both pass through that skip, and both still pass.
- The order that carries a number is untouched: step 10's base weight search at
  line 649 still precedes step 11's write at line 660. The four guards all sit
  above the fold-in at line 636, so nothing moved between steps 9, 10 and 11.
- `!isTRUE(...)` rather than a bare `!(...)` widens the predicate to a length-0
  or length-2 `x$type`. That is a superset of §V.5's trigger, reached by no
  route through `survey`, and it adds no line of its own. It is the explicit
  form `engineering-preferences.md` asks for, not a behaviour change.

## The two states that must not reach step 7

Confirmed in the code. Step 6 runs at lines 553-559:

```r
rep_cols <- colnames(x$repweights)
names_generated <- length(rep_cols) == 0L
if (names_generated) {
  rep_cols <- .repwt_col_names(n_rep)
}
```

A zero-length `colnames()` is intercepted there and replaced with `n_rep`
distinct non-empty generated names, so `n_names == n_rep` holds and the step 7
check cannot fire on it. That state was the original defect and is not a
trigger, exactly as §III.2 step 7 and §V.1 require. The audit's re-run of I-8
(20 unnamed bootstrap replicates), I-9, I-17 and I-18 all convert, which is the
same fact from the other side.

Only the two intended states reach the check, and each has a block: empty
strings in `colnames()` (R-27, which asserts
`expect_identical(colnames(sv$repweights), c("r1", "", "r3", ""))` first, so the
block proves `survey` kept the empty strings and step 6 did not generate) and a
repeated name (R-28).

## Scope discipline

`git diff --numstat origin/develop`:

| File | + | - |
|---|---|---|
| `R/methods-conversion.R` | 117 | 0 |
| `plans/error-messages.md` | 36 | 0 |
| `tests/testthat/test-conversion.R` | 216 | 0 |
| `tests/testthat/_snaps/conversion.md` | 41 | 0 |

Four files, matching `implementation-plan.md` PR 3 §Files touched exactly —
nothing added, nothing missing. Zero deletions anywhere in the pull request.
`NEWS.md`, `NAMESPACE`, everything under `man/`, `R/core-classes.R`,
`R/core-constructors.R` and `R/variance-replicate.R` are all absent from the
diff, so gates 7, 8 and 11 hold. No other file under `tests/testthat/_snaps/`
changed, so the line-ending churn was restored as `implementation.md` reports.

**No export-route change arrived early.** I grepped every added line of
`R/methods-conversion.R` for `svrepdesign(`, `fpc`, `rho`, `fay`,
`as_svydesign` and `combined.weights`. Two hits, both comment prose naming
`survey::as.svrepdesign()`. The four `class =` arguments the diff adds are
`surveycore_error_replicate_type_unsupported`, `surveycore_error_empty_data`,
`surveycore_error_repweights_names_lost` and
`surveycore_error_repwt_name_collision` — the three CB classes plus the one
reused class, and no other. Neither `surveycore_warning_replicate_fpc_dropped`
nor `surveycore_error_fay_rho_unrecoverable` appears. Gates 4 and 5-part hold:
four `cli_abort()` calls, four `class` arguments.

## `plans/error-messages.md` discipline

- Purely additive: 36 insertions, 0 deletions.
- Appended after `### var-extension-slot rows (2026-08-27)`, which is still the
  last section before it (headings at lines 498 then 507).
- CB-1, CB-2 and CB-5 present, verbatim to `spec.md` §V.7. CB-3 and CB-4
  absent, with a three-line note saying they land with the export route and why
  the numbering skips. That is what this pull request's scope requires.
- Row 2's own table row is byte-identical: `cksum` on line 32 of both revisions
  returns `1944711576 127`. Its trigger note is appended in the new section.
- Row 16's note is not added, which is right — D8 assigns it to pull request 4.

## Tolerance integrity

All ten in-scope rows are condition rows and carry no numeric comparison.
`audit.md` reports `identical` for each — class equality, message text,
snapshot match — which is the strictest available reading and cannot be looser
than `test-spec.md`.

The 26 regression re-runs of pull request 1's and 2's rows carry
`test-spec.md` §4's own figures:

| Comparison | Audit | Test-spec §4 | Verdict |
|---|---|---|---|
| Point | 1e-10 | 1e-10 | equal |
| Standard error | 1e-8 | 1e-8 | equal |
| CI bounds | 1e-6 | 1e-6 | equal |
| Stored column against matrix | 1e-12 | 1e-12 | equal |
| Structure | `identical` | `expect_identical()` | equal |

Rows I-15, I-16, I-19 and I-26 report `n/a`, and that is correct:
`test-spec.md` §6.4 writes those four as boolean assertions
(`any(stored == 0)`, `anyNA(stored)`, `any(stored < 0)`), which have no
tolerance to set. No row in `audit.md` is looser than `test-spec.md` at any
point. No violation.

## Coverage

| Measure | Value | Floor | Verdict |
|---|---|---|---|
| Package | 96.22% | 95% | PASS |
| Against this pull request's baseline | 96.20% to 96.22% | no drop | PASS |
| `R/methods-conversion.R` | 99.19% to 99.40% | — | — |
| `# nocov` added | none | none | PASS |

**Verified independently.** I recomputed the added line ranges from the diff
hunk headers myself: `git diff -U0` gives `@@ -479,0 +480,36 @@`,
`@@ -481,0 +518,20 @@` and `@@ -505,0 +562,61 @@`, so the added ranges are
480-515, 518-537 and 562-622 — the same three the leader states.
`gate-7-covr.log` reports `UNCOVERED_COUNT=2`, at lines 138 and 305, and
neither falls in any added range. Both are pre-existing: pull request 1's and
pull request 2's reviews found the same two lines, 138 being the `"fraction"`
else-arm on the export route and 305 the `return(NULL)` in
`.find_col_by_value()` that already carries a rationale. Every line the four
guards add is reached, so there is no coverage regression in new code, and no
guard hides behind an exemption.

## Profile gates

Every gate has a result and none is skipped. pkgdown ran, so there is no skip
condition to justify against `r-package-profile.md`. `R CMD check` reports
`Status: 2 NOTEs`, and the check log shows them at lines 14 and 23 — CRAN
incoming feasibility, and the hidden `.git` directory. Both are the
`baseline.md` pair, so no third NOTE arrived. `devtools::test()` reports
`FAIL 0 | WARN 256 | SKIP 4 | PASS 11366`.

Three departures from the stated procedure, all on record before this review:

| Departure | Record |
|---|---|
| The gates were run by the orchestrator in the foreground, not by the tester as `tester.md` Step 1 writes it. Concurrent runs corrupted a log set on pull request 1, and background runs were killed for low memory | D12, D16. The seven logs in `logs/pr-3/` are one run on the shipping tree, `634f998` |
| Gate 2 reads as "no new warning". `develop` carries 256 pre-existing AAPOR small-cell warnings; this tree reports 256 | D12 |
| Gate 9 reads as "the pull request's own files pass `air format --check`". `air` is a CLI here, not an R package, and 24 files repo-wide are already not air-clean | D16 |

Each is a settled decision with its measurement, and each is stated in
`audit.md`. Neither an undocumented skip nor an unrecorded relaxation is
present.

## The audit's advisory note — settled against the reference, and not a finding

`test-spec.md` §9 asks for the class assertion and the snapshot in separate
`test_that()` blocks. R-24, R-26, R-27 and R-29 each put both in one block. I
checked the rule authority rather than resting on D11.

`.claude/references/testing-detail.md` §"Dual pattern for constructor errors"
shows the two assertions in **one** `test_that()` block, numbered 1 and 2 in
the same body. `tests/testthat/test-constructors.R` — the house's own
error-path file — writes every dual-pattern case that way (lines 135-142,
151-159, 180-187, 341-348). So one block is the established form here, and
`testing-standards.md`'s "one observable behaviour per block" is satisfied: the
observable behaviour is the typed refusal, checked two ways.

`test-spec.md` §9's "separate blocks" sentence is the outlier, not the code.
The tester was right not to score it. No action.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every figure I could check against
the tree: the four-file write surface, 36 insertions and 0 deletions in
`plans/error-messages.md`, four snapshots, `PASS 11343` to `11366`, and the
base and tree hashes. `implementation.md` §Notes-for-tester item 1 reports the
`qty()` deviation up front rather than leaving it to be found, and its account
of why bare `qty()` fails matches what I measured. Nothing in the two documents
disagrees.

One observation, carried forward rather than scored. The header comment index
at the top of `tests/testthat/test-conversion.R` was not extended, though
`test-spec.md` §1 and plan task 7 both ask for it. The index is stale from
before this run: it stops at legacy entry 29 of 38 and names none of pull
request 1's or pull request 2's 23 blocks either, so this pull request neither
created the gap nor widened it against its predecessors, both of which passed
review. The added sections carry their own inline `# -- R-24 ... R-30 ...`
header, so the file is navigable. This is not a behaviour gap and none of the
seven checks turns on it. It belongs to the run's final tidy, alongside the
`qty()` erratum.

## Decision

PASS. All four guards fire on exactly the trigger `spec.md` §III.2 states, in
the order it states, and the two states §III.2 step 7 excludes are still
excluded — step 6 intercepts the zero-name case, and only the empty-string and
repeated-name states reach the check. The four snapshot messages read correctly
at both plural numbers and name what §V.1, §V.2, §V.5 and §V.6 require. The
write surface is the plan's four files with zero deletions, no export-route
code or condition arrived early, `plans/error-messages.md` is purely additive
with row 2 byte-identical, coverage rose and every added line is reached, and
no tolerance in `audit.md` is looser than `test-spec.md`. The one deviation
from the spec's literal text, `{cli::qty()}` for `{qty()}`, is a spec erratum:
the spec's form throws an untyped error before the typed condition exists, and
the rendered message is identical. Record that correction in the archive.
