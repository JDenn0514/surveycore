# Spec: the svydesign replicate bridge (#197, #198)

**Version:** 1.1
**Date:** 2026-09-04
**Status:** Draft — Stage 3r resolution applied
**Pipeline split:** recommended

---

## Document purpose

This document is the source of truth for the behaviour of the two replicate
conversion routes in `R/methods-conversion.R`. It states what the code must do
after the change. Every behaviour below is settled; nothing in this document is
an option to choose between.

Rules already written in `.claude/rules/code-style.md`,
`.claude/rules/r-package-conventions.md` and
`.claude/rules/surveycore-conventions.md` apply and are not restated here.

---

## I. Scope

### I.1 What this change delivers

| # | Change | Route | Source |
|---|---|---|---|
| 1 | Expand `x$repweights` to a full matrix before reading it | import | #197 |
| 2 | Generate replicate column names when `survey` supplies none, and store the names in `@variables$repweights` | import | #197 |
| 3 | Write one column per replicate into `@data` on every conversion, whether or not a column of that name is already there | import | #197 |
| 4 | Raise a typed error when the expanded matrix has columns but the route cannot resolve one usable, distinct name per column | import | #197 |
| 5 | Raise a typed error when a generated name already names a column of the design data | import | #197 |
| 6 | Multiply each expanded column by `x$pweights` when `x$combined.weights` is `FALSE` | import | #197 |
| 7 | Raise a typed error when the source design records a replicate type surveycore does not accept | import | D5 |
| 8 | Raise a typed error when the source design has zero rows | import | D6 |
| 9 | Stop passing `fpc` and `fpctype` to `survey::svrepdesign()`, and raise a typed warning when `@variables$fpc` names a column | export | #198 |
| 10 | Recover Fay's `rho` from the stored scale and pass it to `survey::svrepdesign()` | export | D4 |
| 11 | Raise a typed error when the design names no replicate weight column | export | D6 |
| 12 | Update the roxygen block for `from_svydesign()` and regenerate `man/from_svydesign.Rd` | import | D7 |

Rows 7, 8, 10, 11 and 12 come from decisions D4 to D7 in `decisions.md`. Each
is settled there with the measurement that decides it.

### I.2 What this change does NOT deliver

- **`NEWS.md`.** No entry lands here. Three worktrees run in parallel and all
  three would write to the same insertion point. One direct commit to `develop`
  adds all three entries after the pull requests merge.
- **The Taylor route.** `.as_svydesign_taylor()` and
  `.from_svydesign_taylor()` do not change.
- **The two-phase route.** `.as_svydesign_twophase()` and
  `.from_svydesign_twophase()` do not change.
- **The nonprob route.** No change.
- **Everything else in `R/methods-conversion.R`.** `as_svydesign()`,
  `from_svydesign()`, `as_tbl_svy()`, `from_tbl_svy()`, `.to_formula()`,
  `.vars_from_formula()` and `.find_col_by_value()` keep their current
  behaviour. Only the two replicate routes change, plus one new internal
  helper. The roxygen block above `from_svydesign()` does change — see §II.1
  and §II.3 — but the function body does not.
- **A `combined_weights` key on `survey_replicate`.** The class gains no key.
  The columns named in `@variables$repweights` stay finished weights — weights
  already on the population scale.
- **`R/core-classes.R`.** No change to any class or validator.
- **`R/variance-replicate.R`.** No change to any variance formula.
- **The constructors.** `R/core-constructors.R` does not change.
- **The `combined.weights` argument on the export route.** The route passes no
  value, so `survey::svrepdesign()` uses its own default. That default is the
  correct declaration for finished weights. This does not change.

### I.3 Design support matrix

| Design class | Import route | Export route | Changes here |
|---|---|---|---|
| `survey_replicate` | `svyrep.design` → `survey_replicate` | `survey_replicate` → `survey::svrepdesign` | Yes — both routes |
| `survey_taylor` | supported | supported | No |
| `survey_twophase` | supported | supported | No |
| `survey_srs` | supported through the Taylor route | supported | No |
| `survey_nonprob` | not supported | not supported | No |

---

## II. Architecture

### II.1 Write surface

| File | Change |
|---|---|
| `R/methods-conversion.R` | Two replicate routes; one new internal helper; the roxygen block above `from_svydesign()` |
| `man/from_svydesign.Rd` | Regenerated from that roxygen block by `devtools::document()` |
| `plans/error-messages.md` | Five new rows and two extended-trigger notes in a new dated section (§V) |

No other file in `R/` changes. `NAMESPACE` does not change: the signature, the
`@param` set and the `@return` value of `from_svydesign()` all stay as they
are. `man/` gains exactly one changed file, `man/from_svydesign.Rd`, because
the `@description` and `@details` text change. The two replicate routes are
internal, `.`-prefixed and carry `@noRd`.

### II.2 New internal helper

The helper has one call site, so it goes inline in `R/methods-conversion.R`,
above `.from_svydesign_replicate()`. Promote it to `R/utils.R` in the same
pull request that adds a second call site, per `code-style.md`.

```r
# Build the generated names for a block of replicate weight columns.
# Zero-pads the index to the width of n_rep so the names sort in replicate
# order. Follows the ..surveycore_wt.. convention: a manufactured column must
# not collide with a user column.
#   .repwt_col_names(3L)  → "..surveycore_repwt_1..", ..., "..surveycore_repwt_3.."
#   .repwt_col_names(20L) → "..surveycore_repwt_01..", ..., "..surveycore_repwt_20.."
#' @noRd
.repwt_col_names <- function(n_rep) {
  idx <- formatC(
    seq_len(n_rep),
    width = nchar(as.character(n_rep)),
    flag = "0"
  )
  paste0("..surveycore_repwt_", idx, "..")
}
```

| Property | Value |
|---|---|
| Signature | `.repwt_col_names(n_rep)` |
| `n_rep` | A whole number, `>= 1` |
| Returns | A character vector of length `n_rep` |
| Errors | None |

The `n_rep >= 1` precondition holds because §III.2 step 3 aborts a zero-row
design before the route counts the replicates. The one construction that
reaches this route with `n_rep == 0` is the zero-row design measured in D6,
whose replicate matrix is 0x0, and step 3 refuses it. `survey::svrepdesign()`
raises on a zero-column matrix, so it builds no other source for that state.
The helper itself checks nothing.

### II.3 Documentation surface

The roxygen block above `from_svydesign()` states a contract this change makes
false. Two sentences must change.

| Current text | Why it becomes false |
|---|---|
| "The data, design variables, and replicate weights are preserved" | On the fold-in branch the route multiplies each replicate column by the base weight. The weights cross the bridge correct, not unchanged. |
| Nothing about the written columns | The route can add one column per replicate to the data. For a JK1 or JKn design that is one column per PSU. |

The block must state three things after the change.

1. On a design that reports replication factors, the conversion transforms the
   replicate weights rather than preserving them. It multiplies each replicate
   column by the base weight, so the returned design carries finished weights.
2. When the source design does not name its replicate columns, the conversion
   writes a generated block into the data: one column per replicate, named on
   the `..surveycore_wt..` pattern. The same block already documents that
   pattern for the manufactured weight column, so the two sit together.
3. `@variables$repweights` names those columns, in replicate order.

Keep the existing sentence about metadata: `survey` has no metadata system and
that is unchanged. Do not add a `@param` and do not change `@return`. Run
`devtools::document()` and commit the regenerated `man/from_svydesign.Rd` in
the same pull request.

