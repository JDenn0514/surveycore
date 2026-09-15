# Decisions — domain-marker-logical

One record per decision. D1 to D3 are the user's calls on the Pass 1 review.
D4 to D16 are the unambiguous resolutions applied in the same pass. D17 comes
from the Pass 2 delta review. D18 to D20 come from the plan review.

---

## D1 — SETTLED — 2026-09-12 — The work ships as three PRs

**Question:** The test surface is 48 rows. The PR budget in
`artifact-schemas.md` is 12 rows per PR. The draft spec committed to one PR.

**Decision:** Split three ways.

| PR | Carries | Test surface |
|---|---|---|
| 1 | The `survey_base` validator, the error class, the row in `plans/error-messages.md`, and the fix to the four existing blocks that break | §1, §2 |
| 2 | `.apply_domain()` resolves `NA` to `FALSE` | §3 |
| 3 | `.restrict_to_domain()` cleanup, the printed domain line, the conversion rows | §4, §5, §6 |

**Why:** The "cannot leave the suite red" argument binds only the existing
blocks to the validator. It does not bind the mask change, the conversion
cleanup, or forty-five test rows. A three-way split puts every PR closest to
the bound.

**Rejected:** One PR with a written exception. No waiver path exists in the
rule today, so that asks the plan reviewer to set aside a documented gate
without process support.

**Consequence:** PR 2 depends on PR 1. PR 3 depends on PR 2, because §4 asserts
the printed line agrees with the count the analysis functions use, and that
count changes in PR 2.

Links: [[D2]], [[D3]].

---

## D2 — SETTLED — 2026-09-12 — Seven invariance rows are cut from §3

**Question:** §3 ran the same `NA`-versus-`FALSE` invariance check across
thirteen functions. Nine of them read the mask through the identical call
`domain_mask <- .apply_domain(design)`, with no `NA`-sensitive logic of their
own before they index.

**Decision:** Cut rows 3.2, 3.3, 3.5, 3.6, 3.7, 3.8 and 3.9 — `get_totals()`,
`get_freqs()`, `get_ratios()`, `get_corr()`, `get_covariance()`,
`get_variance()` and `get_effective_n()`. §3 goes from 15 rows to 8.

**Kept and why:**

- 3.1 `get_means()` — the representative simple consumer.
- 3.4 `get_quantiles()` — the existing-block fixes already touch this file, so
  it earns extra scrutiny.
- 3.10 `get_diffs()`.
- 3.11 `get_t_test()` and 3.12 `get_pairwise()` — both build bespoke mask
  combinations rather than reading the helper's output directly.
- 3.13 `survey_glm()` — the base case every model-fitting function rests on.
- 3.14 and 3.15 — the two rows that name the defect itself.

**Why:** `engineering-preferences.md` §1, DRY, is the stated tiebreaker over
§2, "more tests is better". The seven cut rows exercise no code path the kept
rows do not already exercise.

**What the cut stops catching:** a caller-specific regression where one of the
seven functions reads the raw column in place of the helper. The shared-helper
architecture makes that unlikely.

**Corrected by [[D17]].** This record first said "gate 2 greps for it". Gate 2
matches an assignment to the column, and the regression is a read, so gate 2
never sees it. Gate 13 was added to cover it and was measured. The cut stands;
only its reason changed.

Links: [[D1]].

---

## D3 — SETTLED — 2026-09-12 — Two extra test rows, not four

**Question:** Four findings each asked for one extra row, or for the reasoning
to be recorded in place of a row.

**Decision:** Add two rows. Record the reasoning for the other two.

| Row | Verdict |
|---|---|
| The two-phase printed domain line | **Add.** Goes to §4, PR 3. |
| A two-phase or nonprob accept path | **Add.** Goes to §2, PR 1. |
| `get_anova()` invariance | **Record the reasoning.** `get_anova()` builds its statistics from repeated `survey_glm()` fits, and row 3.13 covers `survey_glm()`. The refit check at `R/glm-anova.R:61` is a same-object `identical()` guard, not a mask consumer. |
| An ordered factor rejection | **Record the reasoning.** The check is generic — `!is.logical(x)` — and five types already establish it. One line goes in the edge-case table naming the rendering, `<ordered/factor>`. No test row. |

**Why the two that were added:** each covers a route no other row reaches. The
two-phase print branch indexes the marker column by the phase-2 mask at
`R/methods-print.R:177`, which the plain branch at line 181 does not do. The
accept path was proved on Taylor and on one replicate row only, so two of the
four concrete classes never saw a passing row.

Links: [[D1]].

---

