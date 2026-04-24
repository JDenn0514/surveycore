# Decisions log — polychoric-corr

## 2026-04-23 — Plan review (pipeline-implement Stage 2/3)

### F1 — DESCRIPTION ordering fix (REQUIRED, resolved)

Resolution: moved PR 1's DESCRIPTION edit (add `pbivnorm (>= 0.6.0)`) from task 49 (end of PR) to task 29 (immediately before `.corr_polychoric_loglik()` implementation at task 30). Keeps intermediate package state valid under `R CMD check`.

### F2 — `any_floor_active` surfacing (ADVISORY, no artifact change)

Observation: spec.md line 243 documents `.corr_polychoric_mle()` return list with `n_sparse_cells` but does not spell out the relationship `n_sparse_cells > 0 ⟺ any_floor_active was TRUE at the optimum` (the latter is a `.corr_polychoric_loglik()` return field per line 221). Plan PR 1 task 41 already tests this invariant through the public surfaced bookkeeping, so no plan/spec change is required at PLAN_READY. Builder is expected to propagate `any_floor_active` from loglik to MLE via `n_sparse_cells`.

Disposition: advisory only; spec remains locked.

## 2026-04-24 — HOLD (pipeline-ship Step 0 baseline)

### Classification: `dirty-baseline`

Baseline `devtools::test()` on `develop` @ 795ff5f produced **33 FAIL / 9935 PASS / 4 SKIP / 137 WARN** before any polychoric work began. All 33 failures are in `tests/testthat/test-methods-print.R` (lines 134, 135, 136, 144, 145, 146, 161, 162, 194, 204, 301–306, 314, 315, 478, 490, 501, 509, 519, 520, 530, 531, 559, 573, 596, 623, 624, 646, 673).

Failure pattern: every failing expectation is of the form
```
expect_true(any(grepl("Strata|IDs|FPC|Phase 2|survey_nonprob|Weight distribution|...", out)))
```
where `out <- capture.output(print(d, ...), type = "message")`. The cli output *does* contain those literals when the same fixture is printed interactively under `devtools::load_all()`, but is not captured on the `message` channel under `devtools::test()`. Likely cause: testthat's reporter/sink interaction with `cli`'s output stream. Not a polychoric regression.

Pipeline-ship rule: "If either fails, HOLD with classification `dirty-baseline`. Do not begin."

**Pipeline paused before PR 1 dispatch.** User must resolve the baseline (fix the print tests, or explicitly override this HOLD in this file with a rationale) before resume.

### 2026-04-24 — HOLD rescinded (false alarm)

Root cause: the initial baseline was run as `suppressMessages(devtools::test(quiet = TRUE))`. `suppressMessages()` installs an outer `withCallingHandlers(message = ...)` that catches cli-generated messages before the inner `capture.output(type = "message")` sink inside each `test_methods-print.R` test can capture them, so every `expect_true(any(grepl("Strata|IDs|FPC|...", out)))` sees `out = character(0)`. Without `suppressMessages()`, all 33 tests pass.

Fresh baseline (no `suppressMessages`): **`devtools::test()` → 0 FAIL / 10109 PASS / 4 SKIP / 137 WARN**; **`devtools::check()` → 0 errors, 0 warnings, 2 notes** (both pre-approved: `future file timestamps`, `unstated dependencies in vignettes: 'surveytidy'`).

Baseline is clean. Resuming pipeline at PR 1 dispatch.

## 2026-04-24 — Builder note (PR 1): polyserial oracle tolerance relaxed

### B1 — `polycor::polyserial()` 1e-6 target is unrealistic (ADVISORY)

Observation: spec.md line 356 and implementation-plan.md PR 1 acceptance criteria call for `.corr_polyserial_mle()` to match `polycor::polyserial()` within `1e-6` on equal weights. This target is not achievable with either polycor mode:

