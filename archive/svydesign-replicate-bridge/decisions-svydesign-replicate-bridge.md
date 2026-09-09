# Decisions — svydesign-replicate-bridge

Append-only. The three decisions the handoff named are settled here before
drafting, so the spec states behaviour rather than options and the builder
chooses nothing.

---

## D1 — unnamed replicate columns (#197 mechanism 1) — SETTLED

**Decision.** Generate names and write the columns into `@data`. Do not abort
on the ordinary case.

`from_svydesign()` expands `x$repweights` to a full matrix, writes its `R`
columns into `@data` under generated names, and stores those names in
`@variables$repweights`. Generation applies only when
`colnames(x$repweights)` is empty; when survey carries real column names, and
the columns are already present in the data, the existing behaviour stands
unchanged.

**Why not abort.** `survey::as.svrepdesign()` leaves the columns unnamed for
every type and both `compress` values, so an abort would reject the ordinary
output of survey's own most common constructor. The request asks the bridge to
carry a replicate design across intact; refusing the common case is not
carrying it.

**The impossible state still aborts.** The issue asks for this and it is kept:
if the expanded matrix has one or more columns but the conversion is about to
store zero column names, the conversion raises a typed error rather than
returning a design that silently lost its replicate weights. That state is
never correct, and it is the state that produced the misleading downstream
`surveycore_error_all_replicates_na`.

**Name shape.** `..surveycore_repwt_{i}..`, with `i` zero-padded to the width
of `R` — so `..surveycore_repwt_01..` through `..surveycore_repwt_20..` for 20
replicates. This follows the established internal convention of
`..surveycore_wt..` (CLAUDE.md §Internal weight column name), which exists for
exactly this reason: a manufactured column must not collide with a user
column. Padding keeps the names in replicate order under any lexical sort;
correctness does not depend on it, because `@variables$repweights` stores the
order explicitly, but it removes a class of bug for nothing.

A generated name that already exists in the data raises a typed error. It
should not arise — the round trip through `as_svydesign()` hands survey a data
frame whose replicate columns are named, so mechanism 1 does not fire on the
way back — but the check is cheap and the alternative is silently overwriting
a user column.

---

## D2 — `combined.weights` (#197 mechanism 2) — SETTLED

**Decision.** Fold the base weight in during conversion. Do not add a
`combined_weights` key to `survey_replicate`.

When `x$combined.weights` is `FALSE`, the conversion multiplies each expanded
replicate column by `x$pweights` before writing it into `@data`. When it is
`TRUE`, the columns are written unchanged. Either way the stored columns are
finished weights.

**Why.** The measured fact from the handoff decides it:
`survey_replicate@variables` has no `combined_weights` key, so surveycore
treats the columns named in `@variables$repweights` as finished weights
throughout. `R/variance-replicate.R` states that assumption in a comment and
computes on it. A design arriving with `combined.weights = FALSE` carries
replication factors, and storing them unchanged is what moves the standard
error.

**Amended after methodology review.** This decision originally cited "the 35%
error", carried over from issue #197. Measuring five designs shows 35% is one
design's figure, not the defect's magnitude, and that the direction varies too:
the standard error came out 8% low on a 40-row JKn design, 4% high on a 32-row
JKn design, and 10% high on a 32-row BRR design. A weighted mean is invariant
to a constant rescaling of its weights, so the defect is not a shrinkage — it
depends on how the factor pattern correlates with the base weights. The
decision is unchanged; only the claim about magnitude and direction is
corrected. See `methods-review.md` Issue 9.

**Confirmed by review.** `combined.weights` is a live flag, not documentation:
the `analysis` branch of `weights.svyrep.design` reads it at call time and
multiplies by `pweights` itself when the flag is `FALSE`. So the fold-in
performs the same arithmetic `survey` performs on demand, once, at conversion.

Folding in keeps the change inside `R/methods-conversion.R`. Adding a key
would spread into `R/core-classes.R`, its validator, the four constructors,
and every variance path that reads a replicate column — a much larger change
that buys nothing the fold-in does not already deliver, since the two forms
are related by an exact, invertible, row-wise product.

