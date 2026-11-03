# Adversarial verification — round 1

> **On the `[not archived]` marker in this file.** The Wolter chapter 4
> source it cites is an extracted copy of a copyrighted textbook chapter and
> lives outside this repository. It was deliberately not archived here rather
> than lost by the pipeline: copying it into a public GPL-3 repository would
> not be appropriate. The marker is the closer of the two the citation
> checker accepts. The file was present and read in full when the
> comprehension was written.

Stage 0, `comprehension.md`. Protocol:
`.claude/skills/spec-workflow/references/stage-0-comprehension.md`
§Adversarial Verification. Four agents, one per section, run 2026-09-23.
Each checked its section against Wolter chapter 4, the repo source, and the
decision records. 16 issues.

Each agent's brief was to find claims the source does not support, or that
mischaracterize the source. Style was out of scope.

---

## Formulas (F1-F11) — 6 issues

**FIX-1 (F9, material).** The claim "`scale = 1` plus per-stratum `rscales`
reproduces F3/F4 exactly" names the wrong estimator. F3 and F4 are Jones's
`v_1` (eqs. 4.5.3, 4.6.4a), which centres each replicate on its own stratum
mean `theta_(h.)`. surveycore stores no replicate-to-stratum map, so it
reaches `v_4` (eq. 4.5.6) when `mse = TRUE` and `v_2` (eq. 4.5.4) when
`mse = FALSE`, both centred outside the stratum. Counterexample satisfying
all four of F9's own conditions: `L = 2`, `n_h = 2`, replicate estimates
1, 3, 5, 7, full-sample estimate 4, `rscales = 1/2` each. F3 gives
`1 + 1 = 2`. The surveycore expression with `mse = TRUE` gives
`(1/2)(9 + 1 + 1 + 9) = 10`. Wolter's observation (i) at line 1441 says
`v_4 >= v_1` generically, so this is not an edge case. C4 already concedes
`v_1` is unreachable, so the subsection contradicts itself.

Fix: state that the substitution reproduces `v_4` exactly under `mse = TRUE`
and `v_2` exactly under `mse = FALSE`, and that neither is `v_1`. Keep
Theorem 4.5.3 as the reason the default scale is decidable without settling
`mse`. **The `JKn = 1` conclusion does not change** — `v_4` carries the same
per-stratum `(n_h - 1)/n_h` factor and no overall multiplier.

**FIX-2 (F8, material).** "`(n_h - 1)/n_h` is strictly greater than
`(R - 1)/R` for every `h`" has the inequality backwards. `(n-1)/n = 1 - 1/n`
increases in `n`, and `n_h < R`, so `(n_h - 1)/n_h` is strictly **less**.
Example: `n_h = 2`, `R = 4` gives 0.5 against 0.75. The conclusion — no
overall factor reproduces the per-stratum ones — survives. The stated
direction contradicted both the Problem section and F10, which have the old
default understating the standard error. That reading is the correct one.

**FIX-3 (F3).** The OCR `/2` artifact spans three lines, not two: the `v_1`
display at chapter line 1419, and both lines of the eq. 4.5.7 block, 1426
and 1427. "Ignore those two lines" leaves 1427 standing. The judgement that
`/2` is an artifact is correct, confirmed by eq. 4.5.3 at 1335 and Example
4.5.1 at 1485.

**FIX-4 (F5).** "standard errors differ by at most 0.03 points on 24
domains" is wrong for the figures the sentence is about. Wolter Table 4.7.1:
Black non-Hispanic age 19 reads 3.24 without replicate reweighting and 3.18
with, a gap of 0.06; Hispanic origin age 19 reads 3.51 against 3.56, 0.05.
The 0.03 bound holds for the BHS columns and for the reported means and
medians only.

**FIX-5 (F9, C1).** "Wolter also permits grouping ... in which case `n_h` in
the factor is replaced by the group count [Wolter §4.5]" is an inference the
cited paragraph (chapter line 1492) does not make. That paragraph says only
that valid results follow from deleting the `m_h` observations of the `i`-th
random group. It says nothing about the factor. The grouped variant Wolter
does spell out, eq. 4.5.9 at lines 1578-1591, deletes group `alpha` from
every stratum and uses `1/(k(k-1))`, which is a different construction.
Either drop the clause or re-mark it as the author's inference.

