# Spec Review — as-svydesign-bridge — Pass 1 (2026-09-08)

Six lenses ran in parallel against `spec.md` and `test-spec.md`.

The orchestrator re-ran or re-read every load-bearing claim before accepting
it. One finding (SR-1) turned out worse than the lens described, and the
orchestrator's own measurement (R12) supersedes both lenses that touched it.

## Verdict

**FAIL — 1 BLOCKING, 12 REQUIRED, 11 SUGGESTION.**

Route to Stage 3r. No settled decision D-1 to D-6 is disturbed. Two additions:
D-7 records the print and summary fix, and issue #246 takes the duplication.

## BLOCKING

### SR-1 — The zero-weight edge case is reachable on a nonprob design (Lens 3, Lens 4)

The Stage 2r resolution recorded zero-weight rows as unreachable on every
class, citing `.validate_weights()` and two S7 validators. Both lenses found
the citation wrong. The orchestrator then measured the reachability and found
the case is real.

Measured (R12):

| Action | `survey_taylor` | `survey_nonprob` |
|---|---|---|
| Construct with a zero weight | blocked | blocked |
| Assign `@data` with a zero weight after construction | blocked | **accepted** |

Both lenses concluded "no such path exists today". One does. `survey_nonprob`'s
S7 validator (`R/core-classes.R:1193` onward) checks two weaker conditions
only: condition 4a rejects a negative weight, condition 4b rejects a column
with no positive value. A single zero passes both, and its own message says
"All non-NA weights must be non-negative (>= 0)". `plans/error-messages.md`
row 33 records the permissiveness as deliberate.

The citation error as well: `R/core-classes.R:688` lies inside the
`survey_replicate` validator, which begins at line 631. It is not the
`survey_nonprob` check.

What the conversion does with such a design (R12):

| Shape | Converts to | `survey::degf()` | `svymean()` SE | surveycore's own SE |
|---|---|--:|--:|--:|
| plain | `survey.design2` | 38 | 0.5296146428 | 0.5296146428 |
| replicate | `svyrep.design` | 7 | 0.2422736303 | 0.2422736303 |

Both shapes convert and the standard errors still agree exactly, so the bridge
needs no new guard. But `survey::degf()` gives 38 where `n - 1` is 39, because
survey drops a zero-weight row on the Taylor path.

**Resolution.** Three parts:

1. Rewrite the `spec.md` edge-case row. Zero-weight rows are unreachable on
   `survey_taylor` and `survey_replicate`, where the validator blocks both
   construction and assignment, and reachable on `survey_nonprob` through
   `@data` assignment. Cite the right lines. State that both shapes convert and
   agree.
2. Add the second qualifier to the roxygen degrees-of-freedom passage. That one
   sentence now carries two measured qualifiers: rank for the replicate shape
   (R9) and zero-weight rows for the plain shape (R12).
3. Reinstate a test row for the case, built by `@data` assignment rather than by
   the constructor. The Stage 2r resolution withdrew Fixture 3 and row B-8 as
   unbuildable. The fixture is buildable; only the build route was wrong.

## REQUIRED

### SR-2 — `@param fpctype` contradicts the corrected `@param fpc` (Lens 6)

`R/core-constructors.R:613-615` says `fpctype` is a "multiplier for the
replicate variance". Verified: `R/variance-replicate.R` holds no `fpc` at all,
so `fpctype` is as inert as `fpc`, and D-1 removes the whole `fpctype` block
from the bridge. D-4 corrects `@param fpc` at 610-612 and leaves the next
parameter block asserting the opposite, three lines away in the same help page.

**Resolution.** Extend D-4's correction to `@param fpctype`.

### SR-3 — Print and summary present the inert FPC as an active field (Lens 6)

`R/methods-print.R:406-413` (`print`, `full = TRUE`) and `:828-831`
(`summary`, unconditional) render `FPC: {col} ({fpctype})` beside `Scale:` and
`MSE:`, which do drive the variance. Nothing marks the FPC as inert. A user
runs `summary(d)`, sees the field listed plainly, then gets a warning saying it
has no effect.