- `polycor::polyserial(..., ML = TRUE)` performs a joint MLE over ρ AND thresholds simultaneously (not the two-step approach prescribed by Mannan 2025 §6.1 / Cox 1974). Differs from the two-step MLE at ~1e-4 on the PR 1 fixtures.
- `polycor::polyserial(..., ML = FALSE)` (default) uses Drasgow's fast approximation — not a two-step MLE at all. Differs at ~3e-3.

Hand-computed two-step MLE (the construction Mannan 2025 §6.1 actually prescribes — thresholds from weighted marginals, then 1-D optimize over ρ with thresholds fixed) agrees with `.corr_polyserial_mle()` to machine precision. 

Disposition: builder kept 1e-6 parity against a hand-computed two-step reference (`.hand_polyserial_twostep()`), plus a loose 1e-3 agreement check against `polycor::polyserial(ML = TRUE)` as a sanity gate. Spec-level target unchanged; builder marks this for tester review. If reviewer disagrees, this can be tightened by changing the polycor oracle to the hand-computed two-step in test-spec.md.

### B2 — PC-6 is primarily reachable via optimizer failure, not clean data

Observation: constructing clean ordinal data that forces the probe guard (loglik non-finite at all probes) is practically impossible at the spec's `cell_prob_floor = 1e-300` — `log(floor) ≈ -690` is finite and stats::optimize converges on every realistic input. 

Disposition: builder triggers PC-6 via `eps = 1.5` (forces `lower > upper` → stats::optimize throws → tryCatch catches → PC-6 fires). This is a real code path in `.corr_polychoric_mle()`, but test is pragmatic rather than data-driven. Dispatcher-level PC-6 (PR 2) will cover the probe guard via perturbation-failure scenarios.

### B3 — Pre-existing vignette bug exposed by adding polycor to Suggests

Observation: `vignettes/surveycore-vs-survey.Rmd` chunk `corr-survey` (line ~408) calls `svycor(...)` unqualified. `svycor` is provided by `jtools`, NOT `polycor`. The chunk is guarded by `eval = has_survey && requireNamespace("polycor", quietly = TRUE)` — a typo'd guard (should be `jtools`). When `polycor` is not installed the chunk is silently skipped; when `polycor` IS installed (as required for PR 1's oracle tests) the chunk tries to evaluate `svycor()` and R CMD check's vignette build fails with `could not find function "svycor"`.

This bug is pre-existing — not introduced by PR 1. Adding `polycor` to `Suggests:` (required for `skip_if_not_installed("polycor")` to let oracle tests run in CI) surfaces it.

Disposition: builder keeps `polycor (>= 0.8.0)` in `Suggests:` (oracle tests are a PR 1 acceptance criterion). The vignette fix is outside PR 1's write surface (R/ and tests/testthat/ only). Tester will observe this vignette build failure under `R CMD check --as-cran` and should either:
  (a) patch `vignettes/surveycore-vs-survey.Rmd` line ~408 to change the guard to `requireNamespace("jtools", quietly = TRUE)` and add `library(jtools)` at chunk top (a 2-line fix); this is a doc-only change that could be rolled into PR 1 if the orchestrating skill approves; OR
  (b) run `R CMD check --no-build-vignettes` for PR 1 only, and track the vignette fix as a separate docs-only PR before shipping PR 3 (which re-exports wiring).

Recommendation: option (a) — a trivial vignette fix that unblocks CI. Builder did not apply it here because it lies outside the declared write surface for PR 1. Flagged for reviewer / tester to resolve.

### 2026-04-24 — B3 resolution (orchestrator): scope extension approved

Orchestrator authorizes rolling the 2-line vignette fix in `vignettes/surveycore-vs-survey.Rmd` line ~407 into PR 1's write surface. Rationale: the bug is pre-existing but only ever causes R CMD check failures when `polycor` is present on the check environment. PR 1 *makes* `polycor` present (required for the spec's oracle tests). Fixing it out-of-band would require an extra PR on `develop` whose sole reason to exist is polychoric's `Suggests:` change, so the cleanest attribution is to PR 1.

