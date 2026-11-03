# Spec: Dataset-Level Metadata

| Field | Value |
|---|---|
| Spec ID | `dataset-level-metadata` |
| Version | 2.1 (rev 2 + pass-2 fixes) |
| Date | 2026-08-19 |
| Status | **SPEC_READY** (spec-review Pass 3: PASS, 2026-08-19) |
| Target release | surveycore 1.2.0 (development version 1.1.0.9000 during work) |
| Pipeline split | **recommended** (see §I.5) |

---

## Document Purpose

This document is the source of truth for the dataset-level metadata feature.
It defines one new `survey_metadata` property, one new validator, twelve new
exported functions, a set of shared internal helpers, changes to three
constructors, and changes to eight print/summary methods. The builder
implements from this document alone. Where this document and any other prose
disagree, this document wins.

Style, dispatch, and documentation rules are not restated here. They come from
`.claude/rules/code-style.md`, `.claude/rules/r-package-conventions.md`, and
`.claude/rules/surveycore-conventions.md`.

---

## I. Scope

### I.1 Delivers

| # | Item | Kind |
|---|---|---|
| 1 | `@dataset_metadata` property on `survey_metadata` | Class change |
| 2 | Validator on `survey_metadata` (the class has none today) | Class change |
| 3 | `set_dataset_metadata()` | New export |
| 4 | `set_survey_name()`, `set_data_name()`, `set_vendor()`, `set_field_dates()`, `set_field_period()` | New exports |
| 5 | `extract_dataset_metadata()` | New export |
| 6 | `extract_survey_name()`, `extract_data_name()`, `extract_vendor()`, `extract_field_dates()`, `extract_field_period()` | New exports |
| 7 | Construction promotion: data-frame attributes → `@dataset_metadata` | Internal helper + 3 constructor call sites |
| 8 | Guarded read helper for objects restored from old serialized files | Internal helper |
| 9 | `Dataset:` line in 4 print headers; fuller block in 4 `metadata_info` sections; one name line in 4 summary methods | Print changes |
| 10 | Fix: `as_survey_nonprob()` gains the weighting-history promotion call it currently lacks | Bug fix (existing inconsistency) |
| 11 | Parameterization of the shared setter-input parser and the shared fill validator (defaults keep all existing behavior and messages byte-identical) | Internal helper change |
| 12 | New rows in `plans/error-messages.md`; roxygen; `_pkgdown.yml`; vignette section; `NEWS.md`; version bump to 1.2.0 | Docs/release |

Twelve exports total: six setters, six extractors.

### I.2 Does NOT deliver

- Open (user-defined) keys. The key vocabulary is **closed** (§II.1). Opening
  it later is additive and backward-compatible; this release ships exactly six
  keys.
- Per-variable provenance tracking (open question; deferred).
- A free-text column marker (open question; deferred).
- The `adldata` migration itself (downstream, separate repo).
- Any change in `surveytidy` or `surveywts`.
- Any parsing of dates or names out of `data_name`. No function derives,
  fills, or validates `survey_name`, `data_name`, or the field dates from one
  another. The only cross-key behavior in the whole feature is the
  print-header fallback in §X.
- Repair of old serialized objects. Reads on them succeed (§IV); writes on
  them fail with a typed surveycore error (§IV, DM-8). The remedy is
  documented, not automated.
- `survey_collection` support. Collections do not inherit `survey_base`, so
  every one of the twelve functions rejects a collection with
  `surveycore_error_not_survey_or_df`. This is deliberate: dataset metadata
  belongs to one dataset, and a collection holds several. Member designs keep
  their own metadata whole; the collection print method does not change.

### I.3 Class / design support matrix

| Function group | `survey_taylor` | `survey_replicate` | `survey_twophase` | `survey_nonprob` | plain `data.frame` | `survey_collection` |
|---|---|---|---|---|---|---|
| Setters (all 6) | ✓ | ✓ | ✓ | ✓ | ✓ (writes attributes) | ✗ errors `surveycore_error_not_survey_or_df` |
| Extractors (all 6) | ✓ | ✓ | ✓ | ✓ | ✓ (reads attributes) | ✗ errors `surveycore_error_not_survey_or_df` |
| Construction promotion | ✓ `as_survey()` | ✓ `as_survey_replicate()` | inherits from phase 1 | ✓ `as_survey_nonprob()` | n/a | n/a |
| Print header line | ✓ | ✓ | ✓ | ✓ | n/a | unchanged |

`from_svydesign()`, `from_tbl_svy()`, and `as_tbl_svy()` do not change. They
build an empty `survey_metadata()`, and the empty default already includes an
empty `@dataset_metadata`. The `survey` package carries no dataset metadata,
so there is nothing to promote.

### I.4 Write surface

Production code touches exactly these files:

- `R/core-classes.R` — property, validator, roxygen for `survey_metadata`
- `R/core-metadata.R` — all 12 exported functions,
  `.get_dataset_metadata_list()`, `.format_dataset_result()`,
  parameterization of `.parse_setter_input()` and `.check_extractor_fill()`
- `R/utils.R` — `.dataset_metadata_or_empty()`, `.promote_dataset_metadata()`,
  `.read_dataset_attributes()`, `.check_dataset_key_value()`,
  `.coerce_field_date()`
- `R/core-constructors.R` — 3 promotion call sites + 1 weighting-history fix
- `R/methods-print.R` — 4 print methods, 4 summary methods,
  `.dataset_display_name()`, `.print_dataset_block()`
- `plans/error-messages.md` — new rows (§XI), one trigger-description
  extension for the five reused setter-convention classes (§VI.6), and the
  widened-message variant on the existing `surveycore_error_fill_invalid`
  row (§VIII.1, §XI)
- `NAMESPACE`, `man/` — generated by `devtools::document()`
- `_pkgdown.yml`, `vignettes/creating-survey-objects.Rmd`, `DESCRIPTION`,
  `NEWS.md` — docs/release (§XII)

No other file changes.

### I.5 PR split (recommendation: split)

This feature adds twelve exported functions and changes the class contract, so
a split is required. Four sequential PRs, each reviewable alone. PRs share
files across the sequence but never run concurrently.

| PR | Content | Files | Tests shipped with the PR |
|---|---|---|---|
| A | Property + validator + guarded reader + shared value checker + date coercion helper + all error-table rows | `R/core-classes.R`, `R/utils.R`, `plans/error-messages.md` | Class-layer and validator tests |
| B | Promotion helper + shared attribute reader + constructor wiring + nonprob weighting-history fix | `R/utils.R`, `R/core-constructors.R` | Promotion and constructor tests |
| C | All six setters + all six extractors + parser/fill parameterization | `R/core-metadata.R` | Setter and extractor tests, including old-object write/read behavior |
| D | Print/summary changes + print helpers + vignette + pkgdown + NEWS + version bump | `R/methods-print.R`, docs/release files | Print/summary output tests |

---

## II. Architecture

### II.1 Storage model — closed key vocabulary

One new property on `survey_metadata`:

```r
# Dataset-level metadata. Closed vocabulary — exactly six valid keys:
# survey_name, data_name, vendor, field_start, field_end, field_period.
dataset_metadata = S7::new_property(
  S7::class_list,
  default = quote(list())
)
```

It is a plain named list, like the 11 existing properties. The key vocabulary
is **closed**: exactly six keys are valid, each with a declared type. Any
other key is rejected with `surveycore_error_dataset_key_unknown` (§XI DM-5)
on every path — validator, setters, and extractors. There is no open key
space and no tracking attribute for extra keys: a key that names a base
attribute (`class`, `names`, `groups`, a data column, ...) is simply an
unknown key.

| # | Key | Type | Meaning | Example |
|---|---|---|---|---|
| 1 | `survey_name` | `character(1)`, non-NA | Full formal survey name. No dates. | `"Antisemitic Attitudes in America 2026"` |
| 2 | `data_name` | `character(1)`, non-NA | Display label for this dataset. Usually a short name plus the field period. | `"AAA Ipsos (February-March 2026)"` |
| 3 | `vendor` | `character(1)`, non-NA | Fielding vendor. | `"Ipsos KnowledgePanel Omnibus"` |
| 4 | `field_start` | `Date(1)`, non-NA | First day in the field. | `as.Date("2026-02-10")` |
| 5 | `field_end` | `Date(1)`, non-NA | Last day in the field. | `as.Date("2026-03-04")` |
| 6 | `field_period` | `character(1)`, non-NA | Prose field period, for display. | `"February-March 2026"` |

