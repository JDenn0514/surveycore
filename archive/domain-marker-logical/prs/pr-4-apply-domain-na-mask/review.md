# Review — PR 4 — apply-domain-na-mask

**Verdict**: PASS
**Date**: 2026-09-15 15:40, updated 2026-09-15 17:05
**Tree reviewed**: `4d4b21ab31275d1064aa2e3ed47ec0c4c4f60ac1` (commit `627e4dd`, base `8664d86`)
**Superseded tree**: `7bd2712a3248840dd69bf7a8a6bc1b38eb1ac079` (commit `09d97e3`) — the tree this review first read
**BLOCK history**: tester 1 (cleared), reviewer 1 (raised on `7bd2712`, cleared on `4d4b21a` — see §Judgment 1, Resolution)

`627e4dd` moves `NEWS.md` and nothing else. Every finding in this document that
reads on the code, the tests, the fixture, the gates or the eight criteria was
settled on `7bd2712` and stands unchanged: `git diff 09d97e3..627e4dd
--name-only` returns one file, and it is not under `R/` or `tests/`.

---

## Convergence checks

- Spec coverage: **y**. Every clause of `spec.md` §`.apply_domain(design)` has a
  row in the audit's Per-Test Result Table, except the column-absent branch and
  the "no domain column" edge case, which `test-spec.md` §6 assigns to PR 6 and
  the row ledger claims there. No clause of this PR's contract is unclaimed.
- Test coverage of spec: **y**. §3 rows 3.1–3.9 cover the return type, the
  `NA`-to-`FALSE` resolution, the all-`NA` case and the zero-row case.
- Tolerance integrity: **y**. See §Tolerance integrity.
- Scope discipline: **y**. Four files written, four files planned, exact match.
- Regression safety: **y**. `FAIL 0` on both sides, warnings flat at 256, skips
  flat at 4, notes flat at 2, +66 passing expectations, coverage +0.01.
- Comprehension alignment: **not applicable**. Stage 0 was skipped; there is no
  `comprehension.md` [no such file].
- `audit.md` verdict: PASS.

One check is not clean, and it is not one of the six above: the `NEWS.md` entry
this PR ships states a symptom that this PR's own measurements contradict. The
tester audited nine test rows and seven gates and read no `NEWS.md` text; no
agent before me compared that entry against the measured behaviour. Detail in
§Judgment 1.

---

## Tolerance integrity

`test-spec.md` §Tolerances states one rule for §3: use `expect_identical()`, not
a tolerance, and it records that this tightens the default table (1e-10 point,
1e-8 SE, 1e-6 CI).

| Row | Tolerance in test-spec | Tolerance in audit | Verdict |
|---|---|---|---|
| 3.1–3.9 | `expect_identical()` | `expect_identical()` | match |

Read against the source as well as the audit: every assertion in the nine new
blocks is `expect_identical()`, `expect_false()`, or the local helper
`expect_domain_invariance()`, whose body is two `expect_identical()` forms. No
`tolerance =` argument appears anywhere in the diff. No row is looser than the
test-spec. No Tolerance Integrity violation.

---

## Scope discipline

| File | Plan says | Commit holds |
|---|---|---|
| `R/analysis-helpers.R` | yes | modified (16 lines) |
| `tests/testthat/helper-test-data.R` | yes | modified (+103) |
| `tests/testthat/test-analysis-helpers.R` | yes | modified (+124) |
| `NEWS.md` | yes | modified (+7) |

`git diff --stat 8664d86..7bd2712` lists these four and nothing else. No extra
file, no missing file. The `_snaps/` line-ending churn the builder names was
reverted and is not in the commit.

The audit marks no state change outside this PR's rows. The gate table shows
`FAIL 0` before and after, so no test outside scope changed pass/fail state.

---

## The eight acceptance criteria, one at a time

**1. Rows 3.1–3.6: six blocks, one per function, column by column, never two
result objects whole — MET.** Six blocks exist for `get_means()`,
`get_quantiles()`, `get_diffs()`, `get_t_test()`, `get_pairwise()` and
`survey_glm()`. All six route through `expect_domain_invariance()`, whose body
compares `names()` and then one column at a time. Row 3.6 compares
`as.data.frame(summary(fit)$coefficients)` and asserts `rownames()` separately,
so it never reads the fit object. The audit measured that table at 2 by 4 with
no zero-length column, which closes the empty-loop vacuity risk.

