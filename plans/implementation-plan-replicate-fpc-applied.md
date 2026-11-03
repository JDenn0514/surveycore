# Implementation plan: replicate designs record the FPC (#320)

**Tier:** 2 (plan only) per `.claude/rules/github-strategy.md` — a new argument
form, two new `@variables` keys, and an approach that needed pinning down.
**Branch:** `feature/replicate-fpc-applied`, off `develop` at `d1c8527`.
**Issue:** #320. **Depends on:** #251 (PR #321, `2de9c9b`). **Unblocks:**
surveywts#130, which sets `fpc_applied` on every design `create_*_weights()`
builds.
**Decision record:** D12 in `plans/issue-cleanup.md`, amended for #320.
**Register:** `plans/error-messages.md`, block "replicate-fpc-applied rows";
RF-1 restated, RF-1b, RF-2, RF-3a–g, RF-4 new, CB-3 trigger updated.

## Decisions confirmed before code (2026-10-16)

The issue carried three decisions that had not been reviewed, and step 3 of
the brief turned up a fourth. All four were confirmed with the maintainer.

| # | Question | Decision |
|---|---|---|
| a | A second key, `@variables$fpc_fraction` | Keep it, and validate it. RF-4 covers both keys. |
| b | `fpctype` default | **Required** whenever `fpc` is given, as in `survey` (line 133). The issue proposed defaulting to `"fraction"`; that loses, because `0.9` reads as `f` or as `1 - f` and the two give very different SEs. Exact match only: no partial matching. |
| c | Telling a column from a number | As the issue says — a bare symbol naming a column of `data` is a column and is refused, even when a same-named variable exists; `.env$f` gets around it — plus two edges: a single string naming a column is also a column, and an evaluation error raises RF-3c with the R error as parent. |
| d | `from_svydesign()` | `survey` stores no `fpc` field (see below). Set `fpc_applied = "rscales"` when `x$call[["fpc"]]` is not `NULL`; `NULL` otherwise. `fpc` and `fpc_fraction` stay `NULL`: the stored call is not evaluated. |

### What `survey` stores (step 3 of the brief)

`survey:::svrepdesign.default`, deparsed on survey 4.5, lines 132-147: given
`fpc`, it requires `fpctype`, refuses BRR/Fay/JK2/ACS/successive-difference
("fpc not available for this type") and bootstrap ("Separate fpc not needed
for bootstrap"), requires `length(fpc) == length(rscales)`, refuses values
outside `[0, 1]`, converts a fraction to `1 - f`, and multiplies `rscales`.
`rscales` defaults to `rep(1, R)` first (line 130-131).

The returned object has `type, scale, rscales, rho, call, combined.weights,
variables, pweights, repweights, degf, mse` — **no `fpc` field**. The only
record is `x$call`, from `sys.call()`, where `fpc` survives as an unevaluated
expression. `as.svrepdesign()` keeps no trace either: its call is
`as.svrepdesign.default(design, type = ...)`, and the FPC came from the source
design, which is not stored. So the issue's "when the source carries one"
can only mean "when `x$call` names `fpc`".

## Behaviour

### `as_survey_replicate(fpc = , fpctype = )`

Order of checks, first to last:

1. **RF-1b** — `fpctype` non-`NULL`, `fpc` `NULL`. Unchanged position.
2. **RF-1** — `fpc` is a bare symbol, or a single string, naming a column of
   `data` (when `data` is a data frame). Unchanged position: before
   `.validate_data_frame()`.
3. Existing checks: data frame, weights, repweights, `rscales` length,
   JKn requires `rscales` (RS-2), Fay `rho`.
4. **RF-2** — numeric `fpc` with a type other than JK1, JKn, other.
5. **RF-3a/b** — `fpctype` missing, or not exactly one of the two strings.
6. **RF-3c–g** — evaluate `fpc` (`rlang::eval_tidy(quo, data = list())`, so
   `.env` works); then non-numeric/`dim`, length not 1 or `R`, non-finite,
   out of range.
7. Apply: `f <- if fraction fpc else 1 - fpc`, recycled to `R`;
   `rscales <- (rscales, or rep(1, R) when NULL) * (1 - f)`, where `1 - f` is
   the caller's own value for `"correction"`, so the multiplier is exactly
   the one `survey` uses.

Stored: `rscales` adjusted, `fpc = NULL`, `fpctype = "fraction"` (unchanged
placeholder; `fpc_fraction` is always a fraction whatever was passed),
`fpc_applied = "rscales"`, `fpc_fraction = f` (length `R`, unnamed double).
No `fpc`: `fpc_applied = NULL`, `fpc_fraction = NULL`.

The FPC block runs after the `rscales` checks so that `.validate_rscales()`
sees the caller's `rscales`, not the product, and RS-2 still fires for JKn
without `rscales`.

### The two keys

| `fpc_applied` | Meaning |
|---|---|
| `"rscales"` | The correction is inside `@variables$rscales`. |
| `"repweights"` | The correction is inside the replicate weight columns. |
| `"none"` | An FPC was available and was not applied. |
| `NULL` | No FPC was available, or the design predates the key. |

With `fpc` set and `fpc_applied` `NULL`, the state is **unknown**. A missing
key reads as `NULL` everywhere (`x@variables[["fpc_applied"]]`), because
surveywts and saved objects build lists without it.

### Validator (RF-4, Layer 1)

`survey_replicate`'s validator rejects `fpc_applied` outside `NULL` and the
three strings, and `fpc_fraction` that is not `NULL` or a finite numeric vector
in `[0, 1]` (closed: `1 - c` rounds to 1 for a tiny correction) of length `length(repweights)`. One class,
`surveycore_error_replicate_fpc_record_invalid`. No cross-key coupling.

### `print()` / `summary()`

One helper in `R/methods-print.R`, `.print_replicate_fpc(x, style)`, used by
both replicate sites (they are the same rule; DRY). Subject: the column if
recorded, else `f = a` / `f = a to b` from `fpc_fraction`, else none.

| State | Line |
|---|---|
| `"rscales"` | `FPC: <subject> (applied in replicate scales)` or `FPC: applied in replicate scales` |
| `"repweights"` | `FPC: <subject> (applied in replicate weights)` or `FPC: applied in replicate weights` |
| `"none"` | `FPC: <subject> (not applied)` or `FPC: not applied` |
| unknown | `FPC: <col> (application not recorded)` |
| no FPC | `print()`: `FPC: not specified` (as today); `summary()`: no line (as today) |

The old `(<fpctype>)` suffix goes. The `survey_taylor` and two-phase print
sites do not change.

### `as_svydesign()` (CB-3)

Warn only in the unknown state. Pass no `fpc` to `svrepdesign()` in every
state, which is today's call. The warning gains one `"i"` bullet: the design
does not record whether the correction is already applied.

### `from_svydesign()`

Initialise both keys. `fpc_applied = "rscales"` when
`is.call(x$call) && !is.null(x$call[["fpc"]])`; else `NULL`.

## Must not change

- `R/variance-replicate.R` byte-identical (checked with `git diff --stat`).
- Taylor FPC paths and Taylor/two-phase print sites.
- The column refusal (RF-1) and its class.
- No existing number: a call that built before #320 builds the same design
  plus two `NULL` keys.

## Write surface

`R/core-classes.R` (validator, `@variables` docs), `R/core-constructors.R`
(the FPC block, roxygen), `R/methods-conversion.R` (CB-3 gate, import keys),
`R/methods-print.R` (helper, two sites), `plans/error-messages.md`,
`plans/issue-cleanup.md`, `man/` (regenerated), `tests/`, `NEWS.md`,
`changelog/feature-replicate-fpc-applied.md`.

## Tests

`test-constructors.R`
- Oracle, JK1 / JKn / other × `fpctype` fraction / correction × scalar /
  length-`R` vector against `survey::svrepdesign(fpc = , fpctype = )`. Mean
  1e-10, SE 1e-8. Pass `scale` to neither side; `rscales` to JKn only, the
  same literal both sides. Survey's own warnings (JK1 "guessing n", other
  "set to 1") asserted by message text, not silenced (oracle rule 5).
