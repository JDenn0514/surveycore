# Plan Review: replicate-fay-rho — Pass 1 (2026-09-30)

Five lens agents (sonnet), in parallel, on `implementation-plan.md` (9 PRs,
81 test-spec rows). No lens found a BLOCKING finding. Lenses 1 (PR budget)
and 5 (file completeness) returned PASS with nothing to change.

Each issue carries its resolution. "Orchestrator" means settled in this
session without the user.

**Verdict: FAIL** (4 REQUIRED-UNAMBIGUOUS findings, all applied in pass 1).

### Applied

**Issue 1: The nine-type default block needs a changed helper** (Lens 2,
REQUIRED-UNAMBIGUOUS)
PR 1 task 4 puts `rho = 0.3` on the Fay line, but the block's local helper
`stored(ty)` takes no `rho`. Resolution (orchestrator): the task now says
`stored()` gains `rho = NULL`, and the Fay line calls
`stored("Fay", rho = 0.3)`.

**Issue 2: The FR-2 `rho_txt` binding is never verified** (Lens 4,
REQUIRED-UNAMBIGUOUS)
Spec §III fixes two binding rules: the length-0 string, and truncation to
five values. No PR snapshots either. Resolution (orchestrator): PR 2 task 4
adds snapshots for `numeric(0)` and for a six-value `rho`; PR 2 criterion 4
states both. The PR's figures do not change (same task, same criterion, same
rows 1.8 and 1.9).

**Issue 3: PR 3 criterion 5 does not name its error classes** (Lens 3,
REQUIRED-UNAMBIGUOUS)
Resolution (orchestrator): the criterion now names
`surveycore_error_empty_data`, `surveycore_error_single_row` and
`surveycore_error_rscales_length`.

**Issue 4: The plan does not say why PR 9 follows PRs 6 and 7** (Lens 2,
minor)
Resolution (orchestrator): the order section now states that PR 9's
`NEWS.md` text is false before PR 6 and its rule edit is false before PR 7.

### Declined

**Issue 5: Six criteria map to no numbered test-spec row** (Lens 3, minor)
PR 1 criterion 7, PR 5 criteria 5 (second clause), 6 and 7, PR 8 criteria 5
(second clause) and 6, and PR 9 criterion 6. They check the test-spec's
unnumbered "Existing blocks that change" prose, the `plans/error-messages.md`
register, or spec quality gates 7 and 8. Each is observable and closed.
Resolution (orchestrator): keep them. The register and the quality gates are
spec contract items; the reviewer checks them against `spec.md`. Adding
test-spec rows now would reopen SPEC_READY for no change in behaviour.

**Issue 6: PR 8 depends on PR 1, though spec §I item 9 calls §IX
independent** (Lens 4, informational)
The dependency comes from the refusal test, which must build a Fay phase 1
with `rho`. The plan states it. Resolution (orchestrator): no change; logged
as D-2 in `decisions.md`.

**Issue 7: PR 3 may widen its write surface** (Lens 5, minor)
PR 3 task 7 adds `R/core-constructors.R` only if a test exposes a PR 1
defect, and says so. Resolution (orchestrator): no change.

### Planner findings on the artifacts (not lens findings)

Logged in `decisions.md` as D-1 to D-3: the holding edits PR 1 makes to four
existing blocks, the spec §II quick-reference row that does not exist, and
the one-caller period of `.is_valid_rho()`.

---

# Plan Review: replicate-fay-rho — Pass 2 (2026-09-30)

One delta agent (sonnet) on the four edits of pass 1 only. All four
verified against `spec.md` and the repository; no edit needed.

**Verdict: PASS.**