**2. Row 3.7: no group value that is not a real level — MET.** The block asserts
`expect_false(anyNA(result$group))`, the level set against
`sort(unique(pair$a@data$group[pair$mask]))`, and `sum(result$n) ==
sum(pair$mask)`. The third assertion is the one that would catch a phantom row
that carried a real level.

**3. Row 3.8: the all-`NA` result is identical to the all-`FALSE` result — MET.**
Column by column, plus `expect_identical(result_na$n, 0L)`.

**4. Row 3.9: `.apply_domain()` on a zero-row design returns `logical(0)` — MET.**
`expect_identical(.apply_domain(design), logical(0))` distinguishes `logical(0)`
from `NULL` and from `TRUE`, which is what the row asks.

**5. `make_domain_pair()` builds all four classes, and the `"twophase"` variant
places at least one `TRUE` marker row outside phase 2 — MET.** The source
switches on all four class names, and it carries an explicit forcing line for
the two-phase case. The audit measured the fixture: 200 rows, 74 in phase 2, 149
in domain, 97 `TRUE` marker rows outside phase 2. See §Judgment 4 for what that
means for PR 5 and PR 6.

**6. Gate 13: three files — MET.** `grep -rln "SURVEYCORE_DOMAIN_COL"
R/analysis-*.R R/glm*.R` returns `R/analysis-helpers.R`, `R/analysis-t-test.R`
and `R/glm-anova.R`, recorded in `implementation.md` §Gate 13 and matching the
measurement `spec.md` gate 13 records for 2026-09-12.

**7. `NEWS.md` holds one entry under `## Bug fixes` in the development version
naming issue #262 — MET as written.** The entry sits under
`# surveycore (development version)` then `## Bug fixes`, and closes with
`(#262)`. The criterion tests placement and presence, and both hold. It does not
test whether the entry is true, and the entry is not. That is the BLOCK, and it
is raised against `spec.md` §NEWS.md rather than against this criterion.

**8. Gates 2, 5–12 and the CRAN cookbook scan — MET**, under the reading stated
in §Judgment 2 for `air format --check`. Gate results on tree `7bd2712`:
`document()` clean and `NAMESPACE` unmoved; `test()` `FAIL 0 | WARN 256 | SKIP 4
| PASS 11891`; `run_examples()` pass; `R CMD build` pass; `R CMD check --as-cran`
0 errors, 0 new warnings, 2 NOTEs, both pre-approved or pre-existing (CRAN
incoming feasibility; the `.git` hidden file that `.Rbuildignore` causes);
`pkgdown` clean; `covr` 96.15%; cookbook scan clean. Gate 2 holds — the only
`R/` write is in `.apply_domain()` and it assigns `FALSE`. Gate 5 is vacuous:
this PR adds no `cli::cli_abort()`.

---

## Coverage

96.15% against a 96.14% baseline. Above the 95% floor, and it rose, so the
95–98% HOLD condition in `r-package-profile.md` gate 7 does not fire. The audit
reads `R/analysis-helpers.R` at 97.26% with uncovered lines 953, 959, 960, 1108
and 1154 — none of them in `.apply_domain()`. The lines this PR adds are
covered. D21's covr artifact does not reach here: this PR edits an ordinary
function body, not an S7 `validator =` closure.

---

## Cross-consistency, implementation.md against audit.md

The two describe the same tree and the same work. Both name tree `7bd2712` and
commit `09d97e3`. Both report nine blocks, the four out-of-scope blocks deleted,
and the four required blocks added. The audit's per-row line numbers (1830,
1838, 1846, 1856, 1874, 1883) fall inside the diff hunk the commit adds.

Three smaller notes, none of them blocking:

1. `implementation.md`'s header still reads `**Commit**: 3ab6318` and
   `**Tree**: 939c70e...`, the superseded pair. The final pair appears only at
   the foot of §BLOCK 1 resolution. A later reader who stops at the header takes
   the wrong tree. Fix it in the same cycle as the `NEWS.md` change.
