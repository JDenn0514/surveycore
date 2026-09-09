# implementation.md — PR 3, `fix/svydesign-replicate-guards`

Spec: `archive/svydesign-replicate-bridge/spec-svydesign-replicate-bridge.md` §I.1 rows 4, 5, 7, 8 —
§III.2 steps 1, 3, 7 and 8, the four import refusals.

Base: `4c79a5b3bd75a41a9faf27e09906115142143204`. The worktree came up on
`d4d1db2` again, so it was `git reset --hard` to the stated base before any
code was written.

Commit: `c9c93ca` — `fix(conversion): refuse four unusable replicate sources
on import (#197)`. The tree is clean; nothing is left unstaged.

## Write surface

| File | Change |
|---|---|
| `R/methods-conversion.R` | Modified — four guards inside `.from_svydesign_replicate()` |
| `plans/error-messages.md` | Modified — one new dated section, 36 lines appended, 0 deleted |
| `tests/testthat/test-conversion.R` | Modified — 216 lines appended, 0 deleted; blocks R-24 to R-30 |
| `tests/testthat/_snaps/conversion.md` | Created by the test run — four snapshots |

`man/` and `NAMESPACE` are unchanged: `devtools::document()` ran and moved
neither. `NEWS.md` is untouched. `git diff --name-only origin/develop HEAD`
lists exactly the four files above.

## Summary

- **Step 1 — the replicate type check, first in the route.** Reads `x$type`
  and refuses any value outside the nine `as_survey_replicate()` accepts,
  with `surveycore_error_replicate_type_unsupported`. It runs before the
  data read and before the matrix expansion, so the route does no column
  work for a design it refuses.
- **Step 3 — the row count check**, immediately after
  `data <- .strip_labelled_columns(as.data.frame(x$variables))`. When
  `nrow(data)` is 0 the route raises `surveycore_error_empty_data` with the
  import-route message from §V.6, not row 2's `{.arg data}` template.
- **Step 7 — the usable-name check**, right after step 6 resolves the names.
  `usable <- rep_cols[!is.na(rep_cols) & nzchar(rep_cols)]`, then
  `n_names <- length(unique(usable))`; a mismatch against `n_rep` raises
  `surveycore_error_repweights_names_lost`.
- **Step 8 — the generated-name collision check**, guarded by the
  `names_generated` local that PR 1 recorded. It compares the generated
  names against `names(data)` and raises
  `surveycore_error_repwt_name_collision`. The check is skipped entirely
  when the names came from `survey`.
- **`plans/error-messages.md`** gains the `### svydesign-replicate-bridge
  rows (2026-09-04)` section: the precedent paragraph, the whole
  seven-binding paragraph, rows CB-1, CB-2 and CB-5, one line saying CB-3
  and CB-4 land with the export route, and the extended trigger note for
  row 2. Row 2 itself (line 32) is byte-identical; the diff is 36
  insertions and 0 deletions.

## Task checklist

- [x] 1. New dated section appended after `### var-extension-slot rows
      (2026-08-27)`, which was still the last section. Heading, precedent
      paragraph and bindings paragraph taken verbatim from §V.7.
- [x] 2. Rows CB-1, CB-2 and CB-5 appended verbatim. CB-3 and CB-4 omitted.
- [x] 3. One three-line note records that CB-3 and CB-4 land with the export
      route, in the two pull requests that follow, so the numbering gap
      explains itself. No branch is named.
- [x] 4. Row 2's extended trigger note appended. The row 16 note is not
      added. Row 2 itself is unchanged.
- [x] 5. Step 1 — `surveycore_error_replicate_type_unsupported`, first step
      in the route.
- [x] 6. Step 3 — `surveycore_error_empty_data`, with the route's own
      message.
- [x] 7. Step 7 — `surveycore_error_repweights_names_lost`, computed exactly
      as step 7 writes it.
- [x] 8. Step 8 — `surveycore_error_repwt_name_collision`, generated branch
      only. Rendered and read at one collision and at three.

Nothing in spec §IV was touched. No `surveycore_warning_replicate_fpc_dropped`
and no `surveycore_error_fay_rho_unrecoverable` appears in the code or the
table.

## Tests added — blocks R-24 to R-30

