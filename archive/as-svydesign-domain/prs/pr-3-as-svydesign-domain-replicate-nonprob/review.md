# Review — PR 3 — as-svydesign-domain-replicate-nonprob

**Verdict**: PASS
**Date**: 2026-09-11

Branch `fix/as-svydesign-domain-replicate-nonprob` at `8c86c5f`, tree
`5819738648687bc08c7a7fa40204826aaec51864`, cut from `develop` at `67914a0`,
which is `origin/develop`. The tree hash matches the one `audit.md` records and
the one the gate summary prints. Two commits: `843b33e` the production change,
`8c86c5f` the tests.

## Convergence checks

- Spec coverage: yes, for this PR's slice. All eleven allocated rows have a
  block on this tree, and every block passes.
- Test coverage of spec: yes. Each row maps to an entry in `spec.md`
  §`.restrict_to_domain(converted)` → Edge cases, §`as_svydesign(x)` → Returns
  and Warnings, or §`as_tbl_svy(x)`.
- Tolerance integrity: yes. Point 1e-10 and SE 1e-8 on every numeric
  comparison, which is `test-spec.md` §Tolerances unchanged.
- Scope discipline: yes. Two files, 272 insertions, 1 deletion.
- Regression safety: yes. FAIL 0, WARN 256, SKIP 4 before and after. The
  expectation count moves 11706 to 11749.

## Row ledger — who covers what

| Row | Covering block (line) | Assertions the row asked for |
|---|---|---|
| A-2 | `converts a filtered replicate design to the domain [numerical]` (3547) | parity point and SE, plus the two marker assertions |
| A-3 | `converts a filtered replicate nonprob to the domain [numerical]` (3593) | same |
| C-2 | `converts an unfiltered replicate design unrestricted` (3614) | no condition, row count, marker absent |
| C-4 | `converts an unfiltered replicate nonprob unrestricted` (3626) | same |
| C-5 | `converts an unfiltered plain nonprob unrestricted` (3640) | the SRS warning only, row count, marker absent |
| D-2b | `converts an all-FALSE marker on the replicate route to zero rows` (3660) | zero rows, silent conversion, then `survey`'s untyped error |
| D-2d | `... on a replicate nonprob` (3676) and `... on a plain nonprob` (3690) | zero rows on both shapes; the SRS warning on the plain one |
| E-2 | `as_tbl_svy() inherits the restriction on a filtered plain nonprob` (3711) | `tbl_svy`, domain row count, warning captured |
| G-1b | `raises no condition on a filtered replicate design` (3729) | `expect_no_condition()` on both shapes |
| G-2 | `raises the SRS warning once on a filtered plain nonprob` (3740) | once and nothing else, domain row count |
| G-3 | `warns once about a dropped FPC on a filtered replicate design` (3759) | once and nothing else, result off the return value, marker all TRUE |

I read every cited line. Each block sits where the audit says it does. A
thirteenth block at 3573 runs the A-2 comparison on a marker that
`surveytidy::filter()` wrote. It claims no row and duplicates none: A-5 is the
Taylor-route `filter()` row and PR 1 shipped it. The block uses the same two
tolerances as the rows around it, so it cannot relax anything.

## The four points the dispatch asked me to check

**1. No branch on the weight shape.** `git diff origin/develop...HEAD -- R/`
is four lines. `survey::svrepdesign(...)` gains an assignment to `converted`,
and `.restrict_to_domain(converted)` becomes the last expression of
`.as_svydesign_replicate()`. Nothing else in `R/` changes. The helper at
`R/methods-conversion.R:61` is byte-identical to `develop`: one argument, no
class branch, no read of `x@variables$repweights`. The dispatch in
`as_svydesign()` is untouched, so the two non-probability shapes reach the two
existing call sites through the routing that already exists. `spec.md` §Out and
issue #246 are respected — there is no ninth copy of the predicate.

**2. Warning ordering.** Both warnings fire before the object exists, so the
restriction can neither double one nor suppress one. G-3 pins the FPC warning
and G-2 pins the SRS warning, each with
`expect_no_warning(expect_warning(sv <- as_svydesign(d), class = ...))`. The
nesting is sound: `expect_warning(expr, class = )` consumes the first matching
condition and re-signals everything it does not match, so a second copy of the
same class, or any other warning, reaches the outer expectation and fails it.
The builder reports checking the pattern against a function that raises two
warnings of different classes and getting one failure, which is the
non-vacuity check this asks for. G-3 reads its row count and its marker
assertion off `sv`, the return value of the warned call, as `test-spec.md` §G
requires. C-5 and the plain-nonprob half of D-2d use the same nesting, so the
"exactly once" claim covers the unfiltered design and the empty domain as well
as the ordinary one.

