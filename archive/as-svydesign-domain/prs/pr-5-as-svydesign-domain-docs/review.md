# Review — PR 5 — as-svydesign-domain (docs)

**Verdict**: PASS
**Date**: 2026-09-11

Branch `docs/as-svydesign-domain` at `eb602c0`, tree
`677a9f3fadf6da9fab20b9bfb42d1c709124a236`, cut from `develop` at `d5dcca4`,
which is `origin/develop`. The tree hash matches the one `implementation.md`
records, the one `audit.md` records, and the one `logs/pr-5-summary.txt`
prints. One commit. The local `develop` ref is stale, so every diff below is
against `origin/develop`.

## Convergence checks

- Spec coverage: yes. The nine items of `spec.md` §Documentation contract →
  The `@section` block, plus the `@return` sentence, are all present in
  `R/methods-conversion.R` and in `man/as_svydesign.Rd`. Verified item by
  item below, not from `audit.md`'s summary.
- Test coverage of spec: yes, by construction. `test-spec.md` holds no row for
  this PR. That is a planner decision, not a gap, and the plan states the
  reason at the PR 5 Budget line: the surface is roxygen and one changelog
  file, and the suite reaches it through `devtools::document()`,
  `devtools::run_examples()` and `R CMD check`, which criteria 3, 6 and 7
  assert. I confirmed `test-spec.md` names no roxygen, documentation or
  changelog row anywhere.
- Tolerance integrity: not applicable and not evaded. The PR adds no test and
  edits none; `tests/` is absent from the diff. The only tolerances named
  anywhere in this PR are the changelog's `1e-10` point and `1e-8` SE, which
  are `test-spec.md` §Tolerances unchanged.
- Scope discipline: yes. Exactly three files, and they are the three the plan
  lists.
- Regression safety: yes. FAIL 0, WARN 256, SKIP 4, PASS 11800 and coverage
  96.25% before and after — identical, as a PR that adds no executable line
  must be.

## Item-by-item check of the `@section` block

Read on `R/methods-conversion.R:145-198` and `man/as_svydesign.Rd:75-132`.
The nine items appear in the spec's order, each once.

| Spec item | Where | Verdict |
|---|---|---|
| 1 — active domain, not the full stored sample | R 146-147 | present, first |
| 2 — how a domain arrives; `SURVEYCORE_DOMAIN_COL` = `"..surveycore_domain.."` | R 149-151 | present |
| 3 — applies whenever the column is present; never-filtered converts unrestricted | R 151-153 | present |
| 4 — the marker stays, is an internal marker, all-`TRUE` on the row-removing routes, unchanged on two-phase | R 155-158 | present |
| 5 — an `NA` marker counts as outside the domain | R 158-159 | present |
| 6 — an empty domain still converts, silently, with three outcomes scoped per route | R 161-172 | present |
| 7 — two-phase weights out rather than removes; the estimator difference, both measured pairs, no issue number | R 174-183 | present |
| 8 — the round trip, with the two-phase exception stated separately | R 185-194 | present |
| 9 — `as_tbl_svy()` and `srvyr::filter()`, from inside this section | R 196-200 | present |

Item 6 is the one the spec singled out (F9), and it is scoped correctly. The
block does not make the blanket "0 with a standard error of 0" claim. It says
the conversion raises no surveycore condition on any route, then names the
three outcomes in a list: 0 with a standard error of 0 on Taylor and on the
non-probability shape naming no replicate weights; an error from `survey` at
estimation time on the replicate route and on the non-probability shape naming
replicate weights; `NaN` on two-phase. That matches the five-row measured
table in `spec.md` item 6 exactly, collapsed the way the spec's own closing
paragraph instructs.

Item 7 carries both pairs — 58.458 against 58.067 filtered, 48.9245 against
49.20304 unfiltered — names the mechanism (the phase-1 weight column against
the combined two-phase probability), says the same difference sits on the
unfiltered design, and cites no issue number. Grep of every added `#'` line
for `#[0-9]+` returns nothing.

