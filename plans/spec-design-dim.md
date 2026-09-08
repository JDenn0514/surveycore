# Spec — design-dim (issue #203)

**Status**: DRAFT
**Target version**: 1.1.0.9000
**PR range**: PR 1 (single PR)
**Date**: 2026-09-04

## Document purpose

This document is the source of truth for the behaviour of `dim()` on
surveycore objects. It settles what `dim()` returns for each class, which
base-R size functions change as a consequence, and what error a
`survey_collection` raises. Every behavioural claim below is a recorded
value from `measurements.md` in this directory, which holds 264 measured
probe rows across four passes. Where a claim cites a pass, that pass is the
evidence.

Decisions D1 to D5 in `decisions.md` are settled. This spec implements them
and does not re-open them.

---

## Scope

### In

| Item | Detail |
|---|---|
| `dim()` on `survey_base` | Returns `dim()` of the stored data frame. Registered on `survey_base`, so all four design classes inherit it. |
| `dim()` on `survey_collection` | Raises `surveycore_error_collection_no_dim`. |
| New error class row | One table row in `plans/error-messages.md` for `surveycore_error_collection_no_dim`. |
| Test rows | New blocks in the compatibility test file. |

### Out

| Item | Reason |
|---|---|
| `length()` on any class | D4. Settled out of scope. `length()` on a design returns `1`, and `length()` on a collection returns the member count. Neither changes. |
| `NEWS.md` | D5. Three worktrees run in parallel and all three would add a bullet at the same insertion point. The NEWS entries for all three fixes land in one direct commit to `develop` after the PRs merge. Do not edit `NEWS.md` in this PR. |
| `dimnames()`, `rownames()`, `colnames()` methods | Not added. See §Derived behaviour for what happens to them anyway. |
| `[`, `[[`, `as.matrix()`, `as.data.frame()`, `head()`, `tail()` on a design | Unchanged. Every one of these fails before `dim()` matters, before and after alike (`measurements.md` §Pass 1). |
| `[[` on a collection | Unchanged. It already returns the member. No `[[<-` method exists or is added; the reason is recorded beside the existing collection methods. |

### Class and design support matrix

Five classes, two behaviours.

| Class | Parent | `dim()` behaviour |
|---|---|---|
| `survey_taylor` | `survey_base` | Delegates: `dim()` of the stored data frame |
| `survey_replicate` | `survey_base` | Delegates |
| `survey_twophase` | `survey_base` | Delegates |
| `survey_nonprob` | `survey_base` | Delegates |
| `survey_collection` | **none** | Raises `surveycore_error_collection_no_dim` |

**Read this next sentence twice.** `survey_collection` is not a child of
`survey_base`. Its class definition in `R/core-classes.R:949` declares no
`parent`, and it holds a `@surveys` list rather than a `@data` frame. The two
methods in this spec are therefore independent: neither inherits the other's
behaviour, and a method registered on `survey_base` cannot reach a
collection. `measurements.md` §Pass 3 measured exactly that — with only the
`survey_base` method present, `dim()` on a collection stayed `NULL` on all
nine probes. This is the single most misreadable fact in the change.

**"Delegates" does not mean the four classes report the same column count.**
`measurements.md` §Pass 1 built all four classes from comparable input data
and read four different column counts: 8 for taylor, 13 for replicate, 11 for
twophase, 9 for nonprob. The count is the width of the stored frame, so it
includes the weight column, the cluster and stratum id columns, `fpc`, the
domain flag when present, and every replicate-weight column. It is not a
count of analysis variables, and `ncol()` is therefore not comparable across
design classes. Generic code that computes `ncol(d) - k` to count analysis
variables gets a class-dependent answer.

---

## Architecture

### Files touched

Exactly three files. Nothing else.

| File | Change |
|---|---|
| `R/methods-compat.R` | Add two `S7::method()` registrations after the existing `names()` method at line 23. |
| `tests/testthat/test-methods-compat.R` | Add test blocks. |
| `plans/error-messages.md` | Add one table row (see §Error table). |

No other file is in the write surface. Not `NAMESPACE`, not `man/`, not
`NEWS.md`, not `_pkgdown.yml`, not `DESCRIPTION`, not `R/methods-print.R`,
not `R/core-classes.R`, not `R/zzz.R`.

### Three constraints on the edit