---

## III. Import route — `from_svydesign()` on a `svyrep.design`

`from_svydesign()` dispatches a `svyrep.design` object to this route. The
dispatch itself does not change.

### III.1 Current behaviour

The route reads the replicate column names straight from the object:

```r
rep_cols <- colnames(x$repweights)
```

Two defects follow.

1. `survey::as.svrepdesign()` never names the columns of the matrix it builds,
   for any replicate type and for both `compress` values. `colnames()` returns
   a length-0 vector. The route then stores zero replicate column names, writes
   no columns, and raises nothing. The converted design carries no replicate
   weights. The loss surfaces later, during analysis, as
   `surveycore_error_all_replicates_na`, which points at the analysis call.
2. The route ignores `x$combined.weights`. When that field is `FALSE` the
   matrix holds replication factors, not finished weights. Storing the factors
   unchanged leaves the point estimate correct — it reads `pweights`, not the
   replicate columns — and moves the standard error. Nothing warns.

   The size and the direction of that move both depend on the design.
   Measured across five designs: 35% too small on the `gss_2024` bootstrap
   design in issue #197, 8% too small on a 40-row JKn design, 4% too large on
   a 32-row JKn design, 10% too large on a 32-row BRR design, and 0.1% too
   large on an unclustered JK1 design. Same replicate type, different draw,
   opposite direction.

   The reason is that a weighted mean is invariant to a constant rescaling of
   its weights, so the defect is not a shrinkage. It depends on how the
   replication-factor pattern correlates with the base weights: where those
   weights barely vary the error nearly vanishes, and where they vary a lot it
   is large either way. Treat "the standard error comes out too small" as a
   fact about the `gss_2024` case, not about the defect.

`x$repweights` is also not always a matrix. With survey's default
`compress = TRUE` it is a `repweights_compressed` object: a list with elements
`weights` and `index`. `dim()` still reports the full `n x R`, so a `dim()`
check does not tell the two forms apart. `as.matrix()` expands it.

### III.2 New behaviour — ordered steps

The route runs these steps in this order. Each step that raises a condition is
the **normative** statement of that condition's trigger. §III.5, §V and the
paste-ready block in §V.7 restate the same triggers in a scannable form.

1. **Check the replicate type.** Read `x$type`. When it is not one of
   surveycore's nine accepted values, raise
   `surveycore_error_replicate_type_unsupported` (§V.5). The accepted values
   are `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`, `"Fay"`, `"bootstrap"`, `"ACS"`,
   `"successive-difference"` and `"other"` — the `type` argument of
   `as_survey_replicate()`.

   This check runs first, before any column work. There is no point expanding a
   matrix for a design the route refuses. `survey::as.svrepdesign()` accepts
   `c("auto", "JK1", "JKn", "BRR", "bootstrap", "subbootstrap", "mrbbootstrap", "Fay")`
   and stores the literal string, so `"subbootstrap"` and `"mrbbootstrap"`
   reach this route. The `survey_replicate` validator does not check `type`, so
   without this step the route stores such a value and the export route then
   fails with survey's own bare `'arg' should be one of "BRR", "Fay", ...`.

2. **Read the data.**
   `data <- .strip_labelled_columns(as.data.frame(x$variables))`. Unchanged.

3. **Check the row count.** When `nrow(data)` is 0, raise
   `surveycore_error_empty_data` (§V.6).

   A zero-row `svyrep.design` is reachable. A zero-row `survey.design` through
   `survey::as.svrepdesign(type = "JK1")` builds and reports `nrow(variables)`
   0, a 0x0 replicate matrix and `length(pweights)` 0. The row-count check in
   `.validate_data_frame()` runs only in `as_survey_replicate()`, and this
   route does not call it. An empty replicate design supports no estimate and
   no variance, so the route refuses it here.

4. **Expand the replicate matrix.**
   `rep_mat <- unclass(as.matrix(x$repweights))`.
   `as.matrix()` returns the full `n x R` matrix for both storage forms. Call
   it without a `survey::` prefix: the method is not exported, and the
   `requireNamespace("survey", quietly = TRUE)` guard in `from_svydesign()`
   loads survey's namespace, which registers the method for dispatch.

   The `unclass()` is required, not decoration. `survey::svrepdesign()` puts
   the class `"repweights"` on the object it stores, and `as.matrix()` does
   not remove it: for an uncompressed source,
   `class(as.matrix(x$repweights))` is `"repweights"`, not
   `c("matrix", "array")`. `dim()`, `ncol()`, `colnames()` and `[ , j]` all
   still work on it. Two things break. `as.data.frame()` collapses the whole
   matrix into one column instead of `n_rep` columns, and arithmetic keeps the
   class, so step 9 would propagate it. Strip it once, here, and every later
   step works on a plain matrix.

5. **Count the replicates.** `n_rep <- ncol(rep_mat)`.

6. **Resolve the column names.** Read `colnames(x$repweights)`.
   - When that vector has length 0, set `rep_cols <- .repwt_col_names(n_rep)`
     and record that the names were generated.
   - Otherwise set `rep_cols <- colnames(x$repweights)` and record that the
     names came from `survey`. Do not generate.

7. **Check the names.** A usable name set has exactly `n_rep` entries, and
   every entry is non-`NA`, non-empty and distinct. Compute the usable count:

   ```r
   usable <- rep_cols[!is.na(rep_cols) & nzchar(rep_cols)]
   n_names <- length(unique(usable))
   ```

   When `n_names != n_rep`, raise
   `surveycore_error_repweights_names_lost` (§V.1). Exactly two states reach
   this check:
   - a partly named matrix — `survey` accepts a matrix whose `colnames()`
     holds one or more empty strings, and an empty string cannot name a
     column;
   - a matrix with a repeated name — writing it would collapse two replicates
     into one column.

   A zero-length `colnames()` does not reach this check. Step 6 intercepts it
   and generates `n_rep` distinct non-empty names. That state was the old
   defect: the route stored zero names, wrote no columns, and returned a design
   with no replicate weights. Step 6 removes it, so it is no longer a trigger
   for anything.

8. **Check for a collision.** When the names were generated in step 6 and one
   or more of them already names a column of `data`, raise
   `surveycore_error_repwt_name_collision` (§V.2). Skip this check when the
   names came from `survey`: those names are meant to name existing columns.

9. **Fold the base weight in.** When `isTRUE(x$combined.weights)` is `FALSE`,
   set `rep_mat <- rep_mat * x$pweights`. Otherwise leave `rep_mat` as it is.
   The product is row-wise: `x$pweights` has length `n` and recycles down each
   column, so element `[i, r]` becomes `R[i, r] * p[i]`. Raise no condition on
   either branch. The two forms describe the same design and the product is
   exact.

   This is the correct transformation for **all nine** replicate types
   `survey::svrepdesign()` supports, not only the types measured.
   `combined.weights` is a design-level flag, not a per-type one: every type
   defines a replicate weight as `p[i] * R[i, r]` when the flag is `FALSE`.
   `survey` performs the same multiplication itself, on demand, in the
   `analysis` branch of `weights.svyrep.design`. The fold-in does it once, at
   conversion.

   `scale`, `rscales`, `mse` and `type` need no compensating change. They are
   structural constants of the variance formula and depend on the replicate
   count and the design type, not on the units of the weight column. §IV.3
   passes each of them through unchanged.