## D4 — SETTLED — 2026-09-12 — A fourth existing block joins the change list

`tests/testthat/test-conversion.R:3313`, the block "as_svydesign() selects the
same rows for every marker column type", writes integer, double, character and
factor markers in a loop and asserts `expect_no_condition()` on each. Four of
the five iterations abort at `d@data <- df` under the validator.

**Decision:** Rewrite it as E.4. The logical iteration keeps the row-count and
probability assertions. Each non-logical iteration asserts
`surveycore_error_domain_not_logical` at the write. Rename the block for what
it now asserts. Ships in PR 1 with the validator.

**Also corrected:** the test-spec's "Measured, 2026-09-12" note said three
blocks. It says four.

**Why this matters beyond the fix:** the comment above the block states the
premise this work removes — "Nothing in the package guarantees the column is
logical, no validator checks its type." The #245 reversal is wider than issue
#262 records. The issue names only the factor block at `:3357`. The real
reversal is the cross-type coercion contract this loop pins for four types.

**How it was missed:** the orchestrator's sweep filtered the grep output by
the literal type of the right-hand side, so it could not see a write whose
right-hand side is a variable. The orchestrator passed that result to the
planner as measured. Two lenses found it independently, and the orchestrator
then read the block in the source.

---

## D5 — SETTLED — 2026-09-12 — The test-spec names its fixture helpers

§1, §2 and §3 each described a multi-step fixture build and told the builder to
repeat it per block — about thirty blocks in all. The test-spec now names one
helper that returns the A and B fixture pair, and one that sets a marker column
of a named type, and says where each is defined.

**Why:** `engineering-preferences.md` §1 — do not defer a DRY violation to
later.

---

## D6 — SETTLED — 2026-09-12 — The two-phase print branch gets a row

See [[D3]]. `.print_domain_info()` at `R/methods-print.R:170-186` has two
branches, and rows 4.1 to 4.3 exercised only the plain one.

---

## D7 — SETTLED — 2026-09-12 — The `as.logical()` exclusion keeps its scope and loses its reason

The spec said all four `as.logical()` calls in `R/analysis-corr-latent.R`
become no-ops. That holds for lines 1295, 1378 and 1441, which receive
`pair_active`, already a logical vector. It does not hold for line 1776: that
call reads `.corr_latent_pair()`'s own `active_domain` parameter, and the
caller at `R/analysis-corr.R:451` runs `active_domain <- as.numeric(active_mask)`.
The incoming value is numeric, so the call is a real conversion and stays
needed.

**Decision:** all four stay out of scope. The sentence separates line 1776 from
the other three, so a later reader does not delete it as dead code.

---

## D8 — SETTLED — 2026-09-12 — The `test_invariants()` justification names the real gap

The test-spec claimed every file it names "already calls the helper for the
constructors it uses". `tests/testthat/test-s7-classes.R` calls
`test_invariants()` six times, for Taylor and non-probability only. It never
calls it for a replicate or a two-phase design, though it builds both
repeatedly.

**Decision:** correct the justification to name the pre-existing gap. Do not
close the gap in this work — it sits outside the stated write surface.

---

## D9 — SETTLED — 2026-09-12 — The precedent citation moves to row 38

The spec cited row 22 as "the model row for this check". Row 22 is the
`as_survey_twophase()` constructor's own pre-construction check, Layer 3, and
its message uses `{.arg subset}`. Row 38 is the S7-validator analog carrying
the same class, and its message shape matches the new one. Both carry one
`"x"` bullet, so the substantive claim never changed.

---

## D10 — SETTLED — 2026-09-12 — The two-phase accept path gets a row

See [[D3]].

---

## D11 — SETTLED — 2026-09-12 — The reader list separates readers from writers

`R/analysis-t-test.R:314` and `:810` both assign to the marker column. The spec
listed them among five readers, next to a claim that `surveytidy::filter()` is
"the only intended producer". Both cannot hold.

**Decision:** name the two internal writes as writers, and narrow the producer
claim to external producers. The values written are logical, so nothing breaks
under the validator.

---

## D12 — SETTLED — 2026-09-12 — The check tests storage type only

`is.logical()` returns `TRUE` for a one-column logical matrix, and for a
logical vector carrying any class attribute other than `haven_labelled`, which
the `@data` setter strips.

**Decision:** state in the edge-case table that the check tests storage type
only, and accepts any object for which `is.logical()` is `TRUE`. Do not reject
a matrix shape — that widens the contract and needs its own row, and no
current code produces such a column.

---

## D13 — SETTLED — 2026-09-12 — The ordered factor is documented, not tested

