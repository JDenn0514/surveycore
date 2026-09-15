# Implementation plan — domain-marker-logical

**Status**: DRAFT
**Date**: 2026-09-12
**Source**: GitHub issue #262
**Spec**: `spec.md` (three-PR map) — this plan splits it six ways.

---

## Why six PRs and not three

`test-spec.md` §Row count per PR records that the spec's three-PR shape breaks
the budget: spec PR 1 holds 24 rows and spec PR 3 holds 13, against a bound of
12. The spec's PR map is an input here, not a constraint.

The split keeps every dependency the spec states:

- The validator and the four existing block repairs stay in one PR (PR 1).
  Those blocks write a non-logical marker column and fail on the line that adds
  the validator.
- The validator's accept-path rows ship as PR 2, and the breadth of its reject
  path as PR 3. A later PR may add tests for behaviour an earlier PR shipped.
  Neither needs a behaviour change beyond what PR 1 merged.
- `.apply_domain()` (PR 4) lands after the validator, which guarantees the
  type it relies on.
- The printed-domain rows (PR 6, §4) land after PR 4. Corrected after the
  build: only row 4.2 depends on PR 4. The print method reads the marker
  column directly and never calls `.apply_domain()`, so rows 4.1, 4.3 and
  4.4 read the same on either side of PR 4. See `decisions.md` D26.

The plan reached six entries in two steps. It first split the spec's three into
five. The plan review then found PR 1 at nine acceptance criteria against a
bound of eight, and PR 1 split again — the accept-path rows became PR 2. See
`decisions.md` [[D20]].

---

## PR map

| PR | Branch | Rows | Row count | Criteria | Production change |
|---|---|---|---|---|---|
| 1 | `fix/domain-marker-validator` | §Existing blocks E.1–E.4, §1 1.1–1.4 | 8 | 8 | `survey_base` validator, error class, row 103, NEWS |
| 2 | `test/domain-marker-accept-path` | §2 2.1–2.3 and 2.9 | 4 | 5 | none |
| 3 | `test/domain-marker-type-breadth` | §1 1.5–1.11, §2 2.4–2.8 | 12 | 8 | none |
| 4 | `fix/apply-domain-na-mask` | §3 3.1–3.9 | 9 | 8 | `.apply_domain()` resolves `NA` to `FALSE` |
| 5 | `fix/restrict-to-domain-coercion` | §5 5.1–5.5 | 5 | 8 | `.restrict_to_domain()` coercion removed, design note rewritten |
| 6 | `test/domain-count-agreement` | §4 4.1–4.4, §6 6.1–6.4 | 8 | 8 | none |

Total: 46 rows. `test-spec.md` holds 46 rows. Every row is claimed once and no
row is claimed twice — see §Row ledger. Every entry sits inside both bounds:
12 rows and 8 criteria.

Dependency order: **1 → 2 → 3 → 4 → 5 → 6**. The six run strictly in sequence.
Five files appear in more than one entry, and each entry says so:
`tests/testthat/test-s7-classes.R` (PR 1, PR 2, PR 3),
`tests/testthat/helper-test-data.R` (PR 1, PR 4), `NEWS.md` (PR 1, PR 4),
`tests/testthat/test-conversion.R` (PR 1, PR 5),
`tests/testthat/test-analysis-helpers.R` (PR 4, PR 6).

### Why PR 2 runs before PR 3

Both are test-only, both write `tests/testthat/test-s7-classes.R`, and they run
in sequence, so the shared file is legal. PR 2 goes first for two reasons.

- It completes the validator's contract. PR 1 ships the reject path, PR 2 the
  accept path, and a reader of the first two PRs sees both halves before the
  breadth rows arrive.
- It leaves §2 in ascending order in the file. PR 2 writes 2.1, 2.2, 2.3 and
  2.9 as one group. PR 3 then places its §2 blocks — 2.4 to 2.8 — after 2.3
  and before 2.9, which reads 2.1 to 2.9 in order. The reverse order would ask
  PR 2 for two insertions into a group PR 3 had already written.

---

## Quality gate binding

`spec.md` §Quality gates holds thirteen gates. Each entry below carries only
the gates that bind it.