10. **Find the base weight column.** Unchanged: match `x$pweights` against the
    columns of `data`; when no column matches, add `..surveycore_wt..` and put
    `x$pweights` in it.

    This step must run **before** step 11. The match walks the columns of
    `data` in order and takes the first numeric column whose values equal
    `x$pweights`. A replicate column can hold exactly the base weights — a
    replicate that deletes nothing and scales nothing does. Writing the
    replicate block first would put such a column in reach of the match, and
    the route could name a replicate column as the base weight.

11. **Write the replicate columns.** For each `j` in `seq_len(n_rep)`, write

    ```r
    data[[rep_cols[j]]] <- as.numeric(rep_mat[, j])
    ```

    Write every column, on every conversion. There is no branch and no
    condition. When `data[[rep_cols[j]]]` already holds those values the write
    assigns the same numbers again; when it holds different values the write
    corrects them.

    The unconditional write is what makes `@variables$repweights` true.
    `survey::svrepdesign()` takes `variables` and `repweights` as independent
    arguments and cross-checks neither, so a name in `colnames(x$repweights)`
    can also name a column of `x$variables` that holds unrelated values. A
    route that skipped the write on that branch would store
    `@variables$repweights` naming a column of unrelated data — the same
    silent, wrong standard error that #197 exists to remove.

12. **Build `@variables`.** As §III.3, with `repweights = rep_cols`.

13. **Build the metadata and construct.** Unchanged:
    `.extract_haven_metadata(data)`, then `survey_replicate()`. Steps 10 and 11
    both run before this step, so the metadata reads every column of `data`,
    including the written replicate columns. The written columns are plain
    doubles and carry no label attribute, so they add no metadata entry. The
    base columns keep the entries they arrived with.

### III.3 The `@variables` list this route produces

| Key | Value |
|---|---|
| `weights` | The name of the column that holds `x$pweights`: the matched column when one matches, else `"..surveycore_wt.."`. Unchanged. |
| `repweights` | `rep_cols` — a character vector of length `n_rep`. **This is the changed key.** |
| `type` | `x$type`. Unchanged. |
| `scale` | `x$scale`. Unchanged. |
| `rscales` | `x$rscales`. Unchanged. |
| `mse` | `isTRUE(x$mse)`. Unchanged. |
| `fpc` | `NULL`. Unchanged — the import route records no FPC. |
| `fpctype` | `"fraction"`. Unchanged. |
| `probs_provided` | `FALSE`. Unchanged. |
| `visible_vars` | `NULL`. Unchanged. |

No key is added and no key is removed.

### III.4 The columns this route writes

| Property | Value |
|---|---|
| Count | `n_rep` |
| Names | `rep_cols`, in replicate order |
| Type | `double` |
| Length | `nrow(data)` |
| Row order | The row order of `x$variables`. The route writes columns and never reorders rows. |
| Zeros | Kept. A zero replicate weight is legal: JK1 and JKn delete a whole PSU per replicate, so a deleted row genuinely carries weight 0 in that replicate. Neither the fold-in nor the write treats a zero as missing or invalid. |
| Negative values | Kept. Some calibrated replicate files carry negative replicate weights. The `survey_replicate` validator checks each replicate column for numeric only; the positivity check applies to the base weight column alone. |
| `NA` | Kept, unchanged, when it sits in the replicate matrix. An `NA` in `x$pweights` does not arise — see §III.6. |

### III.5 Branch conditions

| Branch | Fires when | Result |
|---|---|---|
| Type error | `x$type` is not one of surveycore's nine accepted values | `surveycore_error_replicate_type_unsupported` |
| Empty data error | `nrow(data)` is 0 | `surveycore_error_empty_data` |
| Expand a compressed matrix | `x$repweights` is a `repweights_compressed` object | `as.matrix()` returns the full `n x R` matrix |
| Expand a plain matrix | `x$repweights` is a matrix or data frame | `as.matrix()` returns it unchanged in shape |
| Generate names | `length(colnames(x$repweights)) == 0L` | `rep_cols` comes from `.repwt_col_names(n_rep)` |
| Keep survey's names | `length(colnames(x$repweights)) > 0L` | `rep_cols` is `colnames(x$repweights)` |
| Name error | The usable, distinct name count is not `n_rep` | `surveycore_error_repweights_names_lost` |
| Collision error | Names were generated and at least one is already a column of `data` | `surveycore_error_repwt_name_collision` |
| Fold the base weight in | `isTRUE(x$combined.weights)` is `FALSE` | Each column is multiplied by `x$pweights` |
| Store unchanged values | `isTRUE(x$combined.weights)` is `TRUE` | The matrix passes through |
| Write a column | Always, once per replicate | `data[[name]]` holds the finished weights |

### III.6 Edge cases

| Case | Behaviour |
|---|---|
| One replicate (`n_rep == 1L`) | Generated name is `..surveycore_repwt_1..` — width 1, no padding. |
| Two replicates | Generated names are `..surveycore_repwt_1..` and `..surveycore_repwt_2..`. |
| Ten or more replicates | The index is padded to the width of `n_rep`: 20 replicates give `..surveycore_repwt_01..` through `..surveycore_repwt_20..`. |
| Replicate columns already named by `survey` | The names pass through into `@variables$repweights`. No name is generated. No collision check runs. The route still writes every column, from the expanded matrix. |
| Replicate columns named by `survey` but absent from `data` | The route writes them in under those names. |
| Replicate columns named by `survey` with `x$combined.weights` `FALSE` | The route overwrites those columns with the finished weights. The names do not change. |
| A replicate column name that also names a column of unrelated values | The route overwrites that column with the replicate weight. `survey::svrepdesign()` cross-checks `variables` against `repweights` for neither name nor value, so the two can disagree. The replicate matrix is the source of truth. |
| A partly named matrix — `colnames()` holds one or more empty strings | `surveycore_error_repweights_names_lost`. An empty string cannot name a column. |
| A matrix with a repeated column name | `surveycore_error_repweights_names_lost`. Writing it would collapse two replicates into one column. |
| A compressed source whose original columns were named | Step 6 reads `colnames(x$repweights)`. When compression left that vector empty, the route generates names and writes a new block, even though similar columns already sit in the data. The result is correct: `@variables$repweights` names `n_rep` columns of `@data` that hold finished weights. The route does not match values against existing columns to recover a name. |
| Genuine zeros in the matrix | Preserved through the fold-in and the write. |
| A negative value in the matrix | Preserved. The route neither rejects nor rescales it. The validator checks each replicate column for numeric only, and the positivity check covers the base weight column alone. Some calibrated replicate files carry negative replicate weights. |
| `NA` in the matrix | Preserved. |
| `NA` in `x$pweights` | Not reachable through `survey`, so the route adds no guard. Measured: `survey::svydesign()` drops every row whose weight is `NA`, on all three `na_weights` settings. Its source reads `if (any(is.na(pre_weights))) { data <- data[!is.na(pre_weights), ] }`; only `"fail"` stops before that line, while `"warn"` warns and drops and `"allow"` drops in silence. A 10-row frame with one `NA` weight gives a 9-row design with no `NA` in `pweights`. Passing such a matrix straight to `survey::svrepdesign()` fails inside its own `combined.weights` heuristic instead. The `na_weights` argument permits an `NA` weight in the input, not in the design. |
| A zero-column replicate matrix (`n_rep == 0L`) | Not reachable past step 3. Such a design also has zero rows, and step 3 raises `surveycore_error_empty_data` before the route counts the replicates. |
| `x$pweights` holds a zero or a negative value | The `survey_replicate` validator raises `surveycore_error_weights_nonpositive` at construction. Existing behaviour, unchanged. |
| A replicate column equals `x$pweights` exactly, and no column of the data holds the base weights | Step 10 runs before step 11, so the base weight search never sees the replicate block. The route adds `..surveycore_wt..` and records that name in `@variables$weights`. |
| Single-row data | Converted, with no special handling. One row is a legal replicate design and the route adds no guard for it. |
| Zero-row data | `surveycore_error_empty_data` at step 3. |
| A replicate type outside surveycore's nine | `surveycore_error_replicate_type_unsupported` at step 1. `"subbootstrap"` and `"mrbbootstrap"` from `survey::as.svrepdesign()` are the two reachable values. |
| All-`NA` outcome column | Not read by this route. The route touches design columns only. |

