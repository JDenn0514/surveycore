# Spec review — replicate-supplied-args

## Spec Review: replicate-supplied-args — Pass 1 (2026-10-06)

Six lenses, applied in order. Ten findings: 6 REQUIRED, 4 SUGGESTION, 0
BLOCKING. The orchestrator decided every finding. Resolution ran in SMALL mode
on 2026-10-06. Both artifacts are now at revision 2.

### New Issues

#### REQUIRED

**L1-1: The two discard type sets are written twice**
Severity: REQUIRED
Lens: 1 (DRY)
Section: spec §II Functions added, §III step 9, §IV
Violates `.claude/rules/engineering-preferences.md` §1.

The draft wrote the scale set and the `rscales` set inline in
`as_survey_replicate()` step 9 and again in `.as_svydesign_replicate()`. The
numerical property in §IV holds only while the two copies agree.

**Resolution: applied.** Two internal predicates go in `R/utils.R`:
`.replicate_ignores_scale()` (`"BRR"`, `"Fay"`, `"JK2"`, `"ACS"`,
`"successive-difference"`) and `.replicate_ignores_rscales()` (`"JK2"`,
`"ACS"`, `"successive-difference"`). Both functions call them. The export
route wraps each call in `isTRUE()` so a `NULL` stored type gives `FALSE`.
Step 9 excludes Fay from the warning with `!identical(type, "Fay")`, because
step 8 has already set a Fay `scale`. spec §II Functions added (was "None"),
§II Files touched, §III step 9, §IV and decision D-g changed. test-spec §1
gained the shared-set rule, row 5.27 pins all nine types against both sets
through the public API, and row 7.4 pins BRR on the export side. No direct
test of the predicates: the public API reaches every branch.

---

**L2-1: §X names one stale-comment block but counts two**
Severity: REQUIRED
Lens: 2 (Test completeness)
Section: spec §X; test-spec §8

spec §X said "Two blocks stay green with no edit but carry stale comments" and
named only the FPC block. The second occurrence sits inside X11, which is
already edited. test-spec §8 did not list the FPC block at all, so the two
closed lists disagreed.

**Resolution: applied.** spec §X now lists one comment-only block as X12
(`as_svydesign() warns and converts for every replicate type carrying an
FPC`), says the ACS comment is part of X11, and closes the list as "X1 to
X12". test-spec §8 gained T12 for the same block, T11 names its comment
change, and the closing sentence reads "No existing block other than T1 to
T12 changes".

---

**L2-2: Row 5.24 has a numeric check with no tolerance**
Severity: REQUIRED
Lens: 2 (Test completeness)
Section: test-spec §5 row 5.24, §11

The JKn stored-scale check in row 5.24 named no tolerance, so §11's claim that
every numeric `expect_equal()` names one was false.

**Resolution: applied.** Row 5.24 now gives `tolerance = 1e-8` for the JKn
check. A search of the whole test-spec found no other numeric check without a
tolerance. The two new rows, 5.27 and 5.28, name theirs.

---

**L4-1: Edge values of a discarded `scale` are unstated**
Severity: REQUIRED
Lens: 4 (Edge cases)
Section: spec §III Edge cases

The draft covered a non-numeric discarded `scale` (`"a"`) but not `NA_real_`,
`Inf`, a negative number, `0`, or a length-`R` vector.

**Resolution: applied.** spec §III Edge cases gained one row: each of those
values counts as supplied, is discarded with the warning for BRR, JK2, ACS and
successive-difference and silently for Fay, and is never checked. test-spec §1
states the rule, and row 5.28 loops over the five values for BRR (warns,
stores `1 / 20`) and Fay (no condition, stores the Fay value), each at
`tolerance = 1e-8`.

---

**L4-2: Stale `scale` or `rscales` after `update_design()`**
Severity: REQUIRED
Lens: 4 (Edge cases)
Section: spec §I Out, §VIII