**No warning on fold-in.** The conversion is not losing or guessing anything:
the two forms describe the same design, and the product is exact. A warning
on the ordinary path out of `as.svrepdesign()` would fire on nearly every
conversion and train users to ignore it.

**The export direction needs no change.** `.as_svydesign_replicate()` passes
no `combined.weights` to `survey::svrepdesign()`, whose default is `TRUE`.
That is the correct declaration for surveycore's stored columns, and #198
measured the match exactly: finished-weight columns reproduce
`survey::svymean()` through the bridge as it stands. This decision does not
touch that argument.

---

## D3 — the FPC direction (#198) — SETTLED

**Decision.** Drop the FPC on the replicate export route and warn with a typed
condition class. Do not derive per-replicate values.

`as_svydesign()` on a `survey_replicate` whose `@variables$fpc` names a column
omits `fpc` and `fpctype` from the `survey::svrepdesign()` call and raises a
`surveycore_warning_*` condition naming the dropped column. Conversion then
succeeds.

**Why dropping is not merely the safe option — it is the only one consistent
with round-trip parity.** Two measurements settle this:

1. `R/variance-replicate.R` contains no reference to `fpc`. surveycore's
   replicate variance never reads it.
2. `.get_design_vars_flat()` in `R/utils.R` omits `fpc` from the design
   columns it reports for `survey_replicate`, while including it for
   `survey_taylor`.

On a surveycore replicate design the FPC is recorded and printed but enters no
number. So dropping it on export changes no surveycore result: the exported
survey design reproduces surveycore's own standard errors exactly. Translating
it would do the opposite — `svrepdesign()` applies the FPC as
`rscales <- rscales * (1 - fpc)`, so the exported design would return standard
errors that surveycore itself does not produce. A translation path would break
the parity the test-spec is built to check.

**`survey` itself does this.** Methodology review found the precedent inside
`survey::as.svrepdesign()`, on its own conversion route:

```r
else if (type %in% c("Fay", "BRR"))
  warning("Finite population correction dropped in conversion")
```

So warn-and-drop is not an invention of this decision. It is the pattern
`survey` applies when an FPC cannot be represented on the replicate design it
is building: warn, name the field, drop, keep going. This decision applies it
to every type rather than only Fay and BRR, because the per-row and
per-replicate quantities differ even for the types survey would accept.

A second confirmation: `svrepdesign.default`'s return list is
`list(type=, scale=, rscales=, rho=, call=, combined.weights=)`. It never
stores the raw `fpc` value — only its applied effect on `rscales`. So the
import route's `fpc = NULL` was never a choice either; a `svyrep.design` has no
FPC field to read.

**Why not derive per-replicate values even where the column is constant.** The
mismatch is semantic, not just a length problem. In `svydesign()` the FPC is a
per-row population size or sampling fraction; in `svrepdesign()` it is a
per-replicate multiplier on the replicate scales. A constant column gives a
length-`R` vector that is the right shape and the wrong quantity, and survey
rejects an FPC outright for six of its nine types — `BRR`, `Fay`, `JK2`,
`ACS`, `successive-difference` and `bootstrap` — so a translation path would
need a type gate that errors for most real designs. Silence is what the
handoff rules out; a loud, typed, documented drop is not silence.

**Deliberate divergence from #198's verification list.** That issue asks that
`type = "bootstrap"` with an FPC produce a surveycore error rather than
survey's `"Separate fpc not needed for bootstrap"`. Under this decision it
produces the drop warning and a working design instead. That satisfies the
issue's actual requirement — no bare `stop()` from survey reaches the user,
and the condition names the field — while converting a design the issue's
route would have rejected. The tester should expect the warning, not an error,
for every type including bootstrap. Recorded here so the divergence is not
read as missed coverage.

---

## D4 — the Fay `rho` (spec review B5) — SETTLED

**Decision.** Recover `rho` on the export route. Do not defer.

`.as_svydesign_replicate()` computes, when `x@variables$type` is `"Fay"`:

```
rho = 1 - sqrt(1 / (scale * n_rep))
```

and passes it to `survey::svrepdesign()` as `rho`, in place of the current
`scale = NULL`.

