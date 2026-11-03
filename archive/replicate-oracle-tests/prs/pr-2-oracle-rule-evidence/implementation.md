# implementation.md — PR 2, `docs/oracle-rule-evidence`

## Base

| Item | Value |
|---|---|
| sha at dispatch, before any reset | `d4d1db2fe2de42243213d30c5bb56639906494b4` |
| required base sha | `70bfe5495c1362284d13d3a56ec07c12e6ea1eff` |
| action taken | `git reset --hard` to the required sha, then `git checkout -b docs/oracle-rule-evidence` |
| worktree | `C:\Users\jdennen\surveycore\.claude\worktrees\agent-af4d8ea3234bb7884` |

The worktree came up on `main` at `d4d1db2`, as the dispatch predicted. It
also carried one modified tracked file, `.claude/settings.local.json`, which
held local permission and hook edits from another session. The reset
discarded that change. A copy went to the session scratchpad before the
reset. No `plans/` file was staged, edited or reverted.

## Write surface

| File | Action |
|---|---|
| `.claude/rules/testing-surveycore.md` | modified — one insertion |

`git diff --name-only 70bfe54` lists that one path and nothing else.
`tests/testthat/test-conversion.R` shows no change.
`tests/testthat/test-variance-replicate.R` shows no change.

## Summary

- Appended part 2 of the oracle rule to
  `.claude/rules/testing-surveycore.md`, directly after the paragraph PR 1
  ended on and before §S7 error testing layers.
- Added the nine-row per-type table from `spec.md` §III.3, byte-identical to
  the spec, under a lead-in sentence that records the measured versions:
  `survey` 4.5 under R 4.6.1. This resolves the core's forward reference to
  "the per-type table below".
- Added the two paragraphs from `spec.md` §III.2 that make the table
  falsifiable over time: "**The per-type table is a snapshot.**" and
  "**Read a failure against the `survey` version first.**"
- Added the `### What the rule covers` subsection, including the round-trip
  carve-out that names both `tests/testthat/test-conversion.R` blocks by
  title and says both stay, and the sentence that excludes
  `as_survey_nonprob()`. This resolves the core's forward reference in rule 2
  to "the scope paragraph at the end".
- Probed the installed `survey` for all nine replicate types and compared
  every row against `spec.md` §III.3. All nine rows agree. No cell was
  edited.

The `**Version:** 1.2` header stays at 1.2, per the dispatch: the leader has
scheduled one bump to 1.3 at PR 9. The `### Sanctioned exceptions` subsection
is PR 9's content and was not written.

## Task 1 — the probe

Script: `probe-survey-types.R`, written to the session scratchpad outside the
package, run with a single `Rscript` call. Nothing was written into the
repository and no gate was run.

Fixture: `n = 200`, `R = 20` replicate weight columns, lognormal base
weights, `combined.weights = TRUE`, `mse = TRUE`. Each type was built three
times — bare, with `scale = 0.123456`, with `rscales = rep(0.456789, 20)`.
The probe read back `des$scale` and `des$rscales[1]` and captured every
condition through `withCallingHandlers()` plus `tryCatch()`.

Versions measured: **`survey` 4.5**, **R 4.6.1** — the versions `spec.md`
§III.3 records, so agreement was expected.

### What each row needed to build at all

Two rows cannot be measured the way the other seven are.

- **Fay** refuses to build without a `rho`. Bare, it aborts. The probe
  supplied `rho = 0.3` to all three Fay variants. The default scale therefore
  reads as a function of the supplied `rho`, not as a bare constant:
  `1/(R * (1 - rho)^2)` = `1/(20 * 0.49)` = 0.1020408 at `R = 20`,
  `rho = 0.3`. The measured number confirms the spec's formula but is
  specific to the `rho` the probe chose.
