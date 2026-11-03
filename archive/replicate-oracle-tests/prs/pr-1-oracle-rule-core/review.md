# Review — PR 1 — oracle-rule-core

**Verdict**: PASS
**Date**: 2026-09-22

**Branch**: `docs/oracle-rule-core` at `1879a34b06b9dc02969d407eb8e36e31726bea7d`
**Base**: `7800ea9730acdcf03ae33dc24bb9a008a8920e33`
**Commit tree**: `5152c6eb4e07b28c4a149b2294fceec0b5a8ef15` — equals the tree
`audit.md` records.

## Convergence checks

- **Spec coverage**: y. All twelve allocated rows carry a result.
- **Test coverage of spec**: y. Every element of `spec.md` §III.2 inside PR 1's
  range maps to a §6 row.
- **Tolerance integrity**: vacuous. This PR ships no assertion and no number.
- **Scope discipline**: y. One file, the one the plan names.
- **Regression safety**: y. `R/`, `tests/` and `man/` are byte-identical across
  the diff.

### Step 1 — spec coverage

`implementation-plan.md` allocates PR 1 twelve `test-spec.md` §6 rows: 6.1,
6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 6.11, 6.16, 6.18, 6.19, 6.20. `audit.md` scores
all twelve and passes all twelve. I re-read every "Got" cell's line citation
against `.claude/rules/testing-surveycore.md` at `1879a34`. Every citation is
exact:

| Citation | Verified |
|---|---|
| L13 Quick Reference row | present, text matches `spec.md` line 115 |
| L165 section heading | `## The oracle rule — never hand `survey` a number surveycore computed` |
| L93 / L165 / L245 section order | both-modes rule, then this section, then S7 error testing layers |
| L178, L181, L188, L193, L198 | the five numbered rules, in the order 1–5 |
| L171, L204, L207, L214, L227, L239 | scope paragraph, the three further constraints, the precondition, the later-PR clause |

The eight §6 rows this PR does not own — 6.7, 6.9, 6.12, 6.13, 6.14, 6.17 to
PR 2, and 6.10, 6.15 to PR 9 — are named in `audit.md` with their owning PR and
were not scored. That matches the plan's row-allocation table.

`spec.md` §VIII gate 10 is an arc gate, not a PR gate. PR 1's share of it is
complete: the split between the general rules and the `svrepdesign()`-specific
ones (L171), the argument-versus-literal bullet (L207), and the Quick Reference
row (L13). The carve-out, the snapshot sentence, the version-check sentence and
the §III.3 table belong to PR 2; the two sanctioned exceptions belong to PR 9.

### Step 1b — the byte-identity check, run independently

`spec.md` §III.2 says "Use this text ... Adjust nothing but formatting", so a
silent wording change is the defect this check exists to catch. I ran it myself
rather than accept the builder's claim. Method: take the spec range, strip the
block-quote marker, reduce both sides to one whitespace-collapsed token per
line, `diff`.

| Comparison | Result |
|---|---|
| `spec.md` 122–194 against the delivered section L165–L237 | **identical**, 717 tokens |
| `spec.md` 256–259 against the delivered later-PR paragraph L239–L243 | **identical**, 47 tokens |

No wording changed. The only edits are formatting: the leading `> ` came off and
the prose re-wrapped at 80 columns. Nothing from `spec.md` 196–247 leaked into
the file, so PR 2's and PR 9's content is absent as the plan requires.

**One erratum in `implementation.md`, not a defect on disk.** Task 5 cites
"spec lines 205–208" for the later-PR paragraph. That paragraph sits at
`spec.md` 256–259. Lines 205–208 are the tail of the version-check paragraph
plus the `### What the rule covers` heading — PR 2's content, and not identical
to anything this PR ships. The builder's other citation in the same sentence
(122–194) and the five rule line numbers (178, 181, 188, 193, 198) are all
correct, which reads as a transcription slip in the artifact rather than a
verification that never ran. The substantive property holds: I confirmed the
shipped paragraph is identical to the correct spec range. The deliverable is
right, so this is recorded and not blocked.

