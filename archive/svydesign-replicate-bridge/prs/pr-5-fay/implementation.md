# implementation.md — PR 5, `fix/svydesign-replicate-fay`

Base: `8c99271880c68e5da300985c4e935a2c23ae134d`. The worktree came up on
`d4d1db2`, as it did on the four earlier pull requests; `git reset --hard`
put it on the stated base before any code was written.

Commits: `0b40e45` — `fix(conversion): recover Fay's shrinkage factor on the
export route (#198)`, and `56cfc92` — `test(conversion): one invariants call
per constructor, and guard the silent branch (#198)`, and `980e681` —
`test(conversion): guard the export of a zeroed replicate column (#198)`.
The last two fix two BLOCKs and close two coverage gaps. The tree is clean.

## Write surface

Modified — four files, no others:

- `R/methods-conversion.R`
- `plans/error-messages.md`
- `tests/testthat/test-conversion.R`
- `tests/testthat/_snaps/conversion.md`

Created: none. Deleted: none. `man/`, `NAMESPACE` and `NEWS.md` are
untouched; `devtools::document()` produced no diff.

## What was implemented

- `.as_svydesign_replicate()` recovers Fay's shrinkage factor from the
  recorded scale — `rho <- 1 - sqrt(1 / (scale * n_rep))` — and passes it to
  `survey::svrepdesign()`. Without it the route stopped outright for every
  Fay design, with survey's own `With type='Fay' you must supply the correct
  rho`. The step sits between the scale argument computation and the FPC drop
  warning, as spec §IV.2 orders it.
- The scale argument is unchanged: `NULL` for both `"BRR"` and `"Fay"`.
  `survey` recomputes the scale from the recovered `rho`, so the rebuilt
  scale equals the stored one. Measured: `fay.rho = 0.3` recovers 0.3, and
  the exported design reports the source's scale, 0.255102, and the source's
  standard error, 0.1225384.
- The route raises `surveycore_error_fay_rho_unrecoverable` when the type is
  `"Fay"` and the recorded scale is `NULL`, non-finite or not greater than 0,
  or when the recovered factor is `NA` or falls outside `[0, 1)`. The
  `{scale_txt}` binding is a character string on every branch, `"none"` on
  the `NULL` one.
- `rho` reaches the call as `rho = rho_arg`, which is `NULL` for every type
  but `"Fay"`. `NULL` is `svrepdesign.default`'s own default for the
  argument, so no other type sees a change.
- `plans/error-messages.md` gains row CB-4 in CB order, loses the one-line
  pending-rows note, and CB-3 gains the trailing `|` it was missing.

## Tasks

- [x] 1. Insert CB-4 into `### svydesign-replicate-bridge rows (2026-09-04)`,
      verbatim from spec §V.7, between CB-3 and CB-5.
- [x] 2. Remove the pending-rows note that named CB-4.
- [x] 3. Append CB-3's missing trailing pipe; nothing else in that row.
- [x] 4. Recover Fay's `rho` and pass it; step 3 unchanged.
- [x] 5. Raise `surveycore_error_fay_rho_unrecoverable` on the five refusal
      conditions, with `{scale_txt}` a string on every branch, and no
      `# nocov` on either arm.
- [x] 6. Tests X-8 to X-17 (below), two new snapshots.
- [x] 7. BLOCK fix: one `test_invariants()` call per constructor in
      `test-conversion.R`, plus block X-18 for the silent branch's export
      parity (commit `56cfc92`).
- [x] 8. BLOCK fix: block X-19, the export of a design whose replicate column
      holds zeros (commit `980e681`).

## Tests added — `tests/testthat/test-conversion.R`

Twelve blocks, X-8 to X-19, appended to the export-route section, plus two
helpers, `make_taylor_source()` and `make_rep_type()`. Ten came with
`0b40e45`; X-18 arrived with the BLOCK fix in `56cfc92` and X-19 with the
BLOCK fix in `980e681`. The section index comment at the head of the section
lists all twelve.

| Block | Covers |
|---|---|
| X-8 | A Fay design exports; `rho` recovers 0.3; the exported scale and SE match the source (§VI property 9) |
| X-9 | `as_survey_replicate(type = "Fay")` with no scale gives `1 / n_rep`, recovers `rho = 0`, and converts |
| X-10 | Out-of-range arm: scale 0.05 over 8 replicates, class + snapshot |
| X-11 | Missing-scale arm: bare `survey_replicate()`, class + snapshot |
| X-12 | Round trip on a JKn source — point 1e-10, SE 1e-8, CI 1e-6 |
| X-13 | Round trip on a Fay source, same tolerances |
| X-14 | Round trip through the FPC drop; the export leg warns and the numbers still match |
| X-15 | Export parity for `"bootstrap"` |
| X-16 | Export parity for `"JKn"` |
| X-17 | All nine accepted types cross both routes |
| X-18 | `"bootstrap"` with no FPC: no condition raised, and export parity (added by `56cfc92`) |
| X-19 | A `"JK1"` design whose first replicate column is all zeros: no condition raised, the zeros pass through, and export parity (added by `980e681`) |

Two snapshots added, in X-10 and X-11. The six already in
`_snaps/conversion.md` are byte-identical; the file's diff is 22 added lines
and nothing else. No block that the earlier pull requests wrote was edited.

## BLOCK fix — 2026-09-08, commit `56cfc92`

The BLOCK was a contract miss on test organization. `test-conversion.R`
called `test_invariants(d)` twice for designs built by
`as_survey_replicate()`: once in X-1, which predates this branch, and once
in X-9, which commit `0b40e45` added. `.claude/rules/testing-surveycore.md`
allows one call per constructor per test FILE, in the first block that
builds with it.