Item 8's two-phase exception is a separate sentence at the end of the
paragraph, not folded into the general statement, which is what the spec asks.

Item 9 sits inside `as_svydesign()`'s own section and names `as_tbl_svy()`
from there. `man/as_tbl_svy.Rd` is byte-identical to `origin/develop`, so the
spec's reason for putting it here — not adding a fifth file — holds.

**Claims the block makes that `spec.md` does not support: none found.** Every
sentence traces to `spec.md` §Documentation contract, §Scope → In (the
infinite-probability mechanism), §Out (the estimator gap), or §Quality gates
(`survey::svymean()` answers the domain estimate). One note on precision is
below.

## Both false sentences are gone

`git diff origin/develop...HEAD -- R/methods-conversion.R` removes, among the
old block, exactly these two claims:

- `The converted object represents the full stored sample and not the active domain.`
- `A caller who wants the domain has to subset the returned object on that column: subset(converted, ..surveycore_domain..) does it`

Neither survives. `grep` across `R/` and `man/` for `full stored sample`,
`answers for every row` and `subset(converted` returns no hit in either file.
The one remaining `full stored sample` in the repository is
`changelog/fix-as-svydesign-bridge.md:84`, a previous arc's changelog, which is
a historical record and correctly untouched. The word `subset` survives in
`man/as_svydesign.Rd:117` only in the true sentence "a `survey` object records
a subset and not a marker", and in `R/` only in unrelated two-phase code.

## The `@return` sentence

`R/methods-conversion.R:102-104`, rendered at `man/as_svydesign.Rd:18-20`:

> A filtered input returns an object restricted to the active domain; the
> `A filtered design's domain` section below states what that means on each
> route.

Present, and it names the section by its exact title. It sits after the
class-per-input detail and before the value-label detail, so a reader who
stops at `@return` meets the fact. Rd renders the title as `\verb{...}`; there
is no cross-reference macro for a section inside the same topic, so this is
the correct treatment and not a missing link.

## Register — the ruling on item 8's closing sentence

**Finding: no. Note: yes.** The sentence reads "Keep the original design when
you need the original row count", where `spec.md` writes "A caller who needs
the original N keeps the original design". I rule this a note and do not
BLOCK, on three grounds.

1. **The rule does not reach here.** `code-style.md`'s "Never address the user
   ('You must...')" sits inside §Errors and warnings, in the register register
   for `cli_abort()` and `cli_warn()` bullets — the same list that requires the
   `"v"` bullet to be imperative. It governs condition messages, not roxygen
   prose. No rule in `.claude/rules/` sets a register for documentation text.
2. **The file's own voice already says it this way.** `@section A
   non-probability design:` ends "Keep the original object when you need any of
   that." That sentence is on `origin/develop`, this PR does not touch it, and
   it is eleven lines above the new block in the same roxygen header. A BLOCK
   would make two adjacent sections of one help page disagree on voice, which
   is a worse outcome than the deviation.
3. **The spec fixes the fact, not the wording.** §Documentation contract item 8
   says what must be stated. The block states it. No fact moves.

Against that, the cost: one more builder cycle plus a seven-gate rerun on a
host that `decisions.md` records sitting at 1.5 to 1.8 GB free, to change a
sentence that conveys the same fact and matches its neighbour. The ledger
would also gain a reviewer BLOCK for a house rule that does not cover the
text. Recorded here so a later reader sees the call was made, not missed.

## Scope discipline

`git diff --stat origin/develop...HEAD` names exactly three files:
`R/methods-conversion.R` (+72/-28), `changelog/fix-as-svydesign-domain.md`
(+81), `man/as_svydesign.Rd` (+73/-28). That is the plan's Files-touched list
with nothing added and nothing missing.

The `R/` diff is roxygen-only. Run myself:

```
git diff -U0 origin/develop...HEAD -- R/ | grep -E "^[+-]" \
  | grep -vE "^(\+\+\+|---)" | grep -vE "^[+-]#'"
