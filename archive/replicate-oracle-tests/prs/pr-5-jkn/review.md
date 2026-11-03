# Review — PR 5 — test/replicate-oracle-jkn

**Verdict**: PASS
**Date**: 2026-09-22 14:05

Reviewed at commit `0e3127ea6b5ab5c184e6a42a4bfcf131f08f67d1`, tree
`ba47cff369806d0c550db3d9ecb8f05e7f3600c1`, base
`d0de848d506feb186636898fa7726efdc8337a22`. `git diff --stat d0de848 HEAD`:
one file, `tests/testthat/test-variance-replicate.R`, **+84 / −0**.

Scope of this verdict: rows 2.3, 2.4, 3.1.4 and PR 5's eight acceptance
criteria. Rows 2.9, 2.10, 2.11, 2.15, 2.16 and all of §3.6 read the JKn and the
bootstrap block together; the plan allocates them to PR 6 and this review counts
none of them here.

## Convergence checks

- Spec coverage: **y** — every element of `spec.md` §V.4 and §IV.3 "The pinned
  blocks" has a row or criterion in `audit.md`, and each is delivered.
- Test coverage of spec: **y** — `test-spec.md` rows 2.3, 2.4, 3.1.4, §3.6 and
  §3.7 cover §V.4. No §V.4 element lacks a scenario.
- Tolerance integrity: **y** — see below.
- Scope discipline: **y** — `implementation.md` §Write surface names one file;
  the plan's PR 5 "Files touched" names the same file; the diff names the same
  file and nothing else.
- Regression safety: **y** — gate 2 on this tree reads
  `FAIL 0 | WARN 256 | SKIP 4 | PASS 11989`. Baseline 11941, PR 4 left 11982,
  so +7, which is exactly the new block's seven expectations
  (no-warning, stored scale, point estimate, three wrappers, ratio). Warnings
  and skips unchanged. No test outside the PR's surface changed state.

## Independent verification

I re-ran the tester's measurements with my own comment-stripping,
depth-counting instrument rather than trusting the audit's numbers.

**Wrapper nesting** (depth 2 is the `test_that()` body, depth 3 is inside a call
opened at depth 2):

| Line | Depth | Construct |
|---|--:|---|
| 843–852 | 2 | `expect_no_warning(sv <- survey::svrepdesign(...))` — design build and condition assertion, unwrapped |
| 855 | 2 | `expect_equal(sv$scale, 1, tolerance = 1e-8)` — unwrapped |
| 861 | 2 | point estimate, `tolerance = 1e-10` — unwrapped |
| 865 / 866 / 867 | 2 / 3 / 2 | wrapper 1: one `expect_equal` on `sc_mean$se` at `1e-8` |
| 868 / 869 / 870 | 2 / 3 / 2 | wrapper 2: one `expect_equal` on `ci_low` at `1e-6` |
| 871 / 872 / 873 | 2 / 3 / 2 | wrapper 3: one `expect_equal` on `ci_high` at `1e-6` |
| 879–883 | 2 | ratio assertion — unwrapped |

Three `expect_failure(` in code (six textual, three after comment stripping),
each holding exactly one assertion. All four §IV.3 mechanics hold: one
assertion per wrapper (1), point estimate outside (2), design call and its
no-warning assertion outside (3), tolerances carried inside the wrappers (4).

**The ratio assertion.** Delivered as
`expect_equal(sc_mean$se / as.numeric(survey::SE(sv_mean)), sqrt((n_rep - 1) / n_rep), tolerance = 1e-8)`,
at depth 2. It compares the right pair in the right order — surveycore over
`survey`, which is below 1 because surveycore's scale is the smaller one — and
against a literal formula, not against a value read off either design.
Arithmetic re-computed here in double precision from the builder's 17-digit
probe: `0.24018678896352669 / 0.24642644593339988 = 0.97467943448099092`;
`sqrt(19/20) = 0.97467943448089633`; difference `9.4591e-14`, six orders inside
`1e-8`; the standard-error gap is 2.5321%, matching §V.4's "low by 2.53%".
`n_rep` is read from the selected `^repwt_` columns, and the generator returns
`n_psu = 20` columns for the `jkn` mode, so the asserted literal is `sqrt(19/20)`
at run time without any hard-coded count. The assertion passes today (gate 2 has
0 failures) and turns red when either default moves, which is the
attributability job §IV.3 gives it.

**The four-line comment.** Lines 814–818 read: "When issue #253 lands, delete
FOUR lines: the three expect_failure() wrapper lines and the ratio assertion at
the end of this block. Deleting only the three leaves the ratio assertion to
fail against the corrected default." It names the count, names which four, and
names the failure mode the count exists to prevent.

**`rscales`.** Eight code occurrences of the token file-wide; exactly one
`survey::svrepdesign()` call receives it — line 849, in the new block (the
opening call is at 844). The other sites are one `as_survey_nonprob()` call
(229) and two `.svy_rep_var()` calls (628, 643), all unchanged. The surveycore
side receives the same literal `rep(1, n_rep)` at line 840. Nothing crosses from
one side to the other; `n_rep` comes from the fixture's column names.