Verified: both sites sit in the `survey_replicate` methods
(`print` at 350, `summary` at 805). The `survey_taylor` sites, lines 279 and
781, must not change: an FPC is active on that class.

Cost measured: three snapshot lines in one file,
`tests/testthat/_snaps/methods-print.md`.

**Resolution — D-7.** Add the caveat to the two replicate branches only. This
applies D-4's own stated rationale, which the user accepted: a warning saying
the field has no effect must not ship beside package output saying otherwise.
Adds `R/methods-print.R` and its snapshot file to the write surface.

### SR-4 — CN-3's remedy names a function the caller may not have called (Lens 6)

CN-3's `"v"` bullet says to call `{.fn as_svydesign}` on the result. The spec
also states CN-3 propagates through `as_tbl_svy()`. A caller of `as_tbl_svy()`
is told to call a different function, which returns the wrong class for their
pipeline.

**Resolution.** Make the bullet caller-agnostic. Name the surveycore-side
remedy and stop, without naming the downstream call.

### SR-5 — `{.pkg}` is used in a registered message and is absent from the style table (Lens 3)

CN-3's `"i"` bullet uses `{.pkg survey}`. `.claude/rules/code-style.md`'s
markup table lists six forms and not `{.pkg}`, and no row in
`plans/error-messages.md` uses it today.

**Resolution.** Keep `{.pkg survey}`. `R/methods-conversion.R` already uses it
in the `surveycore_error_pkg_not_installed` messages, so the codebase's
practice is settled and the rule table is what lags. Note the gap in the spec
and leave `.claude/rules/code-style.md` alone in this PR. See §Rule documents
that lag the code.

### SR-6 — The roxygen additions outweigh the function they document (Lens 5)

The existing `as_svydesign()` block is about 32 lines. The four new
`@section` blocks add roughly 85. They carry worked derivations, a full
per-type ratio table, and the issue numbers #242 to #245.

Two things verified:

- **No user-facing roxygen anywhere in the package cites a GitHub issue
  number.** `grep -rn "^#' .*#[0-9][0-9]" R/*.R` returns nothing. Issue numbers
  appear only in `#` code comments. Putting #242 to #245 in `?as_svydesign`
  breaks that convention and ships tracker numbers to CRAN.
- **`vignettes/surveycore-vs-survey.Rmd` §5 "Notable Differences" exists**, at
  line 613, and `as_svydesign()` appears in no vignette at all. The bridge is
  undocumented there.

D-3 and D-6 require the degrees-of-freedom and domain facts to sit in the
roxygen. That is untouched. What changes is length and register.

**Resolution.** Trim each section to its core fact plus its measured numbers.
Remove every issue number from roxygen. Move the worked derivations, the
per-type table and the `scale` caveat into `vignettes/surveycore-vs-survey.Rmd`
§5, and point at it with `vignette("surveycore-vs-survey")`. Guard any new
vignette chunk that needs `survey` with
`eval = requireNamespace("survey", quietly = TRUE)`, per `CLAUDE.md` §CI. Adds
the vignette to the write surface.

### SR-7 — `as_tbl_svy()` has no numerical row and no stated N/A (Lens 2)

`as_svydesign()` gets seven numerical rows. Section C gets none, and says
nothing about why. `testing-standards.md` treats an unexplained N/A as a gap.

**Resolution.** State the N/A with its reason: `as_tbl_svy()` adds no numeric
logic, and its correctness follows from sections A and B. Add no redundant row.

### SR-8 — CN-2 propagation through `as_tbl_svy()` is untested (Lens 2)

`spec.md` says both new warnings propagate through `as_tbl_svy()`. Section C
tests only CN-3.

**Resolution.** Add a section C row for CN-2, matching C-2's treatment of
CN-3. No snapshot: one golden copy per message.

### SR-9 — Section A's summary line contradicts row A-6 (Lens 2)

