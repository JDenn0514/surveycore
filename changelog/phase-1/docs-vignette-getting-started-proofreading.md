# docs(vignettes): proofread and fix getting-started vignette

**Date**: 2026-03-02
**Branch**: docs/vignette-getting-started-proofreading
**Phase**: Phase 1

## Changes

- Fix spelling errors: "Everything aspect" → "Every aspect", "is need" → "is needed", "Rather going" → "Rather than going", "ane example" → "an example", "wha this" → "what this", "will up shortly" → "will be up shortly", "the number people" → "the number of people"
- Fix grammar and punctuation: added missing commas, removed errant commas, fixed subject-verb agreement ("its analysis" → "their analysis"), hyphenated "select-all-that-apply", fixed "dplyr like" → "dplyr-like", corrected "Another simpler" → "A simpler", added Oxford commas, added missing periods
- Fix logical/content errors: corrected "three main sections" list (removed placeholder section 4), fixed section heading dash to em dash for `get_corr()`, fixed "no clustering nor strata" → "neither clustering nor strata"
- Replace broken `get_ratios()` example (incomplete sentence, undefined `pew_npors_2025` dataset) with a Trump/Biden favorability ratio using the Nationscape data already present in the vignette
- Fix inaccurate code comment "# remove NAs" → "# remove 'Not sure' responses (coded 999)" and typos in new code comments ("abotu" → "about", "rato" → "ratio")
- Remove orphaned commented-out code referencing undefined `svy` object
- Fix sentence fragment "Next, looking at" → "Next, let's look at"
- Replace `group-means` chunk example with `get_freqs(consider_trump, group = pid3)` — workaround for the same NA-domain bug fixed in `get_freqs()` by #30 that still affects `get_means()` with grouped `survey_calibrated` designs
- Add `eval=FALSE` to the `pak::pak("jacobdennen/surveytidy")` installation chunk so it does not execute during `devtools::check()`

## Files Modified

- `vignettes/getting-started.Rmd` — comprehensive proofreading: spelling, grammar, punctuation, replaced broken get_ratios() example, removed broken/placeholder content, fixed two vignette build errors
