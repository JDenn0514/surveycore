# Decisions — replicate-scale-jkn-bootstrap

Run-local decisions. The arc's own locked decisions are D1, D2 and D5 in
`plans/issue-cleanup.md` and are not restated here.

---

## D-1 — SETTLED — `R = 1` with `type = "bootstrap"` stores `Inf`

**Raised by:** Stage 0 comprehension, as a HOLD. The new bootstrap default
`1/(R-1)` evaluates to `1/0` when the design names one replicate column.
`as_survey_replicate()` accepts one column today and stores `1`.

**Measured before deciding.** survey 4.5, R 4.6.1, Windows. One replicate
column, `type = "bootstrap"`, `mse = TRUE`, no `scale` on either side.
Probe script:
`{scratchpad}/probe-r1-bootstrap.R`, run 2026-09-23.

| Side | stored `scale` | SE of mean `y` |
|---|---|---|
| `survey::svrepdesign()` | `Inf` | `Inf` |
| `as_survey_replicate()` before this change | `1` | finite |

`survey` builds the design and signals no condition. The infinite scale
reaches the standard error.

**Decision.** This PR stores `Inf` for that input. D5 sets the rule for this
constructor: `survey` decides. `survey` returns `Inf`, so surveycore returns
`Inf`.

**What follows:**

- `@param scale` records that a bootstrap design of one replicate column
  gives an infinite scale, and that `survey` does the same.
- One test row pins the stored value at `1/(R-1)` for `R = 1`, so the change
  is visible if a later PR refuses the input.
- A new GitHub issue asks whether either package should refuse a
  single-replicate bootstrap design. It is not this PR's work.

**Rejected alternatives:**

- Refuse `R = 1` with a typed error. It needs a new class row in
  `plans/error-messages.md` and the dual error pattern, and it diverges from
  `survey` on an input guard while this PR exists to remove a divergence.
- Special-case `R = 1` to `scale = 1`. It invents a third convention that
  neither `survey` nor Wolter supports, and it hides a meaningless design
  behind a finite number.
- Say nothing. It ships an undocumented `Inf` that no test covers.

**Decided by:** the user, 2026-09-23.

### Amendment — one premise was false, and the decision was re-confirmed

The first offer of the "refuse" alternative said it needed a new class row in
`plans/error-messages.md`, and the Stage 0 artifact said
`as_survey_nonprob()` documents an "at least 2" rule that its validator does
not enforce. Both statements are wrong. Adversarial verification found the
refusal already ships (FIX-14 in `adversarial-verification.md`):

- `as_survey_nonprob()` raises `surveycore_error_repweights_single` —
  "{.arg repweights} must name at least 2 replicate weight columns." — at
  `R/core-constructors.R:1457-1469`.
- Tests: `tests/testthat/test-constructors.R:2107` and `3008-3024`.
- The class has a row in `plans/error-messages.md` (NB-3).

So a refusal in `as_survey_replicate()` would follow a shipped precedent
rather than set a new one, and it would cost no new error class.

The decision was put to the user again with that correction, together with a
third option — refuse `R = 1` for every replicate type, matching
`as_survey_nonprob()` outright. The user kept D-1 unchanged on 2026-09-23.

**Why it still holds.** D5 makes `survey` the authority for this
constructor, and `survey` stores `Inf`. The two constructors already diverge
on the bootstrap scale itself by decision — `1/(R-1)` here against `1/R`
there, per D1 — so a difference in an input guard is the smaller
inconsistency of the two.

---

## D-2 — SETTLED — the with-replacement condition goes on the exported help page

**Raised by:** methods review Pass 1, issue 2 (Lens 6, REQUIRED).

Wolter's eqs. 4.5.3 to 4.5.6 are written `q_h / n_h`, with
`q_h = (n_h - 1)(1 - n_h/N_h)` without replacement and `q_h = (n_h - 1)` with
replacement. The simplified `(n_h - 1)/n_h` holds only for with-replacement
sampling, or when the sampling fraction is negligible — Wolter chapter line
1416, restated at 1537 to 1551. `comprehension.md` A3 records the condition.
`spec.md` stated the simplified form unconditionally and F-3 shipped it to
users.

**Why it mattered.** A caller sampling PSUs without replacement at a
non-negligible fraction who follows F-3 literally builds `rscales` from
`(n_h - 1)/n_h`, omits `(1 - n_h/N_h)`, and understates the standard error.
That is this PR's own defect moved onto a different population. G8 already
said the `@param rscales` text should carry the caveat, because D12 refuses
the `fpc` argument and leaves `rscales` as the caller's only route.

**Decision.** The caveat goes on the exported help page and in an internal
comment at the JKn switch line. The justification section cites `q_h / n_h`
as the form the equations use and defines `q_h` both ways.

**Rejected:** internal comment only, which leaves the exported fact
incomplete for the without-replacement case; and rewriting F-3 wholly in
Wolter's `q_h / n_h` notation, which is most faithful and hardest to read.

**Decided by:** the user, 2026-09-23.

## D-3 — SETTLED — the `mse` scope exclusion is re-scoped to the jackknife

**Raised by:** methods review Pass 1, issue 3 (Lens 2, REQUIRED).

`spec.md` §Out scoped `mse` out for both changed types by citing Wolter's set
of four estimators and their shared second-order expectation. That set is the
stratified-jackknife family. `comprehension.md` F11 records Theorem 4.5.3 as
the nearest support "for the jackknife, not for the bootstrap". Using it to
cover the bootstrap is a jackknife-specific rescue applied outside its scope.

`1/(R-1)` is the unbiased divisor of a sample variance taken about the sample
mean of the replicate estimates. surveycore defaults to `mse = TRUE`, which
centres on the full-sample estimate — a value the replicates did not pay a
degree of freedom to compute. `survey` sets the bootstrap scale without
consulting `mse`, so the pairing is inherited rather than new.

**Decision.** Re-scope the citation to the jackknife and document the
pairing, including the asymmetry: a bootstrap design at `mse = FALSE` gets the
textbook-consistent pairing and carries no open question. Documentation only.

