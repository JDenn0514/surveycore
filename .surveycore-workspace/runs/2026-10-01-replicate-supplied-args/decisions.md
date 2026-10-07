# Decisions — replicate-supplied-args

## HOLD-1 — What a discarded `rscales` stores (SETTLED 2026-10-06)

**Question:** For JK2, ACS and successive-difference, `as_survey_replicate()`
discards a supplied `rscales` and warns. What does the design store?

**Options:**
- A. Store `NULL`. The design is the same as one built without `rscales`.
- B. Store `rep(1, R)`, as the issue text says.

**Decision:** A, store `NULL` (user, 2026-10-06). This confirms spec
decision D-b.

**Why:** A design does not depend on an argument the constructor discarded.
The variance code already reads `NULL` as `rep(1, R)`, so no standard error
changes. `as_svydesign()` then passes no `rscales` for these types, so
`survey` raises no "not needed" warning on export.

**Effect:** The issue's acceptance line "`rep(1, R)` stored" is superseded.
spec §III discard step 9, register row RS-1, the roxygen facts, and
test-spec rows 5.5 and 5.9 stay as drafted.

## D-g — The two discard type sets live in shared predicates (SETTLED 2026-10-06)

**Question:** spec review finding L1-1. The scale set and the `rscales` set
were written inline in `as_survey_replicate()` and again in
`.as_svydesign_replicate()`. Keep two copies, or share one definition?

**Options:**
- A. Two internal predicates in `R/utils.R`, called by both functions.
- B. Keep the inline lists, as the first draft did. Spec Lens 5 judged this
  correctly sized.

**Decision:** A (orchestrator, 2026-10-06).
`.replicate_ignores_scale(type)` returns
`type %in% c("BRR", "Fay", "JK2", "ACS", "successive-difference")`.
`.replicate_ignores_rscales(type)` returns
`type %in% c("JK2", "ACS", "successive-difference")`. The export route wraps
each call in `isTRUE()`. The constructor's step 9 excludes Fay from the
warning with `!identical(type, "Fay")`.

**Why:**
- `.claude/rules/engineering-preferences.md` ranks DRY first.
- spec §IV's numerical property holds only while the constructor and the
  export route agree on the sets.
- `.is_stratified_jk()` is the precedent for a one-line type-set predicate.
- Each predicate has call sites in two files, so `.claude/rules/code-style.md`
  places it in `R/utils.R`.

**Effect:** spec §II (Files touched, Functions added), §III step 9, §IV and
§XI changed. test-spec gained rows 5.27 and 7.4. The write surface grows by
one file, `R/utils.R`.

## Plan review pass 1 — resolutions (2026-10-07)

Source: `plan-review.md` §Pass 1. Planner applied every Accept row except
where noted. Budgets after resolution: PR 6 criteria 6 → 7; no other figure
moved.

- L3-1 — applied. G item 4 names `checking CRAN incoming feasibility` and the
  `.git` hidden-file note as the only allowed notes.
- L3-2 — applied. PR 6 task 12 joins lines before the grep, on the roxygen
  source and the Rd; PR 6 task 11 (verify) and criterion 3 use it.
- L3-3 — applied. PR 6 task 5 gives eleven required literals, all from
  `spec.md` §III and §V, plus reviewer checklist items R5a, R3 and N1 where
  no literal fits; criteria 3 and 4 check them.
- L5-1 — applied. PR 6 writes `changelog/fix-replicate-supplied-args.md`
  (task 10, criterion 6, Files touched); G item 9 allows `changelog/`.
- L2-1, L3-10 — applied. P-2 says the second call site of
  `.replicate_ignores_rscales()` arrives in PR 4.
- L2-2 — applied. §Order narrows the PR 2 bullet to PR 4's two refusal pins.
- L3-4 — applied. §How to read and PR 5 criterion 3 use a grep over added
  lines of `git diff origin/develop...HEAD -- tests`.
- L3-5 — applied. PR 1 criterion 6 and PR 4 criterion 7 give string checks
  and a removed-lines check; PR 2 criterion 6 gives a diff-scope check for
  criteria 4 to 6.