- Stored keys: `fpc_applied`, `fpc_fraction` (fraction and correction give
  the same `f`), `rscales` product, `fpc` stays `NULL`; JK1 with `NULL`
  rscales starts from `rep(1, R)`; a supplied JK1 `rscales` is multiplied.
- RF-1: bare column refused with a same-named numeric variable in the
  caller's frame; string column refused; `.env$f` accepted and gives the same
  design as the literal. Dual pattern.
- RF-1b dual pattern (snapshot updated for the new message).
- RF-2: every refused type (BRR, Fay, JK2, bootstrap, ACS,
  successive-difference) by class; snapshots for one ordinary type and
  bootstrap.
- RF-3a–g: one block each, dual pattern.
- RS-2 still fires for JKn with `fpc` and no `rscales`.
- `test_invariants()` key list gains both keys for replicate designs
  (`helper-test-data.R`), so every `as_survey_replicate()` /
  `from_svydesign()` file call checks them.
- Existing #251 blocks rewired: `no_such_column` and `starts_with()` now
  reach RF-3c; the "both supplied" block reads the column message; the
  `rscales * (1 - f)` oracle block stops passing `scale = 1` to `survey`
  (oracle rule 2; JKn's `survey` default is 1, so the number does not move).

`test-s7-classes.R` — validator rejects `fpc_applied = "maybe"`, a bad
`fpc_fraction` (wrong length, out of range, non-numeric); accepts each valid
state and a missing key. `class =` only.

`test-methods-print.R` — snapshots for `print()` and `summary()` in all four
states plus the numeric-fpc (fraction subject) and no-subject `"rscales"`
lines.

`test-conversion.R` — `as_svydesign()` warns in the unknown state only;
`"rscales"`, `"repweights"`, `"none"` raise nothing; SE matches surveycore's
to 1e-8 in all four; numeric-`fpc` design's export passes no `fpc` (its call
names none, `rscales` equals the stored product) and SE matches, so no double
application. `from_svydesign()`: an `svrepdesign(fpc = )` source imports
`"rscales"`; a source without `fpc` and an `as.svrepdesign()` source import
`NULL`; both keys present.

## Environment notes (this session)

R 4.6.1 with survey 4.5 is installed, as is `air`. `srr` and `surveytidy` are
not: `devtools::document()` fails on the srr roclet, so use
`roxygen2::roxygenise(roclets = c("rd", "namespace", "collate"))`; the
surveytidy-dependent tests error locally and run in CI.
