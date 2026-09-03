# Decisions — haven-labelled (issue #175)

## D1 — Fix policy: strip the labelled class at construction

**Decided**: 2026-08-27, by the user, before Stage 0 comprehension.
**Status**: SETTLED — do not re-litigate in review.

Drop the `haven_labelled` / `vctrs_vctr` class from `@data` columns in the
construction path. Keep the `labels` attribute on the stored column.

```r
.strip_labelled_class <- function(x) {
  if (inherits(x, "haven_labelled")) {
    attr(x, "class") <- NULL
  }
  x
}
```

### Why

Measured before the decision, with `vctrs` loaded and `haven` absent:

| Check | Result |
|---|---|
| class after strip | `numeric` |
| `labels` attribute retained | TRUE |
| `s - 1`, `s == 1`, `2 * s`, `as.character(s)` | all OK |
| tagged-NA byte pattern before vs after | identical |
| tagged-NA tag still readable | `'r'` |

**Correction, 2026-08-28.** The first tagged-NA measurement used a
hand-built value with the tag in byte 1. That is a plain `NaN`, not a haven
tagged NA — `haven::na_tag()` returned `NA` for it. Re-measured with a
genuine `haven::tagged_na("r")`: the byte pattern is identical before and
after the strip, `na_tag()` still returns `"r"`, and the tagged-NA entry
inside the `labels` attribute stays readable. The claim holds; only the
first test construction was wrong. See `measurements.md` M11, which also
gives the correct haven-free construction (the tag byte is index 5).

And `@metadata@value_labels` already harvests `attr(col, "labels")` at
construction with base R (`R/core-metadata.R:3744`), so no label information
is lost by the strip. `haven` stays in `Suggests`, which honours the written
rule in `.claude/rules/surveycore-conventions.md`.

One site fixes all 26 failing call forms in `audit-empirical.md` §4, and it
turns `get_totals()`'s accidental correctness (§3) into designed
correctness.

### Rejected alternatives

- **Normalize per analysis entry point.** Leaves `@data` untouched, but puts
  the invariant in ~17 places instead of one, so a future `get_*()` can
  forget the line and silently reintroduce the bug. No single existing
  accessor to hook — 80 `design@data[[...]]` sites across 20 files.
- **Move `haven` to `Imports`.** One line, but it overturns a written house
  convention, leaves correctness depending on another package's S3 methods,
  and does not fix D2.

### Consequences the spec must handle

- `survey_data()` now returns plain doubles for previously labelled columns.
  This is observable. Round trips through `as_svydesign()`,
  `from_svydesign()`, `as_tbl_svy()`, `from_tbl_svy()` need checking.
- `.apply_group_labels()` keeps its `requireNamespace("haven")` for tagged
  NAs, but that call must no longer be load-bearing for correctness
  anywhere else.
- Base R `[` drops the `labels` attribute on subsets. Confirmed. Readers
  must take labels from `@metadata@value_labels` or from the full column,
  never from a subset.
- Every construction and mutation route needs the strip, not just
  `as_survey()` — the spec must enumerate them.

## D2 — The polychoric ordinal gap is in scope for this spec

**Decided**: 2026-08-27, by the user.
**Status**: SETTLED.

`get_corr(..., method = "polychoric")` rejects labelled columns with
`surveycore_error_polychoric_requires_ordinal`, because `is.ordered()` is
FALSE on a `haven_labelled` vector (measured, `audit-empirical.md` §5). D1
does not repair this: stripping the class yields a plain double, which is
still not `ordered`.

Fix it in the same spec. A real dataset read through `haven::read_sav()`
hits both defects on the first try, so shipping D1 alone still blocks
`surveyreports`.

The spec must decide how a labelled or previously labelled column is
recognised as ordinal. Candidate signals, to be settled during drafting:
value-label count, monotone integer codes, an explicit metadata marker
(`extract_higher_is()` exists and may already carry the intent).

