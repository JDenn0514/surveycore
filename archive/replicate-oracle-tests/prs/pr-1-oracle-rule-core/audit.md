# Audit — PR 1 — oracle-rule-core

**Verdict**: PASS
**Date**: 2026-09-22 00:00

**Branch**: `docs/oracle-rule-core` at `1879a34b06b9dc02969d407eb8e36e31726bea7d`
**Base**: `7800ea9730acdcf03ae33dc24bb9a008a8920e33`
**Allocated rows**: §6 — 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.8, 6.11, 6.16, 6.18,
6.19, 6.20. Twelve rows, twelve passed.

Rows 6.7, 6.9, 6.12, 6.13, 6.14, 6.17 (PR 2) and 6.10, 6.15 (PR 9) are not
this PR's and were not scored. §2, §3, §4 and §5 belong to the PRs that write
`tests/testthat/test-variance-replicate.R`.

## Per-Test Result Table

Every row is a question about the text of `.claude/rules/testing-surveycore.md`.
Every "Got" cell quotes the delivered file. Tolerance is not numerical here, so
the column carries the check type.

| Test | Got | Expected | Tolerance | Pass |
|---|---|---|---|---|
| 6.1 — both sides from the same inputs, `mse` explicit | L178–180: "**Build both sides from the same inputs.** Same data frame, same weight column, same replicate columns, same `type`, same `mse`. Pass `mse` explicitly to both sides." | states same data, weight column, replicate columns, type, `mse`, with `mse` passed explicitly | text present | ✓ |
| 6.2 — no block passes `scale`, and why | L181–184: "**Pass `scale` to neither side.** `survey::svrepdesign()` honours a supplied `scale` for JK1, JKn, bootstrap and `other`, so a block that passes surveycore's default in gets the same number back out. The comparison then cannot disagree, and a wrong default stays green." | states the ban, the four honouring types, and that the comparison then cannot disagree | text present | ✓ |
| 6.3 — `rscales` to JKn only, same literal, never off the design | L188–192: "**Pass `rscales` to JKn only.** `survey` refuses JKn with combined weights and no `rscales`. Pass the same literal to both sides. Never read `rscales` off the surveycore design." | JKn only; same literal both sides; never read off the surveycore design | text present | ✓ |
| 6.4 — assert the SE, not the point estimate alone | L193–197: "**Assert the standard error, not the point estimate alone.** The scale enters the variance only. A design with a wrong scale returns the same point estimate, so a block that asserts the point estimate alone reports green on a wrong default." | states the assertion and the reason (scale enters the variance only) | text present | ✓ |
| 6.5 — assert the condition, do not silence it | L198–200: "**Assert the condition `survey` raises. Do not silence it.** A warning from `svrepdesign()` is the test telling you `survey` computed the value itself. `suppressWarnings()` round an oracle call hides that." | states assert, and states do not silence | text present | ✓ |
| 6.6 — match by message text; both house rules named | L214–226: "**Match `survey`'s conditions by message text, not by class.** Every condition in `svrepdesign()` is a bare `warning()` or `stop()` … The missing `class =` here is a property of `survey`, and it breaches neither house rule that could be read to require one. `.claude/rules/code-style.md` governs surveycore's own `cli::cli_abort()` and `cli::cli_warn()` calls; an oracle block writes none. `.claude/rules/testing-standards.md` §Assertions requires `class =` on every `expect_warning()`; it governs surveycore's own typed conditions, and `survey` supplies no class to name." | message text, because `survey`'s conditions are untyped; and BOTH house rules named — code-style and testing-standards §Assertions | text present; both rules named | ✓ |
| 6.8 — Quick Reference row, scoped to `svrepdesign()` | L13: "\| Oracle tests against `survey` \| Never hand `survey` a number surveycore computed; assert the SE. Rules 2 and 3 and the per-type table apply to `svrepdesign()` only \|" | a Quick Reference row exists, and it scopes the `scale` and `rscales` rules to `svrepdesign()` only | row present, scope stated | ✓ |
| 6.11 — which rules reach which design | L171–176: "**Which rules reach which design.** Rules 1, 4 and 5 hold for every oracle test against `survey`, whatever the design class. Rules 2 and 3 and the per-type table below name arguments of `survey::svrepdesign()`, so they reach replicate designs only. An author writing a Taylor or two-phase oracle applies rules 1, 4 and 5 and reads rules 2 and 3 as the principle behind them: pass the other side no number this side computed." | three of five (same inputs, assert the SE, assert the condition) hold for every design; scale, rscales and the per-type table reach replicate only; a Taylor or two-phase author can tell which parts bind | text present; rules 1/4/5 are same inputs / assert the SE / assert the condition, rules 2/3 are scale / rscales | ✓ |
| 6.16 — a formula banned as an argument, allowed as an assertion literal | L207–213: "**A formula forbidden as an argument is still allowed as an assertion literal.** The two acts differ. Passing `(R-1)/R` into `svrepdesign()` sets the number the other side computes with, which is the round trip. Writing `(R-1)/R` in an `expect_equal()` states what the block claims the number is … JK1 is the worked case." | states the distinction, with `(R-1)/R` as argument versus as assertion, and JK1 named as the worked case | text present; JK1 named | ✓ |
| 6.18 — heading text and position | L165: "## The oracle rule — never hand `survey` a number surveycore computed". Section headings in order: L93 "The both-modes rule …", L165 this section, L245 "S7 error testing layers". | that exact heading, after the both-modes rule section and before the S7 error testing layers section | heading exact; position exact | ✓ |
| 6.19 — never assert one side's scale against the other's | L204–206: "**Never assert one side's stored scale against the other side's.** Assert each against a literal. An assertion that compares the two sides to each other is the same round trip in a different shape." | states the ban, states "assert each against a literal", states it is the same round trip | text present | ✓ |
| 6.20 — rule 4's CI clause carries a precondition | L227–243: "Rule 4's confidence-bound clause carries one precondition. **Both sides must build the interval from the same distribution and the same degrees of freedom.** They do today, and both use the normal approximation. `survey`'s `confint()` methods for `svrepstat` and `svystat` default to `df = Inf` … surveycore assigns `degf <- Inf` unconditionally … A later PR that moves surveycore's replicate path to design-based degrees of freedom must revisit `tests/testthat/test-variance-replicate.R` in the same PR. Every confidence-bound assertion in the block set fails at once when it lands, and the failure reads as a scale defect unless the reader knows this clause." | same distribution and df; both normal today; `survey` `confint()` for `svrepstat`/`svystat` defaults to `df = Inf`; surveycore replicate path infinite df unconditionally; a later df PR must revisit the replicate test file in the same PR; the failure reads as a scale defect | text present; all six elements | ✓ |