The table order above is the **canonical key order**. The stored list and
every whole-list read (§VIII) keep the present keys in this order, in both
input modes. Overwriting a key keeps its position, which the canonical sort
guarantees trivially.

Throughout this spec, a key is **present** when `key %in% names(dm)` is
`TRUE`. A `NULL`-valued element never counts as present, because the storage
layer never contains one (§III.3 check 6).

**Independence rule.** `survey_name` and `data_name` are two independent keys.
No function reads one to compute, fill, or check the other. The two values may
drift. The print output shows both, so drift is visible (§X).

**Naming rule.** Stored keys and returned list names are always the
`field_*` forms (`field_start`, `field_end`, `field_period`). No `start` or
`end` argument name exists anywhere in the API; `set_field_dates()` takes
`field_start` and `field_end`. The one short argument name is `period` in
`set_field_period(x, period)` (§VII.1), where the function name already
carries the `field_` context.

**Legacy `dates` name.** `dates` is the pre-1.2.0 attribute name for the
prose field period. It is read at construction and on the data-frame extract
path as `field_period` (§V.2). As a setter key, a non-`NULL` `dates` value is
an unknown key (DM-5) whose message points at `field_period` and
`set_field_period()`. `dates = NULL` is the one accepted spelling: it is an
explicit alias for `field_period = NULL` (§VI.4).

### II.2 Canonical value rules — ONE table

The type rules for the six keys live in exactly one place: the table in
§VI.5. The validator (§III.3), promotion (§V.3), the data-frame extract path
(§VIII.2), and the convenience setters (§VII) all reference that table via
one shared internal checker (§II.3). They never restate the rules.

**Storage invariant.** Only checked-and-coerced values are ever written to
`@dataset_metadata` or to a data-frame attribute by this API, so a stored
date is always a `Date(1)`. The validator enforces the same rules on direct
construction and `@<-` assignment, so the invariant holds even for values
that bypass the setters.

### II.3 Internal helpers

In `R/utils.R` (each is used from two or more files):

```r
# Return @dataset_metadata, or list() when the stored S7 class predates the
# property (object restored from an old .rds/.rda file).
.dataset_metadata_or_empty <- function(metadata) {
  if (!"dataset_metadata" %in% S7::prop_names(metadata)) {
    return(list())
  }
  metadata@dataset_metadata
}

# Coerce one candidate field-date value. Wraps as.Date() in tryCatch();
# base conditions from as.Date() NEVER surface to the caller. Returns a
# Date(1) on success, NULL on failure. Accepts: Date(1) non-NA, or a
# character(1) that parses with as.Date(v, format = "%Y-%m-%d") to a non-NA
# date AND round-trips (format(parsed, "%Y-%m-%d") == v). Strict ISO 8601:
# "2026/02/10", "2026-2-1", timestamps, and "2026-02-30" all fail.
.coerce_field_date <- function(value) { ... }

# The single valid-key value checker. mode = "error" raises the class
# from the §VI.5 table; mode = "skip" returns NULL plus a failure reason.
# Returns the coerced value on success. key_style controls how the error
# message names the offender: "val" renders the key as a value
# ({.val {key}}, the DM-3b/DM-6a register); "arg" renders it as a function
# argument ({.arg {key}}, the DM-6b register). `call` is passed through to
# cli_abort() so the error reports the user-facing caller. The validator
# (error), the setters (error), promotion (skip + warn), and the data-frame
# extract path (skip, silent) are its ONLY call sites.
.check_dataset_key_value <- function(
  key,
  value,
  mode = c("error", "skip"),
  key_style = c("val", "arg"),
  call = rlang::caller_env()
) { ... }

# Read the seven recognized attribute names off a data frame and apply the
# full §V.3 value rules through .check_dataset_key_value(mode = "skip").
# Returns list(values = <coerced named list, canonical order>,
#              dropped = <named report of skipped keys and reasons>).
# Promotion warns on the report (DM-7); the extract path ignores it
# (extractors never warn). Any attribute not among the seven names is
# ignored entirely — never promoted, never warned about.
.read_dataset_attributes <- function(data) { ... }

# Promote data-frame attributes into metadata@dataset_metadata via
# .read_dataset_attributes(). Emits one DM-7 warning per dropped key.
# Never errors. Never modifies `data` (§V.4).
.promote_dataset_metadata <- function(data, metadata) { ... }
```

Placement note: the file-placement rule alone would put
`.promote_dataset_metadata()` in `R/core-constructors.R` (single calling
file). It lives in `R/utils.R` instead, directly beside
`.promote_weighting_history()` (`R/utils.R:351`), because the two run at the
same constructor stage, share the attribute-promotion concern, and should be
read together. `.read_dataset_attributes()`, `.check_dataset_key_value()`,
and `.coerce_field_date()` are called from both `R/utils.R` and
`R/core-metadata.R`, so the 2+-files rule places them in `R/utils.R` anyway.

In `R/core-metadata.R`:

```r
# Resolve the effective key-value list for either input mode:
# survey object -> .dataset_metadata_or_empty(x@metadata);
# data frame    -> .read_dataset_attributes(x)$values (silent path).
.get_dataset_metadata_list <- function(x) { ... }

# Convert a resolved dataset-metadata list to "list" or "data_frame" output
# per §VIII.3. .format_scalar_result() is NOT reusable here: it names the
# first column `variable`, and its data_frame branch coerces through a
# character(1) vapply that cannot carry Date values or type-matched fills.
.format_dataset_result <- function(result_list, format, fill) { ... }
```

In `R/methods-print.R` (single-file helpers, defined at the top of the file
per the placement rule; the `.print_domain_info()` precedent):

```r
# Header display name: data_name if set, else survey_name, else NULL.
# Applies the §X.5 sanitation and truncation rules.
.dataset_display_name <- function(metadata) { ... }

# The §X.2 metadata block (Survey:, Vendor:, Field dates:). `header_name`
# is the value .dataset_display_name() printed, so the block can suppress
# a duplicate Survey: line.
.print_dataset_block <- function(metadata, header_name) { ... }
```

Every read path in the package — all six extractors, all four print methods,
all four summary methods — goes through `.dataset_metadata_or_empty()`
(directly or via `.get_dataset_metadata_list()`). Direct
`metadata@dataset_metadata` reads are forbidden outside the helpers and the
setter write path.

---

## III. `survey_metadata` class change

### III.1 Property

Add `dataset_metadata` (§II.1) after `weighting_history` in the property
list. Do not change `survey_base` or any design class; `survey_base@metadata`
already carries the metadata object.

### III.2 Roxygen

- Add `@param dataset_metadata` to the class roxygen block. State the six
  valid keys and their types, and that the vocabulary is closed. Point to
  `set_dataset_metadata()` / `extract_dataset_metadata()`.
- Add a `dataset_metadata` line to the class `@examples` block.
- Add an inline comment beside the property naming the six keys.

### III.3 Validator

`survey_metadata` gains its first validator. It checks `@dataset_metadata`
only. All checks run only when the list is non-empty. Check 7 delegates to
`.check_dataset_key_value(mode = "error")`; the value rules are the §VI.5
table, not restated here. Checks 5, 6, and 8 (name membership, `NULL`
elements, and the date-pair comparison) run in the validator itself.

| # | Check | Error class |
|---|---|---|
| 1 | The property is a list. | (enforced by `S7::class_list`; no class needed) |
| 2 | Every element has a name. | `surveycore_error_dataset_metadata_unnamed` |
| 3 | No name is `NA` or `""`. | `surveycore_error_dataset_metadata_unnamed` |
| 4 | No name is duplicated. | `surveycore_error_dataset_metadata_duplicate_key` |
| 5 | Every name is one of the six valid keys (§II.1). | `surveycore_error_dataset_key_unknown` |
| 6 | No element is `NULL`. | `surveycore_error_dataset_metadata_bad_type` |
| 7 | Every present key's value passes the §VI.5 table. | per §VI.5: `surveycore_error_dataset_metadata_bad_type` (character keys) / `surveycore_error_field_date_invalid` (date keys) |
| 8 | When both dates are present: `field_start <= field_end`. | `surveycore_error_field_dates_reversed` |

Notes:

- The validator accepts stored values only — a date key must already be a
  `Date(1)`. Coercion from ISO strings is a setter/promotion service, not a
  class service. This is the §II.2 storage invariant.
