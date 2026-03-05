# Guide: Using the Phase 0 Specification & Implementation Plan

## Overview

You now have two complementary documents that together form a complete blueprint for Phase 0 implementation:

1. **Formal Specification** (`surveycore-phase0-formal-specification.md`) - WHAT to build
2. **Implementation Plan v2.0** (`phase-0-implementation-plan-v2.md`) - HOW to build it

## For Claude Code: Which Document to Provide?

**Recommendation: Provide BOTH documents together**

### Approach 1: Hand Both Documents (Recommended)
```
"I need you to implement Phase 0 of the surveycore package. Here are two documents:

1. Formal Specification - defines all requirements, invariants, and contracts
2. Implementation Plan - provides step-by-step build instructions

Please read BOTH documents carefully before starting. The formal specification is authoritative for behavior; the implementation plan provides code templates and organization."
```

### Approach 2: Start with Implementation Plan
```
"Implement Phase 0 using this implementation plan. The plan references a formal specification document for detailed requirements. Whenever you're unsure about behavior, consult the formal specification."
```

## Document Breakdown

### Formal Specification (93KB, ~2000 lines)

**Contains:**
- ✅ Formal invariant definitions (what makes a valid survey object)
- ✅ Complete API contracts (exact function behavior)
- ✅ Error handling rules (what errors, what warns)
- ✅ Testing requirements (what to test, coverage targets)
- ✅ Tidy-select specifications
- ✅ Metadata lifecycle rules
- ✅ Value label validation rules
- ✅ Print output specifications
- ✅ Exit criteria checklist

**Use this document for:**
- Understanding "what" needs to be built
- Determining correct behavior in edge cases
- Validation and error handling decisions
- Test case design

### Implementation Plan v2.0 (50KB, ~1100 lines)

**Contains:**
- ✅ File organization and structure
- ✅ Code templates with actual R code
- ✅ Step-by-step build order
- ✅ Testing file organization
- ✅ Package infrastructure (DESCRIPTION, etc.)
- ✅ CI/CD configuration
- ✅ Development timeline
- ✅ Quality gates

**Use this document for:**
- Understanding "how" to build it
- Copy-paste code templates
- Development workflow
- File and function organization

## Key Updates from Original Plan

### 1. Tidy-Select Interface
```r
# OLD (Version 1.0 - formulas)
as_survey(data, ids = ~psu+ssu, weights = ~wt)

# NEW (Version 2.0 - tidy-select)
as_survey(data, ids = c(psu, ssu), weights = wt)
```

### 2. Metadata API Enhancement
```r
# Singular (single variable)
survey_obj <- set_var_label(survey_obj, age, "Age in years")

# Plural (multiple variables)
survey_obj <- set_variable_labels(
  survey_obj,
  age = "Age in years",
  income = "Annual income"
)
```

### 3. CLI Error Messages
```r
# All errors now use cli package
cli::cli_abort(c(
  "x" = "Weight variable {.field wt} not found",
  "i" = "Available: {.field {names(data)}}"
))
```

### 4. Value Label Validation
- Lenient by default (allows extra labels)
- Warns if missing labels for some values
- Documented in formal spec Section II.2.4

### 5. Update Function
```r
# New function for post-construction design updates
survey_obj <- update_design(survey_obj, weights = new_wt)
```

## Implementation Checklist

### Before Starting
- [ ] Read formal specification document completely
- [ ] Read implementation plan v2.0 completely
- [ ] Understand tidy-select interface
- [ ] Set up development environment
- [ ] Create GitHub repository

### During Development
- [ ] Follow file organization exactly as specified
- [ ] Implement in order specified in plan
- [ ] Write tests alongside code (test-alongside strategy)
- [ ] Use cli for all errors/warnings
- [ ] Test tidy-select extensively

### Before Declaring Complete
- [ ] Review exit criteria in formal spec Section X
- [ ] Achieve 100% test coverage (or 98%+ justified)
- [ ] Run R CMD check on all platforms
- [ ] Verify all examples work
- [ ] Check documentation completeness
- [ ] Validate against formal specification

## Common Questions

### Q: What if the documents conflict?
**A:** The formal specification is authoritative for behavior. The implementation plan is authoritative for organization. If they truly conflict, flag it for review.