- L3-6 — applied. PR 4 criterion 7 states a check for each half.
- L3-7 — applied. G item 6 names a `covr::zero_coverage()` command.
- L3-8 — applied. PR 4 task 3 writes the `rscales`-only snapshot text out in
  full; the spec template fixes every word.
- L3-9 — applied in part. F4 now defines `repwt_cols`. The `fay.rho` half is
  a premise error: `survey::svrepdesign()` takes `rho` (`fay.rho` belongs to
  `survey::as.svrepdesign()`); the plan states this under §How to read and P-4.
- L3-11 — applied. PR 1 criteria 1 and 2 give procedures run on the PR
  branch before merge.
- L4-1 — applied. PR 6 task 3 adds one block; attached to criterion 2 with
  row 5.23 (P-3).
- L4-2 — applied. PR 3 tasks 3 and 5 loop over the four warning types.
- L4-3 — applied. PR 1 task 8 adds one block through `survey_replicate()`
  and `as_svydesign()`; attached to criterion 4 with row 7.4 (P-3).
- L4-4 — applied. PR 1 task 10 rewrites the X11 comment; PR 4 task 8 changes
  the code only. Row T11 stays with PR 4.
- L4-5 — applied by naming the existing block "as_svydesign() reproduces a
  replicate nonprob's mean and SE [numerical]" in PR 1 task 9 and criterion 4.
- L4-6 — NOT applied; raised to the coordinator. `spec.md` §X line 631 says
  "These eleven existing blocks fail or warn after the change". Eleven is
  correct: the tables list X1 to X10 and X11, and X12 is introduced
  separately at line 660 as "One more block stays green with no edit to its
  code". Changing "eleven" to "twelve" would make the sentence false, because
  X12 neither fails nor warns. Both copies (`spec.md` in this run directory
  and `plans/spec-replicate-supplied-args.md`) are unchanged.
- L5-2 — applied. The three `plans/` files from commit `3957966` and
  `plans/implementation-plan-replicate-supplied-args.md` ship with PR 1 and
  are in its Files touched; G item 9 allows `plans/` and `changelog/` and
  keeps `.surveycore-workspace/` forbidden.
- L5-3 — declined, per the review: `spec.md` §I excludes vignettes.

## Plan review pass 2 — resolutions (2026-10-07)

Source: `plan-review.md` §Pass 2. All rows applied. No budget figure moved.

- N-1 — applied. PR 6 task 11 joins lines with `tr '\r\n' '  '` in both
  `rd_text` and `roxy_text` (the checkout is CRLF under `core.autocrlf=true`),
  and runs the absence check once against the `develop` Rd, where it must
  count 1. PR 6 criterion 3 and task 12 name the same join.
- N-2 — applied. Every count uses `grep -ci`. No required literal holds a
  regex metacharacter, so none needed escaping; the task says so.
- N-3 — applied. The documentation check is now PR 6 task 11 and Verify is
  task 12; task 5 and criteria 3 and 4 point at task 11.
- N-4 — applied. PR 4 task 2 gives the two-argument warning as a fenced
  three-line block copied from the JK2 render in `spec.md` §III.
- A-1 — applied. §How to read and PR 5 criterion 3 drop added comment lines
  with `grep -vE '^\+\s*#'` before the count.
- A-2 — applied. G item 6 says "every line this PR adds" and notes that
  `covr` is line-based.
- A-3 — applied. PR 2 criterion 6 fixes the removed `expect_` line count at
  4: three from the deleted X4 block, and `expect_equal(stored("JKn"), 1)`
  in the X6 block, re-added with `rscales = rep(1, 20)`. Derived from the
  nine blocks on `develop`; PR 2 task 4 now writes the X6 line out.
- A-4 — applied. PR 1 task 8 records the `survey` 4.5 measurement (BRR
  fallback, one `does not use 'scale='` warning, `sv$scale` 0.2), asserts
  those, and drops the claim that the stored scale passes through. The block
  title is now "as_svydesign() converts a replicate design that stores no
  type"; PR 1 criterion 4 uses it.
