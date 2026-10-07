# Plan review: replicate-supplied-args

## Pass 1 (full panel, 5 lenses, 2026-10-07)

Verdict: **FAIL** (4 REQUIRED).

| Lens | REQUIRED | SUGGESTION |
|---|---|---|
| 1 PR budget | 0 | 0 |
| 2 Dependency ordering | 0 | 2 |
| 3 Acceptance criteria | 3 | 8 |
| 4 Spec coverage | 0 | 6 |
| 5 File completeness | 1 | 2 |

Lens 1 recomputed every budget figure. All six PRs match their stated
figures and sit inside the bound (12 rows, 8 criteria). PRs 2, 3 and 4 sit
at 12 rows. PRs 3 and 4 sit at 8 criteria. 59 rows, each assigned once.

### REQUIRED

| ID | Location | Finding | Resolution |
|---|---|---|---|
| L3-1 | G item 4 | "the one pre-approved note" is not named | Accept: name `checking CRAN incoming feasibility` |
| L3-2 | PR 6 AC 3 | A grep for `leaves no jackknife factor` false-passes across a roxygen or Rd line break | Accept: state a check that joins lines, on roxygen source and Rd |
| L3-3 | PR 6 AC 3, AC 4 | Documentation facts are "wording is yours", so no command checks them | Accept: one required literal per fact, or a named reviewer checklist item where no literal fits |
| L5-1 | PR 6 write surface, G item 9 | No PR writes `changelog/fix-replicate-supplied-args.md`; precedent arcs write one entry in the docs-last PR | Accept: one entry, in PR 6; G item 9 allows it |

### SUGGESTION

| ID | Location | Finding | Resolution |
|---|---|---|---|
| L2-1, L3-10 | P-2 | The second call site of `.replicate_ignores_rscales()` arrives in PR 4, not PR 3 | Accept |
| L2-2 | §Order, PR 2 bullet | Only PR 4's pins need the JKn refusal; PR 3's do not | Accept: narrow the sentence; shared files keep the order |
| L3-4 | PR 5 AC 3, preamble rules | "By reading" is not command-checkable | Accept: grep added lines of `git diff origin/develop...HEAD -- tests` |
| L3-5 | PR 1 AC 6, PR 4 AC 7, PR 2 AC 4–6 | Comment-content and "assertions unchanged" criteria have no check | Accept: a string to check plus a diff-scope check |
| L3-6 | PR 4 AC 7 | Two halves have no stated check | Accept |
| L3-7 | G item 6 | No command for "every branch this PR adds is reached" | Accept: name a covr command |
| L3-8 | PR 4 task 3, AC 2 | The `rscales`-only snapshot text is not written out | Accept: write it out from the spec template |
| L3-9 | Fixtures, PR 5 task 2 | `survey` takes `fay.rho`; F4 has no `repwt_cols` | Accept |
| L3-11 | PR 1 AC 1, AC 2 | "Fails on develop" and commit order need a procedure | Accept: procedure on the PR branch before merge |
| L4-1 | PR 6 | No task covers JK2/ACS/successive-difference with `scale`, `rscales` and `rho` together (spec §III edge cases) | Accept: one block in PR 6 |
| L4-2 | PR 3 tasks 3, 5 | Discarded `scale` values run on BRR only | Accept: loop over the four warning types |
| L4-3 | PR 1 task 6 | Predicate contract (NULL stored type gives FALSE on export) is untested | Accept: one block through the public API |
| L4-4 | PR 1 task 9, P-2 | The X11 comment is false on develop from PR 1 to PR 4 | Accept: fix the comment in PR 1, the code in PR 4 |
| L4-5 | PR 1 | No block covers a `survey_nonprob` design on the export route | Accept: name an existing block or add a parity block |
| L4-6 | spec §X | Spec says "eleven existing blocks" and lists twelve | Accept: correct the spec count, log as erratum |
| L5-2 | G item 9, PR 1 | Three `plans/` files from commit 3957966 appear in PR 1's diff | Accept: they ship with PR 1; G item 9 names `plans/` and `changelog/` |
| L5-3 | vignettes | Section 3.4 of `creating-survey-objects.Rmd` does not mention the discard | Decline: spec §I excludes vignettes |

### Pass 1 resolution notes

- L4-6 withdrawn. Spec §X tables list X1–X11; X12 is introduced separately
  as a block that stays green. "Eleven" is correct. No spec edit.
- L3-9 applied in part. `survey::svrepdesign()` takes `rho`; `fay.rho`
  belongs to `survey::as.svrepdesign()`. The F4 `repwt_cols` fix is in.
- PR 6 moved from 7 rows / 6 criteria to 7 rows / 7 criteria (changelog
  criterion). All other figures unchanged.

## Pass 2 (delta, 2 agents, 2026-10-07)

Verdict: **FAIL** (1 REQUIRED). Every pass 1 finding is RESOLVED except
L3-2, which N-1 reopens.

| ID | Location | Finding | Resolution |
|---|---|---|---|
| N-1 (REQUIRED) | PR 6 task 12, `rd_text` | `tr '\n' ' '` leaves `\r` on this CRLF checkout (`core.autocrlf=true`); the absence check false-passes and wrapped required literals false-fail | Accept: `tr '\r\n' '  '` |
| N-2 | PR 6 task 12 | `grep -ciF` aborts in this Git Bash (exit 134) | Accept: use `grep -ci`; no literal has a regex metacharacter |
| N-3 | PR 6 tasks 11, 12 | The Verify task comes before the check it uses | Accept: move task 12 ahead of Verify |
| N-4 | PR 4 task 2 | The "scale and rscales" text is not a full literal block | Accept: fenced block from the spec's JK2 render |
| A-1 | §How to read, PR 5 AC 3 | The added-lines grep counts added comment lines | Accept: filter `^+\s*#` before the count |
| A-2 | G item 6 | `zero_coverage()` is line-based | Accept: say "every line" |
| A-3 | PR 2 AC 6 | The diff-scope check has no count | Accept: give a count to compare |
| A-4 | PR 1 task 8 | "The stored scale passes through" is wrong: `survey` 4.5 falls back to BRR, warns `does not use 'scale='`, and `sv$scale` is 0.2 | Accept: describe the probed behaviour |

## Pass 3 (delta, final, 2026-10-07)

Verdict: **PASS**. N-1 to N-4 and A-1 to A-4 are RESOLVED. The reviewer ran
the checks: the joined-line absence check counts 1 on the develop Rd (the old
join counted 0), the comment filter counts 1 on a synthetic input, PR 2 AC 6's
figure of 4 holds, and PR 4 task 2 matches the spec's JK2 render.

Three suggestions, no plan change needed:

- The plan header still read "awaiting pass 2". Fixed at freeze.
- `grep -ci` on a joined Rd proves presence, not placement. The reviewer
  checklist items cover placement. No change.
- In PR 1 task 8, `sv$scale == 0.2` cannot tell `1/5` from BRR's `1/R`. The
  warning text pins the BRR fallback. No change.

## Final budget

| PR | Branch | Rows | Criteria |
|---|---|---|---|
| 1 | `fix/replicate-export-ignored-args` | 6 | 7 |
| 2 | `fix/replicate-jkn-rscales-required` | 12 | 7 |
| 3 | `fix/replicate-scale-discard` | 12 | 8 |
| 4 | `fix/replicate-rscales-discard` | 12 | 8 |
| 5 | `test/replicate-supplied-scale-oracle` | 10 | 5 |
| 6 | `fix/replicate-rho-class-and-docs` | 7 | 7 |
