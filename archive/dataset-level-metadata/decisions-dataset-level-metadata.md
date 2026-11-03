# Decisions Log — surveycore dataset-level-metadata

This file records planning decisions made during dataset-level-metadata.

---

## HOLD — spec-review (Stage 3) — 2026-08-19

**Where**: Stage 3 spec review, `spec-review.md` Pass 1
**What**: Five findings are judgment calls the review cannot resolve; verdict is NEEDS-DECISION.
**Why I can't decide**: Each either adds behavior beyond the design plan or re-opens a choice the plan made; two have conflicting lens recommendations.
**Options**: See `spec-review.md` items B10, B11, R1, R2, R3.
**What I need**: One choice per item from the user.

1. **B10** — near-miss typo warning for reserved keys: setter + extractor / setter only / none.
2. **B11** — `set_field_dates()` deletion sentinel, and the `Field dates:` print line when stored dates and `field_period` disagree.
3. **R1** — `fill` vocabulary (`NA` and/or `NA_character_`) and whether the filled value is type-matched per key.
4. **R2** — promoted attributes on `@data`: keep-and-document vs strip-on-promote.
5. **R3** — field-date argument and return names: `start/end/period` (per plan) vs `field_*`, and whether the bare `start`/`end`/`period` key names are rejected with a pointer.

---
## Resolution — 2026-08-19

**Signal resolved**: HOLD — spec-review (Stage 3), all five judgment calls
**Authorized by**: user
**Resume from state**: DRAFT (Stage 3r resolve pass)

### Questions & Decisions

**Q1 (B10): Key vocabulary — open, near-miss policy, or closed?**
- **Decision:** CLOSED vocabulary. Exactly six keys are valid:
  `survey_name`, `data_name`, `vendor`, `field_start`, `field_end`,
  `field_period`. Any other key errors, and the message names the six
  valid keys plus the nearest match when one is close.
- **Rationale:** Nothing in the measured adldata corpus needs an open key
  today. Closed → open later is additive and backward-compatible; open →
  closed would break users. Closing removes the roster attribute, the
  `Other keys:` print line, the typo problem, and the malformed-roster
  construction-abort path.
- **Supersedes:** plan §2's open-key recommendation and spec §II.2's
  rejected-key machinery. Cascades over findings B3 (roster — now gone),
  B5 (read order simplifies to six fixed names + legacy `dates`), B7
  (a column-named key is now simply an unknown key → error), B10, R12
  (only six fixed attribute names are ever written), S4.

**Q2 (B11 + user proposal): field dates API shape**
- **Decision:** SPLIT the prose period from the concrete dates.
  - `set_field_dates(x, field_start, field_end)` — dates only. An
    omitted argument is left unchanged; an explicit `NULL` deletes.
  - `set_field_period(x, period)` — plain scalar setter, same shape as
    `set_vendor()`. `NULL` deletes.
  - `extract_field_dates(x)` returns `list(field_start = <Date>,
    field_end = <Date>)`; `extract_field_period(x)` returns
    `character(1)`.
  - Print: when both dates and a period are set, show both —
    `Field dates: 2024-04-01 to 2024-05-31 (April-May 2024)` — so drift
    is always visible.
- **Rationale:** field dates are structured data; the period is display
  prose. One job per setter removes the mixed NULL semantics and needs
  no deletion sentinel.
- **Supersedes:** plan §4's `set_field_dates(x, start, end, period)`
  signature and spec §VII.2/§IX. Export count becomes 12 (6 setters,
  6 extractors).

**Q3 (R1): `fill` vocabulary and fill typing**
- **Decision:** Accept both `NA` and `NA_character_` (widen the shared
  check). In list format the filled value is type-matched per key
  (`as.Date(NA)` for date keys, `NA_character_` for the character keys).
  In `data_frame` format the filled value is always `NA_character_`.

**Q4 (R2): promoted attributes on `@data`**
- **Decision:** Keep and document. `@data` stays byte-identical to the
  input. The spec states `@metadata@dataset_metadata` wins on every read
  path of a survey object; roxygen warns that rebuilding from `d@data`
  re-promotes the original attributes. One test locks the resurrection
  behavior.