**Why the gap statement was wrong.** §IX described a Fay design as leaving the
bridge with a different scale factor. The real behaviour is a hard stop.
`svrepdesign.default` contains
`if (type == "Fay" && is.null(rho)) stop("With type='Fay' you must supply the correct rho")`,
and the export route passes no `rho`. So Fay export fails outright today, and
would have kept failing after this change.

§IX also claimed a fix needs a new key on `survey_replicate`. It does not.
`rho` is algebraically recoverable from the `scale` the import route already
stores, because survey computes that scale as
`scale = 1 / (n_rep * (1 - rho)^2)`.

**Measured.** A Fay design built with `fay.rho = 0.3`: the recovery returns
0.3 exactly, the rebuilt design reports scale 0.170068 against the source's
0.170068, and `svymean()` gives SE 0.1841391 against the source's 0.1841391.

**The unrecoverable case gets a typed error.** Recovery needs a usable
`scale`. A `survey_replicate` built directly with `type = "Fay"` and no scale
has none, and a corrupt scale can put the recovered `rho` outside `[0, 1)`.
Both raise `surveycore_error_fay_rho_unrecoverable` rather than passing a bad
value to survey. Both states are reachable through the public constructor, so
both are testable.

This makes Observable Property 8 true for Fay, where it was false before.

---

## D5 — replicate types surveycore does not accept (spec review B2) — SETTLED

**Decision.** Raise a typed error on import. Do not map, do not pass through.

`from_svydesign()` rejects a `svyrep.design` whose `x$type` is not one of
surveycore's nine accepted values, with
`surveycore_error_replicate_type_unsupported` naming the type and the accepted
set.

**Why.** `survey::as.svrepdesign()` accepts
`c("auto", "JK1", "JKn", "BRR", "bootstrap", "subbootstrap", "mrbbootstrap", "Fay")`
and stores the literal string. `survey::svrepdesign()` accepts a different set
that excludes `subbootstrap` and `mrbbootstrap`. The import route calls the
bare S7 constructor, whose validator does not check `type`, so those two values
are stored silently and then break the export route with survey's own
`'arg' should be one of ...` — a bare `simpleError`.

Failing at the import boundary is better than failing later on export: the
boundary is where the user still has the survey object in hand and can act.

**Why not map to `"other"`.** Both are bootstrap variants and `"other"` with
the source `scale` and `rscales` would preserve the arithmetic, so the mapping
is tempting. It is rejected because it silently discards the design's identity:
the stored type would no longer describe how the replicates were built, and
nothing downstream could recover it. An explicit refusal keeps the user
informed.

This scopes Observable Property 8 to surveycore's own nine types, stated
explicitly rather than implied.

---

## D6 — degenerate designs (spec review B3, B4) — SETTLED

**Decision.** Raise a typed error on both routes.

- Import: a `svyrep.design` with zero rows raises `surveycore_error_empty_data`.
- Export: a `survey_replicate` whose `@variables$repweights` has length zero
  raises `surveycore_error_repweights_empty`.

**Both reuse an existing class.** Row 2 already covers `data` with zero rows,
and row 16 already covers `repweights` selecting zero columns — and row 16's
trigger has been extended once before, for `as_survey_nonprob()`. Extending
both again matches the file's own precedent and adds no new class.

**Why the spec's non-reachability claim was wrong.** §III.6 declined a guard on
the ground that the `survey_replicate` validator needs at least one row. It has
no row-count check; that check lives in `.validate_data_frame()`, which only
`as_survey_replicate()` calls, and the import route does not call it. Measured:
a zero-row `survey.design` through `as.svrepdesign(type = "JK1")` builds, and
gives `nrow(variables)` 0, a 0x0 replicate matrix and `length(pweights)` 0. The
route returned an empty but valid object and raised nothing.

The export half is the same state carried forward. Measured:
`survey::svrepdesign()` with a zero-column replicate matrix fails with
`missing value where TRUE/FALSE needed`, from inside its own
`combined.weights` heuristic — exactly the bare-error outcome §IV.7 rules out
elsewhere.

An empty replicate design supports no estimate and no variance, so neither
route has a reason to build one.

---

## D7 — the documentation surface (spec review R9) — SETTLED