**Rejected:** adding an `mse = FALSE` bootstrap oracle row, which would grow
an already over-budget row count; and filing a follow-up issue, which the
user did not ask for. The question stays recorded in the spec rather than
tracked in GitHub.

**Decided by:** the user, 2026-09-23.

## D-4 — SETTLED — the nonprob divergence sentence states the magnitude

**Raised by:** methods review Pass 1, issue 8 (Lens 5, REQUIRED).

The required `as_survey_nonprob()` sentence gave the reason for the
divergence and not its size.

**Decision.** The sentence gains a fourth element: on the same frame,
`as_survey_nonprob()`'s bootstrap standard error is smaller than
`as_survey_replicate()`'s by the factor `sqrt((R-1)/R)`. The factor is
already derived in behaviour rule 6 and asserted by `test-spec.md` row 3.2,
so nothing new is computed.

The closed count moves from three elements to four in both documents.

### Correction — the percentage, not the factor

This entry first read "2.6% at `R = 20`", and so did the resolver's edit to
both documents. The direction is wrong. Measured:

```
sqrt(19/20)  = 0.9746794
1 - r        = 0.0253206   -> the nonprob SE is 2.5% SMALLER
1/r - 1      = 0.0259784   -> the replicate SE is 2.6% LARGER
```

2.6% is the rise from the nonprob standard error to the replicate one. The
fall in the other direction is 2.5%. Behaviour rule 6 states the rise and its
2.6% is correct; the nonprob note states the fall and needs 2.5%, or a
re-based sentence.

The error came from D-4's own instruction to reuse behaviour rule 6's figure
rather than recompute it. The instruction was right about the factor and wrong
about the percentage, because the two directions do not share one number.

Found by the Pass 2 delta review. The orchestrator had repeated it here and to
the user before the review caught it.

**Decided by:** the user, 2026-09-23.

## D-5 — SETTLED — the four advisory findings

Applied by the orchestrator on each lens's own recommendation. None changes
behaviour.

| Issue | Lens | Disposition |
|---|---|---|
| 10 — the rescaling-bootstrap objection | 5 | Recorded as one ADVISORY sentence, citing Rao and Wu (1988) `[verify]`. Records a known objection to a single hard-coded divisor. Does not reopen D5. |
| 11 — JKn `rscales` against a domain-emptied stratum | 4 | One row added to §Out, owner "not filed". Pre-existing and untouched by this work. Behaviour rule 7 already states the correct narrow fact. |
| 12 — the df warning in `spec.md` | 3 | No change, on the lens's own recommendation. The warning's home is `.claude/rules/testing-surveycore.md` and `test-spec.md` carries it. |
| 9 — the Wu (2022) / Chen et al. (2021) divisor attribution | 5 | **Open verification item for the user.** No edit. See below. |

### Issue 9 stays open, and it is not a blocker

`R/core-constructors.R:1308-1311` attributes `as_survey_nonprob()`'s
`bootstrap = 1/R` to Wu (2022), *Survey Methodology* 48(2), 283-311, and to
Chen, Li and Wu (2021), *JASA* 115(532), 2011-2021. The attribution is
pre-existing shipped text and this PR keeps it.

D1's new sentence puts that citation in direct contrast with `survey`'s
`1/(R-1)` for the first time, so a reader will infer the two papers
specifically endorse the population-form divisor for calibrated
non-probability bootstrap replicates. Neither paper was attached to this run.
The journals and titles are plausible; the divisor-specific claim is the
load-bearing part and is unverified.

No action taken, because verifying it needs the papers. Recorded so the
question is answered before the sentence ships, not after.

---

## D-6 — SETTLED — the transition stays silent, and the spec records why

**Raised by:** spec review Pass 1, R-13 (lens 6, REQUIRED).

Both defaults move a published standard error by about 2.6% for any affected
design built without an explicit `scale`. Nothing signals it at runtime:
§Errors and warnings says the work adds no warning class, and E1 and E5 both
say no condition is raised. A user upgrades, re-runs an old script, and gets a
different number with no message.

**The locked decisions do not cover this.** D1, D2 and D5 settle the two
values. None of them says whether the transition should be silent. Stage 2 had
no remit to raise it, and Stage 3's API lens did.

**Decision.** No transition message. One paragraph in §Out records that a
signal was weighed and declined, because the NEWS entry plus the
explicit-`scale` escape hatch are the documented route, and a condition on the
constructor would fire on every correct build.

**Rejected:** a one-time session-scoped informational message. It closes the
signal gap, but it adds a condition to a constructor that two edge cases
state raises none, and it must be removed a release or two later.

**Why the record matters more than the choice.** Without the paragraph the
silence reads as an oversight, and the next reviewer raises it again. With it,
the next reviewer sees a decision.

**Decided by:** the user, 2026-09-28.

## D-7 — SETTLED — row 2.3 is deleted

**Raised by:** spec review Pass 1, R-11 (lens 5, REQUIRED).

Row 2.3 built two extra designs per changed type and asserted that the point
estimates are bit-identical and the standard-error ratio is
`sqrt((R-1)/R)`. A wrong default is already caught by row 1.1, against the
old literal, and by rows 2.1 and 2.2, against the oracle. What 2.3 added was
proof that `scale` is a linear multiplier that never touches the point
estimate — a property of `R/variance-replicate.R`, which the spec places
outside the write surface.

**Decision.** Delete row 2.3. Fold its one PR-relevant assertion — that the
new default differs from the old value in the documented direction and
magnitude — into row 1.1, which already builds both scale values.

**What this costs.** The `replicate-oracle-tests` arc measured that a
scale-sensitivity check is the single most load-bearing guard against a wrong
default: its P2 measurement showed that doubling a stored scale leaves the
point estimate bit-identical while moving the standard error by exactly
`sqrt(2)`. Row 2.3 was that shape of check. The coverage is not lost — rows
1.1, 2.1 and 2.2 catch a wrong default between them — but the *mechanism*
proof moves out of this PR.