**FIX-6 (F6, minor).** "`survey` is in the same position." carries no
provenance mark, against the document's own convention at lines 8-13. Mark
it or drop it.

## Gotchas (G1-G11) — 7 issues

**FIX-7 (G1, material).** "D4 moves `as_survey_replicate()` to the same
refusal in PR 4 of the arc" states a PR number the plan contradicts itself
about. Resolved by the orchestrator against the dependency argument:
`plans/issue-cleanup.md:511` says #255 "handles every argument, so it ships
once every argument exists", and :530 says "#243 adds the argument as PR 4",
so **#243 is PR 4 and #255 is PR 5**. The summary table at 321-325 and the
headlines at 505 and 541 are stale. Fix: name the issue (#255), not a PR
number. Add one sentence recording that `plans/issue-cleanup.md` is
internally inconsistent on the arc's PR order, so a later reader does not
trust either number. Everything else in G1 verified, including the
post-change state: `rscales = NULL` is stored as `NULL`
(`R/core-constructors.R:827`) and the variance path substitutes
`rep(1L, n_rep)` (`R/variance-replicate.R:92`).

**FIX-8 (G4, material).** "builds `R = n_psu` columns ... identically for
every `type`" is false for two types. `tests/testthat/helper-test-data.R:512-521`
sets `R` per type: `n_psu %/% 2L` for BRR and Fay, `n_psu` for the
jackknives and the bootstrap. What is identical across types is the column
formula at 522-526, not the column count. The conclusion stands: no column
drops a PSU and none is inflated by `n_h/(n_h - 1)`, so an oracle block on
this fixture proves the two implementations put the same numbers into the
same formula, and proves nothing about `v_4`.

**FIX-9 (oracle table row 2, material).** "This is the rule the defect
defeated" is unsupported. `.claude/rules/testing-surveycore.md:181-187`
records rule 2's one casualty as issue #242. Neither block this work touches
passes `scale` to either side (`tests/testthat/test-variance-replicate.R:834-852`,
`910-928`). These two defects survived behind a round-trip test, which rule 2
explicitly does not reach (rule file 186-187). Fix: name the round-trip
mechanism, and drop the rule 2 attribution.

**FIX-10 ("Why no existing test caught either defect", material).**
"surveycore's only JKn numerical test" is false. At least four exist:
`from_svydesign() matches survey on a JKn factor-form source [numerical]`
(`tests/testthat/test-conversion.R:1455`, asserts the SE at 1487 and both
bounds), the JKn oracle block itself
(`tests/testthat/test-variance-replicate.R:806`, which does not touch
`as_svydesign()`), `as_svydesign() reproduces surveycore's mean and SE for
JKn [numerical]` (`test-conversion.R:2616`), and the nine-type loop at
2636-2659. Fix: say which tests exist and why each is silent on the default,
rather than claiming there is one.

**FIX-11 (mechanism 2, material).** The citation
`R/methods-conversion.R:166` is stale in this worktree — those lines are
roxygen prose about a filtered design's domain. The code is
`scale_arg <- if (type %in% c("BRR", "Fay")) NULL else x@variables$scale` at
372-375, passed as `scale = scale_arg` at 494. The behaviour claimed is real
and matches D10. Re-point the citation; PR 5 of the arc edits that site.

**FIX-12 (G9, minor).** `R/utils.R:1181` is a comment line in the function
header, not code. The `switch()` that returns the value is 1184. The claim
is true.

**FIX-13 (sanctioned exceptions, material).** "the two sanctioned
`expect_failure()` exceptions ... and this work removes both" misdescribes
both halves. `.claude/rules/testing-surveycore.md:299-311` names two
exceptions: one bullet covering the JKn and bootstrap `expect_failure()`
wrappers, and "The Fay block compares nothing", which uses no wrapper and
which #243 closes. This work removes one exception of two. Also: the section
states **three** further constraints, not two; the third, "Match `survey`'s
conditions by message text, not by class", was dropped without a reason.

Counts in that file verified by reading real calls, not grep matches: JKn
block 806-884 with wrappers at 865, 868, 871 and a ratio assertion at
879-883; bootstrap block 886-965 with wrappers at 942, 949, 952 and a ratio
assertion at 960-964. Each block's comment says to delete four lines. Both
correct as written.

## Assumptions and open questions — 1 issue

**FIX-14 (Q1 option 3, material).** "`as_survey_nonprob()`'s roxygen already
claims 'at least 2' ... while its validator does not enforce it" is false.
The constructor raises `surveycore_error_repweights_single` — "{.arg
repweights} must name at least 2 replicate weight columns." — at
`R/core-constructors.R:1457-1469`. Tests at
`tests/testthat/test-constructors.R:2107` and `3008-3024`. The class has a
row in `plans/error-messages.md` (NB-3). The cited lines 1232-1234 are the
roxygen text only. Fix: record that surveycore already refuses a
single-replicate design in one constructor, so refusing it in the other
would follow an existing precedent rather than set a new one. This bears on
D-1 in `decisions.md` and was surfaced to the user.