**Q5 (R3): field-date naming**
- **Decision:** `field_*` names everywhere — arguments, returned list
  names, stored keys. No short-name vocabulary.

### Outcome

Spec and test-spec are revised under a closed six-key vocabulary with a
split dates/period API; all 45 unambiguous findings applied in the same
pass.

---

## Resolution — plan-review Pass 1 revisions — 2026-08-19

**Signal resolved**: plan-review Pass 1 FAIL (B1, R1–R18, S1–S18)
**Authorized by**: coordinator (all findings unambiguous; option choices
directed by the coordinator)
**Resume from state**: PLAN DRAFT (revision pass; plan v1.1)

### Context

The 5-lens plan review failed implementation-plan.md v1.0 (4 PRs). The
review confirmed the §I.5 B/C swap sound. The failures were PR sizing,
task structure, criterion precision, and unscheduled spec items. Several
findings offered alternatives; this entry records the choices taken.

### Questions & Decisions

**Q1 (B1): How to split the oversized exports PR?**
- **Decision:** Three-way split along the dependency grain: PR 2 read
  path (`extract_dataset_metadata()` + read helpers), PR 3 write path
  (`set_dataset_metadata()` + parser parameterization), PR 4 the ten
  convenience wrappers + docs surface (pkgdown, Rd links,
  `extract_metadata()` note).
- **Adjustments to the review's row lists, forced by dependencies:**
  E10 moves to PR 4 (needs `extract_data_name()`); S15e moves to PR 3
  (exercises the general setter only); S24/B2 split across PR 3 and
  PR 4 (the wrappers do not exist in PR 3); each exporting PR writes
  its own roxygen and NAMESPACE entry, because an undocumented or
  unexported function fails that PR's own check and test gates — PR 4
  keeps the family-wide docs items.

**Q2 (R5): Where do the PR 1 helpers with no PR 1 callers live?**
- **Decision:** Option (a). `.dataset_metadata_or_empty()` and
  `.coerce_field_date()` move to PR 2 with their first callers. PR 1
  implements `.check_dataset_key_value()` with the `error`/`val` paths
  only; `mode = "skip"` lands in PR 2 and `key_style = "arg"` lands in
  PR 4, each with its first caller. Coverage notes updated to match.

**Q3 (S1): Where do vignette, NEWS, and DESCRIPTION go?**
- **Decision:** A final docs PR (`feature/dataset-metadata-docs`,
  PR 7, 3 tasks, own vignette/pkgdown gate). The R13 vignette sentence
  on `extract_metadata()`'s carve-out ships there.

**Q4 (S2): Serial chain or declared parallelism?**
- **Decision:** Declare the parallelism the dependencies support:
  PR 1 → PR 2 → PR 3 → PR 4 → PR 5 → PR 7, with PR 6 (print) dependent
  on PR 3 only and free to ship concurrently with PR 4 and PR 5. The
  print fixtures apply state via setters (R7 rule), so print depends on
  the exports, not on promotion. PR 6's write surface is disjoint from
  PR 4's and PR 5's. PRs renumbered 1–7 in shipping order.

**Q5 (S4): Where do the DM-7a–d error-table rows land?**
- **Decision:** In PR 5 (promotion), the PR whose code first raises
  them. All other DM rows stay in PR 1; every raising PR carries a
  "table text matches snapshot" criterion (S9).

**Q6 (S18): NEWS heading in the docs PR?**
- **Decision:** `# surveycore (development version)`. `/merge-main`
  renames the heading at release; the plan states this so release prep
  extends, not re-creates, the section.

### Outcome

implementation-plan.md revised to v1.1 (7 PRs, ≤10 tasks each,
interleaved RED/GREEN/VERIFY, explicit row enumeration, corrected
coverage map, parallelism declared). All B1/R/S findings resolved; no
user decision pending.

---

## Resolution — plan-review Pass 2 revisions — 2026-08-19

**Signal resolved**: plan-review Pass 2 FAIL (2B1, 2R1–2R13, 2S1–2S14)
**Authorized by**: coordinator (all findings unambiguous; the test-spec
edit and the option choices directed by the coordinator)
**Resume from state**: PLAN DRAFT (revision pass; plan v1.2)

