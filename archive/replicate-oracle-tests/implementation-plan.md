# Implementation plan — replicate-oracle-tests

**Date**: 2026-09-16
**Spec**: `spec.md` in this run directory
**Test-spec**: `test-spec.md` in this run directory
**Bounds**: 12 test-spec rows and 8 acceptance criteria per PR
**PR count**: 9

---

## Row count

I counted the numbered rows in `test-spec.md` myself. The total is 72.

`test-spec.md` gained five rows after SPEC_READY. Plan review pass 1 found seven
places where `spec.md` states a requirement and the test-spec carried no row, or
carried a weaker one. The user approved the amendments. They are listed in
`test-spec.md` §Errata applied after SPEC_READY and recorded in `decisions.md`.
The new rows are 2.24, 2.25, 6.18, 6.19 and 6.20. Rows 2.18 and 2.23 were
corrected in place and gained no number.

| Section | Rows | Count |
|---|---|--:|
| §2 Structural checks | 2.1 to 2.25 | 25 |
| §3.1 The per-type table | 3.1.1 to 3.1.9 | 9 |
| §3.5 Run result | 3.5.1 to 3.5.6 | 6 |
| §3.6 The ratio assertion | 3.6.1 to 3.6.4 | 4 |
| §4 Sensitivity probe | 4.1 to 4.3 | 3 |
| §5 End-to-end power proof | 5.1 to 5.5 | 5 |
| §6 The rule text | 6.1 to 6.20 | 20 |
| **Total** | | **72** |

§6 runs its rows out of order across two tables. The first table carries 6.1 to
6.7, 6.11 to 6.16, and the two new rows 6.19 and 6.20 — fifteen points the rule
must state. The second carries 6.8, 6.9, 6.10, 6.17 and the new 6.18 — five
further checks. Together they cover 6.1 to 6.20 with no gap and no repeat.

§1, §3.2, §3.3, §3.4 and §3.7 carry no numbered row of their own. They are prose
constraints that numbered rows point at, so they get no allocation. They still
bind:

| Section | Binds |
|---|---|
| §1 The replicate-count facts per generator mode | PR 3 to PR 8. New row 2.24 now carries its one checkable requirement, so the section is no longer unchecked. |
| §3.2 What each numerical block asserts | PR 3, PR 4, PR 5, PR 6, PR 7 |
| §3.3 The Fay block | PR 8 |
| §3.4 The two pinned blocks | PR 5, PR 6 |
| §3.7 The pinned-block comment | PR 5, PR 6 |

Every one of the 72 rows is claimed by exactly one PR. The allocation table at
the end of this document lists each row against its PR.

---

## Why the work ships as nine PRs

`spec.md` §I calls the work "PR 1 of the replicate-scale arc". One PR would
carry all 72 rows against a bound of 12, so the budget in
`artifact-schemas.md` §PR budget overrides the spec's framing. The budget wins,
and the work splits.

The split follows the write-surface table in `spec.md` §II. Each PR takes one
group of sites that share a probe and a shape:

| PR | Group | Spec sites |
|--:|---|---|
| 1 | The oracle rule — the five numbered rules and the scope split | §III.1, §III.2 |
| 2 | The oracle rule — the evidence table and the carve-outs | §III.2, §III.3 |
| 3 | The eight existing agreeing blocks, plus the invariant call | §V.1, §V.6, §V.7, §IV.4 |
| 4 | The JK1 and JK2 rewrites | §V.2, §V.3 |
| 5 | The JKn block | §V.4 |
| 6 | The bootstrap block | §V.5 |
| 7 | The `other` block | §V.8 |
| 8 | The Fay block | §V.9 |
| 9 | The oracle rule — the sanctioned exceptions, and the finished-file run | §III.2 |

Two groups from the starting decomposition changed shape.

**The four BRR blocks join the ACS and successive-difference blocks.** All eight
take the identical pair of additions: one no-warning assertion and one
stored-scale assertion. Splitting them would give one PR of two rows and another
of four, and both would repeat the same probe. PR 3 carries all eight at six
rows and eight criteria.

**JKn and bootstrap split into two PRs.** Held together they carry 13 rows,
which is over the bound by one. The pinned-shape rows — 2.9, 2.10, 2.11, 2.15,
2.16 and §3.6 — read both blocks at once, so they count at PR 6, the later of
the two. PR 5's own acceptance criteria still state the wrapper shape and the
ratio assertion for the JKn block, so a tester checks that shape when the block
lands and not one PR later.

### The rule text ships in three parts

§6 carries 20 rows against a bound of 12, so the rule section cannot ship in one
PR. Two choices were open: split the text, or distribute its rows across the
PRs whose blocks the rule governs. I split the text. The reason is that a row
of §6 asks what the rule text says, and only the PR that writes that sentence
can make the row true. Distributing 6.9 to a block PR that writes no rule text
would allocate a row to a PR that cannot satisfy it, which the task forbids.

Three parts, not two. Two parts cannot fit at 20 rows. The part that ships last
also carries §3.5's six whole-file run rows, because nothing earlier can satisfy
them, so it can hold at most six rule rows against the bound of 12. That leaves
14 rule rows for the other part, which is over the bound. And the part holding
row 6.15 must ship last, because 6.15 names the JKn, bootstrap and Fay blocks
and those arrive in PR 5, PR 6 and PR 8. So the text splits three ways:

| Part | PR | Content | Rows |
|---|--:|---|--:|
| Core | 1 | The heading and its position, the scope paragraph, the five numbered rules, the three further constraints, the degrees-of-freedom precondition, the Quick Reference row | 12 |
| Evidence | 2 | The per-type table, the snapshot paragraph, the version-check sentence, the "What the rule covers" subsection | 6 |
| Exceptions | 9 | The sanctioned-exceptions subsection | 2 |

PR 1 and PR 2 ship the general rule before every block complies with it. Two
breaches stay open while they do: the JK1 block passes a `scale` argument, and
the JK1 and JK2 blocks wrap their `survey` call in `suppressWarnings()`. PR 4
closes both. A reviewer of PR 1 or PR 2 should read the breach as scheduled work
and not as a defect in the PR under review.

---

## The shipping sequence

The PRs ship in the order 1, 2, 3, 4, 5, 6, 7, 8, 9. **No two PRs run at the
same time.** Seven of the nine write
`tests/testthat/test-variance-replicate.R` and three write
`.claude/rules/testing-surveycore.md`, so no pair of write surfaces is disjoint.
pipeline-ship runs one PR at a time, and that is the only reading under which
the shared write surface is sound. Each PR branches from `develop` after the
previous PR merges.