See [[D3]]. One line in the edge-case table records that the message renders
`<ordered/factor>`. No test row.

---

## D14 — SETTLED — 2026-09-12 — `get_anova()` gets the transitive argument, not a row

See [[D3]].

---

## D15 — SETTLED — 2026-09-12 — The seventh "not logical" check body stays inline

The codebase carries at least six inline "is this logical, if not abort" blocks
of the same shape. This work adds a seventh.

**Decision:** no change in this work. Inline and explicit matches the house
convention and `engineering-preferences.md` §5. Recorded for a future
consolidation.

**Confirmed, not assumed:** the new validator does not duplicate the two-phase
`subset` check at `R/core-classes.R:800-816`. That check reads a per-instance
column name relevant to one class. The new one reads a fixed constant relevant
to all four. The refusal to copy the check into four subclass validators is the
right call.

---

## D16 — SETTLED — 2026-09-12 — Two findings need no change

- **Row 1.11, the mixed-write case.** The rollback comes from S7's replacement
  semantics, not from this work. A lens confirmed it empirically against a
  minimal S7 class. Extending the fixture stays optional.
- **The error message and the failing call site.** R's own backtrace supplies
  the call context. Two bullets are enough for the developer audience the spec
  names.

---

## Open — one assumption the source does not settle

`survey_base` carries no validator today, so nothing in this package yet proves
S7 runs a parent validator for a subclass. The spec states the contract as the
observable — the abort fires on all four concrete classes — and tells the
builder to raise a HOLD rather than copy the check into four subclass
validators if one body does not deliver it. Rows 1.1 to 1.4 catch it either
way.

Two lenses probed the mechanism against a minimal S7 reproduction and both
report that a parent validator runs on every property write, and that a failed
write leaves the object unchanged. That is evidence from a reproduction, not
from this package's own classes, so the HOLD instruction stays.

---

## D17 — SETTLED — 2026-09-12 — The row cut gets a real gate, added in the same pass

**Found by:** the Pass 2 delta review, as its one REQUIRED finding.

D2 cut seven rows from §3 and justified the cut by saying a quality gate
covers the regression the rows would have caught. That claim was false when it
was written. Gate 2 greps for `SURVEYCORE_DOMAIN_COL]] <-`, which matches an
assignment to the column. The regression in question is a direct **read**:
an analysis function that stops calling `.apply_domain()` and reads the raw
column. A read is not an assignment, so gate 2 never sees it. No other gate
covered it, and no rule file or CI check in the repository did either.

**Decision:** add gate 13, and correct the paragraph in §3 that made the claim.

Gate 13 counts the source files that name the column at all:

```
grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R
```

It must return exactly three files — `R/analysis-helpers.R`,
`R/analysis-t-test.R` and `R/glm-anova.R`. A fourth means an analysis function
now names the column directly. The gate runs on PR 2 and PR 3.

**Measured 2026-09-12 on this branch:** the command returns those three files
and no other. `R/analysis-helpers.R` defines the helper, `R/analysis-t-test.R`
writes the column, and `R/glm-anova.R` compares it against itself. None of the
seven cut functions lives in any of the three, so a regression in one of them
would add a fourth file and fail the gate.

**Why this is recorded rather than folded into D2:** D2 is the user's decision
and it stands. What failed was the reason attached to it. The cut is now
backed by a gate that exists and was measured, in place of one that was
assumed.

Links: [[D2]].

---

## D18 — SETTLED — 2026-09-12 — The zero-row mask gets row 3.9, and it calls the helper directly

**Found by:** the plan review, finding F1.

**The gap:** `spec.md` §`.apply_domain(design)` §Edge cases commits to
`logical(0)` on zero-row design data. §3 held rows 3.1 to 3.8 and none of them
built a zero-row design, so the plan shipped a contract line no row observed.
[[D2]] cut seven rows from §3 and named every one; this case is not among them.

**Decision:** add row 3.9 to §3. PR 3 claims it and goes from 8 rows to 9,
inside the bound of 12.

**Renumbered 2026-09-14 by [[D20]].** The figures above were true when this
decision was taken: the plan ran five PRs and §3 belonged to PR 3, which went
from 8 rows to 9. [[D20]] split PR 1 in two and renumbered the rest, so §3 now
belongs to **PR 4**, `fix/apply-domain-na-mask`. The row count is unchanged at
9. No row moved between sections.

**Why it is not a duplicate of rows 2.6 and 2.7:** those two also build a
zero-row frame, and they assert what the **write** does — whether the type
check fires on a `logical(0)` column and on an `integer(0)` one. Row 3.9 starts
after a write that passed and asserts what the **mask helper returns** from the
stored column. Two functions, two acts, one shared fixture shape.