- Deleted the `test_invariants(d)` call in X-9. Every other assertion in
  that block is unchanged; the block still asserts the default Fay scale,
  the recovered `rho = 0`, the rebuilt scale and export parity.
- Added block X-18, and its line in the section index comment. A
  `"bootstrap"` design that records no FPC converts under
  `expect_no_warning()`, and the exported design reproduces
  `get_means(d, y1, variance = "se")` — point estimate to 1e-10, standard
  error to 1e-8. X-5 covers the silent branch with no parity assertion, and
  X-15 covers bootstrap parity through the FPC drop, which warns. Neither
  covers the pair, so nothing in the suite guarded it.
- Fixture: `make_rep_type(type = "bootstrap", seed = 431L)`, the helper the
  other no-FPC blocks use. Measured: zero conditions of any class, mean
  difference 0, SE difference -6.66e-16.

No production code changed. `R/methods-conversion.R`, `plans/error-messages.md`
and `_snaps/conversion.md` are byte-identical to `0b40e45`; the snapshot file
still holds exactly eight snapshots. Only `tests/testthat/test-conversion.R`
moved — 20 lines added, 1 removed.

## Second BLOCK fix — 2026-09-08, commit `980e681`

The BLOCK was a contract miss on coverage: no committed block exercised
`as_svydesign()` on a design whose replicate weight column holds zeros. A
zeroed column is legal — "JK1" and "JKn" delete a whole PSU per replicate,
so a deleted row carries weight 0 there — and the route gives the columns no
special handling.

- Added block X-19, and its line in the section index comment. It builds a
  `"JK1"` design from `make_survey_data(n = 50, n_psu = 10, n_strata = 2,`
  `design = "replicate", type = "brr", seed = 432)` with the first of the
  five replicate columns set to 0, then asserts: the column is all zeros,
  `expect_no_warning(sv <- as_svydesign(d))`, the exported object is a
  `svyrep.design`, `sum(sv$repweights[, 1])` is 0, and parity against
  `get_means(d, y1, variance = "se")` — point estimate to 1e-10, standard
  error to 1e-8.
- `survey::svymean()` reports its own `simpleWarning` on the zeroed
  replicate: '1 replicates gave NA results and were discarded'. That is
  survey's variance code, not the conversion, so the block muffles it by
  class the way X-4 and X-17 do. surveycore discards the same replicate,
  which is why the two standard errors agree. Measured: mean difference 0,
  SE difference -3.16e-15.
- No production code changed, no snapshot added, and no fifth
  `test_invariants()` call. The four calls stand at lines 121, 754, 1157 and
  2150. X-18 stayed as written.

## Gates run

| Gate | Result |
|---|---|
| `air format --check R/methods-conversion.R tests/testthat/test-conversion.R` | exit 0 |
| `devtools::document()` | `NAMESPACE` and `man/` unchanged |
| `Rscript -e 'devtools::test()'` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11542` |
| `git status --porcelain` after the full run | 30 `_snaps/*.md` files rewritten by line endings only, all restored except `conversion.md` |
| `git diff --name-only origin/develop` | the four files above |

Baseline was `FAIL 0 | WARN 256 | SKIP 4 | PASS 11430`. Failures stayed 0,
the warning count did not move, and the run added 112 expectations.

Re-run after the BLOCK fix, commit `56cfc92`:

| Gate | Result |
|---|---|
| `air format --check tests/testthat/test-conversion.R` | exit 0 |
| `devtools::test(filter = "conversion")` | `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 562` |
| `Rscript -e 'devtools::test()'` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11532` |
| `git status --porcelain` after the full run | no `_snaps/*.md` file rewritten; only `test-conversion.R` modified |
| `git diff --name-only origin/develop` | the same four files |

The count fell from 11542 to 11532. The deleted `test_invariants()` call
carried 16 expectations and block X-18 adds 6. Failures stayed 0 and the
warning count held at 256.

Re-run after the second BLOCK fix, commit `980e681`:

| Gate | Result |
|---|---|
| `air format --check tests/testthat/test-conversion.R` | exit 0 |
| `devtools::test(filter = "conversion")` | `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 568` |
| `Rscript -e 'devtools::test()'` | `FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11538` |
| `git status --porcelain` after the full run | no `_snaps/*.md` file rewritten; only `test-conversion.R` modified |
| `git diff --name-only origin/develop` | the same four files |

Block X-19 adds 6 expectations, 11532 to 11538. Failures stayed 0, the
warning count held at 256, and `_snaps/conversion.md` still holds exactly
eight snapshots.

`run-gates.sh`, `R CMD check`, `pkgdown` and `covr` were not run, as
instructed.

## HOLDs

None.

## Notes for tester

- `survey::svrepdesign()` stores the shrinkage factor on the returned object
  as `sv$rho`, so X-8, X-9 and X-13 read the observable rather than
  recomputing the formula in the test.
- `survey` ignores `scale` for `"JK2"`, `"ACS"` and
  `"successive-difference"` and reports a bare `simpleWarning` saying so.
  X-17 muffles it by class, the way the existing X-4 block does. A JK2
  design therefore comes back from a round trip with scale 1, not the scale
  it went out with — X-17 asserts the type, the replicate count and the row
  count, not the scale.
- `make_survey_data(n_psu = 16, type = "brr")` gives 8 replicate columns,
  which is what X-10 needs to reproduce the spec's measured `-0.581`.
