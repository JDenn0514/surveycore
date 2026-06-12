# Stage 0: Deep Comprehension

## When to run

Run Stage 0 before Stage 1 when ANY of the following is true:

- The user has attached a paper, PDF, or markdown file of a journal article
- The feature involves a new statistical estimator or variance formulation
- The feature modifies numerical behavior (not just interface)
- The design references another package's implementation (`survey`, `srvyr`, `MASS`,
  `mice`, or any external variance estimator)
- The feature is in the `variance`, `analysis`, `constructors`, or `nonprob` families

Skip Stage 0 when:
- The request is a docstring fix, parameter default, or test addition
- The request is a rename or DESCRIPTION bump
- No formulas or algorithms are involved

If unsure, run Stage 0. A brief comprehension.md costs much less than a spec that
gets the variance formula wrong.

---

## Your role

You are extracting what is known from the literature and existing implementation
before the spec is written. The goal is not to produce the spec — it is to ensure
that whoever writes the spec has the right formulas, gotchas, and reference
mappings in hand. A spec written without this step is a spec that guesses at the
math.

---

## Input: what to read

If the user has attached material, read it in full before writing anything.
Attachments override any prior knowledge you have about the topic — the user is
telling you which version of the method they want implemented.

Also read:
- `R/` code for related functions (see how surveycore currently handles similar
  estimation problems, especially `.svy_recvar()`, `degf()`, and the replicate
  weight deviation loop)
- `plans/error-messages.md` (understand what error conditions are already defined)
- The referenced package's source if relevant (e.g., `survey::svymean`,
  `survey::svyvar`, `survey::svyglm`)

---

## Six comprehension sub-steps

Work through ALL of these before writing `comprehension.md`:

### 1. Restate the problem

In one paragraph, in your own words: what is the user trying to accomplish and
what statistical challenge does the method solve? Do not quote the paper.
Restating it forces you to actually understand it, not just paraphrase it.

### 2. Reproduce the key formulas

For each formula relevant to the feature:
- Write it out in LaTeX or precise pseudocode
- Bind every symbol to a surveycore function argument or `@data` column
- Note the normalization convention (e.g., do weights sum to N or to n?)
- If there are multiple algebraically equivalent forms, note which one the
  paper or reference package uses — they may differ numerically under finite
  samples

**Example binding table for a weighted mean:**

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| wᵢ | weight for unit i | `design@data[[design@variables$weights]]` |
| N | estimated population total | `sum(wᵢ)` |
| n | sample size | `nrow(design@data)` |
| yᵢ | outcome for unit i | `design@data[[y_var]]` |
| ȳ_w | weighted mean | `sum(wᵢ · yᵢ) / N` |
| ûᵢ | influence function for ȳ_w | `(yᵢ - ȳ_w) / N` (used in Taylor variance) |
| T_u | total of influence functions | `sum(wᵢ · ûᵢ)` (passed to `.svy_recvar()`) |

### 3. List gotchas

For each formula or algorithm, enumerate the failure modes and boundary
conditions. Think like someone who has debugged this in production.

**Survey-specific gotchas to check (not exhaustive — add others as relevant):**

- **Single-PSU stratum** — Taylor variance is undefined (df → 0) when a stratum
  has only one PSU. The spec must state behavior: warn + clamp df, error, or use
  FPC-based correction. Replicate designs sidestep this, but must specify what
  happens if a replicate produces 0 in-domain PSUs for domain estimation.

- **Influence function zeroing for domain estimation** — Out-of-domain units must
  have their influence function contribution set to zero before passing to variance
  machinery (`.svy_recvar()`). Failing to zero these inflates variance for domain
  estimates. This is not optional — it is how design-consistent domain SEs are
  defined.

- **Replicate scale factors** — BRR, JK1, JK2, JKn, and bootstrap each use
  different scale factors (`scale` and `rscales` in `as_survey_rep()`). Wrong
  scale = wrong SE. The spec must state which scale factor applies for each
  replicate type the feature supports, and where scale factors come from
  (user-supplied or auto-derived from the design).

- **Degrees of freedom: design-based vs classical** — Survey inference uses
  `degf(design)` (design-based df), not `n - p` (classical). These can differ
  dramatically for small samples. `degf()` returns non-integer values for
  replicate designs — the spec must not truncate to integer. If df ≤ 0 is
  possible, behavior must be stated (warn + clamp, or error).

- **FPC at the correct level** — Finite population correction must be applied at
  the sampling-stage level, not at the domain level. FPC is a property of the
  design, not of the analysis. The spec must not imply FPC is recomputed
  per-domain.

- **Normalization convention** — Does the estimator require weights to sum to N
  (population total), n (sample size), or 1? Many ESS and DEFF formulas depend
  on the normalization. The spec must state which convention is used and whether
  the formula is valid under the package's actual weight normalization.

- **Near-zero denominator** — Ratio estimators (`mean = total_y / total_x`) can
  produce `Inf` or `NaN` when the denominator total is near zero (zero-weight
  domain, degenerate strata). The spec must state whether this is caught before
  computation or handled in the output.

- **All-NA outcome** — If all values of the outcome column are `NA`, the point
  estimate returns `NA`, but SE formulas may produce `NaN` or `Inf` rather than
  `NA`. The spec must state which is returned.

