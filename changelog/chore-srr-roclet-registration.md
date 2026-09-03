# Changelog: chore/srr-roclet-registration

**Branch:** `chore/srr-roclet-registration`
**Status:** Complete
**Date:** 2026-09-03

## Summary

Fixes #160: `DESCRIPTION` set `Roxygen: list(markdown = TRUE)` and named no
roclets, so `srr::srr_stats_roclet` was never registered. roxygen2 did not know
the `@srrstats`, `@srrstatsNA`, and `@srrstatsVerbose` tags and discarded all
138 of them, spread across five files:

| File | Tags |
|---|---|
| `R/srr-stats-standards.R` | 82 |
| `R/glm.R` | 18 |
| `R/glm-methods.R` | 17 |
| `R/analysis-helpers.R` | 15 |
| `R/core-validators.R` | 6 |

`devtools::document()` printed one `is not a known tag` line per tag on every
run. The rOpenSci standards claims are the artifact under review, so they have
to compile.

The `Roxygen` field now names the roclet alongside the three roxygen2 defaults:

```
Roxygen: list(markdown = TRUE, roclets = c("collate", "namespace", "rd",
    "srr::srr_stats_roclet"))
```

**No behaviour changes, and no generated output changes.** `man/` and
`NAMESPACE` are byte-identical. This was measured, not assumed: `document()`
ran on a clean tree before the edit and left the tree clean, then ran again
after it, and `git diff man/ NAMESPACE` is empty both times.

After the change the roclet reports every standard:

```
── @srrstats standards (108 / 150)
── @srrstatsNA standards (42 / 150)
```

`srr::srr_stats_pre_submit(".")` now reports clean:

> All applicable standards [v0.2.0] have been documented in this package
> (108 complied with; 42 N/A standards).

`devtools::check()` gives 0 errors, 0 warnings, 1 note. The note is `.git`
found in the package directory, which is an artifact of checking inside a git
worktree.

### The one warning this change introduced

The roclet makes roxygen2 parse `tests/` as well as `R/`, which it did not do
before. That surfaced an Rd link in a test helper:

```
✖ helper-test-data.R:599: @description Could not resolve link to topic
  "make_labelled" in the dependencies or base packages.
```

`make_labelled()` is a test helper with no Rd topic, so `[make_labelled()]`
has nothing to resolve to. The link is now plain code formatting.

### One warning left, and it is not this one

`document()` still prints one warning, present both before and after this
change:

```
✖ analysis-corr.R:49: @param failed to evaluate inline markdown code.
! Failed to parse the inline R code: `r = NA`
```

`R/analysis-corr.R:64` writes a backtick span that starts with `r `, and
roxygen2 reads that as inline knitr R code. roxygen2 recovers and writes the
correct `\code{r = NA}` to `man/get_corr.Rd:53`, so the cost is noise, not a
wrong man page. Filed separately as #230 and left alone here.

### No new dependency

`srr` is used only at `document()` time. No CI workflow runs `document()` —
`.github/workflows/` holds `pkgdown.yaml`, `R-CMD-check.yaml`, and
`test-coverage.yaml`, and none of them calls it. So `srr` goes in no
`DESCRIPTION` dependency field. It is not on CRAN, and listing it in `Suggests`
would add an unavailable-package note for no gain.

## Files Modified

- `DESCRIPTION` — the `Roxygen` field now names `srr::srr_stats_roclet`
  alongside the three roxygen2 defaults, `collate`, `namespace`, and `rd`
- `tests/testthat/helper-test-data.R` — changed the `[make_labelled()]` Rd link
  in the `make_labelled_spss()` block to plain code formatting, because the
  roclet makes roxygen2 read this file and the helper has no Rd topic
- `changelog/chore-srr-roclet-registration.md` — this file

## Changes

- Register `srr::srr_stats_roclet` in the `DESCRIPTION` `Roxygen` field, so all
  138 `@srrstats` tags compile instead of being discarded
- Stop the Rd link warning the roclet exposed in `tests/testthat/helper-test-data.R`