### Rejected alternatives

- File as a separate issue and ship D1 first — leaves
  `get_corr(polychoric)` broken on every real dataset in the meantime.
- Out of scope, document the conversion requirement — pushes a
  surveycore-shaped problem onto callers.

## D3 — the D2 ordinality rule: whole-valued doubles are ordinal

**Decided**: 2026-08-28, by the user. Resolves HOLD-1 from
`comprehension.md` §14.
**Status**: SETTLED.

Extend the `is.double` branch of `.corr_detect_ordinal()`
(`R/analysis-corr-latent.R:55-63`) so a double whose non-NA values are all
whole numbers, and whose distinct count is within
`integer_cardinality_cutoff`, returns `"integer_ordinal"`. Mirror the
`is.integer` branch directly above it and reuse the same cutoff.

```r
if (is.double(col)) {
  non_na <- col[!is.na(col)]
  if (length(non_na) == 0L) return("continuous")
  if (all(non_na == trunc(non_na))) {
    n_distinct <- length(unique(non_na))
    if (n_distinct <= integer_cardinality_cutoff) {
      return("integer_ordinal")
    }
  }
  return("continuous")
}
```

### Why, and what this overturns

`measurements.md` M13 established that the gate never inspects the labelled
class. It branches on storage type, so a plain `c(1, 2, 3)` double is
refused exactly like a labelled one. The defect is therefore
**"integer-valued doubles are not seen as ordinal"**, and it has affected
every user since polychoric shipped.

The current line is deliberate. `R/analysis-corr-latent.R:60-62` says:

```r
# Integer-valued doubles with small cardinality are still continuous
# under the spec's strict reading ("is.double" -> "continuous").
```

So D3 **overturns a documented decision from the original polychoric spec**.
The user sanctioned that explicitly. The spec must say so plainly, and the
comment above must be replaced, not left contradicting the code.

The false-positive risk is bounded: `method = "polychoric"` is opt-in and
`pearson` stays the default, so no default behaviour changes. A user only
reaches the new branch by asking for polychoric.

`polyserial` shares this gate, so D3 also bears on
`surveycore_error_polyserial_requires_mixed_types` (PC-2). The spec must
confirm the polyserial pairing still resolves correctly once more columns
classify as ordinal — a pair that used to be ordinal + continuous may now be
ordinal + ordinal and trip PC-2.

### Rejected alternatives

- **Same rule plus a warning.** On a real SPSS file every scale column is a
  whole-valued double, so it would warn on the normal case and become noise.
- **New `ordinal =` argument on `get_corr()`.** Near-zero false positives,
  but the bare call keeps failing, which does not meet the acceptance
  criterion in `request.md`.
- **Defer D2 to its own issue.** Reverses the earlier in-scope call and
  leaves `get_corr(polychoric)` broken on every SPSS-sourced dataset.

## D4 — the strip needs BOTH a constructor-entry call and an S7 setter

**Decided**: 2026-08-28, from measurement. Not a user judgment call.
**Status**: SETTLED unless spec review objects.
**AMENDED 2026-08-28** — see the amendment at the end of this entry. The
original wording said one setter covers all eleven routes. Measurement
showed that is wrong for two of them.

`comprehension.md` §3 found eleven routes that write `@data` and no single
choke point among the constructors. `measurements.md` M4 then measured that
an S7 property `setter` fires **both** at construction and on `@data <-`
assignment.

So one `setter` on the `data` property (`R/core-classes.R:305-308`) covers
all eleven routes, the exported S7 class objects — which let
`survey_taylor(data = labelled_df, ...)` bypass every constructor — and any
external package that assigns `@data`, including `surveytidy`.

Supporting evidence that N constructor edits would not be enough:

- `measurements.md` M7 and M8 — labelled `weights`, labelled `fpc`, and
  labelled `ids + strata` with `nest = FALSE` all abort during
  **construction**, so the strip must run before validation.