Line numbers are of `.claude/rules/testing-surveycore.md` at
`1879a34b06b9dc02969d407eb8e36e31726bea7d`.

### Two notes on the twelve, neither a failure

1. **Row 6.8 states its scope by reference.** The Quick Reference row writes
   "Rules 2 and 3", not "the `scale` and `rscales` rules". Rules 2 and 3 of the
   same file are the `scale` rule (L181) and the `rscales` rule (L188), so the
   content the row asks for is present and resolvable inside the one file. The
   test-spec says the wording is the author's.
2. **Two forward references point at content PR 2 delivers.** L13 and L173 name
   "the per-type table", which is row 6.9 and belongs to PR 2; L187 says "Read
   this rule with the scope paragraph at the end", which is row 6.12 and also
   belongs to PR 2. The dispatch names this the planned intermediate state.

## Standing gates measured on the branch

Four checks that the baseline cannot supply. All four pass.

| # | Check | Command | Result |
|---|---|---|---|
| 1 | One file changed, no third file | `git diff --name-status 7800ea9 HEAD` | `M .claude/rules/testing-surveycore.md` — one path |
| 2 | The touched file is air-clean | `air format --check .claude/rules/testing-surveycore.md` (air 0.11.0, CLI) | exit 0, no diagnostic |
| 3 | `test-conversion.R` unchanged | `git diff --name-only 7800ea9 HEAD -- tests/testthat/test-conversion.R` | 0 paths. Both blocks row 6.12 names are on disk at L239 and L567 |
| 4 | No `R/`, `man/`, `NAMESPACE`, `DESCRIPTION` change; no roxygen change | `git diff --name-only 7800ea9 HEAD -- 'R/*' 'man/*' NAMESPACE DESCRIPTION` | 0 paths |