- The validator does **not** compare `survey_name` with `data_name` (§II.1).
- The validator fires on construction (`survey_metadata(...)`) and on any
  property assignment, because S7 re-validates on `@<-`.
- Validator messages are plain one-line text (Layer 1), not CLI-formatted.
  §XI marks the layer per class.

**Decision note.** The design plan offered an alternative: keep only the
structural checks in the validator and run the value checks in the setter
alone. This spec keeps the full check set in the validator because the print
methods read the keys, and a wrong type there would break every subsequent
`print()` call, which is worse than one construction error. The setters run
the same checks (same shared checker) so users get CLI-formatted messages;
the validator is the backstop.

### III.4 Edge cases (class layer)

| Input | Behavior |
|---|---|
| `survey_metadata()` (default) | `@dataset_metadata` is `list()`. Valid. |
| Empty list assigned explicitly (`m@dataset_metadata <- list()`) | Valid. All checks skipped. |
| `survey_name` set, `data_name` set, values unrelated | Valid. Independence rule. |
| `field_start` set, `field_end` absent | Valid. Check 8 needs both. |
| Any key not in the six (for example `mode`, `dates`, `class`) | Check 5 rejects it. |
| `list(vendor = NULL)` | Check 6 rejects it. Deletion happens by removing the element, not by storing `NULL`. |
| A date key holding an ISO string | Check 7 rejects it (validator accepts `Date` only). |

---

## IV. Old serialized objects (guarded reads, typed write failure)