### III.7 Why the manufactured weight column has no collision guard

Step 10 can add a column named `..surveycore_wt..` to the data. When the data
already holds a column of that name, the route overwrites it and raises
nothing. Step 8 does the opposite for a generated replicate name: it raises a
typed error.

The asymmetry is real and it stays. The overwrite is the existing behaviour of
the import routes — `.from_svydesign_taylor()` and
`.from_svydesign_replicate()` both write the name without a check — and it is
outside this change's scope. Two reasons make it acceptable to leave.

- The name is documented as internal. `..surveycore_wt..` is reserved by
  CLAUDE.md, is documented in `?from_svydesign`, and only surveycore writes
  it. A user column of that name is a collision with a reserved name.
- The overwrite loses no design information. The column that lands there holds
  `x$pweights`, and `@variables$weights` names it, so the design is correct
  after the write. A generated replicate name that collides is different: the
  route would overwrite a user column whose values it never reads.

Changing the weight column's behaviour would touch all three import routes and
their conditions. Raise it as its own issue — see §IX.

---

## IV. Export route — `as_svydesign()` on a `survey_replicate`

`as_svydesign()` dispatches a `survey_replicate` object to this route. The
dispatch itself does not change.

### IV.1 Current behaviour

The route passes the per-row FPC column to `survey::svrepdesign()`:

```r
fpc = if (!is.null(fpc_var)) x@data[[fpc_var]] else NULL,
fpctype = fpctype,
```

`survey::svrepdesign()` treats the FPC as a per-replicate multiplier on the
replicate scales and checks `length(fpc)` against `length(rscales)`, which is
`R`. surveycore's `@variables$fpc` names a column of `@data`, which has length
`n`. The two lengths coincide only when `n` equals `R`, so any replicate design
that carries an FPC fails with survey's own `fpc is wrong length`.
`as_svydesign(x)` takes only `x`, so the caller has no way around it.

The mismatch is semantic as well as a length problem. In `survey::svydesign()`
the FPC is a per-row population size or sampling fraction. In
`survey::svrepdesign()` it is a per-replicate multiplier. Reshaping the column
to length `R` would give the right shape and the wrong quantity. Six of
survey's nine replicate types reject an FPC outright.

### IV.2 New behaviour — ordered steps

The steps that raise a condition are the **normative** statement of that
condition's trigger, as in §III.2.

1. **Read the design keys.** `wts_var <- x@variables$weights`,
   `rep_vars <- x@variables$repweights`, `fpc_var <- x@variables$fpc`.

2. **Check the replicate count.** When `length(rep_vars)` is 0, raise
   `surveycore_error_repweights_empty` (§V.6).

   `survey::svrepdesign()` with a zero-column replicate matrix fails with
   `missing value where TRUE/FALSE needed`, from inside its own
   `combined.weights` heuristic — a bare error with no class. An empty
   replicate design supports no estimate and no variance, so the route refuses
   it here.

3. **Compute the scale argument.** Unchanged: `NULL` when
   `x@variables$type` is `"BRR"` or `"Fay"`, otherwise `x@variables$scale`.
   `survey::svrepdesign()` warns when a scale reaches it for those two types.

4. **Recover Fay's `rho`.** When `x@variables$type` is `"Fay"`, compute

   ```r
   n_rep <- length(x@variables$repweights)
   scale <- x@variables$scale
   rho <- 1 - sqrt(1 / (scale * n_rep))
   ```

   and pass `rho = rho` to `survey::svrepdesign()`. For every other type the
   route passes no `rho`, as today.

   This step is required, not an improvement. `svrepdesign.default` contains

   ```r
   if (type == "Fay" && is.null(rho))
     stop("With type='Fay' you must supply the correct rho")
   ```

   so without `rho` the export route fails outright for Fay.

   The recovery inverts survey's own scale formula. `survey` computes a Fay
   design's scale as `scale = 1 / (n_rep * (1 - rho)^2)`, and the import route
   stores that value in `@variables$scale`. Solving for `rho` gives the line
   above. Measured: a design built with `fay.rho = 0.3` recovers 0.3 exactly,
   rebuilds with scale 0.170068 against the source's 0.170068, and reports
   SE 0.1841391 against the source's 0.1841391.

   **How this meets step 3.** Step 3 keeps passing `scale = NULL` for both
   `"BRR"` and `"Fay"`. For BRR that is the whole story: `survey` computes
   `scale = 1 / n_rep`, which has no free parameter. For Fay, `survey`
   recomputes the scale from the `rho` this step passes, and the `rho` came
   from the stored scale, so the rebuilt scale equals the stored one. Passing
   `rho` alone reproduces the scale. Passing both is unnecessary.

   **When the recovery fails.** Raise
   `surveycore_error_fay_rho_unrecoverable` (§V.4) when `x@variables$type` is
   `"Fay"` and any of these holds:
   - `x@variables$scale` is `NULL`;
   - `x@variables$scale` is not finite;
   - `x@variables$scale` is not greater than 0;
   - the recovered `rho` is `NA`, or falls outside `[0, 1)`.

   **Both arms are reachable, by different routes. Do not mark either
   `# nocov`.** Measured on this worktree:

   | Route | Recorded `scale` | Recovered `rho` | Result |
   |---|---|---|---|
   | `survey_replicate()`, `variables` list with no `scale` key | `NULL` | none | the condition fires |
   | `as_survey_replicate(type = "Fay")`, no `scale` argument | `1 / n_rep` | `0` | legal, converts |
   | `as_survey_replicate(type = "Fay", scale = 0.05)`, 8 replicates | `0.05` | `-0.581` | the condition fires |

   The out-of-range arm comes from `as_survey_replicate()`, which accepts any
   numeric `scale` — no validator checks its value — so a `scale` whose
   product with `n_rep` is below 1 puts the recovered `rho` below 0.

   The missing-scale arm comes from `survey_replicate()`. That constructor is
   exported, its `variables` argument is an untyped list, and its validator
   checks neither `scale` nor `type`. So a caller can build a `"Fay"` design
   with no `scale` key at all, and issue #198's own reproduction uses exactly
   that construction. `as_survey_replicate()` does fill `scale = 1 / n_rep`
   for `"Fay"`, which recovers `rho = 0` — legal, and the BRR case — so that
   constructor never produces the state. The bare one does.

   Both arms therefore need a test, and neither needs a coverage exemption.

5. **Warn when an FPC is recorded.** When `fpc_var` is not `NULL`, raise
   `surveycore_warning_replicate_fpc_dropped` (§V.3). The condition names the
   dropped column. Raise it once per call, before the `survey::svrepdesign()`
   call. When `fpc_var` is `NULL`, raise nothing.

