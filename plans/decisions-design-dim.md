# Decisions — design-dim (issue #203)

Every decision below is settled. Each cites the evidence it rests on.
Measured evidence lives in `measurements.md` in this directory.

---

## D1 — delegate to `@data`, do not error (SETTLED)

**Question.** Should `dim()` on a survey design return `c(nrow, ncol)` of
`@data`, or raise a typed error naming `survey_data()`?

**Decision.** Delegate. `dim(design)` returns `dim(design@data)`.

**Why.**

1. A design has exactly one `@data` frame with one unambiguous row count and
   column count. There is no ambiguity for an error to protect the user from.
2. The row count is the number the caller wants. `measurements.md` §Pass 1
   records `nrow(d)` matching `nrow(survey_data(d))` on all four classes.
3. It fixes the reported use case directly. The surveywts example in issue
   #203 called `nrow(design)` before and after `adjust_nonresponse()`, which
   physically drops rows. Delegation makes that example print the two counts
   it always claimed to print. An error would leave it broken, only loudly.
4. It matches the neighbourhood. `R/methods-compat.R:23` already delegates
   `names()` to `names(x@data)` for exactly this reason. A `dim()` that errors
   beside a `names()` that delegates would be incoherent.
5. The issue itself recommends it, and its fallback ("make them error") is
   offered only for the case where delegating is unwanted because a design is
   not a table. The measurement shows delegating costs nothing, so that case
   does not arise.

**Rejected alternative.** A typed error naming `survey_data()`. It teaches the
user the right function but refuses to answer a question that has an answer,
and it would make `nrow()` on a design the only base-R size function in the
package that raises.

---

## D2 — the regression surface is measured and clean (SETTLED)

**Question.** What does a non-NULL `dim()` change? `nrow()` and `ncol()` are
not generic, so `dim()` is the only lever, and a non-NULL `dim()` is the flag
base R and third-party code read to treat an object as array-like.

**Decision.** Proceed. The surface is six probes wide, and five of the six are
the intended fix.

**Evidence.** `measurements.md`, four passes, 264 probe rows, each run twice
and compared with `diff -u`:

- Pass 1 (200 rows, base R, four design classes): six probes changed. Five
  are `dim`, `nrow`, `ncol`, `NROW`, `NCOL`. The sixth is the `apply()` error
  text, which stayed an error.
- Pass 2 (36 rows, surveytidy 0.6.1 + dplyr 1.2.1 installed): the same five
  size probes changed, nothing else. Ten `dplyr` verbs return live designs in
  both runs.
- Pass 3 and 4 (28 rows, `survey_collection`): see D3.
- Full test suite: `FAIL 0 | WARN 256 | SKIP 4 | PASS 10872`, identical
  before and after. No `_snaps/` entry drifted.
- `R CMD check`: 0 errors, 0 warnings, 1 note, and the note is the `.git`
  entry a worktree carries.
- `vignettes/` and `man/`: zero calls to any of the five affected functions.
- `R/`: 137 `nrow`/`ncol`/`dim`/`NROW`/`NCOL` call sites read, across 40
  files. None takes a design.

**The mechanism, measured rather than argued.** `is.matrix()` and `is.array()`
stayed `FALSE`. They are internal and read the object's real `dim`
**attribute**; an S7 object has none. `nrow()` and `ncol()` call the `dim()`
**generic**, which the new method serves. So the fix reaches the size
functions without opening the gate that hands the object to array code. Every
coercion and subsetting route (`as.matrix`, `as.data.frame`, `t`, `head`,
`tail`, `[`, `[[`) fails earlier than `dim()` matters, before and after alike.

**Consequence for the pipeline tier.** The premise that made this a Full-tier
request — an unmeasured regression surface — is now measured and small. See
"Tier recommendation" below.

---

## D3 — `dim()` on `survey_collection` raises a typed error (SETTLED)

**Question.** `survey_collection` is not a child of `survey_base`
(`R/core-classes.R:949` declares no `parent`) and holds `@surveys`, not
`@data`. A method on `survey_base` leaves `nrow(collection)` returning `NULL`
— the exact defect issue #203 is about. What should the spec do?

