# Spec: `prettytable()`

**Version:** 0.2 (draft)
**Date:** 2026-04-20
**Status:** Draft — ready for spec review

---

## Document Purpose

This document specifies `prettytable()`, a rendering helper that converts a
surveycore result tibble (e.g., `survey_freqs`) into a publication-ready
`tinytable` table. It is the surveycore analog of `adlgraphs::prettytable()`,
ported to surveycore's `.meta` conventions and proportion scaling (0–1).

`prettytable()` is a **presentation layer**, not an analysis function.
It does not recompute estimates — it reshapes, labels, and styles an
existing `survey_result`.

### Why `tinytable`

- **Zero third-party dependencies** — matches surveycore's lean-imports
  philosophy. `tinytable`'s only `Imports` entry is `methods` (base R).
- **Seven output formats** (HTML, LaTeX, Word, PDF, PNG, Markdown, Typst)
  vs. `gt`'s three (HTML, LaTeX, RTF). Survey reports frequently target
  Word and Typst.
- **Minimal semantic model** — the surveycore result tibbles already carry
  all needed structure in `.meta`; we don't need `gt`'s stub/row-group
  scaffolding.

---

## I. Scope

### What This Delivers

| Component | Description |
|---|---|
| `prettytable()` | Exported S3 generic dispatching on `survey_result` subclasses |
| `prettytable.survey_freqs()` | First concrete method — grouped + ungrouped |
| `.pt_make_percent()` | Internal: 0–1 proportion → `"xx%"` display string |
| `.pt_sort_cols()` | Internal: sort pivoted spanner columns by factor order |
| `.pt_build_spanners()` | Internal: split `group_value_<pct\|n>` column names into a `tinytable::group_tt()` spec (spanner label → column indices) |
| `.pt_char_to_factor()` | Internal: preserve factor order through pivot |

### What This Does NOT Deliver (v1)

- `prettytable.survey_means()`, `.survey_totals()`, `.survey_corr()`,
  `.survey_diffs()`, `.survey_quantiles()`, `.survey_ratios()`,
  `.survey_anova()`, `.survey_glm_fit()` — deferred to follow-up PRs.
  v1 ships the generic plus the freqs method so the API shape is fixed
  before the other methods are added.
- Multi-variable `get_freqs()` output (`name` / `value` stacked format).
  v1 errors with a typed class; a stacked renderer is a v2 extension.
- Variance columns in the rendered table. v1 renders only `pct` and `n`
  for freqs, matching the adlgraphs reference behavior. Surfacing
  `ci_low`/`ci_high`/`se` is a v2 extension.
- Theming, color customization, or a `style =` argument. The returned
  `tinytable` object can be further customized by the caller via
  `style_tt()`, `format_tt()`, and `theme_tt()`.

### Dispatch Choice: S3

`prettytable()` dispatches on result classes (`survey_freqs`, `survey_means`,
…), which CLAUDE.md documents as **S3 built on tibble**. This parallels
the existing `meta()` generic exactly:

```r
meta <- function(x, ...) UseMethod("meta")
meta.survey_result <- function(x, ...) attr(x, ".meta")
```

The code-style rule requiring plain-function + `S7::S7_inherits()` applies
to generics that dispatch on the **S7 design classes** — not on S3 result
tibbles.

---

## II. File Organization

```
R/
├── prettytable.R                # Generic + survey_freqs method + helpers

tests/testthat/
├── test-prettytable.R           # snapshot tests for gt output, error paths
```

No additions to `R/analysis-helpers.R` — `prettytable()` is downstream of
`.make_result_tibble()` and reads existing `.meta` only.

---

## III. `prettytable()` Specification

### 3.1 Generic signature

```r
prettytable <- function(x, ...) {
  UseMethod("prettytable")
}
```

### 3.2 `prettytable.survey_freqs()` signature

```r
prettytable.survey_freqs <- function(
  x,
  ...,
  design      = NULL,
  show_genpop = FALSE,
  decimals    = NULL
)
```

| Arg | Type | Purpose |
|---|---|---|
| `x` | `survey_freqs` | Result from `get_freqs()` |
| `design` | survey design or `NULL` | Required only when `show_genpop = TRUE` |
| `show_genpop` | `logical(1)` | Append a general-population column block (grouped results only) |
| `decimals` | `integer(1)` or `NULL` | Percent-display decimals; `NULL` (default) rounds to whole numbers |