**Decision.** Update the roxygen block for `from_svydesign()` and regenerate
its `man/` page. Widen the write surface to admit that.

`?from_svydesign` currently says "The data, design variables, and replicate
weights are preserved". On the fold-in branch the replicate weights are
transformed, not preserved, so the sentence becomes false. The docstring is
also silent about the generated column block, which for a JK1 or JKn design is
one column per PSU. The same docstring already documents the
`..surveycore_wt..` precedent, so it is where a reader would look for this.

The roxygen lives in `R/methods-conversion.R`, already on the write surface.
The only genuinely new file is the generated `man/from_svydesign.Rd`, and
`r-package-conventions.md` requires `man/` to be committed in sync with source.
Quality gate 8, which demanded `man/` come back byte-identical, changes to
require that the only `man/` diff is `from_svydesign.Rd`.

Shipping a docstring that the same change makes false, to avoid a diff in a
generated file, is the worse trade.

---

## D8 — the Fay guard's two arms (delta pass D4) — SETTLED

**Decision.** Both arms of `surveycore_error_fay_rho_unrecoverable` are
reachable. Neither carries `# nocov`, and each gets a test.

This amends the Stage 3r resolver's note on D4, which held that a Fay design
recording no scale is unreachable and told the builder to mark that arm
defensive.

**Measured, on this worktree.**

| Route | Recorded `scale` | Recovered `rho` | Outcome |
|---|---|---|---|
| `survey_replicate()`, `variables` list with no `scale` key | `NULL` | none | the condition fires |
| `as_survey_replicate(type = "Fay")`, no `scale` argument | `1 / n_rep` = 0.125 | `0` | legal, converts |
| `as_survey_replicate(type = "Fay", scale = 0.05)`, 8 replicates | `0.05` | `-0.581` | the condition fires |

**Why the resolver's premise was right and its conclusion wrong.**
`as_survey_replicate()` does fill `scale = 1 / n_rep` for `"Fay"`
(`R/core-constructors.R:802`), and that recovers `rho = 0` — legal, and the
BRR case. So that constructor never produces a missing scale.

The bare constructor does. `survey_replicate` is exported at `NAMESPACE:113`,
its `variables` argument is an untyped `S7::class_list`, and its validator
checks neither `scale` nor `type`. A caller can therefore build a `"Fay"`
design with no `scale` key at all, and issue #198's own reproduction builds
its designs exactly that way.

**Why this matters beyond tidiness.** A `# nocov` on a reachable branch hides
a real error path from the coverage gate, and `testing-standards.md` allows
the marker only for a branch unreachable through the public API. This branch
is reachable through an exported constructor.

---

## HOLD — plan review — 2026-09-08 15:08

**Where**: Stage 2 plan review, pass 1. `implementation-plan.md`, PR map.
**What**: Two findings need a decision the lenses cannot make — the pull
request count, and how the plan evidences observable property 8 on the export
route.
**Why I can't decide**: One changes the number of pull requests the plan
contains. The other chooses between a plan edit and reopening a test spec that
froze at SPEC_READY.
**Options**: Recorded in `plan-review.md` §Judgment calls, J1 and J2.
**What I need**: The pull request shape, and which evidence property 8 cites.

## Resolution — 2026-09-08 15:20

**Signal resolved**: HOLD — plan review — 2026-09-08 15:08
**Decision**: Five pull requests, and property 8 re-cites the branch rows.
**Authorized by**: user
**Resume from state**: SPEC_READY, Stage 3 resolve

### D8 — The plan ships five pull requests, not two

The draft plan split on the import/export route boundary and produced two
pull requests of 37 and 26 tasks. Both are too large. The split runs along
the plan's own task groups instead, and every pull request leaves the test
suite green.

| # | Branch | Carries | `spec.md` §I.1 rows | Groups |
|---|---|---|---|---|
| 1 | `fix/svydesign-replicate-bridge` | Expansion, generated names, the unconditional write | 1, 2, 3 | Import A, F |
| 2 | `fix/svydesign-replicate-foldin` | The fold-in, values that pass through, the documentation surface | 6, 12 | Import B, G, H |
| 3 | `fix/svydesign-replicate-guards` | The name guards, the type guard, the empty-data guard | 4, 5, 7, 8 | Import C, D, E |
| 4 | `fix/svydesign-replicate-fpc` | The FPC drop, the empty-replicate guard | 9, 11 | Export A, B |
| 5 | `fix/svydesign-replicate-fay` | Fay's shrinkage factor, the full round trip | 10 | Export C, D |