**Decision.** Add a second method. `dim()` on a `survey_collection` raises
`surveycore_error_collection_no_dim`. Base `nrow()` and `ncol()` are
`dim(x)[1L]` and `dim(x)[2L]`, so they raise the same error, which is the
intent.

**Decided by the user**, 2026-09-04, after `measurements.md` §Pass 3 showed
the gap. Options offered: leave it `NULL` with a follow-up issue; cover it by
delegating to some member-derived shape; make it a typed error. The user chose
the typed error.

**Why an error and not delegation here.** A collection holds several surveys,
each with its own row and column counts. There is no single answer to return,
so this is the case D1 explicitly did not face. `length()` and `names()`
already answer the container-shaped questions — member count and member names
— and they keep doing so.

**One measured cost, flagged for a deliberate look.** `measurements.md`
§Pass 4:

| | Clean tree | After |
|---|---|---|
| `NROW(collection)` | `2L` | typed error |
| `NCOL(collection)` | `1L` | typed error |

`NROW()` falls back to `length(x)` when `dim(x)` is `NULL`, and `length()` on
a collection is the member count. So `NROW(cl) == 2` was a defensible answer
for a 2-member container, and it now raises. Across all 264 probe rows this is
the only call that moves from a reasonable value to an error. Nothing in `R/`,
`tests/`, `vignettes/` or `man/` calls `NROW()` or `NCOL()` on a collection,
so nothing inside the package breaks; the exposure is user code and downstream
packages.

Reversing this decision is a one-line change to the spec (drop the
`survey_collection` method, restore the follow-up issue), and it costs nothing
after implementation begins beyond the test rows for that method. Recorded
here so the choice stays visible rather than buried.

**Also measured, and an argument for the decision.** `print()` on a
collection is unaffected, because `.fmt_collection_line()`
(`R/methods-print.R:926`) reads `nrow(s@data)` per member rather than
`nrow(collection)`. And `nrow(cl[[i]])` moves from `NULL` to a real count
under the `survey_base` method, so looping members and asking each for its
size starts working — a `vapply()` over members that fails on the clean tree
returns `c(60L, 60L)` after.

---

## D4 — `length()` is untouched (SETTLED)

**Question.** `length()` on a design returns `1`. Change it?

**Decision.** No. Out of scope, per `request.md` §Out of scope and the
handoff. The issue calls `1` defensible for an S7 object.

**Measured note.** `length()` is the reason `NROW()` returned `1L` rather than
`NULL` before this fix: `NROW()` falls back to `length(x)` when `dim(x)` is
`NULL`. After the fix `NROW()` reads `dim(x)[1L]` and never consults
`length()`, so the fix removes the only way a user was likely to meet that
`1`. Leaving `length()` alone therefore costs less after this change than
before it.

`S7::method(length, survey_collection)` already exists
(`R/methods-print.R:978`) and returns the member count. It is not touched.

---

## D5 — `NEWS.md` is untouched (SETTLED)

Per the handoff. Two other worktrees run in parallel and share the insertion
point. The entries for all three fixes land in one direct commit to `develop`
after the PRs merge.

---

## Tier recommendation — for the user to decide

The request was routed Full-tier because the regression surface was unmeasured
and the handoff called the smallness test ambiguous. D2 resolves that: the
surface is six probes wide, the suite is identical on all four counters, and
`R CMD check` is clean.

`pipeline-simplified` is now a defensible route. Its smallness criteria are
met on every axis — two files, no new export, no algorithmic change — and the
one thing that made the change risky is measured.

Two facts argue for keeping a real review anyway, and they arrived from the
measurement rather than from caution:

1. The change is no longer three lines on one method. D3 added a second
   method with a new error class, which needs a row in
   `plans/error-messages.md` and the dual test pattern
   (`expect_error(class=)` plus `expect_snapshot(error = TRUE)`).
2. `NROW(collection)` and `NCOL(collection)` go from a value to an error.
   That is a behaviour change on a working call, on a class issue #203 never
   mentions.

Recommendation: **downgrade to `pipeline-simplified`**, with the two artifacts
already written carried in as the planner input. The tester remains the
quality gate, and the spec plus this measurement give it everything the full
reviewer would have read. The user's call.
