# Implementation plan — dataset-level-metadata

**Plan version**: 1.7 — frozen at plan-review Pass 7 PASS (2026-08-20)
**Spec**: spec.md v2.1 (SPEC_READY)
**Test-spec**: test-spec.md v2.4 (additive bump authorized by plan-review Pass 4)
**Target version**: 1.1.0.9000 during work; 1.2.0 at release (release bump via `/merge-main`, not in these PRs)
**PR range**: PR 1–7

**Changelog**:
- v1.7 — plan-review Pass 7 verdict PASS (0 blocking, 0 required, 0
  judgment calls). The two Pass 7 suggestions were applied verbatim at
  freeze: PR 6 task 4's cell enumeration completed with the `N` cells
  (`expect_no_error`), and PR 4 task 6's rationale split by cause (DM-8
  order via tasks 1–4; B1 cells via PR 2's guarded reader). No structural
  change; task counts unchanged (7/10/10/9/8/8/3); test-spec stays at
  v2.4. Frozen to `plans/implementation-plan-dataset-level-metadata.md`.
- v1.6 — revised per plan-review Pass 6 (6R1, 6R2, 6S1–6S3): the two
  false-RED expectation lines restated as all-state — PR 6 task 4 (6R1)
  and PR 4 task 6 (6R2 primary, with 6S3's clause tightening folded into
  the same edit); PR 5 task 2's GREEN re-scoped to the promotion path,
  with the DM-7 warning emission landing in task 3 (6S1 primary); the
  durable validator-side `Date(1)` narrowing clause added to PR 1 task 5,
  with a matching PR 2 criterion that C7e stays green and PR 2 makes no
  `R/core-classes.R` edit (6S2). No re-partition; task counts unchanged
  (7/10/10/9/8/8/3); test-spec stays at v2.4.
- v1.5 — revised per plan-review Pass 5 (5R1, 5R2, 5S1–5S6): PR 3
  re-partitioned in one motion (rule-2 property guard un-claimed from
  task 1's skeleton and restored as task 9's true RED per 5R1; the
  parameterization GREEN folded to its first failing consumers per 5S1;
  the conventions/minimal-write seam split per 5S2 — PR 3 stays at 10
  tasks); checker date-branch ownership clauses added to PR 1 task 5 and
  PR 2 task 6, with a coverage-map correction for X10 (5R2); PR 4 task 6
  expectation line split (5S3); SR1 mode stated in PR 2 (5S4); DM-1b
  trigger restated as the test-spec §4 recipe (5S5); DM-4b added to
  PR 4's message-text review list (5S6). Test-spec stays at v2.4 — no
  new test contract.
- v1.4 — revised per plan-review Pass 4 (4R1–4R11, 4S1–4S11): PR 2
  re-partitioned (fill-widening fold per 4S1, reader split per 4R2,
  formatter GREEN moved to the capture task per 4R1, `data_frame`-format
  clauses moved to the format task per 4R4); PR 3 re-partitioned (minimal
  write in the skeleton task per 4R3, unknown-key/delegation split per 4S2,
  effective-pair fold, tasks 7–8 re-scoped); C7f re-paired in PR 1 (4R5);
  criteria added or extended in PR 1/PR 3/PR 4/PR 5 (4R6–4R9, 4R11,
  4S3–4S6); test-spec bumped to v2.4 (new row X15; X3/X10 extensions per
  4R10/4S7); Rd-regeneration counts restated (4S8); PR 5 snapshot
  exemption (4S9); post-ship archive step (4S10); pkgcheck-local note
  (4S11).
- v1.3 — revised per plan-review Pass 3 (3R1–3R13, 3J1(a), 3J2(a), 3S1–3S17):
  task splits and folds in PR 1–PR 5; catch-and-re-raise register split fixed
  in PR 1; M-3 extractor variant scheduled; data-frame-mode clauses attached;
  coverage bar restated (98% target / 95% block); test-spec bumped to v2.3
  with rows X10–X14; snapshot-guard byte-identity lists completed; per-PR
  Notes lines for process rules.
- v1.2 — revised per plan-review Pass 2 (2B1, 2R1–2R13, 2S1–2S14): pkgdown entries per
  exporting PR; test-spec bumped to v2.2 with the SR/X/SC/E23 rows; scoped snapshot guard;
  RED/GREEN re-pairing in PR 2; task folds and splits per 2S1/2R3.
- v1.1 — revised per plan-review Pass 1 (B1, R1–R18, S1–S18).

## v1.5 adjustments

All eight Pass 5 findings are applied. 5R1 is applied in its primary
form: the precondition holds — S24 and X4 are the only PR 3 rows that
operate on a stale object, so no task-2 through task-8 row needs the
rule-2 property guard, and task 9 keeps a true RED. Two notes:

1. **5S1 + 5S2 combined re-partition.** Applied literally, 5S1 keeps a
   GREEN-less task 1 and 5S2 adds a split — 11 tasks, over the cap. 5S2
   states the split "takes the slot from 5S1's fold", so the GREEN-less
   task-1 residue (the `make_dataset_design()` fixture, the SR2 guard,
   and the sibling-snapshot byte-identity verification) merges into the
   split's first half. PR 3 stays at 10 tasks and every PR 3 task keeps
   its prior number (old tasks 1–2 redistribute into new tasks 1–2; the
   v1.4 remapping notes for X15 and X3/X10 stay accurate).
2. **5R2 X10 correction landed in the coverage map, not the write
   surface.** PR 3's write surface needs no `R/utils.R` line: the
   error-mode ISO acceptance ships in PR 2's `.coerce_field_date()`
   routing, and PR 3 only wires the rule-11 delegation that first
   asserts it (X10). The §II.3 helpers coverage-map row now records
   this ownership.

## v1.4 adjustments

All 22 Pass 4 findings are applied in their primary (first-stated) form.
No technical obstacle forced an alternative. Two Fix lines name task
numbers that the same pass's re-partition renumbers:

1. **4R10** names "PR 3 task 5" as X15's claimant. After the 4S2 fold, the
   effective-pair GREEN (rule 12) lives in the merged merge/deletion task
   (now PR 3 task 6), so that task claims X15. Same GREEN, new number.
2. **4S7** names "PR 3 task 4" as the claimant of the X3/X10 extensions.
   After the 4S2 split, X3 and X10 sit in the checker-delegation half (now
   PR 3 task 5), which claims both extensions. Same GREEN, new number.

Neither is a substantive deviation.

## v1.3 adjustments

Three places deviate from a Pass 3 Fix line as written; each keeps the
finding's substance:

1. **3R6 (partial re-scope of the E13–E16 range).** The reader-I task's RED
   gains the data-frame-mode clauses of E1, E2a, E2b, E3, E4a–E4d, E11,
   E12a–E12c, and E16 as the Fix directs. The data-frame clauses of E13, E14,
   and E15 stay with the error-paths task instead: their GREEN (the guard and
   error paths) lands there, and the reader-I GREEN cannot turn them green.
   Placing them earlier would recreate the multi-task red window the rule
   forbids.
2. **3R3 after the 3R2 split.** 3R3 names "task 3" as the landing site for
   the three helpers' GREEN, written before 3R2 split that task. The helpers
   now land with their true first callers across the two halves:
   `.dataset_metadata_or_empty()` and `.get_dataset_metadata_list()` in the
   capture task, `.format_dataset_result()` in the fill/format task.
   **Superseded in v1.4 (4R1):** the fill/format placement was unsound —
   the capture task's RED rows assert the formatted return value, so
   `.format_dataset_result()`'s GREEN (default `format = "list"`,
   `fill = NULL` path) now lands in the capture task. The fill/format task
   keeps the `fill = NA`/`NA_character_` type-matched semantics and the
   roxygen/`@export` block.
3. **3S9 (option choice).** The suggestion offered a label or a test-spec §4
   pointer. The label option is taken: the message-text criteria are marked
   "verified by review against `plans/error-messages.md`". Test-spec §4 is
   not changed for this purpose; the v2.3 bump carries only the new rows.

3R5 is applied in its primary form (catch-and-re-raise in PR 1); no
technical obstacle was found.

## Sequencing note

Spec §I.5 recommends four PRs and orders promotion (its PR B) before the
setters/extractors (its PR C). This plan keeps the spec's content groups but
swaps that pair. Reason: every promotion test in test-spec §8 asserts through
the exported setters and extractors (P1, P13, P17a,
`expect_dataset_roundtrip()`), so the promotion PR is only reviewable alone
when the exports already exist. The plan review confirmed this swap sound in
both directions.

Per plan-review B1, the exports group splits into three sequential PRs along
the dependency grain: read path (PR 2), write path (PR 3), convenience
wrappers (PR 4). Per plan-review R5 option (a), each internal helper ships
with its first caller:

- PR 1 implements `.check_dataset_key_value()` with the `error` mode and the
  `"val"` key style, plus the Layer-1 register split in the
  **catch-and-re-raise form** (plan-review 2R12/3R5): the checker always
  emits the Layer-3 CLI bullets; the S7 validator catches the checker's
  condition and re-raises the plain DM-3a/DM-6c one-liner. Every PR 1 line is
  therefore reachable through the validator; no register argument waits for a
  later caller.
