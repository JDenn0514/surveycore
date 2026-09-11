# Changelog: fix/as-svydesign-domain

**Branches:** `fix/as-svydesign-domain-taylor`,
`test/as-svydesign-domain-edge-cases`,
`fix/as-svydesign-domain-replicate-nonprob`,
`fix/as-svydesign-domain-twophase`, `docs/as-svydesign-domain`
**PRs:** #266, #267, #268, #269, and this PR
**Issues:** #245
**Status:** Complete
**Date:** 2026-09-11

## Summary

Closes #245. `as_svydesign()` now returns an object restricted to the active
domain: a filtered design converts to the domain and not to the full stored
sample. `as_tbl_svy()` inherits the change, because it calls `as_svydesign()`
and wraps the result.

`filter()` in surveytidy keeps every row and marks domain membership in a
column. The conversion passed that column through as ordinary data and
installed no restriction, so `survey::svymean()` on the converted object
answered for every row. The point estimate was wrong, not the standard error
alone, and nothing signalled it. The roxygen documented the defect as intended
behaviour and told the caller to subset the returned object by hand.

One internal helper now applies the domain, on the object each route has just
built and immediately before it returns. Four input shapes — Taylor,
replicate, and both non-probability shapes — come back with one row per marked
row. The two-phase shape is the exception: `survey`'s own `[` method keeps
every row and gives each excluded row an infinite probability, which weights it
out of every estimate, so its row count does not change. A row whose marker is
`NA` counts as outside the domain. A design that was never filtered carries no
marker column and converts unrestricted. The conversion stays silent on every
route, including a domain that matches no row; the input design is never
restricted, and a second conversion of the same design gives the same object.

A round trip through `from_svydesign()` recovers the restricted rows and not
the original sample. On the four routes that remove rows the rebuilt design's
row count is its new total, and the original row count is unrecoverable,
because a `survey` object records a subset and not a marker. The all-`TRUE`
marker column travels back, so the rebuilt design prints `Domain: n of n rows`.
The two-phase route is again the exception: it removes no row, so the round
trip recovers the marker at both levels and the rebuilt design prints two
different counts.

The two-phase estimator difference is unchanged. surveycore's two-phase
estimator weights by the phase-1 weight column and `survey`'s two-phase object
weights by the combined two-phase probability, so the two answer 58.458 against
58.067 on the measured filtered design and 48.9245 against 49.20304 on the same
design unfiltered. The gap is independent of the domain and predates this work.
Refs #261.

## Files Modified

- `R/methods-conversion.R` — adds the internal restriction helper, calls it
  from the Taylor, replicate and two-phase routes, and rewrites the
  `@section A filtered design's domain:` block and one `@return` sentence
- `tests/testthat/test-conversion.R` — parity blocks for all five input
  shapes, the marker column's edge cases, and the round trip
- `man/as_svydesign.Rd` — regenerated

## Changes

- Restrict a converted Taylor design to the active domain (#266)
- Pin the marker column's edge cases and the round trip (#267)
- Restrict a converted replicate design, and both non-probability shapes,
  to the active domain (#268)
- Restrict a converted two-phase design to the active domain, by weighting the
  excluded rows out rather than by removing them (#269)
- Rewrite the documentation that described the old behaviour as intended, and
  state per route what the restriction does, what a round trip recovers, and
  how `srvyr`'s `filter()` differs from surveycore's

## Verification

- `survey::svymean()` on the converted object matches `get_means()` on the
  filtered design on all five input shapes: point estimates to 1e-10, standard
  errors to 1e-8. The two-phase shape is measured against a hand-restricted
  two-phase object, because its estimator difference predates the domain.
- The suite on `develop` at `d5dcca4` reports 11800 passing expectations and
  no failure. Package coverage is 96.25%.