Extended write surface for PR 1: add `vignettes/surveycore-vs-survey.Rmd` (modified — guard fix + `jtools::` prefix). This is the only addition. The builder is being continued with explicit authorization to apply the fix and regenerate implementation.md accordingly.

### 2026-04-24 — B1 disposition (orchestrator): keep builder's hand-reference oracle

Spec's `polycor::polyserial()` 1e-6 target is not bit-achievable (polycor uses joint-ML or Drasgow, not two-step). Builder substituted a hand-computed two-step reference at 1e-6 plus a loose 1e-3 sanity check against `polycor::polyserial(ML = TRUE)`. This matches the spec's mathematical intent (two-step MLE per Cox 1974 / Mannan 2025 §6.1) and is consistent with `.corr_polychoric_mle()`'s contract. Spec/test-spec will not be rewritten at PLAN_READY; the reviewer is free to flag this if it disagrees. Advisory only.

### 2026-04-24 — B2 disposition (orchestrator): accept PC-6 eps=1.5 pathway

PC-6 via `eps = 1.5` forcing `lower > upper` is a real code path in `.corr_polychoric_mle()`'s `tryCatch`. The probe guard at `log(1e-300) ≈ -690` is defensive and correctly `# nocov`'d. Dispatcher-level PC-6 coverage (perturbation failures) is owned by PR 2. Advisory only.

## HOLD — builder (PR 2) — 2026-04-24

**Where**: worktree `worktree-agent-ad034666` for `feature/polychoric-corr-variance-paths`
**What**: Worktree is cut from the wrong base commit — PR 1's merged work is not visible, so PR 2 cannot extend it.
**Why I can't decide**: The builder dispatch instructions explicitly require cutting from `develop` (at `03be13d` after PR 1 merged) and mandate emitting HOLD (classification `wrong-worktree-base`) if PR 1 artifacts are absent. Only the orchestrator can re-cut the worktree or fall back to cherry-picking.

**Classification**: `wrong-worktree-base`

**Evidence (verified just now)**:
- `git log -1 --oneline` in the worktree returns `6f7e474 chore(cran): document expected win-builder NOTE for submission` — this is a commit on `main` (v0.7.1 prep), not on `develop`.
- `develop` is at `03be13d chore(plan): mark PR 1 of polychoric-corr complete`; the PR 1 merge commit `0a7197f feat(analysis): add polychoric / polyserial MLE primitives (PR 1/3) (#107)` sits immediately before it. Neither is in this worktree's history.
- `ls R/analysis-corr-latent.R` → file not found. This file was created by PR 1 and is the file PR 2 was told to extend.
- `grep -E "pbivnorm|polycor|jtools" DESCRIPTION` → no matches. PR 1 added `pbivnorm` to Imports and `polycor` / `jtools` to Suggests; none are present here.
- Cross-check: `git show develop:R/analysis-corr-latent.R | head -3` shows the file exists on `develop`, and `git show develop:DESCRIPTION | grep -E "pbivnorm|polycor|jtools"` shows all three deps are on `develop`.

**Options**:
1. Re-cut the worktree from `develop` (currently `03be13d`) and re-dispatch builder. Preferred — clean history, matches the dispatch contract.
2. Cherry-pick `0a7197f` (the PR 1 squash-merge) onto this worktree. The dispatch instructions mention this as the orchestrator's fallback.

**What I need**: Orchestrator to either re-cut the worktree from `develop@03be13d` (option 1) or cherry-pick PR 1 into this worktree (option 2), then re-dispatch builder for PR 2. No code has been written in this worktree; no implementation.md exists yet.

### Resolution — 2026-04-24 — orchestrator