Argument order follows `code-style.md §4`: `x` first, `...` before named-only
control args (`design`, `show_genpop`, `decimals` are all keyword-only).

### 3.3 Behavior

**Reads** (`meta(x)`):

- `m$x[[1L]]$variable_label` — table title; falls back to variable name
  when `NULL` or `""`.
- `names(m$x)[[1L]]` — focal column name in `x`.
- `names(m$group)` — grouping column names (empty when ungrouped).
- `m$group[[i]]$variable_label` — spanner footnote per group (skipped
  when `NA`/`NULL`).

**Build order — produces a `tinytable` object:**

1. Reshape the tibble. Ungrouped results keep three columns: the focal
   variable, `pct`, `n`. Grouped results pivot wide on `group_names` so
   each group level contributes a `<level>_pct` / `<level>_n` column pair.
2. Format the body columns before passing to `tt()`:
   - `pct` columns → `"xx%"` string via `.pt_make_percent(decimals)`
   - `n` columns → `formatC(round(n), big.mark = ",")`
   The focal-variable column becomes the leftmost column of the
   `tinytable` (tinytable has no "stub" concept — the leftmost column
   simply renders as row labels, optionally bolded via `style_tt()`).
3. Rename columns for display:
   - Ungrouped: `pct` → `"Percent"`, `n` → `"N"`
   - Grouped: leaf cells become `"Percent"` / `"N"` (spanner carries
     the level name; see step 5)
   - Focal-variable column: use `m$x[[1L]]$variable_label` when present,
     else the bare variable name
4. Build the `tinytable` with `tt(data, caption = <title>, notes = <list>)`:
   - Title (caption): `Frequencies for "<variable_label>"`
   - `notes`: one entry per grouping variable, keyed by the spanner
     label so `tinytable` renders it as a bound footnote. Entries with
     `NA` / `NULL` labels are skipped.
5. Grouped only — spanner headers via `group_tt(j = ...)`:
   `.pt_build_spanners()` parses the pivoted column names
   (`<level>_pct`, `<level>_n`) into a named list mapping each group
   level to the two column indices it covers, preserving factor order
   via `.pt_sort_cols()`.
6. Cell styling via `style_tt()`:
   - All cells: `line = "tblr"` with `line_color = "black"` for full
     gridlines
   - Spanner row: `line = "b"` with `line_color = "#D3D3D3"`
   - Leftmost column: `bold = TRUE` for row labels
7. Formatting via `format_tt()` is avoided for `pct` / `n` because we
   pre-format as character strings in step 2 — this guarantees
   consistent "xx%" rendering across HTML, LaTeX, Word, Typst, etc.,
   without relying on backend-specific number formatters.

### 3.4 `show_genpop = TRUE` path (grouped only)

Recomputes the ungrouped frequency table via `get_freqs(design, <var>)`
and appends a trailing `genpop_pct` / `genpop_n` column pair. The spanner
spec from `.pt_build_spanners()` adds a final `"General Population"`
spanner covering those two columns. Row alignment uses `merge()` on the
focal variable. The `notes` list omits an entry for this spanner (no
footnote needed).

Errors (`surveycore_error_prettytable_genpop_no_design`) when
`show_genpop = TRUE` and `design` is `NULL`.

### 3.5 Error paths

| Condition | Class |
|---|---|
| Multi-var freqs (`name` + `value` present) | `surveycore_error_prettytable_multivar_unsupported` |
| `show_genpop = TRUE` and `design = NULL` | `surveycore_error_prettytable_genpop_no_design` |
| `decimals` not integer-ish or `NULL` | `surveycore_error_decimals_invalid` (reuse existing) |

All errors follow the `"x"` / `"i"` / `"v"` bullet structure
(`code-style.md §3`). Add new classes to `plans/error-messages.md` before
implementing.

### 3.6 Return value

A `tinytable` object (visible) — class `"tinytable"`. No `.meta` mutation;
input `x` is read-only. Callers can compose further styling via
`style_tt()` / `format_tt()` / `theme_tt()` or render with
`print(x, output = "html" | "latex" | "typst" | "markdown")`.