| Gate | Binds |
|---|---|
| 1 — `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returns nothing | PR 5 |
| 3 — the test-suite sweep writes a logical vector at every hit | PR 1 |
| 4 — `plans/error-messages.md` row 103 matches the `cli_abort()` call | PR 1 |
| 13 — the source sweep returns exactly three files | PR 4, PR 5 |
| 2, 5–12 | every PR |

Gate 1 binds PR 5 because `.restrict_to_domain()` holds the last such call
until then. Gate 13 binds PR 4 and PR 5, the two entries that change a file
naming the marker column; PR 6 re-runs it and records the output.

### How gates appear in the acceptance criteria

A gate that binds one PR gets its own criterion in that PR. The gates that bind
every PR are one gate run, and they get one criterion — the last one in each
entry, which lists them and states the result each must show. The plan review
asked for one observable per criterion; the routine gate run is one act with
one outcome, and splitting it eight ways would put every entry over the
criteria bound with no gain in what a reviewer can check.

`spec.md` §Quality gates binds gates 2 and 5 to 12 to every PR. Each entry's
folded line therefore lists gates 2 and 5 to 12 and the CRAN cookbook scan,
less any of them that carries its own criterion in that entry. One entry
differs: PR 1 gives gate 6 a line of its own, so its folded line reads 2, 5 and
7 to 12. The other five read 2 and 5 to 12.

A gate stays in the line when it is vacuous for that PR. Gate 5 asks that every
`cli::cli_abort()` added carries a `class` argument, and a test-only PR adds
none; the line says so. Gate 6 asks that `devtools::document()` runs clean, and
a PR that changes no roxygen moves nothing; the line says so. A vacuous gate is
still a bound gate, and an entry that drops it reads as an oversight.

Gate 2 and gate 5 sit in that last line in all six entries. The Pass 1 review
asked whether they could carry a criterion each. Only PR 2 has the room, and it
holds them folded like the other five, so the six entries read alike.

### What an acceptance criterion traces to

Four sources, all legitimate. Two plan reviews have now raised the fourth as
untraceable, so it is named here.

| Source | Example in this plan |
|---|---|
| A row in `test-spec.md` | PR 4 criterion 2, row 3.7. |
| A numbered gate in `spec.md` §Quality gates | PR 1 criterion 4, gate 3. |
| An item in `spec.md` §Scope §In | PR 1 criterion 6, the `NEWS.md` entry. |
| A constraint the plan or the test-spec places on the PR itself | The "no file under `R/` changes" criterion in PR 2, PR 3 and PR 6, which pins the test-only boundary this plan draws; and the `test_invariants()` count criterion, which pins `test-spec.md` §Invariants. |

---

## PR entries

### - [x] PR 1: `fix/domain-marker-validator` — the `survey_base` validator rejects a non-logical domain marker column, and the four existing blocks that write one are repaired

- **Budget** — 8 test-spec rows | 8 criteria
  - Rows: `test-spec.md` §1 rows 1.1–1.4, §Existing blocks that change rows
    E.1–E.4. Both figures sit inside their bounds — 8 against 12, and 8
    against 8.

- **Tasks**

  1. Add row 103 to the Error Case Table in `plans/error-messages.md`, after
     rows 101 and 102, with the class `surveycore_error_domain_not_logical`.
     The row lands before any code uses the class.
  2. Add the fixture helper `set_domain_marker(design, type, mask = NULL)` to
     `tests/testthat/helper-test-data.R`, beside `make_survey_data()` and
     `make_all_designs()`.
  3. Write failing tests for the reject path: rows 1.1–1.4 in
     `tests/testthat/test-s7-classes.R`, one block each, one per concrete
     class. Run them. All four fail — nothing aborts today.
  4. Implement the validator: add a `validator` argument to the `survey_base`
     class definition in `R/core-classes.R`. Check the column name first, the
     storage type second. Add the one sentence on the `data` property to the
     same file's roxygen block.
  5. Verify rows 1.1–1.4 pass. Add no check to any of the four subclass
     validators. If one body on `survey_base` does not deliver the abort on
     all four classes, raise a HOLD and stop — see `decisions.md` §Open.
  6. Run the full suite and record which blocks now fail. Repair E.1 and E.2
     in `tests/testthat/test-analysis-quantiles.R`: drop the `as.integer()`
     wrapper in each and keep every existing assertion. Add no new
     `test_invariants()` call to any file.
  7. Repair E.3 and E.4 in `tests/testthat/test-conversion.R`. E.3 now asserts
     the error class at the write; rename the block. E.4 keeps the loop and
     the five types — the logical iteration keeps both assertions, the four
     others assert the class at the write; rename the block and replace the
     comment above it.
  8. Run `devtools::document()`. Commit `man/survey_base.Rd` in the same
     commit as the roxygen change.
  9. Add one entry to `NEWS.md` under `## Breaking changes` in the
     development version, naming the error class and issue #262.
  10. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 1.1–1.4: four blocks in `tests/testthat/test-s7-classes.R` pass,
     each asserting
     `expect_error(class = "surveycore_error_domain_not_logical")` and writing
     no snapshot.
  2. Rows E.1–E.4: the four repaired blocks pass.
  3. The `test_invariants()` call count in
     `tests/testthat/test-s7-classes.R` is unchanged at six.
  4. Gate 3: `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" tests/testthat/` returns
     hits and every hit writes a logical vector. Read the block when the
     right-hand side is a variable.
  5. Gate 4: `plans/error-messages.md` holds row 103 with the class
     `surveycore_error_domain_not_logical`, and the row's message template
     matches the `cli::cli_abort()` call byte for byte.
  6. `NEWS.md` holds one entry under `## Breaking changes` in the development
     version that names `surveycore_error_domain_not_logical` and issue #262.
  7. Gate 6: `devtools::document()` runs clean, `NAMESPACE` is unchanged, and
     `man/survey_base.Rd` is committed with the roxygen change.
  8. Gates 2, 5, 7–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns hits and every hit
     writes a logical vector; every `cli::cli_abort()` added carries a `class`
     argument; `devtools::test()` reports no failure;
     `devtools::run_examples()` passes; `R CMD check --as-cran` reports 0
     errors, no new warning and no note beyond the two pre-approved ones;
     `pkgdown::build_site()` builds with no errored page;
     `covr::package_coverage()` measured with `NOT_CRAN=true` is at or above
     95%; `air format --check` passes on every file this PR touches.