- `audit-addendum.md` §5 — a second design built by
  `as_survey_replicate()` from the same labelled frame still failed when
  only the first design had been stripped.

### Amendment — the setter alone is not sufficient


Full evidence in `verification-d4.md`. I spiked the setter on a throwaway
copy of the package and measured every route.

The setter **does** cover the routes that matter most and that nothing else
could reach: all four constructors, a direct
`survey_taylor(data = labelled_df, ...)` call, and `des@data <- labelled_df`
assignment from an external package such as `surveytidy`. All report zero
labelled columns left in `@data`.

Two routes still abort, because they run on the **raw caller data frame**
before anything reaches `@data`, so the setter has not fired yet:

| Route | Fails at |
|---|---|
| labelled `weights` | `.validate_weights()`, `non_na == 0`, `R/core-validators.R:152`, called from `R/core-constructors.R:326` |
| labelled `fpc` | `fpc_col_j <= 0`, inline at `R/core-constructors.R:380` |

So D4 is a **two-part** design and the spec must require both parts:

1. **Strip on entry to each constructor, before validation.** One call at
   the top of `as_survey()`, `as_survey_replicate()`,
   `as_survey_twophase()` and `as_survey_nonprob()`. This is the part that
   fixes labelled `weights` and labelled `fpc`.
2. **The setter, as the backstop.** This is the part that covers the routes
   no constructor sees.

Neither part is redundant. Each reaches routes the other cannot. Five call
sites in total, against the ~17 a per-analysis-function design would need
and the 80 a per-accessor design would need.

One cost the spec must state: the setter runs on **every** `@data` write,
including inside every dplyr verb method. The helper must return early when
no column carries the class.

## D5 — `survey_data(x, haven_class = FALSE)` restores the class on request

**Decided**: 2026-08-28, by the user. Resolves HOLD-2 and BLOCK B3 from
`spec-review.md`.
**Status**: SETTLED.

Add one argument to `survey_data()`. The default keeps today's behaviour, so
arithmetic on the returned frame stays safe. `haven_class = TRUE` rebuilds
the labelled class on every column that carried it at import.