**Rejected:** keeping the row, which costs rows in an already over-budget
plan; and moving it to the variance engine's own test file, which is correct
ownership but widens this PR to a third test file.

**Decided by:** the user, 2026-09-28.

## D-8 — SETTLED — the internal comment becomes a pointer

**Raised by:** spec review Pass 1, R-10 (lens 5, REQUIRED).

The stratified jackknife derivation was written out in full three times: the
spec's justification section, the `@param scale` roxygen, and the mandated
internal comment at the switch lines. Nothing but style tied them together,
and a correction to the formula had three prose renderings to update.

**Decision.** The internal comment keeps the one line the code needs — which
line, which value — and points at `@param scale` for the derivation. The
roxygen stays the single shipped source. The spec's own justification section
stays; it is the run's record and does not ship.

**Decided by:** the user, 2026-09-28.

## D-9 — SETTLED — two outward-facing actions, one declined

**Raised by:** spec review Pass 1, B-1, R-2, R-6 and S-2.

The user authorised two of three.

**Done — the correction on issue #253.** Its body states that
`as_svydesign()` cannot round-trip a design built with
`bootstrap.average != 1`. Measurement M4 shows it can, and that the error is
an inference from a true premise: the numerator is already inside the stored
scale. Comment posted 2026-09-28.

**Done — issue #291**, "Two drifts between plans/error-messages.md and the
classes the package raises". Labelled `documentation` and `tier:backlog`. It
covers the missing register row for
`surveycore_error_stratified_jk_rscales_unset` (S-2) and the missing snapshot
for `as_survey_replicate()` raising `surveycore_error_weights_all_zero`
(R-2), and notes the NB-3 register-versus-code wording drift as a third item
to fold in.

**Declined — no issue for the negative-`scale` asymmetry (R-6).**
`as_survey_nonprob()` raises `surveycore_error_scale_negative` for a negative
`scale`; `as_survey_replicate()` stores it verbatim, because its scale block
has no `else` branch. Verified in source. A caller passing `scale = -1` gets
a negative variance multiplier silently. It gets a §Out row with owner "not
filed" and no GitHub issue.

**Decided by:** the user, 2026-09-28.

---

## D-10 — SETTLED — E7 shipped a false claim, and the refusal inventory grows to five

**Raised by:** the Stage 3r resolver, as a HOLD. Verified by the orchestrator
before acceptance.

Spec E7 claimed that "a zero-weight row among positive rows ... reach[es] the
same stored `scale` as any other frame". Spec review finding R-1 took that at
face value and asked for a test row building such a frame.

**The design cannot be built.** `.validate_weights()` raises
`surveycore_error_weights_nonpositive` for any non-NA weight at or below zero
(`R/core-validators.R:170-186`), and `as_survey_replicate()` calls it at
`R/core-constructors.R:783` — before the scale switch at 797. Verified by
reading both sites.

So the row R-1 asked for would have been red on arrival, and E7 asserted
something the constructor forbids. No lens caught it: lens 2 verified the
grouping clause and the all-NA clause and not this one.

**Decision.** Correct E7 rather than delete the clause, and name
`surveycore_error_weights_nonpositive` as a fifth class in the spec's refusal
inventory. Test-spec row 1.8 frame 2 asserts the refusal by `class =` in place
of asserting a scale.

The closed count moves from four classes to five in both documents. The class
is pre-existing, has register row 33 and has a snapshot at
`_snaps/labelled-storage.md:39-48`, so this needs no new class and no new
snapshot file.

**Why correction over deletion.** Deleting the clause leaves a reader of E7 to
rediscover the refusal. Naming it puts the fact where the question arises. The
resolver flagged the count expansion as unauthorised, which was right — it was
not covered by any of U-1 to U-4 — and the orchestrator accepted it on the
verification above.

**The narrower alternative, not taken:** drop the clause with a stated reason,
the way the grouping clause was handled. That edit is localised to five sites,
which the resolver listed, if this is ever revisited.

### A fourth register drift, found while chasing this

`plans/error-messages.md` row 33 attributes
`surveycore_error_weights_nonpositive` to the S7 validator for
`survey_taylor` and `survey_replicate`. On the constructor path
`.validate_weights()` raises it first, at Layer 2, so the S7 validator never
sees it.

The attribution matters because `.claude/rules/testing-surveycore.md` sets a
different test pattern per layer — `class =` only for Layer 1, the dual
pattern for Layer 3. A reader who trusts row 33 writes no snapshot for a
CLI-formatted constructor abort.

Recorded as a comment on issue #291 rather than in the spec, to avoid scope
creep. #291 now covers four items.

### One claim verified rather than assumed

The resolver flagged that FP-1 rests on "no replicate variance formula reads
`@variables$fpc`", which it had not measured. Checked:
`R/variance-replicate.R` contains no reference to `fpc` at all. Every other
occurrence in `R/` is the class validator, `glm.R`, the two conversion routes
or the print methods. The premise holds.

**Decided by:** the orchestrator, on verification, 2026-09-28. The user's U-1
to U-4 did not reach it.

---

## D-11 — SETTLED — rule 8 gets a test row, rule 7b gets a rationale

**Raised by:** plan review Pass 1, findings SC-1 and SC-2. Both were
JUDGMENT_CALL, and the verdict was NEEDS-DECISION.

Two behaviour rules in `spec.md` reached no PR and no test-spec row.

- **SC-1, behaviour rule 8.** A `survey_twophase` design over a replicate
  `phase1` inherits the new default unchanged. `as_survey_twophase()` copies
  `phase1@variables` at `R/core-constructors.R:1151` and recomputes no value
  in it. Nothing in `implementation-plan.md` or `test-spec.md` observed this.
- **SC-2, behaviour rule 7's domain clause.** Rule 7 carries two clauses.
  `test-spec.md` §1 already held an explicit "needs no row because X"
  rationale for the grouping clause. The domain clause had no row, no
  rationale and no PR task, so a later reader could not tell the silence from
  an oversight.

**Three shapes were open, the same three for each finding:**

