# Review — PR 2 — oracle-rule-evidence

**Verdict**: PASS
**Date**: 2026-09-22 10:05

Branch `docs/oracle-rule-evidence` at `c4c23f20c3c056add324eaa8fecdf6611b5aba42`.
Base `70bfe5495c1362284d13d3a56ec07c12e6ea1eff`. Tree
`51b1aee208097c6452bc58d86f750c0a0c7011bb`, which I confirmed still equals
`git rev-parse 'HEAD^{tree}'`. The diff is one file, 54 insertions, 0 deletions.

The six untracked `plans/` files and the modified `plans/pr-budget-calibration.md`
are pipeline bookkeeping. I read the diff commit-to-commit, so they are out of
scope, the same reading the audit took.

## Convergence checks

- **Spec coverage**: yes. `spec.md` §III.3 and the §III.2 tail allocated to this
  PR are shipped in full.
- **Test coverage of spec**: yes, with one planner erratum in row 6.9 (F1).
- **Tolerance integrity**: vacuous — see §Tolerance integrity.
- **Scope discipline**: yes. One file, matching the plan entry exactly.
- **Regression safety**: yes. The `R` and `tests` subtrees are byte-identical
  base to head, so no test could change state.

### Rows allocated and validated

The plan's PR 2 entry claims 6 test-spec rows — §6 6.7, 6.9, 6.12, 6.13, 6.14,
6.17 — and 7 acceptance criteria. Both sit inside the budget bounds.
`audit.md` carries one Per-Test Result Table row for each of the six and passes
all six. No allocated row is missing, and the audit claims no row the plan did
not allocate.

### The two claims the tester could not make

The tester may not read `spec.md`. I made both checks.

**1. Byte-identity against `spec.md` §III.3 and §III.2 — confirmed.**

I extracted the spec text mechanically, stripped the `> ` blockquote prefix from
§III.2, and diffed against the shipped file:

| Extent | Lines | Result |
|---|---|---|
| The per-type table, header row and nine data rows | 11 | `diff` empty — identical |
| The snapshot paragraph, the version-check paragraph and the whole `### What the rule covers` subsection | 38 | `diff` empty — identical |

Identical includes the line wrapping. The only added line that is not verbatim
spec text is the lead-in, `The table below is the evidence for rules 2 and 3,
measured on `survey` 4.5 under R 4.6.1.` The spec writes that clause as an
instruction — "Add this table under the rule. It is the evidence for rules 2 and
3, measured on `survey` 4.5 under R 4.6.1." The builder turned the directive
into shipped prose and kept the content clause word for word. That is the
formatting adjustment §III.2 permits, not a wording change.

No cell could have been edited to match a moved oracle: the diff is insertions
only, 54 added and 0 removed, so no pre-existing line changed and every added
line is byte-identical to the spec.

Placement is right. In the shipped file the oracle rule sits at line 165, after
§The both-modes rule at 93 and before §S7 error testing layers at 299. The table
is at 248 and `### What the rule covers` at 271, both inside the section.

**2. The probe agrees with the table — confirmed.**

`implementation.md` reports nine rows measured on `survey` 4.5 under R 4.6.1 at
`R = 20`, the versions §III.3 records. I checked every reported number against
the table's claim:

| Type | Table | Probe | Arithmetic at `R = 20` |
|---|---|---|---|
| BRR | `1/R` | 0.05 | 1/20 = 0.05 |
| Fay | `1/(R * (1 - rho)^2)` | 0.1020408 | 1/(20 x 0.49) = 0.1020408 |
| JK1 | `(R-1)/R` | 0.95 | 19/20 = 0.95 |
| JK2 | `1` | 1 | exact |
| JKn | `1` | 1 | exact |
| bootstrap | `1/(R-1)` | 0.05263158 | 1/19 = 0.05263158 |
| ACS | `4/R` | 0.2 | 4/20 = 0.2 |
| successive-difference | `4/R` | 0.2 | 4/20 = 0.2 |
| other | `1` | 1 | exact |

Every default-scale formula reproduces its measured value. Each honour/discard
cell matches the probe's stored reading. I did not re-probe: the builder's raw
table and its row-by-row comparison against §III.3 sit side by side in
`implementation.md`, the arithmetic closes, and the versions match the ones the
spec measured.

## Ruling on the fifth-column finding

**The four-column table is correct. The fifth column is not required in the
shipped file. This is a planner erratum in `test-spec.md` row 6.9, not a
defect.**