An S7 object saved with `saveRDS()`/`.rda` under surveycore ≤ 1.1.0 stores a
frozen copy of the old class. On such an object,
`x@metadata@dataset_metadata` errors with S7's `Can't find property` message.

Contract:

- Every surveycore read path uses `.dataset_metadata_or_empty()` (§II.3), so:
  - all four print methods and all four summary methods succeed on a restored
    old object — with any argument combination, including
    `metadata_info = TRUE` and `full = TRUE` — and show no dataset lines;
  - all six extractors succeed on a restored old object and return their
    empty/NA results.
- A **write** (any of the six setters) on a restored old object raises
  `surveycore_error_dataset_metadata_unavailable` (§XI DM-8) — a
  CLI-formatted surveycore error, not S7's raw property error. The setters
  detect the condition with the same `S7::prop_names()` membership test the
  guarded reader uses, before any input parsing beyond the `x` class check
  (§VI.2 order). The `"v"` bullet names the remedy: rebuild the object with
  `as_survey()` (or the matching constructor).
- surveycore never rewrites a stored `S7_class` attribute.

---

## V. Construction promotion

### V.1 Placement and call sites

`.promote_dataset_metadata(data, metadata)` is a separate helper. It is not
part of the per-column haven-attribute reader, which keeps its single
column-loop responsibility.

| Constructor | Insertion point | Also fix |
|---|---|---|
| `as_survey()` | immediately after the existing weighting-history promotion (`R/core-constructors.R:548`) | — |
| `as_survey_replicate()` | immediately after `R/core-constructors.R:805` | — |
| `as_survey_nonprob()` | after the haven-metadata line (`R/core-constructors.R:1384`) | **Add the missing `.promote_weighting_history()` call first**, then the new promotion. This fixes the existing inconsistency in this branch. |

`as_survey_twophase()` does not change: it inherits the whole metadata object
from phase 1, and the phase-1 constructor already promoted the attributes.

### V.2 Read order — exactly seven attribute names

The shared reader (§II.3 `.read_dataset_attributes()`) reads exactly seven
whole-data-frame attributes, in this order. All reads use `exact = TRUE`.

| Step | Attribute read | Lands in key |
|---|---|---|
| 1 | `attr(data, "survey_name")` | `survey_name` |
| 2 | `attr(data, "data_name")` | `data_name` |
| 3 | `attr(data, "vendor")` | `vendor` |
| 4 | `attr(data, "field_start")` | `field_start` |
| 5 | `attr(data, "field_end")` | `field_end` |
| 6 | `attr(data, "field_period")` | `field_period` |
| 7 | `attr(data, "dates")` | `field_period`, **only when the `field_period` attribute is ABSENT** (legacy alias) |

Step-7 precision: "absent" means `attr(data, "field_period", exact = TRUE)`
returns `NULL`. When a `field_period` attribute exists but has an invalid
value, step 6 drops it (with DM-7 at promotion) and step 7 still does **not**
run — a present-but-invalid `field_period` is not repaired from `dates`.
This asymmetry is deliberate: repairing from a legacy name would hide the
invalid value.

Any other attribute on the data frame — user attributes, `groups`,
data.table internals, anything — is ignored entirely: never promoted, never
warned about. surveycore claims no attribute name beyond the seven above.

The reader reads `survey_name` and `data_name` independently. It never fills
one from the other. Output is in canonical key order (§II.1).

### V.3 Value rules at promotion

All values pass through `.check_dataset_key_value(mode = "skip")` — the
§VI.5 table applied in warn-and-skip mode. Construction never fails because
of a bad label, and no base condition from `as.Date()` ever surfaces
(§II.3 `.coerce_field_date()`).

- An **absent** attribute (`attr()` returns `NULL`) is skipped silently — it
  is simply not set.
- A **zero-length** value is skipped **with** one
  `surveycore_warning_dataset_metadata_dropped` (DM-7b). Loss is signalled,
  not silent.
- A wrong-typed, wrong-length (length > 1), or unparseable value is skipped
  with DM-7a. A character date that passes the strict ISO rule is stored as
  `Date` (coerced).
- **Variant precedence for the legacy `dates` attribute:** any invalid
  `dates` value — wrong type, zero-length, or wrong length — uses the DM-7d
  variant, whose remedy points at `set_field_period()`, not at the rejected
  `dates` name. DM-7a/DM-7b apply to the six canonical attribute names only.
- If, after per-key coercion, both dates are present and
  `field_start > field_end`, the helper drops **both** date keys with one
  DM-7 warning (§XI DM-7c). Construction proceeds. (Promotion never errors;
  the validator would reject the pair, so the pair must not be written.)
- When no recognized attribute exists, the helper returns `metadata`
  unchanged, and existing print output stays byte-identical.

### V.4 `@data` keeps the original attributes (non-destructive promotion)

Promotion **copies**; it never strips. After construction, the original
whole-data-frame attributes remain on `@data`, byte-identical to the input.
Consequences, all deliberate and documented:

- `@metadata@dataset_metadata` is the **single source of truth** on every
  read path of a survey object. No extractor, print, or summary method ever
  reads `attr(x@data, ...)` on a survey object.
- After `set_vendor(d, "Cint")`, `attr(d@data, "vendor")` still holds the
  original value. Rebuilding with `as_survey(d@data, ...)` re-promotes the
  **original** attributes — deleted or edited keys resurrect. The roxygen for
  `set_dataset_metadata()` and the vignette (§XII) state this explicitly and
  advise against `as_survey(d@data, ...)` round trips.

---

## VI. `set_dataset_metadata()`

### VI.1 Signature

```r
set_dataset_metadata(x, ..., key = NULL, value = NULL)
```

| Arg | Type | Default | Description |
|---|---|---|---|
| `x` | survey design object or `data.frame` | required | The object to modify. |
| `...` | named args, or one named list | — | Convention 1: `set_dataset_metadata(x, vendor = "Ipsos")`. Convention 2: one unnamed named **list**, e.g. `set_dataset_metadata(x, list(vendor = "Ipsos"))`. Supports `!!!` splicing. A `NULL` value deletes the key. |
| `key` | `character` vector | `NULL` | Convention 3: key names, paired with `value`. **Named-only** (after `...`). |
| `value` | `list` | `NULL` | Convention 3: one value per element of `key`. `NULL` deletes every key in `key`. **Named-only** (after `...`). |

Returns the modified object, invisibly.

Convention 3 `value` semantics:

- An atomic `value` is coerced with `as.list(value)` (documented in roxygen).
- Names on `value` are ignored; `key` wins.
- A `NULL` element **inside** a `value` list deletes that key:
  `set_dataset_metadata(x, key = c("vendor", "data_name"), value = list("Cint", NULL))`
  sets `vendor` and deletes `data_name`.
- `value = NULL` (the whole argument) deletes every key in `key` and skips
  the length check (rule 5 below).

This is the standard three-convention setter interface. It reuses the shared
setter-input parser with `content_type = "vector"`,
`content_arg_name = "value"`, and the §VI.6 message parameterization. Unlike
per-variable setters, it performs **no** column lookup: a key is not a
column, so the variable-not-found warning never fires here.

### VI.2 Shared input rules (all conventions)

Checked in this order, before any write:

| # | Rule | Error/warning class |
|---|---|---|
| 1 | `x` is a survey object or data frame. | `surveycore_error_not_survey_or_df` |
| 2 | On a survey object: the metadata object carries the property (§IV). | `surveycore_error_dataset_metadata_unavailable` |
| 3 | Not both `...` and `key`. | `surveycore_error_setter_ambiguous` |
| 4 | At least one of `...` / `key` given. | `surveycore_error_setter_empty` |
| 5 | Convention 3: `key` of length 0 → warn, return `x` unchanged. | `surveycore_warning_setter_empty_variables` |
| 6 | Convention 3: `length(key) == length(value)` when `value` is non-NULL. | `surveycore_error_setter_mismatched_lengths` |
| 7 | Conventions 1–2: every element is named, no blank names. | `surveycore_error_setter_mixed_dots` |
| 8 | Every resulting key name is non-`NA`, non-`""`. | `surveycore_error_dataset_metadata_unnamed` |
| 9 | No key name appears twice in one call. | `surveycore_error_dataset_metadata_duplicate_key` |
| 10 | Every key name is one of the six valid keys — with the `dates = NULL` exception (§VI.4). | `surveycore_error_dataset_key_unknown` |
| 11 | Every non-`NULL` value passes the §VI.5 table. | per §VI.5 |
| 12 | Effective date pair not reversed (§VI.5). | `surveycore_error_field_dates_reversed` |

**Alias resolution order.** The `dates = NULL` alias resolves to
`field_period` **before** rule 9 runs. So
`set_dataset_metadata(x, dates = NULL, field_period = "Feb 2026")` is a
`surveycore_error_dataset_metadata_duplicate_key` error — the two spellings
name one key, and one call may name a key once.

**Reachability of rules 8–9 (corrected check-order statement).** Rules 3–7
run inside the shared parser. A blank or missing name in Conventions 1–2
fails **inside the parser** as `surveycore_error_setter_mixed_dots` (rule 7),
so rule 8 (DM-1) is reachable via Convention 3 only (for example
`key = c("", "vendor")`). Rule 9 (DM-2) runs after parsing and is reachable
through any convention that delivers a duplicated name — duplicated named
`...` arguments and duplicated names in a Convention-2 list pass the parser,
as does `key = c("vendor", "vendor")`.

Rules 8 and 9 make a data frame obey the same structural rules the S7
validator enforces on a survey object, with CLI-formatted messages in both
modes.

### VI.3 Behavior on a survey design object

- Reads the current list through the guarded reader; rule 2 already
  guaranteed the property exists, so the write cannot hit S7's raw error.
- Sets, replaces, or deletes keys in `@metadata@dataset_metadata`. The stored
  list is kept in canonical key order (§II.1) after every write.
- Deleting a key that is not set is a silent no-op. `dates = NULL` is an
  alias for `field_period = NULL`.
- All other metadata properties are untouched. `@data` is untouched (§V.4).

### VI.4 Behavior on a plain data frame

- Writes one whole-object attribute per key: `attr(x, key) <- value` (the
  coerced value — a parsed ISO string is written as `Date`).
- A `NULL` value removes the attribute. Deleting a key that is not set is a
  silent no-op.
- **Legacy `dates` cleanup:** `field_period = NULL` removes **both** the
  `field_period` attribute and the legacy `dates` attribute, so deletion is
  idempotent and nothing resurrects at construction. `dates = NULL` is an
  explicit alias with the identical effect. A non-`NULL` `dates` value is an
  unknown key (rule 10) whose message points at `field_period` /
  `set_field_period()`.
- Per-column attributes, `names`, `row.names`, and class are untouched. A
  data column whose name matches a valid key is never read or written — the
  attribute namespace and the column namespace are distinct. A key that
  matches a column name but is not one of the six (for example `y1`) is an
  unknown key: the call errors and the column is untouched.
- A 0-row data frame is accepted; attributes need no rows.

### VI.5 Key value rules — THE canonical table

This table is the single statement of the per-key value rules (§II.2). The
shared checker implements it; §III.3, §V.3, §VII, and §VIII.2 reference it.

| Key | Accepted value (setter/promotion) | Stored as | On violation (error mode) |
|---|---|---|---|
| `survey_name`, `data_name`, `vendor`, `field_period` | `character(1)`, non-NA | as given | `surveycore_error_dataset_metadata_bad_type` |
| `field_start`, `field_end` | `Date(1)` non-NA, or strict-ISO `character(1)` per `.coerce_field_date()` (§II.3): parses with `format = "%Y-%m-%d"`, non-NA, and round-trips | `Date(1)` | `surveycore_error_field_date_invalid` |
| any of the six | zero-length, length > 1, or `NA` | — | class per the two rows above |

The validator (§III.3) applies the same table with one narrowing: it accepts
`Date(1)` only for the date keys (stored values are always coerced; §II.2).

**Effective-date-pair rule (three-way, per date key).** After the per-key
checks, compute the *effective* value of each date key:

1. The call supplies a non-`NULL` value → the new (coerced) value.
2. The call supplies an explicit `NULL` → **absent** (the deletion counts).
3. The call does not mention the key → the value already stored on `x`.

The reversed-pair check (`field_start > field_end` →
`surveycore_error_field_dates_reversed`) runs **only when both effective
values exist**. So one call can fix a reversed stored pair by deleting one
date and setting the other, and deleting both dates always succeeds. This
rule runs on both survey objects and data frames, so the two modes reject
the same inputs even though data frames have no S7 validator.

Writes are atomic per call: when any check fails, no key is written.

### VI.6 Error table and parser parameterization

`.parse_setter_input()` currently hardcodes `{.arg variable}`,
"variable-label pair", the container noun "vector" ("a named vector in
`...`" / "a fully named vector"), and `age = 'Age in years'` examples in its
five message templates. The container noun cannot be derived from
`content_type`, so it is its own parameter. The parser gains **four**
optional parameters —
`name_arg_name = "variable"`, `pair_noun = "variable-label"`,
`example_pairs = c("age = 'Age in years'", "age = 'Age', income = 'Annual income'")`,
and `container_noun = "vector"`
— whose defaults render the existing templates **byte-identically**, so the
seven existing setters' message text does not change. `set_dataset_metadata()`
passes `name_arg_name = "key"`, `pair_noun = "key-value"`,
`example_pairs = c("vendor = 'Ipsos'", "vendor = 'Ipsos', data_name = 'AAA Ipsos (February-March 2026)'")`,
and `container_noun = "list"`.

The five convention messages, rendered verbatim as this function emits them:

| Class | Verbatim message (as rendered for `set_dataset_metadata()`) |
|---|---|
| `surveycore_error_setter_ambiguous` | `x Provide key names via `...` or via `key`, not both.` / `i Use named `...` args, a named list in `...`, or `key` + `value` — not a mix.` |
| `surveycore_error_setter_empty` | `x `set_dataset_metadata()` requires at least one key-value pair.` / `v Use named `...` args: `set_dataset_metadata(x, vendor = 'Ipsos')`.` |
| `surveycore_warning_setter_empty_variables` | `! `set_dataset_metadata()` was called with `key` of length 0.` / `i No metadata was set. Did you accidentally filter all key names out?` |
| `surveycore_error_setter_mismatched_lengths` | `x `key` has {length(key)} element{?s} but `value` has {length(value)} element{?s}.` / `i They must be the same length (one content value per key name).` |
| `surveycore_error_setter_mixed_dots` | `x All `...` arguments must be named when using Convention 1.` / `i Got {n_named} named and {n_unnamed} unnamed element{?s}.` / `v Use `set_dataset_metadata(x, vendor = 'Ipsos', data_name = 'AAA Ipsos (February-March 2026)')` or a fully named list.` |

`plans/error-messages.md` gets a trigger-description extension on these five
existing rows: their message text is parameterized per calling function; the
canonical templates are the defaults, and dataset-metadata calls render the
`key`/`key-value` variants above.

Full error table for this function:

| Error class | Trigger | Message source |
|---|---|---|
| `surveycore_error_not_survey_or_df` | `x` wrong class (incl. `survey_collection`) | existing template, reused |
| `surveycore_error_dataset_metadata_unavailable` | survey object restored from a ≤ 1.1.0 file | §XI DM-8 |
| `surveycore_error_setter_ambiguous` / `_empty` / `_mismatched_lengths` / `_mixed_dots`, `surveycore_warning_setter_empty_variables` | conventions, as above | parameterized templates above |
| `surveycore_error_dataset_metadata_unnamed` | blank/NA key name (Convention 3) | §XI DM-1 |
| `surveycore_error_dataset_metadata_duplicate_key` | repeated key in one call | §XI DM-2 |
| `surveycore_error_dataset_key_unknown` | key not among the six valid keys | §XI DM-5 |
| `surveycore_error_dataset_metadata_bad_type` | character key wrong type/length/NA | §XI DM-3 |
| `surveycore_error_field_date_invalid` | date key fails `.coerce_field_date()` | §XI DM-6a |
| `surveycore_error_field_dates_reversed` | effective start > effective end | §XI DM-4 |

### VI.7 Edge cases

| Input | Behavior |
|---|---|
| Empty data frame (0 rows) | Attributes written normally. No error. |
| Single-row data frame | Normal. |
| Delete-only call: `set_dataset_metadata(x, vendor = NULL)` | Valid. Removes the key (or no-op when absent). |
| Set and delete in one call | Valid: `set_dataset_metadata(x, vendor = "Cint", data_name = NULL)`. |
| Bulk deletion: `key = c("vendor", "data_name"), value = NULL` | Valid. Length check skipped; both keys deleted; absent keys among them are no-ops. |
| Zero-length value for any key (e.g. `vendor = character(0)`) | Error, class per §VI.5. `character(0)` is not a deletion; only `NULL` deletes. |
| `field_start = "2026-02-30"` (unparseable) or `"2026/02/10"` (non-strict) | `surveycore_error_field_date_invalid`. No base `as.Date()` condition surfaces. |
| Set `field_start` later than an already-stored `field_end` | `surveycore_error_field_dates_reversed` (effective-pair rule). Atomic: nothing written. |
| One call deletes `field_end` and sets `field_start` after the old stored end | Valid — the deleted date is absent from the effective pair. |
| Unknown key near-miss (`Vendor`, `vender`) | DM-5 with the did-you-mean hint (§XI). |
| Unknown key equal to a data column name (`y1 = "x"`) | DM-5; the column is untouched. |
| Empty input, all-NA outcome columns, grouping, weights, strata | Not applicable — this function reads no data columns. |

---

## VII. Convenience setters

All five wrap `set_dataset_metadata()` and inherit its checks, its error
classes, and the §VI.5 table by reference — no type rule is restated at the
wrapper level. All return the modified object invisibly. All accept a survey
design object or a data frame. Check order in every wrapper: (1) `x` class
(`surveycore_error_not_survey_or_df`); (2) old-object property check (DM-8,
survey objects only); (3) the wrapper-level guard in the table below; then
delegation.

### VII.1 Delegation table

| Wrapper | Signature | Exact delegated call | Wrapper-level guard (before delegation) |
|---|---|---|---|
| `set_survey_name(x, name)` | `name`: `character(1)` non-NA, or `NULL` (deletes) | `set_dataset_metadata(x, survey_name = name)` | `name` missing → `surveycore_error_setter_empty` |
| `set_data_name(x, name)` | same shape | `set_dataset_metadata(x, data_name = name)` | `name` missing → `surveycore_error_setter_empty` |
| `set_vendor(x, vendor)` | same shape | `set_dataset_metadata(x, vendor = vendor)` | `vendor` missing → `surveycore_error_setter_empty` |
| `set_field_period(x, period)` | same shape | `set_dataset_metadata(x, field_period = period)` | `period` missing → `surveycore_error_setter_empty` |
| `set_field_dates(x, field_start, field_end)` | see §VII.2 | only the **supplied** arguments are forwarded: both → `set_dataset_metadata(x, field_start = ..., field_end = ...)`; one → that argument alone | both missing → `surveycore_error_setter_empty` |

A missing required value is therefore a typed error, never an unclassed base
"argument missing" error. The wrapper-level guard emits its **own**
`surveycore_error_setter_empty` message — not the general setter's key-value
template — naming the calling function and its missing argument. Rendered
verbatim for `set_vendor()`:

```
"x" = "{.fn set_vendor} requires a value for {.arg vendor}.",
"v" = "Supply a single character value, or {.code NULL} to delete the key."
```

The other three scalar wrappers render identically with their own function
and argument names. `set_field_dates()` renders:

```
"x" = "{.fn set_field_dates} requires at least one of {.arg field_start} or {.arg field_end}."
```

`set_survey_name()` writes only `survey_name` and `set_data_name()` writes
only `data_name`; neither reads or writes the other key, ever. Type
violations for the four scalar wrappers surface from the delegated call with
the §VI.5 classes, so the rendered message names the delegated key (for
example, `set_survey_name(d, 1L)` produces a DM-3b message naming
`survey_name`).

### VII.2 `set_field_dates(x, field_start, field_end)` — dates only

The prose period has its own setter (`set_field_period()`); this function
never touches `field_period`.

| Arg | Type | Description |
|---|---|---|
| `x` | survey object or `data.frame` | Object to modify. |
| `field_start` | `Date(1)`, strict-ISO `character(1)`, or `NULL` | First field day. |
| `field_end` | `Date(1)`, strict-ISO `character(1)`, or `NULL` | Last field day. |

Argument semantics (missing vs `NULL` — the observable contract, using
rlang missing-argument semantics):

- An argument the caller **does not supply** (detected with
  `rlang::is_missing()` on the unevaluated argument) leaves the stored key
  **unchanged**, and is not forwarded to the delegated call.
- An explicit `NULL` **deletes** the key (forwarded as a deletion).
- Any other value is validated and coerced **in the wrapper** through the
  shared checker (§II.3) with `key_style = "arg"` and this function's own
  `call`, so a violation raises the DM-6b variant naming this function's
  argument and reporting `set_field_dates()` as the caller. The delegated
  `set_dataset_metadata()` call then receives already-coerced `Date` values.
- Both arguments missing → `surveycore_error_setter_empty` (§VII.1 wrapper
  message).

The effective-pair rule of §VI.5 applies unchanged; because only supplied
arguments are forwarded, an unsupplied date contributes its stored value and
a `NULL` date contributes absence. `NULL` therefore means the same thing in
every setter in this family: delete.

---

## VIII. `extract_dataset_metadata()`

### VIII.1 Signature

```r
extract_dataset_metadata(x, ..., key = NULL, format = "list", fill = NULL)
```

| Arg | Type | Default | Description |
|---|---|---|---|
| `x` | survey object or `data.frame` | required | Object to read. |
| `...` | bare or quoted key names | — | Keys to return. Empty = all present keys. Plain name matching, **not** tidy-select — a key is not a column (deviation from the sibling extractors; documented in roxygen). |
| `key` | `character` vector or `NULL` | `NULL` | Programmatic alternative to `...`, mirroring the setter's Convention 3. **Named-only.** |
| `format` | `"list"` or `"data_frame"` | `"list"` | Output shape. **Named-only.** |
| `fill` | `NULL`, `NA`, or `NA_character_` | `NULL` | Two effects. For explicitly requested keys that are not set: `NULL` omits them; `NA`/`NA_character_` includes them, type-matched (§VIII.3). With an empty request (no `...`, no `key`), a non-`NULL` `fill` returns the full six-key schema, absent keys filled (§VIII.2). **Named-only.** |

Returns visibly.

`...` capture is specified exactly:

- Elements are captured unevaluated (`rlang::ensyms()`-style): bare symbols
  and character strings are accepted; `!!!` splicing of a character vector
  or list of names is supported.
- Any call in `...` — including tidyselect helpers like `all_of()` — errors
  with `surveycore_error_dataset_key_not_name` (§XI DM-9).
- Duplicated requests are deduplicated, keeping the first position.
- Supplying both `...` and `key` errors with
  `surveycore_error_setter_ambiguous` (reused class; message names `key`).
- Every requested key must be one of the six valid keys; an unknown request
  errors with `surveycore_error_dataset_key_unknown` (DM-5) — a typo is a
  signal, not an empty result.

`fill` validation: the shared fill validator gains a widening parameter.
Its default preserves the existing extractors' behavior and messages
byte-identically (they continue to accept `NULL`/`NA_character_` only); this
function passes the widened mode, which additionally accepts plain `NA`. An
invalid `fill` errors with `surveycore_error_fill_invalid`; the widened
message lists `NULL`, `NA`, and `NA_character_` as valid.

### VIII.2 Key resolution

- On a survey object: the guarded property read (§IV). An object restored
  from an old file yields the empty list. `@metadata@dataset_metadata` is the
  single source of truth; `@data` attributes are never consulted (§V.4).
- On a data frame: the shared attribute reader (§II.3) — the same seven
  names, the same §V.2 order and legacy-`dates` rule, and the same §VI.5
  value rules as promotion, applied **silently** (extractors never warn):
  a wrong-typed, zero-length, or unparseable attribute value is dropped; a
  strict-ISO string date is returned as `Date`; a reversed raw pair drops
  both dates. The §IX return types therefore hold on both input modes.
- With empty `...` and no `key`, `fill = NULL`: all present keys, in
  canonical key order (§II.1), in both input modes.
- With empty `...` and no `key`, `fill` non-`NULL`: the **full six-key
  schema** in canonical order — present keys with their values, absent keys
  filled. This is the codebook/audit idiom; it is cheap and unambiguous
  under the closed vocabulary.
- With requested keys (via `...` or `key`): output preserves the request
  order (after dedup). Unset requested keys follow `fill`. No warning fires
  for an unset valid key — unset is a normal state, not a mistake.

### VIII.3 Output contract

**`format = "list"`** — a named list of the stored values, unmodified
(dates are `Date(1)`). A filled absent key is **type-matched**:
`as.Date(NA)` for `field_start`/`field_end`, `NA_character_` for the four
character keys. Empty result → `list()`.

**`format = "data_frame"`** — a tibble with exactly two columns:

| Column | Type | Content |
|---|---|---|
| `key` | `character` | Key name. Values are unique (dedup guarantees it). |
| `value` | `character` | Display coercion of the value (rule below). |

Display coercion, per value: `Date` → `format(v)` (ISO); `character` → as
stored; a filled absent key → `NA_character_` (fill in this format is always
`NA_character_`, regardless of key type). Empty result → a 0-row tibble with
the two columns.

The first column is named `key`, not `variable`, because the entries are not
variables.

### VIII.4 Errors

| Error class | Trigger |
|---|---|
| `surveycore_error_not_survey_or_df` | `x` wrong class (incl. `survey_collection`) |
| `surveycore_error_setter_ambiguous` | both `...` and `key` supplied (reused class) |
| `surveycore_error_dataset_key_not_name` | a call/tidyselect helper in `...` (§XI DM-9) |
| `surveycore_error_dataset_key_unknown` | a requested key not among the six (§XI DM-5) |
| `surveycore_error_format_invalid` | `format` not `"list"` / `"data_frame"` (existing template; valid values listed) |
| `surveycore_error_fill_invalid` | `fill` not `NULL` / `NA` / `NA_character_` (widened message) |

### VIII.5 Edge cases

| Input | Behavior |
|---|---|
| No dataset metadata at all, `fill = NULL` | `list()` / 0-row tibble. |
| No dataset metadata, empty request, `fill = NA` | Full six-key schema, all filled. |
| Object restored from an old file | Same as "no dataset metadata". |
| Requested key never set, `fill = NULL` | Omitted. |
| Requested key never set, `fill = NA` | Present, type-matched fill (list) / `NA_character_` (data_frame). |
| Duplicate request (`vendor, vendor`) | One `vendor` entry, first position. Holds in both formats. |
| Empty (0-row) data frame with attributes | Attributes read normally. |
| Data frame, raw attribute set with bare `attr()<-` | Read normally — the setter is not required. Bad-typed/zero-length raw values are dropped silently. |

---

## IX. Convenience extractors

All five accept a survey design object or a data frame, use the same key
resolution as §VIII.2 (so the return types below hold on both input modes),
and return visibly. None warns or errors on an unset key. Wrong `x` class →
`surveycore_error_not_survey_or_df`.

| Function | Returns | When unset |
|---|---|---|
| `extract_survey_name(x)` | `character(1)` | `NA_character_` |
| `extract_data_name(x)` | `character(1)` | `NA_character_` |
| `extract_vendor(x)` | `character(1)` | `NA_character_` |
| `extract_field_dates(x)` | `list(field_start = <Date(1)>, field_end = <Date(1)>)` | unset entries are `as.Date(NA)` |
| `extract_field_period(x)` | `character(1)` | `NA_character_` |

`extract_field_dates()` returns the two structured dates only — the prose
period has its own extractor. The returned list names are `field_start` and
`field_end` (the §II.1 naming rule; no short names).

**Strictness rule.** `extract_data_name()` returns the stored `data_name` key
only. When `data_name` is unset it returns `NA_character_` — even when
`survey_name`, `field_start`, `field_end`, and `field_period` are all set. It
never composes a label. The header fallback in §X is the only place in the
package that substitutes one name for the other, and it substitutes for
display only; it writes nothing.

---

## X. Print and summary changes

All eight methods obtain their lines from the two shared helpers
(§II.3 `.dataset_display_name()`, `.print_dataset_block()`); the per-method
sections below are call-site statements, not independent implementations.
All reads go through the guarded reader (§IV), so every method succeeds on
an old restored object with every argument combination and prints no dataset
lines.

### X.1 Header line (all four print methods, always on)

Each print method calls `.dataset_display_name(x@metadata)` and, when the
result is non-`NULL`, emits exactly one line via
`cli::cli_text("Dataset: {display_name}")` — `display_name` is a computed
data variable, never pasted into the format string (§X.5).

Display-name rule: `data_name` if set; else `survey_name` if set; else no
line. Default output stays byte-identical to 1.1.0 when no dataset metadata
is set.

Position: directly before the sample-size line.

- `survey_taylor`, `survey_replicate`: between the class line and
  `Sample size:`.
- `survey_twophase`: between the class line and `Phase 1 sample size:`.
- `survey_nonprob`: directly before `Sample size:` — after the variance
  bullet in the no-repweights branch; directly after the class line in the
  repweights branch (which has no variance bullet).

### X.2 `metadata_info` block (all four print methods)

When `metadata_info = TRUE` or `full = TRUE`, the Metadata section gains a
dataset block **above** the existing labeled-count line, emitted by
`.print_dataset_block()`. Lines, in order, each via `cli::cli_text()` with
the value as a data variable:

1. `Survey: {survey_name}` — printed only when `survey_name` is set, AND
   `data_name` is set (so the header printed `data_name`), AND
   `!identical(survey_name, data_name)`. One string never appears on two
   lines, even when the two keys hold the same value.
2. `Vendor: {vendor}` — when set.
3. `Field dates: {dates_text}` — `dates_text` is composed first, then passed
   as one data variable:
   - both dates set, no period: `<start> to <end>` (ISO, via `format()`)
   - both dates and period set: `<start> to <end> (<period>)` — drift
     between structured dates and prose is always visible
   - exactly one date set: the set date with `?` for the missing one —
     `2026-02-10 to ?` or `? to 2026-03-04`; ` (<period>)` appended when the
     period is also set
   - no dates, period set: the period string alone
   - nothing set: no line.
4. When `@dataset_metadata` is empty (or the object predates the property),
   the block prints nothing and the section is byte-identical to 1.1.0.

### X.3 Verbatim console contract

The blocks below are the literal expected output under cli's ASCII fallback
(non-UTF-8 rendering: `--` rules; `cli_h1()` emits one leading blank line
and pads its rule to the 80-column width; `cli_h2()` emits one leading and
one trailing blank line). In an interactive UTF-8 session the rules render
with `──` instead. Sample sizes and tibble bodies below are illustrative.

New-line cli calls: header line and every block line use `cli::cli_text()`
as specified in §X.1–§X.2. No new `cli_h*()`, `cli_bullets()`, or rule calls
are added.

`survey_taylor`, all six keys set, `print(d, metadata_info = TRUE)`:

```

