# Methodology Grounding Tiers for Spec Skills

**Status:** Draft — architectural proposal
**Applies to:** `pipeline-spec`, `spec-workflow` (Stage 2 methodology review), and any future skill that critiques or justifies methodological claims in surveycore.

---

## What this proposes

A tiered system for grounding methodological claims (in `comprehension-*.md` primarily, and in `spec.md` by link-back) in actual literature rather than in the reviewing model's priors. The planner recommends a tier based on the task's methodological novelty; the user can override.

**Check target:** `comprehension-*.md` is the primary audit surface. Every methodological claim there must be grounded in a cited source. `spec.md` is audited only for the weaker property that every methodological claim in it links back to a specific comprehension section. This avoids duplicating verification work and keeps the dependency chain clean: spec claims → comprehension claims → cache papers (or live search).

**Cross-model verification** (running the same pipeline under a second model like GPT and reconciling disagreements) is deferred. Documented as Tier 4 below but not built.

---

## The literature cache (wiki) — needs to be fleshed out

All tiers except Tier 0 assume a local literature cache exists. The cache is a curated set of survey-methods papers indexed via the qmd MCP, with:

- Full-text markdown extraction per paper (produced once via coarse's extraction pipeline: pymupdf + Mistral OCR).
- A short summary per paper (estimand coverage, design assumptions, key results) kept separate from the full text so drift is visible.
- A qmd collection (`surveymethods` or a subtree of `knowledge`) that supports `lex`, `vec`, and `hyde` search.
- Citation metadata (author, year, DOI or URL, canonical citation string).

**Open design questions (not resolved here):**

- Directory layout (flat `references/*.md` vs. subtopics vs. a full vault schema).
- Summary template (what fields, how long, who writes them — automated extraction vs. hand-written vs. hybrid).
- Curation workflow — who decides a paper is canonical enough to add; how Tier 0 search outputs get promoted back into the cache.
- How the comprehension doc cites cache entries (path-based? docid-based? citation-key-based?).
- Whether the cache lives in this repo, a sibling repo, or the existing knowledge vault.

These need to be designed before any tier above Tier 0 can be built.

---

## Tiers

### Tier 0 — Search-only (no wiki)

**What runs:** A single `coarse-chat` session per spec. The planner asks questions; `ask()` may invoke Perplexity Sonar Pro via the `<<SEARCH: …>>` sentinel mechanism (up to 3 hops per turn). Results are written into `comprehension-*.md` with inline citations to whatever Perplexity returned.

**When to choose:**
- The literature cache does not yet exist or is too sparse to cover the topic.
- You are prototyping a new method and want to see what's out there before curating.
- The methodology is far from surveycore's usual territory and no cached paper is a likely fit.
- You explicitly want the broadest net (web search) even at the cost of reproducibility.

**Caveats:**
- Every spec pays ~$0.05–0.20 per turn; long sessions drift into dollars.
- Non-reproducible: Perplexity results change between runs, so re-running a spec won't produce the same citations.
- No artifact left behind — the next spec on a related topic re-pays for the same searches.
- Perplexity is optimized for breadth and recency, not methodological rigor; it will surface blog posts and preprints alongside peer-reviewed work without distinction.
- Still runs entirely inside one model's priors: the model decides when to invoke search, what query to search with, and how to integrate results. All same-model failure modes (cherry-picked quotes, scope overextension, shared blind spots) apply.

### Tier 1 — Light

**What runs:** Extractor agents read the spec/comprehension, search the wiki via qmd (`lex` + `vec` sub-queries), and produce claim → citation pairs with a quote and page/section locator. A standard verifier agent reads each citation in the original cache file and confirms the quote exists and is on-topic.

**When to choose:**
- Incremental additions to well-understood families (new link function for an existing regression class; new summary statistic on already-shipped variance machinery).
- Bug fixes with methodological implications where the underlying theory is already cited in prior comprehension docs.
- Documentation cleanup that restates existing methodology without advancing it.

**Caveats:**
- Catches hallucinated citations and obvious misquotes, not much else.
- Cherry-picked quotes pass (verifier sees the same sentence the extractor chose and agrees).
- Scope overextension passes (quote is literally correct; application to surveycore's case may not be).
- Missing negative evidence — no one is looking for citations that contradict the claim.

### Tier 2 — Standard

**What runs:** Tier 1 plus (a) an adversarial verifier, whose prompt asks it to find the strongest objection a peer reviewer would raise against each citation (not to confirm), and (b) a counter-citation search — for each claim, an explicit qmd search for contradicting evidence in the cache.

**When to choose:**
- Extensions of an existing estimator to a new design class (e.g., something implemented for Taylor, now added to replicate or nonprob).
- Adjustments to existing methods (Fay factors, finite-population corrections added where absent, new df approximations).
- Specs where the formula is known but the design-consistency argument under complex sampling has not previously been written down in this repo.

**Caveats:**
- Still one-model; still cannot catch errors where the model is confidently wrong in a way the adversarial prompt doesn't break.
- Counter-citation search only works if contradicting papers are actually in the cache — misses gaps in the cache itself.
- Adversarial prompting is noisy: some objections will be plausible-sounding but wrong, and the reconciliation step (planner decides which objections are real) is another same-model judgment.

### Tier 3 — Deep

**What runs:** Tier 2 plus (a) a scope/caveats extraction pass that enumerates every assumption and scope limitation in each cited paper, then checks each claim against that list, and (b) a math re-derivation pass — for algebraic/statistical claims, extract the equation, re-derive independently, and compare to the spec.

**When to choose:**
- Genuinely new methods or new variance estimators that haven't appeared in surveycore before.
- Methods with non-obvious edge cases where mathematical correctness at boundaries matters (t-test / Cohen's d, design-based ANOVA, quantile variance under replicate weights, two-phase extensions).
- Any spec that will be cited by users in published research or that governs code likely to be copied by downstream packages.

**Caveats:**
- Math re-derivation by the same model that wrote the original claim is self-consistency, not independent verification. A model that mis-applied Binder's formula once is likely to mis-apply it again.
- Scope extraction depends on the model actually reading the whole paper; long papers with the key caveat in a footnote are easy to miss.
- Cost and latency are meaningfully higher — 5–6 agent passes per spec.
- None of this addresses cache gaps: if the right paper for the method is not in the cache, Tier 3 returns "grounded" based on second-best sources with no warning.

### Tier 4 — Maximum (deferred, not built)

**What would run:** Tier 3 plus a cross-model verification pass — the entire citation + claim pipeline re-run under a different model provider (e.g., GPT or Gemini), with disagreements surfaced for reconciliation.

**When to build:**
- When Tiers 1–3 have shipped and shadow-run data shows residual errors that look like "Claude's priors confidently wrong" (errors the adversarial pass doesn't catch because it shares the same priors).
- For specs where being wrong is catastrophic (new theoretical contributions, methods forming the basis of future functions, anything touching public API of a CRAN release).

**Why deferred:**
- Adds infrastructure (second provider, keys, cost tracking, output diff tooling).
- Uncertain marginal benefit until Tier 3's failure modes are characterized.
- Interface should be built such that adding Tier 4 later does not require re-architecting Tiers 0–3.

---

## Caveats that apply to every tier

These are design limitations to be honest about, not arguments against the system:

1. **One-model priors.** Every tier except 4 runs inside a single model's priors. Adversarial framing and counter-citation search reduce but do not eliminate the "model is confidently wrong and confidently self-verifies" failure mode. Tier 4 is the only architectural answer; the rest mitigate, not solve.

2. **Cache gaps are invisible.** No tier asks "are the right papers in the cache?" A method can be well-covered in the literature by papers you don't have; every tier will return "grounded" based on whatever is cached. This is a cache-curation problem that must be handled separately from the verification pipeline.

3. **Math re-derivation is self-consistency.** The Tier 3 math pass uses the same model that wrote the claim. Real independent verification requires a symbolic math tool (sympy via a subagent) or a human statistician. The current Tier 3 pretends to do more than it does.

4. **Tier selection is itself high-stakes.** A Tier 1 pick on a spec that should have been Tier 3 produces output that looks rigorous but isn't. The recommendation reasoning must be auditable and should default conservative (when in doubt, up-tier). The user must be able to disagree and force up-tier at any point.

5. **No built-in feedback loop.** Without shadow-running Tier 3 on Tier 1 picks and comparing findings on the first 5–10 specs, tier boundaries are guesses. Calibration data is necessary before the tier boundaries should be trusted.

6. **Methodology ≠ engineering.** This system grounds methodological claims. Engineering decisions (argument order, naming, return shape) have no literature and are out of scope — they're audited by the normal spec review process.

7. **Curation cost is front-loaded.** Every paper in the cache requires a one-time extraction + summary investment. Tiers 1–3 are only cheaper than Tier 0 after that investment pays back across multiple specs on related topics.

---

## Recommended build order

1. Design the wiki (the open questions above). Nothing above Tier 0 can be built until this is settled.
2. Build Tier 0 first — it's the fallback and it doesn't depend on the wiki.
3. Build Tier 1 and Tier 3 together. Skip Tier 2 initially — its boundaries are hardest to define, and a two-way split ("quick" vs. "deep") is enough to validate that tiering matters at all.
4. Shadow-run Tier 3 on Tier 1 picks for the first ~5–10 specs; log what each catches; use that data to decide whether Tier 2 is needed.
5. Add Tier 2 only if shadow data shows cases that obviously want a middle option.
6. Add Tier 4 (cross-model) only after Tier 3 residual errors are characterized.

---

## Open questions to resolve

- Wiki design (directory layout, summary template, curation workflow) — blocks Tiers 1–3.
- How is tier selection surfaced to the user? (CLI prompt? In-skill menu? A field in `comprehension-*.md` that the planner fills in and the user edits?)
- What does "grounded" vs. "partial" vs. "ungrounded" mean operationally for a claim? Must the extractor produce a confidence tag?
- Where does the cross-reference between `spec.md` methodological claims and `comprehension-*.md` sections live? Inline link? A dedicated "provenance" section at the bottom of the spec?
- How are coarse-chat fallback results (from Tier 0, or from Tier 1–3 when a gap is detected) promoted into the cache? Automatic write-back? Manual review step?
- Should the wiki be surveycore-specific or shared across the surveyverse ecosystem?