1. **`R/methods-compat.R` carries plain `#` comments, not roxygen.** Document
   the new methods with `#` comments in the style of the neighbouring
   `names()` block. Do not add `#'`, do not add `@export`, and do not expect
   `devtools::document()` to produce a diff. `dim` is a base generic and
   `R/zzz.R` calls `S7::methods_register()` in `.onLoad()`, so the new
   methods need no `NAMESPACE` entry and no `zzz.R` edit. A `document()` run
   that changes `NAMESPACE` or `man/` means something went wrong.
2. **The repository stores R sources with CRLF line endings.** Preserve them.
   Do not let an editor normalise `R/methods-compat.R` to LF; a whole-file
   line-ending diff hides the three-line change and is not reviewable.
3. **Register both methods in the same file, next to each other.** The
   `survey_collection` method exists only because the `survey_base` method
   does not reach that class. Splitting them across files loses that link.

### Functions added

Two S7 method registrations. No new function is exported, and no existing
function signature changes.

```r
S7::method(dim, survey_base) <- function(x) dim(x@data)

S7::method(dim, survey_collection) <- function(x) {
  # raises surveycore_error_collection_no_dim
}
```

### Class changes

None. No property is added, removed, or renamed on any class.

---

## Function contracts

### `dim()` on a `survey_base` design

- **Signature**: `dim(x)` — `x` is the object, per the base generic. No other
  argument exists and none is added.
- **Arguments**: `x` — an object of class `survey_taylor`,
  `survey_replicate`, `survey_twophase`, or `survey_nonprob`. There is no
  `NULL` case: the generic dispatches on the class of `x`.
- **Returns**: an integer vector of length 2 — the row count and the column
  count of the stored data frame, in that order. Identical in value and type
  to calling `dim()` on the object returned by `survey_data()`.
- **Errors**: none. This method raises no condition.
- **Warnings**: none. This method emits no condition.
- **Edge cases**:

| Case | Behaviour |
|---|---|
| A design with a single stored row | Returns `c(1L, ncol)`. Nothing special-cases row counts. This is a measured value, not a corollary: `measurements.md` §Pass 5A recorded `dim()` reading `c(1L, 7L)` and `nrow()` reading `1L` on a one-row design. |
| How a one-row design is reached | Not by construction. The three raw-frame constructors reject a one-row frame with `surveycore_error_single_row` (`R/core-validators.R:101`), and the constructor floor is two rows, which builds and reads `c(2L, 7L)`. Assignment to the `@data` property does reach one row: the S7 property assignment accepts it, because no validator in `R/core-classes.R` checks the row count (`measurements.md` §Pass 5A). |
| A design whose stored frame gained a domain-membership column | Returns the widened column count. The method reports the stored frame as it is, with no column filtering. |
| A design after column selection dropped columns | Returns the reduced column count. |
| A design after column selection **hid** a design column rather than dropping it | Returns the full stored column count, which is larger than the number of columns `print()` shows. `.data_for_print()` (`R/methods-print.R:23-31`) shows only `@variables$visible_vars` when that key is set, and the ecosystem's `select()` sets it to keep a design variable that variance estimation needs but the user did not select. `@data` keeps every column. `measurements.md` §Pass 5B set the key to two columns and read `ncol()` at `7L` against 2 printed columns. **This is correct.** The method reports the frame, and the frame is what variance estimation reads; a count that followed the print filter would under-report the data the design actually holds. `print()` already tells the user, in the same output: `Design variables preserved but hidden: ...` (`R/methods-print.R:43`). Leave that file alone: its line 26 carries a `# nocov` marker reading "only set by surveytidy", and revisiting that marker is not part of this change. |
| A design after a column-adding operation | Returns the widened column count. Column addition reaches a design through the ecosystem's `mutate()` verb, which `measurements.md` §Pass 2 measured as returning a live design. `update_design()` cannot add a data column — its formals are `x`, `ids`, `weights`, `strata`, `fpc`, `repweights` and `validate`, it re-specifies design variables only, and a data-column argument raises `unused argument` (`measurements.md` §Pass 5C). |
| A design after a row-dropping operation | Returns the reduced row count. This is the reported use case from issue #203: two calls, before and after, print two different counts. |
| An all-`NA` column in the stored frame | No effect. `dim()` counts rows and columns; it does not inspect values. |
| Zero-weight rows | No effect, same reason. |
| A design built with no strata, no ids, and no `fpc` | No effect. The method reads the frame, not the design variables. |