- **Two-phase variance decomposition** — Two-phase designs require Phase 1 and
  Phase 2 variance to be decomposed separately and summed. Using a single-phase
  estimator on two-phase data produces biased (typically underestimated) SEs.
  The spec must specify the decomposition formula and which `.svy_recvar()` call
  handles each phase.

- **Zero-weight rows** — What happens when wᵢ = 0? Most survey estimators
  exclude these naturally, but the influence function and replicate deviation
  loop must handle zero-weight rows without producing `0/0` or dropping rows
  from the dataset.

### 4. Map references to design decisions

For each citation, package function, or equation number, record which design
decision it justifies.

Format:
```
{paper} §{section/equation} → {design decision}
```

Examples:
```
Binder (1983) eq. 5 → Taylor variance for regression uses score-based linearization
survey::svymean source → influence function is zeroed for out-of-domain units by
  multiplying by the domain indicator before passing to .svy_recvar()
survey::svydesign source → degf() computes df as (n_PSU - n_strata) for Taylor designs
```

### 5. Extract assumptions

What does the method assume that the user's request did not state? These are
the things that will surprise implementers or users if not made explicit:

- Population model: SRS, stratified, clustered, two-phase?
- Is the estimator design-consistent under the supported design types?
- Does the variance estimator require the same design structure as the point
  estimator, or can they differ?
- What does the formula assume about the weight normalization?
- Does the method require a minimum sample size per stratum or PSU (e.g.,
  ≥ 2 PSUs per stratum for Taylor variance)?

### 6. Flag open questions

Things you cannot resolve from the available material. These will become HOLDs
or spec decisions. List them so Stage 1 (drafting) knows where to be careful:

- "The paper doesn't specify behavior when a stratum has a single PSU — likely
  warn + coerce df to 1, but not stated."
- "survey::svyglm uses a different df correction for replicate designs; unclear
  if surveycore should match exactly."

---

## Output: `comprehension.md`

Write to `.pipeline-workspace/runs/{YYYY-MM-DD-id}/comprehension.md`. If the
workspace does not yet exist, pipeline-spec creates it — write to the run
directory.

Use this structure:

```markdown
# Comprehension — {id}

## Problem
{one paragraph in your own words}

## Formulas
{LaTeX or pseudocode for each formula; include symbol binding table}

## Gotchas
- {single-PSU stratum} — {what the formula does; required behavior}
- {influence function zeroing} — {when it matters for this feature}
[enumerate all that apply to this feature, add others beyond the list above]

## Reference mapping
- {paper/package} §{section/equation} → {design decision}
[one entry per citation or source function]

## Assumptions
- {assumption} — {why it matters}
[one entry per implicit constraint]

## Open questions
- {question} — {why it can't be resolved from available material}
[if any; omit section if none]
```

---

## Adversarial Verification

After writing `comprehension.md`, run an adversarial verification pass before
advancing to Stage 1. Errors in the comprehension artifact propagate directly
into the spec and then into code — catching a misread formula here costs far
less than catching it during review or in CI.

### Task framing for subagents

Each adversarial subagent has one job: **identify claims in `comprehension.md`
that are not supported by the source text, or that mischaracterize what the
source says.** This is not a style review. A claim that is accurate but could
be written more precisely is not an issue. Only flag genuine misreadings.

Do not ask subagents to "prove it wrong." Ask them to find specific
unsupported or mischaracterizing claims.

### Process

**Step 1 — Divide by section.** Spawn one subagent per section of
`comprehension.md` (Formulas, Gotchas, Reference Mapping, Assumptions). Each
subagent receives:
- Their assigned section of `comprehension.md`
- The original source material(s) (paper, package source, or both)
- The framing above — their only task is identifying unsupported or
  mischaracterizing claims

Each subagent produces a findings list. Claims with no issue are listed as
`OK`. Issues are formatted as:

```
ISSUE: [section heading + the specific claim]
SOURCE: [exact location in the source — equation number, line, or section]
PROBLEM: [why the claim lacks support or mischaracterizes the source]
```

**Step 2 — Fix pass.** A single fix subagent receives all findings and the
current `comprehension.md`. It addresses every `ISSUE` entry and writes a
revised `comprehension.md` to the same path.

**Step 3 — Sign-off check.** Re-run the adversarial subagents against the
revised `comprehension.md`. If no `ISSUE` entries remain, advance to Stage 1.
If issues remain and this is round 1, run one more fix pass (Step 2 → Step 3).

**Cap at 2 fix rounds.** If substantive issues remain after round 2, surface
them to the user with the note that the source material may be ambiguous or
that the claim requires a judgment call. Do not iterate further — flag and
advance.

---

## After Stage 0

Tell the user:

> "comprehension.md is written and adversarially verified. Next: Stage 1 will
> use it to draft both spec.md and test-spec.md. The Literature Lens in Stage
> 2 will cross-check the spec's formulas against this comprehension document."

Do NOT draft the spec in the same session as Stage 0 unless the user explicitly
asks to continue. Stage 0 is a research pass; Stage 1 is a writing pass. Keep
them separate so the drafting process starts with a clear head.