The evidence:

- `spec.md` §III.3 carries **four** columns: `Type`, `Default scale`,
  `A supplied scale`, `A supplied rscales`. It has no `Condition on a bare call`
  column. §III.2 says "Adjust nothing but formatting", so the builder was
  forbidden to add one.
- `test-spec.md` §7 carries **five**, adding `Condition on a bare call`.
- So the two planning artifacts disagree, and the builder shipped the spec. A
  literal reading of row 6.9's "it matches the table in §7 below" is
  unsatisfiable by any builder who obeys §III.2. The tester's pass on the row's
  own terms was the right call, and escalating the column to me was right.

Which artifact requires the fifth column, and where it belongs: **`test-spec.md`
requires it, for the tester's own use, and it belongs nowhere in the rule file.**
§7 opens with "Use this to judge §3.1 and §6.9". The conditions column exists to
judge §3.1, whose per-block column `survey` condition the block must assert
carries the fragment each of PRs 3 to 8 asserts. `spec.md` §V.1 to §V.9 carry the
same fact per block in their `survey` condition rows — §V.8, for one, fixes
`scale or rscales not specified, set to 1` for the `other` block.

So the conditions material for PRs 3 to 8 lives in two places that the block
authors read, and the rule file was never one of them. A later reader is served
by three things the shipped text already has: rule 5, which requires asserting
whatever condition `survey` raises; the message-text bullet, which says how; and
the snapshot paragraph, which tells the author to probe the installed version and
read the behaviour back rather than trust the table. A per-type conditions column
would also be the most version-fragile content in the file, and one §7 cell —
ACS's "none when `mse` is explicit" — is conditional on a block's own argument,
which does not belong in a table about `scale` and `rscales`. Leaving it out is
defensible on its merits, not only on authority.

If the leader wants the conditions column in the rule file, that is a new scope
item for PR 9 and a spec amendment to §III.3. It is not PR 2 rework.

## Judgement on the two substituted probe rows

**Both rows remain evidence for what the table claims. Neither substitution
weakens them.**

- **JKn, probed with `rscales` supplied.** The table's own `rscales` cell reads
  "required, honoured". The first word *is* the refusal. Supplying `rscales` does
  not work around the table's claim; it instantiates it. Reading whether JKn
  honours a supplied `scale` needs `rscales` present because that is the only
  shape that builds, so the cell "honoured" was measured on the only measurable
  path. The builder flagged that this is the one cell whose first word is about
  buildability rather than behaviour. That is accurate, and the spec wrote it
  that way deliberately.
- **Fay, probed at `rho = 0.3`.** The cell is a formula *in* `rho`, so it cannot
  be instantiated without one, and `survey` refuses to build without one. The two
  behaviour cells — "discard, no warning" and "honoured" — were measured with
  `rho` present, which is again the only buildable shape, and `rho` is orthogonal
  to what `survey` does with a supplied `scale`.

  One honest limit: a single point confirms the formula's *value* at
  `rho = 0.3`, not its functional form across `rho`. The measured 0.1020408 does
  discriminate against the plausible alternatives at `R = 20` — `1/R` gives
  0.05 and `1/(R(1-rho))` gives 0.0714 — so the row is strong evidence, not
  proof. This does not reach a finding: the file tells every reader the table is
  a snapshot to be re-probed, and the spec fixed the cell's text.

## The `other` row and the warning the probe found

The builder reports that `other` stores a supplied `scale` **and** still raises
`scale or rscales not specified, set to 1`, so the message is false on that path.

**The table's `other` row is complete for the question the table asks, and
correct.** The three behaviour columns answer what `survey` does with a supplied
value — store it or throw it away. `other` stores it. "honoured" is exact.

One asymmetry is worth recording, and it is the spec's, not the builder's. Four
rows — BRR, JK2, ACS, successive-difference — write "warn, discard", so the table
is not condition-free. A reader could therefore infer from a bare "honoured" that
`other` is silent. That inference is wrong. Three mitigations hold: rule 5
requires asserting whatever condition fires, so a block author following the rule
cannot assert silence by mistake; the snapshot paragraph tells the author to probe
and read the behaviour back; and the fact itself is already recorded upstream in
`comprehension.md` §G4 and asserted downstream at `test-spec.md` row 3.1.8, which
PR 8's block must satisfy. Nothing is lost. See F2 — an observation for PR 9, not
a defect, because §III.2 forbade the builder from adjusting the cell.