1. add a test-spec row and give it to a PR;
2. add an explicit "needs no row because X" rationale;
3. accept the gap and record it here.

**Decision.** Shape 1 for rule 8, shape 2 for rule 7b.

**Why they differ.** Rule 8's value crosses a property copy. A copy is the
one operation in the chain that can drop or recompute a value, and no
assertion anywhere caught it. A two-phase user over a replicate `phase1`
gets a moved standard error from this work, so the value is published. Rule
7b's value crosses nothing: `filter()` marks domain membership and writes no
`@variables` key, so a domain restriction cannot reach the stored default.
The rule's other claim — that the variance takes the same factor after the
restriction — is a claim about `R/variance-replicate.R`, which no PR writes
and which is outside the write surface. A row there would assert a property
of a file this work does not touch.

**What shipped.**

- `test-spec.md` §1 gains row 1.9 and a paragraph saying it is not one of the
  seven edge behaviours. The row builds a `survey_replicate` per changed type
  with no `scale`, builds a `survey_twophase` over each, and asserts the
  stored `phase1` scale against its own literal — `1` for JKn,
  `1 / (n_rep - 1)` for the bootstrap — never one against the other. It also
  asserts that neither construction raises a condition, and it states that a
  Taylor `phase1` carries no `scale` and is untouched.
- `test-spec.md` §1 gains the domain rationale beside the grouping one.
- `implementation-plan.md` gives row 1.9 to PR 3. PR 3 already writes
  `tests/testthat/test-constructors.R` as its whole write surface, and it
  merges after PR 1, which the ordering constraint requires because the row
  asserts a changed default. PR 3's budget moves from 3 rows and 7 criteria
  to 4 rows and 8 criteria. Both figures sit inside their bounds.
- The block adds no `test_invariants()` call. `test-constructors.R` already
  calls it once for `as_survey_twophase()`.

**Decided by:** the user, 2026-09-28.

---

## HOLD — builder (PR 1) — 2026-09-28 23:10

**Where**: PR 1, step 3 of the task list. Two test blocks outside every write
surface named in `implementation-plan.md`:

- `tests/testthat/test-nonprob-bootstrap-variance.R:160`, block
  `get_means() SE is bitwise identical for survey_nonprob and survey_replicate with same data`
- `tests/testthat/test-analysis-corr.R:1728`, block
  `get_corr() polychoric: survey_nonprob with repweights matches survey_replicate numerically`

**What**: The step-3 red set is eleven assertions, not the nine `spec.md`
predicts. The two extra blocks both assert that `as_survey_nonprob()` and
`as_survey_replicate()` agree *numerically* on a bootstrap design. That is the
identity `spec.md` quality gate 6 deliberately breaks, so both blocks encode
the pre-change behaviour and must move when the default moves.

Measured, not inferred. The builder's full run went from
`[ FAIL 0 | WARN 256 | SKIP 4 | PASS 12005 ]` to
`[ FAIL 2 | WARN 256 | SKIP 4 | PASS 12001 ]`; SKIP held at 4 both times, so no
block hid behind a skip. In each block the point estimate still passes and only
the variance-derived number fails, which is the signature of a scale change:
`mean` and `r` agree, `se` and `ci_low` diverge by `sqrt((R-1)/R)`.

**Why I can't decide**: It is a scope question, not a behaviour question. The
behaviour is settled — D1 is locked, and `spec.md` §`as_survey_nonprob()` says
"the same `type` string means a different divisor in the two constructors, by
decision D1". What is unsettled is which PR repairs the two blocks, and that
requires amending three frozen artifacts:

1. `spec.md` §Test-file write surface — "Exactly one block in the whole suite
   asserts a stored default that this change breaks" is true of *stored
   defaults* and false of *derived numbers*. Two more blocks assert derived
   equality. §Files touched says seven files; the real figure is nine.
2. `test-spec.md` row 4.5 — "every test file outside
   `tests/testthat/test-constructors.R` and
   `tests/testthat/test-variance-replicate.R` holds its state" is now false.
3. `implementation-plan.md` PR 5 AC-3 — repeats row 4.5's closed list.

Left unamended, PR 5's tester BLOCKs on a criterion this arc has already made
unmeetable, in the same shape as D12 and D16 in
`archive/svydesign-replicate-bridge/`.

**Options**:

- **A — widen PR 1 to six files; retarget both blocks there.** Keeps `develop`
  green at every merge, which is the plan's stated reason PR 1 exists ("PR 1 is
  the smallest change that leaves the suite green"). Costs: three artifact
  errata, and PR 1 grows past the write surface the reviewer checks.
- **B — defer both blocks to PR 4 and merge PR 1 and PR 4 together.** Keeps
  PR 1's write surface intact and puts the repair beside PR 4's rows 3.1/3.2,
  which assert the same divergence deliberately. Costs: PR 1 merges red, which
  branch protection refuses, and it abandons one-PR-at-a-time for this arc.
- **C — send the finding back to `pipeline-spec`, amend the three artifacts,
  then resume.** Most faithful to the state model. Costs: a full spec cycle for
  a gap whose correct behaviour nobody disputes.

**What I need**: A choice of A, B or C, and — if A — approval to record the
three errata in this file as settled so the reviewer and PR 5's tester have
authority for the widened file list.

### Not part of this HOLD — one pre-existing defect found in passing

`tests/testthat/test-nonprob-bootstrap-variance.R:183`, block
`get_ratios() SE matches equivalent survey_replicate for survey_nonprob`,
passes only because both sides evaluate to `NULL`; testthat logs
"Unknown or uninitialised column: `se`" for each. It compares nothing today and
will begin to fail when `get_ratios()` gains an `se` column. Pre-existing, not
caused by this work, and outside its write surface. It wants a GitHub issue,
not a fix here.

### RESOLVED — 2026-09-29 — option A, by the user

Widen PR 1 to six files and retarget both blocks there. The three errata below
are SETTLED. The reviewer and PR 5's tester take them as authority; do not
re-argue them.

