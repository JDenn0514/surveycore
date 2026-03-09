# docs(vignette): add creating-survey-objects vignette

**Date**: 2026-02-25
**Branch**: docs/vignette-creating-survey-objects
**Phase**: Phase 0.75

## Changes

- Add `vignettes/creating-survey-objects.qmd`: a full worked-example vignette
  covering all five constructors (`as_survey()`, `as_survey_repweights()`,
  `as_survey_srs()`, `as_survey_calibrated()`, `as_survey_twophase()`)
  with a decision guide, codebook variable reference tables (with Function
  Argument column), and worked examples for NHANES, ANES, GSS, Pew NPORS,
  ACS PUMS, Pew Jewish Americans, the school district SRS case, the
  message-testing panel, and the university voluntary response case
- Add `vignettes/references.bib`: bibliography covering Cochran (1977),
  Lohr (2022), Lumley (2010), Wolter (2007), Valliant & Dever (2018),
  Fay (1989), Judkins (1990), Baker et al. (2013), Elliott & Valliant (2017),
  Mercer et al. (2018), McPhee et al. (2023), and Census Bureau (2022)
- Include decision table mapping design type to constructor, reordered so
  `as_survey_srs()` precedes `as_survey_calibrated()` and
  `as_survey_twophase()` is last (rarest use case)
- Add per-dataset variable reference tables with Variable, Role, and
  Function Argument columns for all six bundled datasets
- Add Section 5.3 clarification: unit of analysis is the school (not the
  student) and why the weight is constant in SRS
- Add Section 6.2 expansion: `as_survey_calibrated()` covers raking,
  post-stratification, propensity score weighting, and matching-based weights
- Add Section 6.6 worked example: university voluntary response survey,
  with guidance for both the calibrated-weights and weights = 1 paths
- Add Section 7: probability vs. calibration weights — comparison table and
  practical test for choosing the right constructor
- Add Section 8: when no constructor applies — program evaluation classrooms
  as a worked example, with a general decision rule table
- Add Section 9 (renumbered from 7): common codebook variable reference

## Files Modified

- `vignettes/creating-survey-objects.qmd` — new file: full vignette source
- `vignettes/references.bib` — new file: bibliography
