# Spec: `survey_collection` — Multi-Survey Container

**Version:** 1.1 (approved)
**Date:** 2026-04-20
**Status:** Approved — Stage 4 Pass 2 complete; ready for `/implementation-workflow`

---

## Document Purpose

This document is the authoritative specification for `survey_collection`, an S7
container that holds multiple independent `survey_base` objects for comparative
analysis. It adapts the design sketch in
`../surveytidy/plans/future/survey-collection-design.md` into surveycore's spec
conventions, locks in the six open questions from that sketch, and defines the
dispatch mechanism used by `get_*()` functions.

`survey_collection` is the correct alternative to the `bind_rows(design1, design2)`
anti-pattern: designs are never combined, variance estimation is never
re-specified, and each survey is analyzed independently. The collection exists
only to enable "run this analysis across N surveys and bind the results" with a
single function call.

---

## I. Scope

### What This Delivers (surveycore)

| Component | Description |
|---|---|
| `survey_collection` | S7 class, exported. Named list of `survey_base` objects. |
| `as_survey_collection()` | Constructor, exported. Accepts named/unnamed `survey_base` arguments. |
| `add_survey()` | Add a survey to an existing collection, returning a new collection. |
| `remove_survey()` | Remove a survey by name, returning a new collection. |
| `print.survey_collection` | S7 method: compact header + per-survey summary. |
| `[[.survey_collection` | S7 method: returns the underlying `survey_base` by name or index. |
| `length.survey_collection` | S7 method: number of surveys in the collection. |
| `names.survey_collection` | S7 method: survey names. |
| `.dispatch_over_collection()` | Internal helper: runs a `get_*()` function across every survey and binds with an `.id` column. |
| Collection branch in every `get_*()` | One-line dispatch at each function's entry point (§IV). |
| Error classes | 6 new rows in `plans/error-messages.md` (§VI). |

### What This Does NOT Deliver

- **dplyr verbs on `survey_collection`** — `filter`, `select`, `mutate`,
  `group_by` live in surveytidy. Specced separately. This spec only defines the
  class + estimation dispatch so surveytidy can build on it.
- **Pooled estimation** — no combined-design inference. Surveys are always
  analyzed independently and the results are row-bound. Pooling (meta-analytic
  combining of estimates) is explicitly out of scope.