**E-1 — `spec.md` §Test-file write surface undercounts the broken blocks.**
It says "Exactly one block in the whole suite asserts a stored default that
this change breaks". That sentence is true of *stored defaults* and false of
the blocks this change breaks. Three blocks break, not one:

| Block | File | What it asserts | Why it breaks |
|---|---|---|---|
| `as_survey_replicate() computes bootstrap default scale = 1/R` | `test-constructors.R:676` | the stored default | the default moves |
| `get_means() SE is bitwise identical for survey_nonprob and survey_replicate with same data` | `test-nonprob-bootstrap-variance.R:160` | a derived SE identity | gate 6 breaks the identity |
| `get_corr() polychoric: survey_nonprob with repweights matches survey_replicate numerically` | `test-analysis-corr.R:1728` | a derived CI identity | gate 6 breaks the identity |

Read the spec sentence as scoped to stored defaults. §Files touched says seven
files; the true figure is nine.

**E-2 — `test-spec.md` row 4.5's closed list gains two files.** It reads
"every test file outside `tests/testthat/test-constructors.R` and
`tests/testthat/test-variance-replicate.R` holds its state". The list is now
four: those two plus `tests/testthat/test-nonprob-bootstrap-variance.R` and
`tests/testthat/test-analysis-corr.R`. The rest of the row stands unchanged —
no file under `tests/testthat/_snaps/` may change, and a changed snapshot is
still a finding to report and never to accept.

**E-3 — `implementation-plan.md` PR 5 AC-3 inherits E-2's list.** It repeats
row 4.5's two-file list and takes the same four-file correction.

**Why A and not B or C.** The plan's own reason for PR 1's existence is that it
is "the smallest change that leaves the suite green"; B abandons exactly that
and merges PR 1 red, which branch protection refuses. C spends a spec cycle on
a gap whose correct behaviour nobody disputes — D1 is locked and gate 6 already
documents the divergence.

**The shape of this erratum is not new.** A closed count stated in one artifact
that another artifact's prose makes unreachable is the same failure recorded as
D12 and D16 in `archive/svydesign-replicate-bridge/` and as S3, S6 and N3 in
`archive/replicate-oracle-tests/`. Recording it here before PR 5 runs is what
stops it becoming a tester BLOCK.

**The latent defect gets an issue.** The `get_ratios()` NULL-vs-NULL block at
`test-nonprob-bootstrap-variance.R:183` is filed rather than fixed. It is
pre-existing and its repair depends on what `get_ratios()` should return.
It is filed as issue #292,
https://github.com/JDenn0514/surveycore/issues/292.

**E-4 — added 2026-09-29, from PR 1's reviewer; the fourth erratum.**
`test-spec.md` row 4.4 and `implementation-plan.md` PR 1 AC-5 both say the
diff of `tests/` holds "no other changed line carrying the literal
`1 / n_rep` or `(n_rep - 1) / n_rep`". That is unreachable as written. The two
assertions this PR adds to pin the divergence are
`sqrt((n_rep - 1) / n_rep)`, and that expression contains the second literal.

Measured on the merged branch: four changed lines carry
`(n_rep - 1) / n_rep` — two deleted, the old ratio assertions the plan orders
removed, and two added, the new ones — plus one deleted line carrying
`1 / n_rep`, the retargeted stored default. Six lines, every one accounted for
by a task the plan names.

Read the criterion as scoped to lines that assert an *old default as a stored
value*. There is one such line and the PR deletes it. A line that uses the
same expression to assert the *size of the documented divergence* is what this
work sets out to add and cannot be what the criterion excludes.

This is the same failure shape as E-1: a closed count stated in one artifact
that another artifact's own instructions make unreachable. It is the fourth in
this arc and the pattern is now worth naming in the retrospective — a count
and the prose governing it should live in the same artifact.

---

## HOLD — orchestrator (PR 1 CI) — 2026-09-29 15:45

**Classification**: `ci-failure`, external cause. Not a defect in PR 1 and not
fixable inside this arc.

**Where**: PR #293, five of six CI checks red at
`r-lib/actions/setup-r-dependencies@v2`, about one minute in, before any
surveycore code runs. `windows-latest` was still pending when this was
written.

**What**: pak cannot resolve a dependency.

```
! Could not solve package dependencies:
* deps::.: Can't install dependency surveytidy (>= 0.5.0)
* surveytidy: Can't find package called surveytidy.
```

**Root cause, measured**: `surveytidy` was archived from CRAN on
**2026-09-27 19:00**. `surveytidy_0.6.0.tar.gz` now sits in
`https://cran.r-project.org/src/contrib/Archive/surveytidy/` and the package
is absent from the active `src/contrib/PACKAGES` index. pak resolves against
the active index, so an archived package reads as missing.

The timeline closes the case:

| Date | Event |
|---|---|
| 2026-09-23 02:30 | `develop` CI green at `73879a0`, same DESCRIPTION |
| 2026-09-27 19:00 | CRAN archives `surveytidy` 0.6.0 |
| 2026-09-29 15:34 | PR #293 CI fails at dependency resolution |

**PR 1 is not implicated.** It touches six files and `DESCRIPTION` is not one
of them; `git diff --stat develop..HEAD -- DESCRIPTION` is empty.
`surveytidy (>= 0.5.0)` sits at DESCRIPTION line 53 in both `73879a0` and
`develop`'s tip `fd621a1`, byte-identical. The only commit between them,
`fd621a1`, touched archive and plan files only — and it reached `develop` by a
direct push that bypassed the required check, which is why `develop` shows no
red run of its own.

**`develop` is broken too.** Any PR opened against it today fails the same
way. This is a repository-wide blocker that PR 1 merely surfaced first.

**A correction to the record**: an earlier note in this session inferred from
commit `3d65f2b fix(ci): remove surveytidy from Suggests — not on CRAN` that
the package had never been on CRAN. That was wrong. It was on CRAN at 0.6.0
and has been archived; `3d65f2b` describes a state that predates its
publication, and `be09768`'s re-add was legitimate at the time.

