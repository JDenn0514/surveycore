# Implementation — PR 6: fay-rho-print

**Branch**: `feature/fay-rho-print`
**Base**: `5273462` (tree `8183fde`)
**Head**: `f6b19a1`

## Write surface

- Modified: `R/methods-print.R`
- Modified: `tests/testthat/test-methods-print.R`
- Modified: `tests/testthat/_snaps/methods-print.md` (added entries only, 173 lines)
- Created: none. Deleted: none.

## Summary

- Added the internal helper `.fay_rho_to_print()` to `R/methods-print.R`,
  as spec §II gives it. It returns the stored `rho` for a Fay design whose
  `rho` passes `.is_valid_rho()`, else `NULL`.
- `print()` for `survey_replicate` calls the helper once. When it returns a
  value, the class line gains `, rho = {.val {rho}}` and the full print adds
  the bullet `Rho: {.val {rho}}` directly after `Scale:`.
- `summary()` for `survey_replicate` calls the helper once and does the same
  for the type line and the `Rho:` line after `Scale:`.
- When the helper returns `NULL`, the template strings are the same
  characters as before, so the output of every other type is unchanged.
  `git diff` on `_snaps/methods-print.md` shows insertions only.

## Tasks

- [x] 1. Default print snapshot of FA (Fay, `rho = 0.5`, scale 0.4); class
  line `<survey_replicate> (FAY, 10 replicates, rho = 0.5)`.
- [x] 2. Full print snapshot; `Rho: 0.5` directly after `Scale: 0.4`.
- [x] 3. Summary snapshot; type line with `rho = 0.5`, `Rho: 0.5` after
  `Scale: 0.4`.
- [x] 4. Fay design rebuilt by hand with `survey_replicate()` and no `rho`
  key: snapshot of `print(d, full = TRUE)` and `summary(d)`, no `Rho:` line
  and no `rho =` text.
- [x] 5. Helper and both methods implemented.
- [x] 6. Snapshots read and checked (below). `devtools::document()` left no
  diff. `air format --check` passes on both changed `.R` files.

Two extra blocks use the same hand-rebuilt design. A Fay design with an
unusable stored `rho` (`1`, `-0.1`, `NA_real_`, length 2, `"0.5"`, a 1 x 1
matrix) prints no rho. A BRR design with a stored `rho = 0.5` key prints no
rho.

Tasks 1 to 3 also carry explicit line assertions next to each snapshot, so
a block fails if a snapshot is accepted with the wrong content. The full
print assertion strips the bullet glyph first, because cli draws it as `*`
or as a Unicode dot, by locale.

## Snapshot review

`snapshot_review()` needs an interactive session, so it was not run. I read
each of the four new entries in the `git diff` of
`tests/testthat/_snaps/methods-print.md` before I committed them:

- `print.survey_replicate class line shows rho for a Fay design`: the class
  line reads `<survey_replicate> (FAY, 10 replicates, rho = 0.5)`.
- `print.survey_replicate full=TRUE puts the Rho line after Scale`:
  `* Scale: 0.4`, then `* Rho: 0.5`, then `* MSE: TRUE`.
- `summary.survey_replicate shows rho on the type line and after Scale`:
  `Type: replicate weights (FAY, 10 replicates, rho = 0.5)`; `Scale: 0.4`,
  then `Rho: 0.5`, then `MSE: TRUE`.
- `a Fay design with no rho key prints and summarises no rho`: no `Rho:`
  line and no `rho =` text in either output.

The diff has no `-` lines, so no existing entry changed.

## HOLDs

None.

## Notes for tester

- The worktree opened on `d4d1db2`. It was reset to `5273462` before work
  started.
- One full-suite run (`NOT_CRAN=true`) was made at the head commit. A test
  run rewrites line endings in about 30 unrelated `_snaps/` files; those
  were reverted and are not in the commit.