The section opens "Rows A-1 to A-6 name an FPC column". Row A-6 is the no-FPC
row, and the Fixture 1 note groups it with the no-FPC rows.

**Resolution.** Correct the summary line.

### SR-10 — B-9 and B-10's reuse instruction is ambiguous (Lens 2)

"Reuse B-5's fixture and its converted object" does not say whether the row
shares a block or rebuilds. The D section resolves the identical ambiguity
explicitly, and the existing `test-conversion.R` rebuilds per block.

**Resolution.** Add the D section's sentence to B-9 and B-10: a test block owns
its own setup.

### SR-11 — A-9 and A-10 specify an assertion with no sanctioned mechanism (Lens 2)

The rows require asserting no condition class begins `surveycore_`. No test in
the repo does that, `class =` matching is by inheritance rather than by
pattern, and inspecting the class vector needs the `tryCatch` family the house
rule forbids.

Measured by the orchestrator:

| Condition | Classes |
|---|---|
| survey's JKn and Fay failures | `simpleError, error, condition` |
| surveycore's `cli_abort()` | `surveycore_error_*, rlang_error, error, condition` |

`inherits(e, "simpleError")` is TRUE for survey's and FALSE for surveycore's.

**Resolution.** Specify `expect_error(..., class = "simpleError")`. It states
the intent exactly, uses only sanctioned testthat, and needs no exception to
the no-`tryCatch` rule.

### SR-12 — The forward leg drops `@calibration` and `@reference_sample` silently (Lens 4)

Neither route reads either property. The roxygen's round-trip passage names
both as lost when `from_svydesign()` rebuilds, which implies the forward leg
preserves them. It does not.

**Resolution.** One sentence in the nonprob roxygen section and one edge-case
row: both fields are dropped on the way out, not only on the way back.

### SR-13 — The eighth copy of the nonprob routing test (Lens 1)

Seven sites already write `!is.null(design@variables$repweights)` in full
inside a `survey_nonprob` branch, and all seven raise the same warning first
bullet as an independent `paste0()` literal. The bridge adds an eighth of each.

**Resolution.** Keep the inline test, and file the consolidation. Issue **#246**
is filed. Reasons: a one-line predicate with a single call site in this PR is
the premature abstraction `engineering-preferences.md` item 3 warns against,
and extracting for one site while seven keep the inline form reads as
consolidation without being it — the argument Lens 1 itself makes against a
partial extraction of the message text. `spec.md` gains a note recording the
eighth copy and citing #246, so the debt is written down rather than silent.

Note for the resolver: `.claude/rules/code-style.md` names the shared-helper
file `07-utils.R`. The file is `R/utils.R`. Cite the real one.

## SUGGESTION — apply

- **SR-14** (Lens 1) `@param fpc`'s corrected text should link
  `[as_svydesign()]` rather than name it in backticks, and point at the roxygen
  section instead of restating it. One authoritative site.
- **SR-15** (Lens 1) Add `[as_survey_nonprob()]` to the nonprob roxygen
  section, so the reader reaches the fuller existing explanation of why the SRS
  approximation understates variance
  (`R/core-constructors.R:1194-1212`).
- **SR-16** (Lens 5) Rewrite A-4 and A-5 to assert no error and no surveycore
  warning class, rather than the absence of survey's message text. Pinning a
  foreign package's wording is what A-9 and A-10 already avoid.
- **SR-17** (Lens 3) Drop or fix the claim that the comment "sits three lines
  above the code this change edits". The comment is at 141-142 and the
  arguments removed are at 156-157.
- **SR-18** (Lens 4) Add an edge-case row for `visible_vars`: `as_svydesign()`
  ignores it, so a `select()`-narrowed design converts with every original
  column present. Consistent with `dim()`, which documents the same at
  `R/methods-compat.R:50-51`.
- **SR-19** (Lens 4) Add an edge-case row for a zero-length `repweights`
  vector: not constructible, with both guards named
  (`surveycore_error_repweights_empty` at 0 columns,
  `surveycore_error_repweights_single` at 1) and `update_design()`'s refusal of
  `survey_nonprob` at `R/update-design.R:227-236`.