Five ordering constraints are hard:

1. PRs 5, 6 and 8 ship before PR 9. Row 6.15 names the two sanctioned
   exceptions, and PR 5, PR 6 and PR 8 create the blocks the rule text
   describes. PR 4 also ships before PR 9, for a different reason: row 3.5.1
   reads the finished file, and the JK1 and JK2 rewrites must be in it.
   Constraint 5 subsumes both under the stated order. An earlier draft of this
   list wrote the second dependency as "PR 4 ships before PR 9" and cited row
   6.15 for it. That pairing was wrong — 6.15 names no block PR 4 touches — and
   the two dependencies are now stated apart. `decisions.md` records the fix.
2. PR 5 ships before PR 6. PR 5 writes the `# Block 24:` header that PR 6 writes
   under, and the pinned-shape rows count at PR 6 because they read both blocks.
3. PR 7 ships after PR 3, PR 4, PR 5 and PR 6. §4's sensitivity probe covers all
   eight numerical types, and the eighth is `other`.
4. PR 7 ships before PR 8. `spec.md` §II fixes the order of the four new blocks
   under one `# Block 24:` header as JKn, bootstrap, `other`, Fay, and forbids
   interleaving. PR 7 writes the `other` block and PR 8 writes the Fay block, so
   the file order forces the PR order. The stated sequence already satisfies it.
5. PR 9 ships last. §3.5's rows read the finished file: 28 blocks, nine types,
   one run with `survey` present and one with it absent.

PR 4 could ship before PR 3 without breaking a row. The stated order is the one
to use, because PR 3 adds the `test_invariants()` call the file lacks today and
that closes a standing breach of
`.claude/rules/testing-surveycore.md`.

---

## The two-file gate reads per PR

`test-spec.md` row 2.13 and `spec.md` §VIII gate 12 say `git diff --name-only`
lists exactly two files. That figure is the arc's total write surface, not one
PR's. Per PR the gate reads: **no third file appears.** A PR may list one of the
two files.

| PR | Files the diff lists |
|--:|---|
| 1, 2, 9 | `.claude/rules/testing-surveycore.md` only |
| 3, 4, 5, 6, 7, 8 | `tests/testthat/test-variance-replicate.R` only |

A tester must not BLOCK a rule-only PR for listing one file. A third file in any
PR's diff is a BLOCK. Row 2.13 counts at PR 3, the first PR with a test-file
diff; every later PR repeats the same check as a standing gate.

---

## Standing gates — every PR

These hold on every PR and are not re-allocated as rows:

1. The diff lists no third file (see the section above).
2. Both touched files pass `air format --check`. `air` is a command-line tool
   here, not an R package, and several files repo-wide are already not clean, so
   the gate reads as "the file this PR touches passes".