### Step 2 — Tolerance Integrity

Mostly vacuous here, and I state that rather than invent a finding. `test-spec.md`
§8 sets three numerical tolerances and applies them to the assertions in the
oracle blocks — §2 to §5, every one of them allocated to PR 3 and later. PR 1
ships one markdown section and no assertion. `audit.md` says so and uses the
Tolerance column for a check type ("text present", "heading exact; position
exact"). No row could be loosened, because no row carries a number. No
violation.

### Step 3 — scope discipline

| Source | Write surface |
|---|---|
| `implementation-plan.md` PR 1 "Files touched" | `.claude/rules/testing-surveycore.md` |
| `implementation.md` §Write surface | `.claude/rules/testing-surveycore.md` |
| `git diff --name-only 7800ea9 1879a34` | `.claude/rules/testing-surveycore.md` |

Match. No extra file, no missing file. `git diff --stat` reads
`1 file changed, 81 insertions(+)` — insertions only, so no existing line moved.

Regression safety, measured rather than inferred. Subtree hashes across the
diff:

| Directory | Base | Head |
|---|---|---|
| `R` | `3146b739…` | `3146b739…` |
| `tests` | `1d03c325…` | `1d03c325…` |
| `man` | `f82e32a6…` | `f82e32a6…` |

Identical. No test could change state, in or out of scope. `audit.md` marks no
regression, and none was available to mark.

### Step 4 — CRAN cookbook and profile gates

`audit.md` §CRAN cookbook violations reads "None". The write surface holds no
`.R` file, so no pattern in `r-package-profile.md` §CRAN cookbook scan has
anything to match. A PASS verdict with no violation is consistent.

All seven profile gates carry a result. One skip: pkgdown, `SKIPPED — scope`.
Allowed — the write surface touches none of `R/`, `vignettes/`, `README*`,
`_pkgdown.yml` or `DESCRIPTION`, and the hard rule does not bite because the
`NAMESPACE` diff is empty. The skip is logged in the gates table with its
reason, as the profile requires.

**The not-re-run reasoning, checked.** The dispatch asked whether any gate could
still move. I verified both of the record's two facts myself, and I identify no
gate that could move on this tree.

1. `.Rbuildignore` line 8 is `^\.claude$`. The whole directory leaves the
   tarball, so gates 4, 5 and 6 cannot see the change.
2. Nothing reads the file at run time. The five `.claude` hits under `tests/`
   and `R/` — `test-constructors.R:11`, `test-glm-anova-numerical.R:7`,
   `test-metadata-system.R:4266`, `test-validators.R:8`, `R/utils.R:5` — are all
   comments citing a rule. None opens a file.
3. The `R`, `tests` and `man` subtrees are byte-identical to the baseline tree,
   so gates 1, 2, 3 and 7 would run identical code over identical inputs.

Gate 1's contract is the stronger reading — `NAMESPACE` and `man/` byte-identical
before and after `document()` — and it holds, because the roxygen sources did not
move. Gate 5's two NOTEs are both pre-existing on the clean baseline tree and
neither is new, so no new NOTE pattern appeared: `checking CRAN incoming
feasibility` is pre-approved, and `checking for hidden files and directories`
comes from `.git` and is recorded on `baseline.md` and on the earlier
`as-svydesign-bridge` arc. Read gate 5 as "2 NOTEs, and these two".

### Step 5 — coverage floor

96.15%, flat against `baseline.md`. Above the 95% floor and above the 98% target
question entirely, because the PR adds no source line: the covr denominator
cannot move, so the new-code clause has nothing to apply to.

### Step 6 — comprehension alignment

Three of `comprehension.md`'s gotchas bear on the text this PR ships, and each
lands in a shipped sentence:

| Gotcha | Where it ships |
|---|---|
| G1 — `survey` raises no typed condition | L214–L226, the message-text constraint; row 6.6 |
| G3 — the point estimate cannot detect a scale defect | L193–L197, rule 4; row 6.4 |
| G12 — both packages build the bound from the normal distribution | L227–L238, the precondition; row 6.20 |

The remaining gotchas — G2, G4, G4b, G5 to G11, G13 — constrain the oracle
blocks, which PR 3 to PR 8 write, and each is carried by a `test-spec.md` §2 to
§5 row allocated to those PRs. No gap.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every point they both address: the
one-file write surface, the two forward references that resolve in PR 2, and the
open rule breaches in `tests/testthat/test-variance-replicate.R`. Both classify
the third as scheduled work for PR 4 and outside this write surface, and both are
right — the plan's shipping sequence puts the rule before the blocks that obey it,
and the test file is not in this PR's surface. The forward references at L13, L173
("the per-type table") and L187 ("the scope paragraph at the end") are in the spec
text this PR was ordered to ship unchanged, so the dangling reference is the
planned intermediate state, not an editing error. Nothing else disagrees.

## The two judgment calls

### 1. The `**The precondition is measured.**` paragraph is rightly not shipped

**Ruling: the builder is correct. Do not ship it.**

Three authorities agree, and none of them reaches the paragraph.

- `spec.md` §III.2's instruction governs a block quote. The quote runs from line
  122 to line 247. The paragraph sits at lines 249–254, outside it. "Use this
  text" does not name it.
- `implementation-plan.md` PR 1 acceptance criterion 5 lists what the
  precondition must carry: the same distribution and the same degrees of freedom,
  both using the normal approximation today, and the later-PR obligation. All
  three are on disk at L227–L243.
- `test-spec.md` row 6.20 lists six elements. All six are present, and `audit.md`
  checks each. The row asks for no citation of a run-directory artifact.

The asymmetry the builder introduced — shipping the later-PR paragraph from
outside the quote while dropping the measurement paragraph from outside the same
quote — is not arbitrary. The plan's task 3 names the later-PR clause explicitly
and row 6.20 requires it; neither names the measurement citation.

The substantive argument is also sound. The paragraph cites `measurements.md` §M7
and `comprehension.md` §G12, both of which live in this run directory and neither
of which a reader of a checked-in rules file can open. Shipping it would put two
dead references into a permanent rule. This repository already carries that cost
once: `archive/haven-labelled/` records nine cited documents that are not in the
repository. Not repeating it is the right call.

### 2. The unbumped `**Version:** 1.2` header is not a defect in this PR

**Ruling: no bump is required, and none belongs to PR 1.**

No artifact asks for one. I grepped all three: `spec.md`, `test-spec.md` and
`implementation-plan.md` contain no instruction to bump the rules file's
`**Version:**` header, and none of `test-spec.md` §6's twenty rows checks it.
`spec.md` line 4's "**Target version**: 1.1.0.9000 (no version bump)" is the
package version in `DESCRIPTION`, a different field. A reviewer cannot block for a
requirement no artifact states.

The file's own "Decided — do not re-litigate without updating this document" does
not reach this PR either. That clause governs changing a decision already in the
file. PR 1 adds a new section and re-litigates nothing; the both-modes rule, the
invariants rule and the tolerance table are untouched.

**If the leader wants a bump, it belongs to PR 9, not here**, and the builder's
churn argument is the right one: three PRs edit this file, so one bump to 1.3 as
the arc's last edit covers all three additions where three bumps would leave two
intermediate states on `develop` that describe no stable file. One caveat — PR 9's
plan entry does not mention a version bump, so PR 9's builder will not make one
unless the criterion is added to that entry first. That is a plan edit, and it is
the leader's call, not a condition on this PR.

## Decision

PASS. All seven checks are clean. The twelve allocated rows pass and every line
citation in `audit.md` is exact against the tree it names; the delivered text is
byte-identical to `spec.md` §III.2 as a whitespace-collapsed token stream, which
I verified myself rather than accept on report; the write surface is the single
file the plan names, with the `R`, `tests` and `man` subtrees provably unmoved;
the gate carry-forward rests on two facts I re-measured, and I identify no gate
that could move on this tree. Both judgment calls the builder flagged are decided
in the builder's favour. One erratum is recorded against `implementation.md`'s
line citation for the later-PR paragraph; the file on disk is correct, so nothing
blocks.