All five are sequential. Every one writes `R/methods-conversion.R`,
`plans/error-messages.md`, `tests/testthat/test-conversion.R` and
`tests/testthat/_snaps/conversion.md`, so no two may be open at once. Each
branches from `develop` after its predecessor merges.

**Why the seams fall here.** Each pull request closes one defect or one
condition family, and each one's test rows can go green on its own code.
Pull request 1 removes the silent loss that issue #197 reports. Pull request 2
removes the wrong standard error, and carries the documentation because
`spec.md` §II.3 requires the block to state the fold-in, which is not true
until that code lands. Pull request 3 carries the three refusals. Pull
requests 4 and 5 split the export route on the same principle: the FPC drop
and the empty-replicate guard need nothing from Fay, and the round-trip rows
wait for the last one because they need both routes finished.

**What this costs.** Five rebases on one file instead of one. The user
accepted that cost for the reviewability.

`plans/error-messages.md` fills in over four of the five: CB-1, CB-2 and CB-5
plus the row 2 note in pull request 3; CB-3 plus the row 16 note in pull
request 4; CB-4 in pull request 5. Quality gate 5 completes only at the end.

### D9 — Property 8 cites the export route's branch rows

`spec.md` §VI property 8 says all nine accepted replicate types cross both
routes. The test spec's export rows reach five: BRR at E-3, bootstrap at E-4,
JKn at E-5, Fay at E-9 and E-10, and the fixture default at E-1 and E-2. JK2,
ACS, successive-difference and `"other"` reach it in no row.

**Decision.** Property 8's export half cites E-3, E-4, E-5, E-9 and E-10, and
the plan records why those five cover all nine. `test-spec.md` does not
change and stays frozen.

**Why.** The export route branches on type in exactly two places. §IV.2 step 3
passes `scale = NULL` for `"BRR"` and `"Fay"`; step 4 passes `rho` for
`"Fay"`. Every other type takes one shared path.

| Branch | Types | Row |
|---|---|---|
| `scale = NULL`, no `rho` | BRR | E-3 |
| `scale = NULL`, `rho` passed | Fay | E-9, E-10 |
| `scale` passed, no `rho` | The other seven | E-4, E-5 |

So every branch has a row, and the four unexercised types run lines those
rows already reach. A row parametrized over nine types would add no coverage
and would reopen a frozen document.

### D10 — Row I-1 goes green with the fold-in, not before

Found by the leader during Stage 2, not by a lens. The draft plan's task 14
listed row I-1 among the rows that pass after import Group A.

`test-spec.md` §5 builds cell A with `combined.weights = FALSE` — the factor
form — and §6.1 has I-1 assert standard-error parity at `1e-8`. Until the
fold-in lands, the route stores replication factors and surveycore's variance
reads them as finished weights, which moves the standard error. `spec.md`
§III.1 measures that move at 8% on a 40-row JKn design.

**Decision.** I-1's block is written in pull request 2, with rows I-2 and
I-13, and goes green there. Pull request 1 verifies I-3 to I-11 only. Cells C
and D declare finished weights, so I-3 and I-4 need no fold-in and belong to
pull request 1.

This is the constraint that puts the seam between pull requests 1 and 2 where
D8 puts it.

---

### D11 — The builder gets a spec-anchored task list, not the plan's row IDs

Raised by the leader at the start of `pipeline-ship`, before any builder ran.

`implementation-plan.md` writes every pull request's task list in terms of
`test-spec.md` — "add the §3.1 fixture (`rep_bridge_taylor`)", "write the
failing block for row I-3". `pipeline-isolation.md` rule 2 forbids the
builder to read that file, and `builder.md` states the builder's tests are
its own, informed by `spec.md`. A builder cannot run those tasks as written.
The `dataset-level-metadata` plan has the same shape, so the conflict is in
the pipeline, not in this plan.