- **What it does not do**: it does not add a `dim` attribute to the object, it
  does not touch `dimnames()`, and it does not make the object array-like.
  See §Derived behaviour.

### `dim()` on a `survey_collection`

- **Signature**: `dim(x)` — `x` is the object, per the base generic.
- **Arguments**: `x` — an object of class `survey_collection`.
- **Returns**: nothing. The method always raises.
- **Errors**: one — `surveycore_error_collection_no_dim`. It fires on every
  call, for every collection, with no condition to test first.
- **Warnings**: none.
- **Edge cases**:

| Case | Behaviour |
|---|---|
| A collection with one member | Raises. The message pluralizes to the singular form: it reads `1 survey`, not `1 surveys`. |
| A collection with many members | Raises. The message reads the plural form. |
| A grouped collection | Raises. `@groups` does not enter the message. |
| Members that all hold the same row and column counts | Still raises. The method does not inspect member shapes, so a collection whose members happen to agree gets the same error as one whose members disagree. This keeps the contract one sentence long and keeps the answer stable when a member is later replaced. |

- **Why an error here and not delegation** (D3): a collection holds several
  surveys, each with its own row count and column count, so there is no
  single pair to return. `length()` and `names()` already answer the two
  container-shaped questions — the member count and the member names — and
  they keep answering them. `measurements.md` §Pass 4 measured both at their
  clean-tree values under the patched tree.

---

## Behaviour rules

### Derived behaviour — the five functions, not three

`nrow()` and `ncol()` are **not** generic. Base R defines them as `dim(x)[1L]`
and `dim(x)[2L]`. `NROW()` and `NCOL()` read `dim()` too, and fall back to
`length(x)` only when `dim(x)` is `NULL`. So one `dim()` method fixes five
functions, and the two methods in this spec are the only lever available.

Issue #203 lists three broken functions. There are five.
`measurements.md` §Pass 1 recorded the before values on all four design
classes:

| Function | Before, a design | After, a design | Before, a collection | After, a collection |
|---|---|---|---|---|
| `dim()` | `NULL` | `c(rows, cols)` | `NULL` | typed error |
| `nrow()` | `NULL` | row count | `NULL` | typed error |
| `ncol()` | `NULL` | column count | `NULL` | typed error |
| `NROW()` | `1L` | row count | `2L` (member count) | typed error |
| `NCOL()` | `1L` | column count | `1L` | typed error |

`NROW()` and `NCOL()` are the part the issue misses, and they were the worse
failure of the two. They returned `1L`, not `NULL` — a plausible wrong number
in place of a visible `NULL`. Both now report the row count and the column
count.

The `NROW()` and `NCOL()` columns for a collection are the one measured cost
of this change. On the clean tree `NROW(collection)` returned the member
count, which is a defensible answer for a container; it now raises. Across
all 264 probe rows this is the only call that moves from a reasonable value
to an error (`measurements.md` §Pass 4). D3 accepted that cost with the
reasoning recorded there. Nothing in `R/`, `tests/`, `vignettes/` or `man/`
calls `NROW()` or `NCOL()` on a collection.

### What the two numbers count

The row count is the unweighted sample row count of the stored frame. It is
not a population estimate, and no weight enters it.

The column count is the width of the stored frame. It includes the weight
column, the cluster and stratum id columns, `fpc`, the domain flag when
present, and every replicate-weight column. It is not a count of analysis
variables, and it is not comparable across design classes:
`measurements.md` §Pass 1 read 8, 13, 11 and 9 columns for taylor,
replicate, twophase and nonprob on comparable input data. A replicate design
carries one column per replicate weight and a two-phase design carries the
phase-2 subset column, so the same analysis variables give a different total.

### Domain estimation semantics — `dim()` reports the STORED row count

`dim(design)` reports the number of rows the design stores. It does not
report the number of rows in the active domain.

The two differ after a domain filter. Per `CLAUDE.md` §Key Implementation
Rules, a filter on a design keeps every row and marks domain membership; only
a physical subset removes rows. `measurements.md` §Pass 2 measured a 60-row
design through a filter that selects a strict subset, and the stored row
count read 60 of 60 in both runs.