```

returns empty. No executable line changed on either side of the diff.

`git diff --stat origin/develop...HEAD -- NEWS.md NAMESPACE plans/ tests/ DESCRIPTION vignettes/ _pkgdown.yml`
returns empty, which covers plan criterion 5 and the spec's
`plans/error-messages.md` byte-identity gate. Nothing under `tests/`.

`git status` shows one modified and four untracked files under `plans/` — the
arc's planning artifacts, outside every PR's write surface. Pre-existing,
unchanged, correctly uncommitted. Not scope creep. I did not touch them and
neither did the audit.

## Structural gate — counted independently

`spec.md` §Quality gates' structural bullet, plan criterion 8, read by me on
the final state of the file with `grep`, not taken from `audit.md`:

| Check | Expected | Measured |
|---|--:|--:|
| `^\.restrict_to_domain <- function` | 1 | 1 (line 68) |
| Its arity | 1 | 1 — `function(converted)` |
| `\.restrict_to_domain(converted)` call sites | 3 | 3 (315, 482, 528) |
| `restrict_to_domain` anywhere in `R/` outside that file | 0 | 0 |
| Mask `r & !is.na(r)` in `R/` | 1 | 1 (line 80) |
| Presence check `SURVEYCORE_DOMAIN_COL %in% names(frame)` in `R/` | 1 | 1 (line 75) |
| Frame branch `inherits(converted, "twophase2")` in `R/` | 1 | 1 (line 69) |

The three call sites are one each in `.as_svydesign_taylor()`,
`.as_svydesign_replicate()` and `.as_svydesign_twophase()`, in that order, and
none passes a frame. The counts sit 44 lines below where the PR 4 review
recorded them (271, 438, 484), which is exactly the net line growth this PR's
roxygen adds (+72/-28). The helper body I read at lines 68-81 holds the branch,
the check and the mask, and nothing else does. Gate satisfied. No second copy
to report as a finding.

## Changelog

`changelog/fix-as-svydesign-domain.md`, checked against
`.claude/skills/changelog-workflow.md`.

| Requirement | State |
|---|---|
| Flat path `changelog/{type}-{slug}.md` | yes — no subdirectory, type `fix`, kebab slug |
| Title `# Changelog: {type}/{slug}` | `# Changelog: fix/as-svydesign-domain` |
| `**Branches:**` | five, the documented replacement for `**Branch:**` on a multi-branch feature |
| `**PRs:**` | `#266, #267, #268, #269, and this PR` |
| `**Issues:**` | `#245` |
| `**Status:**` / `**Date:**` | `Complete` / `2026-09-11`, a real date |
| `## Summary` opens with the issue | `Closes #245.` |
| First sentence names the return-value change | yes — "`as_svydesign()` now returns an object restricted to the active domain: a filtered design converts to the domain and not to the full stored sample" |
| `## Files Modified` before `## Changes` | yes |
| `## Verification` (optional) | present, and carries numbers |

Factual claims, checked against the shipped PRs and `spec.md`:

- `#266` — "Restrict a converted Taylor design to the active domain". Matches
  the merged commit `1674bf6`, which carried the Taylor route and the helper.
- `#267` — "Pin the marker column's edge cases and the round trip". Matches
  `67914a0`, a test-only PR.
- `#268` — replicate plus both non-probability shapes. Matches.
- `#269` — two-phase, "by weighting the excluded rows out rather than by
  removing them". Matches D8 and `spec.md` §Scope → In.
- The two-phase paragraph gives the same two pairs the roxygen gives and adds
  `Refs #261`, which is allowed in a changelog and forbidden only in the
  user-facing roxygen. The roxygen carries no issue number.
- `## Verification`'s "point estimates to 1e-10, standard errors to 1e-8" is
  `test-spec.md` §Tolerances unchanged, and "11800 passing expectations,
  coverage 96.25%" matches the gate run and the audit's before column.

`## Files Modified` lists the three source-side files of the whole arc and not
this PR's three, which is right for an arc-level entry that four merged PRs
already built.

## Profile gates

All seven ran in one call on tree `677a9f3`, the branch tree. Read from
`logs/pr-5-summary.txt` and the per-gate logs; I ran nothing.

