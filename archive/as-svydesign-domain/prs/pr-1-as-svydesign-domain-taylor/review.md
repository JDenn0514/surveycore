# Review — PR 1 — as-svydesign-domain-taylor

**Verdict**: PASS
**Date**: 2026-09-10 15:10

**Tree audited**: `a2f6baac6d514b1cc33739cdd66831e394425333`
**HEAD**: `a65674e` on `fix/as-svydesign-domain-taylor`, rebased onto `develop` @ `24220af`
**Diff read**: `git diff origin/develop...HEAD` — 2 files, 384 insertions, 1 deletion

## Convergence checks

- Spec coverage: **y**
- Test coverage of spec: **y**
- Tolerance integrity: **y**
- Scope discipline: **y**
- Regression safety: **y**
- Comprehension alignment: **n/a** — no `comprehension.md` [no such file]; Stage 0 skipped by the user

### Spec coverage — the helper and the Taylor route

Every term of `spec.md` §`.restrict_to_domain(converted)` is in the diff, and
each one has an audited row or is verified structurally in the source.

| Spec term | In the code | Validated by |
|---|---|---|
| One argument, `.`-prefixed, internal, under the internal-helpers heading | `R/methods-conversion.R:61`, after `.to_formula()`, under the heading at line 12 | structural, read in source; PR 5 asserts the final count |
| Column-presence check; absent column returns `converted` un-indexed | lines 62–66 | C-1 — row count identical, marker absent, `expect_no_condition()` |
| `as.logical()` first, then `r & !is.na(r)` | lines 68–69 | the five-type block (L3313), the unconvertible-factor block (L3339), the `NA`-row block (L3356) |
| `[` and never `subset()` | line 69, `converted[r & !is.na(r), ]` | F-1, F-2, F-3 — the stored call deparses identically filtered and unfiltered, and the round trip recovers `ids`, `strata`, `weights` |
| No two-phase frame branch yet | `frame <- converted$variables`, no class branch | verified in source; PR 4's task |
| Called once per route, on the object just built, immediately before the return | line 260, the last expression of `.as_svydesign_taylor()`; the `eval(bquote(...))` value now assigns to `converted` | A-1, A-4, A-5, A-6, D-1 |
| Input design untouched; a second call converts the same way | no write to `x` anywhere in the diff | D-8 |
| Raises no condition | no `cli_abort()` and no `cli_warn()` added | G-1a |
| Same class returned | `[` preserves the class | G-1a asserts `inherits(sv, "survey.design2")` |
| Marker column stays, all values `TRUE` | no column drop | A-4's two marker assertions, on the same call site and the same converted class; D-7 is PR 4's |

The two shapes this one call site serves are both tested: `survey_taylor`
(A-1, A-5, A-6) and `survey_nonprob` naming no replicate weights (A-4), which
is why D13 moved A-4 into this PR.

### Test-spec coverage of spec

No planner gap on PR 1's surface. Each of the eleven budgeted rows maps to one
block, and each `spec.md` §Quality gates bullet for this PR's routes has a
claiming row in the plan's gate map.

### Implementation and audit describe the same system

They converge. Both name the same helper, the same one-argument shape, the same
mask, the same single call site, the same eleven rows and the same four extra
blocks. Three cosmetic staleness items, none of them a disagreement about
behaviour:

1. `implementation.md`'s header records `HEAD: 49e17bb` and `Base: a545505`.
   The real HEAD is `a65674e` and the base is `24220af`. The rebase and the fix
   are both disclosed further down the same file, under the two changes made on
   the branch and under BLOCK 1.
2. `implementation.md` says 14 blocks. Its own enumeration sums to 15, and the
   file holds 15, from L3082 to L3374.
3. `audit.md`'s Per-Test table line numbers run three lines early from D-1
   onward — D-1 at 3217, really 3220 — because the table predates the C-1 fix
   that added three net lines above them. Every block title in the table
   matches a real block exactly.

## Tolerance integrity

No violation. Every numeric comparison in the new section carries the
`test-spec.md` §Tolerances value verbatim — point `1e-10`, SE `1e-8` — at
`expect_equal()`, with `expect_identical()` on row counts, names and
`@variables`. Grepped the whole new section: 13 `tolerance =` arguments, all
`1e-10` or `1e-8`, none looser, none omitted on a numeric row. No CI-bound row
falls in this PR; F-4 is PR 2's.

**No hand-computed expected value stands where an oracle was available.** A-1,
A-5, A-6 and D-1 compare `survey::svymean()` against `get_means()` on the
filtered design. A-4 does the same and adds a second oracle — the identical
frame and domain through `as_survey()` — as an extra assertion, not a
substitute. The only literal expected values are the two zeros in the
all-`FALSE` block, which `spec.md` §Documentation contract item 6 measured as
the Taylor route's outcome, and that block is PR 2's row D-2a, not audited
here.