**The block calls `.apply_domain()` directly.** Rows 3.1 to 3.8 reach the
helper through a public analysis function, which is the house default
(`.claude/rules/testing-standards.md`). This row does not: an analysis call on
a zero-row design can raise for reasons of its own, and no public route
isolates the mask's length from those reasons. The rule allows a direct test
when the public API cannot close the gap and the behaviour is material, and
both hold here.

Links: [[D2]].

---

## D19 — SETTLED — 2026-09-12 — The `haven_labelled` accept path gets row 2.9, built inline

**Found by:** the plan review, finding F2.

**The gap:** `spec.md` §`survey_base` validator §Edge cases commits to a
`haven_labelled` column over a logical base passing, because the `@data` setter
strips the class before the validator reads the column. No row anywhere tested
the setter and the new validator together. [[D12]] names `haven_labelled` once,
in passing, as the one class attribute the setter strips; it settles the matrix
case and not this one.

**Decision:** add row 2.9 to §2 as an accept-path row. It asserts two things:
the write raises no `surveycore_error_domain_not_logical`, and the stored
column reads back as a plain logical vector with the class gone. PR 1 claims it
and goes from 11 rows to 12, which is the bound.

**Renumbered 2026-09-14 by [[D20]].** The figures above were true when this
decision was taken: the plan ran five PRs, PR 1 held every §2 accept row, and
row 2.9 took it from 11 rows to 12. [[D20]] moved the accept rows out of PR 1,
so row 2.9 now belongs to **PR 2**, `test/domain-marker-accept-path`, which
holds 4 rows. PR 1 holds 8. The row itself is unchanged.

**The column is built in the block, not by the fixture helper.**
`set_domain_marker(design, type, mask)` takes six named types and
`haven_labelled` is not one of them. Two routes were open: add a seventh type,
or build the column in the block and hand it to the helper as `mask` with
`type` `"logical"`, the path that writes `mask` as given, attributes and all.
The second route wins. `.claude/rules/testing-standards.md` says edge-case data
is built in the test and never added as a parameter of a data generator, and
row 2.5 already carries its `label` attribute through that same path. The
helper gains no type and no argument.

**`haven` is in Suggests**, so the block calls `skip_if_not_installed("haven")`
inside itself, per `.claude/rules/testing-surveycore.md`.

Links: [[D12]].

---

## D20 — SETTLED — 2026-09-12 — PR 1 splits in two, and the plan runs six PRs

**Found by:** the plan review's F3 rewrite, which unbundled PR 1's acceptance
criteria and left the entry over the bound.

**The figure that triggered it:** PR 1 held **9 acceptance criteria against a
bound of 8**, after the plan review's finding F3 unbundled its first criterion.
Its row figure was inside the bound, at 12 of 12.

**Why no fold reached 8:** PR 1 held four test-row claims — the reject set
(1.1–1.4), the accept set (2.1–2.3 and 2.9), the stripped class on 2.9, and the
four repaired blocks — plus the `test_invariants()` count, gate 3, gate 4, the
`NEWS.md` entry, and one line already holding every routine gate. F3 forbids
re-bundling to fit, and `artifact-schemas.md` §PR budget says a PR past either
bound splits before the plan reaches PLAN_READY.

**Decision:** split PR 1 by its acceptance criteria, per the Stage 3 procedure
in `.claude/skills/pipeline-implement/SKILL.md`.

| New PR | Branch | Rows | Criteria |
|---|---|---|---|
| 1 | `fix/domain-marker-validator` | §1 1.1–1.4, §Existing blocks E.1–E.4 | 8 |
| 2 | `test/domain-marker-accept-path` | §2 2.1–2.3, 2.9 | 5 |

PRs 2 to 5 renumber to 3 to 6. Every row keeps the same section and number, and
the total stays at 46.

**PR 2 runs before PR 3.** Both are test-only and both write
`tests/testthat/test-s7-classes.R`, in sequence. PR 2 first completes the
validator's contract next to PR 1, and it lets PR 3 place rows 2.4 to 2.8
between 2.3 and 2.9, which leaves §2 in ascending order in the file.

**Confirmed before the split, not assumed:** PR 1 ships a reject-path check and
now claims no §2 row, so the question is whether anything in it still proves
the validator accepts a legal column. It does. Rows E.1, E.2 and E.4 each write
a logical marker column and then assert something that only runs if the write
completes — `test-spec.md` §Existing blocks that change states all three. A
validator that rejected a logical column fails those three blocks and gate 7
catches it inside PR 1. The plan records the reading under §Where PR 1's accept
path is proved, so a later reader does not read the missing §2 rows as a gap.