**Usage, which bounds the options**: every `surveytidy` reference under `R/` is
text inside a `cli` message (`{.fn surveytidy::filter}`), so there is no
runtime dependency. Under `tests/` the calls are real — `surveytidy::filter()`,
`surveytidy::group_by()` and similar — but **35 blocks carry
`skip_if_not_installed("surveytidy")`**, so they skip cleanly when it is
absent rather than failing.

`https://github.com/JDenn0514/surveytidy` is public, so a `Remotes:` entry can
resolve it.

**What I need**: a choice of remedy. Every option is a `DESCRIPTION` or CI
change, outside this arc's write surface and affecting the whole repository,
so it wants its own branch merged to `develop` before PR #293 can go green.

### The cause runs deeper than surveytidy — surveycore itself was archived

Investigating the remedy turned up the real chain. Recorded because it
changes the order of any fix and reaches well past this arc.

| Time (2026-09-27) | Event |
|---|---|
| — | `marginaleffects` 1.0.0 reaches CRAN (local machine is pinned at 0.32.0) |
| 18:00 | CRAN archives **`surveycore` 1.0.0** — `tests` ERROR on 8 of 12 flavors |
| 19:00 | CRAN archives **`surveytidy` 0.6.0** — cascade; it Imports `surveycore (>= 0.8.2)` |

`surveytidy`'s own checks were **OK on all 13 flavors** at archival. It did
nothing wrong; it fell with its dependency.