6. **Call `survey::svrepdesign()` without `fpc` and without `fpctype`.** The
   route passes neither argument, on either branch of step 5. It passes `rho`
   for `"Fay"` and for no other type. Nothing else in the call changes.

7. **Return** the `survey::svrepdesign` object. The route returns it visibly,
   as today.

The local `fpctype` value that the route computes today becomes unused. Remove
it.

### IV.3 The keys this route reads, and where each one goes

| `@variables` key | `survey::svrepdesign()` argument | Note |
|---|---|---|
| `weights` | `weights = x@data[[wts_var]]` | Unchanged |
| `repweights` | `repweights = x@data[, rep_vars, drop = FALSE]` | Unchanged |
| `type` | `type = x@variables$type` | Unchanged |
| `scale` | `scale = scale_arg` | Unchanged; `NULL` for `"BRR"` and `"Fay"` |
| `rscales` | `rscales = x@variables$rscales` | Unchanged |
| `mse` | `mse = isTRUE(x@variables$mse)` | Unchanged |
| `fpc` | *not passed* | **Changed.** Triggers the warning when non-`NULL` |
| `fpctype` | *not passed* | **Changed.** Never reaches survey |
| `scale`, `repweights`, `type` | `rho = 1 - sqrt(1 / (scale * n_rep))` | **New.** Passed for `"Fay"` only, derived from the stored scale and the replicate count |
| — | `data = x@data` | Unchanged |
| — | `combined.weights` | Not passed, as today. survey's default declares finished weights, which is what `@data` holds. |

The route writes nothing and produces no `@variables` list. It does not modify
`x`.

### IV.4 The FPC stays on the surveycore design

The drop affects the exported `survey` design only. After the call:

- `x@variables$fpc` still names the same column.
- `x@variables$fpctype` still holds the same value.
- `x@data` still holds the FPC column.
- `print(x)` and `summary(x)` still report the FPC.

No property of `x` changes. A second `as_svydesign(x)` call raises the same
warning again.

### IV.5 Why the drop changes no surveycore number

surveycore's replicate variance never reads the FPC.
`R/variance-replicate.R` contains no reference to it, and
`.get_design_vars_flat()` in `R/utils.R` omits `fpc` from the design columns it
reports for `survey_replicate` while including it for `survey_taylor`. On a
replicate design the FPC is recorded and printed but enters no number.

So the exported design reproduces surveycore's own standard errors exactly.
Translating the FPC would do the opposite. `survey::svrepdesign()` reads
`fpctype` and then scales the replicate scales:

```r
fpc <- switch(fpctype, correction = fpc, fraction = 1 - fpc)
rscales <- rscales * fpc
```

So a translated FPC multiplies every replicate scale by `1 - fpc` under the
default `fpctype = "fraction"`, and the exported design would return standard
errors that surveycore itself does not produce.

`survey` reaches the same conclusion for the same kind of case. Its own
`as.svrepdesign()` contains, on the branch that builds a Fay or BRR design:

```r
warning("Finite population correction dropped in conversion")
```

Warn-and-drop is `survey`'s established idiom for an FPC that cannot be
represented on the replicate design being built. This route applies it to every
type rather than only those two, because the per-row and per-replicate
quantities differ even for the types `survey::svrepdesign()` would accept an
FPC for.

There is also nothing to carry in the other direction.
`svrepdesign.default`'s return list is
`list(type=, scale=, rscales=, rho=, call=, combined.weights=)` — it never
stores the raw `fpc` value, only its applied effect on `rscales`. So §III.3's
`fpc = NULL` on the import route is not a choice either: a `svyrep.design` has
no FPC field to read.

### IV.6 Edge cases

| Case | Behaviour |
|---|---|
| No FPC recorded (`@variables$fpc` is `NULL`) | No warning. The call shape is the same as the FPC case, minus the warning. |
| FPC recorded, type `"JK1"` or `"JKn"` — types survey accepts an FPC for | Warn and drop. The rule does not depend on the type. |
| FPC recorded, type `"bootstrap"` | Warn and drop. Conversion succeeds. survey's `Separate fpc not needed for bootstrap` never reaches the caller. |
| FPC recorded, type `"BRR"`, `"Fay"`, `"JK2"`, `"ACS"` or `"successive-difference"` — types survey rejects an FPC for | Warn and drop. Conversion succeeds. survey's `fpc not available for this type` never reaches the caller. |
| FPC recorded, type `"other"` | Warn and drop. |
| One replicate column | No special handling. |
| Zero replicate columns (`length(@variables$repweights)` is 0) | `surveycore_error_repweights_empty` at step 2. Reachable from a `survey_replicate` built by a route that does not call `.validate_data_frame()`. |
| A replicate column holding zeros | No special handling. The route passes the columns through. |
| Type `"Fay"` with a usable scale | The route passes the recovered `rho`. Conversion succeeds and the exported design reports the stored scale. |
| Type `"Fay"` with a scale that yields no `rho` in `[0, 1)` | `surveycore_error_fay_rho_unrecoverable` at step 4. Two reachable cases: a `scale` whose product with the replicate count is below 1, from `as_survey_replicate()`; and no recorded `scale` at all, from the bare `survey_replicate()` constructor. See §IV.2 step 4. |
| Type `"Fay"` with the constructor's default scale | The default is `1 / n_rep`, which recovers `rho = 0`. Conversion succeeds. A Fay design with `rho = 0` is the BRR case. |
| Type `"BRR"` | No `rho`. `survey` computes `scale = 1 / n_rep`, which has no free parameter. |
| `@variables$fpctype` is `NULL` | No effect: the route no longer reads it. |

### IV.7 Deliberate divergence from #198's verification list

Issue #198 asks that `type = "bootstrap"` with an FPC produce a surveycore
error instead of survey's `Separate fpc not needed for bootstrap`. This change
produces the drop warning and a working design instead. That meets the issue's
requirement — no bare `stop()` from `survey` reaches the caller, and the
condition names the field — and it converts a design the error route would have
rejected. Every replicate type, bootstrap included, converts.

---

## V. Conditions

Four errors and one warning are new. Two existing classes gain a new trigger.
Add the five new rows and the two extended-trigger notes to
`plans/error-messages.md` in a new dated section, in that file's own six-column
format. Row 62 (`surveycore_warning_twophase_method_unknown`) and row 89
(`surveycore_warning_fpc_partial_stages`) are the precedent for the warning: a
`surveycore_warning_*` class raised by a conversion route when a design detail
cannot cross intact. Rows 16 and 17 are the precedent for extending a trigger
rather than adding a class.

**One normative location per condition.** The ordered step in §III.2 or §IV.2
states each trigger normatively. The Trigger field in the subsections below,
the predicate in the §III.5 branch table, and the Condition column of the
paste-ready block in §V.7 all restate it in a scannable form. The Condition
column prose is a paraphrase of the Trigger fields. An editor who changes one
of the four checks the other three.

### V.1 `surveycore_error_repweights_names_lost`

| Field | Value |
|---|---|
| Route | `from_svydesign()` on a `svyrep.design` |
| Trigger | The usable, distinct name count is not `n_rep` (§III.2 step 7) |
| Level | ERROR |
| Bindings | `{n_rep}` = `ncol(as.matrix(x$repweights))`; `{n_names}` = the count of usable, distinct names, as computed in §III.2 step 7 |