Links: [[D1]], [[D19]].

---

## Carry-forward to PR 5 — 2026-09-14 — a stale comment the validator's arrival falsified

**Found by:** the PR 1 reviewer, as its one carried finding.

`tests/testthat/test-conversion.R:3296` still reads:

> as.logical() is what makes the claim hold for a marker column that is not
> logical; a character column raised an unclassed base error without it.

The validator PR 1 ships makes that false. A character marker column cannot be
built at all now, so no conversion route ever sees one, and `as.logical()` is
not what makes the claim hold.

**Why PR 1 left it:** the block is not one of the four E-rows, and it writes no
marker column, so gate 3 does not reach it. Editing it would have put PR 1
outside its stated write surface.

**Where it goes:** PR 5. That entry already rewrites the design note above
`.restrict_to_domain()` in `R/methods-conversion.R` for the same reason — the
note states a premise the validator deletes. This comment is the same act in
the test file, and PR 5 already owns `tests/testthat/test-conversion.R`.

**Note for PR 5's builder:** PR 5 acceptance criterion 7 greps `R/` for the
phrase "no validator checks its type". That grep does not reach this comment,
which lives in `tests/` and uses different words. Fix it by reading the block,
not by trusting the grep.

---

## D21 — SETTLED — 2026-09-14 — covr cannot see inside an S7 `validator =` closure, so `codecov/patch` reads red and the arc merges anyway

**Found by:** the PR 1 gate run, then adjudicated by the PR 1 reviewer and
confirmed empirically by the orchestrator.

**What covr reports.** On PR 1's tree, `covr` marks every line of the new
`survey_base` validator body as uncovered — `R/core-classes.R` lines 348, 349,
355, 356, 357 and 372 — while rows 1.1 to 1.4 assert the abort fires on all
four concrete design classes and all four pass. Package coverage read 96.14%
against a 96.25% baseline. `codecov/patch` failed on PR #272 as a result.

**The control that settles it.** Line 709 also reads uncovered and sits outside
both of PR 1's diff hunks, so this PR did not touch it. It is
`if (!is.numeric(wt_col))`, the guard on
`surveycore_error_weights_not_numeric` inside `survey_taylor`'s own validator.
**Nine tests in `tests/testthat/` assert that error class and all nine pass.**
Pre-existing code, demonstrably executed, reported as uncovered. The common
factor is the `validator =` closure, not the age of the code and not the tests.

covr therefore does not attribute execution inside an S7 `validator =`
closure. The 0% patch figure is a measurement artifact.

**Decision (user, 2026-09-14):** merge PR 1 with `codecov/patch` red, and
record the mechanism here so no later PR re-investigates it.

Three reasons the merge is safe:

- `codecov/patch` is not a required check. Branch protection on `develop`
  requires exactly one context, `ubuntu-latest (release)`, and it passed.
  `mergeStateStatus` read `UNSTABLE`, which is mergeable.
- The behaviour is tested. The abort is asserted on all four concrete classes
  by typed-class expectations, which is the contract `spec.md` §Class and
  design support states.
- The 95% floor that governs this arc is met. Plan PR 1 criterion 8 asks for
  "at or above 95%"; the measured 96.14% clears it.

**Two rejected repairs.** `# nocov` on the validator body was rejected: it
needs an edit to `R/core-classes.R` outside PR 1's reviewed tree, forcing a
fresh gate run and audit, and `.claude/rules/testing-standards.md` allows
`# nocov` only for branches unreachable via the public API — this one is
reachable and reached. A `codecov.yml` change was rejected as outside this
arc's write surface; it belongs in its own chore PR if anyone wants the badge
green.

**What later PRs should expect.** PR 4 (`R/analysis-helpers.R`) and PR 5
(`R/methods-conversion.R`) change ordinary function bodies, not validator
closures, so covr should see their lines normally. Any PR that adds or edits a
validator body will show the same red `codecov/patch`. That is this artifact,
not a regression, and it needs no new investigation.

**Process finding, recorded not acted on.** PR 1's tester justified the 0.11
point coverage dip against a "0.5pp HOLD trigger". No such threshold exists in
any reference file. `r-package-profile.md` gate 7 says "HOLD if 95–98% and
dropped vs baseline"; the plan's criterion says "at or above 95%". The reviewer
ruled the plan criterion governs the PR verdict and gate 7 governs tester
routing, and did not let the invented number change the verdict.

---

## D22 — SETTLED — 2026-09-14 — `run-gates.sh` scopes changed files against the LOCAL `develop` ref, which is stale in a worktree