| Gate | Result | Note |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing — the committed `.Rd` is current |
| `devtools::test()` | PASS | FAIL 0, WARN 256, SKIP 4, PASS 11800 |
| `run_examples()` | PASS | no example added or changed |
| `R CMD build` | PASS | `surveycore_1.1.0.9000.tar.gz` |
| `R CMD check --as-cran` | PASS | `Status: 2 NOTEs` |
| `pkgdown::build_site()` | PASS | ran, not skipped — write surface touches `R/` |
| `covr::package_coverage()` | PASS | 96.25% |

No gate skipped, so no skip condition to justify.

The two NOTEs are `checking CRAN incoming feasibility`, pre-approved in
`r-package-profile.md`, and `checking for hidden files and directories`,
which finds `.git` and is caused by `.Rbuildignore`. The second is not on the
profile's pre-approved list, but it is not a new pattern: it is recorded on
every PR of this arc from PR 0 forward, and `archive/as-svydesign-bridge/`
records it under AC-6 for the same reason. No PR can fix it. Accepted, as in
the four reviews before this one.

pkgdown built the page. `logs/pr-5/gate-6-pkgdown.log` line 38 reads
`Reading man/as_svydesign.Rd` and line 39 `Writing reference/as_svydesign.html`,
with no error between them. Plan criterion 6 met.

## Coverage

96.25%, against a `develop` baseline of 96.25%. Floor is 95%. No drop, and no
drop is possible: the PR adds no executable line, so it adds no new line to be
uncovered. `R/methods-conversion.R` reads 99.77% with one uncovered line, 630,
which is the `# nocov — callers always pass non-NULL` early return inside
`.find_col_by_value()` — pre-existing, unrelated to this arc, and carrying its
explanatory comment as `testing-standards.md` requires.

The runner's `changed R/ files: 2` line is the stale-local-`develop`
misreport the audit names. The second file is `R/analysis-means-helpers.R`,
which PR #263 touched before this branch was cut; its three uncovered lines
(180, 268, 336) are on `origin/develop` already and are outside this PR's
write surface. Against `origin/develop` one `R/` file changed, and only its
comments.

## CRAN cookbook

`audit.md` reports None, and its verdict is PASS, so there is no
tester-classification error to escalate. The classification is sound on its
face: the `R/` diff contains no executable line, so no executable-code pattern
can appear in it. The audit scanned anyway and found nothing.

## Comprehension alignment

No `comprehension.md` [no such file] — the run was trimmed by the user's scope note in
`request.md`, which skips Deep Comprehension and the methods review on the
grounds that the issue locks the decision and the change adds no statistical
method. Step 6 does not apply.

## Notes — recorded, not findings

1. **Precision beyond the logged measurement.** The roxygen's unfiltered pair
   reads 48.9245 against 49.20304. `spec.md` §Out and
   `findings-preflight.md` §F3 print the same pair rounded, 48.9 against
   49.203, and no artifact in the run directory prints the longer digits. The
   builder took them from `decisions.md` §"PR 4 review PASS — carry-forward
   into PR 5", item 4, which is the instruction it was given, and the two
   forms agree on rounding. Not a contradiction and not a finding. A later
   reader who wants to verify the third and fourth digits has to re-run the
   `findings-preflight.md` §F3 snippet; the run directory will not answer it.
2. **Register**, ruled above.

## Decision

PASS. The `@section` block states the nine items of `spec.md` §Documentation
contract in order, adds no claim the spec does not support, and both false
sentences are gone from `R/` and from `man/`. The `@return` sentence is
present and names the section. The write surface is the plan's three files and
the `R/` half of it is roxygen-only. The structural gate holds on my own
grep. All seven gates pass on the audited tree, coverage is at the arc's
steady 96.25%, and the two NOTEs are the two this arc has carried since PR 0.

---

## Arc closeout

This is the last PR of the arc. Issue #245 opened it; PRs #266, #267, #268,
#269 and this one close it.

### Did any PR deliver less than `spec.md` promised?