## SUGGESTION — decline, with the reason

- **SR-20** (Lens 6) Soften CN-2's "on the converted design" for the two types
  that never convert. Declined: the error that follows makes the outcome plain,
  and both types are tracked as #243 and #244. The lens recommended declining
  too.
- **SR-21** (Lens 6) Prefix CN-3's first bullet to signal the repetition.
  Declined: one concept keeps one phrasing, which D-2 settled.
- **SR-22** (Lens 6) Shorten the new `@section` titles to the terse house
  style. Declined as stated, but SR-6 trims the sections, so re-check the
  titles fit once the prose is shorter.
- **SR-23** (Lens 2) Test the two-replicate-column minimum. Declined: no code
  path branches on the count, and the numeric rows compute their expectations
  from the fixture's own `R`.
- **SR-24** (Lens 4) Test the `R = 2` boundary on the replicate route.
  Declined for the same reason.

## Verified and closed with no finding

- Every quoted "before" roxygen block matches the current source verbatim at
  its stated line, including the two lines that must not change, 344 and 588
  (Lens 3).
- The `CN` register prefix is genuinely unused; all nineteen in-use prefixes
  confirmed; the new subsection's placement and the Coverage Map insertion
  point are right (Lens 3).
- Both new condition class names are unused anywhere in the repo (Lens 3).
- `test_invariants()` needs exactly two new calls. The file calls it for
  `as_survey()` at lines 121 and 754 and for no other constructor (Lens 2).
- `skip_if_not_installed()` placement in the new blocks matches the file's
  existing practice exactly (Lens 2).
- `make_survey_data()`'s real signature matches the test-spec's description,
  and it has no nonprob shape, so the inline fixture is correct per
  `testing-standards.md` (Lens 2).
- The withdrawn Fixture 3 left no dangling reference, and the row arithmetic is
  internally consistent (Lens 2).
- `type = "jackknife"` is normalised to `"JK1"` at construction, so the
  converted object always carries the normalised value (Lens 4).
- `haven_labelled` columns are stripped at construction on all three
  constructors, so `@data` reaching either route is already free of them
  (Lens 4).
- No column name in `@data` can shadow a field `survey` writes: the user's
  frame is nested at `rval$variables`, one level below every field either
  constructor sets (Lens 4, checked against both survey constructors).
- The twophase degenerate-subset and zero-row cases are blocked at
  construction, transitively through `phase1` (Lens 4).
- No new helper, abstraction or indirection is introduced; the nonprob branch
  is inlined into the existing dispatch rather than wrapped in a new function
  (Lens 5).
- Scope holds: all named files are named, and no code fix for #242 to #245
  leaks into the file list or the quality gates (Lens 5).
- Every dispatch branch and every condition class has at least one firing test
  and, where relevant, an absence test. No unexercised new branch (Lens 2).

## Rule documents that lag the code

Two stale references found while reviewing, both outside this PR's scope and
neither blocking. Reported for the user to decide:

- `.claude/rules/code-style.md:22` and `:134` name `R/07-utils.R`. The file is
  `R/utils.R`. The same file's lines 16, 39-41 name `04-methods-print.R`,
  `00-s7-classes.R` and `05-methods-conversion.R`; the real files are
  `methods-print.R`, `core-classes.R` and `methods-conversion.R`.
  `.claude/rules/testing-surveycore.md:166` and `:168` carry the same two stale
  names.
- `.claude/rules/code-style.md`'s inline-markup table omits `{.pkg}`, which
  `R/methods-conversion.R` already uses.

---

# Pass 2 — delta (2026-09-08)

Two Explore agents, one per artifact, scoped to the sections pass 1 changed.
This is the delta pass the review-loop budget allows: at most two agents,
changed sections only.

## Verdict

**PASS, after seven corrections applied by the orchestrator.**