3. The full suite passes: `Rscript -e "devtools::test()"`. No new failure and no
   new skip. "0 warnings" reads as "no new warning" — the suite carries 256
   pre-existing small-cell warnings on a clean base branch (issue #167) and one
   pre-existing warning in the correlation block.
4. `test_invariants(` appears exactly once in
   `tests/testthat/test-variance-replicate.R` from PR 3 onward. No PR after PR 3
   adds a second call, even though PR 5, PR 6, PR 7 and PR 8 each build a design
   with `as_survey_replicate()`. The house rule is one call per constructor per
   file.
5. `tests/testthat/test-conversion.R` is unchanged. Row 6.17 counts at PR 2;
   every later PR repeats the check.
6. Nothing under `R/` changes, and no roxygen changes. So `devtools::document()`,
   `devtools::run_examples()` and `pkgdown::build_site()` produce no diff and no
   new error. A diff from any of the three means the write surface leaked.
7. Coverage stays at or above 95%, measured with `NOT_CRAN=true`. Every PR adds
   test code and no source line, so the figure is expected flat or slightly up.
8. No block in `tests/testthat/test-variance-replicate.R` hard-codes a replicate
   count. Row 2.24 counts at PR 3, the first PR that writes a replicate-count
   expression into the file; PR 4 to PR 8 each repeat the check over the blocks
   they write.

## A note on the task shape

No PR ships an `R/` change. So the usual TDD sub-steps — write a failing test,
implement, verify green — do not apply. The tests are the deliverable. Each
block PR takes this shape instead:

1. **Probe.** Build a design on the installed `survey`, with the arguments the
   block may pass and no others. `spec.md` §III.2's snapshot paragraph requires
   this step: the per-type table records `survey` 4.5, and a later release can
   change a default or a message without changing its interface.
2. **Read back.** Read the stored scale, the condition and the warning count off
   the probe. Compare each against the figure in `spec.md` §V for the block's
   type. On a disagreement, stop and report the installed `survey` version and
   the measured value. Do not edit the block to match a moved oracle.
3. **Write the block.**
4. **Run the single file.** `Rscript -e 'testthat::test_local(filter =
   "variance-replicate")'`.
5. **Confirm the expected colour.** Eight block types are green. The two pinned
   blocks are green as blocks, with three wrapped assertions failing inside
   them. §5's power proof is the one step that asks for a red.

---

## PR map

- [x] **PR 1: `docs/oracle-rule-core`** — write the oracle rule's five numbered
      rules, the scope split and the Quick Reference row.
  - **Budget** — 12 test-spec rows | 7 criteria
    - Rows: §6 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 6.11, 6.16, 6.18, 6.19, 6.20
    - The entry sits at the row bound of 12 and inside the criteria bound of 8.
      Criteria 4 and 5 of the earlier draft each covered one of `spec.md`
      §III.2's three further constraints. They are now one criterion covering
      all three, which frees the slot criterion 5 uses for the
      degrees-of-freedom precondition. `decisions.md` records the consolidation.
  - **Tasks**
    1. Open `.claude/rules/testing-surveycore.md`. Find the end of §The
       both-modes rule and the heading of §S7 error testing layers. The new
       section goes between the two.
    2. Write the section from `spec.md` §III.2: the heading, the two opening
       sentences, the "Which rules reach which design" paragraph, the five
       numbered rules, and the three further constraints that follow them.
       Change nothing but the formatting.
    3. Write the degrees-of-freedom precondition paragraph that follows rule 4
       in `spec.md` §III.2, including the clause that binds a later PR which
       moves the replicate path to design-based degrees of freedom.
    4. Add the Quick Reference row from `spec.md` §III.1 to the table at the top
       of the file.
    5. Read the section back against `spec.md` §III.2 sentence by sentence.
       Confirm the five rules keep their numbers.
    6. Run `air format --check` on the file. Run `git diff --name-only` and
       confirm one entry.
    7. Run the full suite. Confirm the same result as the base branch.
  - **Acceptance criteria**
    1. The file carries a section headed "The oracle rule — never hand `survey`
       a number surveycore computed", after the both-modes rule section and
       before the S7 error testing layers section (row 6.18).
    2. The section carries five numbered rules. They state, in order: both sides
       from the same inputs with `mse` explicit; `scale` to neither side, with
       the reason that `survey` honours it for four types; `rscales` to JKn only,
       as the same literal on both sides, never read off the surveycore design;
       assert the standard error and not the point estimate alone, because the
       scale enters the variance only; assert the condition `survey` raises and
       do not silence it (rows 6.1 to 6.5).
    3. The section carries the paragraph that names which rules reach which
       design class, and it says the `scale` rule, the `rscales` rule and the
       per-type table reach replicate designs only (row 6.11).
    4. The section carries all three of `spec.md` §III.2's further constraints:
       that conditions are matched by message text because every condition
       `survey` raises is untyped, naming both house rules a reader could read as
       requiring `class =` (row 6.6); that a formula forbidden as an argument is
       still allowed as an assertion literal, with JK1 as the worked case (row
       6.16); and that a block never asserts one side's stored scale against the
       other side's but asserts each against a literal (row 6.19). A section
       carrying two of the three fails this criterion.
    5. The section carries rule 4's confidence-bound precondition: both sides
       build the interval from the same distribution and the same degrees of
       freedom, both use the normal approximation today, and a later PR that
       moves the replicate path to design-based degrees of freedom must revisit
       `tests/testthat/test-variance-replicate.R` in the same PR (row 6.20).
    6. The Quick Reference table at the top of the file carries one new row for
       the oracle rule, and that row says the `scale` and `rscales` rules apply
       to `svrepdesign()` only (row 6.8).
    7. `git diff --name-only` lists `.claude/rules/testing-surveycore.md` and no
       other file. `air format --check` passes on it. The full suite matches the
       base branch.
  - **Files touched** — `.claude/rules/testing-surveycore.md`
  - **Pipeline tier**: recommended

- [x] **PR 2: `docs/oracle-rule-evidence`** — add the per-type evidence table,
      the snapshot paragraph and the "What the rule covers" subsection.
  - **Budget** — 6 test-spec rows | 7 criteria
    - Rows: §6 6.7, 6.9, 6.12, 6.13, 6.14, 6.17
    - Both figures sit inside their bounds.
  - **Tasks**
    1. Probe the installed `survey`. For each of the nine replicate types build
       a design at `R = 20`: once bare, once with a supplied `scale`, once with a
       supplied `rscales`. Read back the stored scale and every condition.
    2. Compare the nine probe rows against the table in `spec.md` §III.3. On a
       disagreement, stop and report the row, the installed `survey` version and
       the measured value. Do not edit the table to match the probe.
    3. Append the `spec.md` §III.3 table under the rule section, with the
       sentence that records the measured `survey` and R versions.
    4. Write the snapshot paragraph and the sentence that tells a maintainer to
       check the `survey` version before reading a red block as a surveycore
       regression.
    5. Write the "What the rule covers" subsection: the round-trip carve-out
       naming both `tests/testthat/test-conversion.R` blocks by title and saying
       both stay, and the sentence that excludes `as_survey_nonprob()`.
    6. Confirm both named block titles exist in
       `tests/testthat/test-conversion.R`, and that `git diff` lists no change to
       that file.
    7. Run `air format --check`. Run the full suite.
  - **Acceptance criteria**
    1. The rule section carries the table of what `survey` does with a supplied
       `scale` and a supplied `rscales`, one row per replicate type, nine rows,
       and it names the measured `survey` version (row 6.9).
    2. Every row of the delivered table is identical to the corresponding row of
       `spec.md` §III.3. No cell was edited to match a moved oracle. Where the
       task 2 probe disagreed with a row, the PR description reports the row, the
       installed `survey` version and the measured value, and the delivered table
       still carries the spec's row.
    3. The section says the table is a snapshot and tells an author to probe the
       installed version before writing a new block (row 6.13).
    4. The section tells a maintainer to check the `survey` version before
       reading a red oracle block as a surveycore regression (row 6.14).
    5. The section carries a subsection saying the rule does not cover a
       round-trip test, naming both `tests/testthat/test-conversion.R` block
       titles, and saying both are correct and stay (row 6.12).
    6. The section says the rule does not cover `as_survey_nonprob()`, because
       `survey` has no non-probability design class (row 6.7).
    7. `git diff --name-only` lists `.claude/rules/testing-surveycore.md` and no
       other file. `tests/testthat/test-conversion.R` shows no change (row 6.17).
       `air format --check` passes.
  - **Files touched** — `.claude/rules/testing-surveycore.md`
  - **Pipeline tier**: recommended

- [x] **PR 3: `test/replicate-oracle-silent-blocks`** — add the no-warning
      assertion and the stored-scale assertion to the eight existing agreeing
      blocks, and add the one `test_invariants()` call.
  - **Budget** — 7 test-spec rows | 8 criteria
    - Rows: §2 2.13, 2.14, 2.19, 2.24; §3.1 3.1.1, 3.1.6, 3.1.7
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Probe each of the eight blocks. Build the `survey` design on the block's
       own fixture arguments and seed, and collect every condition the call
       raises. Confirm each of the eight calls is silent. If one warns, record
       the seed, the full warning text, the mean replicate weight and the weight
       ratio, and stop.
    2. Probe the stored scale. Read `sv$scale` back from each of the eight
       designs. Confirm `1 / R` on the four BRR designs and `4 / R` on the two
       ACS and two successive-difference designs. `R` is 10 on seven of the
       eight and 5 on the `mse = FALSE` block, which builds on 10 primary
       sampling units.
    3. Edit each of the eight blocks. Add the no-warning assertion on the
       design-building call, and add the stored-scale assertion against the
       formula in the replicate count read from the selected columns. Put the
       one-line comment above each stored-scale assertion: it guards `survey`'s
       own default, a failure there means `survey` changed, and the tolerance is
       the standard-error and variance row. Change nothing else in the eight
       blocks.
    4. Add one `test_invariants()` call on the surveycore design in the block
       titled `get_means() replicate SE matches survey::svymean() — BRR design`.
       Add no second call anywhere in the file.
    5. Leave `mse = FALSE` alone on both sides of the block titled
       `get_means() replicate: mse=FALSE matches survey with mse=FALSE`. It is
       the only block that reaches the centred branch of the replicate variance
       expression.
    6. Run the single file. Confirm 0 failures.
    7. Grep the file for `test_invariants(` and confirm one hit. Run
       `air format --check` and `git diff --name-only`. Run the full suite.
  - **Acceptance criteria**
    1. Each of the eight blocks asserts that its `survey::svrepdesign()` call
       raises no warning.
    2. Each of the eight blocks asserts `survey`'s stored scale against a formula
       in the replicate count: `1 / R` in the four BRR blocks, `4 / R` in the two
       ACS and the two successive-difference blocks (rows 3.1.1, 3.1.6, 3.1.7).
    3. No block hard-codes a replicate count. Every block reads `R` from the
       replicate columns it selected (row 2.24).
    4. Every stored-scale assertion carries a one-line comment above it, and that
       comment says all three things: the assertion guards `survey`'s own
       default; a failure there means `survey` changed and not that surveycore
       regressed; and the tolerance is the standard-error and variance row, so a
       later editor does not widen it. A comment with two of the three fails this
       criterion (`spec.md` §IV.3; row 2.18 counts all 13 comments at PR 7).
    5. Every stored-scale assertion uses tolerance `1e-8`.
    6. `test_invariants(` appears once in the file, inside the block titled
       `get_means() replicate SE matches survey::svymean() — BRR design`
       (row 2.19).
    7. The block titled `get_means() replicate: mse=FALSE matches survey with
       mse=FALSE` still passes `mse = FALSE` to both sides.
    8. `git diff --name-only` lists `tests/testthat/test-variance-replicate.R`
       and no other file (row 2.13, read per PR). `air format --check` passes on
       it (row 2.14).
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 4: `test/replicate-oracle-jk1-jk2`** — rewrite the JK1 and JK2 oracle
      blocks, and prove the JK1 block turns red on a wrong default.
  - **Budget** — 10 test-spec rows | 8 criteria
    - Rows: §2 2.2, 2.5, 2.25; §3.1 3.1.2, 3.1.3; §5 5.1, 5.2, 5.3, 5.4, 5.5
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
      Row 2.25 folds into criterion 1 rather than gaining a criterion of its own,
      because the entry is already at the criteria bound.
  - **Tasks**
    1. Probe JK1. Build the `survey` design on the `jk1` fixture at seed 15 with
       no `scale`, and capture every condition. Confirm one warning, whose
       message contains `guessing n=number of replicates`. Read `sv$scale` back
       and confirm `(R - 1) / R` at `R = 20`.
    2. Probe JK2. Build the `survey` design on the same fixture with no `scale`
       and no `rscales`. Confirm one warning, whose message contains
       `with type JK2 scale= and rscales= are not needed`. Read `sv$scale` back
       and confirm `1`.
    3. Rewrite the JK1 block whole. Three things come out and do not come back:
       the two lines that compute the scale in the block body, the `scale =`
       argument on the `survey` call, and the `suppressWarnings()` round it.
       Assert the warning by the fragment, assert the warning count, assert the
       four quantities, and assert `survey`'s stored scale against `(R - 1) / R`
       with its comment. Do not match on the string `JK1` alone and do not use
       the full warning text: it contains `(n-1)/n`, and the parentheses read as
       a regular-expression group.
    4. Rewrite the JK2 block whole. The `suppressWarnings()` comes out. Assert
       the warning by the fragment and assert the warning count. Keep the
       block's existing comment on the JK2 scale and its existing assertion that
       the surveycore design stores `scale = 1`. Add the assertion of `survey`'s
       stored scale against `1` with its comment. Do not write that JK2's
       per-stratum factors belong in `rscales`.
    5. Run the single file. Confirm 0 failures.
    6. Grep the file. Confirm no `survey::svrepdesign()` call receives a `scale`
       argument, and confirm `suppressWarnings(` has no hit. Two pre-existing
       `scale =` hits belong to blocks that call an internal variance routine
       directly and build no `survey` design; they stay.
    7. Run the power proof. Find the value the replicate constructor stores as
       the default scale for `type = "JK1"`, change it to `1`, run the single
       file, and record which assertions fail. Revert the change. Confirm
       `git status` reports no modified file under `R/`, then run the file again.
    8. Run the full suite and `air format --check`.
  - **Acceptance criteria**
    1. All three of `spec.md` §V.2's removals hold in the JK1 block. It passes no
       `scale` to `survey::svrepdesign()` (row 2.2); it wraps the call in no
       `suppressWarnings()`; and its body contains no line that computes
       `(n_rep - 1L) / n_rep`, and no other restatement of surveycore's own
       default scale formula (row 2.25). The formula stays allowed inside the
       stored-scale assertion of criterion 2. The block also asserts exactly one
       warning whose message contains `guessing n=number of replicates`
       (row 3.1.2).
    2. The JK1 block asserts the point estimate at `1e-10`, the standard error at
       `1e-8`, both bounds at `1e-6`, and `survey`'s stored scale against
       `(R - 1) / R` at `1e-8`. The stored-scale assertion carries its one-line
       comment above it, and that comment says all three things: it guards
       `survey`'s own default; a failure there means `survey` changed and not
       that surveycore regressed; and the tolerance is the standard-error and
       variance row.
    3. The JK2 block wraps its call in no `suppressWarnings()` and asserts
       exactly one warning whose message contains `with type JK2 scale= and
       rscales= are not needed` (row 3.1.3).
    4. The JK2 block keeps its comment on the JK2 scale and its assertion that
       the surveycore design stores `scale = 1`, and adds the assertion of
       `survey`'s stored scale against `1`. That assertion carries its own
       one-line comment saying all three things: it guards `survey`'s own
       default; a failure there means `survey` changed and not that surveycore
       regressed; and the tolerance is the standard-error and variance row.
    5. `suppressWarnings(` has 0 hits in the file (row 2.5).
    6. With the constructor's JK1 default changed to `1`, the JK1 block fails on
       the standard error and on both confidence bounds, its point-estimate
       assertion still passes, and every other block in the file keeps the result
       it had before the change (rows 5.1, 5.2, 5.3).
    7. After the change is reverted, the JK1 block passes again and `git status`
       reports no modified source file (rows 5.4, 5.5).
    8. The file runs with 0 failures. The diff lists
       `tests/testthat/test-variance-replicate.R` and no other file.
       `air format --check` passes.
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 5: `test/replicate-oracle-jkn`** — add the JKn oracle block, pinned,
      under a new section header.
  - **Budget** — 3 test-spec rows | 8 criteria
    - Rows: §2 2.3, 2.4; §3.1 3.1.4
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Probe JKn. Build the `survey` design on the `jkn` fixture at seed 15 with
       `rscales` set to one value per replicate, all `1`, and no `scale`. Confirm
       the call raises no warning and that `sv$scale` reads `1`. Build the same
       design again with no `rscales` and confirm `survey` refuses it. That
       refusal is why this is the one block that supplies the argument.
    2. Probe the gap. Compute both standard errors and their ratio. Confirm
       `0.240186788963527` against `0.2464264459334`, a ratio of
       `0.974679434480991`, against `sqrt(19 / 20) = 0.974679434480896`.
    3. Add one new section header at the end of the file, reading
       `# Block 24: Oracle blocks for the remaining replicate types`. Renumber no
       existing header.
    4. Write the JKn block under it. Build both sides from the same fixture, the
       same weight column, the same replicate columns and the same explicit
       `mse`. Write the `rscales` literal twice, once per side. Read no value off
       either design and pass it to the other.
    5. Assert the point estimate bare. Assert `survey`'s stored scale against `1`
       bare, with its comment. Assert the ratio of the two standard errors
       against `sqrt((R - 1) / R)` bare. Put the standard error, the lower bound
       and the upper bound each in its own `testthat::expect_failure()` wrapper —
       three wrappers, one assertion each. Keep the design-building call and the
       no-warning assertion outside every wrapper, because a warning raised
       inside a wrapper escapes it.
    6. Write the block comment: it names issue #253 and states that PR 3 of the
       arc deletes four lines — the three wrapper lines and the ratio assertion.
    7. Title the block so it names the disagreement and issue #253. A title of
       the form "X matches Y" asserts the opposite of what the block proves.
    8. Run the single file. Confirm 0 failures and that the block passes. Run the
       full suite and `air format --check`.
  - **Acceptance criteria**
    1. The file carries a block for `type = "JKn"` under a new
       `# Block 24: Oracle blocks for the remaining replicate types` header at
       the end of the file, and no existing `# Block N:` header changed number.
    2. The block passes the same `rscales` literal to both sides, written out
       twice, and reads neither copy off a design (row 2.4).
    3. Exactly one `survey::svrepdesign()` call in the file receives an `rscales`
       argument, and it is in the JKn block. The pre-existing `rscales =` hit in
       the block that compares two surveycore constructors is unchanged
       (row 2.3).
    4. The block asserts that its design-building call raises no warning, and
       asserts `survey`'s stored scale against `1` at `1e-8` (row 3.1.4). That
       assertion carries its one-line comment above it, and the comment says all
       three things: it guards `survey`'s own default; a failure there means
       `survey` changed and not that surveycore regressed; and the tolerance is
       the standard-error and variance row.
    5. The block carries three `testthat::expect_failure()` wrappers, one
       assertion each, round the standard error and the two bounds. The point
       estimate, the stored scale, the ratio assertion, the design-building call
       and the no-warning assertion all sit outside every wrapper.
    6. The block carries one unwrapped assertion of the standard-error ratio
       against `sqrt((R - 1) / R)` at `1e-8`, and it passes.
    7. The block comment names issue #253 and says PR 3 deletes four lines. The
       block title names the disagreement, names issue #253 and claims no match
       (`spec.md` §V.4; row 2.23 as corrected reads all three titles at PR 8). A
       title that names the disagreement and drops the issue number fails this
       criterion.
    8. The file runs with 0 failures. The diff lists
       `tests/testthat/test-variance-replicate.R` and no other file.
       `air format --check` passes.
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 6: `test/replicate-oracle-bootstrap`** — add the bootstrap oracle
      block, pinned in the same shape, and prove the shape holds in both pinned
      blocks.
  - **Budget** — 10 test-spec rows | 8 criteria
    - Rows: §2 2.9, 2.10, 2.11, 2.15, 2.16; §3.1 3.1.5; §3.6 3.6.1, 3.6.2,
      3.6.3, 3.6.4
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Probe bootstrap. Build the `survey` design on the `bootstrap` fixture at
       seed 15 with no `scale` and no `rscales`. Confirm the call raises no
       warning and that `sv$scale` reads `1 / (R - 1)` at `R = 20`. Do not pass
       `bootstrap.average`; surveycore has no equivalent.
    2. Probe the gap. Confirm `0.0551026284560812` against
       `0.0565341039389252`, a ratio of `0.974679434480991`, the same factor the
       JKn block carries.
    3. Write the bootstrap block under the `# Block 24:` header, after the JKn
       block.
    4. Give it the shape of the JKn block: a bare point estimate, a bare
       stored-scale assertion with its comment, a bare ratio assertion against
       `sqrt((R - 1) / R)`, three wrappers with one assertion each, and the
       design-building call and no-warning assertion outside every wrapper.
    5. Write the block comment naming issue #253 and the four lines PR 3 deletes.
       Title the block so it names the disagreement, names issue #253 and claims
       no match. `spec.md` §V.5 requires the issue number in the title.
    6. Run the single file. Confirm 0 failures.
    7. Count the wrappers in each pinned block and confirm three and three.
       Count the ratio assertions and confirm one and one. Confirm each ratio
       assertion sits outside every wrapper. Run the full suite and
       `air format --check`.
  - **Acceptance criteria**
    1. The file carries a bootstrap block after the JKn block under the
       `# Block 24:` header. It asserts that no warning fires and asserts
       `survey`'s stored scale against `1 / (R - 1)` at `1e-8` (row 3.1.5). That
       assertion carries its one-line comment above it, and the comment says all
       three things: it guards `survey`'s own default; a failure there means
       `survey` changed and not that surveycore regressed; and the tolerance is
       the standard-error and variance row.
    2. The JKn block and the bootstrap block each carry exactly three
       `testthat::expect_failure()` wrappers, each holding exactly one assertion
       (row 2.9).
    3. The point-estimate assertion in each pinned block sits outside every
       wrapper (row 2.10).
    4. The design-building call and its condition assertion in each pinned block
       sit outside every wrapper (row 2.11).
    5. Each pinned block carries exactly one unwrapped assertion of the two
       standard errors as a ratio against the literal `sqrt((R - 1) / R)`, with
       `R` read from the selected columns, at tolerance `1e-8` (rows 2.15, 3.6.1,
       3.6.2, 3.6.3, 3.6.4).
    6. The comment in each pinned block names issue #253 and says PR 3 of the arc
       deletes four lines (row 2.16).
    7. The bootstrap block title names the disagreement and issue #253 and claims
       no match.
    8. The file runs with 0 failures. The diff lists
       `tests/testthat/test-variance-replicate.R` and no other file.
       `air format --check` passes.
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 7: `test/replicate-oracle-other`** — add the `other` oracle block,
      completing the eight numerical types, and measure the sensitivity probe.
  - **Budget** — 6 test-spec rows | 8 criteria
    - Rows: §2 2.17, 2.18; §3.1 3.1.8; §4 4.1, 4.2, 4.3
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Probe `other`. Build the `survey` design with `type = "other"` on the
       `jk1` fixture at seed 15, with neither `scale` nor `rscales`. Confirm one
       warning, whose message contains
       `scale or rscales not specified, set to 1`, and that `sv$scale` reads `1`.
       Supplying either argument silences the warning and restores the round trip
       this work removes, so supply neither.
    2. Probe the agreement. Compare all four quantities on this fixture. Expect
       the point estimate to match exactly, the standard error to differ by about
       `2.4e-14` and each bound by about `5.0e-14`.
    3. Write the `other` block under the `# Block 24:` header, after the
       bootstrap block. Assert the warning by the fragment, assert the warning
       count, assert the four quantities, and assert `survey`'s stored scale
       against `1` with its comment. The block carries no
       `expect_failure()` wrapper.
    4. Run the single file. Confirm 0 failures.
    5. Run the sensitivity probe in a scratch script, outside the package. For
       each of the eight numerical types, build the surveycore design the way its
       block does, overwrite the design's stored scale with twice its value, and
       recompute the mean with its standard error and both bounds. Record the
       three differences per type.
    6. Count the stored-scale assertions and their comments in the file. Confirm
       13 of each. Read all 13 comments and confirm each one carries the three
       elements `spec.md` §IV.3 requires: the guard on `survey`'s default, the
       reading of a failure, and the named tolerance row. Confirm the JK1, JK2
       and `other` blocks each assert a warning count. Run the full suite and
       `air format --check`.
  - **Acceptance criteria**
    1. The file carries a block for `type = "other"` after the bootstrap block,
       and it asserts exactly one warning whose message contains
       `scale or rscales not specified, set to 1` (row 3.1.8).
    2. The block asserts the point estimate at `1e-10`, the standard error at
       `1e-8`, both bounds at `1e-6`, and `survey`'s stored scale against `1` at
       `1e-8`. The stored-scale assertion carries its one-line comment above it,
       and the comment says all three things: it guards `survey`'s own default; a
       failure there means `survey` changed and not that surveycore regressed;
       and the tolerance is the standard-error and variance row. The block
       carries no wrapper.
    3. The three blocks that match a warning message — JK1, JK2 and `other` —
       each also assert that the design-building call raises exactly one warning,
       3 of 3 (row 2.17).
    4. Every assertion of `survey`'s stored scale in the file carries its
       comment, 13 of 13, and every one of the 13 comments says all three
       things: it guards `survey`'s own default; a failure there means `survey`
       changed and not that surveycore regressed; and the tolerance is the
       standard-error and variance row, so a later editor does not widen it. A
       comment with two of the three fails this criterion (row 2.18).
    5. On all eight numerical types, doubling the stored scale leaves the point
       estimate identical; the difference is `0` (row 4.1).
    6. On all eight, doubling the stored scale changes the standard error by a
       factor of `sqrt(2)`, far above `1e-8` (row 4.2).
    7. On all eight, both confidence bounds move by far more than `1e-6`
       (row 4.3).
    8. The file runs with 0 failures. The diff lists
       `tests/testthat/test-variance-replicate.R` and no other file.
       `air format --check` passes.
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 8: `test/replicate-oracle-fay`** — add the Fay refusal block, the last
      of the four, and confirm the whole-file structural properties.
  - **Budget** — 10 test-spec rows | 8 criteria
    - Rows: §2 2.1, 2.6, 2.7, 2.8, 2.12, 2.20, 2.21, 2.22, 2.23; §3.1 3.1.9
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Probe the refusal. Call `survey::svrepdesign()` on the `fay` fixture at
       seed 15 with `type = "Fay"` and no `rho`. Capture the error and confirm
       the message contains `With type='Fay' you must supply the correct rho`.
       The error is a bare `stop()`, so match the text.
    2. Probe the surveycore side. Build the design on the same columns with
       `type = "Fay"` and nothing else supplied. Read the stored scale back and
       confirm `1 / R`, which is `0.1` at `R = 10`.
    3. Write the Fay block last under the `# Block 24:` header. It compares
       nothing. Assert the refusal by the message fragment, and assert the
       surveycore stored scale against `1 / R`.
    4. Write the block comment. It states three things: issue #243 owns the gap
       and PR 4 of the arc rewrites this block into a real comparison; half the
       block asserts what another package refuses to do, and that half guards
       `survey`'s behaviour; a failure on the refusal half most likely means
       `survey` changed its message or dropped the requirement.
    5. Title the block so it names the refusal and claims no match.
    6. Run the single file. Confirm 0 failures.
    7. Grep the finished file and record five figures: the count of
       `skip_if_not_installed("survey")` hits against the count of blocks that
       call `survey`; the replicate types with at least one oracle block; the
       order of the four new blocks under the `# Block 24:` header; the estimator
       in each of the four new blocks; and the three titles that claim no match,
       noting which of them name issue #253. Expect the JKn and bootstrap titles
       to name it and the Fay title not to.
    8. Read the file once for the round trip: no block passes a value read off
       one design into the other, no block asserts one side's stored scale
       against the other's, and no shared helper builds both sides. Run the full
       suite and `air format --check`.
  - **Acceptance criteria**
    1. The file carries a Fay block last under the `# Block 24:` header. It
       asserts an error whose message contains
       `With type='Fay' you must supply the correct rho`, and a surveycore stored
       scale of `1 / R`, which is `0.1` at `R = 10` (row 3.1.9).
    2. The Fay block carries a comment naming issue #243, saying the refusal half
       guards `survey`'s behaviour, and saying a failure there most likely means
       `survey` changed (row 2.12).
    3. All nine replicate types have at least one oracle block in the file, 9 of
       9: BRR, JK1, JK2, JKn, bootstrap, ACS, successive-difference, other, Fay
       (row 2.1).
    4. Every block that builds a `survey` design asserts a condition — a message
       fragment where `survey` raises one, the absence of a warning where it does
       not (row 2.7).
    5. Every `skip_if_not_installed("survey")` hit sits inside a `test_that()`
       body, and the hit count equals the count of blocks that call `survey`
       (row 2.8).
    6. No block passes a value read off one design into the other, and no block
       asserts one side's stored scale against the other side's. No file-level or
       `helper-*.R` function returns both designs (rows 2.6, 2.20).
    7. The four new blocks sit under one `# Block 24:` header in the order JKn,
       bootstrap, `other`, Fay; each estimates the mean of `y1` with
       `get_means()` on one side and `survey::svymean(~y1, ...)` on the other;
       the JKn, bootstrap and Fay titles claim no match with `survey`, 3 of 3;
       and the JKn and bootstrap titles also name issue #253, 2 of 2. The Fay
       title names the refusal and no issue number; `spec.md` §V.9 asks for none
       there, and #243 sits in the Fay comment, which criterion 2 covers
       (rows 2.21, 2.22, 2.23).
    8. The file runs with 0 failures. The diff lists
       `tests/testthat/test-variance-replicate.R` and no other file.
       `air format --check` passes.
  - **Files touched** — `tests/testthat/test-variance-replicate.R`
  - **Pipeline tier**: recommended

- [x] **PR 9: `docs/oracle-rule-exceptions`** — record the two sanctioned
      exceptions in the rule, and validate the finished file.
  - **Budget** — 8 test-spec rows | 8 criteria
    - Rows: §3.5 3.5.1, 3.5.2, 3.5.3, 3.5.4, 3.5.5, 3.5.6; §6 6.10, 6.15
    - The entry sits inside the row bound of 12 and at the criteria bound of 8.
  - **Tasks**
    1. Append the sanctioned-exceptions subsection from `spec.md` §III.2 to the
       rule section: the JKn and bootstrap blocks that wrap three failing
       assertions, closed by issue #253; the Fay block that compares nothing,
       closed by issue #243; and the sentence that anything else which breaks the
       shape is a violation.
    2. Read the whole rule section back. Confirm it records no exact expectation
       total and no run time. Issue #215 forbids both, because they go stale
       within a few merges.
    3. Confirm the three blocks the subsection describes exist on disk with the
       titles it uses.
    4. Run the single test file with `survey` installed. Record the failure count
       and the skip count.
    5. Run the single test file with `survey` unreachable on the library path.
       Record which blocks skip and whether anything fails.
    6. Count the `test_that()` blocks in the file, and count the replicate types
       with at least one oracle block.
    7. Run the full suite. Compare the warning set against the base branch. The
       pre-existing warning in the correlation block for a domain with fewer than
       two paired observations stays, and it touches no oracle block.
    8. Run `air format --check` and `git diff --name-only`.
  - **Acceptance criteria**
    1. The rule section carries a subsection naming the two sanctioned
       exceptions with the issues that close them — the JKn and bootstrap
       wrappers with issue #253, the Fay block that compares nothing with issue
       #243 — and says anything else that breaks the shape is a violation
       (row 6.15).
    2. The rule section records no exact expectation total and no run time
       (row 6.10).
    3. `tests/testthat/test-variance-replicate.R` runs with 0 failures and 0
       skips when `survey` is installed (row 3.5.1).
    4. The file holds 28 `test_that()` blocks: the 24 it held before the arc,
       plus the four new ones (row 3.5.2).
    5. Nine replicate types have at least one oracle block, 9 of 9 (row 3.5.3).
    6. With `survey` absent, every block that calls `survey` skips and nothing
       fails (row 3.5.4).
    7. The file's own run raises no new warning. The one pre-existing correlation
       warning stays and is reported, not fixed. No no-warning assertion fires;
       if one does, the seed and the full warning text are reported, because the
       fixture moved and not the assertion (rows 3.5.5, 3.5.6).
    8. `git diff --name-only` lists `.claude/rules/testing-surveycore.md` and no
       other file. `air format --check` passes.
  - **Files touched** — `.claude/rules/testing-surveycore.md`
  - **Pipeline tier**: recommended

---

## Row allocation — all 72 rows

| Row | PR | Why this PR |
|---|--:|---|
| 2.1 | 8 | Nine types need the Fay block, which PR 8 adds. |
| 2.2 | 4 | The JK1 block is the only `scale =` site on a `survey` design. |
| 2.3 | 5 | The JKn block is the only `rscales` site on a `survey` design. |
| 2.4 | 5 | The row reads the JKn block only. |
| 2.5 | 4 | Both `suppressWarnings()` sites are in the JK1 and JK2 blocks. |
| 2.6 | 8 | Whole-file property; PR 8 is the last PR to write the file. |
| 2.7 | 8 | The Fay block is the last block that builds a `survey` design. |
| 2.8 | 8 | The skip-guard count matches the block count only when all 14 exist. |
| 2.9 | 6 | Reads both pinned blocks, "3 and 3". |
| 2.10 | 6 | Reads both pinned blocks. |
| 2.11 | 6 | Reads both pinned blocks. |
| 2.12 | 8 | The Fay comment. |
| 2.13 | 3 | First PR with a test-file diff; every later PR repeats the check. |
| 2.14 | 3 | Same as 2.13. |
| 2.15 | 6 | Reads both pinned blocks, "1 and 1". |
| 2.16 | 6 | Reads both pinned-block comments. |
| 2.17 | 7 | The third fragment-matching block is `other`. |
| 2.18 | 7 | "13 of 13" holds once all 13 numerical blocks exist. |
| 2.19 | 3 | PR 3 adds the one `test_invariants()` call. |
| 2.20 | 8 | Whole-file property; PR 8 writes the file last. |
| 2.21 | 8 | The header holds all four new blocks only after PR 8. |
| 2.22 | 8 | Reads all four new blocks. |
| 2.23 | 8 | Reads the JKn, bootstrap and Fay titles. |
| 2.24 | 3 | PR 3 is the first PR that writes a replicate-count expression; every later PR repeats the check as a standing gate. |
| 2.25 | 4 | The JK1 block body is the only site with the computed-scale lines. |
| 3.1.1 | 3 | The four BRR blocks. |
| 3.1.2 | 4 | The JK1 rewrite. |
| 3.1.3 | 4 | The JK2 rewrite. |
| 3.1.4 | 5 | The JKn block. |
| 3.1.5 | 6 | The bootstrap block. |
| 3.1.6 | 3 | The two ACS blocks. |
| 3.1.7 | 3 | The two successive-difference blocks. |
| 3.1.8 | 7 | The `other` block. |
| 3.1.9 | 8 | The Fay block. |
| 3.5.1 | 9 | Reads the finished file. |
| 3.5.2 | 9 | The 28-block count holds only after PR 8. |
| 3.5.3 | 9 | Reads the finished file. |
| 3.5.4 | 9 | Reads the finished file with `survey` absent. |
| 3.5.5 | 9 | Reads the finished file's warning set. |
| 3.5.6 | 9 | Reads every no-warning assertion at once. |
| 3.6.1 | 6 | "1 and 1" across both pinned blocks. |
| 3.6.2 | 6 | Reads both ratio assertions. |
| 3.6.3 | 6 | Reads both ratio assertions. |
| 3.6.4 | 6 | Reads both ratio assertions. |
| 4.1 | 7 | The probe covers eight numerical types; `other` is the eighth. |
| 4.2 | 7 | Same as 4.1. |
| 4.3 | 7 | Same as 4.1. |
| 5.1 | 4 | The proof needs the rewritten JK1 block on disk. |
| 5.2 | 4 | Same as 5.1. |
| 5.3 | 4 | Same as 5.1; "every other block" is the 24 then in the file. |
| 5.4 | 4 | Same as 5.1. |
| 5.5 | 4 | Same as 5.1. |
| 6.1 | 1 | Rule 1. |
| 6.2 | 1 | Rule 2. |
| 6.3 | 1 | Rule 3. |
| 6.4 | 1 | Rule 4. |
| 6.5 | 1 | Rule 5. |
| 6.6 | 1 | The message-text constraint. |
| 6.7 | 2 | Sits in the "What the rule covers" subsection. |
| 6.8 | 1 | The Quick Reference row. |
| 6.9 | 2 | The per-type evidence table. |
| 6.10 | 9 | Reads the finished section. |
| 6.11 | 1 | The scope paragraph. |
| 6.12 | 2 | The conversion carve-out. |
| 6.13 | 2 | The snapshot paragraph. |
| 6.14 | 2 | The version-check sentence. |
| 6.15 | 9 | Names blocks that exist only after PR 8. |
| 6.16 | 1 | The argument-versus-literal bullet. |
| 6.17 | 2 | Pairs with 6.12; every later PR repeats the check. |
| 6.18 | 1 | PR 1 writes the heading and places the section. |
| 6.19 | 1 | The third of the three further constraints. |
| 6.20 | 1 | Rule 4's precondition paragraph. |

---

## Spec quality gates against the PR map

`spec.md` §VIII lists 18 gates. Four are standing gates on every PR. The rest
land at one PR.

| Gate | PR |
|--:|---|
| 1 nine types have a block | 8 |
| 2 no `scale` to `svrepdesign()` | 4 |
| 3 one `rscales`, in JKn | 5 |
| 4 no `suppressWarnings()` | 4 |
| 5 no value read off one design into the other | 8 |
| 6 every block asserts a condition; three assert the count | 7, 8 |
| 7 five assertions per numerical block, with the comment | 7 |
| 8 three wrappers, one ratio assertion, the #253 comment | 6 |
| 9 the Fay comment | 8 |
| 10 the rule section, the table and the Quick Reference row | 1, 2, 9 |
| 11 the full suite passes | standing |
| 12 the diff lists exactly two files | standing, read per PR |
| 13 `air format --check` | standing |
| 14 the skip guard inside every block | 8 |
| 15 `test_invariants(` exactly once | 3, then standing |
| 16 28 `test_that()` blocks | 9 |
| 17 three titles claim no match | 8 |
| 18 `test-conversion.R` unchanged | 2, then standing |

Two items gate 10 does not list. `spec.md` §VIII gate 10 enumerates what the
rule section must carry and omits two things `spec.md` §III.2 ships: the "never
assert one side's stored scale against the other side's" bullet and rule 4's
confidence-bound precondition. §IV says §III.2 governs, so the omission costs
nothing, and the builder ships §III.2's text with formatting changes only.
Rows 6.19 and 6.20 close the checking gap, and both land at PR 1.
`decisions.md` records the reasoning.

---

## Budget summary

| PR | Rows | Bound 12 | Criteria | Bound 8 |
|--:|--:|---|--:|---|
| 1 | 12 | at bound | 7 | inside |
| 2 | 6 | inside | 7 | inside |
| 3 | 7 | inside | 8 | at bound |
| 4 | 10 | inside | 8 | at bound |
| 5 | 3 | inside | 8 | at bound |
| 6 | 10 | inside | 8 | at bound |
| 7 | 6 | inside | 8 | at bound |
| 8 | 10 | inside | 8 | at bound |
| 9 | 8 | inside | 8 | at bound |
| **Total** | **72** | | **70** | |

Every entry sits inside both bounds. No entry is over either one. The criteria
bound binds on seven of the nine entries. The row bound binds on one, PR 1,
which sits at 12 after the three new §6 rows.
`plans/pr-budget-calibration.md` records the same pattern on #273 and
#274: a test-only entry costs about 11 to 14 added lines per row, against 25 to
35 on a source-and-test entry, so a row bound derived from source-heavy PRs sits
well above a test-only PR's real size. Every entry here is test-only or
documentation-only. PR 5 at three rows is the smallest, and #273 shipped at four
rows with no BLOCK.

---

## Signals

No HOLD. Every constraint in the task is consistent with `spec.md` and
`test-spec.md` under one stated reading, and each reading is recorded above:

- the one-PR framing in `spec.md` §I yields to the budget (see §Why the work
  ships as nine PRs);
- the two-file figure in row 2.13 and gate 12 reads per PR as "no third file
  appears" (see §The two-file gate reads per PR);
- the rule text splits three ways rather than having its rows distributed (see
  §The rule text ships in three parts);
- `test-spec.md` gained five rows and two in-place corrections after
  SPEC_READY, on the user's approval. `test-spec.md` §Errata applied after
  SPEC_READY lists them and `decisions.md` records each one. `spec.md` is
  unchanged and remains the source of truth.