The builder's other observation, that JK2 and `other` warn on a bare call, is
also §G4 content and contradicts no cell. Agreed on both counts.

## Tolerance integrity

**Vacuous, and I decline to invent a finding.** This PR ships one Markdown file.
It adds no assertion, no numeric comparison and no tolerance. `test-spec.md` §8's
three tolerances govern the §3 block rows, every one of which is allocated to
PRs 3 to 8. The audit's Tolerance column reads "exact text" or "byte-exact" on
all six rows, which is the right reading for a documentation row and is not
looser than anything the test-spec specifies. No relaxation is possible here.

## Scope discipline

The plan's Files touched for PR 2 is `.claude/rules/testing-surveycore.md`.
`implementation.md` §Write surface names that one path. `git diff --name-only`
base to head returns that one path. No extra file, no missing file.

No regression outside scope is possible: `R` and `tests` are byte-identical base
to head, so the suite runs identical code over identical inputs.

One plan deviation, sanctioned. Plan task 7 says "Run `air format --check`. Run
the full suite." The builder ran `air format --check` (exit 0) and did not run
the suite. `decisions.md` §S1 is the leader's standing instruction that the seven
R gates are not re-run on the three rules-only PRs. The deviation is authorised
and does not count against the PR (F4).

## Gate carry-forward — re-measured

I re-ran the identity measurement rather than taking `gates.md` on trust:

| Path | Base → head |
|---|---|
| `R` | IDENTICAL — `3146b739c8d173310ee6a8bfc225318fa885e757` |
| `tests` | IDENTICAL — `1d03c325c085a3d2da73d44b2ef94f25f2bfe30b` |
| `man` | IDENTICAL — `f82e32a6512c8c41b146a648257fd962e2fbc614` |
| `NAMESPACE` | IDENTICAL — `27c131881726a06dfc55ccdcfeb5f115a265052a` |
| `DESCRIPTION` | IDENTICAL — `70660166464ffb09b2aa0ce94e6ba3973efbdb8c` |
| `vignettes` | IDENTICAL — `81ad88246458499d4e87e3b29410a40063dc4e7e` |
| `_pkgdown.yml` | IDENTICAL — `517d963bbf3764d0c9a42e8d666158c2570922bd` |
| `.Rbuildignore` | IDENTICAL — `356be8e71dc98bcf713e1ddb0d48165cba7e1ff3` |

`.Rbuildignore` line 8 is `^\.claude$`, so `R CMD build` never puts the changed
file in the tarball. I also checked the run-time claim myself:
`grep -rn "testing-surveycore\|\.claude/rules" R tests` returns seven hits and
every one is a comment citing a rule — no `readLines()`, no file open. So gates 1
to 7 would read identical inputs.

**I name no gate for a re-run.** Every input to every gate is byte-identical, and
the one differing file is outside the tarball and unread at run time. A re-run
would measure machine noise.

Row 6.17 verified independently: the `tests/testthat/test-conversion.R` blob is
`b3a1251fe6e349d88a566698ba0a1947032b42f4` at both base and head, and both named
block titles match by fixed-string search at lines 239 and 567.

## Profile gates and the CRAN cookbook

`audit.md` §CRAN cookbook violations reads "None", and the write surface holds no
`.R` file, so the scan has nothing to scan. Every gate carries a result.

The pkgdown skip is allowed. `r-package-profile.md` §pkgdown skip condition
permits it when the write surface touches no `R/`, `vignettes/`, `README*`,
`_pkgdown.yml` or `DESCRIPTION` — confirmed above, all identical. The hard rule
does not bite: the `NAMESPACE` diff is empty, so no export changed.

The second NOTE, `checking for hidden files and directories`, is not on the
pre-approved list. It does **not** trigger STOP. `signals.md` §STOP reaches a
*new* NOTE pattern, and `baseline.md` records this one on the clean baseline tree
at `e9a6c808` with no change applied, caused by `.git` through `.Rbuildignore`.
Gate 5 reads as "2 NOTEs, and these two", exactly as `baseline.md` instructs. A
third NOTE would block.

## Coverage

96.15%, flat against the `baseline.md` figure of 96.15%. Above the 95% floor.
This PR adds no source line, so the denominator cannot move and there are no new
lines to leave uncovered. Clean.

## Comprehension alignment

`comprehension.md` exists, so I ran the check on this PR's content.