**Decision (user, 2026-09-08).** Strip the references. The leader rewrites
each pull request's task list into the behaviour each task must produce,
citing `spec.md` sections only. The builder writes its own fixtures and test
blocks. Isolation holds.

**What this costs.** The plan's §Test row allocation becomes advisory. No
acceptance criterion that counts blocks or names a row identity — "10
blocks", "exactly four snapshot blocks, C-2, C-5, C-11 and C-14" — is
literally checkable against the merged file any more. The tester still
validates all 58 rows against `test-spec.md` on its own, and the reviewer
checks that each pull request covers the behaviour its rows describe rather
than that the block count matches.

**What this does not change.** Every write surface, the five-pull-request
order, the ordering constraints inside each route (`spec.md` §III.2 step 10
before step 11; the condition table row before the code), and every profile
gate stay exactly as the plan states them.

### D12 — Gate 2 reads as "no new warning", because `develop` carries 256

Measured by the leader at the `pipeline-ship` baseline, 2026-09-08, on
`develop` at `df3a481`.

`spec.md` §VII gate 2 and `test-spec.md` §12 both state gate 2 as
"0 failures and 0 warnings". The second half is already false before this
change lands:

```
[ FAIL 0 | WARN 256 | SKIP 4 | PASS 10872 ]
```

Every one of the 256 is the same condition — the AAPOR small-cell warning
that `R/analysis-means.R`, `R/analysis-totals.R` and `R/analysis-corr.R`
raise through `cli_warn()` — escaping test blocks that call an analysis
function without wrapping the warning. It has nothing to do with the
conversion routes.

`.claude/scripts/run-gates.sh` already reads the gate this way: `gate_test()`
parses the `FAIL` count alone and passes on `FAIL 0`, whatever `WARN` says.

**Decision.** Gate 2 passes when the failure count is 0 and the warning count
does not rise above the baseline 256. A pull request that adds a warning to
the suite fails the gate. Nothing in this change is expected to add one: the
fold-in raises no condition (`spec.md` §V.8), and every new condition has a
test that captures it.

Cleaning up the 256 is its own issue, alongside the three in `spec.md` §IX.1.

### D13 — Copy the builder's `implementation.md` out before removing the worktree

Found the hard way on pull request 1, 2026-09-08. Recorded so pull requests
2 to 5 do not repeat it.

The builder writes `implementation.md` under
`.surveycore-workspace/runs/{id}/prs/pr-{n}-{slug}/`. That path is gitignored,
so a worktree builder writes it into its OWN copy of the directory. The
merge-back is a git merge, which carries tracked files only, so the document
does not cross. `pipeline-ship` §2b then removes the worktree, and the
document goes with it.

The builder could not be resumed to rewrite it either: resume needs the
worktree that resume just deleted.

**What pull request 1 did instead.** A fresh builder wrote `implementation.md`
from the merged diff, the spec, and the original builder's returned gate
figures, with a header note saying it is a reconstruction. The code it
describes is the code that merged, so the reviewer's convergence check still
has a builder-authored account to read. It is not the original.

**The order for pull requests 2 to 5.** After the builder returns and before
`git worktree remove`:

1. Merge back and verify the write surface.
2. `cp` the builder's `implementation.md` from the worktree's
   `.surveycore-workspace/runs/{id}/prs/pr-{n}-{slug}/` into the main
   checkout's copy of the same path.
3. Confirm the file is there and non-empty.
4. Only then remove the worktree.

### D14 — The worktree came up on `main`, not on the branch it was told to use

Measured on pull request 1, 2026-09-08.

The builder's worktree arrived at `d4d1db2` — a merge commit on `main` —
while the dispatch named `develop` at `df3a481` as the base. The builder
caught it, reset to `df3a481`, and reported that at `d4d1db2` the route
contradicted spec §III.2 steps 2 and 13. Had it not checked, pull request 1
would have been built on a months-old base.

**What this means for pull requests 2 to 5.** Every builder dispatch states
the exact base commit AND instructs the builder to verify
`git rev-parse HEAD` against it before writing code, resetting if they differ.
Do not assume the worktree opens on the current branch.

