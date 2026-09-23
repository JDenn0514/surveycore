# Spec review — replicate-oracle-tests

**Pass**: 1 of a maximum 3 (full panel, six lenses)
**Date**: 2026-09-16
**Verdict**: FAIL — 2 BLOCKING, 11 REQUIRED, 12 ADVISORY. Route to Stage 3r.

Two findings need the user. Everything else resolves as a batch.

| Lens | Outcome |
|---|---|
| 1 — DRY | 3 ADVISORY |
| 2 — Test completeness | 1 REQUIRED, 3 ADVISORY |
| 3 — Contract completeness | 3 REQUIRED, 3 ADVISORY |
| 4 — Edge cases | 1 BLOCKING, 2 REQUIRED, 2 ADVISORY |
| 5 — Engineering level | 4 REQUIRED, 2 ADVISORY |
| 6 — API coherence | 1 BLOCKING, 3 REQUIRED, 2 ADVISORY |

Lens 2 confirmed no coverage is lost: 24 blocks today, 28 after, nothing in the
"unchanged" set dropped. Lens 3 re-checked every message fragment and every row
of the per-type table against the installed `survey` 4.5 source and found no
defect. Lens 4 closed the fixture-collapse question: the gap is about `1/(2R)`,
so `R` would need to reach about 5e7 before it fell under the SE tolerance.

---

## BLOCKING

### B1 — an `expect_failure()` wrapper passes for any failure, not the right one

Lens 4, with lens 2 converging independently.

`expect_failure()` passes on exactly one failure and zero successes. It does not
care WHY the assertion failed. Quality gate 8 checks only the shape: one wrapper,
one assertion, a comment naming #253.

So a builder who compares the wrong pair of values, or misnames a column,
produces a failing assertion, a passing wrapper and a green suite. Nothing ties
the wrapped failure to the known scale defect. Lens 2 reached the same place from
the other side: the blocks pin "disagrees with `survey`", not "is wrong by the
documented amount", so a DIFFERENT regression landing before PR 3 also ships
green.

**Fix**: each pinned block carries one unwrapped assertion checking the ratio
`sc_se / sv_se` against the literal `sqrt((R - 1) / R)`. It passes today, it
makes the wrapped failure attributable, and it turns red the moment PR 3 changes
the default. Add it to the comment instruction, so PR 3 removes four lines rather
than three.

### B2 — the rule, read literally, condemns the correct conversion tests

Lens 6.

`as_svydesign()` passes surveycore's stored scale into `svrepdesign()` by design.
`tests/testthat/test-conversion.R:239` and `:640` build oracle-shaped comparisons
on that path. They are correct: they test the conversion function's fidelity, not
an independent variance derivation.

Rule 2 of the shipped text says "Pass `scale` to neither side", and the only
stated exclusion is `as_survey_nonprob()`. The spec cites the conversion path
twice in its own out-of-scope table, so it knows the conflict exists. The rule
does not. The rule outlives the spec, and a maintainer enforcing it has grounds
to break working tests.

**Fix**: carve the conversion tests out in the rule text itself. The rule governs
tests that prove surveycore's variance correct by independent comparison. It does
not govern round-trip tests that prove `as_svydesign()` carries the design's own
scale across.

---

## Needs the user

### U1 — keep or drop the stored-scale assertion

Lens 5, REQUIRED, JUDGMENT CALL. Raised against the spec's own design.

§IV.3 item 5 makes every numerical block assert `survey`'s stored scale against a
literal. Lens 5 argues it answers a different question from the one issue #256
asks — it detects a change in `survey`'s defaults, not a wrong surveycore
default — lands in all eight numerical blocks, and duplicates facts the new rule
table already holds, so one fact must stay correct in two places.

Lens 5 recommends dropping it. Lens 6 built finding A7 on the assumption it
exists. The spec author added it deliberately and flagged it in the errata.

Put to the user. See §Questions.

### U2 — `test_invariants()`: add the call, or defer it explicitly

Lenses 2, 3 and 5, all REQUIRED, all independently.

`.claude/rules/testing-surveycore.md` requires one `test_invariants()` call per
constructor per FILE. `test-variance-replicate.R` exercises
`as_survey_replicate()` throughout and calls the helper zero times. That is a
standing violation of a rule the spec quotes.

§IV.4 says adding one call "is permitted". That is a ceiling with no floor. No
quality gate checks it. Two builders will read it two ways, and the file may ship
still at zero with nothing catching it.

Put to the user. See §Questions.

---

## REQUIRED — batch, unambiguous

- **R1** (lens 4) The three blocks matching a specific message do not guard
  against a SECOND, unintended warning firing alongside the expected one. The six
  silent blocks are guarded; these are not. Assert the warning count.
- **R2 / R4** (lenses 4, 6) The message fragments and the refusal table are a
  snapshot of `survey` 4.5. Nothing tells a future author to re-read what
  `survey` does on their installed version before writing a block, and nothing
  tells a maintainer to check the `survey` version before assuming a surveycore
  regression. One sentence each, in the shipped rule.
- **R3** (lens 6) The rule over-claims. Its Quick Reference row and heading are
  general; rules 2 and 3 and the per-type table are `svrepdesign()`-specific. An
  author writing a Taylor-design oracle is bound by the wording and finds
  mechanics keyed to arguments their design lacks. State the split.
- **R5** (lens 6) Block titles are left to the builder, and the file's convention
  is "X matches Y". Three blocks do not match: JKn and bootstrap disagree, Fay
  compares nothing. Constrain those three titles to name the disagreement or the
  refusal.
- **R7** (lens 5) The shipped rule never mentions the two exceptions this PR
  creates — the wrapped pinned blocks and the Fay block that compares nothing. A
  maintainer reading the rule file cannot tell sanctioned exceptions from
  violations. Name them and the issues that close them.
