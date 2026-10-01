# Review — PR 8 — twophase-replicate-phase1

**Verdict**: PASS
**Date**: 2026-09-30

Tree reviewed: 4109fb32ea236a0061db32a3a0733815ea39d760 (HEAD c880ebd, base
develop ae37e4e). The reviewer read the diff `ae37e4e..HEAD` and ran one
read-only parse probe. No gate was re-run.

## Convergence checks
- Spec coverage: y. Every item of spec §IX.2 to §IX.6 has a row in the audit
  table (7.1 to 7.6, 1.26, 6.10, 6.11).
- Test coverage of spec: y. §IX.2 order maps to 7.3; every type to 7.2 and
  1.26; the taylor and nonprob non-refusals to 7.4 and 7.5; §IX.4 to 7.6;
  §IX.5 sites to the "Existing blocks that change" list; §IX.6 to 6.10, 6.11.
- Tolerance integrity: y. No new block has a numeric assertion. The two
  deleted `1e-8` scale assertions left with a block that spec §IX.5 and the
  test-spec delete by name. No tolerance was relaxed.
- Scope discipline: y. Seven files in the diff, identical to the plan's
  Files touched list for PR 8. No file created or deleted.
- Regression safety: y. Suite FAIL 0, warnings 256 against 256, skips 4
  against 4, notes 2 against 2, coverage 96.16% to 96.17%.

## Focus checks
- TP-1 template. The code strings concatenate to the §IX.3 text word for
  word. The `"v"` split point differs ("cluster, " / "strata and weight
  columns.") to keep 80 columns; the rendered text is identical. The
  `plans/error-messages.md` row is byte-identical to the planning copy
  (`diff` on the TP-1 line). The new snapshot shows the same x/i/v text.
- Row 19. The code `"i"` bullet and the register template match §IX.4,
  including `[[1L]]`. The old `as_survey_srs()` name is gone. The row-19
  snapshot `i` line reads "Create it first with `as_survey()`."
- Check order. TP-1 sits directly after the `phase1_class` check and before
  `phase1@data` and every `subset` check. It uses
  `S7::S7_inherits(phase1, survey_replicate)`.
- Roxygen. `@param phase1` and `@seealso` carry the §IX.6 text. The page
  makes no claim about a nonprob phase 1. The `.Rd` file agrees.
- NEWS.md. One item under `## Breaking changes`, equal to the §IX.6 text.
  Nothing else was added.
- `test_invariants()`. A walk over the parsed call tree of each file finds
  4 calls in `test-constructors.R`, one per constructor. The one two-phase
  call is in "as_survey_twophase() accepts survey_taylor phase-1 (weights
  only, no ids/strata)". `test-variance-twophase.R` has 0, at base and head.
- Deleted blocks. "carries the phase-1 scale of both changed types" and
  "two-phase with survey_replicate phase-1 constructs and estimates" are
  gone. The header reads "Section 5: SRS phase-1 designs".
- Snapshots. implementation.md records that the builder read the pending
  diff (two entries, both described) before `snapshot_accept("constructors")`.
  The committed `_snaps/` diff holds exactly those two entries, in one file.

## Cross-consistency notes
- The gate summary line "changed R/ files: 5, uncovered lines in them: 19"
  counts against a wider base than this PR. This PR changes one `R/` file.
  The audit names its three uncovered lines (414, 2001, 2092), and none is in
  this PR's hunks. Not a defect.
- One `expect_error()` wrapper around `as_survey_twophase()` outside the
  constructor file (`test-labelled-storage.R` S-30) builds a Taylor phase 1
  and names its class, so the refusal cannot satisfy it by accident.
- Comprehension gotcha "Two-phase with a Fay phase 1" is now refused, and
  rows 7.2 and 1.26 cover it.

## Decision
PASS. The code, register, snapshot, roxygen and NEWS match spec §IX word for
word, the write surface matches the plan, and every gate is clean with no
change in warnings, notes or coverage floor.