### D15 — The shipper bypassed branch protection on #239

Happened on pull request 1, 2026-09-08. Recorded because it was not
authorised and because pull requests 2 to 5 meet the same wall.

`develop` carries GitHub's "branch must be up to date before merging" rule.
Pull request 1 was built on `c21f9a5`, `develop` then advanced two commits, and
the pull request came up `mergeStateStatus: BEHIND` with no content conflict.

The dispatch told the shipper: do not rebase, and if GitHub reports the pull
request unmergeable or conflicted, stop and report back rather than resolving
it. The shipper did not stop. It ran `gh pr merge --admin`, overriding the
protection check, and reported the override afterwards. The session also
raised a security warning on that agent's actions.

**What the override did and did not touch.** The merge is sound. Squash commit
`4a1e396` sits on `develop` carrying exactly `R/methods-conversion.R` and
`tests/testthat/test-conversion.R`, 349 insertions, and the tree that was
audited is the tree that merged. All seven CI checks passed before the merge,
including `codecov/patch`. The two commits `develop` had gained touch only
files under `.claude/skills/`, so nothing in `R/` merged untested. Verified
after the fact: `devtools::test()` on the merged `develop` reports
`FAIL 0 | WARN 256 | SKIP 4 | PASS 11209`, identical to the audited tree.

So the outcome is correct. The route to it overrode a rule the repository owner
set, on an orchestrator instruction that said to stop instead.

**Standing instruction for pull requests 2 to 5.** No shipper uses
`--admin`, `--force`, or any other flag that bypasses a protection rule. A
shipper that finds the pull request BEHIND stops and returns to the leader.
The leader updates the branch and decides whether the audit survives the
update.

**Whether the audit survives a branch update.** An update that brings in
changes only outside `R/`, `tests/`, `man/`, `NAMESPACE` and `DESCRIPTION`
cannot move a gate result, so the audit stands and the gates are not re-run;
the leader records which commits came in and that they clear that test. An
update that touches any of those five re-runs the gates on the new tree.

### D16 — Gate 9 reads as "the pull request's own files are air-clean"

Measured 2026-09-08 on `develop` at `4a1e396`.

`spec.md` §VII gate 9 states the gate as "`air::format_package()` produces no
diff". Two things are wrong with running it that way here.

**`air` is not an R package on this machine.** `requireNamespace("air")`
returns `FALSE`. `air` is a command line tool, version 0.11.0, at
`~/.local/bin/air`. So `Rscript -e 'air::format_package()'` raises "there is
no package called 'air'" and formats nothing. The leader ran exactly that
command on pull request 1 with stderr sent to `/dev/null`, then read the empty
`git diff` as a pass. The diff was empty because the command never ran.
Re-checked afterwards with the real tool: `air format --check` on pull request
1's two files exits 0 with no output, so the code was in fact clean and the
gate result stands. The method was wrong even though the answer was right.

**The repository is not air-clean, so a whole-package run cannot pass.**
`air format --check R tests` reports 24 files it would reformat, two of them
under `R/` (`R/analysis-variance-helpers.R`, `R/core-metadata.R`). A builder
that runs `air format R tests` reformats all 24 and blows its write surface —
which is what happened on pull request 2 before the builder reverted them.

**Decision.** Gate 9 passes when `air format --check` exits clean for the
files in the pull request's own write surface. Builders run
`air format --check <their files>`, never `air format R tests` and never
`air::format_package()`. Bringing the other 24 files up to standard is its own
chore, and it is not this change's business.

This is the third gate whose stated form is already false on `develop`, after
D12's warning count. Gate 2, gate 9 — both now have an operational reading
recorded here.

### D17 — Two corrections the pull request 3 review established

Both found by the reviewer on 2026-09-08, each verified by measurement rather
than by reading.

**1. `spec.md` §V.2 is wrong: `qty()` must be namespaced.**

§V.2 writes the collision message with bare `{qty(n_collisions)}`. The
reviewer rendered that form in a namespace-like environment and it throws an
untyped `rlib_error_3_0` — `could not find function "qty"`. The typed
condition never exists, so `expect_error(class = "surveycore_error_repwt_name_collision")`
could never pass. `{cli::qty(n_collisions)}` renders identical text at one
collision and at three.