- **Files touched**
  - `R/core-classes.R`
  - `man/survey_base.Rd` (regenerated)
  - `plans/error-messages.md`
  - `NEWS.md` (also PR 4 — the two PRs run in sequence)
  - `tests/testthat/helper-test-data.R` (also PR 4 — in sequence)
  - `tests/testthat/test-s7-classes.R` (also PR 2 and PR 3 — in sequence)
  - `tests/testthat/test-analysis-quantiles.R`
  - `tests/testthat/test-conversion.R` (also PR 5 — in sequence)

- **Pipeline tier**: recommended

#### Where PR 1's accept path is proved

Every §2 row ships later — 2.1 to 2.3 and 2.9 in PR 2, 2.4 to 2.8 in PR 3. PR 1
is therefore a PR that adds a reject-path check and claims no accept-path row.
That is not a gap: three of the writes in rows E.1, E.2 and E.4 are logical,
and each one must complete for its block to pass.

| Row | The logical write it makes | What fails if the validator over-rejects |
|---|---|---|
| E.1 | The `as.integer()` wrapper goes and the block writes the logical mask. | Its assertion — the domain estimate differs from the full-sample estimate — never runs. |
| E.2 | The wrapper goes and the block writes an all-`FALSE` logical mask. | Its two assertions — an `NA` estimate and `n = 0` — never run. |
| E.4 | The loop keeps five types, and the logical iteration writes a logical marker, converts, and asserts `sum(mask)` rows and a finite probability per retained row. | That iteration aborts at the write. |

Read against `test-spec.md` §Existing blocks that change, which states all
three writes and the assertions that follow them. A validator that rejected a
logical column would fail all three blocks, so gate 7 catches it inside PR 1.

What PR 1 does **not** prove is the accept path beyond a Taylor design and a
logical column with no `NA`. Two later PRs carry the rest.

- PR 2 proves the `NA`-bearing column and the attribute-carrying column:
  rows 2.2 (one `NA`), 2.3 (every element `NA`) and 2.9 (the `haven_labelled`
  class). All three are Taylor designs, as is row 2.1.