**Found by:** the orchestrator, on PR 2's gate run.

**The symptom.** PR 2 changes exactly one file, `tests/testthat/test-s7-classes.R`.
Its coverage gate nonetheless reported `changed R/ files: 1, uncovered lines in
them: 7`, naming `R/core-classes.R` and the same seven lines as PR 1.

**The cause.** `.claude/scripts/run-gates.sh` gate 7 computes the changed set as:

```
git diff --name-only develop...HEAD -- 'R/*.R'
```

`develop` there is the LOCAL branch ref. This arc runs from a git worktree, and
`develop` is checked out in a different worktree (`C:\Users\jdennen\surveycore`).
A worktree session only ever fetches `origin/develop`, so the local `develop`
ref never advances. Measured on PR 2:

| Ref | Commit |
|---|---|
| local `develop` | `8fe3fa2` — the arc's starting point |
| `origin/develop` | `5b05a8c` — with PR 1 merged |

So the script compared against the pre-PR-1 tree and charged PR 1's
`R/core-classes.R` diff to PR 2.

**What it does and does not affect.**

- The package coverage percentage is unaffected. It is measured package-wide and
  never reads the changed set. PR 2's 96.14% is a real figure.
- The PASS/FAIL verdict is unaffected. The gate compares the package total
  against the 95% floor.
- The `changed R/ files` and `UNCOVERED_LINE` columns ARE wrong. They report the
  cumulative arc diff since `8fe3fa2`, not the PR's own diff.

**Decision:** do not repair the local ref. `git update-ref` or `git branch -f` on
a branch checked out in another worktree leaves that worktree's index
disagreeing with its HEAD, which is a worse failure than a mis-scoped log
column. Instead, the orchestrator computes the real changed set with
`git diff --name-only origin/develop...HEAD` and hands the tester the corrected
figure with the gate table.

**What later PRs should expect.** Every remaining PR in this arc will show a
changed-R/-file column carrying the whole arc's `R/` diff since `8fe3fa2`. For
PR 3 and PR 6 — both test-only — the correct answer is zero changed `R/` files.
For PR 4 and PR 5 the column will name their own file PLUS
`R/core-classes.R` from PR 1.

**Worth fixing upstream, not here.** The one-word fix is `origin/develop...HEAD`
in gate 7, or deriving the base from the PR's merge base. That edits
`.claude/scripts/run-gates.sh`, which is outside this arc's write surface, so it
belongs in its own chore PR. Logged here so the next reader of a mis-scoped
coverage column does not re-diagnose it.

---

## D23 — SETTLED — 2026-09-15 — `spec.md` never names the six functions §3 fixes, so the builder cannot reach rows 3.1–3.6 from it

PR 4's first build drew a tester BLOCK. Four of its six invariance blocks
covered `get_totals()`, `get_freqs()`, `get_ratios()` and `get_corr()` — four of
the seven functions `test-spec.md` §3 cuts by name under "Six functions, not
thirteen". The four required blocks, `get_diffs()`, `get_t_test()`,
`get_pairwise()` and `survey_glm()`, were absent.

**The builder could not have got this right.** `spec.md` names no analysis
function anywhere. It describes the change as reaching "thirteen call sites"
(lines 113, 119, 326) and stops there. The six kept functions and the seven cut
ones exist only in `test-spec.md`, which the builder is forbidden to read. The
implementation plan's task 2 says "one block per function" and names none.
A builder handed `spec.md` and that task has no way to choose the six.

**Decision:** treat this as an artifact gap, not a builder error, and fix it in
the BLOCK body rather than by relaxing the two-artifact rule. The BLOCK body
states the six names and the reason each earns its place. That keeps the
builder's independence from `test-spec.md` intact — it learns the requirement,
not the test.

**What the two-artifact rule actually requires.** Neither document may reference
the other. It does not follow that `spec.md` may omit a behavioural constant the
builder must hit. Where `test-spec.md` fixes a closed list by name, `spec.md`
has to carry the same list on its own authority, or the list is unreachable.

**Worth fixing upstream, not here.** The repair is one paragraph in `spec.md`
§3 naming the six and the seven. That edit belongs to a spec revision, and this
arc is frozen at PLAN_READY, so it is logged rather than applied. The next
`pipeline-spec` run should add a Stage 3 lens check: every closed list the
test-spec fixes by name appears in the spec too.

---

## D24 — SETTLED — 2026-09-15 — A builder cannot be resumed after its worktree is removed, so every BLOCK cycle needs a fresh builder