- **R8** (lens 5) The stored-scale assertion has no tolerance row, while the spec
  says "do not invent a tolerance". Moot if U1 drops it; otherwise name the row.
- **R10** (lens 3) §V.1 cites §IV.2 for the no-warning assertion. §IV.2 is the
  argument table; the assertion is defined in §IV.3. One-word fix.
- **R11** (lens 3) The spec reconciles message-matching against
  `code-style.md` but not against `testing-standards.md`, whose Assertions row
  requires `class=` on every `expect_warning()`. That is the rule that actually
  governs the shape a builder writes. Name it the same way.

## ADVISORY — batch

- **A1** (lens 1) §IV restates §III.2's five rules with no pointer. §III ships
  into the rules file and later PRs will edit it; §IV dies with this spec. Add a
  governing-document line.
- **A2** (lens 1, lens 5 converging) The spec never says whether to extract a
  shared "build both sides" helper or write it inline. The builder faces DRY-first
  in one rules file and flat blocks in another. The file's 24 existing blocks
  already answered it inline. Say so.
- **A4** (lens 4) §IV.4's rule that the `survey` skip guard sits inside each
  block has no quality gate. It is grep-checkable. Add it.
- **A5** (lens 4) §VII lists two cases as "cannot arise". Zero-weight columns,
  all-NA columns and single-PSU fixtures also cannot arise, because the generator
  and the fixed fixture forbid them. Say so rather than leaving a reader to
  re-derive it.
- **A6** (lens 6) The Fay block asserts that ANOTHER package refuses. The
  required comment names #243 and PR 4 but never says what kind of test it is. A
  failure there most likely means `survey` changed its message, not that
  surveycore regressed. Add that clause.
- **A7** (lens 6) The same formula `(R - 1) / R` is forbidden as a constructor
  argument and required as an assertion literal. The spec resolves this for JK1 in
  prose; the shipped rule never states the general principle. Generalise it once.
- **A8** (lens 5, lens 3 converging) §VII and §IX both say "the six blocks where
  `survey` is silent". The leader verified the count off the spec's own
  write-surface table: 4 BRR + 2 ACS + 2 successive-difference + JKn + bootstrap
  = **10**. Six counted silent TYPES, and one of those six, Fay, has no numerical
  block. Both the noun and the number are wrong.
- **A9** (lens 2) §V.1 spells out both additions for BRR. §V.6 and §V.7 do not,
  for no stated reason. Make them consistent.
- **A10** (lens 2) `test-spec.md` gives the tester a checkable total of 28
  blocks. `spec.md` §VIII never states it, so the builder's checklist cannot catch
  a dropped or extra block. Add it.
- **A11** (lens 3) The file uses `# Block N:` section headers. The spec never
  says where the four new blocks land. Two builders produce two layouts.
- **A12** (lens 3) The new blocks never name the outcome variable or the
  estimator function. Every existing block uses `y1`. State `y1` and
  `get_means()`.

## Not accepted

- **Lens 1, one constraint stated four times.** It appears in a rule, a contract,
  a worked example and a checklist. Each serves a different reader at a different
  moment. That is the repetition the house test style accepts. Leave it.
- **Lens 5, a shared assertion helper.** Lens 1 and lens 5 both recommend staying
  inline. A helper that builds both sides invites the round-trip this PR removes.
  A2 records the choice; no helper.

---

# Pass 2 — delta

**Date**: 2026-09-16
**Scope**: the sections Stage 3r changed. Two agents, per the review-loop budget.
**Verdict**: PASS. All 25 fixes verified. No new issue. No artifact change needed,
which is the early exit.

## Agent A — the shipped rule and the common contract

All RESOLVED: B1, B2, U1, U2, R1, R2/R4, R3, R7, R11, A1, A2, A7.

- The ratio assertion sits outside every wrapper, names the tolerance row without
  a number, and the comment now says PR 3 deletes four lines.
- The conversion carve-out sits inside the shipped blockquote and names both
  tests by title, not by line. Both titles verified present at
  `tests/testthat/test-conversion.R:239` and `:567`. The original finding cited
  `:640`, which is a comment header — the corrected location holds.
- §IV.4 reads as a requirement and names the block. That block is
  `test-variance-replicate.R:12`, genuinely the file's first.
- Read standalone, the blockquote holds together. The five inserted paragraphs
  use the bold-lead pattern the pre-existing constraints already use, so they do
  not read as patches.

## Agent B — the blocks, the gates, the errata, and the cross-document check

All RESOLVED: A8, R5, B1, A9, A10, A11, A12, A5, A6, A4, U2, R10.

- Both "six" sites now read ten and say blocks. The two surviving "six" hits in
  each document are unrelated and correct.
- The three generator facts behind the new "cannot arise" rows were checked
  against `tests/testthat/helper-test-data.R` and hold: weights are a positive
  ratio times a lognormal factor, `y1` is drawn from a normal with no NA
  injection, and every `n_psu` in the file is 10 or 20 across 23 occurrences.

**Cross-document check — the one that matters.** Every gate in `spec.md` §VIII,
1 to 18, has a matching check in `test-spec.md`, stated in full. The reverse
holds too: nothing in `test-spec.md` would block a build compliant with
`spec.md`. The two documents agree on the block count (28), the silent and
warning split (10 and 3), the comment counts (13, 2, 1) and the tolerance row.

**Two-artifact rule holds.** No numeric tolerance value appears in `spec.md`. No
cross-reference in either direction. The single `R/` mention in `test-spec.md`
is a directory, not a path.

## Stage 3 verdict

**PASS.** Advance to SPEC_READY.
