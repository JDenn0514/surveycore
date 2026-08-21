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