-- Survey Design ---------------------------------------------------------------
<survey_taylor> (Taylor series linearization)
Dataset: AAA Ipsos (February-March 2026)
Sample size: 200


-- Metadata --

Survey: Antisemitic Attitudes in America 2026
Vendor: Ipsos KnowledgePanel Omnibus
Field dates: 2026-02-10 to 2026-03-04 (February-March 2026)
0 variable(s) labeled

# A tibble: 200 x 7
...
```

Same class, only `field_period` set among the date fields (plus `data_name`),
`print(d, metadata_info = TRUE)` — the `Field dates:` line carries the prose
period alone, and no `Survey:` line appears (`survey_name` unset):

```

-- Survey Design ---------------------------------------------------------------
<survey_taylor> (Taylor series linearization)
Dataset: AAA Ipsos (February-March 2026)
Sample size: 200


-- Metadata --

Field dates: February-March 2026
0 variable(s) labeled

# A tibble: 200 x 7
...
```

Only `survey_name` set (no `data_name`), default `print(d)` — the header
falls back and no other line appears:

```

-- Survey Design ---------------------------------------------------------------
<survey_taylor> (Taylor series linearization)
Dataset: Antisemitic Attitudes in America 2026
Sample size: 200

# A tibble: 200 x 7
...
```

No dataset metadata set — output is byte-identical to surveycore 1.1.0 (no
`Dataset:` line, no metadata-section additions).

`survey_replicate` header with `data_name` set:

```