No. Every row of `spec.md` §Quality gates has an owner in the plan's
gates-to-PRs map, and every owner shipped:

| Spec gate | Owner | State |
|---|---|---|
| One row per marked row on four routes; finite-probability count on two-phase | PR 1, PR 3, PR 4 | delivered |
| `svymean()` answers the domain estimate on all five shapes | PR 1, PR 3, PR 4 | delivered |
| An unfiltered design converts exactly as before | PR 1, PR 3, PR 4 | delivered |
| The stored call is the same expression | PR 1 (F-2) | delivered, Taylor only — see deferred item 4 |
| The round trip names `ids`, `strata`, `weights` | PR 1 | delivered |
| No condition the unfiltered design does not raise | PR 1, PR 3, PR 4 | delivered |
| The marker column stays on every route | PR 1, PR 3, PR 4 | delivered |
| The marker column's type does not change the outcome | PR 2 | delivered |
| The input design is unchanged | PR 1 | delivered |
| One helper, one argument, three call sites, no duplicate mask or branch | built PR 1/3/4, asserted PR 5 | delivered and counted above |
| `plans/error-messages.md` byte-identical | every PR | delivered |
| `document()`, `check()`, coverage floor | every PR | delivered |
| §Documentation contract — the nine items and the `@return` sentence | PR 5 | delivered |

All 43 `test-spec.md` rows are claimed once in the plan's row ledger and all
43 shipped. The write surface across the arc is the four files `spec.md`
§Files touched names, and no fifth file changed. `NEWS.md` correctly stayed
out: `/merge-main` drafts its release section from `changelog/`.

Nothing `spec.md` promised is missing and undeferred.

### The five items the arc carries forward

Each is recorded somewhere a later reader will find it.

1. **Issue #246 — the eight in-place copies of the `survey_nonprob` routing
   predicate.** Recorded in `spec.md` §Out, which also states this arc added
   no ninth copy. An open GitHub issue, so it survives the run directory.
2. **Issue #261 — the two-phase weighting gap.** Recorded in `spec.md` §Out,
   `decisions.md` §D3, `test-spec.md` (rows B-2 and the F3 coverage line), and
   `changelog/fix-as-svydesign-domain.md` as `Refs #261`. The changelog entry
   is the durable one: it lands in `NEWS.md` at the next release. The roxygen
   states the difference without the number, which is what `spec.md` item 7
   requires.
3. **Issue #262 — `.apply_domain()`'s raw marker read, and the five grouped
   `get_*()` functions that share it.** Recorded in `spec.md` §Function
   contracts (the third-reader paragraph D10 added), `decisions.md` §D9/§D10,
   and `spec-review.md` R-1. An open issue.
4. **The stored call on the four non-Taylor routes.** `spec.md` line 181 says
   the restriction "preserves the stored call on every route"; the §Quality
   gates bullet and `test-spec.md` row F-2 pin it on the Taylor route only.
   The helper has one body and one operator, so the claim is pinned once and
   generalises by construction, but no row asserts it on the other four
   routes. Recorded in the PR 3 review, the PR 4 review (carry-forward item 6)
   and `decisions.md` §"PR 4 review PASS". **This is the one deferred item
   with no GitHub issue.** It survives only in the archived run directory.
   That is weaker than the other four, and it is the item to raise if the arc
   is ever reopened. It is not a defect in PR 5, whose contract is
   documentation and which adds no test block by the plan's design.
5. **The one-row calibrated domain's `NA_real_` (D17).** Filed as issue #265,
   recorded in `decisions.md` §D17 with the full statistical argument and in
   the §"Issue numbers for D15, D16 and D17" table. The neighbouring D16
   deferral is issue #264 in the same table.

### One recommendation for the archive

When this run is archived under `archive/as-svydesign-domain/`, the archive
note should carry two things a later reader cannot reconstruct from the
files: deferred item 4 above, which has no issue number, and the note that the
roxygen's 48.9245 / 49.20304 figures are one rounding step finer than any
measurement the run logged. Both are recorded here; neither blocks the merge.