`pipeline-ship` §2c says to send the BLOCK body to the SAME builder via
`SendMessage`, so it keeps its context and warm cache, and to dispatch a fresh
builder only if the original is unavailable.

**On this machine the original is always unavailable.** The send failed with
`This agent cannot be resumed: its worktree no longer exists, and the fallback
directory is not covered by the session's isolation fences.` Step 2b removes the
worktree before the tester runs, and resume needs the worktree that removal just
deleted. The two steps contradict each other for any builder dispatched with
`isolation: "worktree"`.

**Decision:** on a BLOCK, dispatch a fresh builder with no worktree, pointed at
the branch already checked out in the main checkout. The fresh builder needs
more in its brief than a resumed one: what is ACCEPTED and must not be touched,
where to work, and that it is a replacement. §2c's "warm cache" saving is not
available here and should not be planned for.

**Cost.** One BLOCK cycle costs a full builder dispatch, not a message. PR 4's
cycle is the first measurement in this arc; the three earlier PRs took none.

**Worth fixing upstream, not here.** Either keep the worktree until the PR
ships, or have the builder work in the main checkout from the start. Both edit
`pipeline-ship`, which is outside this arc's write surface.

---

## HOLD — builder — 2026-09-15 (PR 5, `fix/restrict-to-domain-coercion`)

**Where**: `.restrict_to_domain()` in `R/methods-conversion.R:75-79`; PR 5
scenario 3 and acceptance criterion 2; fixture `make_domain_pair("twophase")`
in `tests/testthat/helper-test-data.R`.

**What**: The domain restriction never runs on a two-phase design built with
`method = "approx"`. `as_svydesign()` returns the full stored sample where the
caller asked for the domain. PR 5's scenario 3 cannot assert what acceptance
criterion 2 states on the fixture the brief names.

**The measurement.** `make_domain_pair("twophase")` calls
`as_survey_twophase(..., method = "approx")`. `survey::twophase(method =
"approx")` returns an object of class `c("twophase", "survey.design")`.
`.restrict_to_domain()` branches on `inherits(converted, "twophase2")`, which
is `FALSE` for that object, so it falls to `converted$variables`. An `approx`
two-phase object carries no `$variables` at all, `names(NULL)` is `NULL`, the
name test fails, and the helper returns the object unrestricted.

On the 200-row fixture, with 149 in-domain rows and 74 phase-2 rows:

| Design | Class | Finite probabilities | Expected |
|---|---|---|---|
| `make_domain_pair("twophase")$a`, `method = "approx"` | `twophase` | 74 | 52 |
| Same frame and marker, `method = "full"` | `twophase2` | 52 | 52 |

52 is `sum(mask & subset)` — in-domain AND in phase 2. The `full` route is
correct. The `approx` route silently reports the full sample.

This also corrects the brief and the frozen planning documents from the other
side. They predicted 52 against 149 for the `approx` fixture. The real
contrast is 74 against 52, and the cause is an unhandled class rather than a
counting question.

**Why I can't decide**: Closing the gap means widening the helper's class test
to `inherits(converted, "twophase2") || inherits(converted, "twophase")`. That
is a behavioural change to a conversion route. PR 5's task list authorises the
`as.logical()` removal and the design note only, and the arc's `spec.md` says
nothing about `method = "approx"`. The archived `as-svydesign-domain` arc that
added the helper tested `method = "full"` alone, so the gap is pre-existing and
was never a decision anyone took.

**Options**:

1. **Widen the class test in this PR.** One line, plus a `NEWS.md` bug-fix
   entry, since it changes a user-visible answer. Costs: a behavioural change
   outside the frozen task list, and `simple` is a third `method` value whose
   converted class I have not measured.
2. **Defer to a new issue.** PR 5 ships the coercion removal as planned.
   `as_svydesign()` keeps reporting the full sample for an `approx` two-phase
   domain until that issue ships.
3. **Change the fixture to `method = "full"`.** Rejected. It hides the defect
   behind a passing test, and `helper-test-data.R` is outside PR 5's write
   surface.

**What I need**: A decision between option 1 and option 2 — fix the `approx`
route in this PR, or open an issue and defer it.

### What PR 5 shipped meanwhile

Commit `ead5691`. The coercion removal, the rewritten design note and all five
scenarios are in and green. Scenario 3 builds its two-phase design from the
fixture's frame and marker with `method = "full"`, so it asserts acceptance
criterion 2 exactly and derives 52 from the fixture. Its comment names the
`approx` gap and points at this HOLD. No assertion pins the defect.

---

## D25 — SETTLED — 2026-09-15 — The `method = "approx"` no-op is deferred to its own PR, not folded into PR 5