---

## IV. Dependencies

Add to `DESCRIPTION`:

```
Imports:
    tinytable (>= 0.4.0),
    tidyr (>= 1.3.0),
    tidyselect (>= 1.2.0)
```

`tinytable` is safe to place in `Imports`: it has zero third-party R
dependencies (its only `Imports` entry is `methods`, a base R package).
Adding it does not enlarge surveycore's transitive dependency footprint
in any meaningful way, and `prettytable()` is a core rendering path that
should Just Work without the user installing an optional package.

`tidyr` and `tidyselect` are already in `Imports` (verify in
`DESCRIPTION` during implementation).

Minimum version: pin to the release that supports the `notes =`
argument and `group_tt(j = ...)` spanner API used in §III.3.
`tinytable >= 0.4.0` covers these; confirm the exact floor when
implementing.

---

## V. Test Plan

### Happy paths

- Ungrouped single-var freqs → returns a `tinytable` with expected
  caption, leftmost-column row labels, and `Percent` / `N` body columns.
- Grouped freqs (1 group) → pivot shape correct; one spanner level
  via `group_tt()`; one entry in `notes`.
- Grouped freqs (2 groups) → two spanner levels; two `notes` entries;
  column order follows factor levels of each group.
- `show_genpop = TRUE` → appends a trailing `General Population`
  spanner block; `notes` excludes the genpop spanner.
- `decimals = 1` → body shows `"12.3%"` style.
- `decimals = NULL` → body shows `"12%"` style.

### Error paths

- Multi-var freqs → `surveycore_error_prettytable_multivar_unsupported`.
- `show_genpop = TRUE` with `design = NULL` →
  `surveycore_error_prettytable_genpop_no_design`.

### Edge cases

- Variable with no label (no `@metadata@variable_labels[[var]]`, no
  `attr(col, "label")`) → title falls back to the variable name.
- Empty-string label (`""`) → treated as missing; falls back to name.
- Group variable with `NA` label → footnote skipped for that group.
- Factor variable with reordered levels → spanner order follows levels.
- Character-valued group variable → spanner order follows sort order.

### Snapshot tests

Use `testthat::expect_snapshot()` on the rendered HTML output (via
`print(pt, output = "html")` or `format(pt, output = "html")`) for a
minimal grouped and ungrouped case. Also snapshot the Markdown output
(`output = "markdown"`) — it's small, text-diff-friendly, and catches
column-ordering and spanner-structure regressions independent of HTML
noise. Updates go through `snapshot_review()` per
`.claude/rules/testing-standards.md §3`.

---

## VI. Open Questions for Spec Review

1. **`tinytable` minimum version.** §IV pins `>= 0.4.0` as a placeholder.
   Confirm the actual floor when implementing by checking the release
   that introduced the `notes =` argument and the `group_tt(j = ...)`
   spanner form used here.
2. **Generic location.** `R/prettytable.R` (new file) vs. folding into
   `R/analysis-meta.R` alongside `meta()`. Preferred: new file —
   `prettytable()` will grow one method per result class.
3. **Should ungrouped freqs also accept `show_genpop`?** In adlgraphs,
   genpop only applies to grouped tables. Keeping that constraint keeps
   the API simple.
4. **Column-label attributes.** Per `project_column_labels` memory, all
   `get_*()` should set column-level `label` attributes. `prettytable()`
   should read those when available (for the ungrouped branch's
   `Percent` / `N` labels and the focal-variable header) rather than
   hardcoding. v1: hardcode + fall through to attribute if present.
   Revisit in v2.
5. **Output-format coverage in tests.** Snapshotting both HTML and
   Markdown gives cheap regression coverage, but LaTeX / Typst are
   also supported. Do we pin those in snapshots, or trust `tinytable`
   to render them correctly? Preferred: HTML + Markdown only for v1.

---

## VII. Relationship to Ecosystem

`prettytable()` is surveycore-internal. The companion `surveyviz` package
(ecosystem slot for visualization) may later add richer rendering. This
function is the minimum viable pretty-printer for surveycore results,
kept in-package because it reads `.meta` directly and co-evolves with
the result-class shapes.