- PR 3 proves the class breadth: rows 2.4 (replicate, every element `NA`) and
  2.8 (two-phase, one `NA`).

---

### - [x] PR 2: `test/domain-marker-accept-path` — a legal logical marker column passes the validator

The validator ships in PR 1, which proves its reject path. This PR proves its
accept path: a logical column with no `NA`, with one `NA`, with every element
`NA`, and one that arrives carrying the `haven_labelled` class. No production
file changes.

- **Budget** — 4 test-spec rows | 5 criteria
  - Rows: `test-spec.md` §2 rows 2.1–2.3 and 2.9. Both figures sit inside
    their bounds — 4 against 12, and 5 against 8.

- **Tasks**

  1. Write the accept-path blocks for rows 2.1–2.3 in
     `tests/testthat/test-s7-classes.R`, one block each, below the reject
     blocks PR 1 added. Each writes through `set_domain_marker()` and asserts
     that no condition of class `surveycore_error_domain_not_logical` is
     raised — not the absence of every condition.
  2. Run them. All three pass. An accept row passes with or without the
     validator; what it pins is that the check does not over-reject, and rows
     1.1–1.4 in PR 1 already prove the check fires.
  3. Write row 2.9's block in the same file, after 2.3. Call
     `skip_if_not_installed("haven")` on its first line. Build the column in
     the block — a logical mask carrying the `haven_labelled` class and its
     labels attribute — and hand it to `set_domain_marker()` as `mask` with
     `type` `"logical"`. Add no type and no argument to the helper.
  4. Verify row 2.9: the write raises no
     `surveycore_error_domain_not_logical`, and the column read back out of
     the design is logical and carries no class attribute.
  5. Add no new `test_invariants()` call to the file. It already calls the
     helper for the Taylor constructor.
  6. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 2.1–2.3 and 2.9: four accept-path blocks in
     `tests/testthat/test-s7-classes.R` pass, and no write in them raises
     `surveycore_error_domain_not_logical`.
  2. Row 2.9: the marker column read back out of the design is a plain logical
     vector and carries no `haven_labelled` class.
  3. No file under `R/` changes: `git diff --stat` against the base branch
     lists no path under `R/` or `man/`, and `NAMESPACE` is unchanged.
  4. The `test_invariants()` call count in
     `tests/testthat/test-s7-classes.R` is unchanged at six.
  5. Gates 2, 5–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns the same hits as
     before this PR and every hit writes a logical vector; every
     `cli::cli_abort()` added carries a `class` argument, and this PR adds
     none; `devtools::document()` runs clean and leaves `NAMESPACE` unchanged;
     `devtools::test()` reports no failure; `devtools::run_examples()` passes;
     `R CMD check --as-cran` reports 0 errors, no new warning and no note
     beyond the two pre-approved ones; `pkgdown::build_site()` builds with no
     errored page; `covr::package_coverage()` measured with `NOT_CRAN=true` is
     at or above 95%; `air format --check` passes on every file this PR
     touches.

- **Files touched**
  - `tests/testthat/test-s7-classes.R` (also PR 1 and PR 3 — the three PRs
    run in sequence)

- **Pipeline tier**: recommended

---

### - [x] PR 3: `test/domain-marker-type-breadth` — the validator's remaining reject and accept rows

The validator ships in PR 1 and its accept path in PR 2. This PR adds the rest
of the test surface: the four further wrong types, the two constructor routes,
the rollback row, and the accept rows on the remaining classes and shapes. No
production file changes.

- **Budget** — 12 test-spec rows | 8 criteria
  - Rows: `test-spec.md` §1 rows 1.5–1.11, §2 rows 2.4–2.8. Both figures sit
    at their bounds — 12 against 12, and 8 against 8.