§G4 — "JK2 warns even when the caller supplies nothing", which also records
`other`'s bare-call `scale or rscales not specified, set to 1` and JK1's guessing
warning — is the gotcha the builder's two extra observations restate. It is
covered: `test-spec.md` rows 3.1.2, 3.1.3 and 3.1.8 each require the matching
block to assert the fragment, at PRs 4 and 8, and §7's fifth column holds the
reference. §G12, the degrees-of-freedom precondition, shipped in PR 1's text and
is restated in §III.2. No gotcha relevant to PR 2 is unreached by either a
test-spec scenario or a spec rationale. Clean.

## The three planned absences — all confirmed not defects

1. **PR 9's `### Sanctioned exceptions` subsection is absent.** Rows 6.10 and
   6.15 belong to it and are not allocated to PR 2. The added text introduces no
   expectation total and no run time, so it does not pre-empt 6.10.
2. **`tests/testthat/test-variance-replicate.R` still breaches the rule** — JK1
   passes `scale`; JK1 and JK2 wrap the `survey` call in `suppressWarnings()`.
   `implementation-plan.md` lines 114 to 117 tell a reviewer of PR 1 or PR 2 to
   read the breach as scheduled work, and PR 4 closes it. The file is outside
   this write surface and is byte-identical base to head.
3. **`**Version:** 1.2` is unchanged, and §S2's reasoning holds.** I re-checked
   its premise: `grep` across `spec.md`, `test-spec.md` and
   `implementation-plan.md` finds no mention of the version header and no §6 row
   that checks it. So a bump here would be an edit no artifact requires, outside
   the spec's fixed text. It would also go stale immediately — PR 9 adds a whole
   subsection to the same file, so a bump at PR 2 would describe a file that PR 9
   then changes again. **The bump belongs at PR 9, not here.**

## Observations — none is a BLOCK or a STOP

- **F1 — planner erratum, `test-spec.md` row 6.9.** "it matches the table in §7
  below" cannot be satisfied literally: §7 has five columns and `spec.md` §III.3,
  which governs the shipped text, has four. Record the erratum; do not re-spec.
  Suggested reading for the remaining PRs: row 6.9 means "matches §7 on the three
  columns describing what `survey` does with a supplied `scale` and `rscales`".
- **F2 — spec observation for PR 9's consideration.** The table writes "warn,
  discard" on four rows and a bare "honoured" on `other`, which in fact warns
  while honouring. Mitigated by rule 5, the snapshot paragraph, §G4 and test-spec
  row 3.1.8. Changing it needs a §III.3 amendment, so it cannot be PR 2 rework.
- **F3 — Fay's row rests on one `rho`.** Confirms the formula's value at
  `rho = 0.3`, not its form across `rho`. Inherent to a cell that is a formula in
  `rho`; the snapshot paragraph already sets the reader's expectation.
- **F4 — plan task 7's "Run the full suite" was not run**, per `decisions.md`
  §S1. Authorised.
- **F5 — the file uses CRLF terminators**, pre-existing for the whole file and
  not introduced by this diff. Matches the `_snaps/` line-ending rule's
  neighbourhood; no action.

## Cross-consistency notes

`implementation.md` and `audit.md` agree on every fact I can check
independently: the one-file write surface, the 54/0 diff, the nine-row table,
the two block titles at lines 239 and 567, `air format --check` exit 0, the
`test-conversion.R` blob, the carried gate figures, and the tree hash
`51b1aee2`. The only divergence between them is one the audit declared: the
tester ran no probe, and the builder did. That is the division of labour the
dispatch set, and I closed the gap by checking the builder's probe against the
spec's table myself.

Both artifacts independently flag the same three planned absences and the same
fifth-column question. No disagreement to resolve.

## Decision

PASS. All seven checks are clean: the six allocated rows are covered and pass;
the shipped table and prose are byte-identical to `spec.md` §III.3 and §III.2 on
a 49-line mechanical diff, with an insertions-only patch that makes a silent cell
edit impossible; the write surface matches the plan exactly; the CRAN cookbook
and the profile gates are clean, with the gate carry-forward re-measured on eight
subtrees; coverage is flat at 96.15% over an unchanged denominator; comprehension
§G4 and §G12 are both reached; and `audit.md`'s verdict is PASS. The fifth-column
finding resolves as a planner erratum in `test-spec.md` row 6.9 with no shipped
consequence, and Tolerance Integrity is vacuous on a PR that ships no number.
