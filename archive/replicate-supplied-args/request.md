# Request — replicate-supplied-args

## Intent
Implement GitHub issue #255. `as_survey_replicate()` must treat a supplied
`scale`, `rscales` and `rho` the way `survey::svrepdesign()` does: discard the
argument for the types `survey` overrides, store the type's own value, and
raise a typed warning (none for Fay `scale`). `as_svydesign()` must stop
passing `scale` for the five types `survey` overrides. The issue also carries
the JKn half of #244: JKn with no `rscales` is refused; JK2 is not.

## Acceptance criteria
- For BRR, Fay, JK2, ACS and successive-difference, an explicit `scale` is
  discarded and the type's own value stored. BRR, JK2, ACS and
  successive-difference raise a typed warning; Fay raises nothing.
- For JK2, ACS and successive-difference, an explicit `rscales` is discarded
  and `rep(1, R)` stored, with the same warning.
- No warning fires when the caller supplies neither, on any of the nine types
  (D8 divergence from `survey`'s unconditional JK2 warning; stated in
  `@param scale`).
- `as_survey_replicate(type = "JKn")` with no `rscales` raises
  `surveycore_error_stratified_jk_rscales_unset`.
- `as_survey_replicate(type = "JK2")` with no `rscales` still builds.
- A `rho` supplied for any type but Fay raises a typed warning and is
  discarded (check what #243 already shipped; do not duplicate).
- For JK1, JKn, bootstrap and other, an oracle test passes the same explicit
  `scale` to both packages and asserts the SEs agree to 1e-8.
- `as_svydesign()` on a design with an explicit non-default scale reproduces
  surveycore's SE, for all nine types.
- New warning class row(s) in `plans/error-messages.md` before the code. One
  class for "the type ignores this argument", argument name in the bullet.
- `as_survey_nonprob()` keeps refusing both JK2 and JKn with no `rscales`
  (D1); its roxygen gains a sentence on the divergence.

## Attachments
- `issue-255.md` (this directory) — the full issue body, with the
  per-type table read from `survey:::svrepdesign.default`.
- `plans/issue-cleanup.md` D1, D4, D7, D8, D10 — the locked decisions.