Gate 2 reads as "the file this PR touches passes". `air` is a command-line
tool on this machine, not an R package, and files repo-wide are already not
air-clean (see `archive/svydesign-replicate-bridge/` D16).

## Before/After Comparison

Before comes from
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/baseline.md` [no such file]
(tree `e9a6c808f228388175b1b6892e7372d39e3e2fb8`, commit `7800ea9`). After
comes from the gate record, which carries the baseline figures forward for the
reason stated below.

| Metric | Before PR | After PR | Δ |
|---|---|---|---|
| tests passing | 11941 | 11941 | 0 |
| test failures | 0 | 0 | 0 |
| test warnings | 256 | 256 | 0 |
| test skips | 4 | 4 | 0 |
| coverage | 96.15% | 96.15% | 0 |
| R CMD check notes | 2 | 2 | 0 |

Coverage sits above the 95% floor and did not drop, so no HOLD. The 256
warnings read as "no new warning" — they are the pre-existing AAPOR small-cell
warnings of issue #167, per `baseline.md`.

## Profile gates

Copied from
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/prs/pr-1-oracle-rule-core/gates.md` [no such file].
The leader ran the gates, not the tester: this machine has about 1.8 GB free, a
memory watchdog kills R gate processes, and overlapping runs have corrupted
whole log sets here.

| Gate | Result | Notes |
|---|---|---|
| `devtools::document()` | PASS | wrote nothing; baseline — `R/` and `man/` byte-identical |
| `devtools::test()` | PASS | `[ FAIL 0 \| WARN 256 \| SKIP 4 \| PASS 11941 ]`; baseline — `tests/` byte-identical |
| `run_examples()` | PASS | all examples ran; baseline — no roxygen change |
| `R CMD build` | PASS | baseline — `.Rbuildignore` carries `^\.claude$` |
| `R CMD check --as-cran --no-manual` | PASS | 2 NOTEs, both pre-existing; baseline §The two NOTEs |
| pkgdown | SKIPPED — scope | no `R/`, `vignettes/`, `README*`, `_pkgdown.yml` or `DESCRIPTION` change |
| `covr` | PASS — 96.15% | baseline — no source line added or removed |
| CRAN cookbook scan | PASS | no `.R` file in the write surface |

Baseline logs:
`.surveycore-workspace/runs/2026-09-16-replicate-oracle-tests/logs/baseline/`

Tree: `5152c6eb4e07b28c4a149b2294fceec0b5a8ef15`

### Why no R gate was re-run, and why that is a measurement

The diff lists one path, `.claude/rules/testing-surveycore.md`. Two facts make
every R gate identical to the baseline run:

1. `.Rbuildignore` carries `^\.claude$`, so `R CMD build` excludes the whole
   directory. Gates 4, 5 and 6 cannot see the change.
2. No test opens the file at run time. The four `.claude` hits under `tests/`
   are comments citing a rule. `R/` and `tests/` are byte-identical to the
   baseline tree, so gates 1, 2, 3 and 7 would run identical code over
   identical inputs.

I identify no gate that could still move on this tree. A re-run would measure
machine noise.

### The two NOTEs

Both are pre-existing and neither is new.

1. `checking CRAN incoming feasibility` — pre-approved in
   `.claude/rules/r-package-conventions.md`.
2. `checking for hidden files and directories` — `R CMD build` finds `.git`.
   Not on the pre-approved list in `r-package-profile.md`, but present on the
   clean baseline tree with no change applied, and recorded earlier on the
   `as-svydesign-bridge` arc. `.Rbuildignore` causes it and this PR cannot fix
   it. Gate 5 reads as "2 NOTEs, and these two". A third NOTE blocks.

## CRAN cookbook violations

None. The write surface holds no `.R` file, so no pattern in
`r-package-profile.md` §CRAN cookbook scan has anything to match.

## Out of scope, noted and not scored

`tests/testthat/test-variance-replicate.R` does not comply with the new rule
yet. The JK1 block passes a `scale` argument, and the JK1 and JK2 blocks wrap
their `survey` call in `suppressWarnings()`. PR 4 of this arc closes both. The
test file is not in this PR's write surface, and §2 to §5 of the test-spec
belong to later PRs, so this is not a defect here.

## BLOCKs

None.