- **`survey_glm()` / `get_anova()` on collections** — v1 dispatches only the
  tibble-returning `get_*()` functions (§IV.1). Extending to `survey_glm()` is
  nontrivial (fit objects don't row-bind cleanly) and is deferred. Both
  `survey_glm()` and `get_anova()` gain an explicit early check:
  if their first argument is a `survey_collection`, they raise
  `surveycore_error_collection_not_supported_by_fn` with a message pointing
  users at the deferral (rather than falling through to the generic
  `surveycore_error_unsupported_class`). See §VI row C12.
- **Collection-of-collections** — nesting is rejected at construction.
- **Automatic de-duplication or alignment of variables across surveys** —
  heterogeneous schemas are allowed. Per-call `.on_missing` controls behavior
  (§III.4).

### Supported Survey Classes

Any `survey_base` subclass is permitted as a collection element:

| Class | Supported |
|---|---|
| `survey_taylor` | Yes |
| `survey_replicate` | Yes |
| `survey_twophase` | Yes |
| `survey_nonprob` | Yes |
| `survey_srs` | Yes |

Mixed-type collections are allowed (Q3 resolution). The collection never
combines designs, so heterogeneous classes cannot produce an invalid state.

### Relationship to Other Functions

| Function | When to use |
|---|---|
| `as_survey_collection(d1, d2, ...)` | Build a collection from existing survey objects |
| `add_survey(coll, name = d)` | Append a survey to an existing collection |
| `remove_survey(coll, "name")` | Drop a survey from a collection |
| `get_freqs(coll, x)` | Run `get_freqs()` on each survey; bind with `.survey` id column |
| `coll[["name"]]` | Pull out a single `survey_base` |

---

## II. File Organization

```
R/
├── core-classes.R                  # + survey_collection class def + validator
├── core-constructors.R             # + as_survey_collection()
├── methods-print.R                 # + print, [[, length, names methods
├── survey-collection.R             # NEW: add_survey, remove_survey,
│                                   #   .dispatch_over_collection()
├── analysis-*.R                    # Each get_*() gets a 3-line collection branch
│                                   #   at its entry point

tests/testthat/
├── test-survey-collection.R        # NEW: all collection-specific tests
│                                   #   (validator, constructor, add/remove,
│                                   #   [[, length, names, heterogeneous
│                                   #   schemas — feature-grouped)
├── test-survey-collection-dispatch.R  # NEW (PR 2): dispatch + oracle tests
└── test-methods-print.R            # + print.survey_collection snapshot
```

`.dispatch_over_collection()` is placed in `R/survey-collection.R` (not
`R/07-utils.R`) because the collection feature group has multiple helpers that
only make sense together.

---

## III. `survey_collection` S7 Class

### 3.1 Class Definition

```r
survey_collection <- S7::new_class(
  "survey_collection",
  properties = list(
    surveys = S7::class_list
  ),
  validator = function(self) {
    if (length(self@surveys) == 0) {
      return("Collection must contain at least one survey.")
    }
    nms <- names(self@surveys)
    if (is.null(nms) || any(nms == "") || any(is.na(nms))) {
      return("All surveys in the collection must be named.")
    }
    if (anyDuplicated(nms)) {
      return(paste0(
        "Collection names must be unique. Duplicates: ",
        paste(unique(nms[duplicated(nms)]), collapse = ", ")
      ))
    }
    not_surveys <- !vapply(
      self@surveys,
      function(x) S7::S7_inherits(x, survey_base),
      logical(1)
    )
    if (any(not_surveys)) {
      return(paste0(
        "All elements must inherit from survey_base. Bad elements: ",
        paste(nms[not_surveys], collapse = ", ")
      ))
    }
    NULL
  }
)
```

**Non-inheritance note:** `survey_collection` deliberately does **not**
inherit from `survey_base`. This is what makes the nested-collection case
fall out of invariant 3 (§3.2) automatically: a `survey_collection` passed
as an element fails the `S7_inherits(x, survey_base)` check. A future
refactor that makes `survey_collection` inherit from `survey_base` would
silently permit collection-of-collections nesting and must be rejected.

### 3.2 `@surveys` Invariants

1. Length ≥ 1.
2. Fully named — no empty, NA, or duplicate names.
3. Every element inherits `survey_base` (i.e., is a `survey_taylor`,
   `survey_replicate`, `survey_twophase`, `survey_nonprob`, or `survey_srs`).
4. No nested `survey_collection` — rejected by invariant 3 because
   `survey_collection` does not inherit `survey_base`.

These are enforced by the S7 validator (Layer 1) — structural errors, tested
with `class=` only, no snapshot.

### 3.3 Constructor Signature

```r
as_survey_collection <- function(...) {
  # Captures both named and unnamed arguments.
  # Unnamed bare-symbol arguments are auto-named from the expression.
  # Unnamed non-symbol arguments (e.g., function calls) error.
}
```

Behavior:

1. Capture arguments with `rlang::enquos(...)`.
2. For each argument:
   - If the caller supplied a name, use it.
   - Else if the argument expression is a bare symbol, use `as_name()` on the
     symbol.
   - Else (unnamed, non-symbol, e.g., `as_survey(df, ...)` passed inline) error
     with `surveycore_error_collection_unnamed_expr`.
3. Repair duplicate names by appending `_1`, `_2`, … in order of appearance
   (see §3.3.1) and emit `surveycore_warning_collection_duplicate_name_repaired`
   listing the rename mapping. The first occurrence of a duplicated name is
   kept as-is; subsequent occurrences are suffixed. If the suffixed name is
   itself already taken, the suffix is incremented until unique.
4. Evaluate each quosure.
5. Call `survey_collection(surveys = list_of_evaluated)`; the S7 validator
   catches remaining invariants.

### 3.3.1 Duplicate-name Repair

Both `as_survey_collection()` and `add_survey()` repair duplicate names
rather than erroring. The algorithm:

```
repair_names(nms):
  seen <- character(0)
  out  <- character(length(nms))
  for i in seq_along(nms):
    nm <- nms[i]
    if nm %in% seen:
      j <- 1
      repeat:
        candidate <- paste0(nm, "_", j)
        if !(candidate %in% seen):  break
        j <- j + 1
      out[i] <- candidate
    else:
      out[i] <- nm
    seen <- c(seen, out[i])
  out
```

Trigger the warning (`surveycore_warning_collection_duplicate_name_repaired`)
only if at least one name was changed. Include the mapping
`original → repaired` in the warning body so the user can trace what
happened.

The S7 validator's duplicate-name check (row C2) becomes a pure **backstop**:
it only fires when someone bypasses the constructors and calls
`survey_collection(surveys = list_with_dupes)` directly.

Example:

```r
# Named — names used as given
as_survey_collection("2017-18" = d_2017, "2019-20" = d_2019)

# Unnamed bare symbols — auto-named
as_survey_collection(d_2017, d_2019)
# equivalent to: as_survey_collection("d_2017" = d_2017, "d_2019" = d_2019)

# Unnamed non-symbol — errors
as_survey_collection(as_survey(df, weights = w))
# surveycore_error_collection_unnamed_expr
```

### 3.4 `.on_missing` Argument Semantics (used by `get_*()` dispatch)

When a `get_*()` function runs over a collection and a survey is missing a
variable the call requires:

| Value | Behavior |
|---|---|
| `"error"` (default) | Error `surveycore_error_collection_missing_var` naming which surveys lack the variable. |
| `"skip"` | Omit those surveys from the bound result. Emit `surveycore_message_collection_skipped_surveys` listing the omissions. The `.id` column lists only surveys that contributed rows. |

No `"drop_cols"` mode (common-variables-only) — that was considered and
rejected: it silently discards columns the user may need later in their
pipeline. Users who want intersection can call `select()` explicitly (surveytidy
layer) before estimation.

`.on_missing` is detected **after** per-survey evaluation raises
`surveycore_error_variable_not_found`. This is a **new surveycore-owned error
class** (added to `plans/error-messages.md` as part of this spec). Every
`get_*()` function in §4.2 must pre-check the tidy-select resolution against
`names(design@data)` and raise `surveycore_error_variable_not_found` with a
wrapped message when a requested variable is absent, rather than letting
tidyselect's native `vctrs_error_subscript_oob` propagate. This gives the
dispatch helper a stable, surveycore-owned hook to `tryCatch` on.

**Scope of "requested variable":** the pre-check covers **every named NSE
argument the function declares** — not only the focal `x`. The table in §4.2
enumerates the NSE arg set per function (`x`, `group`, `numerator`,
`denominator`, `by`, `treats`, `covariates`). A survey is considered missing
the requested variable if *any* of those arguments resolves to a column
absent from `names(design@data)`. Rationale: a survey that cannot supply
every input the function requires cannot produce a row comparable to the
other surveys — better to skip it whole under `.on_missing = "skip"` than
silently drop the group/treatment/covariate structure.

Concrete behaviors:

- `get_means(coll, age, group = region)` with `region` absent in survey 2:
  `.on_missing = "skip"` drops survey 2 from the result; `.on_missing =
  "error"` raises `surveycore_error_collection_missing_var` naming survey 2.
- `get_ratios(coll, num, denom)` with `denom` absent in survey 2: same —
  the missing denominator is a requested variable.
- `get_diffs(coll, y, treats, covariates = c(age, sex))` with `sex` absent
  in survey 2: same — covariates participate in the pre-check.

§7.1.5 must include a test exercising this broader scope (e.g.,
`get_means(coll, y1, group = grp_missing_in_s2, .on_missing = "skip")`).

The dispatch helper catches that specific error class per survey, decides
based on `.on_missing`, and re-raises or skips. Non-missing-variable errors
always propagate.

### 3.5 Print Method

```
A survey_collection with 3 surveys:
  "2017-18": survey_taylor, 9,254 rows, 48 variables
  "2019-20": survey_taylor, 8,704 rows, 48 variables
  "2021-22": survey_taylor, 7,208 rows, 50 variables
```

Formatting rules (locked here — the snapshot test enforces them):

- **Row / variable counts**: `format(nrow(s@data), big.mark = ",")` and
  `format(ncol(s@data), big.mark = ",")`.
- **Class name**: `S7::class_name(s)[1]` (take the first element — leaf class
  name, bare, no `<>` wrapping).
- **Header**: `A survey_collection with {n} survey{?s}:`.
- **Per-survey line**: `  "{name}": {class_name}, {rows} rows, {vars} variables`
  — two-space indent, double quotes around name.
- **Abbreviation for large collections**: when `length(x) <= 20`, print every
  survey. When `length(x) > 20`, print the first 10, then a single line
  `  ... and {length(x) - 13} more`, then the last 3. The header still shows
  the full count.

Snapshot tested via `test-methods-print.R` (one snapshot for a small
collection, one for a collection of length 25 to exercise the abbreviation
branch). Returns `invisible(x)` per `code-style.md §4`.

### 3.6 `[[`, `length`, `names`

```r
S7::method(`[[`, survey_collection) <- function(x, i) x@surveys[[i]]
S7::method(length, survey_collection) <- function(x) length(x@surveys)
S7::method(names, survey_collection) <- function(x) names(x@surveys)
```

`[[` accepts character or integer `i`. Base R list semantics apply:
out-of-bounds **integer** indexing errors (`subscript out of bounds`);
unknown **character** names return `NULL`. The method body
`function(x, i) x@surveys[[i]]` produces this behavior automatically — do
not wrap it to force a uniform `NULL`. Tested in §7.1.1 with both
`expect_null(coll[["nonexistent"]])` and
`expect_error(coll[[99L]])`.

No `[`, no `$`, no `[[<-` in v1 — keep the mutation surface narrow. Mutation
happens through `add_survey()` / `remove_survey()` only.

### 3.7 `add_survey()` and `remove_survey()`

```r
add_survey(x, ...)
remove_survey(x, name)
```

**`add_survey(x, ...)`** — takes a collection `x` and one or more new surveys
passed via `...` with the same naming rules as `as_survey_collection()`
(named, or bare-symbol). Returns a new `survey_collection` with the new
surveys appended. Applies the duplicate-name repair algorithm from §3.3.1
against the combined name vector (existing names + new names) so any
collision between a new name and an existing one is resolved by suffixing
the new name with `_1`, `_2`, etc., emitting
`surveycore_warning_collection_duplicate_name_repaired`. Existing names are
never modified. S7 validator re-runs on the resulting object.

**`remove_survey(x, name)`** — takes a collection and a character vector of
names to drop. Returns a new `survey_collection` without those entries.
Errors `surveycore_error_collection_name_not_found` if any requested name is
absent. If removing would leave zero surveys, the S7 validator catches it and
raises the empty-collection error.

Both functions return visibly (they produce a new object; not setters in the
`invisible(x)` sense).

---

## IV. Dispatch Over Collections

### 4.1 `.dispatch_over_collection()` Helper

```r
#' @keywords internal
#' @noRd
.dispatch_over_collection <- function(
  fn,
  collection,
  ...,
  .id = ".survey",
  .on_missing = c("error", "skip")
) {
  .on_missing <- rlang::arg_match(.on_missing)
  nms <- names(collection@surveys)

  # Per-survey evaluation with missing-variable handling.
  # .id is NOT assigned inside the loop — we first collect raw results so we
  # can run the collision check against un-augmented column names.
  results <- list()
  skipped <- character(0)
  for (nm in nms) {
    r <- tryCatch(
      fn(collection@surveys[[nm]], ...),
      surveycore_error_variable_not_found = function(cnd) {
        if (.on_missing == "skip") {
          skipped <<- c(skipped, nm)
          NULL
        } else {
          cli::cli_abort(
            c(
              "x" = "Survey {.val {nm}} in the collection is missing a required variable.",
              "i" = "Original error: {conditionMessage(cnd)}",
              "v" = "Set {.code .on_missing = \"skip\"} to drop surveys missing the variable."
            ),
            class = "surveycore_error_collection_missing_var",
            parent = cnd
          )
        }
      }
    )
    if (!is.null(r)) {
      results[[nm]] <- r
    }
  }

  if (length(skipped) > 0) {
    cli::cli_inform(
      c("i" = "Skipped {length(skipped)} survey{?s} missing the requested variable: {.val {skipped}}."),
      class = "surveycore_message_collection_skipped_surveys"
    )
  }

  if (length(results) == 0) {
    cli::cli_abort(
      c("x" = "No surveys in the collection contained the requested variable."),
      class = "surveycore_error_collection_all_skipped"
    )
  }

  # .id collision check — run BEFORE any .id assignment so we inspect the
  # analysis function's native column set, not our augmented one.
  first_cols <- names(results[[1]])
  if (.id %in% first_cols) {
    id_name <- .id
    cli::cli_abort(
      c(
        "x" = "{.arg .id} value {.val {id_name}} conflicts with a column produced by the analysis function.",
        "v" = "Pass a different {.arg .id}, e.g. {.code .id = \"wave\"}."
      ),
      class = "surveycore_error_collection_id_collision"
    )
  }

  # Only now attach the .id column to each per-survey result.
  for (nm in names(results)) {
    results[[nm]][[.id]] <- nm
  }

  out <- dplyr::bind_rows(results)

  # Move .id to the front.
  out <- out[, c(.id, setdiff(names(out), .id))]

  # .meta carry-over policy:
  #   1. First-survey .meta is copied to the top-level of attr(out, ".meta")
  #      for backward compatibility with existing downstream consumers.
  #   2. Every survey's .meta is ALSO preserved under
  #      attr(out, ".meta")$per_survey[[name]] so no information is lost.
  #   3. attr(out, ".meta")$collection carries the collection-level metadata:
  #        $surveys        — character vector of survey names contributing rows
  #        $survey_classes — named character vector: S7::class_name() per survey
  #   4. If per-survey .meta entries disagree on value_labels / variable_label /
  #      question_preface for the focal variable(s), emit a
  #      surveycore_warning_collection_meta_divergence warning naming the
  #      divergent variable(s). Users who do not introspect per_survey at
  #      least see the warning.
  first_meta <- attr(results[[1]], ".meta")
  per_survey_meta <- lapply(results, function(r) attr(r, ".meta"))
  collection_meta <- list(
    surveys = names(results),
    survey_classes = vapply(
      names(results),
      function(nm) S7::class_name(collection@surveys[[nm]])[1],
      character(1)
    )
  )
  new_meta <- c(
    first_meta,
    list(
      per_survey = per_survey_meta,
      collection = collection_meta
    )
  )
  attr(out, ".meta") <- new_meta

  .warn_on_meta_divergence(per_survey_meta)   # see §4.1.1

  class(out) <- class(results[[1]])
  out
}
```

Notes:

- The `tryCatch` classed on `surveycore_error_variable_not_found` — a new
  surveycore-owned error class added by this spec (see §VI row C10). Every
  `get_*()` listed in §4.2 gains a pre-check after its tidy-select step that
  raises this class when a requested variable is absent from
  `names(design@data)`, wrapping the underlying `vctrs_error_subscript_oob`
  as `parent`. This avoids coupling the dispatch helper to vctrs' internal
  error class.
- `.meta` carry-over preserves per-survey metadata under
  `attr(out, ".meta")$per_survey[[name]]` so downstream consumers (`clean()`,
  `gt()` helpers) can retrieve the correct labels for each survey's rows.
  The first survey's `.meta` is still copied to the top level for backward
  compatibility. See `.warn_on_meta_divergence()` below for the divergence
  warning.

### 4.1.1 `.warn_on_meta_divergence()` Helper

```r
#' @keywords internal
#' @noRd
.warn_on_meta_divergence <- function(per_survey_meta) {
  # Compare the same nested key across surveys. Keys inspected:
  #   $group$<var>$value_labels, $group$<var>$variable_label,
  #   $group$<var>$question_preface,
  #   $x$<var>$value_labels,     $x$<var>$variable_label,
  #   $x$<var>$question_preface
  # For each (slot, var, field) triple, if any two surveys' values differ
  # (compared with identical()), record the variable name.
  # Emit one warning listing all divergent variables.
  #
  # If per_survey_meta has length 1 or there is no divergence, return
  # invisibly.

  divergent_vars <- character(0)   # populated per the comparison above

  if (length(divergent_vars) == 0) {
    return(invisible(NULL))
  }

  cli::cli_warn(
    c(
      "!" = "Per-survey metadata diverges for {length(divergent_vars)} variable{?s}: {.field {divergent_vars}}.",
      "i" = "The top-level {.code .meta} reflects only the first survey. Per-survey metadata is preserved under {.code attr(result, \".meta\")$per_survey}.",
      "i" = "Downstream helpers (e.g., {.fn clean}, {.fn gt}) should consult {.code $per_survey} for accurate per-row labeling."
    ),
    class = "surveycore_warning_collection_meta_divergence"
  )
}
```

Divergence is compared with `identical()`, which is strict: differing
attribute orders or name-only-vs-labelled vectors both count as divergent.
Users are expected to pre-align labels (via `set_val_labels()` etc.) before
building a collection if they want zero-warning output.

**Absence-vs-presence policy:** if survey A has a metadata key populated and
survey B does not have that key at all (e.g., `$x$age$value_labels` present
in A, absent in B), that counts as divergence. `identical(value, NULL)` is
`FALSE`, which is the intended behavior — users who add labels to a later
wave should be told that earlier waves are not similarly labelled.

**Closed set of fields checked.** The helper inspects exactly these
`(slot, var, field)` triples, where `slot ∈ {group, x}`, `var` is every
variable-name key appearing under either slot across any survey, and
`field` is one of:

- `value_labels`
- `variable_label`
- `question_preface`

Other `.meta` keys (e.g., `variable_note`, user-added fields) are **not**
compared by this helper. If a future change to the `.meta` structure adds a
new correctness-critical field, the helper must be updated explicitly —
divergence scope is closed by design, not open-ended. This is documented in
a roxygen `@details` block on the helper.
- `.meta` carry-over: the collection result inherits the first survey's `.meta`
  nested shape. A new top-level key `.meta$collection = list(surveys = nms)`
  is added so downstream consumers (e.g., clean/print/gt helpers) can tell they
  came from a collection.
- `dplyr::bind_rows()` handles column-order heterogeneity across surveys; any
  column present in only some surveys gets `NA` for missing rows. This is the
  documented "heterogeneous schemas are allowed" behavior from §III.4.

### 4.2 Per-Function Dispatch Branch

Every `get_*()` function gains a 3-line branch at the top. The first argument
keeps whatever name the function already uses (`design` for every current
`get_*()`); only the branch is added:

```r
get_freqs <- function(design, x, ..., group, .id = ".survey", .on_missing = "error") {
  if (S7::S7_inherits(design, survey_collection)) {
    return(.dispatch_over_collection(
      get_freqs, design,
      x = {{ x }}, group = {{ group }}, ...,
      .id = .id, .on_missing = .on_missing
    ))
  }
  # ... existing implementation unchanged ...
}
```

A second example for `get_ratios()` (which has three NSE arguments):

```r
get_ratios <- function(design, numerator, denominator, ..., group,
                       .id = ".survey", .on_missing = "error") {
  if (S7::S7_inherits(design, survey_collection)) {
    return(.dispatch_over_collection(
      get_ratios, design,
      numerator = {{ numerator }},
      denominator = {{ denominator }},
      group = {{ group }},
      ...,
      .id = .id, .on_missing = .on_missing
    ))
  }
  # ... existing implementation unchanged ...
}
```

Implementation notes for the branch:

- The `design` argument is the S7 dispatch target — `S7_inherits(design, ...)`.
- **Every named NSE formal declared by the function must be forwarded with
  `{{ arg }}` in the dispatch call.** Relying on `...` is insufficient:
  named formals (`group`, `numerator`, `denominator`, `by`, `treats`,
  `covariates`) are bound to the function's own parameter name and are
  NOT present in `...`. A literal call like `get_means(coll, y1, group = sex)`
  binds `group = sex` inside `get_means`, and without explicit
  `group = {{ group }}` forwarding it would be silently dropped when calling
  the helper — every per-survey call would run with `group = NULL`,
  producing wrong results with no error. The oracle tests in §7.1.4
  exercise each function with its NSE args populated so a dropped-arg
  regression fails immediately.
- The complete set of NSE args each `get_*()` must forward:

  | Function | NSE args to forward via `{{ }}` |
  |---|---|
  | `get_freqs()` | `x`, `group` |
  | `get_means()` | `x`, `group` |
  | `get_totals()` | `x`, `group` |
  | `get_quantiles()` | `x`, `group` |
  | `get_ratios()` | `numerator`, `denominator`, `group` |
  | `get_corr()` | `x`, `group` |
  | `get_diffs()` | `x`, `treats`, `group`, `covariates` |
  | `get_t_test()` | `x`, `by`, `group` |
  | `get_pairwise()` | `x`, `by`, `group` |

- `.dispatch_over_collection()` receives the collection as its second
  positional argument (named `collection` inside the helper) and passes
  each `survey_base` through as the first argument of `fn()` — which means
  `fn()`'s first argument name is irrelevant: `fn(collection@surveys[[nm]], ...)`
  lines up positionally.

Functions receiving the branch in v1:

- `get_freqs()`
- `get_means()`
- `get_totals()`
- `get_quantiles()`
- `get_ratios()`
- `get_corr()`
- `get_diffs()`
- `get_t_test()`
- `get_pairwise()`

Deferred (see §I "What This Does NOT Deliver"): `survey_glm()`, `get_anova()`.

### 4.3 `.id` and `.on_missing` Argument Addition

These two arguments are added to every function in §4.2. Argument order:
they are **named-only control scalars** and go immediately **after** `...`,
following the tidyverse convention that R uses to force named supply (once
`...` appears in the formals, subsequent parameters must be matched by name).
This matches the existing post-`...` placement of `group`, `names_to`,
`values_to`, `variance`, etc. in the current `get_*()` signatures.

`code-style.md §4` describes the default order for ordinary optional scalars
(pre-`...`). A companion carve-out will be added to that rule: **named-only
control args (those callers must supply by name) go after `...`**. The
`.id` / `.on_missing` placement in this spec is the first application of
that carve-out.

Defaults: `.id = ".survey"`, `.on_missing = "error"`. When the function is
called on a single `survey_base` (not a `survey_collection`), both arguments
are **silently ignored**, even if the caller passes a non-default value. The
result shape for single-design calls is unchanged by this spec. The roxygen
`@param` block for each argument must say explicitly: *"Only used when the
first argument is a `survey_collection`; silently ignored otherwise."*

### 4.4 Why a Wrapper Instead of Per-Function Implementations

DRY (engineering-preferences.md §1). The collection loop, `.id` handling,
column ordering, `.meta` carry-over, missing-variable handling, and id
collision check all live in one place. Bug fixes land once. New `get_*()`
functions opt in with a short branch — three lines of control flow plus
one `{{ arg }}` forwarding line per declared NSE argument (see §4.2 table).

---

## V. Edge Cases

| # | Condition | Behavior |
|---|---|---|
| 1 | Empty collection (0 surveys) | S7 validator error: `surveycore_error_collection_empty` |
| 2 | Duplicate survey names in constructor / `add_survey()` | Auto-repaired to `name_1`, `name_2`, …; warning `surveycore_warning_collection_duplicate_name_repaired`. Validator error `surveycore_error_collection_duplicate_name` only via direct `survey_collection(surveys = ...)` bypass. |
| 3 | Unnamed argument that is not a bare symbol | Constructor error: `surveycore_error_collection_unnamed_expr` |
| 4 | Non-`survey_base` element | S7 validator error: `surveycore_error_collection_bad_element` |
| 5 | Collection containing a collection | Caught by invariant 4 (rejected by invariant 3) — same class as #4 |
| 6 | `get_*()` called, one survey missing variable, `.on_missing = "error"` | Error `surveycore_error_collection_missing_var` naming the survey |
| 7 | `get_*()` called, all surveys missing variable, `.on_missing = "skip"` | Error `surveycore_error_collection_all_skipped` |
| 8 | `.id` name collides with a column the analysis function produces | Error `surveycore_error_collection_id_collision` |
| 9 | Heterogeneous value labels / variable label / question preface across surveys for the same variable | `bind_rows()` union on data columns; per-survey `.meta` preserved under `attr(out, ".meta")$per_survey`. Emits `surveycore_warning_collection_meta_divergence` naming divergent variables (§4.1.1). |
| 10 | `remove_survey()` on the last remaining survey | Validator catches the empty collection → `surveycore_error_collection_empty` |
| 11 | `add_survey()` with a name that already exists | Auto-repaired via `_N` suffix; warning `surveycore_warning_collection_duplicate_name_repaired` |
| 12 | `remove_survey()` with a name that doesn't exist | Error `surveycore_error_collection_name_not_found` |
| 13 | Mixed design types in one collection | Allowed (Q3 resolution). No warning. |

---

## VI. Error Message Table (additions to `plans/error-messages.md`)

| # | Function | Condition | Level | Error Class | cli Message Template |
|---|---|---|---|---|---|
| C1 | S7 validator | Empty collection | ERROR | `surveycore_error_collection_empty` | `"Collection must contain at least one survey."` (validator text; not CLI-formatted) |
| C2 | S7 validator (backstop only) | Duplicate names (via direct `survey_collection(surveys = ...)` bypass) | ERROR | `surveycore_error_collection_duplicate_name` | `"Collection names must be unique. Duplicates: {.field {dupes}}"` |
| C2a | `as_survey_collection()` / `add_survey()` | Duplicate names repaired via `_N` suffix | WARNING | `surveycore_warning_collection_duplicate_name_repaired` | `"Collection names must be unique; repaired {length(renames)} name{?s} by suffixing: {.code {fmt_mapping}}."` |
| C3 | `as_survey_collection()` | Unnamed non-symbol argument | ERROR | `surveycore_error_collection_unnamed_expr` | `"All arguments must be named or passed as bare symbols. Position {.val {i}} is an unnamed expression."` |
| C4 | S7 validator | Non-`survey_base` element | ERROR | `surveycore_error_collection_bad_element` | `"All elements must inherit from {.cls survey_base}. Bad: {.field {bad}}"` |
| C5 | `.dispatch_over_collection()` | Survey missing variable, `.on_missing = "error"` | ERROR | `surveycore_error_collection_missing_var` | `"Survey {.val {nm}} is missing a required variable. Set {.code .on_missing = \"skip\"} to drop surveys missing the variable."` |
| C6 | `.dispatch_over_collection()` | All surveys skipped | ERROR | `surveycore_error_collection_all_skipped` | `"No surveys in the collection contained the requested variable."` |
| C7 | `.dispatch_over_collection()` | `.id` collides with analysis-function column | ERROR | `surveycore_error_collection_id_collision` | `"{.arg .id} value {.val {id_name}} conflicts with a column produced by the analysis function."` (bind `id_name <- .id` locally before the `cli_abort()` call for readability) |
| C8 | `remove_survey()` | Name not in collection | ERROR | `surveycore_error_collection_name_not_found` | `"Survey {.val {missing}} not found in collection. Available: {.val {have}}."` |
| C9 | `.dispatch_over_collection()` | Informational: surveys skipped | MESSAGE | `surveycore_message_collection_skipped_surveys` | `"Skipped {length(skipped)} survey{?s} missing the requested variable: {.val {skipped}}."` |
| C10 | Every `get_*()` in §4.2 | Tidy-selected variable(s) not present in `@data` | ERROR | `surveycore_error_variable_not_found` | `"Variable{?s} {.val {missing}} not found in survey data. Available: {.val {have}}."` (pre-check runs before tidyselect; `parent = NULL`) |
| C11 | `.warn_on_meta_divergence()` | Per-survey `.meta` value_labels / variable_label / question_preface differ across surveys for the same variable | WARNING | `surveycore_warning_collection_meta_divergence` | `"Per-survey metadata diverges for {length(vars)} variable{?s}: {.field {vars}}. Per-survey metadata is preserved under {.code attr(result, \".meta\")$per_survey}."` |
| C12 | `survey_glm()` / `get_anova()` | Called on a `survey_collection` | ERROR | `surveycore_error_collection_not_supported_by_fn` | `"{.fn {fn_name}} does not yet support {.cls survey_collection} inputs. Run {.fn {fn_name}} on each survey individually, or see {.topic survey_collection} for the current dispatch coverage."` |
| C13 | `.dispatch_over_collection()` | `.id` is not a single non-empty, non-NA character string | ERROR | `surveycore_error_collection_invalid_id` | `"{.arg .id} must be a single non-empty, non-NA character string. Got {.cls {class(.id)[1]}} of length {.val {length(.id)}}."` |
| C14 | `.dispatch_over_collection()` | `dplyr::bind_rows()` fails because per-survey results have incompatible types for a shared column | ERROR | `surveycore_error_collection_bind_type_mismatch` | `"Cannot combine per-survey results: column type mismatch. Each survey must produce compatible types for shared columns. Original error: {conditionMessage(cnd)}"` (wraps the underlying `vctrs` error as `parent`) |

All twelve rows must land in `plans/error-messages.md` before implementation
starts. Row C10 is required by the `.on_missing` contract in §III.4 / §IV.1
and is added to every `get_*()` listed in §4.2. Row C11 is emitted by
`.warn_on_meta_divergence()` (§4.1.1) when per-survey metadata disagrees.
Row C12 is emitted by the collection guards in `survey_glm()` and
`get_anova()` (§I "What This Does NOT Deliver").

---

## VII. Test Plan

### 7.1 File: `tests/testthat/test-survey-collection.R`

Sections:

1. **Happy paths**
   - `as_survey_collection()` with explicit names
   - `as_survey_collection()` with bare-symbol auto-naming
   - Mixed: some named, some bare
   - Mixed design types (taylor + replicate + srs)
   - `length()`, `names()`, `[[]` ergonomics
   - `[[`: `expect_null(coll[["nonexistent"]])` (character OOB); `expect_error(coll[[99L]])` (integer OOB — base R list semantics)
   - `add_survey()` appends correctly
   - `remove_survey()` removes correctly
2. **S7 validator errors (Layer 1 — `class=` only)**
   - Empty collection
   - Unnamed element (passed directly into `survey_collection(surveys = ...)` bypassing the constructor)
   - Duplicate names
   - Non-`survey_base` element (e.g., a `data.frame`)
   - Nested `survey_collection` (rejected by the `survey_base` check)
3. **Constructor errors (Layer 3 — dual pattern: `class=` + snapshot)**
   - Unnamed non-symbol argument
4. **Dispatch happy paths**
   - `get_freqs()` over a 3-survey homogeneous collection → bound result with `.survey` first
   - `get_means()` same pattern
   - `get_totals()` same pattern
   - `get_quantiles()`, `get_ratios()`, `get_corr()`, `get_diffs()`, `get_t_test()`, `get_pairwise()` — one test each confirming `.survey` column and row counts
   - Custom `.id` name: `get_freqs(coll, x, .id = "wave")` → `wave` column
   - `.meta$collection$surveys` populated
   - `.meta$collection$survey_classes` populated
   - `.meta$per_survey[[name]]` preserves each survey's meta
   - `.id` / `.on_missing` arguments are silently ignored for single-`survey_base`
     calls (result shape unchanged)
   - **Dispatch-identity oracle tests**: for each of `get_means()`,
     `get_totals()`, `get_freqs()`, assert that
     `get_fn(coll, ...)` equals `dplyr::bind_rows(lapply(names(coll), function(nm) get_fn(coll[[nm]], ...)), .id = ".survey")` up to column order
     and `tolerance = 1e-12` on numeric columns. This guards against the
     dispatch helper silently mutating per-survey results.
   - **NSE-argument forwarding oracle tests**: for each `get_*()` in §4.2,
     include an oracle test that exercises **every** named NSE arg the
     function declares (e.g., `get_means(coll, y1, group = grp)`,
     `get_ratios(coll, num, denom, group = grp)`,
     `get_diffs(coll, y, treats = t, group = g, covariates = c(age, sex))`).
     A dropped-`{{ }}`-forwarding regression would cause the per-survey
     branch to run with the NSE arg defaulted and fail the oracle
     comparison immediately.
5. **Dispatch errors (dual pattern — `class=` + snapshot)**
   - Missing variable, default `.on_missing = "error"` →
     `surveycore_error_collection_missing_var`
   - All surveys missing variable, `.on_missing = "skip"` →
     `surveycore_error_collection_all_skipped`
   - `.id` collision with an analysis-function output column:
     `get_means(coll, y1, .id = "mean")` →
     `surveycore_error_collection_id_collision`; snapshot the CLI message
   - `survey_glm()` called on a `survey_collection` →
     `surveycore_error_collection_not_supported_by_fn`
   - `get_anova()` called on a `survey_collection` →
     `surveycore_error_collection_not_supported_by_fn`
   - Every `get_*()` in §4.2 raises
     `surveycore_error_variable_not_found` when its tidy-selected variable
     is absent (one representative test per function family; dual pattern
     for `get_means()`, `class=` only for the rest)
   - **NSE-arg scope test**: `get_means(coll, y1, group = grp_missing_in_s2, .on_missing = "skip")`
     skips survey 2 — confirms the `.on_missing` pre-check scope covers
     every named NSE argument, not only the focal `x` (§III.4)
6. **Dispatch messages**
   - `.on_missing = "skip"` emits `surveycore_message_collection_skipped_surveys`
7. **Length-1 collection (edge)**
   - `as_survey_collection("d" = d1)` → valid length-1 collection
   - `get_means()` over length-1 collection produces a tibble with one
     `.survey` value and the same row count as direct per-survey call
   - `.on_missing = "skip"` with the single survey missing the variable
     triggers `surveycore_error_collection_all_skipped`
8. **Heterogeneous schemas**
   - Two surveys with different column sets; `get_freqs()` on a shared var works; `bind_rows()` `NA`-fills extras when a result column is absent
9. **`.meta` carry-over and divergence**
   - Happy path: all surveys share identical value_labels / variable_label /
     question_preface → `attr(out, ".meta")$per_survey[[nm]]` populated for
     every survey; top-level `.meta` equals first survey's; no warning
   - Divergence path: two surveys disagree on `value_labels` for the focal
     var → `surveycore_warning_collection_meta_divergence` warning (dual
     pattern — `class=` + snapshot); `attr(out, ".meta")$per_survey` still
     preserves each survey's meta
   - `attr(out, ".meta")$collection$survey_classes` records the S7 class
     name for each constituent survey
10. **`add_survey()` / `remove_survey()` duplicate repair + errors (dual pattern)**
    - `add_survey()` with duplicate name → auto-repair via `_N` suffix; warning
      `surveycore_warning_collection_duplicate_name_repaired` (dual pattern)
    - `as_survey_collection()` with duplicate names across multiple args →
      repair + warning (dual pattern)
    - `remove_survey()` with unknown name
    - `remove_survey()` emptying the collection → validator error
    - Direct `survey_collection(surveys = list_with_dupes)` bypass →
      validator error `surveycore_error_collection_duplicate_name` (Layer 1,
      `class=` only)
11. **Print** — snapshot test in `test-methods-print.R`

### 7.2 Coverage Target

98%+ line coverage on `R/survey-collection.R` and the added branches in each
`get_*()`. The per-function branch is three lines and is exercised by §7.1
Section 4 tests — one per function.

### 7.2.1 `test_collection_invariants()` Helper

Mirroring `test_invariants()` (testing-surveycore.md), a new helper
`test_collection_invariants(coll)` is added to
`tests/testthat/helper-test-data.R` and must be called as the **first
assertion** in every `test_that()` block that builds a `survey_collection`
via `as_survey_collection()` or `add_survey()`.

```r
test_collection_invariants <- function(coll) {
  # Invariant 1: inherits survey_collection
  expect_true(S7::S7_inherits(coll, survey_collection))
  # Invariant 2: @surveys is a list of length >= 1
  expect_true(is.list(coll@surveys))
  expect_gte(length(coll@surveys), 1L)
  # Invariant 3: fully named, no empty/NA/duplicate names
  nms <- names(coll@surveys)
  expect_false(is.null(nms))
  expect_false(any(nms == "" | is.na(nms)))
  expect_equal(anyDuplicated(nms), 0L)
  # Invariant 4: every element inherits survey_base
  for (s in coll@surveys) {
    expect_true(S7::S7_inherits(s, survey_base))
  }
  # Invariant 5: deliberately NOT inheriting survey_base
  expect_false(S7::S7_inherits(coll, survey_base))
}
```

### 7.3 Synthetic Data

Use `make_survey_data(seed = ...)` with varying `seed` to build 2–3 distinct
surveys. For heterogeneous-schema tests, drop a column from one of the
resulting data frames before wrapping in `as_survey()`.

---

## VIII. Documentation

### 8.1 New Roxygen Pages

- `as_survey_collection()` — constructor, `@family collections`
- `add_survey()`, `remove_survey()` — `@family collections`
- `survey_collection` class — `@family collections`, documents properties

### 8.2 Existing Page Updates

Every `get_*()` function in §4.2 gains:

- A new `@param .id` describing the identifier column
- A new `@param .on_missing` describing the two modes
- A new `@examples` block showing collection dispatch
- `@seealso [as_survey_collection()]` (unless the function is already one of
  the three constructors that carry `@seealso` per `surveycore-conventions.md §1`)

### 8.3 Vignette

Defer. A `vignette("comparing-surveys")` is natural but is out of scope for
the v1 ship of this feature. Add to `plans/future/` as a follow-up.

---

## IX. Implementation Order

1. Error classes — add every row in §VI to `plans/error-messages.md`.
2. S7 class — `survey_collection` in `R/00-s7-classes.R` with validator.
3. Constructor — `as_survey_collection()` in `R/03-constructors.R`.
4. Methods — `print`, `[[`, `length`, `names` in `R/04-methods-print.R`.
5. Mutation helpers — `add_survey()`, `remove_survey()` in
   `R/survey-collection.R`.
6. Dispatch helper — `.dispatch_over_collection()` in
   `R/survey-collection.R`.
7. Per-function branches — **one PR covering all nine `get_*()` functions**
   in §4.2, landing the dispatch branch (three lines + one `{{ }}` per NSE
   arg) and the `.id` / `.on_missing` params together. Rationale: the change
   is mechanical (correct-or-not) and a single PR lets the reviewer inspect
   the template once and scan the nine applications for consistency.
   Nine separate PRs would be heavy process overhead for ~27 lines of
   code.
8. Tests — `test-survey-collection.R` grown alongside each step; oracle
   comparisons not needed (the dispatch loop is pure R, not numerical).
9. Docs — roxygen updates, `devtools::document()`.

Locked decisions (previously open questions, closed in Stage 4):

- **`add_survey()` does NOT accept a `survey_collection`.** Users who want
  to concatenate collections pass surveys via
  `as_survey_collection(!!!as.list(coll1@surveys), !!!as.list(coll2@surveys))`.
  Rationale: keeps the `add_survey()` contract single-purpose; concatenation
  of collections is rare enough that a splice is acceptable.
- **`.meta$collection$survey_classes` is populated** with a named character
  vector recording `S7::class_name()[1]` per constituent survey (see §4.1).
- **`print()` abbreviates for `length(x) > 20`** (see §3.5): full list for
  ≤20; first 10 + `… and N more` + last 3 above that.

---

## X. Out of Scope (Explicit Defers)

| Item | Reason |
|---|---|
| dplyr verbs on `survey_collection` | surveytidy package concern |
| Collection support in `survey_glm()` / `get_anova()` | Fit objects don't row-bind cleanly; needs separate design |
| Pooled / meta-analytic estimation across surveys | Different statistical contract; out of scope for a container |
| `as.list()` / `as_tibble()` round-trips | Defer until a concrete ask |
| CRUD beyond `add_survey()` / `remove_survey()` (e.g., `rename_survey()`) | Rebuild from scratch covers it; add if demand materializes |
| Vignette | Land after the feature ships |

---

## Summary

`survey_collection` is a lightweight, named, validated S7 container over one
or more `survey_base` objects. The container never modifies the surveys it
holds. Estimation functions gain a three-line dispatch branch that delegates
to `.dispatch_over_collection()`, which handles per-survey evaluation,
`.on_missing` policy, `.id` column placement, and `.meta` carry-over. Mixed
design types are allowed; heterogeneous schemas are allowed with strict
default error behavior and an explicit `"skip"` escape hatch. Mutation is
restricted to `add_survey()` / `remove_survey()`; direct `@surveys`
manipulation is not supported. dplyr verbs and `survey_glm()` collection
support are explicitly deferred.