-- Survey Design ---------------------------------------------------------------
<survey_replicate> (BRR, 5 replicates)
Dataset: AAA Ipsos (February-March 2026)
Sample size: 200
```

`survey_twophase` header with `data_name` set:

```

-- Survey Design ---------------------------------------------------------------
<survey_twophase> (method: full)
Dataset: AAA Ipsos (February-March 2026)
Phase 1 sample size: 400
Phase 2 sample size: 120
```

`survey_nonprob` (no replicate weights) header with `data_name` set:

```

-- Survey Design ---------------------------------------------------------------
<survey_nonprob> (non-probability) [experimental]
* Variance: SRS approximation (no bootstrap replicate weights)
Dataset: AAA Ipsos (February-March 2026)
Sample size: 200
```

`survey_nonprob` (with replicate weights) header with `data_name` set — no
variance bullet exists in this branch, so the line follows the class line:

```

-- Survey Design ---------------------------------------------------------------
<survey_nonprob> (non-probability, BOOTSTRAP, 10 replicates) [experimental]
Dataset: AAA Ipsos (February-March 2026)
Sample size: 200
```

The four classes' outputs are otherwise identical modulo their existing
class-specific lines; no other class-specific dataset behavior exists.

### X.4 Summary methods (all four)

Each summary method currently emits `cli::cli_text("")` and then the
`Metadata: N of M variable(s) labeled` line. The new line goes **after that
blank line and directly above the `Metadata:` line**, using
`.dataset_display_name()` (same fallback as §X.1); no line when the helper
returns `NULL`. Verbatim tail of `summary()` for `survey_taylor` with
`data_name` set:

```