**Why surveycore's CRAN tests failed.** `[ FAIL 10 | WARN 335 | SKIP 426 |
PASS 11128 ]`, every failure in the grouped `get_diffs()` path:

- `test-analysis-diffs-helpers.R` rows 478, 668, 669, 858, 1038, 1334
- `test-analysis-diffs.R` rows 471, 490, 562, 1026

Two symptoms, one cause. `marginaleffects` 1.0.0 returns one fewer row in the
grouped path — `nrow` 3 against 4, 5 against 6. The absent row makes a group
comparison evaluate to `NA`, and `.build_diffs_output()` tests it with a bare
`if`, so three blocks die on `missing value where TRUE/FALSE needed` at
`if (grp_match)`, `if (match_g)` and `if (grp_ok)`.

**This machine cannot see the defect.** Local `marginaleffects` is 0.32.0 and
CRAN's is 1.0.0, a major bump. `DESCRIPTION` sets `marginaleffects (>= 0.18.0)`
with no upper bound, so the package claims compatibility it does not have. The
baseline `FAIL 0` at the head of this run and every gate table in it were
measured against 0.32.0 and say nothing about 1.0.0.

**The fix order is forced, and it is the reverse of the one chosen.** The user
selected "fix surveytidy and resubmit to CRAN". surveytidy cannot return
first: CRAN will not accept a package whose Imports are absent. The order is

1. make `.build_diffs_output()` NA-safe and correct against
   `marginaleffects` 1.0.0, under a real 1.0.0 install;
2. resubmit `surveycore`;
3. resubmit `surveytidy`, unchanged.

Step 1 is its own arc. It is not a replicate-scale change, it touches
`R/analysis-diffs*.R`, and nothing in this arc's write surface reaches it.

**Bearing on PR #293.** None of it is caused by PR #293 and none of it is
fixed by changing PR #293. The PR stays open and reviewed. Note for whoever
resumes: once `marginaleffects` 1.0.0 is installed locally, the baseline
becomes `FAIL 10`, not `FAIL 0`, and every gate figure in this run needs
re-measuring before it can be compared.

**E-5 — added 2026-09-29, from PR 2's reviewer; the switch-line numbers are stale.**
`spec.md` and `implementation-plan.md` both name `R/core-constructors.R:807`
for the JKn default and `:813` for the bootstrap default. PR 1's roxygen
rewrite added 44 lines above them, so the true positions are now:

| Default | Plan says | Actually at |
|---|---|---|
| `JKn = 1,` | `:807` | **`:851`** |
| `bootstrap = 1 / (n_rep - 1L),` | `:813` | **`:861`** |

Measured on `d11d1f8`. Line 807 now holds a bare `}` and line 813 holds
`data,`.

This is not cosmetic. **PR 3 and PR 4 both run mutation checks that edit these
lines by number.** A builder following the plan literally would edit unrelated
code: mutating `}` either breaks the parse or changes nothing, and a mutation
that changes nothing produces a green re-run that reads as "the assertion did
not turn red" — the exact false negative the mutation check exists to prevent.

Every remaining dispatch must carry `:851` and `:861`, and must tell the
builder to confirm the line content before editing rather than trusting the
number.

**Tolerance rule for the rest of the arc — settled by PR 2's reviewer.**
The tester asked whether ten bare `expect_equal()` calls breach Tolerance
Integrity by taking testthat's 1.49e-8 default where the test-spec writes
1e-8. Ruling: **not a breach, and do not add explicit tolerances.**

Three reasons, the first decisive. All 16 pre-existing stored-scale assertions
in `test-constructors.R` are bare `expect_equal()`, including line 691, which
PR 1 shipped and PR 1's reviewer passed; adding ten explicit tolerances in
PR 2 would state two different bars for one quantity in adjacent blocks. The
band between 1e-8 and 1.49e-8 is unreachable here — measured gaps are `0e+00`
and a wrong default opens a gap of 0.05 or 0.0026, four to five orders of
magnitude clear of both. And the distinction is principled, not convenient:

> Write `tolerance =` where the row's **assert** column names it — rows 1.9,
> 3.1 and 3.2. Leave it bare where only the §1 preamble maps the quantity to
> a tolerance band.

PR 2's builder already followed this without being told. PRs 3, 4 and 5 follow
the same rule.

Two smaller rulings from the same review, both acceptable as built: row 1.1
may omit `rscales = rep(1, n_rep)` (plan AC-1 never names it, rows 1.2 and 1.5
bracket it, no branch lies between); and row 1.3 may subselect generated
columns, because `testing-standards.md` bans generator *parameters* and none
were added. **Caution for PR 3:** rows 1.6 and 1.8 must build their frames
inline, because there the frame content is the thing under test.

**E-6 — added 2026-09-29, before PR 3 dispatch; a task orders a forbidden read.**
`implementation-plan.md` PR 3, task 3, says of row 1.7: "Read the nine values
from `test-spec.md` §What this work changes and transcribe them. Write no
value of your own."

The builder contract forbids reading `test-spec.md`. `.claude/agents/builder.md`
lists it under **Never**, and every dispatch in this arc repeats the
prohibition. A builder that obeys the task breaks the contract; one that obeys
the contract cannot do the task as written.

**Resolution: the builder takes the nine values from `spec.md` §Default scale
table, After column.** That table carries all nine types and is the spec's own
statement of them, so "write no value of your own" is still satisfied — the
values come from an artifact, not from the builder. No value is lost:

| `type` | After |
|---|---|
| `"JK1"` | `(R - 1) / R` |
| `"JK2"` | `1` |
| `"JKn"` | `1` |
| `"BRR"` | `1 / R` |
| `"Fay"` | `1 / R` |
| `"bootstrap"` | `1 / (R - 1)` |
| `"ACS"` | `4 / R` |
| `"successive-difference"` | `4 / R` |
| `"other"` | `1` |

This is the fifth instance in this arc of one artifact depending on another
that its reader may not open, and the shape is now familiar enough to name.
`archive/domain-marker-logical/` D23 records the same failure costing a
tester BLOCK: "a closed list that lives in only one of the two artifacts
cannot be hit". A plan task addressed to the builder must cite only what the
builder may read.

---

## HOLD — builder (PR 3) — 2026-09-29 — RESOLVED by the orchestrator, no user block

**E-7 — `spec.md` E7 is wrong about the single-row frame, and §Errors and
warnings is missing a sixth class.**

E7 says: "A single-row frame and an all-NA outcome column each reach the same
stored `scale` as any other frame ... Those two frames are ordinary inputs and
not refusals: the constructor builds each one and raises no condition."

The all-NA half is right. The single-row half is false. Measured:

- `.validate_data()` raises `surveycore_error_single_row` at
  `R/core-validators.R:109`, before the scale switch runs;
- `tests/testthat/test-constructors.R:969` has pinned that refusal since
  PR #76, under the comment "data has 1 row (error — matches survey package
  behavior)".

So the constructor has never built a one-row frame, the refusal is deliberate,
it matches the `survey` package, and it was already under test before this arc
began. PR 3's criterion 1 asks for a construction that cannot happen.

§Errors and warnings compounds it. That section lists five classes firing
before the default is computed and calls them exhaustive for this purpose.
`surveycore_error_single_row` is a **sixth**, and it is absent.

**Resolution — both halves, decided here and not escalated.** The behaviour is
not in question: it is fixed, pinned and matches `survey`. Only the spec's
description of it is wrong, so there is no choice of behaviour for the user to
make, and the two candidate repairs are additive rather than exclusive.

1. **Row 1.6 uses a two-row frame**, the smallest that builds. The property the
   row exists to test is that the stored default depends only on `type` and
   `R` and on nothing in the data; a two-row frame tests that exactly as well
   as a one-row frame would, and unlike a one-row frame it can be constructed.
2. **The single-row refusal is asserted as a fifth refusal**, by `class =` and
   with no snapshot, beside criterion 2's four. It is the same category as
   those four and the spec's own table should have carried it.

Neither half weakens a criterion. Criterion 1 keeps its claim — that the
smallest buildable frame stores the same two values as the 20-column frame —
and criterion 2 gains one true refusal.

**Note the repetition.** §Errors and warnings already records one correction of
exactly this kind: "E7 first said a zero-weight row among positive rows reaches
the stored default. It does not: the constructor refuses that frame." E7 has
now been wrong twice, in the same way, about which frames the constructor
refuses. A reader of the archived spec should treat E7's list of
"ordinary inputs" as unverified and check each against
`R/core-validators.R`.

**E-8 — added 2026-09-29, from PR 3's reviewer; three more stale plan
references, all in PR 4's section, plus one trap.**

Verified against the tree PR 4 will branch from.

| What | Plan says | Actually at | File |
|---|---|---|---|
| `as_survey_nonprob()` `@details`, the Wu (2022) / Chen et al. (2021) paragraph | `:1306-1311` | **`:1354-1359`** (citation on `:1357`) | `R/core-constructors.R` |
| the two-phase `phase1` copy | `:1151` | **`:1199`** | `R/core-constructors.R` |

Both `R/` numbers are stable for PR 4, because PR 3 changes no `R/` file. The
`tests/testthat/test-constructors.R` numbers below are read on PR 3's branch
and hold once PR 3 merges, which is the base PR 4 cuts from.

**AC-4's duplication is two-sided, and the earlier ruling stands with a
correction.** PR 2's reviewer found PR 4's AC-4 duplicates the nonprob SE-ratio
assertion PR 1 shipped, and ruled no re-scope but a cross-reference comment.
That holds. What it missed: the nonprob `1 / n_rep` stored value is **also**
already asserted, at `test-constructors.R:2482`, and the nine-type table
asserts it again at `:1002`. So PR 4's cross-reference should name **both**
`:1002` and `:2482`, not one of them.

**Do not use the JK2 block at `test-constructors.R:652` as row 3.1's
template.** It is titled "as_survey_replicate() and as_survey_nonprob() agree
on JK2 scale" and it asserts `d_rep@variables$scale` against
`d_np@variables$scale` — two stored scales compared to each other, with no
literal anywhere. `.claude/rules/testing-surveycore.md` forbids exactly that:
"Never assert one side's stored scale against the other side's. Assert each
against a literal." Row 3.1 asks for the same shape of comparison and must
assert each side against `1`, not against the other. The JK2 block is
pre-existing and outside this arc's surface, so it is not PR 4's to fix — but
copying it would import the defect.

**Four non-blocking findings on PR 3 itself**, none affecting the verdict.
One is fixed: the fifth-refusal comment claimed "neither block repeats the
other's coverage" while also saying both reach the same guard, which cannot
both be true — `.validate_data()` Error 4 tests `nrow` only, so the two blocks
hit an identical line set. Corrected in commit `81d3249` to say the assertion
adds no line coverage and earns its place by completing the refusal inventory.
The other three are cosmetic and left alone: three block-header line numbers
in `audit.md` sit 4-7 lines low because they cite the block body rather than
the `test_that(` line; `audit.md` mislabels testthat's bare default as 1e-10
where it is 1.49e-8; and `audit.md` does not record the `air format --check`
result.

**E-9 — added 2026-09-29, from PR 4's reviewer; the sixth instance of one
pattern, and the reason to stop treating them as separate errata.**

PR 4's tester found row 2.3 built on two seeded 40-row frames where the
test-spec prescribes four-row literals, and referred it up. **Ruling:
acceptable, and the divergence belongs to the plan rather than the builder.**
Plan AC-1 and AC-2 never transcribe the six prescribed values, so a builder
forbidden to read the test-spec could not have hit them. The row was
unhittable to the letter from the artifacts the builder is allowed to open.

The substitution costs nothing. Exactness on these frames is **structural, not
seed-dependent**: any draw from `y1` in 2:30 and `wt` in 1:9 at n = 40 keeps
every partial sum an exact integer well under 10,800, so both accumulation
routes agree bit-for-bit whatever the ordering.

**This is the sixth instance of one failure**, and the pattern is now the
arc's main finding about its own process:

| Erratum | The closed thing | Why it was unreachable |
|---|---|---|
| E-1 | "exactly one block breaks" | scoped to stored defaults only |
| E-2 | row 4.5's two-file list | two more files broke |
| E-4 | AC-5's "no other line" | the new assertions contain the literal |
| E-6 | row 1.7's nine values | ordered a forbidden `test-spec.md` read |
| E-7 | criterion 1's one-row frame | the frame cannot be built |
| E-9 | row 2.3's four-row literals | plan never transcribed them |

Five of the six share a mechanism: **a count, list or fixture fixed in one
artifact, addressed to a reader not permitted to open it.** `archive/
replicate-oracle-tests/` records the same shape three times (S3, S6, N3) and
`archive/domain-marker-logical/` D23 records it costing a tester BLOCK.

The rule that would have prevented all five: **a plan task addressed to the
builder must transcribe every closed value it requires, because the builder
cannot open the test-spec that holds them.** Naming the source is not enough
when the source is forbidden. This belongs in the pipeline's planner guidance,
not in a seventh erratum on a future arc.

**What PR 5 must know** — verified by PR 4's reviewer across the whole arc.

1. **E-2's four-file list is complete and correct arc-wide**, measured over
   `076bafe..HEAD`: `test-constructors.R`, `test-variance-replicate.R`,
   `test-nonprob-bootstrap-variance.R`, `test-analysis-corr.R`. **Zero**
   `tests/testthat/_snaps/` changes.
2. **The arc's base for the closing sweep is `076bafe`**, which is
   `d11d1f8^` — the commit `develop` sat at before PR 1. Note `076bafe` is the
   CI `Remotes` fix, which is not part of this arc but precedes PR 1 on
   `develop`.
3. **Assert file names, not a commit range.** Every PR merged by squash, so
   the SHAs in the plan and in any shipper record do not exist on `develop`.
   A range-based sweep will mislead.
4. **`NEWS.md` takes 2.6%, the rise.** The nonprob help page already carries
   2.5%, the fall. Both are correct in their own direction and neither may be
   copied into the other's place.
5. The changelog entry still owes two items `spec.md` §The changelog entry
   names: the **E5 window**, and the statement that this work clears **one of
   the two** sanctioned exceptions in `.claude/rules/testing-surveycore.md`,
   not both.
6. If CI turns red, read it against `surveytidy`/`marginaleffects` before
   treating it as a regression — see the CI HOLD above and issue #294.

**E-10 — added 2026-09-29, from PR 5's reviewer; the rule this work
invalidated, and one wording fix.**

`.claude/rules/testing-surveycore.md` §Sanctioned exceptions said **two**
blocks in `tests/testthat/test-variance-replicate.R` break the oracle rule's
normal shape on purpose, and named the JKn and bootstrap `expect_failure()`
wrappers as one of them. PR 1 deleted all six wrappers. The rule was
therefore false from PR 1's merge onward.

**Fixed here rather than deferred to an issue, and the reason matters.**
`.claude/rules/` auto-loads into every agent's context in this repository. A
stale rule is not a documentation nicety — it is an instruction that a future
builder or reviewer will act on. This one told them the wrappers exist, so an
agent could restore them, or read their absence as a violation of the rule
they were auditing against. The section now says one exception remains, names
the Fay block as that one, and records that the wrappers were removed by #253
and must not be restored.

This widens PR 5's write surface by one file, to three. `spec.md` §Scope
required this work to *record* that it clears one of the two exceptions, which
the changelog does; it did not foresee that the rule stating the count would
need editing. Noted rather than hidden.

**A wording fix in the changelog, also from this review.** Its verification
list called both `R CMD check` notes "pre-approved". Only one is:
`.claude/rules/r-package-conventions.md` pre-approves `checking CRAN incoming
feasibility` and `no visible binding for global variable`. The second note
this arc carries, `checking for hidden files and directories`, is a
pre-existing note that `.Rbuildignore` causes and that no single PR can fix —
tolerated, not pre-approved, as `archive/as-svydesign-bridge/` AC-6 records.
The list now names both notes and distinguishes them.

**The reviewer's closing addition to the central finding.** Beyond the
closed-count pattern, it names one thing a reader of this archive most needs:
this arc moved a published standard error **with no runtime signal, by
explicit decision** (`spec.md` §A runtime transition signal was weighed and
declined). `NEWS.md` is therefore the only artifact that explains a 2.6% move
to a user who hits it. That decision is defensible and recorded, but it puts
unusual weight on one paragraph of release notes.