All seven assumptions A1-A7 verified, including A3 against chapter lines
1184-1188, 1637 and 1709, and A5 against
`.claude/rules/testing-surveycore.md:227-237`. Q1's five-part core claim
verified part by part: the constructor accepts one column
(`R/core-constructors.R:763-768`), `.validate_repweights()` imposes no
minimum (`R/core-validators.R:285-328`), no `.validate_scale()` exists
anywhere, and today's `bootstrap = 1 / n_rep` does store `1` at `R = 1`.
Q2 and Q3 are genuinely open.

## Reference mapping — 2 issues

**FIX-15.** Same as FIX-13, in the `testing-surveycore.md` row.

**FIX-16 (minor).** "deparse line numbers 148-149" is not what D2 records.
`plans/issue-cleanup.md:89` gives "107-112, 148" for JKn. The bootstrap
half, "88-95" from D5:124, is exact.

Rows 1-15 and 18-19 all verified, including every `§x.y` number against the
chapter's line ranges.

---

## FIX-17 — added after the fix pass, from an omission in this file

The Formulas agent raised two issues against F8. This file carried only the
first, the reversed inequality (FIX-2). The second was dropped when the
findings were consolidated, which is an error in this document and not in
`comprehension.md`.

The dropped finding: F8 cited §4.5 footnote 1 as marking `L = 1` as the point
where the stratified treatment meets the unstratified one. The footnote does
the opposite. It contrasts the two pseudovalues at `L = 1` —
`(n-1)(1-f)` here against `(n-1)(1-f)^{1/2}` in §4.3 — and says they agree
for a linear estimator and diverge for a nonlinear one. It is a statement
about pseudovalues, about bias removal and about where a finite-population
correction enters. It says nothing about the variance factor F8 derives.

The fix pass raised a second question about the same citation: it could find
no footnote 1 in §4.5 and asked the delta review to check. **Measured.** The
footnote exists at chapter lines 1203-1215, attached to eq. 4.5.2. Its
marker renders as `$^1$`, which is why a search for the word "footnote"
returns nothing in that range. The citation is valid. The Reference mapping
agent, which called footnote 1 the only one in §4.5, was right.

**Applied by the orchestrator**, directly, in F8 and in the matching
Reference mapping row. F8 now says the chapter does not mark `L = 1` as a
meeting point, states the footnote's real content, and keeps its own accurate
sentence that the equality is arithmetic. The mapping row splits in two: one
row for eq. 4.5.3 carrying the arithmetic coincidence, one for the footnote
carrying what it actually says, with a note not to read it as authority on
the factor.

## Two chapter-wide searches worth keeping

Both run over all 2052 lines of `wolter_2007_ch04_jackknife.md` [not archived], and both
confirm a claim the artifact makes:

- `bootstrap`, case-insensitive: **zero hits**. Chapter 4 is silent on the
  bootstrap. No row in Reference mapping leans on it for the `1/R` →
  `1/(R-1)` change, which is sourced to D5 and to
  `survey:::svrepdesign.default` alone. "Yue" also returns zero hits, so
  Rao, Wu and Yue (1992) is absent from the chapter.