### Context

Pass 2 verified all 37 Pass 1 findings resolved and the five documented
adjustments sound, then failed the plan on new findings the re-partition
introduced. Three choices in this pass were not predetermined by the
review text alone; this entry records them.

### Questions & Decisions

**Q1 (2R1/2R8/2R9): Row IDs live in the plan, not the test-spec.**
- **Decision:** Bump test-spec.md to v2.2 — additive only, authorized by
  the coordinator. The formerly plan-local rows move into the test-spec
  verbatim with their IDs kept: SR1, X1, E23 → §7; SR2, X2–X6, SC1–SC5
  (new IDs for the five reused setter convention-error cases) → §6;
  X7, X8 → §8; X9 → §9. No v2.1 row or contract changed. The frozen copy
  at `plans/test-spec-dataset-level-metadata.md` is refreshed in sync.
- **Rationale:** Testers consume test-spec.md only; a contract that
  lives in plan prose would never be written.

**Q2 (2B1): `_pkgdown.yml` placement — reversal of the v1.1 deferral.**
- **Decision:** Each exporting PR appends its own reference entries:
  PR 2 adds `extract_dataset_metadata` to "Metadata — extractors";
  PR 3 adds `set_dataset_metadata` to "Metadata — setters"; PR 4 adds
  the ten wrappers. The v1.1 "defer to PR 4" choice is reversed.
- **Rationale:** The reference index is exhaustive (no catch-all) and
  CI builds the site on every PR, so a deferred entry fails PR 2 and
  PR 3 at their own gates. No effect on PR 6 parallelism (PR 6 changes
  no export and does not touch `_pkgdown.yml`).

