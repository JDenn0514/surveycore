# implementation.md — PR 1 `docs/oracle-rule-core`

## Write surface

| Action | File |
|---|---|
| Modified | `.claude/rules/testing-surveycore.md` |

`git diff --name-only` against `7800ea9` lists that one file and no other.
`git diff --stat` reads `1 file changed, 81 insertions(+)`.

No `.R` file, no roxygen block, no `NAMESPACE` entry, no `DESCRIPTION` line.

## What this PR implements

- Adds one section, `## The oracle rule — never hand `survey` a number
  surveycore computed`, at line 165 of
  `.claude/rules/testing-surveycore.md`. It sits after §The both-modes rule
  (line 93) and before §S7 error testing layers (line 245).
- Ships the section body from `spec.md` §III.2 verbatim: the two opening
  sentences, the "Which rules reach which design" paragraph, the five numbered
  rules in their spec order, and the three further constraints that follow
  them.
- Ships rule 4's degrees-of-freedom precondition paragraph, plus the paragraph
  that binds a later PR: a PR that moves surveycore's replicate path to
  design-based degrees of freedom must revisit
  `tests/testthat/test-variance-replicate.R` in the same PR.
- Adds one Quick Reference row, `Oracle tests against `survey``, immediately
  after the `Both input modes` row, so the table's row order keeps mirroring
  the file's section order. The row states that rules 2 and 3 and the per-type
  table apply to `svrepdesign()` only.
- Writes none of PR 2's content (per-type evidence table, the snapshot
  paragraph, the "What the rule covers" subsection) and none of PR 9's
  (sanctioned exceptions).

## Task checklist

- [x] 1. Located the boundary between §The both-modes rule and §S7 error
      testing layers; the new section goes between the two.
- [x] 2. Wrote the section from `spec.md` §III.2 — heading, two opening
      sentences, scope paragraph, five numbered rules, three further
      constraints. Formatting only was changed: the leading `> ` of the spec's
      block quote was removed and prose was re-wrapped at 80 columns.
- [x] 3. Wrote the degrees-of-freedom precondition paragraph and the
      later-PR clause.
- [x] 4. Added the Quick Reference row from `spec.md` §III.1.
- [x] 5. Read the section back against `spec.md` §III.2. Verified
      mechanically, not by eye: the shipped section and spec lines 122–194,
      both reduced to a single whitespace-collapsed word stream, compare
      byte-identical under `diff`. The later-PR paragraph compares identically
      against spec lines 205–208 the same way. `grep -n "^[0-9]\. \*\*"` on
      the file returns the five rules at lines 178, 181, 188, 193, 198, in the
      order 1, 2, 3, 4, 5.
- [x] 6. `air format --check .claude/rules/testing-surveycore.md` — exit 0, no
      output. `git diff --name-only` — one entry. No line in the new section
      exceeds 80 columns.
- [x] 7. Full suite, `devtools::check()`, `devtools::document()`,
      `run_examples()` and `covr` not run, per the dispatch. The leader runs
      every gate. The PR touches no `.R` file and no roxygen.

## HOLDs raised

None.

## Notes for tester

- **Two rule breaches stay open in `tests/testthat/test-variance-replicate.R`
  while this PR is on the branch, and neither is a defect in this PR.** The
  JK1 block passes a `scale` argument, which rule 2 forbids, and the JK1 and
  JK2 blocks wrap their `survey` call in `suppressWarnings()`, which rule 5
  forbids. PR 4 of this arc closes both. The test file is outside this PR's
  write surface, so the general rule ships before every block complies with
  it. Read the breach as scheduled work.
- **Rule 2 ends with a forward reference that resolves in PR 2.** Its last
  sentence reads "Read this rule with the scope paragraph at the end", and
  that scope paragraph is the "What the rule covers" subsection PR 2 adds. The
  same holds for the scope paragraph's phrase "the per-type table below". Both
  phrases are in the spec text this PR was told to ship unchanged, so the
  dangling reference is the planned intermediate state and not an editing
  error.
- The spec's `**The precondition is measured.**` paragraph is not shipped. It
  sits outside the §III.2 block quote, and it cites `measurements.md` §M7 and
  `comprehension.md` §G12 — two run-directory artifacts that no reader of a
  checked-in rules file can open.
- The file's `**Version:** 1.2` header is unchanged. The spec asks for no
  bump, and PR 2 and PR 9 edit the same file, so one bump at the end of the
  arc costs less churn than three.

## CRAN compliance

All ten builder compliance rules in
`.claude/skills/pipeline-shared/references/r-package-profile.md` are
inapplicable: this PR changes one markdown rules file, adds no R code, no
roxygen, and no export, so there is nothing for `devtools::document()` or
`_pkgdown.yml` to record.