**Header.** `# Block 24: Oracle blocks for the remaining replicate types` at line
803. `diff` of the `^# Block ` lists at base and at HEAD shows one added line and
no other change, so no existing header renumbered. It is the last header, the
block runs to the end of file (884), and PRs 6, 7 and 8 can append bootstrap,
`other` and Fay beneath it in that order.

**Title.** `get_means() JKn SE disagrees with survey::svymean() — issue #253` —
names the disagreement, names the issue, claims no match.

**Conventions.** The stored-scale comment is the exact 99-character string (S4);
`grep -Fxc` counts 11 at HEAD and 10 at base, one added and byte-identical.
`mse = TRUE` is passed explicitly on both sides (N1). No `scale =` and no `rho`
reaches either constructor. The skip guard sits inside the block. No second
`test_invariants()` call — the file's one call stays at line 31 (§IV.4). CRLF
line endings preserved.

## Tolerance integrity

| Assertion | Delivered | `test-spec.md` §8 | Verdict |
|---|---|---|---|
| Point estimate | `1e-10` | `1e-10` | equal |
| Standard error (wrapped) | `1e-8` | `1e-8` | equal |
| Both bounds (wrapped) | `1e-6` | `1e-6` | equal |
| `survey` stored scale | `1e-8` | `1e-8` (SE/variance row) | equal |
| Standard-error ratio | `1e-8` | `1e-8` (SE/variance row) | equal |

No tolerance is looser than specified and none is omitted. The diff carries 0
deletions, so no pre-existing tolerance could have been widened; line 174's
missing tolerance (finding N2) is untouched and stays out of scope.

## Profile gates

`audit.md` §Profile gates and the After column of §Before/After still read
**pending** — the gate pass was in flight when the session paused, and the
tester was instructed to start no R process. I did not run gates; I read the
leader's completed run in
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/pr5/`, whose
`Tree:` line reads `ba47cff369806d0c550db3d9ecb8f05e7f3600c1` — the same tree
the audit records and the same tree as HEAD.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing |
| `devtools::test()` | PASS | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11989` |
| `run_examples()` | PASS | all examples ran |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | 2 NOTEs: `CRAN incoming feasibility` and `hidden files and directories` (`.git`) — both on the baseline tree, neither new |
| pkgdown | SKIPPED — scope | write surface is one test file; no `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or `DESCRIPTION`; NAMESPACE diff empty, so the hard rule in `r-package-profile.md` does not bite |
| `covr` | 96.15% | equal to baseline 96.15%; no `R/` line added or removed |
| `air format --check` | PASS | run by the tester, exit 0 |
| CRAN cookbook scan | PASS | no violations; no `R/` file touched |

Coverage clears the 95% floor, is flat against baseline, and the PR adds no
source line, so no new-code coverage drop is possible.

## Comprehension alignment

`comprehension.md` gotchas that reach JKn are all discharged: G7 (a scalar
`rscales` would read differently) — the block passes a length-`R` vector; G10
(surveycore does not refuse JKn without `rscales`) — deferred in `spec.md` §V.4
to issue #255, explicitly out of this arc; the measured scale, SE and ratio
figures in §§117–166 match the builder's probe to thirteen significant figures.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every figure I re-measured: three
wrappers, one `svrepdesign()` `rscales` site, 99-character comment 10 → 11, the
ratio and its `9.46e-14` residual, the one added `# Block` header.

Three observations, none of them a defect and none conditioning this verdict:

1. **`audit.md` bookkeeping.** Its §Profile gates and §Before/After After column
   should be replaced with the table above before the arc is archived. The
   verdict here does not depend on that edit: the gate evidence exists in
   `logs/pr5/` on the identical tree and I checked it directly.
2. **The ratio assertion attributes the standard-error wrapper.** The two bound
   wrappers stay attributable only through it — a misnamed `ci_low` would still
   produce a failing assertion and a passing wrapper. That is the shape
   `spec.md` §IV.3 and `test-spec.md` §3.6 specify (one ratio assertion, on the
   standard errors), so it is a property of the design, not of this build. A
   reader of PR 6 should know it.
3. **The comment says "When issue #253 lands" where `spec.md` §IV.3 says "PR 3
   of the arc".** The issue number is the durable reference and this arc's own
   PR 3 has already shipped, so the delivered wording is the clearer of the two.
   Acceptance criterion 7 asks for the issue number and the count of four; both
   are present.

## Decision

PASS. Every §V.4 and §IV.3 requirement is delivered and independently
re-measured: the wrapper nesting holds at paren depth, the ratio assertion
compares the right pair in the right order against a literal and passes with a
`9.46e-14` residual, the comment names four lines and which four, one
`svrepdesign()` call receives `rscales` and the surveycore side gets the same
literal, and the header adds Block 24 without renumbering. Tolerances match
`test-spec.md` exactly on all five assertions, the diff has 0 deletions, and the
gates pass on the reviewed tree with coverage flat at 96.15%.