- **JKn** refuses with combined weights and no `rscales`:
  `Error: Must provide rscales for combined JKn weights`. Bare and
  scale-only both abort, so neither can report a stored scale. To read the
  JKn default scale the probe supplied `rscales` alone, which gives
  `scale = 1`. To read whether JKn honours a supplied `scale` the probe
  supplied `scale` **and** `rscales` together, because that is the only
  shape that builds. The table's JKn `rscales` cell reads "required,
  honoured" for this reason, and it is the only cell in the table whose
  first word is about buildability rather than about what `survey` does with
  the value.

### Raw probe result, nine rows

Stored values at `R = 20`. "supplied" means the probe passed
`scale = 0.123456` or `rscales = rep(0.456789, 20)`.

| Type | Stored scale, bare | Stored scale when `scale` supplied | Warning on supplied `scale` | Stored `rscales[1]` when `rscales` supplied | Warning on supplied `rscales` |
|---|---|---|---|---|---|
| BRR | 0.05 | 0.05 | `type='BRR' does not use 'scale=' argument` | 0.456789 | none |
| Fay | 0.1020408 | 0.1020408 | none | 0.456789 | none |
| JK1 | 0.95 | 0.123456 | none | 0.456789 | `scale (n-1)/n not provided: guessing n=number of replicates` |
| JK2 | 1 | 1 | `with type JK2 scale= and rscales= are not needed and will be ignored` | 1 | same JK2 message |
| JKn | error; 1 with `rscales` supplied | 0.123456 (with `rscales` also supplied) | none | 0.456789 | none |
| bootstrap | 0.05263158 | 0.123456 | none | 0.456789 | none |
| ACS | 0.2 | 0.2 | `with type ACS scale= and rscales= are not needed and will be ignored` | 1 | same ACS message |
| successive-difference | 0.2 | 0.2 | `with type successive-difference scale= and rscales= are not needed and will be ignored` | 1 | same successive-difference message |
| other | 1 | 0.123456 | `scale or rscales not specified, set to 1` | 0.456789 | same `other` message |

Reference constants at `R = 20`: `1/R` = 0.05, `(R-1)/R` = 0.95,
`1/(R-1)` = 0.05263158, `4/R` = 0.2, `1/(R * (1 - rho)^2)` at `rho = 0.3` =
0.1020408.

## Task 2 — probe versus `spec.md` §III.3, row by row

The spec's table on the left, the probe's reading on the right. **All nine
rows agree.** No disagreement, so no cell was edited and no HOLD was raised.

| Type | Spec: default scale | Probe | Spec: supplied `scale` | Probe | Spec: supplied `rscales` | Probe | Verdict |
|---|---|---|---|---|---|---|---|
| BRR | `1/R` | 0.05 = 1/20 | warn, discard | discarded, warned | honoured | 0.456789 stored | agree |
| Fay | `1/(R * (1 - rho)^2)` | 0.1020408 at `rho = 0.3` | discard, no warning | discarded, silent | honoured | 0.456789 stored | agree |
| JK1 | `(R-1)/R`, guessed | 0.95, with the "guessing" warning | honoured | 0.123456 stored | honoured | 0.456789 stored | agree |
| JK2 | `1` | 1 | warn, discard | discarded, warned | warn, discard | discarded, warned | agree |
| JKn | `1` | 1 | honoured | 0.123456 stored | required, honoured | aborts without it; 0.456789 stored with it | agree |
| bootstrap | `1/(R-1)` | 0.05263158 | honoured | 0.123456 stored | honoured | 0.456789 stored | agree |
| ACS | `4/R` | 0.2 | warn, discard | discarded, warned | warn, discard | discarded, warned | agree |
| successive-difference | `4/R` | 0.2 | warn, discard | discarded, warned | warn, discard | discarded, warned | agree |
| other | `1` | 1 | honoured | 0.123456 stored | honoured | 0.456789 stored | agree |

The delivered table is byte-identical to `spec.md` §III.3, header row
included, verified by `diff` of the eleven lines against the spec's.

### Two probe observations the table does not carry

Neither contradicts a cell. Both are about when `survey` warns, not about
what it does with a supplied value, so neither belongs in the table's three
columns. Recorded here because a block author reading only the table could
be surprised.