**Q3 (2R13): Where is the §VII.1 wrapper `setter_empty` template
recorded?**
- **Decision:** The preferred fix. PR 1 task 3 records the §VII.1
  wrapper variants (the four scalar-wrapper template and the
  `set_field_dates()` template) on the M-4 row of
  `plans/error-messages.md`. PR 4 asserts its wrapper snapshots against
  that row. The alternative (assert against spec §VII.1 and add the
  file to PR 4's surface) is rejected: the error table stays complete
  from the start.

### Outcome

implementation-plan.md revised to v1.2 (7 PRs; task counts 8/10/10/9/
9/8/3; scoped snapshot guard per 2R10; RED/GREEN re-pairing in PR 2
documented as a deviation; `expect_dataset_roundtrip()` moved to PR 5;
coverage map corrected). test-spec.md bumped to v2.2 and its frozen
copy refreshed. All Pass 2 findings resolved; no user decision pending.

---

## HOLD — plan-review Pass 3 — 2026-08-20

**Where**: Stage 2 plan review, implementation-plan.md v1.2, findings 3J1 and 3J2
**What**: Two judgment calls surfaced by the Pass 3 lenses need a user decision before Stage 3 resolve.
**Why I can't decide**: Both have two defensible options with real tradeoffs; the plan and spec do not settle them.
**Options**:
- 3J1 (PR 5 bundling): (a) keep the bundle — the nonprob weighting-history fix is one line and P17b needs it in the same PR; (b) hoist the fix + P17b into a small standalone PR ahead of PR 5, dropping PR 5 to promotion-only (adds an eighth PR, shrinks PR 5 below the five-file bar).
- 3J2 (DM-5b interim state): (a) add a PR 3 criterion that the completed DM-5b renders through the extractor path; (b) declare PR 2's hint-less rendering deliberately provisional until PR 3.
**What I need**: One choice for each of 3J1 and 3J2.

## Resolution — 2026-08-20

**Signal resolved**: HOLD — plan-review Pass 3 (3J1, 3J2)
**Decision**: 3J1 → option (a): keep the PR 5 bundle; document the over-bar rationale (one-line nonprob fix, P17b needs it in-PR). 3J2 → option (a): add a PR 3 criterion that the completed DM-5b renders through extract_dataset_metadata(), alongside the "PR 2's E15 snapshot unchanged" criterion.
**Authorized by**: user
**Resume from state**: DRAFT (Stage 3 resolve, plan-review Pass 3 findings)

---

## HOLD — pipeline-ship (coordinator) — 2026-08-21 14:20

**Where**: Step 0 baseline check, profile gate 6 (`pkgcheck`), all 7 PRs
**What**: The `pkgcheck` gate named in test-spec §13 and in plan note 4S11 cannot run in this environment.
**Why I can't decide**: Two authorities disagree. Test-spec §13 lists `pkgcheck` as a gate that must pass, and plan note 4S11 says it runs locally. Commit `7fd2095` removed pkgcheck from this repo's required checks with the message "pkgcheck is not required for merge" and "not ready to fix pkgcheck failures". Waiving a named gate on my own would be a gate relaxation, which the reviewer must treat as STOP.
**Options**:
- (a) Waive the gate. Testers log `pkgcheck` as SKIPPED with the `7fd2095` reason. It is not a gate failure. Every other gate stays mandatory.
- (b) Install universal-ctags, then run the gate. Commit `7fd2095` says pkgcheck failures exist and are unfixed, so the baseline is likely dirty and every PR BLOCKs on pre-existing problems.
- (c) Halt the feature, fix pkgcheck on `develop` first, then start the pipeline.
**What I need**: One choice among (a), (b), (c).

## Resolution — 2026-08-21 14:22

**Signal resolved**: HOLD — pipeline-ship (coordinator), `pkgcheck` gate unavailable
**Decision**: Option (a). The `pkgcheck` gate is waived for all 7 PRs of this feature. Testers record it in the `audit.md` Profile gates table as `SKIPPED — not a merge requirement (commit 7fd2095); ctags absent in this environment`, and it does not count as a gate failure. Reviewers treat this waiver as authorized, not as a tolerance or gate relaxation. All other test-spec §13 gates stay mandatory: `document`, `test`, `run_examples`, `R CMD check --as-cran`, `pkgdown`, `covr`, and the CRAN cookbook scan.
**Authorized by**: user
**Resume from state**: PLAN_READY (Step 0 baseline check continues)

---

## Note — pipeline-ship (coordinator) — 2026-08-21 15:05

**Not a signal.** Recorded so the reviewer does not read the covr invocation as a gate relaxation.

**Where**: Step 0 baseline check, profile gate 8 (`covr`), all 7 PRs
**Finding**: `covr::package_coverage()` invoked without `NOT_CRAN=true` reports 93.73%, below the 95% floor. Invoked WITH `NOT_CRAN=true` it reports 95.90%.
**Cause**: Ten test files carry a file-level `skip_on_cran()`. `devtools::test()` sets `NOT_CRAN=true` so those files run — the suite passes 12580 tests. Plain `covr::package_coverage()` does not set it, so all ten skip and roughly 3300 lines of source read as untested. The depressed files are exactly the ones behind those skips: `R/analysis-corr-latent.R` (73.89) and `R/variance-twophase.R` (75.98) both leave the low list once the variable is set.
**Consequence**: every tester on this feature invokes covr with `NOT_CRAN=true`, matching how the suite runs under `devtools::test()` and under `R CMD check --as-cran`. The 95% floor and the 98% new-code target both stand unchanged; only the invocation is corrected. `R CMD check --as-cran` independently runs the full suite to `Status: OK`, corroborating that the tests exist and pass.
**Authority**: `r-package-profile.md` gate 8 names the command but not the environment; test-spec §12 states the bar as "98%+ line coverage on the new code; PRs blocked below 95%". Neither is modified by this note.
**Baseline record**: `baseline.md` in this run directory.

---

## Note — pipeline-ship (coordinator) — 2026-08-22

**Not a signal.** Three items the reviewer needs, none requiring a decision.

### 1. The pkgcheck waiver is superseded

Commit `0508e84` (#157) removed the `pkgcheck` gate from the pipeline itself —
it is gone from `r-package-profile.md`, `artifact-schemas.md`, and every agent
definition. The waiver recorded on 2026-08-21 14:22 is therefore moot rather
than a standing exception. No PR on this feature runs or reports pkgcheck.

### 2. PR 1 base drift — repaired, and why its first gate run showed a failure

The PR 1 builder's worktree was created from `main`, not `develop`
(merge-base `2639df2`, the v1.1.0 release commit). Six develop commits were
absent, including `ee46e73`, which deleted the C14 collection-dispatch
snapshot because its text embeds a `vctrs` factor hash that `vctrs` 0.7.3
changed.

That single fact explains the builder's one reported test failure. The
builder asserted the failure was "pre-existing", having reverted two source
files to develop's versions and reproduced it — but that test cannot
distinguish base drift, so the conclusion was wrong. The failure was neither
a code defect nor a develop defect.

Repair: the builder's seven commits were cherry-picked onto `develop` with no
conflicts, then rebased onto develop tip `602f9b0`. `R CMD check --as-cran`
on the repaired branch returns `Status: OK` with `Rd cross-references ... OK`.

The worktree base selection has since been fixed by the user (Orca was
creating worktrees off `main`), so later PRs do not inherit this.

### 3. Two infrastructure defects found and fixed on develop

Both would have blocked every PR of this feature, and neither is attributable
to any agent's work.

| Commit | Defect |
|---|---|
| `7cf0704` | `run-gates.sh` gate 7 measured coverage without `NOT_CRAN=true` while gate 2 set it. Ten test files carry a file-level `skip_on_cran()`, so coverage read 93.73% against a hard 95% floor. Every PR would have failed the covr gate falsely. |
| `dad88d8` | The committed `man/` was generated by roxygen2 7.3.3; the installed version is 8.1.0, which renders `@family` cross-references differently. `document()` rewrote 61 of 85 Rd files, so the document-drift gate would have failed on every PR and every feature PR would have carried all 61 files in its diff. Regenerated once, package-wide, with `Config/roxygen2/version: 8.1.0` recorded. |

`602f9b0` follows up by correcting two stale references to the old
`RoxygenNote` field, in the DESCRIPTION template and in the srr G1.4 claim.

### 4. Pre-existing issues observed, deliberately NOT addressed

Out of scope for this feature; recorded so they are not mistaken for
regressions.

- `devtools::document()` emits 23 warnings of the form `S3 method
  'fitted.survey_glm_fit' needs @export or @exportS3Method tag`. NAMESPACE is
  byte-identical, so nothing in the output changed.
- `devtools::document()` emits roughly 40 `@srrstats is not a known tag`
  warnings. DESCRIPTION has `Roxygen: list(markdown = TRUE)` with no roclet
  entry, so srr's roclet is never registered and every `@srrstats` tag is
  ignored.

---

## Note — pipeline-ship (coordinator) — 2026-08-24

**Not a signal.** Classification of a NOTE that is not on the pre-approved list,
recorded so the reviewer does not treat it as a new NOTE pattern warranting STOP.

### The `checking examples` NOTE is a local timing artifact

PR 1's gate 5 (`R CMD check --as-cran --no-manual`) reports `Status: 2 NOTEs`:

| NOTE | Classification |
|---|---|
| `checking CRAN incoming feasibility` | Pre-approved (`r-package-profile.md`) |
| `checking examples ... [33s] NOTE` | Local timing artifact — see below |

The examples NOTE reads:

```
Examples with CPU (user + system) or elapsed time > 5s
         user system elapsed
get_corr 5.43   0.17     5.7
```

Three facts establish it is not attributable to PR 1 and not a package defect:

1. **PR 1 does not touch `get_corr`.** Its write surface is `R/core-classes.R`,
   `R/utils.R`, `plans/error-messages.md`, two test files, and
   `man/survey_metadata.Rd`. No correlation source file is in the diff.
2. **CI does not reproduce it.** Run `32685871302` on develop at `c356ed0`
   reports `checking examples ... OK` on all four platforms — macOS 12s,
   Windows 24s, Ubuntu release 24s, Ubuntu devel 25s. No individual example
   crosses the 5s threshold on any CI runner. CI is green.
3. **It was invisible in the Step 0 baseline for an environment reason.** The
   baseline ran before `polycor` was installed. `get_corr`'s `@examples` block
   computes a polychoric correlation, which requires `polycor`. With the package
   absent that example did no work; with it installed the example computes and
   takes 5.7s on this machine.

The threshold is a fixed 5s against wall-clock time, so whether it fires depends
on machine speed. This development machine is slower on that example than any CI
runner. CI also sets `error-on: '"warning"'`, so NOTEs do not fail CI in any
case.

**Consequence:** the examples NOTE is non-blocking for every PR of this feature.
It is not a tolerance relaxation and not a gate misclassification — it is a NOTE
whose cause is identified, whose scope is outside this feature, and which the
authoritative CI environment does not produce. Should it ever appear naming a
file inside a PR's write surface, that is a different finding and must be
treated as one.

---

## Note — pipeline-ship (coordinator) — 2026-08-24 (PR 2)

**Not a signal.** Two carry-forwards and one correction, recorded for later PRs.

### 1. Carry-forward to PR 3 — pin the non-character `key` coercion

PR 2's reviewer ruled the builder's handling of a non-character `key` (for
example `key = 1L`) defensible: it passes through `as.character()` and then
fails the unknown-key check as DM-5, rather than inventing an error class
spec §VIII.4 does not list. The reviewer asked that **PR 3 pin this coercion
with a test**, since PR 3 owns the setter side of the same convention. Include
this in PR 3's builder brief.

### 2. The PR 1 handshake on `R/core-classes.R:244` is closed

PR 1's reviewer accepted that line as uncovered, refusing `# nocov` because
PR 2 is forbidden from editing `R/core-classes.R` and so could never remove
the marker. It predicted the line becomes reachable once PR 2 widens the
checker.

PR 2's reviewer confirmed both halves: the `R/core-classes.R` diff is empty,
and the widened checker now returns a coerced `Date` for an ISO string, so the
narrowing at 244 is the only remaining path that can reject a *stored* ISO
string. PR 1's stored-ISO rejection assertion still passes, which proves that
path executed. Refusing `# nocov` was the correct call, and no stale exclusion
was left behind.

### 3. Correction — base R partial matching runs the opposite way

The tester's PR 2 BLOCK text and the coordinator's relay to the builder both
described `attr()` partial matching backwards. We described testing
`attr(df, "vend")`. In fact `attr(x, "vendor", exact = FALSE)` matches a
**stored** attribute named `vendor_extra`; it does not match a lookup of
`"vend"`. A `vend`-only test would have passed whether or not `exact = TRUE`
was present.

The builder caught the error and covered both directions, then mutation-checked
it: flipping `exact = FALSE` at `R/utils.R:589` fails the test 2 of 2. The
tester and the reviewer each verified the `vendor_extra` direction
independently, the reviewer from the code rather than from the mutation report.

Recorded because the same error could recur: when a BLOCK names a specific
test recipe, the recipe is a suggestion and the builder is expected to verify
it actually exercises the contract.

---

## Note — pipeline-ship (coordinator) — 2026-08-24 (PR 3)

**Not a signal.** A correction to a coordinator error, recorded because the
failure mode is worth avoiding again.

### The coordinator relayed a builder pushback that was wrong

PR 3's tester blocked on, among other rows, S15e:
`set_dataset_metadata(x, field_start = NULL, field_end = <earlier than the
stored start>)` succeeding via the three-way effective-pair rule.

The builder reported that this was already covered by pre-existing tests named
"deleting the end date frees a later start", and added what it believed was the
untested mirror direction. The coordinator verified those tests existed at
`f6cbc63`, accepted the characterization, and told the tester its S15e finding
"does not hold".

**That was wrong.** The pre-existing tests delete `field_end` and set
`field_start` LATER than the stored end. S15e names the converse: delete
`field_start` and set `field_end` EARLIER than the stored start. They are
different scenarios. The tester's original finding was correct, and what the
builder added as "the mirror direction" was in fact S15e itself.

The tester declined to adopt the coordinator's characterization, re-read the
diff, and recorded both directions factually. That was the right call.

**Outcome is unaffected**: both directions are now tested, in both input modes,
which is broader coverage than the row required.

**Lesson for later PRs.** The coordinator verified that the builder's cited
tests existed, but did not verify they matched the blocked row's scenario.
Existence is not equivalence. When relaying a builder's claim that a blocked
row is already covered, check the cited test against the row's specific
inputs before telling a tester its finding is void — and never present such a
relay as settled when the tester holds the contract and can check.

---

## Note — pipeline-ship (coordinator) — 2026-08-24 (PR 5)

**Not a signal.** A spec defect found by the PR 5 builder, with measured
evidence, recorded for the reviewer to rule on.

### Spec §XII.4 names `as_tibble()` as an attribute dropper. It is not.

Spec §XII.4 directs the `@section Attribute persistence:` block to name base
`[`, `as_tibble()`, and `merge()` as operations that drop whole-data-frame
attributes. The PR 5 builder measured the actual behavior on this toolchain and
found the claim wrong for `as_tibble()` and imprecise for `[`. I reproduced it
independently:

| Operation | Whole-object attribute |
|---|---|
| `tibble::as_tibble(df)` | **preserved** |
| `df[, c("a", "b")]` (column form) | **DROPPED** |
| `df[1:2, ]` (row form) | **preserved** |
| `merge(df, df2, by = "a")` | **DROPPED** |

Measured on R 4.6.1, tibble 3.3.1.

So the spec's instruction, followed literally, would have shipped a false claim
in user-facing documentation — telling users that converting to a tibble loses
their dataset metadata when it does not. And "base `[`" alone is ambiguous: the
column form drops, the row form does not.

**What the builder did.** It named all three operations the spec requires, but
stated accurately what each one does, so the manual carries no false claim. It
pinned the two operations that genuinely drop — `df[, cols]` and `merge()` —
with behavioral tests. Then it flagged the deviation rather than either
following the spec blindly or silently ignoring it.

**Assessment.** This is the right handling. Documentation that misstates
behavior is a user-facing defect, and it would have been introduced by
following a frozen spec whose factual premise had gone stale. The builder
neither guessed nor suppressed the conflict.

**For the reviewer.** The literal spec instruction and the shipped roxygen
differ. Rule on whether accurate documentation that deviates from a stale spec
claim is acceptable here, or whether the spec must be amended first. Note that
the spec is frozen at SPEC_READY, so amending it is a heavier action than
accepting the correction. The measured table above is the evidence.

---

## Resolution — pipeline-ship — 2026-08-24 (PR 5, §XII.4 spec defect)

**Signal resolved**: the §XII.4 spec defect recorded in the preceding note.

**Ruling by PR 5's reviewer**: the accurate roxygen is ACCEPTABLE; no spec
amendment is required before merge. It names all three droppers the spec asks
for, describes each truthfully, still delivers the warning the spec intended,
and carries the §V.4 resurrection note. A false claim in the manual is the
greater harm. The reviewer also observed the block correctly cites
`survey_data()` rather than `d@data`, which `code-style.md` requires.

**Authorized by**: reviewer, PR 5 review pass 1.

### MANDATORY CARRY-FORWARD TO PR 7 — the same false claim appears twice

The reviewer found that **spec §XII.3 repeats the identical false
`as_tibble()` claim for the VIGNETTE**, which ships in PR 7. The earlier note
in this file covered only §XII.4, the roxygen half.

If PR 7's builder follows §XII.3 literally, the vignette will state that
`as_tibble()` drops dataset metadata while the roxygen corrected in PR 5 says
it does not — shipping both a false claim and self-contradicting documentation.

**PR 7's builder brief MUST carry this measured table** (R 4.6.1, tibble 3.3.1):

| Operation | Whole-object attribute |
|---|---|
| `tibble::as_tibble(df)` | **preserved** |
| `df[, c("a", "b")]` (column form) | DROPPED |
| `df[1:2, ]` (row form) | **preserved** |
| `merge(df, df2, by = "a")` | DROPPED |

The vignette's attribute-persistence paragraph must describe each operation
accurately, exactly as PR 5's roxygen now does, and must stay consistent with
it. Naming all three operations is still required — the spec's intent is to
warn users that metadata can be lost — but the description of each must be
true.