Option 3 applied: skipped worktree isolation entirely for PR 2 since the same `wrong-worktree-base` pattern also affected PR 1. Created `feature/polychoric-corr-variance-paths` directly off `develop@03be13d` and dispatched builder without `isolation = "worktree"`. PR 1 artifacts were confirmed present (`R/analysis-corr-latent.R` + `pbivnorm`/`polycor`/`jtools` in DESCRIPTION) before dispatch. Builder then executed successfully in one pass.

## 2026-04-24 — PR 2 reviewer advisory dispositions

### D1 — PC-9 boundary detector `eps = 1e-4` vs spec's `1e-6`

Reviewer accepted (PASS verdict) on the "physical reachability" ground first established in B1. Spec says "ρ̂ within ε = 1e-6 of ±1", but the optimizer bounds (`-1 + 1e-6, 1 - 1e-6`) plus `stats::optimize()`'s default tolerance (`.Machine$double.eps^0.25 ≈ 1.22e-4`) mean the MLE stops ~4.2e-5 short of the boundary. Detector at 1e-6 would never fire; at 1e-4 it fires on genuinely-at-the-rail optimizations.

Disposition: advisory, orchestrator-approved. The `eps` argument is exposed on the helper so callers can tighten. A future polish PR may amend spec.md to "1e-4" and add a comment pointing to the optimizer-tolerance constraint. Not blocking.

### D2 — `.corr_fisher_ci()` placement

Spec Architecture said helpers live in `R/analysis-corr-helpers.R`; that file was not created by PR 1 and PR 2's declared write surface did not include it. Builder placed the helper in `R/analysis-corr-latent.R` (inside the declared surface) rather than unilaterally extending the surface. Reviewer accepted; orchestrator concurs — the conservative choice. PR 3 may opt to refactor `R/analysis-corr.R`'s inline Fisher-z CI code to call this helper if the write surface allows.

### D3 — PC-11 dispatcher branch `# nocov`

Same rationale as B2 (PR 1): with `stats::optimize()` default tolerance + 1e-12 modeled-probability threshold, the branch is essentially unreachable via realistic fixtures. Detection logic is already covered by PR 1 helpers. Acceptable per new-code-coverage interpretation; new-code coverage stands at 100 %.

## 2026-04-24 — STOP (reviewer, PR 3)

### Category: tolerance-relaxation + coverage-floor + spec-coverage-gap (combined)

Reviewer returned STOP on PR 3 covering four distinct issues. `review.md` is at
`.surveycore-workspace/runs/2026-04-23-polychoric-corr/prs/pr-3-api-wiring/review.md`. Full text preserved there; summary below.

### A — Polychoric parity tolerance (STOP, tolerance-relaxation)

Spec §Tolerances + test-spec say `polycor::polychor()` parity at **1e-6** on 3×3 / 4×5 / 2×2 equal-weight fixtures. PR 3 uses **1e-4** uniformly and substitutes a **4×4** fixture for the spec's **4×5**. PR 1 shipped 1e-6 at the primitive layer on the exact 3×3 / 4×5 / 2×2 fixtures with the same `stats::optimize(tol = .Machine$double.eps^0.25)`; the builder's "optimizer-floor" rationale is empirically refuted by PR 1. Of the three observed deltas, 3×3 (4.47e-8) and 2×2 (1.52e-9) pass 1e-6 trivially; only the 4×4 (substituted) case misses, at 1.50e-6. Fix: restore 4×5 fixture, use 1e-6.

### B — Polyserial parity tolerance (STOP, tolerance-relaxation)

Spec target 1e-6; PR 1 precedent (decisions.md B1) established a hand-computed two-step reference at 1e-6 as the accepted oracle. PR 3 ignored the precedent and used `polycor::polyserial(ML = TRUE)` at **5e-3** — 5000× looser than the established precedent. `polycor::polyserial(ML = TRUE)` is a joint MLE, not the two-step that spec §5.1 mandates, so the comparison is mathematically inappropriate regardless of tolerance. Fix: port the `.hand_polyserial_twostep()` reference from PR 1's test file (or re-derive it) and pin at 1e-6.