Pass 1's twenty-four resolutions all landed. Pass 2 found four defects the
edits introduced or left behind, and three inaccuracies. All seven are
mechanical, all seven were applied directly, and each was verified by reading
the file back.

## What pass 2 found

### In `test-spec.md`

1. **BLOCKING — the `test_invariants()` call for `as_survey_replicate()` was
   placed wrong.** Row A-1 claimed to hold "the file's first" call for that
   constructor. It is not: the file's own helper `make_rep()` calls
   `as_survey_replicate()` and an existing block uses it at
   `tests/testthat/test-conversion.R:141`, before any new section A block.
   Verified by reading the file. The same document had already reasoned this
   correctly for `test-methods-print.R` and reached the opposite conclusion for
   `test-conversion.R`.
   **Applied:** section A adds no call. Section B keeps its one call, which is
   sound because the file has no non-probability block at all. The pre-existing
   gap is recorded and left to whichever change next touches that block, which
   is how the sibling file's identical gap is already handled. Row count line
   corrected from two calls to one.
2. **BLOCKING — R13 was not folded into the two row-count edge cases.** They
   still read "nothing measured that route". R13 measured it. This was the
   orchestrator's own sequencing: R13 was recorded after pass 1's resolver
   finished, so the resolver could not have cited it.
   **Applied:** both rows now carry R13's measured asymmetry and cite #248. The
   note below the table carries R13's full table.
3. SUGGESTION — the non-default `scale` row stated R11's finding with no
   R-number. **Applied.**
4. SUGGESTION — "the two `as_tbl_svy()` blocks" is three:
   `tests/testthat/test-conversion.R:292`, `:300` and `:311`. **Applied.**

### In `spec.md`

5. **BLOCKING — the row-count loophole section contradicted R13 and cited
   neither R13 nor #248.** Same root cause as item 2.
   **Applied:** the section carries R13's table, the incidental nature of the
   one block, the bare oracle message a one-row design produces on the bridge,
   and #248.
6. **REQUIRED — a fabricated citation.** The section read "The spec review's
   summary said eleven". `spec-review.md` states no file total anywhere;
   searched and confirmed. The number eleven came from the orchestrator's brief
   to the resolver, and the resolver attributed it to this document.
   **Applied:** the attribution is removed. The arithmetic that survives stands
   on its own.
7. SUGGESTION — two quality gates were imprecise. "about 68 lines" is now 68.
   The `fpctype` gate searched only for "adjust", a word the `fpctype` block
   never contained, so it passed whatever happened to that block; it now names
   both phrasings and says why one alone does not hold.

Also corrected: `spec.md`'s header cited R1 to R12.

## Why no pass 3

The budget allows three passes. Pass 2's findings were seven mechanical
corrections with one right answer each, applied by the orchestrator rather than
by a resolver agent, and each verified by reading the changed lines back. A
third panel would re-read text whose only changes are the seven listed above.

Two coherence checks were run instead, over the whole of both artifacts:

- the numbered rows counted directly: 31, matching the header and the six
  per-section figures;
- every measurement range and every superseded figure checked. The one
  surviving mention of the old lens ratio is a labelled correction note
  explaining the supersession, which is what it should be.

## What pass 2 confirmed, and the orchestrator re-verified independently

- Every roxygen "before" quote matches the current source verbatim at its
  stated line, including 344 and 588, the two that must not change.
- No GitHub issue number appears in any of the four new `@section` blocks.
- The four blocks are 22, 17, 16 and 13 lines, for 68, down from about 85.
- The vignette passage matches the real file: §5 starts at line 613,
  `has_survey` is bound in the setup chunk at line 19, and the heading style
  and table shape match.
- The thirteen-file table is right, and each named file exists or is a `man/`
  page `devtools::document()` regenerates.
- `NEWS.md` names three shipped fixes, and `git log` confirms #238, #239 and
  #240 are the three most recent commits with no entries.
- No existing print snapshot line changes, because `make_rep_design()` passes
  no `fpc`. This is why D-7 needs a new test file and section F exists.