- PR 2 adds `.dataset_metadata_or_empty()`, `.coerce_field_date()`, and the
  checker's `mode = "skip"` parameter (first callers in PR 2).
- PR 4 adds the checker's `key_style = "arg"` parameter (first caller:
  `set_field_dates()`).
- `expect_dataset_roundtrip()` is defined in PR 5, its first caller
  (plan-review 2S2).

Docs placement:

- **`_pkgdown.yml` ships incrementally with each exporting PR** (plan-review
  2B1, reversing the v1.1 deferral): the reference index is exhaustive and CI
  builds the site on every PR, so PR 2 appends `extract_dataset_metadata` to
  "Metadata — extractors", PR 3 appends `set_dataset_metadata` to
  "Metadata — setters", and PR 4 appends the ten wrappers.
- The `extract_metadata()` roxygen `@details` sentence ships in PR 4.
- Vignette, NEWS, and the DESCRIPTION `Description` extension ship in the
  final docs PR (PR 7, per plan-review S1), including the R13 vignette
  sentence on `extract_metadata()`'s carve-out.
- The DM-7a–d error-table rows ship in PR 5, the PR whose code first raises
  them (plan-review S4). All other DM rows — plus the §VII.1 wrapper
  `setter_empty` variants recorded on the M-4 row (plan-review 2R13) and the
  `extract_dataset_metadata()` variant recorded on the M-3 row (plan-review
  3R4) — ship in PR 1. Every raising PR carries a message-text criterion
  verified by review against `plans/error-messages.md` (S9/3S9).

Test-spec v2.3: the formerly plan-local row IDs (SR1, SR2, X1–X9), the E23
row, and the SC1–SC5 convention rows entered test-spec.md at v2.2
(plan-review 2R1/2R8/2R9). Pass 3 adds rows X10, X11, X13 (§6), X14 (§7),
and X12 (§8) — additive bump authorized by plan-review Pass 3 (3R11, 3S11,
3S12, 3S13, 3J2). Pass 4 bumps the test-spec to v2.4: it adds row X15 (§6,
the DM-4b general-setter dual) and extends rows X3 and X10 (§6) — additive
bump authorized by plan-review Pass 4 (4R10, 4S7); every prior row ID is
unchanged. The frozen copy at
`plans/test-spec-dataset-level-metadata.md` is refreshed in sync. Testers
consume test-spec.md only; no contract lives in plan prose.

**`plans/` freeze (plan-review 3S17).** The four frozen planning copies
(`plans/*dataset-level-metadata*.md`) are committed by the coordinator as a
pre-PR-1 step, outside every PR write surface. Builders must not stage
`plans/*dataset-level-metadata*.md` in any PR. (`plans/error-messages.md` is
different: it is a maintained reference and sits inside the PR 1 and PR 5
write surfaces.)

**Post-ship archive (plan-review 4S10).** After PR 7 merges, the
coordinator — outside every PR write surface — moves the four planning
documents to `archive/dataset-level-metadata/` and adds the reference line
for that directory to `CLAUDE.md`.

Forced row reassignments relative to plan-review B1's row lists (each forced
by a dependency B1's lists did not resolve):

- **E10** moves from the read-path PR to the wrappers PR: it asserts through
  `extract_data_name()`, which does not exist before PR 4.
- **S15e** moves from the wrappers PR to the write-path PR: it exercises
  `set_dataset_metadata()` only, and it is the row that covers the
  effective-pair logic in the PR that implements it.
- **S24 and B2 split**: PR 3 asserts DM-8 for `set_dataset_metadata()` (dual
  pattern); PR 4 completes the class checks for the five wrapper setters and
  carries the B2 dual on `set_vendor(old, "x")`. Both duals are required —
  they are distinct contracts, not duplicates (plan-review 2S10).
- **S25a–S25c split** (plan-review 2R5): PR 3 delivers the `!!!full_keys`
  round-trip clause; the convenience-pair clause (`set_vendor` /
  `extract_vendor`) completes in PR 4.
- **E17, E18a, E18b, E18e, E19, E20b split** (plan-review 2R6): in PR 2 these
  are asserted through `extract_dataset_metadata()` (with `fill = NA` where
  the row asserts an NA result); their convenience-extractor clauses complete
  in PR 4.
- **B1 split** (plan-review 2R4): PR 2 delivers the
  `extract_dataset_metadata()` clause; PR 4 completes the five wrapper
  extractors' stale-object behavior.
- **X14 lands in PR 3** although it is a §7 (extractor) row: it asserts the
  completed DM-5b rendering, which the PR 3 renderer change delivers
  (plan-review 3J2, user decision (a)).
- **Roxygen per export**: each exporting PR (2, 3, 4) documents and exports
  its own functions, because an undocumented or unexported function fails
  that PR's own R CMD check and test gates.
- **The sibling regression re-assertions split**: SR1 (fill) guards the
  fill-validator widening and ships in PR 2; SR2 (parser) guards the parser
  parameterization and ships in PR 3. Both live in
  `tests/testthat/test-dataset-metadata.R` per plan-review R18.
- **Reader/extractor task pairing (2R2/3R2/3R3/4R1/4S1)**: PR 2's helper
  GREENs sit with the first rows that assert their output — the capture
  task lands `.dataset_metadata_or_empty()`,
  `.get_dataset_metadata_list()`, and `.format_dataset_result()` (default
  `format = "list"`, `fill = NULL` path; plan-review 4R1); the fill/format
  task lands the fill-validator widening (its first failing consumers are
  E4a/E4b; SR1 rides along as the regression guard — plan-review 4S1) plus
  the type-matched fill semantics. No task is an implementation-only run.

Source→test mapping deviations, both documented in test-spec §3/§12
(plan-review S17):

- `R/utils.R` helpers have no direct tests. Test-spec §12 forbids reaching
  into internal helpers; every helper is covered indirectly through the
  exported functions and the validator.
- `tests/testthat/test-dataset-metadata.R` has no matching `R/` source file.
  It is the documented split of test-spec §3: the twelve exports form one
  coherent unit and the metadata-system test file is already very large.

## Dependency chain and parallelism

```
PR 1 → PR 2 → PR 3 → PR 4 → PR 5 → PR 7
                  \
                   → PR 6 ──────────↗
```