**This is correct behaviour, not a defect.** A method that delegates to the
stored frame can honestly report only what the frame holds, and the stored
count is the count the reported use case needs — the operation in issue #203
physically drops rows, so the before and after counts differ exactly as the
example claimed. Record it in the method's comment block so no later reader
files it as a bug. A user who wants the in-domain count asks the analysis
functions, which carry it in their own output.

**A filtered design already reports both numbers, user-facing.**
`.print_domain_info()` (`R/methods-print.R:170-183`) is called from all four
design print methods (`:228`, `:378`, `:497`, `:634`) and prints
`Domain: {n_domain} of {n_total} row{?s}` whenever the domain column is
present — `Phase 2 rows` in the two-phase variant at `:179`, the same two
numbers. Those are exactly the two numbers the
stored-versus-domain confusion runs together, and a user who prints a
filtered design sees both. The same stored count was also reachable before
this change: issue #203's own example calls the row count on the stored
frame through the exported accessor. This change adds a second route to a
number that already existed; it does not create a new number.

**Two follow-ups, neither in this write surface.**

1. The deferred `NEWS.md` entry (D5) must state the stored-count semantics,
   not only that the size functions now work.
2. A user-facing documentation home for the stored-count rule is a separate
   issue. The most plausible home is the `@details` of the stored-frame
   accessor, since that is where the stored frame is already documented.
   Writing it means editing roxygen and regenerating `man/`, which
   contradicts this spec's own constraint that `devtools::document()`
   produces no diff. Do not do it in this PR.

### What does not change, and why

`measurements.md` §Pass 1 and §Pass 2 recorded 44 unchanged probes per design
class and 31 unchanged probes through the ecosystem. The mechanism is
measurable rather than lucky: `is.matrix()` and `is.array()` are internal and
read the object's real `dim` **attribute**, which an S7 object does not have,
while `nrow()` and `ncol()` call the `dim()` **generic**, which the new
method serves. The size functions get their answer; the gate that hands an
object to array code never opens.