1. **JK2 and `other` warn even when nothing is supplied.** Bare JK2 raises
   `with type JK2 scale= and rscales= are not needed and will be ignored`,
   and bare `other` raises `scale or rscales not specified, set to 1`. The
   table's "warn, discard" for JK2 is still right — the warning does fire on
   a supplied value — but the warning is not evidence that something was
   supplied.
2. **`other` warns and honours at the same time.** With `scale = 0.123456`
   supplied, `other` stores 0.123456 and still raises
   `scale or rscales not specified, set to 1`. The message is false on that
   path. The stored value is what the table records, and it is honoured.

## Task checklist

- [x] 1. Probe the installed `survey` for all nine types, bare and with each
  of `scale` and `rscales`, reading back the stored scale and every
  condition. Fay needed `rho = 0.3`; JKn needed `rscales` to build at all,
  and needed `scale` and `rscales` together to show that it honours `scale`.
  Both recorded above.
- [x] 2. Compare the nine probe rows against `spec.md` §III.3. All nine
  agree. Nothing to stop and report; no cell edited.
- [x] 3. Append the §III.3 table with the sentence recording the measured
  `survey` and R versions.
- [x] 4. Write the snapshot paragraph and the "check the `survey` version
  before reading a red block as a surveycore regression" paragraph.
- [x] 5. Write the `### What the rule covers` subsection: the round-trip
  carve-out naming both `test-conversion.R` blocks and saying both stay, and
  the `as_survey_nonprob()` exclusion.
- [x] 6. Confirm both block titles exist in
  `tests/testthat/test-conversion.R` and that the file shows no change.
  Both matched the spec's text exactly, at lines 239 and 567.
- [x] 7. `air format --check` on the file, and `git diff --name-only` against
  the base sha showing one entry. Both clean.
- [x] 8. No full suite, no `devtools::check()`, no `document()`, no
  `run_examples()`, no `pkgdown`, no `covr`. The probe ran as one short
  `Rscript` call from the session scratchpad.

## Task 6 — the two block titles

| Spec text | File | Line | Match |
|---|---|---|---|
| `as_svydesign(survey_replicate) gives svymean matching survey::svrepdesign [numerical]` | `tests/testthat/test-conversion.R` | 239 | exact |
| `from_svydesign() + as_svydesign() replicate round-trip agrees [numerical]` | `tests/testthat/test-conversion.R` | 567 | exact |

The rule's text wraps the first title across two lines, because it exceeds
80 columns. The wrap is the file's line wrapping; the title's characters are
unchanged, and a `grep` for either half finds the block.

## Task 7 — checks

| Check | Result |
|---|---|
| `air format --check .claude/rules/testing-surveycore.md` | exit 0, no output |
| `git diff --name-only 70bfe54` | one entry, `.claude/rules/testing-surveycore.md` |
| lines over 80 columns among the added lines | none |
| lines over 80 columns in the file | 7, all pre-existing (the Quick Reference rows at 11–16 and the two-speeds table at 33–34) |

## HOLDs

None. The spec fixed every sentence this PR ships, the probe agreed with
every row of the table, and both named block titles matched the file.

## Notes for tester

- The section's placement is between the paragraph PR 1 ended on ("A later PR
  that moves surveycore's replicate path...") and `## S7 error testing
  layers`. Both forward references in PR 1's core now resolve: rule 2's "the
  scope paragraph at the end" points at `### What the rule covers`, and "the
  per-type table below" in the scope paragraph points at the table.
- The table carries no heading of its own. `spec.md` §III.2 gives it none
  inside the block quote and says "Adjust nothing but formatting", so it sits
  under a lead-in sentence rather than a `###` header. The only `###` in this
  PR's insertion is `What the rule covers`, which the spec does give as a
  heading.
- `tests/testthat/test-variance-replicate.R` still breaks the rule the file
  now states: the JK1 block passes `scale`, and the JK1 and JK2 blocks wrap
  their `survey` call in `suppressWarnings()`. The dispatch assigns both to
  PR 4. The file is outside this write surface and was not touched.
- Re-running the probe needs no fixture from the package. The script builds
  its own data frame.