**Correction, 2026-09-02 (issue #207).** "Every column that carried it at
import" describes a provenance test. The shipped code has no such test, and
the `@return` text and §VIII.1 rule 2 both describe the code correctly: the
rebuild fires on every column carrying a `labels` attribute. So a column that
never carried the class is promoted too — an sjlabelled-native column, or one
labelled by `set_val_labels()` in data-frame mode before construction.

Issue #207 kept the attribute test and corrected the wording. The attribute
is the only thing `.restore_haven_class()` can see. A provenance record would
need new state that survives every write to the `data` property, plus
rename and select lifecycle wiring, and it would buy nothing: the promotion
is opt-in and drops no data. Read "every column that carried it at import"
above as "every column carrying a `labels` attribute". §XII.5 of the spec
carries the matching correction.

**Second correction, 2026-09-02 (issue #205).** "The attribute is the only
thing `.restore_haven_class()` can see" was true of the helper and wrong of
the feature. `survey_data()` holds `x@metadata`, and that is the store a
design's own setters write: `set_val_labels()` on a design writes
`@metadata@value_labels` and touches no column, and `set_var_label()` writes
`@metadata@variable_labels` the same way. So the rebuild returned the labels
the import set even after the analyst corrected them, and returned none at
all for a column labelled on the design — the failure the argument was
added to remove.

`survey_data()` now passes each column's two metadata entries into the
helper. The metadata wins; the column attribute is the fallback for each. The
sjlabelled promotion above is unchanged, because it comes from the fallback.

The attribute test survives in one place, and it is a consequence of this
decision, not a second one: `set_val_labels(x, v = NULL)` clears the metadata
entry and leaves the column's attribute in place, so the fallback rebuilds
the class from that attribute. Telling a cleared entry from one that was
never set needs the provenance state #207 refused.

**Third correction, 2026-09-03 (issue #206).** The value-label test decides
*whether* to rebuild. It never decided *what* the column already was, and
the rebuild wrote the class with `attr(x, "class") <- ...`, which replaces
the whole class vector. So a `factor` carrying a `labels` attribute came
back as `haven_labelled` over its level codes, with the levels gone, and a
`Date` came back as its day count. `set_val_labels()` on a data frame writes
the attribute onto any column, so a user frame reached this with no `haven`
involved, and no step warned: the labels covered every observed level, so
`surveycore_warning_missing_labels` stayed quiet too.

The rebuild now returns early on `is.object(x)`. A column that carries a
class of its own has no haven class to rebuild, and the strip only ever
removes `haven_labelled`, so a classed column reaching the helper never
carried one.

This narrows the promotion #207 settled; it does not reopen it. #207 refused
a *provenance* record — state saying which columns arrived labelled. The
class attribute is not that record. It is on the column, it costs one
`is.object()` call, and it says what the column is now rather than where it
came from.

The `label` and `labels` attributes still follow the metadata on a classed
column, the way they already did for an unclassed column that gets no class.
A variable label on a factor is what `haven::write_sav()` writes as the
variable's name, so dropping it would trade one silent loss for another.

```r
survey_data(d)
#>  q: 1 2 3                                  plain double

survey_data(d, haven_class = TRUE)
#>  q: <haven_labelled> Low, Mid, High
```

### Why an opt-in, and why this name

The problem it solves is measured in `spec-review.md` B3: `haven` and
`labelled` dispatch on the **class**, so after the strip
`haven::as_factor()` returns `1/2/3` instead of `Low/Mid/High`, and
`haven::write_sav()` writes a file whose value labels are `NULL`. Neither
raises an error.

The default stays stripped because `survey_data()` output is what
`surveyreports` and `surveytidy` consume, and restoring the class
unconditionally would push the original arithmetic failure into those
packages. Measured scale of that failure: **15 of 25** everyday operations
break on a labelled column when `haven` is absent, including
`weighted.mean()` and `ifelse()`.

The name is `haven_class`, not `labelled`, for a reason the docs must carry:
**the value labels are present either way.** Only the class varies.
`labelled = TRUE` would imply labels against no labels, which is false and
would mislead the exact person reading the argument to debug this.
`haven_class` also stays greppable for anyone asking why their column is no
longer `haven_labelled`, avoids the `set_*` and `as_*` prefixes the package
reserves for setters and constructors, and matches the existing
`label_values` / `label_vars` flag style.

### Restore the variant, not just the base class

A column that arrived as `haven_labelled_spss` must be rebuilt as
`haven_labelled_spss`, not as plain `haven_labelled`. The strip keeps
`na_values` and `na_range` (`measurements.md` M9), so the information needed
to pick the right class is still on the column. The rule: rebuild the SPSS
variant when either attribute is present, otherwise the base class.

Rebuild is lossless, verified in `spec-review.md` B3 — the reconstructed
column restores both `as_factor()` and the `write_sav()` round trip.

### `sjlabelled` needs nothing

Measured, with `sjlabelled` installed to a scratch library. The stripped
column is **identical** to what `sjlabelled` produces natively:
`sjlabelled::set_labels()` on a numeric vector returns class `numeric`
carrying `labels` and `label`, which is exactly what the strip leaves, down
to the type of the labels vector. All four readers tested —
`as_label()`, `get_labels()`, `get_label()`, `to_numeric()` — return the same
answer on the haven-class, stripped and sjlabelled-native shapes.

So two conventions exist: read the class (`haven`, `labelled`) or read the
attribute (`sjlabelled`). The strip moves the data from the first to the
second, not outside both. The spec should say this, because it bounds the
blast radius.

### `haven` in Imports stays rejected

Re-measured while answering this: promoting `haven` to `Imports` would add
**12 packages, 6 needing compilation** — `bit`, `bit64`, `clipr`, `cpp11`,
`crayon`, `forcats`, `haven`, `hms`, `progress`, `readr`, `tzdb`, `vroom`
— against a current tree of 23. That is a delimited-file reader, a time-zone
database and a 64-bit integer type, imported to obtain S3 method
registration. surveycore never reads a file. D1's rejection of that route
stands, now with a number attached.

### Scope call — `survey_data()` only

My judgment, flagged for the user to override: the argument goes on
`survey_data()` alone, not on `as_svydesign()` or `as_tbl_svy()`. Those two
are conversion functions whose contract is to produce a `survey` or `srvyr`
object; adding a labelled-class flag to them is a separate concern. Document
the boundary in their `@return` text and point at
`survey_data(haven_class = TRUE)` as the supported route.

### Amendment — rebuild with base R, not `haven::labelled()`

**Decided**: 2026-08-28, prompted by the user. Supersedes the first draft of
this decision, which called `haven::labelled()` and
`haven::labelled_spss()`.

A `haven_labelled` vector is attributes plus a class vector. Nothing about
it needs haven to construct. This whole investigation built labelled columns
with `structure()` in processes where haven was never loaded, which was the
proof sitting in plain sight.

```r
.restore_haven_class <- function(x) {
  labels <- attr(x, "labels", exact = TRUE)
  if (is.null(labels)) {
    return(x)
  }
  spss <- !is.null(attr(x, "na_values", exact = TRUE)) ||
    !is.null(attr(x, "na_range", exact = TRUE))
  attr(x, "class") <- if (spss) {
    c("haven_labelled_spss", "haven_labelled", "vctrs_vctr", typeof(x))
  } else {
    c("haven_labelled", "vctrs_vctr", typeof(x))
  }
  x
}
```

Measured against haven's own constructors on six shapes — labelled double,
integer, character, `haven_labelled_spss` with `na_values`, the same with
`na_range`, and a column holding a tagged NA:

| Check | Result |
|---|---|
| `identical()` to `haven::labelled()` / `labelled_spss()` output | **TRUE, all six** |
| class chain matches the original exactly | TRUE, all six |
| attribute set matches | TRUE, all six |
| `inherits(x, "haven_labelled")` | TRUE |
| `vctrs::vec_ptype()` accepts it | TRUE |
| `haven::as_factor()` labels | correct, all six |
| `labelled::to_factor()` labels | correct, all six |
| `haven::write_sav()` round trip | labels preserved on all but the tagged NA, which fails identically from haven's own constructor |

Full evidence in `verification-d5.md`.

**What this buys.** Three things, and the third is the best of them:

1. It removes the runtime `haven` requirement, so the typed error for
   "haven is missing" is no longer needed. One fewer error class, one fewer
   `plans/error-messages.md` row.
2. It honours `.claude/rules/surveycore-conventions.md`, which already says
   to read label attributes with base R and never to call
   `haven::var_label()`. Writing the class back with base R is the same rule
   in the other direction.
3. `haven_class = TRUE` now works **even when haven is not installed**. A
   user on a machine without haven can still produce a properly classed
   column to hand to a colleague who has it, or to write out later. Calling
   `haven::labelled()` would have made the argument fail exactly where
   surveycore's whole premise is that haven is optional.

**The one trade-off, stated.** Base R hardcodes the class chain, so if haven
ever changed it, the restore would produce a stale chain, whereas
`haven::labelled()` would track upstream. Judged acceptable: the chain is de
facto public API that `vctrs` dispatch depends on, and D1 already depends on
the same stability when it reads the attributes. The test-spec should pin
the expected chain so an upstream change fails loudly rather than silently.

**A second, smaller trade-off.** Base R construction skips haven's input
validation, which checks that `labels` is named and shares the type of `x`.
That is correct here, because this path **restores** attributes that came
off a valid labelled column rather than constructing from user input. If a
caller had hand-set a malformed `labels` attribute before construction, the
strip keeps it and the restore re-attaches a class over it. Worth one
sentence in the spec; not worth validating for.

### Rejected alternatives

- **Always restore in `survey_data()`.** Least surprising for an analyst,
  no new API, but it moves the arithmetic failure into `surveyreports` and
  `surveytidy`.
- **Rebuild by calling `haven::labelled()`.** The first draft of this
  decision. Rejected: it needs haven at runtime, which contradicts the
  package's own convention and would break the argument on exactly the
  machines where haven is absent.
- **Document the boundary and change no code.** Smallest diff, and more
  defensible than it first looked now that `sjlabelled` is known to be
  unaffected. Rejected because the remaining failure — an SPSS export losing
  every value label — is silent, and the user has to remember it forever.
- **`labelled`, `haven_labelled`, `restore_class`, `set_haven`** as names.
  Reasons above.

---

## D6 — a new per-argument error class validates the `haven_class` flag

**Status**: SETTLED by the user, 2026-08-31, at Stage 1 of pipeline-implement.
**Raised as**: HOLD-3 by the planner.

### The conflict

Two sentences in the frozen spec could not both hold.

`spec.md` §VIII.1 rule 7 said: "validate it the way the package validates
other scalar flags and reuse the existing class."

`spec.md` §IX.1a said: "`plans/error-messages.md` gains no row and loses
none."

There is no generic scalar-flag class to reuse. Every scalar-flag class in
the package names its own argument:

| Class | Site |
|---|---|
| `surveycore_error_subset_not_logical` | `plans/error-messages.md:54`, row 22 |
| `surveycore_error_na_rm_not_logical` | `R/analysis-helpers.R:692` |
| `surveycore_error_sata_not_logical` | `R/core-metadata.R:2816` |
| `surveycore_error_fill_not_logical` | `R/core-metadata.R:2933` |
| `surveycore_error_reverse_coded_not_logical` | `R/core-metadata.R:3260` |

So "the way the package validates other scalar flags" **is** a new
per-argument class. Rule 7's own instruction defeats its second clause.

### Decision

Add one row: `surveycore_error_haven_class_not_logical`.

```r
cli::cli_abort(
  c(
    "x" = "{.arg haven_class} must be {.code TRUE} or {.code FALSE}.",
    "i" = "Got {.obj_type_friendly {haven_class}}."
  ),
  class = "surveycore_error_haven_class_not_logical"
)
```

### Why §IX.1a said otherwise

§IX.1a's "no new row" was written about two **withdrawn** classes — a
warning fired when the strip runs, and an error for "`haven` is not
installed" under `haven_class = TRUE`. Both were correctly withdrawn. Neither
is the flag validation. The section states a count it never checked against
rule 7, so the count was wrong, not the reasoning.

### Rejected alternatives

- **Reuse `surveycore_error_na_rm_not_logical`.** Keeps §IX.1a's count
  literally true. Rejected: the message names `na.rm`, an argument
  `survey_data()` does not have, so the error misdirects the caller who is
  debugging.
- **No typed class.** Rejected: `.claude/rules/code-style.md` requires
  `class=` on every `cli_abort()` call, no exceptions. It also cannot be
  tested with `expect_error(class = ...)`, which
  `.claude/rules/testing-standards.md` requires for a user-facing
  constructor error.

### Consequent edits

| File | Change |
|---|---|
| `spec.md` §VIII.1 rule 7 | Name the new class in place of "reuse the existing class" |
| `spec.md` §IX.1a | Heading and count become "one new row, none removed"; third table row records the class |
| `test-spec.md` D-22 | Expected class becomes the named class |
| `test-spec.md` §5 | Class row names the class |
| `plans/error-messages.md` | Gains one row — carried by PR 4 |

---

## D7 — the nine-PR shape: split the strip PR at the gate seam, split the close-out out of the ordinality PR

**Status**: SETTLED by the user, 2026-08-31, at Stage 3 of pipeline-implement.
**Raised as**: findings R1, R2 and R3 of `plan-review.md` pass 1.

### The problem

Version 1.0 of `implementation-plan.md` had seven PRs. Two broke the size
limits in `.claude/rules/github-strategy.md` (one logical unit per PR) by a
wide margin:

| PR | Tasks | Files | Limit |
|---|---|---|---|
| old PR 3 — the whole §III strip | 25 | 10 | 10 tasks, 5 files |
| old PR 7 — ordinality plus close-out | 29 | 8 | 10 tasks, 5 files |

Old PR 3 also carried a justification with two bad arguments. Both are
recorded here so they do not come back:

1. **"Two PRs would share `R/utils.R`, so they could never run concurrently.
   Splitting buys no parallelism."** A non-sequitur. Blocking concurrency is
   a reason not to parallelise a split, not a reason not to split. The same
   plan sequences PR 3a → PR 4 across that same file.
2. **"Neither half alone satisfies gates 8 and 9, so they must land in one
   merge."** The plan itself completes gate 15 across four PRs and gate 16
   across every PR, then confirms each at the end. Gate atomicity was a
   policy choice presented as a technical necessity.

### Decision

Nine PRs:

```
PR 1 → PR 2 → PR 3a → PR 3b → (PR 4 ‖ PR 6) → PR 5 → PR 7 → PR 8
```

**The strip PR splits at the gate seam.** The two halves of §III each have
their own gate, so the gates name the seam:

| PR | Content | Gate |
|---|---|---|
| PR 3a | the two `R/utils.R` helpers plus the S7 setter on the `survey_base` `data` property (§III Part 2) | 8 |
| PR 3b | the four constructor-entry strip calls (§III Part 1) | 9 |

Gates 17 and 18 — both recorded measurements, not pass-or-fail — go to
PR 3a, which adds the setter whose cost and non-recursion were measured.

**The ordinality PR sheds its close-out.** PR 7 keeps §I items 4 and 7. A new
PR 8 carries the whole-feature verification: gates 4, 5, 6, 15 and 16, plus
the `plans/error-messages.md` row-count check from D6.

### The intermediate state is safe

After PR 3a merges and before PR 3b merges, a frame whose `weight` or `fpc`
column carries the labelled class still aborts with `vctrs_error_ptype2`.
That is today's behaviour on `develop`, so it is not a regression.

It is also invisible to CI. The rows that exercise that failure — S-14 to
S-20 and the rest of `test-spec.md` §4.2 — live in
`tests/testthat/test-labelled-storage.R`, a file PR 3b creates. At PR 3a's
merge point that file does not exist, so no new test fails and both
`devtools::test()` and `devtools::check()` pass.

### Two consequences worth recording

**PR 8 needs a write surface.** A verification-only PR has an empty diff and
cannot be opened. PR 3a and PR 7 each append an entry under a
`## Breaking changes` heading, so `NEWS.md` ends with two such headings.
PR 8 merges them and orders the five entries. The work can only be done
last, and it gives gate 15 a PR that makes it true rather than one that only
observes it.

**PR 8 diffs against `cf6f153`, not `develop`.** By the time PR 8 opens,
`develop` carries the whole feature, so `git diff develop` is empty and every
whole-feature check would pass without testing anything. The base commit is
the only comparison that means something.

### Rejected alternatives

- **Split the strip PR only, eight PRs.** Keeps the close-out inside PR 7 as
  a labelled final phase. Rejected: PR 7 stays at 29 tasks, so the finding
  is reworded rather than fixed.
- **Keep seven PRs and fix the reasoning.** Rewrite old PR 3's justification
  to drop the two bad arguments and collapse the described steps to bring
  task counts down on paper. Rejected: it accepts a 10-file review in one
  merge and answers a size problem with wording.