- PR 1–PR 4 are strictly sequential (each uses the prior PR's exports).
- PR 5 (promotion) depends on PR 4: its tests call the convenience
  extractors (P5, P8, P10).
- PR 6 (print) depends on PR 3 only: its fixtures apply metadata state via
  `set_dataset_metadata()`, and its helpers read via the PR 2 guarded
  reader. It does NOT depend on PR 4 or PR 5, and it touches neither an
  export nor `_pkgdown.yml`, so 2B1 does not affect its parallelism.
- PR 6 may therefore ship concurrently with PR 4 and with PR 5. Its write
  surface (`R/methods-print.R`, `tests/testthat/test-methods-print.R`,
  `tests/testthat/_snaps/methods-print.md`) is disjoint from PR 4's and
  PR 5's surfaces, so pipeline-ship can dispatch it in parallel.
- PR 7 (docs) depends on PR 5 AND PR 6 (the vignette shows promotion; NEWS
  describes the full feature).
- PR numbering is shipping order; PR 6 may land at any point after PR 3.

## Shared gate: scoped snapshot/test-file guard (plan-review 2R10)

"Pre-existing" means: present at surveycore 1.1.0. Every PR's criteria
include this guard, instantiated with the PR's own files:

1. No pre-existing test file other than the PR's own listed test files is
   modified.
2. Snapshot files the PR appends to change by addition only: every
   pre-existing block is byte-identical (no `-` lines in the `git diff`).
3. `_snaps/**` files the PR does not own stay byte-identical whole-file
   (`_snaps/metadata-system.md` in every PR; `_snaps/dataset-metadata.md`
   and `_snaps/constructors.md` in PR 6; `_snaps/methods-print.md` in PR 5
   — plan-review 3S15).
4. `_snaps/dataset-metadata.md` is not pre-existing (PR 2 creates it), so
   PR 3/PR 4/PR 5 additions there are exempt from rule 3 (plan-review 4S9);
   rule 2 protects the earlier PRs' blocks in that file.

**Gate note (plan-review 4S11).** The test-spec §13 `pkgcheck` gate runs
locally: the repo has no pkgcheck CI workflow (removed in commit
`7fd2095`). Every other §13 gate runs in CI and locally.

---

## PR map

- [x] PR 1: `feature/dataset-metadata-class` — `@dataset_metadata` property, `survey_metadata` validator, value checker (error/val, catch-and-re-raise register split), and the non-DM-7 error-table rows

  - **Tasks** (7)
    1. Add the `full_keys` fixture to `tests/testthat/helper-test-data.R` (single definition; the six canonical keys in canonical order; test-spec §2).
    2. Error table (merged per plan-review 3S2). Add `plans/error-messages.md` rows DM-1a/1b, DM-2a/2b, DM-3a/3b, DM-4a/4b, DM-5a/5b, DM-6a/6b/6c, DM-8, DM-9 (spec §XI); the §VI.6 trigger-description extension for the five reused convention classes; the widened `surveycore_error_fill_invalid` variant; on the M-4 (`surveycore_error_setter_empty`) row, the §VII.1 wrapper variants — the four scalar-wrapper template and the `set_field_dates()` template (plan-review 2R13); on the M-3 (`surveycore_error_setter_ambiguous`) row, the `extract_dataset_metadata()` variant with the key/`key`-register wording (plan-review 3R4). Extend the file's `## Coverage Map` with the owning test files for every added row (plan-review 3S16). DM-7a–d are excluded — they ship in PR 5.
    3. Property. RED: write test-spec rows C1, C2, C3 in `tests/testthat/test-s7-classes.R`; confirm failure. GREEN: add the `dataset_metadata` property to `survey_metadata` in `R/core-classes.R` with the inline six-key comment and roxygen — plain backticked function references only, no `[...]` Rd links (PR 4 converts them; plan-review R6), and the `@examples` line uses `survey_metadata(dataset_metadata = list(vendor = "Ipsos"))`, never a setter. VERIFY: rerun C1–C3 plus the full file.
    4. Structural validator checks. RED: write rows C4, C5a, C5b, C5c, C6, C7f (C7f is check 6's failing row; plan-review 4R5); confirm failure. GREEN: implement validator checks 2–6 (spec §III.3). VERIFY: rerun C4–C6 and C7f plus the file.
    5. Value checks. RED: write rows C7a, C7b, C7c, C7d, C7e; confirm failure. GREEN: implement `.check_dataset_key_value()` in `R/utils.R` with `mode = "error"` and `key_style = "val"` (§VI.5 table; the `skip`/`arg` parameters land in PR 2/PR 4 with their first callers) in the catch-and-re-raise register form (plan-review 2R12/3R5): the checker always emits the Layer-3 CLI bullets; the validator wraps its delegation in a catch and re-raises the plain DM-3a/DM-6c one-liner. In this PR the checker's error-mode date branch is `Date(1)`-only — the ISO-string routing through `.coerce_field_date()` ships in PR 2 (plan-review 5R2). Then implement validator check 7, delegating with the Date(1)-only narrowing for date keys. The validator-side narrowing is the durable one: it must exist in `R/core-classes.R` even though it is redundant while the checker is also `Date(1)`-only — PR 2 widens the checker, and the validator narrowing alone keeps C7e green after that widening; do not deduplicate it away (plan-review 6S2). VERIFY: rerun C7a–C7e plus the file; assert the validator-path DM-3a/DM-6c messages with `expect_error(regexp = ...)`, not a snapshot.
    6. Date pair and re-validation. RED: write rows C8, C9, C10, C11; confirm failure. GREEN: implement validator check 8 (`field_start <= field_end` when both present); C9–C11 need no new code (S7 re-validates on `@<-`). VERIFY: rerun C8–C11 plus the file.
    7. Closing gate: run `devtools::document()` (confirm `man/survey_metadata.Rd` regenerates and NAMESPACE is unchanged), the full suite, and `devtools::check()`.

  - **Notes** (process, per plan-review 3S7)
    - Coverage rationale (plan-review R5(a)/3R5): the catch-and-re-raise form makes every line PR 1 adds reachable through the validator; no PR 1 code waits for a later caller.

  - **Acceptance criteria**
    - Test-spec §5 rows C1, C2, C3, C4, C5a, C5b, C5c, C6, C7a, C7b, C7c, C7d, C7e, C7f, C8, C9, C10, C11 all pass. Each row expands to one or more `test_that()` blocks, one observable behavior per block (test-spec §3). All are class-only — no snapshots.
    - `survey_metadata()` with no arguments yields `@dataset_metadata` identical to `list()` (C1).
    - `full_keys` is defined exactly once, in `helper-test-data.R`, with the six canonical keys in canonical order (test-spec §2; plan-review 3S8).
    - Rows C4, C5a–C5c, C6, C7a–C7f, C8 cover every spec §III.3 error class from direct construction; row C10 proves the validator re-runs on `@<-` assignment (plan-review R10).
    - Validator-path DM-3a and DM-6c render as plain one-line text matching their `plans/error-messages.md` rows, asserted with `expect_error(regexp = ...)`, not a snapshot (plan-review 2R12); the regexp text is verified by review against `plans/error-messages.md` (plan-review 3S9/4R8).
    - Verified by review against spec §III.2 (plan-review 4R9): the `survey_metadata` roxygen carries (1) the `@param dataset_metadata` block naming the six keys as a closed vocabulary, (2) that block's pointers to `set_dataset_metadata()` and `extract_dataset_metadata()`, (3) the class `@examples` line using `survey_metadata(dataset_metadata = list(vendor = "Ipsos"))`, and (4) the inline six-key comment in `R/core-classes.R`.
    - `plans/error-messages.md` contains rows DM-1 through DM-6, DM-8, DM-9, the five-class trigger extension, the widened `fill_invalid` variant, the §VII.1 wrapper `setter_empty` variants on the M-4 row (plan-review 2R13), and the `extract_dataset_metadata()` variant on the M-3 row (plan-review 3R4); its `## Coverage Map` names the owning test file for every added row (plan-review 3S16). DM-7a–d are absent (they ship in PR 5).
    - PR 1 roxygen contains no Rd link to a not-yet-existing topic; R CMD check reports no Rd cross-reference warning.
    - Scoped snapshot/test-file guard holds (own test files: `test-s7-classes.R`, `helper-test-data.R`; appended snapshot files: none).
    - Profile gates (test-spec §13) all pass. New-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/core-classes.R`
    - `R/utils.R`
    - `plans/error-messages.md`
    - `tests/testthat/test-s7-classes.R`
    - `tests/testthat/helper-test-data.R`
    - `man/survey_metadata.Rd` (regenerated)

  - **Pipeline split**: recommended (class contract change; new validator behavior)

- [x] PR 2: `feature/dataset-metadata-read-path` — guarded reader, date coercion, attribute reader, fill widening, and `extract_dataset_metadata()`

  - **Tasks** (10)
    1. Add fixtures `make_dataset_df()` and `make_stale_metadata_design()` to `tests/testthat/helper-test-data.R` (each defined once; `make_stale_metadata_design()` supports all four design classes per test-spec §2). Create `tests/testthat/test-dataset-metadata.R` with the B0 fixture guard; verify B0 passes.
    2. Extractor core I — capture, resolution, and list formatting (plan-review 3R2/4R1). RED: write rows E1, E2a, E2b (list-format clause only — its `format = "data_frame"` clause ships in task 8; plan-review 4R4), E3, E11, E12a, E12b, E12c, E16 in survey mode (state via validated `@<-` assignment — setters do not exist yet); confirm failure. GREEN: implement `.dataset_metadata_or_empty()` in `R/utils.R` and `.get_dataset_metadata_list()` in `R/core-metadata.R` (their first callers; plan-review 3R3), the `extract_dataset_metadata()` capture core — `ensyms`-style capture, key resolution, request-order dedup — and `.format_dataset_result()` in its default `format = "list"`, `fill = NULL` path (plan-review 4R1 — these rows assert the formatted return value). VERIFY: rerun the rows plus the full file.
    3. Extractor core II — fill widening, fill semantics, roxygen (plan-review 3R2/4S1/4R1). RED: write row SR1 (sibling fill regression; confirm it passes against current behavior — the regression guard) and rows E4a, E4b, E4c in survey mode (E4d ships in task 8; plan-review 4R4); confirm the E4 rows fail. GREEN: add the widening parameter to the shared fill validator (defaults byte-identical; plan-review 4S1 — E4a/E4b are its first failing consumers) and implement the `fill = NA`/`NA_character_` type-matched fill semantics; write the roxygen/`@export` block: `@family metadata`, `@return`, runnable `@examples` that establish state with bare `attr(df, "vendor") <- ...` only, named-only notes for `key`, `format`, and `fill` (spec §XII.5/§XII.9; plan-review 2R11/2S14/3S10), the §VIII.1 sentence documenting plain name matching — not tidy-select (plan-review 3R12), plain backticks for not-yet-existing functions. VERIFY: rerun the rows plus the full file; SR1 still passes; `_snaps/metadata-system.md` unchanged.
    4. Reader I — skeleton and wiring (split per plan-review 4R2). RED: write rows E17, E21, E22, X1; confirm failure. GREEN: implement the `.read_dataset_attributes()` skeleton — the seven-name §V.2 ordered read with `exact = TRUE`, canonical output order — and wire the extractor's data-frame mode. VERIFY: rerun plus the file.
    5. Reader I — data-frame-mode clause completions (split per plan-review 4R2; no new GREEN). Write the data-frame-mode clauses of E1, E2a, E2b, E3, E4a–E4c, E11, E12a–E12c, and E16 (plan-review 3R6; E4d ships whole in task 8 per 4R4); confirm state — the task-4 wiring carries them. VERIFY: rerun plus the full file.
    6. Reader II — value checks. RED: write rows E18a, E18b, E18c, E18d, E23 (`expect_no_warning` on every drop); confirm failure. GREEN: add the checker's `mode = "skip"` parameter and implement `.coerce_field_date()`; the checker's date branch routes BOTH modes through `.coerce_field_date()`, so the error-mode ISO acceptance ships in this PR, covered by the skip-mode rows — PR 3's X10 first asserts it (plan-review 5R2). Then build the `dropped`-report classification (wrong type, zero length, wrong length; invalid legacy `dates` → the DM-7d variant). VERIFY: rerun plus the file.
    7. Reader III — legacy and pair rules. RED: write rows E18e, E19, E20a, E20b; confirm failure. GREEN: implement the legacy-`dates` step-7 rule and the reversed-pair double drop (the DM-7c report variant). VERIFY: rerun plus the file.
    8. Data-frame format. RED: write rows E5, E6a, E6b, E4d, and E2b's `format = "data_frame"` clause (both moved here per plan-review 4R4 — this task implements the format they assert; both input modes, which exist after task 4); confirm failure. GREEN: implement the `"data_frame"` output format, including the always-`NA_character_` fill rendering (E4d). VERIFY: rerun plus the file.
    9. Error paths and stale reads (fold per plan-review 3R2). RED: write rows E7, E8, E13, E14, E15 (dual pattern; both modes — see the v1.3 adjustments note on 3R6), the `surveycore_error_not_survey_or_df` guard rows for `extract_dataset_metadata()` (`1L`, `"a"`, a `survey_collection`; dual once), and row B1, `extract_dataset_metadata()` clause only (returns `list()` on `make_stale_metadata_design()` output; the five wrapper clauses complete in PR 4); confirm failure/state. GREEN: implement the guards and error paths, including the DM-5b base unknown-key renderer — the "Valid keys:" bullet with no hint (plan-review 2S4; PR 3 layers the hint and legacy-`dates` bullets on top). The extractor raises `surveycore_error_setter_ambiguous` directly with its own `cli_abort()` against the M-3 extractor variant — it does not call `.parse_setter_input()` (plan-review 3R4). B1 needs no new code (guarded reader). VERIFY: rerun; review each snapshot.
    10. Closing gate: append `extract_dataset_metadata` to the "Metadata — extractors" reference section of `_pkgdown.yml` (plan-review 2B1); `devtools::document()` (NAMESPACE +1 export; `man/extract_dataset_metadata.Rd` created; seealso-only regeneration of the 23 existing `@family metadata` topics); full suite; `devtools::check()`; `pkgdown::build_site()` clean.

  - **Acceptance criteria**
    - Test-spec §7 rows E1, E2a, E2b, E3, E4a, E4b, E4c, E4d, E5, E6a, E6b, E7, E8, E11, E12a, E12b, E12c, E13, E14, E15, E16, E17, E18a, E18b, E18c, E18d, E18e, E19, E20a, E20b, E21, E22, E23, SR1, X1 and §10 rows B0 and B1 (`extract_dataset_metadata()` clause) pass. Rows E9a, E9b, E10 ship in PR 4; row X14 ships in PR 3.
    - Rows E17, E18a, E18b, E18e, E19, E20b are asserted through `extract_dataset_metadata()` (with `fill = NA` where the row asserts an NA result); their convenience-extractor clauses complete in PR 4 (plan-review 2R6).
    - Every listed §7 row that does not name a mode runs in both survey-object and data-frame mode (test-spec §3; plan-review R11), with the exemption stated explicitly (plan-review 3R7): the §7 data-frame read-path sub-table (E17–E22, E23, X1) is data-frame mode only; the both-modes rule applies to E1–E16; SR1 runs in survey-object mode only, matching its sibling-extractor recipe (`extract_var_label(d, fill = NA)`; plan-review 5S4). Survey-object state in this PR is applied via validated `@<-` assignment only.
    - No PR 2 test constructs a survey object from `make_dataset_df()` output (plan-review R7 forward guard — promotion does not exist yet).
    - PR 1's row C7e stays green after this PR widens the checker's date branch (the ISO routing through `.coerce_field_date()`): the validator-side `Date(1)`-only narrowing in `R/core-classes.R` carries it, and this PR makes no `R/core-classes.R` edit (plan-review 6S2).
    - Verified by review, not by test (test-spec §12): the `dropped` report of `.read_dataset_attributes()` distinguishes all four DM-7 variants of spec §V.3, including legacy-`dates`. The behavioral gate is PR 5 rows P8–P12 plus X7/X8, with E23 executing the invalid-legacy-`dates` branch in this PR; PR 5's `.read_dataset_attributes()`-unmodified criterion is the handshake (plan-review 2R8/2S9).
    - `extract_dataset_metadata()` rejects `1L`, `"a"`, and a `survey_collection` with `surveycore_error_not_survey_or_df` (dual once).
    - E15's snapshot locks the DM-5b base form: the "Valid keys:" bullet, no hint line (plan-review 2S4).
    - Verified by review against `plans/error-messages.md` (plan-review S9/3S9): the snapshotted text for DM-9, the widened `fill_invalid`, the reused `format_invalid` rendering, and the E13 `setter_ambiguous` rendering (the M-3 extractor variant; plan-review 3R4) matches its table row.
    - Roxygen uses plain backticks for not-yet-existing functions; `@examples` establish state with bare `attr()` writes only; `key`, `format`, and `fill` documented as named-only (plan-review 2R11/2S14/3S10); the `extract_dataset_metadata()` roxygen carries the §VIII.1 plain-name-matching (not tidy-select) sentence — verified by review against spec §VIII.1 (plan-review 3R12).
    - `full_keys`, `make_dataset_df()`, and `make_stale_metadata_design()` are each defined exactly once, in `helper-test-data.R`; `make_stale_metadata_design()` accepts all four design classes even though this PR exercises fewer (plan-review R12/R16).
    - Every block that constructs a survey object opens with `test_invariants(design)`.
    - Scoped snapshot/test-file guard holds (own test files: `test-dataset-metadata.R` (new), `helper-test-data.R`; created snapshot file: `_snaps/dataset-metadata.md`).
    - In the 23 regenerated `@family metadata` Rd files, the only diff is the `Other metadata:` seealso list (plan-review R17/2S6).
    - Profile gates (test-spec §13) all pass, including `pkgdown::build_site()` with the new reference entry; new-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/core-metadata.R`
    - `R/utils.R`
    - `_pkgdown.yml`
    - `tests/testthat/test-dataset-metadata.R` (new)
    - `tests/testthat/helper-test-data.R`
    - `tests/testthat/_snaps/dataset-metadata.md` (new)
    - `NAMESPACE` (regenerated; +1 export)
    - `man/` (new `extract_dataset_metadata.Rd`; seealso-only regeneration of the 23 existing `@family metadata` topics)

  - **Pipeline split**: recommended (one new exported function; new internal read machinery)

- [x] PR 3: `feature/dataset-metadata-setter` — parser parameterization and `set_dataset_metadata()`

  - **Tasks** (10)
    1. Conventions Ia — fixture, sibling guard, parser parameterization, and the rules skeleton (re-partitioned per plan-review 5S1/5S2; re-scoped per 5R1). Add the `make_dataset_design()` fixture to `helper-test-data.R` (defined once). It builds a plain `make_survey_data()` frame, constructs, then applies state via `set_dataset_metadata()` on the constructed design — never via data-frame attributes (plan-review R7). It accepts all five `design` values (incl. `nonprob_rep`) and all four `state` values (plan-review R16). `expect_dataset_roundtrip()` is defined in PR 5, its first caller (plan-review 2S2). RED: write row SR2 (sibling setter regression; confirm it passes against current behavior — the regression guard), rows SC1, SC2, SC3, SC4, SC5, and the `not_survey_or_df` class checks for this function; confirm the SC rows and class checks fail. GREEN: add the four parameters to `.parse_setter_input()` (`name_arg_name`, `pair_noun`, `example_pairs`, `container_noun`) with byte-identical defaults (spec §VI.6; first failing consumers: the SC rows — plan-review 5S1), and implement the setter skeleton — §VI.2 rules 1 and 3–7 (class guard, parser call with the key/key-value/list parameterization); the rule-2 property guard lands in task 9 (plan-review 5R1). VERIFY: rerun; SR2 still passes; all existing sibling-setter snapshot files byte-identical; snapshots render the "key-value pair" / "list" wording verbatim (test-spec §4; plan-review S10); SC5 captures the return value and asserts it unchanged.
    2. Conventions Ib — the minimal write (split per plan-review 5S2). RED: write rows S1a, S1b, S1c, S1d, S1e, S1f, S2; confirm failure. GREEN: implement the minimal happy-path write in BOTH modes (plan-review 4R3): the §VI.3 survey write (guarded read; canonical write via `@<-`) and the §VI.4 data-frame attribute write, so the S1 rows can read stored state back through the extractor. VERIFY: rerun plus the file.
    3. Conventions II. RED: write rows X2, the DM-1b trigger (`key = c("")` — test-spec §4's recipe; plan-review 5S5), and the DM-2b triggers (duplicated named `...` args AND `key = c("vendor", "vendor")`); confirm failure. GREEN: implement §VI.2 rules 8–9 plus the alias resolution that runs before the duplicate check. VERIFY: rerun plus the file.
    4. Value checks Ia — unknown-key layering (split per plan-review 4S2). RED: write rows S16a, S16b, S16c, S16d, and X14 (completed unknown-key rendering through the extractor; test-spec v2.3; plan-review 3J2); confirm failure. GREEN: implement rule 10 — unknown-key rejection layering the hint and legacy-`dates` bullets on PR 2's DM-5b base renderer (plan-review 2S4). VERIFY: rerun plus the file; PR 2's E15 snapshot block is unchanged; X14's snapshot shows the completed rendering through `extract_dataset_metadata()`.
    5. Value checks Ib — checker delegation (split per plan-review 4S2). RED: write rows Z1, Z2, Z3, Z4, Z5, Z6, X3 (extended v2.4 scope: the `{.val}`-register snapshot for `field_start = 20260210` AND for `field_start = NA`; plan-review 4S7), and X10 (extended v2.4 scope: ISO strings through the general setter, both modes, plus the round-trip-failing string `"2026-2-1"`; test-spec v2.4; plan-review 3S11/4S7); confirm failure. GREEN: implement rule 11 — checker delegation (error/val); the error-mode ISO acceptance itself ships in PR 2's `.coerce_field_date()` routing, so this task edits no `R/utils.R` line (plan-review 5R2). VERIFY: rerun plus the file.
    6. Merge, deletion, effective pair, and atomicity (fold per plan-review 4S2). RED: write rows S3, S4, S5, S6a, S6b, S6c, S7a, S7b, S7c, S15e, S8, and X15 (reversed pair via the general setter — the DM-4b dual; test-spec v2.4; plan-review 4R10); confirm failure. GREEN: implement the canonical-order merge, `NULL` deletion, rule 12 — the three-way effective-pair rule — and atomic writes. VERIFY: rerun plus the file.
    7. Survey write-path guarantees (re-scoped per plan-review 4R3). RED: write rows S21a, S21b (non-interference), and S25a, S25b, S25c — round-trip clause (`!!!full_keys`, extract-all identical, canonical order) only; the convenience-pair clause ships in PR 4 (plan-review 2R5); `test_invariants(design)` first in every constructing block; confirm state (the task-2 write path is class-generic). GREEN: none expected; fix the write path if a per-class gap appears. VERIFY: rerun plus the file.
    8. Data-frame write-path guarantees and legacy cleanup (re-scoped per plan-review 4R3). RED: write rows S16e, S16f, S16g (setter clauses only — the construction clause ships in PR 5 beside S23; plan-review S3), S20, S20b, S22, and X11 (valid key equal to a column name; test-spec v2.3; plan-review 3S12); confirm failure for S16f and S16g (the cleanup does not exist yet) and state for the frame-invariant rows. GREEN: implement the legacy-`dates` cleanup on `field_period = NULL` and the `dates = NULL` cleanup alias. VERIFY: rerun plus the file.
    9. Stale-object write guard. RED: write rows S24 (DM-8 via `set_dataset_metadata(old, vendor = "x")`, dual pattern) and X4; confirm failure (a true RED — task 1 excludes the rule-2 guard, and no task-2 through task-8 row uses a stale object; plan-review 5R1). GREEN: implement the rule-2 property guard ahead of input parsing. VERIFY: rerun; snapshot locks the rebuild-with-`as_survey()` remedy.
    10. Closing gate: roxygen and `@export` for `set_dataset_metadata()` — `@family metadata`, `@return`, runnable `@examples`, named-only notes for `key`/`value` (spec §XII.5/§XII.9; plan-review 2S14), the §VI.1 sentence documenting the Convention-3 `as.list(value)` coercion (plan-review 3R12), plain backticks for the not-yet-existing wrappers (plan-review 2R11); the `@section Attribute persistence:` block ships in PR 5. Append `set_dataset_metadata` to the "Metadata — setters" section of `_pkgdown.yml` (plan-review 2B1). `devtools::document()` (+1 export), full suite, `devtools::check()`, `pkgdown::build_site()` clean.

  - **Acceptance criteria**
    - Test-spec §6 rows S1a, S1b, S1c, S1d, S1e, S1f, S2, S3, S4, S5, S6a, S6b, S6c, S7a, S7b, S7c, S8, S15e, S16a, S16b, S16c, S16d, S16e, S16f, S16g (setter clauses), S20, S20b, S21a, S21b, S22, S24 (general setter), S25a, S25b, S25c (round-trip clause), SC1, SC2, SC3, SC4, SC5, SR2, X2, X3, X4, X10, X11, X15, Z1, Z2, Z3, Z4, Z5, Z6, and §7 row X14 pass.
    - Exclusions, enumerated (plan-review 2S11/4S3): rows S10, S11, S12a, S12b, S12c, S12d, S13a, S13b, S13c, S14a, S14b, S14c, S14d, S14e, S14f, S14g, S15a, S15b, S15c, S15d, E9a, E9b, X5, X6, X13 ship in PR 4; S15e stays here; S23 and the S16g construction clause ship in PR 5; the S25 convenience-pair clause ships in PR 4.
    - The five reused convention classes each pass with the dual pattern (SC1–SC4) and SC5 warns with the return value captured and asserted unchanged (plan-review 2R9).
    - The §4-matrix duals delivered in task 3 pass (plan-review 4S4): the DM-1b blank-name trigger `key = c("")` (test-spec §4's recipe; plan-review 5S5), and both DM-2b triggers — duplicated named `...` arguments, and `key = c("vendor", "vendor")` — each with the dual pattern.
    - Every listed §6 row that does not name a mode and does not operate on a stale object runs in both survey-object and data-frame mode (plan-review R11/3S5); §7 row X14, which names no mode, also runs in both modes (plan-review 4S6).
    - Convention-message snapshots render the `key` / "key-value pair" / "list" wording verbatim per test-spec §4; SR2 proves the sibling `variable` / "variable-label pair" / "vector" wording is untouched.
    - PR 2's E15 snapshot block is unchanged; PR 3 adds only the hint and legacy-`dates` bullets to the DM-5b rendering (plan-review 2S4). X14 passes: the completed DM-5b renders through the extractor path — a near-miss request via `extract_dataset_metadata()` shows the hint bullet (plan-review 3J2, user decision (a)).
    - PR 2's E13 snapshot block is byte-identical after the parser parameterization (plan-review 3R4).
    - X10 passes with its v2.4 extended scope: `set_dataset_metadata(x, field_start = "2026-02-10")` stores a `Date`; `set_dataset_metadata(x, field_start = "2026/02/10")` and `set_dataset_metadata(x, field_start = "2026-2-1")` (round-trip failure) each raise `surveycore_error_field_date_invalid`; both modes (spec §VI.5; plan-review 3S11/4S7).
    - X3 passes with its v2.4 extended scope: the `{.val}`-register snapshot covers `field_start = 20260210` and `field_start = NA` (plan-review 4S7).
    - X11 passes: on a data frame with a column named `vendor`, the setter writes the attribute and leaves the `vendor` column byte-identical (spec §VI.4; plan-review 3S12).
    - X15 passes: with `field_end` stored, `set_dataset_metadata(x, field_start = <a later date>)` raises `surveycore_error_field_dates_reversed` — dual pattern, both modes — and the stored state is unchanged afterwards (plan-review 4R10). This row is the DM-4b general-setter dual behind the message-text criterion below.
    - Verified by review against `plans/error-messages.md` (plan-review S9/3S9): the snapshotted text for DM-1b, DM-2b, DM-3b, DM-4b, DM-5b, DM-6a, and DM-8 matches its table row.
    - `set_dataset_metadata()` rejects `1L`, `"a"`, and a `survey_collection` with `surveycore_error_not_survey_or_df` (class checks; the family snapshot lives in PR 2).
    - `make_dataset_design()` is defined exactly once in `helper-test-data.R` and accepts all five `design` values and all four `state` values even where this PR's rows exercise fewer (plan-review R12/R16); no test constructs a survey object from `make_dataset_df()` output (R7).
    - Roxygen for `set_dataset_metadata()` carries `@family metadata`, `@return`, runnable `@examples`, named-only `key`/`value` notes, the §VI.1 `as.list(value)` coercion sentence (verified by review against spec §VI.1; plan-review 3R12), and no Rd link to a not-yet-existing topic (plan-review 2R11/2S14).
    - Every block that constructs a survey object opens with `test_invariants(design)`.
    - Scoped snapshot/test-file guard holds (own test files: `test-dataset-metadata.R`, `helper-test-data.R`; appended snapshot file: `_snaps/dataset-metadata.md`, addition-only).
    - In the 24 regenerated `@family metadata` Rd files — the 23 pre-existing family topics plus `extract_dataset_metadata.Rd`, already shipped in PR 2 — the only diff is the `Other metadata:` seealso list (plan-review R17/2S6/4S8).
    - Profile gates (test-spec §13) all pass, including `pkgdown::build_site()` with the new reference entry; new-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/core-metadata.R`
    - `_pkgdown.yml`
    - `tests/testthat/test-dataset-metadata.R`
    - `tests/testthat/helper-test-data.R`
    - `tests/testthat/_snaps/dataset-metadata.md`
    - `NAMESPACE` (regenerated; +1 export)
    - `man/` (new `set_dataset_metadata.Rd`; seealso-only regeneration of the 24 family topics — the 23 pre-existing plus `extract_dataset_metadata.Rd`; plan-review 4S8)

  - **Pipeline split**: recommended (one new exported function; shared-parser change touching seven sibling setters)

- [x] PR 4: `feature/dataset-metadata-wrappers` — ten convenience wrappers, Rd links, pkgdown completion, `extract_metadata()` note

  - **Tasks** (9)
    1. Vendor pair. RED: write rows S12a, S12b, S12d (`set_vendor(d)` → `setter_empty`, dual once for the wrapper message), E9a and E9b (vendor entries), the X13 vendor clause (`set_vendor(d, 1L)` dual; snapshot names `vendor`; plan-review 3R11), and the S25a/S25b/S25c convenience-pair completion (`set_vendor` / `extract_vendor` on each design class; plan-review 2R5); confirm failure. GREEN: implement `set_vendor()` and `extract_vendor()` per spec §VII/§IX (wrapper check order: class → DM-8 → guard → delegation). VERIFY: rerun plus the file.
    2. Name pairs. RED: write rows S10, S11, S12c, S12d (name setters), E9a/E9b (name entries), E10, and the X13 name clauses (`set_survey_name(d, 1L)` and `set_data_name(d, 1L)` duals; snapshots name `survey_name` and `data_name`; plan-review 3R11); confirm failure. GREEN: implement `set_survey_name()`, `set_data_name()`, `extract_survey_name()`, `extract_data_name()`. VERIFY: rerun plus the file.
    3. Period pair. RED: write rows S13a, S13b, S13c (snapshot names `field_period`), S12d (period setter), E9a/E9b (period entries); confirm failure. GREEN: implement `set_field_period()` and `extract_field_period()`. VERIFY: rerun plus the file.
    4. Dates pair. RED: write rows S14a, S14b, S14c, S14d, S14e, S14f, S14g, E9a/E9b (dates entries), X5; confirm failure. GREEN: add the `key_style = "arg"` parameter to `.check_dataset_key_value()` in `R/utils.R` (first caller; plan-review R5(a)/2S1 — no behavior change for existing callers), then implement `set_field_dates()` (`rlang::is_missing()` semantics, arg-style pre-validation with the wrapper's own `call`, supplied-arguments-only forwarding) and `extract_field_dates()`. VERIFY: rerun plus the file.
    5. Effective-pair behavior through the wrappers. RED: write rows S15a, S15b, S15c, S15d; confirm state. GREEN: none expected (delegation carries the §VI.5 rule). VERIFY: rerun plus the file.
    6. Stale and guard-order rows (split per plan-review 3R1). RED: write the S24 completion (class checks: the five wrapper setters on `make_stale_metadata_design()` output raise DM-8), B2 (dual on `set_vendor(old, "x")`; snapshot locks the rebuild remedy — deliberately distinct from PR 3's S24 dual, both required; plan-review 2S10), X6, and the B1 wrapper completion (the four scalar extractors return `NA_character_` and `extract_field_dates()` returns the all-NA pair on a stale object; plan-review 2R4); confirm state for the S24 wrapper completion, B2, and X6 — the per-wrapper check order (class → DM-8 → guard → delegation, spec §VII.1) lands with each wrapper in tasks 1–4 — and for the B1 wrapper completion, which PR 2's guarded reader carries through the tasks 1–4 extractors; no cell here is a true RED (plan-review 6R2/6S3, rationale split per Pass 7 suggestion). GREEN: none expected; complete the guard order if a per-wrapper gap appears. VERIFY: rerun plus the file.
    7. Extractor clause completions and family guard (split per plan-review 3R1). RED: write the E17/E18a/E18b/E18e/E19/E20b convenience-extractor clause completions (plan-review 2R6) and the `not_survey_or_df` class checks for all ten wrappers; confirm state. GREEN: none expected (delegation already carries the behavior). VERIFY: rerun plus the file.
    8. Docs surface: roxygen for the ten wrappers (`@family metadata`, `@return`, runnable `@examples`, no `@seealso`); convert the deferred backticked references to Rd links in `R/core-classes.R` AND `R/core-metadata.R` (plan-review R6/2R11); add the one-sentence `extract_metadata()` `@details` note (spec §XII.8).
    9. Closing gate (fold per plan-review 3S3): append the ten wrappers to `_pkgdown.yml` (five to "Metadata — setters", five to "Metadata — extractors"); `extract_dataset_metadata` and `set_dataset_metadata` are already present from PR 2/PR 3 (plan-review 2B1). `devtools::document()` (+10 exports; five to ten new Rd topics depending on the §XII.9 pairing choice — every export has a documented entry and a `_pkgdown.yml` entry (plan-review 2S7); `survey_metadata.Rd`, `set_dataset_metadata.Rd`, `extract_dataset_metadata.Rd` (plan-review 4R11), and `extract_metadata.Rd` regenerate; seealso regeneration of the 25 family topics — the 23 pre-existing plus `extract_dataset_metadata.Rd` and `set_dataset_metadata.Rd` (plan-review 4S8)), full suite, `devtools::check()`, `pkgdown::build_site()` clean.

  - **Notes** (process, per plan-review 3S7)
    - Deviation rule (plan-review 2S5): a fixture gap discovered during implementation is a plan deviation; resolving it requires adding `helper-test-data.R` to this PR's write surface — safe, because PR 6 does not touch that file.

  - **Acceptance criteria**
    - Test-spec §6 rows S10, S11, S12a, S12b, S12c, S12d, S13a, S13b, S13c, S14a, S14b, S14c, S14d, S14e, S14f, S14g, S15a, S15b, S15c, S15d, S24 (wrapper completion), S25a/S25b/S25c (convenience-pair completion), X13, §7 rows E9a, E9b, E10 plus the E17, E18a, E18b, E18e, E19, E20b convenience-extractor clause completions, §10 row B1 (wrapper completion: four scalar extractors return `NA_character_`, `extract_field_dates()` returns the all-NA pair, on `make_stale_metadata_design()` output) and B2, and rows X5, X6 pass.
    - X13 passes: the DM-3b wrapper duals for `set_vendor(d, 1L)`, `set_survey_name(d, 1L)`, and `set_data_name(d, 1L)` each snapshot a message naming the delegated key, mirroring the S13c treatment (spec §VII.1/§XI; plan-review 3R11).
    - `extract_metadata()` roxygen carries the §XII.8 one-sentence carve-out note; the `man/extract_metadata.Rd` diff is that sentence only (plan-review 3R8).
    - Every listed row that does not name a mode and does not operate on a stale object runs in both survey-object and data-frame mode (plan-review R11/3S5), with the exemption stated explicitly (plan-review 4R6): the §7 data-frame read-path rows (E17, E18a, E18b, E18e, E19, E20b) complete in data-frame mode only; the both-modes rule applies to E9a, E9b, E10 and the §6 rows. Every constructing block opens with `test_invariants(design)`.
    - Verified by review against spec §XII.9 (plan-review 4S5): each of the ten wrappers' roxygen carries `@family metadata`, a full `@return`, runnable `@examples`, and no `@seealso`.
    - No test constructs a survey object from `make_dataset_df()` output (plan-review R7/2R7 — promotion does not exist yet).
    - DM-6a and DM-6b render distinctly: separate snapshots for the `{.val}` form (PR 3's X3) and the `{.arg}` form reporting `set_field_dates()` as caller, plus the NA bullet (plan-review R15). Verified by review against `plans/error-messages.md` (plan-review S9/3S9): the snapshotted DM-4b (via the S15a/S15b `set_field_dates()` duals; plan-review 5S6), DM-6b, and wrapper `setter_empty` text matches its table rows, including the §VII.1 wrapper variants recorded on the M-4 row in PR 1 (plan-review 2R13).
    - All ten wrappers reject `1L`, `"a"`, and a `survey_collection` with `surveycore_error_not_survey_or_df` (class checks). With PR 2 and PR 3 this completes the §4 all-twelve-exports guard row and the spec §I.3 support matrix.
    - S14c proves the raised condition is the typed surveycore error, never a base `as.Date()` condition.
    - Verified by review (2S9 pattern; plan-review 3S14): no direct `@dataset_metadata` read exists outside the guarded helpers and the setter write path (spec §II.3).
    - `devtools::document()` yields exactly twelve dataset-metadata exports in NAMESPACE across PR 2–PR 4; every export appears in a `_pkgdown.yml` reference section; the site builds clean.
    - In the 25 regenerated `@family metadata` Rd files — the 23 pre-existing family topics plus `extract_dataset_metadata.Rd` and `set_dataset_metadata.Rd`, already shipped in PR 2/PR 3 (plan-review 4S8) — the only diff is the `Other metadata:` seealso list; `survey_metadata.Rd`, `set_dataset_metadata.Rd`, and `extract_dataset_metadata.Rd` additionally gain the Rd links (plan-review R17/R6/2S6/4R11).
    - Scoped snapshot/test-file guard holds (own test file: `test-dataset-metadata.R`; appended snapshot file: `_snaps/dataset-metadata.md`, addition-only).
    - Profile gates (test-spec §13) all pass; new-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/core-metadata.R`
    - `R/utils.R`
    - `R/core-classes.R` (Rd-link conversion only)
    - `_pkgdown.yml`
    - `tests/testthat/test-dataset-metadata.R`
    - `tests/testthat/_snaps/dataset-metadata.md`
    - `NAMESPACE` (regenerated; +10 exports)
    - `man/` (five to ten new topics per the §XII.9 pairing choice; `survey_metadata.Rd`, `set_dataset_metadata.Rd`, `extract_dataset_metadata.Rd` (plan-review 4R11), `extract_metadata.Rd`, and family seealso regeneration)

  - **Pipeline split**: recommended (ten new exported functions)

- [x] PR 5: `feature/dataset-metadata-promotion` — construction promotion in three constructors, the nonprob weighting-history fix, DM-7 rows

  - **Tasks** (8)
    1. Add the DM-7a, DM-7b, DM-7c, DM-7d rows to `plans/error-messages.md` (moved here from the class PR per plan-review S4 — this PR's code first raises them). Extend the file's `## Coverage Map` with the owning test files for the four rows (plan-review 3S16).
    2. `as_survey()` promotion. RED: write rows P1, P2, P3, P4, P5, P6a, P7 in `tests/testthat/test-constructors.R` (`test_invariants(design)` first in every block); confirm failure. GREEN: implement `.promote_dataset_metadata()` in `R/utils.R` — the promotion path only (consumes the PR 2 `dropped` report unchanged; never errors; never modifies `data`; the DM-7 warning emission lands in task 3, whose rows first assert it — plan-review 6S1) — and wire the `as_survey()` call site (spec §V.1). VERIFY: rerun plus the file.
    3. Warning variants. RED: write rows P6b, P8, P9, P10, P11, P12, X7, X8; each with `expect_warning(class = ...)`, a message snapshot, and the return value captured and asserted; confirm failure. GREEN: implement the per-variant warning emission. VERIFY: rerun; review the snapshots.
    4. Round trip and non-destruction. Define `expect_dataset_roundtrip()` in `helper-test-data.R` (single definition; first caller here — plan-review 2S2). RED: write rows P13, P14, P15, P20, P21, P22; confirm state. GREEN: none expected. VERIFY: rerun plus the file.
    5. Other constructors. RED: write rows P16, P17a, P17b; confirm failure. GREEN: wire `as_survey_replicate()`; wire `as_survey_nonprob()` — add the missing `.promote_weighting_history()` call first, then the dataset promotion. VERIFY: rerun plus the file.
    6. Inheritance, imports, and export conversion. RED: write rows P18, P19a, P19b, and X12 (`as_tbl_svy()` no-change; test-spec v2.3; plan-review 3S13) — block-level `skip_if_not_installed()` where the row names it; confirm state. GREEN: none expected (two-phase inherits; converters build empty metadata; `as_tbl_svy()` is a named no-change surface). VERIFY: rerun.
    7. Residue rows. RED: write S23 and the S16g construction clause (rebuilding after `field_period = NULL` yields no `field_period` — deletion is idempotent) in `tests/testthat/test-dataset-metadata.R`; confirm state. GREEN: none expected. VERIFY: rerun.
    8. Closing gate (fold per plan-review 3S3): add the `@section Attribute persistence:` block to `set_dataset_metadata()` roxygen in `R/core-metadata.R` (spec §XII.4 — the droppers and the §V.4 resurrection note; the behavior it documents now exists); `devtools::document()` (only `man/set_dataset_metadata.Rd` changes; NAMESPACE unchanged — plan-review S16); full suite; `devtools::check()`.

  - **Notes** (process)
    - Bundle rationale (plan-review 3J1, user decision (a)): this PR's hand-edited write surface exceeds five files, and the bundle stays. The `as_survey_nonprob()` weighting-history fix is one call-site line, and P17b must ship in the same PR as the promotion wiring it asserts. Splitting would add an eighth PR with no review benefit.

  - **Acceptance criteria**
    - Test-spec §8 rows P1, P2, P3, P4, P5, P6a, P6b, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, P17a, P17b, P18, P19a, P19b, P20, P21, P22, X7, X8, X12 and §6 rows S23 plus the S16g construction clause pass.
    - `surveycore_warning_dataset_metadata_dropped` fires for all four message variants; DM-7d fires for all three invalid legacy-`dates` shapes (wrong type, zero-length, length > 1) and takes precedence over DM-7a/DM-7b (plan-review R14); construction always succeeds; the DM-7d snapshots point at `set_field_period()`.
    - `plans/error-messages.md` contains rows DM-7a–DM-7d and its `## Coverage Map` names the owning test file for each (plan-review 3S16/4R7).
    - Verified by review against `plans/error-messages.md` (plan-review S9/3S9): the snapshotted DM-7 text matches the rows added in task 1.
    - P17b passes: `as_survey_nonprob()` now promotes weighting history (the pre-existing inconsistency is fixed). Forward note: PR 7 gives this fix its own separately-described NEWS bullet (plan-review 2S3).
    - P20 locks the documented resurrection behavior; P22 locks the documented base-subsetting attribute loss.
    - X12 passes: `as_tbl_svy()` raises no error on a design carrying dataset metadata, and the design's metadata is unchanged afterwards (guarded by `skip_if_not_installed("srvyr")`; spec §I.3; plan-review 3S13).
    - `set_dataset_metadata()` roxygen gains `@section Attribute persistence:` naming base `[`, `as_tibble()`, `merge()` and the §V.4 resurrection note (spec §XII.4); P20 is its behavioral gate (plan-review 3R9).
    - Merge-order invariance toward PR 6 (plan-review 3R13, mirroring 2R7): no new `_snaps/constructors.md` block captures `print()` or `summary()` console output of a design carrying dataset metadata; construction snapshots capture the warning message only, with the design assigned.
    - `.read_dataset_attributes()` is not modified in this PR (plan-review R8 — the handshake for PR 2's review-verified `dropped` report).
    - `expect_dataset_roundtrip()` is defined exactly once, in `helper-test-data.R` (plan-review 2S2).
    - Every constructing block opens with `test_invariants(design)`.
    - Scoped snapshot/test-file guard holds (own test files: `test-constructors.R`, `test-dataset-metadata.R`, `helper-test-data.R`; appended snapshot files: `_snaps/constructors.md` and `_snaps/dataset-metadata.md`, addition-only — every pre-existing block byte-identical; `_snaps/methods-print.md` untouched whole-file — plan-review 3S15).
    - Profile gates (test-spec §13) all pass; new-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/utils.R`
    - `R/core-constructors.R`
    - `R/core-metadata.R` (roxygen `@section` only)
    - `plans/error-messages.md`
    - `tests/testthat/test-constructors.R`
    - `tests/testthat/test-dataset-metadata.R`
    - `tests/testthat/helper-test-data.R`
    - `tests/testthat/_snaps/constructors.md`
    - `tests/testthat/_snaps/dataset-metadata.md`
    - `man/set_dataset_metadata.Rd` (regenerated)

  - **Pipeline split**: recommended (constructor behavior change; new warning class in play)

- [x] PR 6: `feature/dataset-metadata-print` — print and summary lines, print helpers (depends on PR 3 only; may ship concurrently with PR 4 and PR 5)

  - **Tasks** (8)
    1. Taylor header. RED: write the §9 grid `print(d)` cells for taylor states (a), (b), (c) in `tests/testthat/test-methods-print.R` (state (a) re-runs the existing snapshot); confirm the (b)/(c) cells fail. GREEN: implement `.dataset_display_name()` at the top of `R/methods-print.R` (fallback rule; §X.5 sanitation and truncation) and wire the taylor header line. VERIFY: rerun; the pre-existing state-(a) blocks are byte-identical.
    2. Remaining headers. RED: write the `print(d)` grid cells for replicate, twophase, nonprob (states per the grid; `N` cells as `expect_no_error`) and test-spec §9 row PR7 (nonprob_rep placement); confirm failure. GREEN: wire the three remaining print headers at the §X.1 positions (data-variable `cli::cli_text()` calls only). VERIFY: rerun plus the file.
    3. Metadata block. RED: write the `metadata_info = TRUE` grid cells and test-spec §9 rows PR1, PR2, PR3, PR4, PR5, PR6, PR10; confirm failure. GREEN: implement `.print_dataset_block()` (§X.2 lines; duplicate-`Survey:` suppression via `header_name`) and wire the four `metadata_info` sections. VERIFY: rerun plus the file.
    4. Full layout (restated per plan-review 6R1; cell scope completed per Pass 7 suggestion). RED: write the `full = TRUE` grid cells for all four classes, states (a)–(c) — the `S` cells are taylor a/b/c, replicate a, and nonprob b (the nonprob method's `full` sets a different `*_info` set and its header branch differs, so it is exercised directly); the remaining cells are `N` (`expect_no_error`); confirm state — every print method reduces `full` to `metadata_info <- TRUE`, so the task-1–3 wiring carries these cells. GREEN: none expected; fix the wiring if a per-method gap appears. VERIFY: rerun.
    5. Summaries. RED: write the `summary(d)` grid cells (states a, b, c per the grid); confirm failure. GREEN: wire the `Dataset:` line into the four summary methods (§X.4 placement). VERIFY: rerun plus the file.
    6. Hardening. RED: write test-spec §9 rows PR8 and X9; confirm state. GREEN: fix the helpers if any hardening gap appears. VERIFY: rerun.
    7. Stale objects. RED: write test-spec §9 row PR9 (4 classes × 4 calls; snapshot the taylor `print(old)`; `expect_no_error` for the other fifteen); confirm state. GREEN: none expected (guarded reader). VERIFY: rerun.
    8. Closing gate: `devtools::document()` (confirm `man/` and NAMESPACE unchanged), full suite, `devtools::check()`; verify the scoped snapshot guard.

  - **Notes** (process)
    - Fixture-gap deviation rule (plan-review 3S4): PR 6 runs concurrent with PR 5, which owns `helper-test-data.R`. A fixture gap discovered during implementation forces PR 6 to serialize after PR 5 — PR 6 must not touch that file while the PRs are concurrent.
    - Write-surface forward note (plan-review 3R13): `_snaps/constructors.md` joins this PR's write surface if PR 5's construction-snapshot criterion (no console output of metadata-carrying designs) is ever relaxed.

  - **Acceptance criteria**
    - Every `S` cell of the test-spec §9 grid passes with a reviewed snapshot; every `N` cell passes `expect_no_error`; test-spec §9 rows PR1, PR2, PR3, PR4, PR5, PR6, PR7, PR8, PR9, PR10, X9 pass.
    - State-(a) cells prove byte-identical output to 1.1.0.
    - Test-spec §9 row PR9 passes: all sixteen stale-object calls succeed with no dataset lines, reaching all four print methods and all four summary methods.
    - Test-spec §9 rows PR8 and X9 pass: hostile values never abort `print()`; braces render literally; `\n`, `\r`, `\t` each render as a space; truncation is 57 characters plus `...` — on the header path and on the block path.
    - Merge-order invariance (plan-review 2R7): no PR 6 test calls a PR 4 convenience setter/extractor or constructs a survey object from `make_dataset_df()` output — all metadata state is applied via `set_dataset_metadata()` on a constructed design, so PR 6's snapshots are invariant to PR 4/PR 5 merge order.
    - Verified by review (2S9 pattern; plan-review 3S14): no direct `@dataset_metadata` read exists outside the guarded helpers and the setter write path (spec §II.3) — the print helpers read via the guarded reader only.
    - Every constructing block opens with `test_invariants(design)`.
    - Scoped snapshot/test-file guard holds (own test file: `test-methods-print.R`; appended snapshot file: `_snaps/methods-print.md`, addition-only — every pre-existing block byte-identical; `_snaps/dataset-metadata.md`, `_snaps/metadata-system.md`, and `_snaps/constructors.md` untouched whole-file — plan-review 3S15).
    - This PR's write surface is disjoint from PR 4's and PR 5's (concurrency-safe); the PR modifies no fixture.
    - Profile gates (test-spec §13) all pass; new-code coverage ≥98% target, merge blocked below 95% (test-spec §12).

  - **Files touched**
    - `R/methods-print.R`
    - `tests/testthat/test-methods-print.R`
    - `tests/testthat/_snaps/methods-print.md`

  - **Pipeline split**: recommended (user-visible output contract across eight methods)

- [x] PR 7: `feature/dataset-metadata-docs` — vignette, NEWS, DESCRIPTION (depends on PR 5 and PR 6)

  - **Tasks** (3)
    1. Add the "Dataset-level metadata" section to `vignettes/creating-survey-objects.Rmd`: the data-raw workflow, `survey_name`/`data_name` shown side by side with the independence statement, the attribute-persistence paragraph (base `[`, `as_tibble()`, `merge()` drop attributes — set metadata last or on the design), and the sentence naming `extract_metadata()`'s exclusion of dataset-level keys (plan-review R13; spec §XII.3/§XII.8).
    2. Create the `# surveycore (development version)` heading above `# surveycore 1.1.0` in `NEWS.md` (the heading does not exist yet — plan-review 2S8; `/merge-main` renames it at release, plan-review S18). Under it: the new-API list, the serialization caveat, and a separately-described bullet for the `as_survey_nonprob()` weighting-history fix (plan-review 2S3). Extend the DESCRIPTION `Description` field; `Version:` stays `1.1.0.9000` (the release bump belongs to `/merge-main`).
    3. Closing gate: knit the vignette, `pkgdown::build_site()`, full suite, `devtools::check()`.

  - **Acceptance criteria**
    - The vignette builds and contains — verified by review against spec §XII.3 and §XII.8 (plan-review 3S6, 2S9 pattern): the data-raw workflow (§XII.3), the independence statement (§XII.3), the attribute-persistence paragraph naming the droppers (§XII.3), and the `extract_metadata()` carve-out sentence (§XII.8).
    - `NEWS.md` carries — verified by review against spec §XII.6 (plan-review 3S6): the feature list, the serialization caveat, and the separately-described weighting-history-fix bullet under a newly created `# surveycore (development version)` heading above `# surveycore 1.1.0`; no `1.2.0` heading exists (release prep owns it).
    - DESCRIPTION `Version:` is unchanged; only the `Description` field text changes — content verified by review against spec §XII.7 (plan-review 3S6).
    - Scoped snapshot/test-file guard holds (own test files: none; no `_snaps/**` change).
    - Profile gates (test-spec §13) all pass; no new R code, so the covr gate carries forward unchanged from PR 6 (plan-review 2S12).

  - **Files touched**
    - `vignettes/creating-survey-objects.Rmd`
    - `NEWS.md`
    - `DESCRIPTION`

  - **Pipeline split**: optional (no exported function, no contract change, 3 files touched)

---

## Spec-contract coverage map

| Spec contract item | Covered by |
|---|---|
| §I.3 class/design support matrix (four classes + data frames + collection rejection, per export; three named no-change conversion surfaces) | PR 2 (`extract_dataset_metadata`), PR 3 (setter; S25a–S25c round-trip clause), PR 4 (ten wrappers; E9/E10; S25 pair completion; guard completion), PR 5 (P16–P18, P19a/P19b, X12 `as_tbl_svy()`), PR 6 (§9 grid) |
| §II storage model, canonical order, independence rule | PR 1 (C2, C3), PR 3 (S6b, S6c), PR 4 (S10, S11, E10) |
| §II.3 direct-read prohibition | Review-verified criteria in PR 4 and PR 6 (plan-review 3S14) |
| §III property, validator, roxygen | PR 1 (C1–C11; `man/survey_metadata.Rd`; Layer-1 DM-3a/DM-6c rendering per 2R12); Rd-link conversion in PR 4 |
| §II.3 helpers: `.check_dataset_key_value()` | error/val + catch-and-re-raise register split (3R5): PR 1; `mode = "skip"`: PR 2; `key_style = "arg"`: PR 4 |
| §II.3 helpers: `.dataset_metadata_or_empty()`, `.coerce_field_date()`, `.read_dataset_attributes()`, `.get_dataset_metadata_list()`, `.format_dataset_result()` | PR 2; `.coerce_field_date()` serves both checker modes — the error-mode ISO acceptance that PR 3's X10 asserts ships here (plan-review 5R2) |
| §IV guarded reads / typed write failure | PR 2 (B0, B1 extractor clause), PR 3 (S24, X4), PR 4 (S24/B1/B2 completion, X6), PR 6 (§9 row PR9) |
| §V promotion, `.promote_dataset_metadata()`, nonprob weighting-history fix | PR 5 (P1–P22, X7, X8, `expect_dataset_roundtrip()`); reader delivered in PR 2 with E23 executing the invalid-legacy-`dates` branch (2R8 handshake via PR 5's unmodified-reader criterion) |
| §VI `set_dataset_metadata()` (incl. §VI.1 `as.list(value)` roxygen sentence per 3R12; §VI.4 column-name key X11; §VI.5 ISO-via-general-setter X10; §VI.5 effective-pair DM-4b dual X15 per 4R10; §VI.6 parser parameterization; SC1–SC5 convention rows) | PR 3 |
| §VII five convenience setters (incl. §VII.1 wrapper `setter_empty` templates recorded on M-4 in PR 1; §VII.1/§XI DM-3b wrapper duals X13 per 3R11) | PR 4 (templates and duals asserted); PR 1 (table rows) |
| §VIII `extract_dataset_metadata()` (incl. §VIII.1 fill widening; SR1; §VIII.1 not-tidy-select roxygen sentence per 3R12); completed DM-5b via the extractor (X14) | PR 2; X14 in PR 3 (3J2) |
| §IX five convenience extractors | PR 4 |
| §X print/summary changes and helpers | PR 6 |
| §XI error/warning table | PR 1 (all rows except DM-7; trigger extension; fill variant; M-4 wrapper variants; M-3 extractor variant per 3R4), PR 5 (DM-7a–d); message-text review criteria at PR 2/3/4/5 (S9/3S9) and `expect_error(regexp=)` at PR 1 |
| §XII docs/release | PR 1 (`man/survey_metadata.Rd`), PR 2–4 (roxygen per export with §XII.5 named-only and §XII.9 family/return/examples; `_pkgdown.yml` incrementally per exporting PR per 2B1; §XII.8 roxygen half in PR 4 with its Rd-diff criterion per 3R8), PR 5 (§XII.4 `@section` with its criterion per 3R9), PR 7 (vignette incl. §XII.8 vignette half, NEWS, DESCRIPTION — review-verified per 3S6) |
| §XIII quality gates | Each gate maps to the PR that owns its behavior: class gates PR 1; extractor/setter gates PR 2–4; round-trip, legacy-`dates`, non-destruction, twophase/import, nonprob-fix gates PR 5; print/byte-identity and stale-object gates PR 6; error-table and check gates every PR's closing task. Byte-identity asserted via the scoped snapshot guard (2R10/3S15) |
| §XIV integration contracts | No PR touches surveytidy/surveywts surfaces; collection rejection covered under the §I.3 row |