- `JK1` and `JKn`, literal: **zero hits**. Those labels are `survey`'s. The
  chapter supports the mathematics and not the naming.

## Verdict on the JKn claim, after verification

CONFIRMED WITH CONDITIONS, unchanged. `JKn = 1` is right. Wolter's factor is
per stratum in every form the chapter gives — eq. 4.5.3, eq. 4.5.6, eq.
4.6.4a, and the worked NLSY97 example at Table 4.7.2 — and no form carries an
overall multiplier. Two of the corrections above touch how the claim is
stated, not whether it holds: the reachable variant is `v_4` and not `v_1`
(FIX-1), and the inequality in F8 runs the other way (FIX-2).

---

# Delta sign-off — round 1 of at most 2

Two agents, scoped to the eleven headings the fix pass reported as changed.
Run 2026-09-23. Verdict: all 17 findings landed. Six mark-level or
citation-level corrections remained; the orchestrator applied all six
directly.

## Formulas — 7 of 7 landed

The agent re-derived FIX-1's counterexample independently and got the same
three numbers: `v_1 = 2`, surveycore with `mse = TRUE` = 10, `v_4` = 10.

It also checked the narrowed verdict sentence against every stratified
variance form in the chapter — eq. 4.5.3, eqs. 4.5.4 to 4.5.6, McCarthy's
`v_M` at chapter line 1364, Lee's `v_L` at 1370, Example 4.5.1, the four
pps-wr forms at 1534-1551, eqs. 4.6.4a and 4.6.4b, and Table 4.7.2's `v_J`.
Every one puts the factor inside the sum over strata with no overall
multiplier. Eq. 4.5.9 is the only form with an overall factor, and it deletes
a group from every stratum, so it is not a delete-one-unit form. The
narrowing holds.

**DELTA-1, applied.** The paragraph added for FIX-2 carried no provenance
mark. Now marked to `R/core-constructors.R:807` for the old default and to
`tests/testthat/test-variance-replicate.R:877-883` and `958-964` for the two
oracle ratio assertions, which measure the same direction.

## Gotchas, Reference mapping, Open questions — 10 of 10 landed

FIX-14's line range was wrong in this file and right in the fix pass:
`R/core-constructors.R:1457` closes the zero-column guard, and the
single-column guard runs 1460 to 1470, with the class at 1469.

**DELTA-2, applied.** The nine-type conversion loop row cited
`tests/testthat/test-conversion.R:2636-2659`, which stops short of two of
the four assertions the cell claims. Now 2636-2663.

**DELTA-3, applied.** The Reference mapping row for the four-variant
ordering dropped Wolter's condition. Observation (iii) gives
`v_4 >= v_3 = v_2 >= v_1` only "whenever the `n_h` are roughly equal".
Unconditionally the chapter gives (i) `v_4 >= v_1` and (ii)
`v_3 >= v_2 >= v_1`. The row now carries the condition and says the
conclusion survives either reading.

**DELTA-4, applied.** The Wu 2022 / Chen et al. 2021 row called
`R/utils.R:1178` roxygen. It is a plain `#` comment in
`.compute_nonprob_scale()`'s header, and it is not inside
`as_survey_nonprob()`. The row now separates the genuine roxygen at
`R/core-constructors.R:1306-1311` from the comment.

**DELTA-5, applied.** Rows 3 and 5 of the five-rules table stated two
in-repo facts with no mark. Now marked to
`tests/testthat/test-variance-replicate.R:840`, `849`, `843` and `920`.

**DELTA-6, applied.** Q3 stated `rep(1, n_rep)` with no mark. Now marked to
the same file at `840` and `849`.

## One repo drift found, outside this work

`plans/error-messages.md:307` writes the `"i"` bullet of NB-3 as "Bootstrap
variance requires >= 2 replicates". `R/core-constructors.R:1467` says
"Replicate variance". The register file and the code disagree. This document
quotes only the `"x"` bullet, which matches verbatim, so no claim here rests
on it. It is a one-line docs fix and belongs to no issue in this arc.

## Sign-off

No ISSUE entries remain. Stage 0 advances to COMPREHENDED on one fix round,
inside the two-round cap.