Dataset: AAA Ipsos (February-March 2026)
Metadata: 0 of 8 variable(s) labeled
```

The same placement applies in all four summary methods (for
`survey_twophase` the blank line follows the Phase 2 design block). No other
summary line changes. With no dataset metadata the summary output is
byte-identical to 1.1.0.

### X.5 Print hardening (all name-bearing lines)

- Every user-supplied string (`display_name`, `survey_name`, `vendor`,
  `dates_text` period part) is passed to cli as a **data variable** — never
  `paste0()`-ed into the format string — so `{`, `}`, and glue syntax in a
  value cannot abort `print()`.
- Before display, `\n`, `\r`, and `\t` in a value are each replaced with a
  single space.
- Values longer than **60 characters** are truncated to 57 characters plus
  `...` (ASCII). Applies per value, in `.dataset_display_name()` and
  `.print_dataset_block()` both.

---

## XI. New error and warning classes

Add these rows to `plans/error-messages.md` (row prefix `DM-`). Layer-1 rows
(S7 validator) are plain one-line text, not CLI-formatted — the C1/C4/G1
precedent. Layer-3 rows use the full x/i/v CLI register. Reused classes
(§VI.6, §VIII.4) get no new rows beyond the §VI.6 trigger-description
extension.

Nine new classes: eight errors (DM-1 … DM-6, DM-8, DM-9) and one warning
(DM-7).

Also update the **existing** `surveycore_error_fill_invalid` row: add the
`extract_dataset_metadata()` variant, whose message lists `NULL`, `NA`, and
`NA_character_` as valid (§VIII.1). The sibling extractors keep the
two-value message.

**Variable bindings.** Every template variable below is bound: `{key}` = the
offending key name; `{value}` = the offending value; `{n_bad}` = count of
unnamed/blank entries; `{dupes}` = the duplicated names; `{valid_keys}` = the
fixed vector of the six §II.1 names; `{suggestion}` = the nearest valid key
(bound only when the hint condition holds); `{expected}` = one of two fixed
strings — `"a single non-NA character string"` (character keys) or
`"a Date scalar or an ISO 8601 date string (YYYY-MM-DD)"` (date keys);
`{start}`/`{end}` = the effective ISO-formatted dates.

| # | Layer / function(s) | Condition | Level | Class | Message template |
|---|---|---|---|---|---|
| DM-1a | Layer 1: `survey_metadata` validator (trigger: direct construction or `@<-`) | An element of `@dataset_metadata` has no name, an `NA` name, or an empty name | ERROR | `surveycore_error_dataset_metadata_unnamed` | plain: `All dataset metadata entries must have a non-empty name.` |
| DM-1b | Layer 3: `set_dataset_metadata()` (Convention 3) | A key name is `NA` or `""` | ERROR | `surveycore_error_dataset_metadata_unnamed` | `"x" = "All dataset metadata keys must have a non-empty name.", "i" = "Found {n_bad} unnamed or blank-named entr{?y/ies}."` |
| DM-2a | Layer 1: validator | A key name is duplicated | ERROR | `surveycore_error_dataset_metadata_duplicate_key` | plain: `Duplicate dataset metadata key(s): <names>.` |
| DM-2b | Layer 3: `set_dataset_metadata()` | A key name appears twice in one call | ERROR | `surveycore_error_dataset_metadata_duplicate_key` | `"x" = "Duplicate dataset metadata key{?s}: {.val {dupes}}.", "i" = "Each key must appear exactly once."` |
| DM-3a | Layer 1: validator | A character key (`survey_name`, `data_name`, `vendor`, `field_period`) has the wrong type, length ≠ 1, or is `NA`; or any element is `NULL` | ERROR | `surveycore_error_dataset_metadata_bad_type` | plain: `Dataset metadata key <key> must be a single non-NA character string.` |
| DM-3b | Layer 3: `set_dataset_metadata()` and the four character-key wrappers | Same, at the setter | ERROR | `surveycore_error_dataset_metadata_bad_type` | `"x" = "Dataset metadata key {.val {key}} must be {expected}, not {.cls {class(value)[[1L]]}} of length {length(value)}.", "v" = "Supply a single non-NA character value, or {.code NULL} to delete the key."` |
| DM-4a | Layer 1: validator | `field_start` is after `field_end` | ERROR | `surveycore_error_field_dates_reversed` | plain: `field_start is after field_end.` |
| DM-4b | Layer 3: `set_dataset_metadata()`; `set_field_dates()` | Effective `field_start` after effective `field_end` (§VI.5 three-way rule) | ERROR | `surveycore_error_field_dates_reversed` | `"x" = "{.val field_start} ({start}) is after {.val field_end} ({end}).", "v" = "Swap the two dates, or correct the wrong one."` |
| DM-5a | Layer 1: validator | A stored key is not one of the six | ERROR | `surveycore_error_dataset_key_unknown` | plain: `Unknown dataset metadata key: <key>.` |
| DM-5b | Layer 3: all setters and extractors | A supplied/requested key is not one of the six | ERROR | `surveycore_error_dataset_key_unknown` | `"x" = "{.val {key}} is not a dataset metadata key.", "i" = "Valid keys: {.val {valid_keys}}."` — plus, when the lowercased key is within Levenshtein distance 1 of a valid key: `"i" = "Did you mean {.val {suggestion}}?"` — plus, when the key is `dates` (non-NULL value): `"i" = "The legacy {.val dates} attribute maps to {.val field_period}.", "v" = "Use {.fn set_field_period}, or {.code dates = NULL} to delete."` |
| DM-6a | Layer 3: `set_dataset_metadata()` only (checker `key_style = "val"`; the wrappers pre-validate, so a delegated date value is already a `Date`) | A `field_start`/`field_end` value fails `.coerce_field_date()` | ERROR | `surveycore_error_field_date_invalid` | `"x" = "{.val {key}} must be {expected}, not {.cls {class(value)[[1L]]}} of length {length(value)}.", "i" = "Got {.val {value}}."` — plus, when the value is `NA`: `"i" = "The value is NA."` |
| DM-6b | Layer 3: `set_field_dates()` (checker `key_style = "arg"`, wrapper's own `call`) | Same, naming the function's own argument | ERROR | `surveycore_error_field_date_invalid` | `"x" = "{.arg {key}} must be {expected}, not {.cls {class(value)[[1L]]}} of length {length(value)}.", "i" = "Got {.val {value}}."` — same NA bullet. (`{key}` is `field_start` or `field_end`, which is both the key and the argument name.) |
| DM-6c | Layer 1: validator | A date key's stored value is not a `Date(1)` non-NA | ERROR | `surveycore_error_field_date_invalid` | plain: `Dataset metadata key <key> must be a Date scalar.` |
| DM-7a | Layer 3: constructor promotion (`as_survey()`, `as_survey_replicate()`, `as_survey_nonprob()`) — CLI register | One of the six canonical attributes has a wrong-typed, wrong-length (length > 1), or unparseable value; skipped | WARN | `surveycore_warning_dataset_metadata_dropped` | `"!" = "Dataset attribute {.field {key}} has an invalid value and was not promoted.", "i" = "Expected {expected}; got {.cls {class(value)[[1L]]}} of length {length(value)}.", "v" = "Fix the attribute on the data frame, or set the key later with {.fn set_dataset_metadata}."` |
| DM-7b | Layer 3: constructor promotion — CLI register | One of the six canonical attributes has a zero-length value; skipped | WARN | `surveycore_warning_dataset_metadata_dropped` | `"!" = "Dataset attribute {.field {key}} has a zero-length value and was not promoted.", "v" = "Set a single non-NA value, or remove the attribute."` |
| DM-7c | Layer 3: constructor promotion — CLI register | Coerced `field_start` > `field_end`; both dropped | WARN | `surveycore_warning_dataset_metadata_dropped` | `"!" = "Dataset attributes {.field field_start} and {.field field_end} are reversed ({start} is after {end}); neither was promoted.", "v" = "Correct the dates on the data frame, or set them later with {.fn set_field_dates}."` |
| DM-7d | Layer 3: constructor promotion — CLI register | The legacy `dates` attribute has ANY invalid value (wrong type, zero-length, wrong length); skipped. Takes precedence over DM-7a/DM-7b for the `dates` name | WARN | `surveycore_warning_dataset_metadata_dropped` | `"!" = "Legacy dataset attribute {.field dates} has an invalid value and was not promoted to {.val field_period}.", "v" = "Set the period with {.fn set_field_period}."` |
| DM-8 | Layer 3: all six setters | Survey object restored from a ≤ 1.1.0 file lacks the property | ERROR | `surveycore_error_dataset_metadata_unavailable` | `"x" = "This object cannot store dataset metadata.", "i" = "It was created by surveycore <= 1.1.0, before the {.field dataset_metadata} property existed.", "v" = "Rebuild the object with {.fn as_survey} (or the matching constructor), then set the metadata."` |
| DM-9 | Layer 3: `extract_dataset_metadata()` | A `...` element is a call (incl. tidyselect helpers) | ERROR | `surveycore_error_dataset_key_not_name` | `"x" = "{.arg ...} must contain bare key names or strings.", "i" = "Tidy-select helpers do not apply here: a dataset metadata key is not a column.", "v" = "Use bare names ({.code vendor}), strings ({.val vendor}), or the {.arg key} argument."` |

---

## XII. Documentation, metadata, release

1. `devtools::document()` regenerates `NAMESPACE` and `man/`. Twelve new
   export entries. `man/survey_metadata.Rd` updates.
2. `_pkgdown.yml`: the six setters join the "Metadata — setters" section;
   the six extractors join the "Metadata — extractors" section.
3. `vignettes/creating-survey-objects.Rmd`: new "Dataset-level metadata"
   section. Show the `data-raw` workflow (set attributes on the tibble, then
   `as_survey()`). Show `survey_name` and `data_name` side by side and state
   that the two are independent. Add an **attribute-persistence paragraph**:
   base `[` subsetting, `as_tibble()`, and `merge()` silently drop
   whole-object attributes, so set dataset metadata **last**, directly before
   `usethis::use_data()` — or set it on the survey design instead.
4. `set_dataset_metadata()` roxygen gains `@section Attribute persistence:`
   with the same warning and the named droppers, plus the §V.4 note that
   rebuilding from `d@data` re-promotes the original attributes.
5. Roxygen for `key`, `value`, `format`, and `fill` states they are
   named-only (they follow `...`).
6. `DESCRIPTION`: extend the `Description` field to mention dataset-level
   metadata; bump `Version:` per the release workflow (dev `1.1.0.9000`
   during work; `1.2.0` at release).
7. `NEWS.md`: `# surveycore 1.2.0` heading; list the new API; add a "Notes"
   item with the serialization caveat: objects saved under ≤ 1.1.0 read
   cleanly (they report no dataset metadata) but cannot receive dataset
   metadata until rebuilt with a constructor (writes raise a typed error
   naming the remedy).
8. `extract_metadata()` is deliberately untouched: it reports per-variable
   fields only, and dataset-level keys are not variables. State this in its
   roxygen `@details` (one sentence) and in the vignette section.
9. All new exported functions carry `@family metadata`, full `@return`, and
   runnable `@examples`. The convenience setters/extractors may share `.Rd`
   pages per pair (setter page, extractor page) or stand alone — builder's
   choice; every export needs a documented entry either way.

---

## XIII. Quality gates

Done means all of the following hold:

- [ ] `survey_metadata()` default produces `@dataset_metadata == list()`.
- [ ] All validator checks in §III.3 fire with the stated classes; a list
      with all six keys constructs cleanly; an unknown key is rejected at
      the class layer.
- [ ] A metadata object with an unrelated `survey_name`/`data_name` pair
      constructs cleanly (independence).
- [ ] All twelve exported functions behave per §VI–§IX on all four design
      classes and on plain data frames; `survey_collection` input is
      rejected with the stated class.
- [ ] Attribute round trip holds for valid values of the six keys:
      `set_dataset_metadata(df, ...)` → `as_survey(df, ...)` →
      `extract_dataset_metadata(d)` returns the same keys and values in
      canonical order. Exceptions, both signalled by DM-7 at construction:
      zero-length attribute values and invalid attribute values do not
      survive construction.
- [ ] Legacy `dates` attribute promotes to `field_period` only when the
      `field_period` attribute is absent; an explicit `field_period`
      attribute — valid or not — stops the `dates` fallback.
- [ ] Promotion is non-destructive: `@data` stays byte-identical to the
      input, and `as_survey(d@data, ...)` re-promotes the original
      attributes (documented resurrection behavior).
- [ ] `as_survey_twophase()` designs expose the phase-1 keys;
      `from_svydesign()` / `from_tbl_svy()` objects expose none.
- [ ] `as_survey_nonprob()` now promotes both weighting history and dataset
      metadata.
- [ ] Print/summary output is byte-identical to 1.1.0 whenever no dataset
      metadata is set; the new lines render per §X otherwise; the seven
      existing setters' convention messages are byte-identical to 1.1.0.
- [ ] Reads on an object whose stored class predates the property succeed
      and report no dataset metadata. For each of the four design classes, a
      restored old object of that class survives `print()`,
      `print(metadata_info = TRUE)`, `print(full = TRUE)`, and `summary()` —
      four calls per class, sixteen in total, reaching all four print
      methods and all four summary methods. Writes on such an object raise
      DM-8.
- [ ] Every new error/warning class exists in `plans/error-messages.md`.
- [ ] `devtools::document()` run; `devtools::check()` passes with 0 errors,
      0 warnings, no new notes beyond the two pre-approved ones.

---

## XIV. Integration contracts

- **surveytidy** — no change requested. Dataset-level metadata is not keyed
  by variable, so `select()`/`rename()` metadata lifecycles do not touch it.
  surveytidy verbs must not rebuild `@metadata` from scratch; they already
  carry the whole object forward, which preserves the new slot.
- **surveywts** — no change. `@weighting_history` and `@dataset_metadata` are
  separate slots with separate promotion paths.
- **adldata** — future consumer. Its 13 `data_name` and 10 `vendor` raw
  attributes promote with no edit. The one legacy `dates` attribute promotes
  via the §V.2 step-7 rule. Migration of `data-raw/` scripts is out of scope
  here.
- **survey_collection** — explicitly out of scope for 1.2.0 (§I.2).