**The coordinator's test edit (`478b09d`) is sound and tightens toward spec.**
It replaced the builder's ratio-identity assertion with
`expect_equal(as.numeric(survey::SE(sm)), sc$se[[1L]], tolerance = 1e-8)`.
Test-spec row A-4 asks for exactly that: `survey::svymean()` on the converted
object against `get_means()` on the filtered design, point and SE, at point
1e-10 and SE 1e-8, with the warning captured by
`expect_warning(sv <- ..., class = ...)` and the result read off the return
value. The block does all four. The ratio identity it replaced did **not**
satisfy A-4 — it pinned the defect instead of the parity — so the edit closes a
row that was open, and it relaxes nothing. `decisions.md` D15 records the same
block as the single failure the #263 fix produced, which is independent
evidence that the rewrite was required rather than optional. The process
irregularity is real, because test content is the builder's domain, and it is
disclosed in `implementation.md` and reflected in `audit.md`, which reports the
row as real oracle parity and not a ratio. No verdict consequence.

## Scope discipline

`implementation.md` §Write surface lists `R/methods-conversion.R` and
`tests/testthat/test-conversion.R`. The plan's PR 1 entry lists the same two
files. Verified against `origin/develop`:

```
git diff --numstat origin/develop...HEAD
47      1       R/methods-conversion.R
337     0       tests/testthat/test-conversion.R
```

`NAMESPACE`, `NEWS.md`, `DESCRIPTION`, everything under `man/`, everything
under `changelog/`, everything under `tests/testthat/_snaps/`, and
`plans/error-messages.md` are byte-identical to `origin/develop` — each checked
by name, each an empty diff. No extra file, no missing file.

Two further scope facts:

- The R diff is two hunks: the helper, and the one line that assigns
  `survey::svydesign()`'s value to `converted` plus the call. No other route,
  no roxygen, nothing else in the file.
- The test diff is one hunk appended at the end of the file, 337 insertions and
  **zero deletions**. No pre-existing block was edited, moved or removed. The
  `test_invariants(` count is 6 on both `HEAD` and `origin/develop`, which is
  what `test-spec.md` §Invariants requires of this PR.

### The four extra blocks — judged, not waved through

The builder wrote four blocks past its task list: the five-type marker loop
(L3313), the unconvertible factor (L3339), the `NA` marker row (L3356) and the
all-`FALSE` marker (L3374). They cover the plan's rows D-2a, D-4, D-6, D-6a,
D-6c and part of D-6b, all assigned to PR 2.

**Not scope creep, and not a repeat of issue #165.** Five grounds:

1. No production code beyond the spec. The R diff is the helper and one call
   site. The extra content is test content only.
2. The behaviour they pin is `spec.md` §`.restrict_to_domain()` → Edge cases,
   which PR 1 ships in full. The plan says so itself: PR 1 ships the complete
   row mask, including `as.logical()` and the `NA` resolution, so PR 2 adds no
   production code and pins marker-column behaviour PR 1 already delivers.
3. Both files are PR 1's authorised write surface. Nothing landed outside it.
4. The #165 failure mode needs the later PR to be locked out of the file. PR
   2's write surface **is** `tests/testthat/test-conversion.R`, the same file,
   so PR 2 can extend, rename or delete anything PR 1 wrote here. The coupling
   is repairable by the PR that inherits it.
5. The budget moves the safe way. PR 2 drops from 11 claimed rows to about 5,
   well inside the bound of 12, which retires the plan's own warning that row
   headroom is thin on PR 2.

**What PR 2 should do.** Recompute the row ledger before dispatch:

- Still open, unchanged: D-3 (a single `TRUE`), D-5a (all `NA`), E-1
  (`as_tbl_svy()`), F-4 (round trip point, SE and both CI bounds), F-5 (the
  rebuilt design's all-`TRUE` marker and its `Domain: n of n rows` line).
- **One assertion is owed on a row PR 1 half-covered.** D-6b requires the row
  count **and** that every probability in the converted object is finite. The
  five-type loop asserts the row count and `expect_no_condition()` for the
  `FALSE`/`TRUE` factor, and never asserts `all(is.finite(sv$prob))`. That is
  the assertion `test-spec.md` calls the guard on finding F10 — the corrupt
  probability vector a factor marker built before coercion. PR 2 must add it,
  to the existing loop block or to a block of its own.
- Mark D-2a, D-4, D-6, D-6a and D-6c satisfied by PR 1 in the ledger rather
  than re-writing them. A second copy of each in one file buys nothing, and the
  house norm is against it.
- PR 2 keeps a coherent job on that basis: five rows plus one assertion, all in
  the one file, still the PR that closes §D and §F for the Taylor route. Do not
  drop it.

### Regression safety

No test outside this PR's scope changed state. `devtools::test()` reads FAIL 0
on both cycles, 11685 then 11686 passing, WARN 256 both times, which is the
pre-existing AAPOR small-cell count. The zero-deletion, single-hunk,
append-only test diff independently rules out a silently altered pre-existing
assertion.

One bookkeeping note on the Before column, not an integrity finding. The
audit's Before figures — 11606 passing, 96.24% — were captured on the pre-#263
`develop`, so the +80 test delta mixes #263's tests with PR 1's. The floor and
the direction are what the gate needs, and both hold.

## Profile gates

Every gate has a result. Log paths `logs/pr-1/` for the first cycle and
`logs/pr-1-fix/` for the audited tree.

| Gate | Result | Reviewer's check |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; `man/` and `NAMESPACE` diffs empty against `origin/develop` |
| `devtools::test()` | PASS | `logs/pr-1-fix/gate-2-test.log` tail reads FAIL 0, WARN 256, SKIP 4, PASS 11686. The log differs from the first cycle's by exactly the one added assertion, so the gate genuinely reran on this tree |
| `devtools::run_examples()` | PASS | log present |
| `R CMD build` | PASS | tarball produced |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` — CRAN incoming feasibility, pre-approved, and the pre-existing hidden-file `.git` NOTE that `.Rbuildignore` causes and this PR cannot fix. No new NOTE pattern |
| `pkgdown::build_site()` | SKIPPED — justified | see below |
| `covr` | 96.25% | see below |

**The pkgdown skip is justified, not undocumented.** The profile's scope-skip
clause reads on the write surface, and this PR does touch `R/`. The audit's
ground is different and stronger, and I verified it:
`git diff --name-only 478b09d a65674e -- R/` returns nothing, so the only change
between the tree pkgdown passed on and the audited tree is one test file.
`logs/pr-1/gate-6-pkgdown.log` ends with the site built, and its only
`[WARNING]` is a pandoc duplicate-identifier line from an unchanged vignette.
The hard rule does not fire either: the `NAMESPACE` diff is empty, so no export
changed.

**Coverage.** 96.25% package against a recorded 96.24% baseline — up 0.01, no
drop, and the 95% floor is clear. No new-code gap:
`R/methods-conversion.R` reads 99.77% and its one uncovered line is 571, a
pre-existing `# nocov`-marked defensive `return(NULL)` in
`.find_col_by_value()`, outside both of this PR's hunks. The gate's
changed-file list naming `R/analysis-means-helpers.R` is the `run-gates.sh`
artifact the dispatch flagged: the script diffs against local `develop` pinned
at `a545505`, which predates #263. Against `origin/develop` this PR changes one
R file, confirmed by `git diff --name-only origin/develop...HEAD`. Measurement
artifact, not a finding, and the three uncovered lines it drags in belong to a
file PR 1 does not touch.

## CRAN cookbook

`audit.md` reports None and the audit verdict is PASS, so there is no
tester-classification error. Spot-checked the nine-line helper and the one
changed call: no `T`/`F`, no `set.seed()`, no bare `print()` or `cat()`, no
`options(warn = -1)`, no `installed.packages()`, no `<<-`, no unrestored state,
no home write, no core count.

## The deferred structural gate

`spec.md` §Quality gates asks for one helper, one argument, three call sites,
and no duplicated mask or branch. The plan defers the assertion to PR 5,
criterion 8, which reads the arc's final state. Nothing in PR 1 pre-empts or
contradicts it. Counted on this tree:

- definitions of `.restrict_to_domain`: 1, at line 61, one argument
- call sites: 1, at line 260, in `.as_svydesign_taylor()` — the count PR 1 is
  meant to leave; PRs 3 and 4 add the other two
- mask expression `r & !is.na(r)`: 1 occurrence in `R/`
- column-presence check: 1
- frame-selection branch: 0, correctly — PR 4 adds it
- call sites passing a frame: 0
- other definitions repo-wide: none

## Cross-consistency notes

One standing risk, recorded because it belongs to the arc rather than to this
PR. The roxygen at `R/methods-conversion.R:132-144` still says the converted
object represents the full stored sample and not the active domain, and still
tells the caller to subset the returned object by hand. PR 1 changes the Taylor
route's behaviour and leaves that text for PR 5, which is the plan's stated
sequencing and passed plan review. The consequence is that `develop` carries
documentation contradicting its own behaviour until PR 5 merges. It reaches no
user unless a release runs from `develop` in that window, which `/merge-main`
governs. If the arc stalls anywhere before PR 5, the `@section` block is the
first thing to fix.

Four untracked planning files sit in `plans/` in this worktree. They are not in
the PR diff. The shipper should stage by path, not with `git add -A`.

## Decision

PASS. All seven checks are clean: every term of the spec's helper and Taylor
contract is in the diff with an audited row behind it, every tolerance matches
`test-spec.md` exactly, the write surface is the two planned files and nothing
else, the test diff is append-only with zero deletions, the gates all have a
result with the one skip verified against a byte-identical `R/`, coverage clears
the floor with no new-code gap, and `audit.md`'s verdict is PASS. The BLOCK
cycle closed correctly, and C-1 now asserts all three things its row specifies.
The HOLD closed without amending a frozen artifact, and the coordinator's test
edit moved row A-4 onto the assertion the test-spec asks for. The four
out-of-budget test blocks are test-only, inside the write surface, inside the
spec's edge cases, and repairable by PR 2, which owns the same file; PR 2's
ledger needs recomputing and still owes D-6b's finite-probability assertion.