`update_design()` with changed replicate columns can leave a stored `scale` or
`rscales` that no longer fits. The draft did not say whether this work covers
it.

**Resolution: applied as an out-of-scope record.** The defect is older than
this work and belongs to issue #300. spec §I Out and §VIII each gained an
entry. test-spec §1 gained a one-line out-of-scope note so the tester does not
test it.

---

**L6-1: The JKn NEWS entry gives no migration step**
Severity: REQUIRED
Lens: 6 (API coherence)
Section: spec §IX entry 2; test-spec §9 row 9.4

The JKn refusal is a breaking change. Its error carries a "v" bullet with the
fix, but the NEWS entry told the caller only that the call now fails.

**Resolution: applied.** spec §IX entry 2 now tells the caller to pass
`rscales` with one entry per replicate column, for example
`(n_h - 1) / n_h`, matching the error's "v" bullet. test-spec row 9.4 checks
that the entry carries that action clause and names `rscales`.

---

#### SUGGESTION

**L3-1: The register note heading is paraphrased**
Severity: SUGGESTION
Lens: 3 (Contract completeness)
Section: spec §VI

The draft said to add an "Updated trigger descriptions" note. The heading
`plans/error-messages.md` uses three times is
`**Updated trigger descriptions for existing rows:**`.

**Resolution: accepted and applied.** spec §VI quotes the exact heading.

---

**L3-2: RS-1 fragment wording**
Severity: SUGGESTION
Lens: 3 (Contract completeness)
Section: spec §VI row RS-1

The finding proposed rewording the RS-1 condition text.

**Resolution: declined.** The row states the trigger, the stored values and
the D8 exception in full. A rewording adds no fact.

---

**L4-3: No JK2 `from_svydesign()` round-trip row**
Severity: SUGGESTION
Lens: 4 (Edge cases)
Section: spec §IV Edge cases

The finding proposed an import-then-export row for JK2, parallel to the ACS
and successive-difference row.

**Resolution: declined.** The export route keys on the stored type only, so a
JK2 import takes the same branch as a JK2 design built by the constructor.
`survey` warns on every JK2 export, so the row could not tell a passed value
from a withheld one.

---

**L6-2: Placement of the `as_survey_nonprob()` sentence**
Severity: SUGGESTION
Lens: 6 (API coherence)
Section: spec §V

The finding proposed moving the JK2 divergence sentence onto the
`as_survey_replicate()` help page.

**Resolution: declined.** The two help pages cross-link through `@seealso`,
and the sentence explains why `as_survey_nonprob()` keeps its refusal, so it
belongs on that page.

---

### Lens 5 (Engineering level)

No finding. The lens judged "no new helpers" correctly sized for the draft.
L1-1 overrules that judgement, because `engineering-preferences.md` ranks DRY
first.

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 10. Applied: 7 (6 REQUIRED, 1 SUGGESTION). Declined: 3
SUGGESTION.

**Overall assessment:** The spec was implementable before the review. The six
REQUIRED fixes close a duplicated type list, two mismatched closed lists, one
missing tolerance, two unstated edge cases and a NEWS entry with no migration
step.

## Spec Review: replicate-supplied-args — Pass 2 (2026-10-06)

Delta pass, two reviewers, changed sections only (spec.md revision 2,
test-spec.md revision 2).

- spec.md: L1-1, L2-1, L3-1, L4-1, L4-2 and L6-1 resolved. Step 9 logic and
  the `isTRUE()` guard for a `NULL` stored type checked. No new issue.
- test-spec.md: L2-1, L2-2, L4-1 and L6-1 resolved. Row 5.27's nine-type
  table checked against the default formulas. Row 7.4 checked against
  `R/methods-conversion.R` and survey 4.5 source. T11 and T12 titles exist
  verbatim. No reference to spec.md, no internal helper named. No new issue.

**Verdict: PASS** (early exit: pass 2 required no change to either artifact)