| Block | Asserts | Snapshot |
|---|---|---|
| R-24 | `subbootstrap` source raises the type error | yes |
| R-25 | `mrbbootstrap` source raises the type error | no — class only |
| R-26 | zero-row `svyrep.design` raises the empty-data error | yes |
| R-27 | a matrix with two empty-string names raises the name error | yes |
| R-28 | a matrix with a repeated name raises the name error | no — class only |
| R-29 | one generated name already in the data; singular rendering | yes |
| R-30 | three generated names already in the data; plural rendering | no — class and two `expect_match()` |

Four snapshots, one per class. Each block also asserts its precondition, so
a failure separates a wrong guard from a source design that is not in the
state the block intends: R-24 and R-25 assert `sv$type`; R-26 asserts
`nrow(sv$variables)` 0 and a 0 by 0 matrix; R-27 and R-28 assert
`colnames(sv$repweights)`; R-29 and R-30 assert `colnames(sv$repweights)`
has length 0, which is what puts step 6 on the generating branch.

Both `survey::as.svrepdesign()` calls in R-24 and R-25 sit inside
`suppressWarnings()`, so survey's own bootstrap heuristic warnings stay out
of the assertions.

Every block that PRs 1 and 2 added still passes, unedited. No guard refuses
a source design that an existing block converts.

## Gate results

| Gate | Result |
|---|---|
| `air format --check R/methods-conversion.R tests/testthat/test-conversion.R` | exit 0. `air format` was run on the test file first and rewrote only new lines — 216 insertions, 0 deletions. |
| `devtools::document()` | `NAMESPACE` and `man/` unchanged. |
| `Rscript -e 'devtools::test()'` | `FAIL 0 | WARN 256 | SKIP 4 | PASS 11366`. Baseline was `FAIL 0 | WARN 256 | SKIP 4 | PASS 11343`: failures stay 0, the warning count does not rise, and 23 expectations are added. |
| `git status --porcelain` after the full run | 31 `_snaps/*.md` files came up modified by line endings only and were restored with `git checkout -- tests/testthat/_snaps/`. `_snaps/conversion.md` is untracked at that point, so the restore does not touch it. |
| `git diff --name-only origin/develop HEAD` | Exactly the four files. |

`run-gates.sh`, `R CMD check`, `pkgdown::build_site()` and `covr` were not
run, as instructed.

## Notes for tester

1. **`cli::qty()`, not bare `qty()`.** Spec §V.2 and row CB-2 write
   `{qty(n_collisions)}`. That form throws
   `Could not evaluate cli {} expression: qty(n_collisions) / could not find
   function "qty"` from inside `.from_svydesign_replicate()`, because the
   package uses `::` everywhere and imports no cli function. The code uses
   `{cli::qty(n_collisions)}`, which is the house pattern already in
   `R/analysis-corr-latent.R:1721` and `R/survey-collection.R:660`. The
   rendered message is identical — `qty()` emits no text — so the table row
   stays verbatim as §V.7 writes it. Both numbers were rendered and read:
   one collision gives "The design data already has a column named
   ..surveycore_repwt_2..." and "Rename the conflicting column"; three give
   "has columns named ..., ..., and ..." and "Rename the conflicting
   columns", with no double space.
2. **The type check tolerates a length-0 or length-2 `x$type`.** The
   predicate is `!isTRUE(rep_type %in% accepted)`. A bare
   `!rep_type %in% accepted` would itself error on a `NULL` type with
   "argument is of length zero" instead of raising the typed condition. No
   route through `survey` produces such a value, so no test drives it; it
   adds no line of its own.
3. **How the zero-row source is built.** `survey::svydesign(ids = ~1, ...)`
   on a zero-row frame fails inside survey with "lengths of prob/weights and
   ids don't match". `ids = ~psu` builds, and
   `survey::as.svrepdesign(type = "JK1")` on it gives `nrow(variables)` 0, a
   0 by 0 matrix and `length(pweights)` 0. Measured: neither call warns.
   Subsetting a built design with `svf[FALSE, ]` reaches the same state and
   is the second route, if a future block needs one.
4. **Step 8 reads PR 1's `names_generated` local.** It was already there and
   was not recomputed.
5. **Row 2 of `plans/error-messages.md` is untouched.** The whole file diff
   is append-only: `git diff --stat` reports 36 insertions and 0 deletions.

## HOLDs

None.