```r
cli::cli_abort(
  c(
    "x" = paste0(
      "The {.pkg survey} design has {n_rep} replicate weight column{?s} ",
      "but {n_names} usable column name{?s}."
    ),
    "i" = paste0(
      "{.fn from_svydesign} needs one name per replicate column to store ",
      "the weights in the design data."
    ),
    "v" = paste0(
      "Rebuild the design with {.fn survey::svrepdesign} and pass ",
      "{.arg repweights} as a data frame with one named column per replicate."
    )
  ),
  class = "surveycore_error_repweights_names_lost"
)
```

Exactly two states reach this condition: a partly named matrix, where
`colnames()` holds one or more empty strings, and a matrix with a repeated
name. A zero-length `colnames()` does not. §III.2 step 6 intercepts it and
generates `n_rep` distinct non-empty names, so the count always matches. The
zero-name state is the defect this change removes, not a trigger.

### V.2 `surveycore_error_repwt_name_collision`

| Field | Value |
|---|---|
| Route | `from_svydesign()` on a `svyrep.design` |
| Trigger | The route generated the replicate names, and at least one generated name already names a column of the design data (§III.2 step 8) |
| Level | ERROR |
| Bindings | `{collisions}` = the generated names that already name a column, in replicate order; `{n_collisions}` = `length(collisions)` |

```r
cli::cli_abort(
  c(
    "x" = paste0(
      "{.fn from_svydesign} cannot store the replicate weights under ",
      "generated names."
    ),
    "i" = paste0(
      "The design data already {cli::qty(n_collisions)}",
      "{?has a column/has columns} named {.field {collisions}}."
    ),
    "i" = paste0(
      "A generated name reaches the data when an earlier conversion left its ",
      "replicate columns there."
    ),
    "v" = paste0(
      "Rename the conflicting {cli::qty(n_collisions)} column{?s} in the design ",
      "data, then convert again."
    )
  ),
  class = "surveycore_error_repwt_name_collision"
)
```

Each bullet carries its own quantity, so each pluralizes on its own. Verified
in both numbers: one collision renders "The design data already has a column
named X.", and three render "The design data already has columns named X, Y,
and Z."

The `qty()` call is required, not decoration. `cli` evaluates every bullet as
its own string, and a `{?s}` with no quantity in the same bullet makes
`cli_abort()` throw `simpleError: Cannot pluralize without a quantity` before
the typed condition exists. A test on the class would then never pass.

### V.3 `surveycore_warning_replicate_fpc_dropped`

| Field | Value |
|---|---|
| Route | `as_svydesign()` on a `survey_replicate` |
| Trigger | `x@variables$fpc` is not `NULL` (§IV.2 step 5) |
| Level | WARN |
| Bindings | `{fpc_var}` = `x@variables$fpc` |

```r
cli::cli_warn(
  c(
    "!" = paste0(
      "{.fn as_svydesign} dropped the finite population correction column ",
      "{.field {fpc_var}}."
    ),
    "i" = paste0(
      "{.fn survey::svrepdesign} takes one FPC value per replicate, and a ",
      "{.cls survey_replicate} design records one value per row."
    ),
    "i" = paste0(
      "surveycore's replicate variance does not read the FPC, so the ",
      "returned design reproduces surveycore's own standard errors."
    ),
    "v" = paste0(
      "Call {.fn survey::svrepdesign} directly with {.arg fpc} to apply a ",
      "per-replicate correction."
    )
  ),
  class = "surveycore_warning_replicate_fpc_dropped"
)
```

The `"v"` bullet is imperative and addresses no one. Second person is
forbidden by `code-style.md`.

### V.4 `surveycore_error_fay_rho_unrecoverable`

| Field | Value |
|---|---|
| Route | `as_svydesign()` on a `survey_replicate` |
| Trigger | `@variables$type` is `"Fay"` and the stored scale yields no usable `rho` (§IV.2 step 4) |
| Level | ERROR |
| Bindings | `{scale_txt}` = the recorded scale formatted as a one-element character string, or the string `"none"` when `@variables$scale` is `NULL` |

```r
cli::cli_abort(
  c(
    "x" = paste0(
      "{.fn as_svydesign} cannot recover the {.val Fay} shrinkage factor ",
      "for this design."
    ),
    "i" = paste0(
      "{.fn survey::svrepdesign} requires {.arg rho} for ",
      "{.code type = \"Fay\"}, and surveycore derives it from the recorded ",
      "scale."
    ),
    "i" = paste0(
      "The recorded scale is {.val {scale_txt}} and yields no value in ",
      "{.code [0, 1)}."
    ),
    "v" = paste0(
      "Rebuild the design with {.fn as_survey_replicate} and pass the ",
      "{.arg scale} the {.val Fay} replicates were built with."
    )
  ),
  class = "surveycore_error_fay_rho_unrecoverable"
)
```

`{scale_txt}` is a string in every branch, including the `NULL` branch, so the
message renders without a special case. The route builds it before the call.

### V.5 `surveycore_error_replicate_type_unsupported`

| Field | Value |
|---|---|
| Route | `from_svydesign()` on a `svyrep.design` |
| Trigger | `x$type` is not one of surveycore's nine accepted values (§III.2 step 1) |
| Level | ERROR |
| Bindings | `{rep_type}` = `x$type`; `{accepted}` = the nine accepted values, in the order `as_survey_replicate()` declares them |

```r
cli::cli_abort(
  c(
    "x" = paste0(
      "The {.pkg survey} design records replicate type {.val {rep_type}}, ",
      "which surveycore does not accept."
    ),
    "i" = "surveycore accepts {.val {accepted}}.",
    "v" = paste0(
      "Rebuild the design with {.fn survey::as.svrepdesign} and an accepted ",
      "type, then convert it again."
    )
  ),
  class = "surveycore_error_replicate_type_unsupported"
)
```

No bullet pluralizes, so no bullet needs a quantity. `{.val {accepted}}`
renders the nine values as a comma-separated list.

### V.6 Existing classes with an extended trigger

Two conditions reuse a class already in `plans/error-messages.md`. Neither adds
a class. Rows 16 and 17 of that file set the precedent: a trigger description
grows when a second function raises the same class.

| Class | Existing row | Route | New trigger |
|---|---|---|---|
| `surveycore_error_empty_data` | 2 | `from_svydesign()` on a `svyrep.design` | `nrow(as.data.frame(x$variables))` is 0 (§III.2 step 3) |
| `surveycore_error_repweights_empty` | 16 | `as_svydesign()` on a `survey_replicate` | `length(@variables$repweights)` is 0 (§IV.2 step 2) |

Each route raises the class with its own message. Row 2's template names an
argument that these routes do not have, so neither route reuses the text.

```r
# Import route, §III.2 step 3.
cli::cli_abort(
  c(
    "x" = "The {.pkg survey} design has no rows.",
    "i" = paste0(
      "{.fn from_svydesign} needs at least one row to build a ",
      "{.cls survey_replicate} design."
    ),
    "v" = "Convert a design built on data with at least one row."
  ),
  class = "surveycore_error_empty_data"
)
```

```r
# Export route, §IV.2 step 2.
cli::cli_abort(
  c(
    "x" = "The design names no replicate weight column.",
    "i" = paste0(
      "{.fn survey::svrepdesign} needs at least one replicate weight ",
      "column, and fails with an untyped error without one."
    ),
    "v" = paste0(
      "Rebuild the design with {.fn as_survey_replicate} and name its ",
      "replicate weight columns."
    )
  ),
  class = "surveycore_error_repweights_empty"
)
```

### V.7 Rows to add to `plans/error-messages.md`