**3. D-2b is untyped and stays untyped.** The block is
`expect_error(survey::svymean(~y1, sv), "All replicates contained NAs")` — no
`class =` argument. `git diff origin/develop...HEAD --stat` names two files, so
`plans/error-messages.md`, `tests/testthat/_snaps/`, `NAMESPACE`, `man/`,
`NEWS.md` and `DESCRIPTION` are all byte-identical to `origin/develop`. The
arc adds no condition class, and this PR adds no golden file for a message that
belongs to `survey`.

**4. Tolerance integrity.** Six numeric comparisons in the new section, three
at 1e-10 for the point estimate and three at 1e-8 for the standard error. Those
are `test-spec.md` §Tolerances with no deviation. Row counts, marker presence
and marker values use `expect_identical()` and `expect_true()`, which is what
the same section prescribes. Nothing is looser and nothing is tighter.

## Scope

`git diff origin/develop...HEAD --numstat`:

```
3	1	R/methods-conversion.R
269	0	tests/testthat/test-conversion.R
```

That is the plan's Files touched line for PR 3, exactly. The test file has zero
deleted lines, so no existing block changed — which matches `test-spec.md`
§Existing rows whose assertions change, "None". The worktree also carries one
modified and four untracked files under `plans/`. They are the arc's planning
artifacts, they are deliberately uncommitted, and they are outside every PR's
write surface. They are not scope creep, and the shipper keeps them out of the
commit.

`test_invariants()`: the file holds five calls, at lines 121, 770, 1173, 2166
and 2795, all of them ahead of the new section and none of them added by this
PR. `as_survey_replicate()` and `as_survey_nonprob()` are covered once each
already, so the once-per-constructor-per-file rule says add none, and the
builder added none.

## Profile gates

| Gate | Result | Verified against |
|---|---|---|
| `devtools::document()` | PASS | `logs/pr-3/gate-1-document.log`; the `man/` and `NAMESPACE` diffs are empty |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11749 |
| `devtools::run_examples()` | PASS | `logs/pr-3/gate-3-examples.log` |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` |
| pkgdown | PASS | run, not skipped; the write surface touches `R/` |
| covr | 96.25% | `COVERAGE_PCT=96.25` |
| CRAN cookbook scan | None | one `R/` file, four lines, no pattern matches |

No gate was skipped, so no skip needs a justification. The two NOTEs are
`checking CRAN incoming feasibility`, which is pre-approved, and the `.git`
hidden-file NOTE. The second one is not new: it appears in the `pr-0`, `pr-1`,
`pr-1-fix` and `pr-2` check logs of this run at the same count, and
`archive/as-svydesign-bridge/` records `.Rbuildignore` as its cause. No new
NOTE pattern, so nothing escalates.

The four skips sit in `test-glm-anova-numerical.R`, `test-glm-anova.R` and
`test-srr-compliance.R`. None is in `test-conversion.R`, so `survey`, `srvyr`
and `surveytidy` were installed and all thirteen new blocks ran.

Coverage: 96.25%, above the 95% floor, equal to the PR 1 and PR 2 figures and
above the 96.24% baseline. The gate summary's `changed R/ files: 2` is the
stale-local-ref misreport the dispatch describes — `run-gates.sh` diffs against
the local `develop` ref at `a545505`, so it still lists PR 0's
`R/analysis-means-helpers.R`. Against `origin/develop` this PR changes one `R/`
file. `CHANGED_FILE_PCT R/methods-conversion.R=99.77`, and the file's only
uncovered line is 573, the `} # nocov — callers always pass non-NULL` early
return inside `.find_col_by_value()`, a helper this PR does not touch. The two
production lines the PR adds run on every replicate conversion in the suite, so
no new line is uncovered.

## Cross-consistency notes

`implementation.md` and `audit.md` describe the same system. Both name the same
base and the same tree, two files, one call site, and the same eleven rows.
Two small prose gaps, neither of them a defect:

- `implementation.md` §Summary says the section gains "14 blocks", and its own
  enumeration in the same sentence sums to thirteen. The file holds thirteen.
  The enumeration and the file agree; the total is a miscount.
- `audit.md` says the file holds "six pre-existing calls" of
  `test_invariants()`, then lists five line numbers plus one comment. Five
  calls and one comment is what the file holds.

The audit's per-row table omits the `filter()`-marked block at 3573, which
claims no test-spec row. Gate 2 covers its pass state, and I read its
tolerances directly.

D-2d deserves one sentence. `test-spec.md` writes the row as zero rows plus the
condition claim, and adds that the estimation outcome "follows the helper it
routes into". The plan's task 7 and acceptance criterion 4 narrow that to the
row count and the conditions, and this PR asserts what the plan asks. The two
estimation outcomes are pinned once each already, by D-2a on the Taylor route
and by D-2b here, on the same code paths the two non-probability shapes reach.
Nothing is left unasserted.

One process deviation, recorded and accepted, as on PR 2. The tester did not
run the gates; the dispatching session ran them and `audit.md` states that it
accepts the printed summary. I read the logs under `logs/pr-3/`, and every
figure the audit reports matches its log.

## Decision

PASS. The production change is one call site and four lines, with no branch on
the weight shape and no second copy of the routing predicate. All eleven rows
are covered, none twice, at the test-spec's own tolerances. Both pre-existing
warnings are pinned at exactly one occurrence on a filtered design. The
snapshot directory and `plans/error-messages.md` are untouched. Every gate has
a result, none was skipped, and coverage holds at 96.25% with no new uncovered
line.

## Carry-forward into PR 4 and PR 5

1. **The helper's comment is now stale, and PR 4 is the PR that repairs it.**
   `R/methods-conversion.R:37-43` still reads "The class this helper serves
   today, `survey.design2`, keeps the frame at `converted$variables`." After
   this PR the helper also serves `svyrep.design`, which keeps the frame in the
   same place, so the sentence is incomplete rather than wrong. PR 4 adds the
   two-phase frame branch and rewrites that paragraph anyway. Name all three
   classes there.
2. **The call-site count.** Two call sites exist today, at
   `R/methods-conversion.R:260` and `:427`. PR 5's criterion 8 counts "one
   helper, one argument, three call sites, no duplicated mask or branch". That
   count reaches three only after PR 4 lands, so PR 5 must not run it earlier.
3. **Do not copy this PR's condition idiom onto the two-phase route.** The
   `expect_no_warning(expect_warning(..., class = ))` nesting works here
   because the replicate and non-probability routes raise at most one typed
   warning. On the two-phase route `survey` emits untyped warnings of its own,
   so the outer expectation would fail on `survey`'s noise. `test-spec.md`
   §G-1c gives the class-pattern technique for that route and forbids
   `expect_no_condition()` there.
4. **`test_invariants()` for `as_survey_twophase()`.** The file still carries
   no call for that constructor. PR 4 adds exactly one, in B-1, per
   `test-spec.md` §Invariants. PR 3 correctly added none.
5. **Small domains and the warning count.** Four blocks in this PR pass
   `min_cell_n = 1L` to `get_means()`, because the domains hold 20 to 29 rows
   against a default threshold of 30. Without it the suite's warning total
   moves off 256 and the audit's before/after row changes. PR 4's B-2 calls
   `get_means()` on a two-phase design; if its domain falls below 30 rows, pass
   the same argument.
6. **Fixtures PR 4 can reuse.** `make_filtered_taylor()` (3069),
   `make_filtered_rep()` (3521) and `make_filtered_nonprob()` (3531) sit in the
   file. PR 4 needs its own filtered two-phase fixture, and `test-spec.md` §B-4
   warns that the file's own two-phase builder names no phase-2 cluster
   identifier.
7. **One thing no row asserts, recorded so it is a known state.** `spec.md`
   §`as_svydesign(x)` → Returns says the stored call survives the restriction
   on every route, and F-2 asserts it on the Taylor route only. The operator is
   shared and the helper has one body, so the claim is pinned once. The
   filtered replicate round trip is untested. This matches the frozen
   test-spec and is not a gap this PR introduced; it is one block if a later
   reader wants it.