PR 5's builder raised a HOLD. `.restrict_to_domain()` in
`R/methods-conversion.R` tests only the `twophase2` class. A two-phase design
built with `method = "approx"` carries class `twophase`, falls to
`converted$variables` — which is `NULL` on both two-phase classes — and returns
unrestricted. `as_svydesign()` on a filtered `approx` design silently returns
the full stored sample.

**Confirmed independently of the builder**, R 4.6.1, Windows, `survey` 4.4-2:

| `method` | class | `$variables` | `phase1$sample$variables` |
|---|---|---|---|
| `"approx"` | `twophase`, `survey.design` | NULL | present |
| `"full"` | `twophase2`, `survey.design` | NULL | present |

On the shipped `make_domain_pair("twophase")` fixture, which uses
`method = "approx"`, the converted object reports 74 finite probabilities. The
same frame and marker at `method = "full"` report 52, the correct
in-domain-and-in-phase-2 count. 74 is the unrestricted phase-2 count.

**Not introduced here.** The class test predates the arc. PR 5 removes an
`as.logical()` coercion from the same function and does not touch it.

**Decision:** open the issue immediately and fix it in a separate small PR after
PR 6, rather than widening PR 5. Three reasons. PR 5 stays inside its five
stated rows and eight criteria, so its tester can audit it against the frozen
test-spec without a row that does not exist there. The fix earns its own test
row, which a widened PR 5 would have carried as unaudited scope. And the arc's
own precedent — the four deferred issues in `archive/as-svydesign-bridge/` —
is to defer out-of-scope findings to numbered issues rather than absorb them.

Issue #276 carries the measurement, the one-line fix and the test row. The fix
copies the shape already at `R/methods-conversion.R:719`, which tests both
classes.

**What PR 5 asserts instead.** Its two-phase scenario builds a `method = "full"`
design from the fixture's frame and marker and asserts the derived count of 52.
It pins the coercion removal and nothing about this defect.

**Correction to the planning documents this supersedes.** The reviewer of PR 4
flagged that `test-spec.md` §5's "`sum(mask)` gives the expected count" is wrong
for row 5.3 and should read `sum(mask & subset)`. That correction stands and is
the count PR 5 asserts. The reviewer's figure of 149 for `sum(mask)` is the
whole in-domain count; neither 149 nor the fixture's own 74 is the right
expectation for a correctly restricted conversion.

---

## D26 — SETTLED — 2026-09-15 — Three of the four §4 rows do not depend on PR 4, and the plan's ordering rationale was wrong

`implementation-plan.md` §Why six PRs and not three ordered PR 6 after PR 4 on
this ground: "The printed-domain rows (PR 6, §4) land after PR 4, which changes
the count they compare against."

**Measured false for three of the four rows.** PR 6's tester ran the rows
against the true pre-#275 `.apply_domain()`. Only row 4.2 breaks. Rows 4.1, 4.3
and 4.4 read the same on either side of PR 4.

**Mechanism**, confirmed in source at `R/methods-print.R:171-186`:
`.print_domain_info()` counts with `sum(col, na.rm = TRUE)` straight off the
marker column. It never calls `.apply_domain()`. PR 4 changed that helper and
nothing the print method reads.

**Not a defect in the tests.** Rows 4.1, 4.3 and 4.4 still constrain the print
method's own `NA` handling — the fixture carries three `NA` markers, and a print
method that mishandled them would report `NA of 200` or 151 rather than 149.
That is a real property. It is not the property the plan named.

**Row 4.2 carries the count-agreement contract alone.** It parses the printed
count out of the output and compares it with the `n` column of an ungrouped
`get_means()`. Neither side derives from the other, so it is a true cross-check
between the print path and the analysis path.

**The obvious hole was checked and is not there.** If the two routes could
disagree anywhere it would be two-phase, where the print method counts phase-2
rows only. `.twophase_mean_cell()` sets `n_d <- sum(domain[subset])`, which is
the same quantity the print method reports, so the two agree by construction
rather than by coincidence.

**Decision:** log it and repair the one sentence, in the shape of D23 and D25.
The PR ships. The ordering it produced was harmless — PR 6 after PR 4 is still
correct for row 4.2, and no row needed a different order.

**The general lesson, for the next plan.** The rationale was written from the
shape of the change rather than from a measurement, and it survived three plan
reviews and a freeze. A dependency claim of the form "B depends on A because A
moves what B measures" is checkable before the build: run B's rows against A's
pre-image. Nobody did until the tester's non-vacuity probe, which found it as a
side effect rather than as its target.