- **Tasks**

  1. Write the type-breadth blocks in `tests/testthat/test-s7-classes.R`: rows
     1.5 (double), 1.6 (character), 1.7 (factor) and 1.8 (list), each on a
     Taylor design, each through `set_domain_marker()`.
  2. Verify each new block is not vacuous: comment out the type check in
     `R/core-classes.R` locally, run the four blocks, confirm all four fail,
     restore the file. Do not commit that edit.
  3. Write the constructor rows 1.9 and 1.10: a data frame that already
     carries an integer marker column, passed to the Taylor constructor and to
     the non-probability constructor. Run them; both pass.
  4. Write row 1.11: after a failed assignment, read the design's data back
     and assert it holds no marker column.
  5. Write the accept rows 2.4 (replicate, all `NA`), 2.5 (logical carrying a
     `label` attribute, attribute survives the write) and 2.8 (two-phase, one
     `NA`, the design's own subset column untouched). Place every §2 block
     this PR adds after row 2.3's block and before row 2.9's, both of which
     PR 2 wrote. The file then reads 2.1 to 2.9 in order.
  6. Write the zero-row pair 2.6 and 2.7, building the zero-row frame inline
     in the block. Assert on the named class only.
  7. Re-run step 2's vacuity check over rows 2.7, 1.9 and 1.10 as well, then
     restore the file.
  8. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 1.5–1.10 and 2.7: seven blocks in
     `tests/testthat/test-s7-classes.R` pass, each asserting
     `expect_error(class = "surveycore_error_domain_not_logical")` and writing
     no snapshot. `tests/testthat/_snaps/` gains no entry for that class.
  2. Rows 2.4 and 2.6: two accept-path blocks pass, and neither write raises
     `surveycore_error_domain_not_logical`.
  3. Row 1.11: the design's data holds no marker column after the failed
     write.
  4. Row 2.5: the `label` attribute survives the write.
  5. Row 2.8: the two-phase design's own subset column is unchanged.
  6. No file under `R/` changes: `git diff --stat` against the base branch
     lists no path under `R/` or `man/`, and `NAMESPACE` is unchanged.
  7. The `test_invariants()` call count in
     `tests/testthat/test-s7-classes.R` is unchanged at six.
  8. Gates 2, 5–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns the same hits as
     before this PR and every hit writes a logical vector; every
     `cli::cli_abort()` added carries a `class` argument, and this PR adds
     none; `devtools::document()` runs clean and leaves `NAMESPACE` unchanged;
     `devtools::test()` reports no failure; `devtools::run_examples()` passes;
     `R CMD check --as-cran` reports 0 errors, no new warning and no note
     beyond the two pre-approved ones; `pkgdown::build_site()` builds with no
     errored page; `covr::package_coverage()` measured with `NOT_CRAN=true` is
     at or above 95%; `air format --check` passes on every file this PR
     touches.

- **Files touched**
  - `tests/testthat/test-s7-classes.R` (also PR 1 and PR 2 — the three PRs
    run in sequence)

- **Pipeline tier**: recommended

---

### - [x] PR 4: `fix/apply-domain-na-mask` — `.apply_domain()` resolves an `NA` marker to `FALSE`

- **Budget** — 9 test-spec rows | 8 criteria
  - Rows: `test-spec.md` §3 rows 3.1–3.9. Both figures sit inside their
    bounds — 9 against 12, and 8 against 8.

- **Tasks**

  1. Add the fixture helper `make_domain_pair(class = "taylor", seed = 42)` to
     `tests/testthat/helper-test-data.R`. It returns `a`, `b` and `mask`. It
     accepts `"taylor"`, `"replicate"`, `"twophase"` and `"nonprob"`, because
     PR 5 and PR 6 read it and do not change it. Build the `"twophase"`
     variant so at least one in-domain row sits outside phase 2 — PR 6 row 4.4
     proves nothing otherwise.
  2. Write the failing invariance blocks 3.1–3.6 in
     `tests/testthat/test-analysis-helpers.R`, one block per function, each
     comparing column by column with `expect_identical()`. Run them. They fail
     — the `NA` design and the `FALSE` design disagree today.
  3. Write the failing block for row 3.7: grouped `get_means()` on design A
     returns only real levels of `group`. Run it; it fails with a phantom
     group row.
  4. Write the block for row 3.8: an all-`NA` marker column, ungrouped
     `get_means()`, against the all-`FALSE` result.
  5. Write the block for row 3.9 in the same file. Build a zero-row design
     inline, carrying a `logical(0)` marker column, and call `.apply_domain()`
     on it. Assert the return value is `logical(0)` — a logical vector of
     length zero. Run it. It passes on the current tree; it is a contract row,
     not a failing-first row.
  6. Implement the change in `R/analysis-helpers.R`: `.apply_domain()`
     resolves `NA` to `FALSE` and adds no coercion. The column-absent branch
     does not change.
  7. Update the `@return` text of `.apply_domain()` to the post-change
     contract.
  8. Verify rows 3.1–3.9 pass. Add no new `test_invariants()` call.
  9. Add one entry to `NEWS.md` under `## Bug fixes` in the development
     version, naming issue #262.
  10. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 3.1–3.6: six blocks in `tests/testthat/test-analysis-helpers.R`
     pass, one per function, each comparing column by column with
     `expect_identical()` and never comparing two result objects whole.
  2. Row 3.7: the grouped `get_means()` result on design A carries no group
     value that is not a real level of `group`.
  3. Row 3.8: the all-`NA` result is identical to the all-`FALSE` result.
  4. Row 3.9: `.apply_domain()` on a zero-row design returns `logical(0)`.
  5. `make_domain_pair()` builds all four classes, and its `"twophase"`
     fixture places at least one `TRUE` marker row outside phase 2.
  6. Gate 13: `grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R`
     returns exactly three files — `R/analysis-helpers.R`,
     `R/analysis-t-test.R` and `R/glm-anova.R`.
  7. `NEWS.md` holds one entry under `## Bug fixes` in the development version
     naming issue #262.
  8. Gates 2, 5–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns hits and every hit
     writes a logical vector; every `cli::cli_abort()` added carries a `class`
     argument; `devtools::document()` runs clean and leaves `NAMESPACE`
     unchanged; `devtools::test()` reports no failure;
     `devtools::run_examples()` passes; `R CMD check --as-cran` reports 0
     errors, no new warning and no note beyond the two pre-approved ones;
     `pkgdown::build_site()` builds with no errored page;
     `covr::package_coverage()` measured with `NOT_CRAN=true` is at or above
     95%; `air format --check` passes on every file this PR touches.

- **Files touched**
  - `R/analysis-helpers.R`
  - `tests/testthat/helper-test-data.R` (also PR 1 — the two PRs run in
    sequence)
  - `tests/testthat/test-analysis-helpers.R` (also PR 6 — in sequence)
  - `NEWS.md` (also PR 1 — in sequence)

- **Pipeline tier**: recommended

---

### - [x] PR 5: `fix/restrict-to-domain-coercion` — `.restrict_to_domain()` drops the coercion and keeps the `NA` guard

- **Budget** — 5 test-spec rows | 8 criteria
  - Rows: `test-spec.md` §5 rows 5.1–5.5. Both figures sit inside their
    bounds — 5 against 12, and 8 against 8.

- **Tasks**

  1. Write the conversion blocks 5.1–5.5 in `tests/testthat/test-conversion.R`,
     one block per row, each calling `skip_if_not_installed("survey")` inside
     the block. Rows 5.2–5.4 take their `NA` design from `make_domain_pair()`,
     one class per row, and use `sum(mask)` as the expected count.
  2. Run them against the current tree. All five pass — these are regression
     rows for behaviour that already holds.
  3. Remove the `as.logical()` coercion in `.restrict_to_domain()` in
     `R/methods-conversion.R`. Keep `r & !is.na(r)`.
  4. Rewrite the design note above the helper. It records two facts: the class
     validator guarantees the type at the write, and `!is.na(r)` still reads
     an `NA` marker as outside the domain.
  5. Verify rows 5.1–5.5 still pass. Add no new `test_invariants()` call.
  6. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 5.1, 5.2 and 5.4: three blocks in
     `tests/testthat/test-conversion.R` pass, and each converted object holds
     only the rows whose marker reads `TRUE` — for 5.2 and 5.4 that is
     `sum(mask)` rows, with the `NA` row absent.
  2. Row 5.3: the two-phase conversion keeps every row, and the count of
     finite probabilities equals `sum(mask)`.
  3. Row 5.5: a design with no marker column converts with every row kept and
     no condition raised.
  4. Each of the five blocks calls `skip_if_not_installed("survey")` inside
     the block.
  5. Gate 1: `grep -rn "as.logical(.*SURVEYCORE_DOMAIN_COL" R/` returns
     nothing.
  6. Gate 13: `grep -rln "SURVEYCORE_DOMAIN_COL" R/analysis-*.R R/glm*.R`
     returns exactly three files — `R/analysis-helpers.R`,
     `R/analysis-t-test.R` and `R/glm-anova.R`.
  7. The old design note is gone: a grep for the phrase "no validator checks
     its type" over `R/` returns nothing.
  8. Gates 2, 5–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns hits and every hit
     writes a logical vector; every `cli::cli_abort()` added carries a `class`
     argument; `devtools::document()` runs clean and leaves `NAMESPACE`
     unchanged; `devtools::test()` reports no failure;
     `devtools::run_examples()` passes; `R CMD check --as-cran` reports 0
     errors, no new warning and no note beyond the two pre-approved ones;
     `pkgdown::build_site()` builds with no errored page;
     `covr::package_coverage()` measured with `NOT_CRAN=true` is at or above
     95%; `air format --check` passes on every file this PR touches.

- **Files touched**
  - `R/methods-conversion.R`
  - `tests/testthat/test-conversion.R` (also PR 1 — the two PRs run in
    sequence)

- **Pipeline tier**: recommended

---

### - [x] PR 6: `test/domain-count-agreement` — the printed domain count agrees with the analysis count, and a design with no marker column is unchanged

The count these rows assert on moves in PR 4, so this PR runs after it. No
production file changes.

- **Budget** — 8 test-spec rows | 8 criteria
  - Rows: `test-spec.md` §4 rows 4.1–4.4, §6 rows 6.1–6.4. Both figures sit
    inside their bounds — 8 against 12, and 8 against 8.

- **Tasks**

  1. Write rows 4.1–4.3 in `tests/testthat/test-methods-print.R`, taking the
     fixture from `make_domain_pair()`. Capture the printed output and assert
     on the numbers in the `Domain: n of N` line, not on a snapshot of the
     whole print method.
  2. Write row 4.2 as its own block: the `n` from the printed line equals the
     `n` column of an ungrouped `get_means()` on `y1` for the same design,
     compared with `expect_identical()`.
  3. Write row 4.4: the two-phase design A from `make_domain_pair("twophase")`,
     printed. The line counts phase-2 rows only, and design B gives the
     identical line. Confirm the fixture places at least one in-domain row
     outside phase 2 before you trust the row; if it does not, raise the
     finding rather than editing the helper.
  4. Run rows 4.1–4.4. They pass on this tree and would have failed before
     PR 4.
  5. Write rows 6.1–6.4 in `tests/testthat/test-analysis-helpers.R`: a Taylor
     design straight from the constructor, ungrouped and grouped
     `get_means()`, printed, and an assignment of a data frame with no marker
     column.
  6. Run rows 6.1–6.4; all pass. Add no new `test_invariants()` call to either
     file.
  7. Run the gates listed under Acceptance criteria.

- **Acceptance criteria**

  1. Rows 4.1 and 4.3: two blocks in `tests/testthat/test-methods-print.R`
     pass; the printed line for design A reads `Domain: n of N` with `n` the
     count of `TRUE` elements and `N` the row count, and design B gives the
     identical line. Neither block writes a snapshot of the print method, and
     `tests/testthat/_snaps/methods-print.md` gains no entry.
  2. Row 4.2: the `n` in the printed domain line and the `n` column of the
     ungrouped `get_means()` result are identical under `expect_identical()`.
  3. Row 4.4: the two-phase printed line reports the count of `TRUE` marker
     elements among phase-2 rows and the phase-2 row count, and the line from
     design B is identical.
  4. Rows 6.1 and 6.2: two blocks in
     `tests/testthat/test-analysis-helpers.R` pass; the ungrouped
     `get_means()` result holds every row of the design, and the grouped one
     holds one row per level of `group`.
  5. Row 6.3: the printed output of a design with no marker column holds no
     `Domain:` line.
  6. Row 6.4: assigning a data frame with no marker column to the design's
     data raises no condition.
  7. No file under `R/` or `man/` changes, `NAMESPACE` is unchanged, and
     `tests/testthat/helper-test-data.R` is unchanged — `make_domain_pair()`
     is read, not edited.
  8. Gates 2, 5–12 and the CRAN cookbook scan: the gate run is clean.
     `grep -rn "SURVEYCORE_DOMAIN_COL\]\] <-" R/` returns the same hits as
     before this PR and every hit writes a logical vector; every
     `cli::cli_abort()` added carries a `class` argument, and this PR adds
     none; `devtools::document()` runs clean and leaves `NAMESPACE` unchanged;
     `devtools::test()` reports no failure; `devtools::run_examples()` passes;
     `R CMD check --as-cran` reports 0 errors, no new warning and no note
     beyond the two pre-approved ones; `pkgdown::build_site()` builds with no
     errored page; `covr::package_coverage()` measured with `NOT_CRAN=true` is
     at or above 95%; `air format --check` passes on every file this PR
     touches. Gate 13 runs once more and returns the output PR 5 recorded;
     neither it nor gate 2 can move, because this PR edits no file under `R/`.

- **Pipeline tier**: recommended

- **Files touched**
  - `tests/testthat/test-methods-print.R`
  - `tests/testthat/test-analysis-helpers.R` (also PR 4 — the two PRs run in
    sequence)

---

## Row ledger

Every row in `test-spec.md`, with the one PR that claims it.

| Section | Rows | PR |
|---|---|---|
| §1 | 1.1, 1.2, 1.3, 1.4 | 1 |
| §1 | 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11 | 3 |
| §2 | 2.1, 2.2, 2.3, 2.9 | 2 |
| §2 | 2.4, 2.5, 2.6, 2.7, 2.8 | 3 |
| §3 | 3.1–3.9 | 4 |
| §4 | 4.1–4.4 | 6 |
| §5 | 5.1–5.5 | 5 |
| §6 | 6.1–6.4 | 6 |
| §Existing blocks | E.1, E.2, E.3, E.4 | 1 |

Counts: PR 1 = 8, PR 2 = 4, PR 3 = 12, PR 4 = 9, PR 5 = 5, PR 6 = 8. Sum = 46,
which equals the test-spec total. No row is unclaimed and no row is claimed
twice.

### Where the §1 and §2 cut falls

Three PRs share the validator's test surface, and the cut runs by the act each
row performs, not by section.

| PR | Rows | The act |
|---|---|---|
| 1 | §1 1.1–1.4, §Existing blocks E.1–E.4 | The abort fires on all four concrete classes from one body, and the four blocks that wrote a wrong type are repaired. These eight cannot leave PR 1: the four repaired blocks fail on the line that adds the validator. |
| 2 | §2 2.1–2.3, 2.9 | A legal logical column passes — with no `NA`, with one `NA`, with every element `NA`, and carrying the `haven_labelled` class. |
| 3 | §1 1.5–1.11, §2 2.4–2.8 | Breadth. Four further wrong types, the two constructor routes, the rollback row, and the accept rows on the remaining classes and shapes. |

PR 1 and PR 2 together prove the contract the spec states. A reader of the
first two sees the check fire and sees it stay quiet, without reading PR 3.
PR 1 alone still cannot pass with a validator that rejects a logical column —
see §Where PR 1's accept path is proved.

§2 is the one section two boundaries cut: PR 2 takes 2.1 to 2.3 and 2.9, and
PR 3 takes 2.4 to 2.8. Row 2.9 is the `haven_labelled` accept row, added in the
plan review. It goes with PR 2 because it is an accept-path row, and PR 3 sits
at the 12-row bound without it.

---

## Fixture ownership

| Helper | Added by | Read by |
|---|---|---|
| `set_domain_marker()` | PR 1 | PR 1, PR 2, PR 3 |
| `make_domain_pair()` | PR 4 | PR 4, PR 5, PR 6 |

PR 1 builds `set_domain_marker()` with all six types at once, because PR 2 and
PR 3 read it and may not change it. Row 2.9 in PR 2 needs no seventh type: it
builds its column in the block and hands it over as `mask`.

PR 4 builds `make_domain_pair()` for all four classes at once, because PR 5
and PR 6 read it and may not change it.

---

## HOLD carried from `decisions.md`

`decisions.md` §Open records one assumption the source does not settle:
`survey_base` carries no validator today, so nothing in this package yet
proves S7 runs a parent validator for a subclass. PR 1 task 5 carries the
instruction: if one body on `survey_base` does not deliver the abort on all
four concrete classes, raise a HOLD and stop. Do not copy the check into the
four subclass validators.

No new HOLD is raised by this plan.
