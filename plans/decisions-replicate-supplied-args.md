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