### C — Public-API PC dual-pattern coverage (BLOCK, folded into STOP)

Test-spec.md §Error paths + §Warning paths require dual-pattern tests (`expect_error(class=)` + `expect_snapshot(error=TRUE)` / `expect_warning` + `expect_snapshot`) for every PC class at the public-API layer. PR 3 provides this for only PC-1, PC-3, PC-4. PC-7 and PC-13 are class-only. PC-2, PC-5, PC-6, PC-8, PC-9, PC-10, PC-11, PC-12, PC-14 have no public-API-layer tests. Dispatcher-layer tests from PR 2 cover the message text, but the **routing through `get_corr()`** is the public contract and is not end-to-end tested. Fix: add public-API dual-pattern tests for the 11 missing classes, or at minimum `expect_error/warning(class = ...)` + one representative snapshot per class.

### D — Coverage drop on `R/analysis-corr.R` (STOP, coverage-on-new-code)

File coverage 99.70 % → 96.38 % (−3.32 %). Uncovered lines are in the `n_failed_replicates_total` accumulator (the `<<-` condition-handler branch) and the populated-scalar `meta()` path. Spec Invariant 6 explicitly requires the populated-scalar path be tested; test-spec.md PC-12 row explicitly requires "assert `meta(result)$n_failed_replicates_total` has expected scalar value". Audit tested only the NULL-when-zero branch; the populated branch is uncovered *and* missing the required test. Absolute package coverage (95.82 %) is above 95 % so not an automatic BLOCK, but new-code-coverage integrity per signals.md STOP criteria is violated. Fix: one PC-12 public-API test that constructs a replicate scenario with 0 < failures ≤ 20 % and asserts `meta()$n_failed_replicates_total` is a positive integer — this single test closes D entirely and contributes to C.

### Reviewer's recommendation

"Re-dispatch pipeline-implement (builder) on existing branch; no planner re-dispatch required. All four items resolvable in one builder cycle — a single PC-12 public-API test closes most of C, all of D, and Invariant 6."

### Pipeline state

Pipeline HALTED at PR 3 reviewer STOP. Per signals.md §Resume protocol: user must explicitly authorize resume in decisions.md before any further dispatch. Options are:

1. **Override and re-dispatch builder** with targeted fixes for A + B + C + D. This is the reviewer-recommended path. ~1 builder cycle expected.
2. **Override and accept STOP as-shipped** with documented tolerance exceptions. Not recommended; breaks precedents established at B1 / D1 boundaries.
3. **Halt polychoric-corr and escalate** for planner re-dispatch to re-draft spec tolerances. Major rework; polychoric primitives + variance paths (PR 1, PR 2) already shipped.

## Resolution — 2026-04-24 — user override (STOP → resume)

**Signal resolved**: PR 3 reviewer STOP (A + B + C + D)  
**Decision**: Option 1 — override STOP and re-dispatch builder on the existing branch with targeted fixes for all four items. No planner re-dispatch.  
**Authorized by**: user  
**Resume from state**: PR 3 builder loop (pre-audit). Tester and reviewer will re-run after builder returns.

Builder dispatch scope:
- A: revert to spec's 4×5 polychoric fixture; pin `polycor::polychor()` parity at 1e-6.
- B: port or re-derive the two-step hand reference from PR 1's `.hand_polyserial_twostep()` helper; pin polyserial parity at 1e-6.
- C: add public-API dual-pattern tests (`expect_error/warning(class=)` + `expect_snapshot`) for the 11 missing PC classes. Prefer reusing PR 2 dispatcher-layer message text via shared snapshot files if testthat permits, to avoid duplication.
- D: add a PC-12 public-API test (0 < failures ≤ 20 %) that asserts `meta()$n_failed_replicates_total` is a positive integer scalar. Covers spec Invariant 6.



