# Request: fix the svydesign replicate bridge

Issues: #197, #198. Both live in `R/methods-conversion.R`, about 150 lines
apart, and both come from reading `x$repweights` without checking what it
holds.

## Intent

The two conversion routes between surveycore and the `survey` package must
carry a replicate design across intact, in both directions.

## #197 — `from_svydesign()`, two failures

1. Replicate column names come from `colnames(x$repweights)`, which is empty
   for every design `survey::as.svrepdesign()` produces. The converted object
   keeps no replicate weights and says nothing. The error surfaces later, in
   `.svy_rep_var()`, pointing somewhere else.
2. When names do exist, `x$combined.weights` is ignored. A
   replication-factor design converts as if its columns were finished
   weights, and standard errors come out about 35% too small.

## #198 — `as_svydesign()`, one failure

`.as_svydesign_replicate()` passes the per-row FPC column to
`survey::svrepdesign()`, which wants one value per replicate. Any replicate
design carrying an FPC fails with `fpc is wrong length`, and `as_svydesign(x)`
takes only `x`, so there is no workaround at the call site.

## Why now

This is the last CRAN-release blocker on the open-issue list. #197 returns
wrong standard errors silently, which is the one failure a released version
should not carry.

## Out of scope

- `NEWS.md` (written in one commit after all three parallel PRs merge)
- Anything in `R/methods-conversion.R` outside the two replicate routes