### Q: Can I deviate from the specification?
**A:** No. The specification represents carefully considered decisions. Any deviation must be explicitly approved and documented.

### Q: What if I find an edge case not covered?
**A:** Refer to the error philosophy (Section V in formal spec): fail fast for design issues, be lenient for metadata. When in doubt, err on the side of strictness with clear error messages.

### Q: Should I implement beyond Phase 0 scope?
**A:** No. The specification explicitly lists what is NOT in Phase 0 scope (Section X.2). Stick to the boundaries.

## File Roadmap

Here's where to find key information:

| Topic | Formal Spec Section | Implementation Plan Section |
|-------|---------------------|----------------------------|
| Object invariants | I. Object Model | Component 1: S7 Classes |
| API signatures | II. API Specification | Component 3: Constructors |
| Tidy-select usage | II.1 Constructor Functions | Component 3: Constructors |
| Metadata system | II.2 Metadata Functions | Component 2: Metadata System |
| Error handling | V. Error Philosophy | Component 6: Validators |
| Print behavior | VIII. Output Formatting | Component 5: Print Methods |
| Testing strategy | VI. Testing Requirements | Testing Updates |
| Exit criteria | X. Phase 0 Exit Criteria | Quality Gates |

## Important: S7 Method Registration Syntax

The implementation plan code examples use S3 syntax (`print.survey_taylor <- function(...)`)
which is **incorrect** for S7 classes. The correct syntax is:

```r
# WRONG (S3 syntax - does not work for S7)
print.survey_taylor <- function(x, ...) { ... }

# CORRECT (S7 method registration)
S7::method(print, survey_taylor) <- function(x, ...) { ... }
```

This applies to ALL methods in the implementation plan code templates. Always use
`S7::method()` when implementing methods for S7 classes.

---

## Tips for Claude Code

### 1. Read Before Writing
Don't jump straight to coding. Spend time understanding the specifications.

### 2. Reference Frequently
Keep both documents open. Reference them constantly during implementation.

### 3. Test Continuously
Write tests alongside code. Don't defer testing.

### 4. Follow Order
The implementation plan specifies an order. Follow it. Dependencies are designed to build incrementally.

### 5. Ask Questions
If something is unclear, ask before implementing. Assumptions lead to rework.

## Success Indicators

You'll know Phase 0 is successful when:

✅ All 20+ items in exit criteria checklist are complete
✅ R CMD check passes with 0 errors, 0 warnings, 0 notes
✅ 100% test coverage (or 98%+ with justification)
✅ All examples in documentation run successfully
✅ Round-trip conversions preserve data exactly
✅ Tidy-select works with helpers (starts_with, etc.)
✅ Error messages are clear and use cli formatting
✅ Can create all three design types successfully

## Timeline Expectations

**Optimistic (full-time, experienced):** 16-18 days
**Realistic (part-time, learning curve):** 4-6 weeks

Don't rush. Quality over speed. The specification is comprehensive for a reason - it prevents rework.

## Next Steps After Phase 0

Once Phase 0 is complete:

1. **Phase 0.5:** surveytidy package (dplyr verb implementations) — can run in parallel with Phase 1
2. **Phase 1:** Core analysis functions (get_means, get_totals, get_freqs, etc.)
3. **Phase 2:** Regression (survey_glm), crosstabs, vignettes
4. **Phase 2.5:** surveywts package — can run in parallel with Phases 1-2
5. **Phase 3:** Polish & Release (all four packages at 0.1.0)

But don't think about those yet. Focus on Phase 0. Do it right.

---

## Quick Start for Claude Code

```
Hi Claude Code! I need you to implement Phase 0 of the surveycore R package.

I'm providing two documents:
1. Formal Specification - defines all requirements
2. Implementation Plan v2.0 - provides build instructions

Please:
1. Read BOTH documents completely before starting
2. Follow the implementation order in the plan
3. Consult the formal specification for all behavioral decisions
4. Use test-alongside strategy (write tests with code)
5. Ask questions if anything is unclear

The formal specification is authoritative for WHAT to build.
The implementation plan is authoritative for HOW to organize it.

Let's build something great!
```

---

Good luck! 🚀