| Behaviour | State after this change |
|---|---|
| `is.matrix()`, `is.array()`, `is.data.frame()`, `is.list()`, `is.vector()` on a design | All `FALSE`, unchanged |
| `print()` and `summary()` on all four design classes | Byte-identical output |
| `print()` on a collection | Unchanged, and not by luck: the collection print path reads the row count of each member's stored frame, not the row count of the collection, so it never calls the raising method |
| `str()` on a design | Unchanged (S7's own method) |
| Coercion and subsetting on a design (`as.matrix`, `as.data.frame`, `t`, `head`, `tail`, `[`, `[[`) | Still error, same messages |
| `dimnames()`, `rownames()`, `colnames()` on a design | Still `NULL` at their defaults |
| Ten data-manipulation verbs on a design | Still return a live design |
| Every analysis function and the conversion routes | Unchanged output shapes |
| Every one of the 137 internal size-function call sites in `R/`, across 40 files | Unchanged. None takes a design; they take a stored frame, a local frame, a result tibble, or a matrix (`measurements.md` §surveycore's own internals) |

Two consequences worth naming, both benign:

1. **`apply()` on a design fails one line later.** It used to fail at its own
   `dim()` guard; it now fails coercing the object to a vector. Both states
   are errors raised inside `apply()` before any user function runs. The new
   message names the cause less clearly. Incidental, not a regression.
2. **`rownames(x, do.NULL = FALSE)` on a design builds row-count-many
   names.** It built one name before. The change runs in the correct
   direction, and no caller in `R/`, `tests/`, `vignettes/` or `man/` passes
   `do.NULL = FALSE`.

One improvement worth naming: asking each member of a collection for its own
size starts working. Under the clean tree a loop over members calling the row
count on each one fails outright; under this change each member answers with
its real count, because a member is a design and the `survey_base` method
reaches it.

---

## Error table

Add exactly one row to `plans/error-messages.md`. Place it in the
`survey_collection` area of that file, after the existing collection
subsections, under this exact heading:

```
### survey_collection dim (design-dim)
```

That file already carries three differently-styled collection subsections —
`### survey_collection rows (PR 1)`, `### survey_collection rows (PR 2 —
dispatch)` and `### survey_collection uniform grouping
(collection-uniform-groups)`. Use the heading above verbatim rather than
inventing a fourth style. Follow the column format of the rows already there.

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|----------|-----------|-------|-------------|----------------------|
| C16 | `dim()` on a `survey_collection` (and therefore `nrow()`, `ncol()`, `NROW()`, `NCOL()`) | Always — a collection has no single set of dimensions | ERROR | `surveycore_error_collection_no_dim` | `"x" = "A {.cls survey_collection} has no single set of dimensions.", "i" = "It holds {n} survey{?s}, each with its own row and column counts.", "v" = "Extract one member with {.code [[} and ask that survey instead, e.g. the member named {.val {first_name}}."` |

Bind `n` to the member count and `first_name` to the first member name
locally before the `cli::cli_abort()` call, so the template reads as written.

Notes on the template:

- The register follows `code-style.md` §Errors and warnings.
- `{?s}` handles the one-member case, so a single-member collection reads
  `1 survey`.
- **The `"v"` bullet must not presume the caller's variable name.** The
  measured form in `measurements.md` §Pass 4 hardcoded an object named `x`
  inside a code snippet, which is wrong for every user whose object is named
  something else. The template above names the member instead of the
  variable: it points at `[[` and at a real member name read off the object,
  and it never guesses what the object is called.
- `{.code [[}` is intended as a code snippet, not a function name. `[[` is an
  operator the user types, so the `{.code}` markup is correct and `{.fn}`
  would be wrong. Do not rewrite it against the `{.fn}` row of the markup
  table in `code-style.md`.
- The class value is `surveycore_error_collection_no_dim`.

The `survey_base` method has no error table row. It raises nothing.

---

## Quality gates

Each gate below is objectively verifiable. The first two are the bar the
measurement already established on this change, so a failure there is a
regression introduced during implementation and not a pre-existing condition.

- [ ] The full test suite reports FAIL 0. The measured baseline on the clean
      tree and on both patched variants was identical on all four counters
      (`measurements.md` §Regression probe — full test suite).
- [ ] No `_snaps/` file drifts. After a full suite run, the only modified
      paths are the three files in the write surface plus any new snapshot
      file the new tests create. No existing snapshot is rewritten.
- [ ] `R CMD check` reports 0 errors, 0 warnings, 1 note, and the note is the
      hidden-`.git`-directory note that a git worktree carries. It appears on
      the clean tree too. Any second note blocks.
- [ ] `devtools::document()` produces no diff in `NAMESPACE` or `man/`. The
      edited source file carries no roxygen.
- [ ] `git diff --stat` lists exactly three files.
- [ ] The diff on `R/methods-compat.R` shows only added lines and no
      line-ending change on untouched lines.
- [ ] `dim()`, `nrow()`, `ncol()`, `NROW()` and `NCOL()` each return the
      stored row or column count on all four design classes, and each raises
      `surveycore_error_collection_no_dim` on a collection.
- [ ] `is.matrix()` and `is.array()` return `FALSE` on all four design
      classes.
- [ ] `print()` on a collection still renders.
- [ ] Coverage stays at or above the 95% floor.

---

## Integration

No integration contract changes.

- **Downstream packages**: the size functions on a design begin returning a
  count where they returned `NULL` or `1L`. Any downstream code that branched
  on `NULL` gets a number instead. `measurements.md` §Pass 2 ran the change
  against a real install with the ecosystem's data-manipulation layer loaded
  and found the same five size probes changed and nothing else; ten verbs
  returned a live design in both runs.
- **The one exposure**: `NROW()` and `NCOL()` on a collection now raise where
  they returned a member count. Nothing inside this package calls them that
  way. Downstream and user code is the exposure, and it is accepted under D3.
- **No DESCRIPTION change, no new dependency, no export change, no new
  vignette.** This change is not CRAN-relevant.

---

## Pipeline split

**A split pipeline run — builder and tester as separate stages — is
recommended for this change, on two grounds: it adds a new error class, and
it changes the behaviour of a call that already worked.**

The code change is small and would qualify as optional on file count alone.
Two facts keep a real review worthwhile, and both arrived from the
measurement rather than from caution:

1. The change carries a new error class, which needs a registry row and the
   dual test pattern. That is a contract addition, not a parameter default.
2. `NROW()` and `NCOL()` on a collection go from a working value to an
   error — a behaviour change on a call that worked, on a class issue #203
   never mentions.