Append this section at the end of the file, after
`### var-extension-slot rows (2026-08-27)`. The `CB` prefix stands for
conversion bridge and is unused elsewhere in the file. The Condition column
paraphrases the Trigger fields in §V.1 to §V.6; an editor who changes one
checks the other.

```markdown
### svydesign-replicate-bridge rows (2026-09-04)

All four errors and the warning are user-facing conversion conditions raised by
an exported function, so they carry the full CLI x/i/v register.
Row 62 (`surveycore_warning_twophase_method_unknown`) and row 89
(`surveycore_warning_fpc_partial_stages`) are the precedent for a
`surveycore_warning_*` class raised when a design detail cannot cross a
conversion route intact.

**Variable bindings.** `{n_rep}` = the number of columns in the expanded
replicate matrix; `{n_names}` = the number of usable, distinct replicate column
names the route resolved — a usable name is non-`NA` and non-empty;
`{collisions}` = the generated names that already name a column of the design
data; `{n_collisions}` = how many of them there are; `{fpc_var}` = the name of
the dropped FPC column; `{scale_txt}` = the recorded replicate scale as a
string, or `"none"` when no scale is recorded; `{rep_type}` = the replicate
type the `survey` design records; `{accepted}` = the nine replicate types
`as_survey_replicate()` accepts.

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| CB-1 | `from_svydesign()` (replicate) | The route cannot resolve one usable, distinct name per replicate column — an empty-string name, or a repeated name | ERROR | `surveycore_error_repweights_names_lost` | `"x" = "The {.pkg survey} design has {n_rep} replicate weight column{?s} but {n_names} usable column name{?s}.", "i" = "{.fn from_svydesign} needs one name per replicate column to store the weights in the design data.", "v" = "Rebuild the design with {.fn survey::svrepdesign} and pass {.arg repweights} as a data frame with one named column per replicate."` |
| CB-2 | `from_svydesign()` (replicate) | The route generated the replicate column names, and one or more of them already names a column of the design data | ERROR | `surveycore_error_repwt_name_collision` | `"x" = "{.fn from_svydesign} cannot store the replicate weights under generated names.", "i" = "The design data already {cli::qty(n_collisions)}{?has a column/has columns} named {.field {collisions}}.", "i" = "A generated name reaches the data when an earlier conversion left its replicate columns there.", "v" = "Rename the conflicting {cli::qty(n_collisions)} column{?s} in the design data, then convert again."` |
| CB-3 | `as_svydesign()` (replicate) | `@variables$fpc` names a column; the FPC is omitted from the `survey::svrepdesign()` call | WARN | `surveycore_warning_replicate_fpc_dropped` | `"!" = "{.fn as_svydesign} dropped the finite population correction column {.field {fpc_var}}.", "i" = "{.fn survey::svrepdesign} takes one FPC value per replicate, and a {.cls survey_replicate} design records one value per row.", "i" = "surveycore's replicate variance does not read the FPC, so the returned design reproduces surveycore's own standard errors.", "v" = "Call {.fn survey::svrepdesign} directly with {.arg fpc} to apply a per-replicate correction."` |
| CB-4 | `as_svydesign()` (replicate) | `@variables$type` is `"Fay"` and the recorded scale is missing, non-finite or non-positive, or yields a shrinkage factor outside `[0, 1)` | ERROR | `surveycore_error_fay_rho_unrecoverable` | `"x" = "{.fn as_svydesign} cannot recover the {.val Fay} shrinkage factor for this design.", "i" = "{.fn survey::svrepdesign} requires {.arg rho} for {.code type = \"Fay\"}, and surveycore derives it from the recorded scale.", "i" = "The recorded scale is {.val {scale_txt}} and yields no value in {.code [0, 1)}.", "v" = "Rebuild the design with {.fn as_survey_replicate} and pass the {.arg scale} the {.val Fay} replicates were built with."` |
| CB-5 | `from_svydesign()` (replicate) | `x$type` is not one of the nine replicate types `as_survey_replicate()` accepts — `survey::as.svrepdesign()` also produces `"subbootstrap"` and `"mrbbootstrap"` | ERROR | `surveycore_error_replicate_type_unsupported` | `"x" = "The {.pkg survey} design records replicate type {.val {rep_type}}, which surveycore does not accept.", "i" = "surveycore accepts {.val {accepted}}.", "v" = "Rebuild the design with {.fn survey::as.svrepdesign} and an accepted type, then convert it again."` |

**Updated trigger descriptions for existing rows:**

- Row 2 (`surveycore_error_empty_data`): trigger description extended — now
  also fired by `from_svydesign()` on a `survey::svrepdesign` object whose data
  has 0 rows. That route raises the class with a conversion-register message of
  its own; it does not reuse the `{.arg data}` template.
- Row 16 (`surveycore_error_repweights_empty`): trigger description extended —
  now also fired by `as_svydesign()` on a `survey_replicate` whose
  `@variables$repweights` has length 0.
```

### V.8 Conditions this change does not add

- No condition fires on the fold-in. `survey::as.svrepdesign()` reports the
  factor form for every replicate type, so the fold-in is the path nearly every
  real conversion takes. A warning there would fire on almost every call.
- No condition fires when the route generates names. Generation is the ordinary
  case for `survey::as.svrepdesign()` output.
- No condition fires when the route writes over an existing replicate column.
  §III.2 step 11 writes every column on every conversion.
- No condition fires on a negative replicate weight, or on `NA` in
  `x$pweights`. See §III.6.
- No condition fires when the route overwrites a `..surveycore_wt..` column.
  See §III.7.

### V.9 Why one condition is silent and the other is loud

The fold-in is silent and the FPC drop warns. The two are different kinds of
event.

The fold-in is a correction. Both weight forms describe the same design, the
product is exact and invertible, and `survey` performs the same multiplication
itself at call time. No information is lost and the user has nothing to act on.

The FPC drop is a loss. The design records a quantity that the exported
`survey` design will not carry, and there is an alternative the user can take:
call `survey::svrepdesign()` directly with a per-replicate `fpc`. A condition
that names the dropped column and the alternative is worth its noise.

---

## VI. Observable properties

These properties must hold after the change. They are stated as behaviour of
the two exported functions.

1. **Import parity.** For a `svyrep.design` built by
   `survey::as.svrepdesign()`, the design that `from_svydesign()` returns
   produces the same point estimate, the same standard error and the same
   confidence bounds as `survey` reports on the original design. This holds for
   both `compress` values and for both `combined.weights` values.
2. **Export parity.** For a `survey_replicate` design, the
   `survey::svrepdesign` object that `as_svydesign()` returns produces the same
   point estimate and standard error that surveycore produces on the design
   itself. This holds whether or not the design records an FPC.
3. **Round-trip parity.** `as_svydesign(from_svydesign(b))` produces the same
   point estimate and standard error as `b`.
4. **No silent loss.** After `from_svydesign()` on a `svyrep.design`,
   `length(@variables$repweights)` equals the replicate count of the source
   design, and every name in it is a column of the design data.
5. **No silent renaming.** When the source design names its replicate columns,
   `@variables$repweights` holds those names, in that order.
6. **The export drop is loud.** `as_svydesign()` on a replicate design that
   records an FPC raises a typed warning that names the dropped column, and
   returns a working design.
7. **The export drop is not destructive.** The surveycore design is the same
   object before and after the call.
8. **Every accepted replicate type converts in both directions.** All nine
   types `as_survey_replicate()` accepts cross both routes, Fay included. A
   type outside that set does not reach the export route: `from_svydesign()`
   refuses it with a typed error at import.