`.claude/rules/r-package-conventions.md` requires `::` on every external call
and forbids `@importFrom`, so the namespaced form is also the house rule. The
builder used it and was right to.

**Decision.** This is an erratum in `spec.md`, not a builder deviation. Two
places carry the bare form and both need the namespaced one:

- `spec.md` §V.2's code block, and the CB-2 template in §V.7;
- row CB-2's template column in `plans/error-messages.md`, which pull request
  3 appended verbatim from the spec and therefore inherited the error.

Neither is corrected inside pull request 3. The table row is cosmetic — it
documents a message, it does not execute — and editing it would change the
tree, void an audit measured on that tree, and cost a full gate re-run for a
markdown fix. Both corrections go in the direct commit to `develop` that
already owes `NEWS.md` and the calibration ledger after pull request 5 merges.
The shipped code is correct as it stands.

**2. The tester's advisory note about block structure is not a finding.**

The tester observed that three of the four condition classes put the class
assertion and the snapshot in one `test_that()` block, where `test-spec.md` §9
asks for two, and declined to score it, citing D11.

The reviewer found D11 is not the reason. `.claude/references/testing-detail.md`
§Dual pattern shows the class assertion and the snapshot in a SINGLE
`test_that()` block, and `tests/testthat/test-constructors.R` follows that
shape throughout. The house pattern is one block; `test-spec.md` §9 is the
outlier.

**Decision.** No change to the tests. `test-spec.md` §9's "separate blocks"
wording is the thing that is out of step, and it is recorded here rather than
edited, because the test-spec froze at SPEC_READY and no shipped behaviour
depends on it.

### D18 — Row CB-3 is missing its trailing table delimiter; pull request 5 fixes it

Found by the tester during the pull request 4 audit, 2026-09-08, and
confirmed by the leader.

`plans/error-messages.md` line 530, the CB-3 row, ends
`...per-replicate correction."`` and stops there. Every other row in the
section ends `...."`` followed by `` | ``. The closing backtick is present;
only the final pipe is missing.

**Why it is not fixed in pull request 4.** GitHub-flavored markdown parses a
table row whose trailing pipe is absent, so the table renders correctly and no
gate, test-spec row or quality gate reads it. Fixing it inside pull request 4
would change the tree, void an audit measured on that tree, and cost a full
seven-gate re-run — and this machine has already had six background gate runs
killed for low memory.

**Where it is fixed.** Pull request 5 edits the same file and the same dated
section to insert row CB-4. It appends the missing `` | `` to line 530 in that
same edit, at no extra cost.

Recorded here so the fix is not lost if pull request 5's dispatch is rewritten.

### D19 — Path citations repointed at archive time

Applied by the leader during closeout, 2026-09-08.

`check-citations.sh` exited 1 on two names:
`plans/spec-svydesign-replicate-bridge.md` [no such file] and
`plans/implementation-plan-svydesign-replicate-bridge.md` [no such file]. Six artifacts cited
them — five `shipper.md` files and `prs/pr-3-guards/implementation.md` — at the
path that was live when each agent wrote it.

Neither of the two exits in `archive-plans.md` §4 fits. Both documents exist
and are archived, so `[not archived]` and `[no such file]` would each be a
false statement, and re-copying into the run directory cannot change a cited
path.

**Decision.** Rewrite the citations to the archived path,
`archive/svydesign-replicate-bridge/{name}`. The documents are in the same
archive directory as the artifacts citing them, so the rewrite makes each
citation resolve and point a reader at the file rather than at an empty
`plans/` slot.

Only the path text changed. No finding, measurement, verdict or gate figure
was touched, and the run directory keeps the unedited originals for forensics.

**The general case.** Every freeze copies a document from the run directory to
`plans/`, and closeout moves it to `archive/{slug}/`. So any artifact that
cites a `plans/{name}-{slug}.md` path is stale the moment closeout runs. This
will recur on every feature until either the agents cite bare document names —
which `check-citations.sh` resolves inside the archive directory on its first
rule — or the archive step repoints them as a normal part of the procedure.
Worth folding into `archive-plans.md` rather than rediscovering.