2. The builder reports the pre-fix failures as `variable lengths differ (found
   for '(weights)')` for the four added blocks. The tester recorded pass/error
   state per block and not the messages, so the red-under-regression claim is
   confirmed at the level that matters (eight of nine go red) and the wording is
   unconfirmed. Recorded, not disputed.
3. The two failures at `test-analysis-helpers.R:1429` and `:1430` are a
   `load_all()` artifact. The `devtools::test()` gate reports `FAIL 0` on this
   tree and names no failure there. Settled.

---

## Judgment 1 — the `NEWS.md` entry describes a symptom nobody measured

**This is the BLOCK.**

The shipped entry:

> A grouped analysis of a filtered design no longer reports a group that no
> in-domain row supports. A domain marker holding `NA` selected a row of all
> `NA` values, which **reached the grouped result as a group combination of its
> own.** Every `get_*()` function now reads an `NA` marker as outside the
> domain, and the numbers agree with a design whose marker stores `FALSE` in
> that place. (#262)

The second sentence is false, and this PR's own artifacts say so. Measured
pre-fix behaviour, from `implementation.md`:

- `get_means()`, `get_totals()`, `get_freqs()`, `get_quantiles()`,
  `get_ratios()` and `get_corr()` each aborted with `missing value where
  TRUE/FALSE needed`, raised by the `if (n_d == 0L || N_d <= 0)` guard inside
  the cell helper, because the phantom row's weight is `NA`.
- `get_diffs()`, `get_t_test()`, `get_pairwise()` and `survey_glm()` aborted
  with `variable lengths differ (found for '(weights)')`.
- The grouped case: "the call does not return at all". The `FALSE`-marker design
  returned three group rows; the `NA`-marker design returned nothing.
- The ungrouped all-`NA` case aborted too.

The tester's independent regression probe agrees: eight of the nine blocks read
**Error** under the pre-fix helper, and none read a wrong number.

Ten function-level measurements and one tester probe, and not one of them shows
a phantom group reaching a result. The phantom group is real inside the call —
it is the cell whose `NA` count trips the guard — but it never reached a user.
What reached the user is an abort.

**So "silently" is wrong too.** Issue #262's title says the functions "silently
report the wrong" values. Nothing measured in this arc is silent, and nothing
measured returns a wrong number. The failure is loud and total. The entry does
not use the word, but it inherits the framing, and a user who hit this bug saw
`Error: missing value where TRUE/FALSE needed` and will not find their symptom
in these release notes.

**Why the builder and not the planner.** `spec.md` §NEWS.md dictates the first
sentence almost verbatim, and that sentence, read alone, is a true statement
about the present. The second sentence is the builder's own, it states a fact,
the fact is wrong, and the builder held the contradicting measurement in the
same document. The spec sentence and the issue title both need correcting too,
but neither edit is available inside a frozen arc, so they are logged below and
the repair lands in the entry.

### BLOCK body — for the builder, self-contained

> **BLOCK — 2026-09-15 15:40 — reviewer**
>
> **What is wrong.** The `NEWS.md` entry you added under `## Bug fixes` says the
> phantom group "reached the grouped result as a group combination of its own".
> Your own red-to-green evidence says it did not: every pre-fix call aborted —
> `missing value where TRUE/FALSE needed` from the six mask-indexing functions,
> `variable lengths differ (found for '(weights)')` from the four model-fitting
> ones — and the grouped call "does not return at all". A user who met this bug
> saw an error, not a wrong number. The entry tells them to look for a wrong
> number.
>
> **What to change.** `NEWS.md` only. Rewrite the entry so it describes the
> symptom you measured: before this change, an analysis of a filtered design
> whose domain marker held `NA` failed rather than returning an estimate, and a
> grouped call failed on the group combination the `NA` row created. Keep the
> entry under `## Bug fixes` in the development version, keep `(#262)`, and keep
> the closing statement that every `get_*()` function now reads an `NA` marker
> as outside the domain and agrees with a design storing `FALSE` there. Claim no
> symptom this arc did not measure — in particular, do not write that a wrong
> number was returned, and do not write "silently".
>
> Also correct the header of `prs/pr-4-apply-domain-na-mask/implementation.md`:
> it still names commit `3ab6318` and tree `939c70e`, which are superseded.
>
> **What must not change.** `R/analysis-helpers.R`,
> `tests/testthat/helper-test-data.R` and
> `tests/testthat/test-analysis-helpers.R` are ACCEPTED as they stand on commit
> `09d97e3`. Do not touch them. Do not add or delete a test block. The nine
> blocks, the fixture and the `.apply_domain()` body all pass review.
>
> **Gates.** The code tree does not move, so the `test()` and `covr` results
> carry forward. `NEWS.md` is in the tarball and pkgdown renders the changelog,
> so `R CMD build`, `R CMD check --as-cran` and `pkgdown::build_site()` need a
> re-run on the new tree. The orchestrator decides how to schedule that under
> the memory watchdog.

### Resolution — cleared on tree `4d4b21a`

The coordinator made the edit inline rather than dispatching a builder. Commit
`627e4dd`, 7 insertions and 6 deletions, `NEWS.md` only. The entry now reads:

> * An analysis of a filtered design whose domain marker holds `NA` no longer
>   fails. The `NA` marker selected a row of `NA` values, and the call then
>   stopped with `missing value where TRUE/FALSE needed`, or with `variable
>   lengths differ`, instead of returning an estimate. A grouped call stopped
>   on the group combination that the `NA` row created. Every `get_*()`
>   function now reads an `NA` marker as outside the domain, and the numbers
>   agree with a design whose marker stores `FALSE` in that place. (#262)

Against the six constraints in the BLOCK body:

| Constraint | Met |
|---|---|
| Describes only the symptom this arc measured | yes — both error strings are the ones `implementation.md` records, one from the six mask-indexing functions and one from the four model-fitting ones |
| Claims no wrong number | yes — the claim is gone; the entry now says the call stopped |
| Does not say "silently" | yes |
| Under `## Bug fixes` in the development version | yes — first bullet of that section, under `# surveycore (development version)` |
| Keeps `(#262)` | yes |
| Keeps the closing agreement statement | yes — carried over word for word |
| Nothing else moves | yes — `git diff 09d97e3..627e4dd --name-only` returns `NEWS.md` alone |

The sentence "A grouped call stopped on the group combination that the `NA` row
created" is the one I read hardest, because it is the sentence closest to the
one I blocked. It is accurate. The phantom group combination is real inside the
call — it is the cell whose `NA` count trips the guard — and the entry now says
the call stopped there, which is what was measured. It no longer says the group
reached the result.

`implementation.md`'s header is corrected too: commit `09d97e3`, tree
`7bd2712…`, each marked as superseding the earlier pair.

**Naming the two error strings is the right call.** A changelog reader who met
this bug has one artifact in hand — the error text — and that text is the only
thing they can search for. The entry is the only document in the package that
will ever carry it. The house NEWS style already names concrete identifiers,
including typed error classes in the neighbouring `polyserial` entry, so this is
consistent and not an escalation of detail. One qualifier for the record, which
changes nothing: both strings come from base R and `stats`, not from surveycore,
so a future R release could reword them. That costs the entry nothing, because
it describes behaviour that is now past.

**The coordinator editing this directly was right.** The BLOCK body was already
the brief, so a builder dispatch would have re-delivered text that existed, and
`decisions.md` D24 records that a BLOCK cycle on this machine costs a full
dispatch rather than a message. The isolation fence is untouched: the fence
keeps the builder away from `test-spec.md`, and the coordinator reads every
artifact by role. The independent check survives, because I verified the result
against the committed tree and not against the report of it.

**The three-gate subset is sufficient. Run nothing more.** The commit touches no
file under `R/` or `tests/`, so `devtools::test()`, `covr` and
`devtools::document()` read the same values they read on `7bd2712` — they have
no input that moved. `NEWS.md` reaches exactly three consumers: the tarball,
`R CMD check --as-cran`, which parses it, and the pkgdown changelog. All three
ran on `4d4b21a` and all three pass, with the same 2 NOTEs. Nothing else can
have moved.

One optional note, not a finding and not a request: the entry's second sentence
runs to about 36 words, over the 25-word bar the house writing standard sets. A
full stop after `variable lengths differ` would split it. Leave it or split it;
either ships.

### Upstream, outside this arc's write surface

1. `spec.md` §NEWS.md, PR 2 bullet: "no longer reports a group that no in-domain
   row supports" states the defect as a wrong report. The measured defect is an
   abort. The arc is frozen at PLAN_READY, so this is a log entry in the shape
   of D23, not an edit.
2. Issue #262's title — "grouped `get_*` functions silently report the wrong"
   values — is contradicted by ten measurements in this arc. The issue should be
   corrected before this PR merges, because the `NEWS.md` entry cites it and a
   reader follows the link.

---

## Judgment 2 — `air format --check` and criterion 8

**Criterion 8 is MET. I applied the "the PR's own files pass" reading, the same
one archived decision D16 applied in `archive/svydesign-replicate-bridge/`.**
Stated plainly, because the literal reading gives the other answer.

The measurement: `R/analysis-helpers.R` passes,
`tests/testthat/test-analysis-helpers.R` passes,
`tests/testthat/helper-test-data.R` **fails — and fails identically at the base
commit `8664d86`**.

Verified without running the formatter: the offending block is
`.hand_polyserial_twostep()`, at line 1448 of the file at `8664d86` and at line
1551 now, shifted by exactly the 103 lines this PR adds. This PR's hunk runs
from line 1130 to line 1236. The two regions do not overlap. The PR did not
create the violation and did not move the offending lines.

Three reasons the strict reading loses:

- `spec.md` gate 12 writes its own carve-out: "Files the PR does not touch are
  out of the gate; some of them are already not air-clean." The gate's stated
  purpose is to stop a PR introducing unformatted code.
- `.claude/rules/code-style.md` says reformat-only commits stay separate from
  functional changes. Repairing `.hand_polyserial_twostep()` inside this PR
  would break that rule to satisfy gate 12.
- D16 read the equivalent gate the same way on a comparable tree.

Not left silent: `tests/testthat/helper-test-data.R` is not air-clean on
`develop` and this PR does not fix it. It wants a `chore:` reformat-only PR of
its own. Nothing in this arc should carry it.

---

## Judgment 3 — deleting four passing blocks was right

The replacement builder deleted correct, passing blocks for `get_totals()`,
`get_freqs()`, `get_ratios()` and `get_corr()`. Against
`engineering-preferences.md` #2, "more tests is better", that reads badly. It is
still right here, for four reasons.

1. **The same file's rule #3 governs the case.** "Engineered enough — not under,
   not over. The current spec determines the right level." `test-spec.md` §3
   "Six functions, not thirteen" is the current spec, and it cuts those four by
   name with a measured argument: all seven cut functions read the mask through
   the same one-line `.apply_domain()` call, none holds `NA`-sensitive logic
   before it indexes, and the six kept rows reach every code path the thirteen
   would.
2. **Coverage confirms the argument rather than resting on it.** The final tree,
   with the four blocks gone, reads 96.15% — above the baseline, not below it —
   and `R/analysis-helpers.R` reads 97.26% with no uncovered line in
   `.apply_domain()`. The deletions cost no line.
3. **Scope discipline is my own check 3.** Blocks asserting behaviour this PR
   does not claim are blocks the audit table cannot trace to a row. Nine rows,
   nine blocks, one-to-one, is what makes this PR auditable.
4. **The trade was recorded, not hidden.** The test-spec names what the cut
   stops catching — a caller-specific regression, where one of the seven stops
   calling the shared helper — and moves that cover to gate 13, a source sweep.

One residual risk, recorded and not blocking: gate 13 is bound to PR 4, PR 5 and
PR 6 in the plan, and to nothing after this arc ships. It is a grep over file
names in a plan document, not a test in the suite. When the arc closes, the
regression the test-spec names goes uncovered. Whoever wants it covered should
open an issue for a test-suite-resident sweep; this PR is not the place.

---

## Judgment 4 — forward coupling to PR 5 and PR 6

`make_domain_pair()` ships here and PRs 5 and 6 read it without editing it. It
supports what they need. One sentence in the test-spec does not, and PR 5's
builder brief has to carry the correction.

**What holds.**

- All four classes build: `"taylor"`, `"replicate"` (BRR, `n_psu = 10`, so five
  replicate columns), `"twophase"` and `"nonprob"`. The tester measured all
  four. Statically, `make_survey_data()` lower-cases `type` and demands an even
  `n_psu`, and 10 is even, so the replicate branch is sound.
- The `"twophase"` variant places `TRUE` markers outside phase 2 — 97 of them,
  measured. PR 6 row 4.4 can therefore tell the two print routes apart: the
  phase-2 route gives 52 and the whole-frame route gives 149.
- PR 6 rows 4.1 and 4.3 need designs A and B to print the same line.
  `.print_domain_info()` counts with `na.rm = TRUE`, so they do.
- PR 6 row 4.2 needs the printed `n` to equal the `n` of an ungrouped
  `get_means()`. For the taylor fixture both are `sum(mask)` once this PR lands.
- PR 5 rows 5.2 and 5.4 (taylor, replicate) remove rows, so the converted row
  count is `sum(pair$mask)`, exactly as the test-spec says.

**What does not hold, and it is a planner error, not a fixture defect.**
`test-spec.md` §5 says: "Rows 5.2 to 5.4 take their `NA` design from
`make_domain_pair()`, one class per row. `sum(mask)` from the same call gives
the expected count." For row 5.3, the two-phase row, `sum(mask)` is the wrong
number. The two-phase route removes no row and gives excluded rows an infinite
probability, so the count that records the restriction is the count of finite
probabilities, and that count is `sum(marker & subset)`. With this fixture it is
52, against `sum(mask) = 149`.

The conflict is inherent to the test-spec, not to the fixture: §4 row 4.4
*requires* `TRUE` markers outside phase 2, and any such fixture makes `sum(mask)`
larger than the finite-probability count. The existing blocks in
`tests/testthat/test-conversion.R` already compute it the right way —
`marked_phase2 <- sum(df[[SURVEYCORE_DOMAIN_COL]] & df$subset)` at lines 3925
and 3943.

The fixture supports the correct computation with no edit: `subset` is a column
of `@data`, so PR 5 writes
`sum(pair$mask & pair$a@data[[pair$a@variables$subset]])`. **PR 5's dispatch
brief must carry this, or PR 5 writes a block that cannot pass and reads the
fixture as the cause.** The `dataset-level-metadata` precedent — a fixture
shipped in one PR and unusable by a later one — does not repeat here. The
fixture is usable; one sentence of arithmetic guidance around it is wrong.

**Two further notes for the PR 5 and PR 6 briefs.**

- `make_domain_pair()` writes **three** `NA` markers, not the "exactly one" that
  `test-spec.md` §Fixture helpers states, and one of the three (row 130) sits
  where the mask would otherwise be `FALSE`, not `TRUE`. Three assert strictly
  more than one and `sum(mask)` stays the in-domain count, so nothing downstream
  breaks. Row 5.2's phrase "the `NA` row is not in the converted object" reads
  over three rows.
- The `"nonprob"` branch of the helper is built by no shipped test in any of the
  six PRs. Plan criterion 5 required it, so it stays, but nothing exercises it.

---

## Decision

**PASS on tree `4d4b21a`.**

Everything this PR was asked to build was built, and built well: nine blocks for
nine rows, a one-job helper with no coercion, a fixture that serves two later
PRs, `expect_identical()` throughout, and a clean gate run with coverage up. The
one defect — a `NEWS.md` entry that told a user to look for a wrong number where
ten measurements say they would have seen an abort — is repaired in `627e4dd`,
which moves that file and no other. The three gates `NEWS.md` can move were
re-run and pass. The seven convergence checks are clean, Tolerance Integrity
holds, scope discipline holds, and the coverage floor is met with no regression
in new lines.

Two items leave this review open for the arc, neither of them a defect in PR 4:

1. **PR 5's brief must carry the §5 row 5.3 correction.** `test-spec.md` §5 says
   `sum(mask)` gives the expected count for the two-phase conversion row. It
   does not. The two-phase route removes no row and gives excluded rows an
   infinite probability, so the count is `sum(mask & subset)` — 52 on this
   fixture, against `sum(mask) = 149`. Detail and the exact expression are in
   §Judgment 4. Without this, PR 5 writes a block that cannot pass and reads
   `make_domain_pair()` as the cause.
2. **Issue #262's title should be corrected before this PR merges.** It says the
   functions "silently report the wrong" values. The `NEWS.md` entry now cites
   an issue whose title contradicts it, and a reader follows that link.