9. **A Fay design keeps its scale.** For a Fay design, the
   `survey::svrepdesign` object that `as_svydesign()` returns reports the same
   scale the surveycore design records, and the same standard error the source
   `survey` design reports.
10. **The stored replicate columns match the source matrix.** After
    `from_svydesign()`, each column named in `@variables$repweights` holds the
    corresponding column of the expanded source matrix, times the base weight
    when the source reported replication factors. This holds whether or not a
    column of that name was in the data before the conversion.
11. **A degenerate design is refused, not built.** `from_svydesign()` on a
    zero-row `svyrep.design` and `as_svydesign()` on a design that names no
    replicate column both raise a typed error. Neither returns an object and
    neither lets an untyped `survey` error reach the caller.
12. **The generated columns add no metadata.** After `from_svydesign()`, the
    variable labels on the base columns are the ones the source data carried,
    and the written replicate columns contribute no metadata entry.

---

## VII. Quality gates

Each gate is a check with one observable outcome.

| # | Gate | How to check |
|---|---|---|
| 1 | `R CMD check` is clean | `devtools::check()` gives 0 errors, 0 warnings and at most the two pre-approved notes |
| 2 | The full test suite passes | `Rscript -e "devtools::test()"` reports 0 failures and 0 warnings |
| 3 | Line coverage does not fall below the floor | `covr::package_coverage()` with `NOT_CRAN=true` reports at least 95% for the package, and 100% of the new lines in `R/methods-conversion.R` are covered |
| 4 | Every new condition is typed | Every `cli_abort()` and `cli_warn()` added in this change carries a `class` argument |
| 5 | The condition table matches the code | The five new class names in `plans/error-messages.md` §svydesign-replicate-bridge appear verbatim in `R/methods-conversion.R`, alongside the two reused names `surveycore_error_empty_data` and `surveycore_error_repweights_empty`. No other new class name appears there |
| 6 | The write surface holds | `git diff --name-only` against `origin/develop` lists only `R/methods-conversion.R`, `man/from_svydesign.Rd`, `plans/error-messages.md`, `tests/testthat/test-conversion.R` and `tests/testthat/_snaps/conversion.md` |
| 7 | `NEWS.md` is untouched | `git diff --name-only` does not list `NEWS.md` |
| 8 | Only the documented page regenerates | `devtools::document()` leaves `NAMESPACE` unchanged, and the only file under `man/` that differs from `origin/develop` is `man/from_svydesign.Rd` |
| 9 | Formatting is clean | `air::format_package()` produces no diff |
| 10 | The FPC arguments are gone from the export call | `R/methods-conversion.R` contains no `fpc =` or `fpctype =` argument inside the `survey::svrepdesign()` call |
| 11 | No class change leaked in | `git diff` shows no change to `R/core-classes.R`, `R/core-constructors.R` or `R/variance-replicate.R` |
| 12 | The docstring no longer states the false contract | `man/from_svydesign.Rd` contains no sentence saying the replicate weights are preserved, and does describe the written replicate column block |
| 13 | Fay reaches survey with a shrinkage factor | The `survey::svrepdesign()` call in `R/methods-conversion.R` passes `rho` on the `"Fay"` branch, and no run of the export route produces survey's `With type='Fay' you must supply the correct rho` stop |

---

## VIII. Integration

| Package | Contract | Effect of this change |
|---|---|---|
| `survey` | `Suggests`. Both routes guard on `requireNamespace("survey", quietly = TRUE)` and raise `surveycore_error_pkg_not_installed` when it is absent. The guard also loads survey's namespace, which registers `as.matrix.repweights_compressed` for dispatch. | Unchanged, and now relied on for the expansion step. The export route also passes `rho` for a Fay design, an argument `survey::svrepdesign()` already accepts |
| `srvyr` | `Suggests`. `as_tbl_svy()` calls `as_svydesign()`; `from_tbl_svy()` calls `from_svydesign()`. | `as_tbl_svy()` on a replicate design that records an FPC now raises the new warning and succeeds where it used to fail. `from_tbl_svy()` on a `subbootstrap` or `mrbbootstrap` design now raises a typed error where it used to return a design that failed later |
| `surveytidy` | Reads `@variables$repweights` and `@variables$visible_vars`. | Unchanged key set. A converted design now carries replicate column names where it used to carry none |
| `haven` | `Suggests`. `.strip_labelled_columns()` and `.extract_haven_metadata()` run as they do today. | Unchanged. The written replicate columns are plain doubles and carry no label attributes |

---

## IX. Gaps

**No gap remains inside the two routes.** §III and §IV state one behaviour per
branch, and every branch has a stated trigger. The Fay gap that version 1.0 of
this document recorded is closed: §IV.2 step 4 recovers `rho` from the stored
scale, so a Fay design crosses the export route with the scale it arrived with.
Closing it needed no new key on `survey_replicate` and no change outside
`R/methods-conversion.R`.

### IX.1 Follow-up issues — outside this change

Three facts came out of review. None is a defect in the two routes, and none
is fixed here. Raise each as its own issue.

| Finding | Why it is outside this change |
|---|---|
| `.claude/rules/code-style.md` states that `@data` and `@metadata` "have exported accessors (`survey_data()`, `survey_metadata()`)". `survey_data()` behaves that way. `survey_metadata()` does not: it is the S7 class constructor, and handed a design it aborts with `@variable_labels must be <list>, not <surveycore::survey_replicate>`. A `survey_metadata` object also has no `@variables` property. Read metadata off a design as `@metadata` and its named properties. | It changes a rule file, not the two routes. It matters because a builder following that rule would write a call that cannot work. |
| A replicate design's FPC enters no surveycore number, whether or not it is exported, and nothing says so at construction. `as_survey_replicate()` accepts `fpc` and records it, `print()` and `summary()` report it, and `R/variance-replicate.R` never reads it. A warning at construction would be the honest place to say so. | It changes `R/core-constructors.R`, which §I.2 rules out, and it affects every replicate design rather than the conversion routes. |
| No positivity check exists for replicate weight columns. The `survey_replicate` validator checks each replicate column for numeric only; the positivity check covers the base weight column alone. Negative replicate weights pass silently. Whether they should is a methodology question, since some calibrated replicate files carry them by design. | It changes `R/core-classes.R`, which §I.2 rules out, and the correct behaviour is undecided. |

The `..surveycore_wt..` overwrite in §III.7 is a third candidate. It is
pre-existing behaviour of all the import routes, so it belongs to whichever
issue takes on the manufactured column names, not to this one.

---

## Errata applied at archive time

| # | Location | Correction | Authority |
|---|---|---|---|
| 1 | §V.2 code block, and row CB-2's template in §V.7 | `{qty(n_collisions)}` corrected to `{cli::qty(n_collisions)}`, in three places | `decisions-svydesign-replicate-bridge.md` D17 |

The bare form does not work. Measured by the pull request 3 reviewer: rendered
from the package namespace it throws an untyped `rlib_error_3_0`,
`could not find function "qty"`, so the typed condition never exists and a
test on `surveycore_error_repwt_name_collision` could never pass.
`.claude/rules/r-package-conventions.md` also requires `::` on every external
call. The shipped code in `R/methods-conversion.R` uses the namespaced form,
and pull request 4 corrected row CB-2 in `plans/error-messages.md` to match.

The rendered message is identical either way, at one collision and at three.
