# Review — PR 6 fay-rho-print

**Verdict**: PASS
**Branch**: feature/fay-rho-print, HEAD f6b19a1
**Base**: develop 5273462
**Tree**: 43958277b43d0f9e2e3ee6839bae51339351e6a2 (checked with `git rev-parse HEAD^{tree}`)

## 1. Convergence

| Spec item (§II, §VII) | test-spec row | audit row | Code | Result |
|---|---|---|---|---|
| Class line of `print()` adds `, rho = {rho}` | 5.1 | 5.1 | `R/methods-print.R` 379-390 | ✓ |
| `Rho:` line directly after `Scale:` in full print | 5.2 | 5.2 | 423-425 | ✓ |
| Type line of `summary()` adds the suffix; `Rho:` after `Scale:` | 5.3 | 5.3 (two rows) | 831-841, 855-857 | ✓ |
| A Fay design with no usable rho prints no rho | 5.4 | 5.4 (three rows), extra row "unusable stored rho" | helper gate | ✓ |
| Other types unchanged, byte for byte | 5.5 | 5.5, extra row "BRR with a stored rho key" | helper gate | ✓ |
| `survey_nonprob` print does not change | none needed (spec states it) | none | `git diff` has no hunk in the nonprob method | ✓ |

Points the orchestrator asked about, read from `git diff 5273462 HEAD -- R/`:

- `.fay_rho_to_print()` is byte-equal to spec §II. Its gate (`identical(type, "Fay")` and `.is_valid_rho(rho)`) is written once, in the helper.
- `print()` and `summary()` each call the helper exactly once. Each builds the suffix and the `Rho:` line from the one value, both with `{.val {rho}}`.
- When the helper returns `NULL`, `paste0()` joins the same characters as the old template string. So the output of every other type is unchanged.
- `git diff --numstat` on `_snaps/methods-print.md`: 173 added, 0 removed. No `-` line in the diff.
- The four new snapshot entries read as spec §VII gives them: `(FAY, 10 replicates, rho = 0.5)`, `* Scale: 0.4` then `* Rho: 0.5`, the summary type line, and `(FAY, 10 replicates)` with no rho for the hand-built design.
- `implementation.md` §Snapshot review records that the builder read each new entry in the diff before the commit, because `snapshot_review()` needs an interactive session. Tasks 1 to 3 also assert the lines directly, so a snapshot accepted with wrong content turns the block red.

## 2. Tolerance integrity

The one numeric row (5.1 stored scale) uses 1e-8, equal to test-spec §Tolerances "stored scale against its literal". Every other row is an exact string or logical comparison. No row is looser.

## 3. Scope discipline

`implementation.md` §Write surface, `git diff --name-only 5273462 HEAD` and plan PR 6 Files touched all name the same three files. No extra file, no missing file. Pass and fail counts moved only by the 42 new expectations (12242 to 12284). Warnings stay at 256, skips at 4.

## 4. CRAN cookbook and profile gates

The cookbook table says None, and the audit verdict is PASS. All seven gates have a result in `gates/summary.txt`. `gate-5-check.log` line 100 reads `Status: 2 NOTEs`: the CRAN incoming feasibility note (pre-approved) and the `.git` hidden-file note (accepted by criterion G item 4). No gate was skipped.

## 5. Coverage

96.16%, above the 95% floor, and equal to the baseline. The uncovered lines in `R/methods-print.R` (556, 559, 582, 659, 909, 915) are outside the PR's added lines. The other uncovered lines in `gate-7-covr.log` are in files this PR does not change.

## 6. Comprehension alignment

Comprehension M9 (no rho in print today) and the open question "show rho or not" are settled by decision S5 and spec §VII. Comprehension line 263 names the `survey_nonprob` `Scale:` line; spec §VII puts it out of scope with a reason. No gap.

## Observations (no effect on the verdict)

- Audit says the file calls `test_invariants()` for `as_survey_replicate()` "in the first block that builds with that constructor". This is not accurate. The block at line 217 builds a replicate design earlier and has no such call; before this PR the file had no replicate call. The new call at line 1935 adds coverage that was missing, so this PR breaks no rule. A later clean-up can move the call to the first replicate block.
- `gates/summary.txt` reports "changed R/ files: 5" for covr. That count is not taken against this PR's base, which has one changed `R/` file. The per-line figures above are correct.

## Verdict

PASS. All seven checks are clean, and `audit.md` is PASS.
