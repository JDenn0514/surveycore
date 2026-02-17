# Surveyverse Ecosystem - High-Level Roadmap

**Version:** 0.1.0 Development Roadmap  
**Last Updated:** February 2025  
**Status:** Planning Phase

---

## Vision & Goals

### Project Vision
Create a modern, tidyverse-compatible ecosystem for survey analysis in R that prioritizes:
1. **Statistical Rigor** - Maintain exact statistical accuracy with proper survey variance estimation
2. **Tidy Integration** - Seamless integration with dplyr/tidyr workflows
3. **Label Preservation** - Automatic preservation of haven-style metadata throughout analysis
4. **User Experience** - Intuitive API that makes complex survey analysis accessible

### Core Principles
- **Accuracy First**: Statistical correctness is non-negotiable; performance and convenience are secondary
- **Modular Design**: Separate packages with clear responsibilities, loadable together
- **Independence**: No runtime dependency on `survey` or `srvyr` packages (vendor variance code with attribution)
- **Modern R**: Built on S7 object system, requires R >= 4.3.0
- **Full Replacement**: Designed as complete alternative to `survey` + `srvyr`, not a wrapper

---

## Package Ecosystem

### Four-Package Architecture

```
surveyverse/
├── surveycore/       # Core: S7 objects, metadata, analysis functions
├── surveytidy/       # Adapters: dplyr/tidyr verb implementations
├── surveyweights/    # Weighting: Calibration, raking, propensity, replicate creation
└── surveyverse/      # Meta: Load all packages together
```

### Package 1: surveycore

**Purpose:** Core survey infrastructure and analysis functions

**Key Components:**
- S7 class system (survey_base, survey_taylor, survey_replicate, survey_twophase)
- Metadata system (variable labels, value labels, question prefaces, transformations, notes)
- Vendored variance estimation code from `survey` package (with attribution and refactoring)
- Analysis functions: `get_freqs()`, `get_means()`, `get_diffs()`, `get_corr()`, `get_totals()`, `get_quantiles()`, `get_ratios()`
- Regression: `survey_glm()`, `clean()`
- Crosstabs: `get_crosstab()`
- Object creation: `as_survey()`, `as_survey_rep()`, `as_survey_twophase()`
- Conversion utilities: `as_svydesign()`, `as_tbl_svy()`

**Dependencies:**
- S7 (required)
- Base R packages: stats, methods
- Minimal additional dependencies (dplyr, tidyr for internal use only)
- Suggests: survey (for testing/validation only)

**NAMESPACE:**
- All `get_*()` functions
- All `survey_*()` functions  
- Metadata helpers: `var_label()`, `val_labels()`, `question_preface()`
- Object creation and conversion
- S3 methods for compatibility (print, summary, coef, vcov, predict, fitted, residuals)

---

### Package 3: surveyweights

**Purpose:** Survey weighting, calibration, and replicate weight creation

**Key Components:**

*Calibration & Raking:*
- `calibrate()` - General calibration to known population totals
- `rake()` - Iterative proportional fitting (raking)
- `poststratify()` - Post-stratification weighting
- `calibrate_to_sample()` - Sample-based calibration (following svrep pattern)
- `calibrate_to_estimate()` - Calibrate to control totals with variance

*Replicate Weight Creation:*
- `create_bootstrap_weights()` - Bootstrap replicate weights
  - Rao-Wu-Yue-Beaumont (RWYB) method
  - Standard bootstrap variants
- `create_jackknife_weights()` - Jackknife replicate weights
  - Delete-one jackknife
  - Random-groups jackknife
- `create_brr_weights()` - Balanced repeated replication
- `create_fay_weights()` - Fay's generalized replication
- `create_gen_boot_weights()` - Generalized survey bootstrap
- `create_sdr_weights()` - Successive difference replication

*Nonresponse Adjustments:*
- `adjust_nonresponse()` - Nonresponse weight adjustments
  - Weighting class adjustments
  - Response propensity adjustments
- `redistribute_weights()` - Weight redistribution (following svrep pattern)
  - Unknown eligibility adjustments
  - Reduce/increase patterns

*Propensity Score Weighting:*
- `create_propensity_weights()` - General propensity score weighting
  - Inverse probability of treatment weighting (IPTW)
  - Average treatment effect (ATE) weights
  - Average treatment on treated (ATT) weights
  - Average treatment on controls (ATC) weights
  - Overlap weights
  - Matching weights
- `estimate_propensity()` - Propensity score estimation
  - Logistic regression
  - Probit regression
  - Machine learning options (random forest, GBM)
- `trim_weights()` - Weight trimming/truncation
- `stabilize_weights()` - Weight stabilization

*Diagnostics & Assessment:*
- `check_balance()` - Covariate balance assessment
  - Standardized mean differences
  - Variance ratios
  - Love plots
- `summarize_weights()` - Weight summary statistics
  - Distribution, extremes, effective sample size
  - Design effects
- `diagnose_propensity()` - Propensity score diagnostics
  - Common support assessment
  - Overlap assessment
  - Extreme weight identification
- `compare_weighted_estimates()` - Compare estimates across weighting schemes

*Utility Functions:*
- `effective_sample_size()` - Calculate effective n after weighting
- `weight_variability()` - Coefficient of variation of weights
- `as_replicate_design()` - Convert Taylor to replicate design
- `as_taylor_design()` - Convert replicate to Taylor (if possible)

**Dependencies:**
- surveycore (required)
- dplyr, tidyr (for internal use)
- stats (glm for propensity estimation)
- Optional: randomForest, gbm, ranger (for ML propensity estimation)

**NAMESPACE:**
- All `create_*()` functions
- All `adjust_*()` functions
- `calibrate()`, `rake()`, `poststratify()`
- `estimate_propensity()`, `trim_weights()`, `stabilize_weights()`
- `redistribute_weights()`
- All diagnostic functions
- Utility functions

**Inspired By:**
- svrep package (Ben Schneider) - replicate weights, sample-based calibration, redistribute_weights
- survey package - calibrate, rake, postStratify
- WeightIt package - propensity score weighting methods
- twang package - propensity score estimation and diagnostics

---

### Package 4: surveytidy

**Purpose:** Tidy verb implementations for survey objects

**Key Components:**
- Full dplyr verb support with design preservation
- Full tidyr verb support with design preservation
- Domain-aware filtering (automatic domain estimation)
- Physical subsetting with `subset()`
- Label preservation through all operations
- Design variable protection (always preserved even if not selected)

**Implemented Verbs:**

*Column operations:*
- `select()`, `mutate()`, `rename()`, `relocate()`, `pull()`, `glimpse()`

*Row operations:*
- `filter()`, `filter_out()` (domain-aware)
- `arrange()`
- `slice()`, `slice_head()`, `slice_tail()` (design-aware)
- `distinct()` (design-aware)

*Group operations:*
- `group_by()`, `ungroup()`

*Multi-column operations:*
- `across()`, `if_any()`, `if_all()`

*Vector functions:*
- `if_else()`, `case_when()`, `desc()`, `row_number()`
- dplyr 1.2.0+: `replace_when()`, `recode_values()`, `replace_values()`, `when_any()`, `when_all()`

*tidyr operations:*
- `drop_na()`
- `separate_wider_*()`, `separate_longer_*()`, `unite()`

*Complex operations (if feasible):*
- `*_join()` operations (merge survey designs)
- `bind_rows()`, `bind_cols()` (combine survey designs)
- `pivot_longer()`, `pivot_wider()` (with design preservation)
- `nest()`, `unnest()`, `unnest_wider()`, `unnest_longer()`

*Special functions:*
- `subset()` - physical subsetting (different from filter's domain estimation)

**Dependencies:**
- surveycore (required)
- dplyr (>= 1.2.0)
- tidyr
- rlang

**NAMESPACE:**
- S7 methods for all dplyr generics
- S7 methods for all tidyr generics
- Helper functions for design preservation

---

### Package 5: surveyverse

**Purpose:** Meta-package for easy installation and loading

**Key Components:**
- Loads surveycore, surveytidy, and surveyweights
- Provides unified startup message
- Version compatibility checking

**Dependencies:**
- surveycore (required)
- surveytidy (required)
- surveyweights (required)

**Usage:**
```r
library(surveyverse)
# Loads all three packages, similar to library(tidyverse)
```

---

## Technical Architecture

### S7 Class Hierarchy

```
survey_metadata                    # Metadata container
└── properties:
    ├── variable_labels: list     # name → label
    ├── value_labels: list        # name → named vector
    ├── question_prefaces: list   # name → preface text
    ├── transformations: list     # name → transformation history
    └── notes: list               # name → user notes

survey_base                        # Abstract base class
├── properties:
│   ├── data: data.frame
│   ├── metadata: survey_metadata
│   ├── weights: numeric
│   └── groups: character         # active grouping variables
└── subclasses:
    ├── survey_taylor
    │   └── properties:
    │       ├── ids: list         # cluster identifiers (multi-stage)
    │       ├── strata: character # stratification variable(s)
    │       ├── fpc: list        # finite population corrections
    │       └── nest: logical     # whether PSUs nest in strata
    │
    ├── survey_replicate
    │   └── properties:
    │       ├── repweights: matrix      # replicate weight matrix
    │       ├── type: character         # "BRR", "JK", "bootstrap", etc.
    │       ├── scale: numeric          # scaling factor
    │       ├── rscales: numeric        # replicate-specific scales
    │       ├── rho: numeric           # Fay parameter (if applicable)
    │       └── mse: logical           # variance estimation approach
    │
    └── survey_twophase
        └── properties:
            ├── phase1: survey_base    # Phase 1 design
            ├── phase2: survey_base    # Phase 2 design  
            └── method: character      # estimation method

survey_glm_fit                     # Regression output
├── properties:
│   ├── coefficients: numeric
│   ├── vcov: matrix
│   ├── fitted_values: numeric
│   ├── residuals: numeric
│   ├── design: survey_base       # original survey object
│   ├── degf: numeric            # degrees of freedom
│   ├── family: list             # glm family
│   ├── formula: formula         # model formula
│   └── metadata: list           # variable labels for predictors
└── S3 compatibility methods:
    ├── print()
    ├── summary()
    ├── coef()
    ├── vcov()
    ├── predict()
    ├── fitted()
    └── residuals()
```

### Metadata System Design

**Philosophy:** Metadata is optional but powerful. All functions work correctly even when metadata is NULL.

**Helper Functions:**
```r
# Getters
var_label(svy, "age")                    # Get variable label
val_labels(svy, "education")             # Get value labels
question_preface(svy, "satisfaction_1")  # Get question preface
transformation(svy, "income_cat")        # Get transformation history
note(svy, "sampling")                    # Get note

# Setters
var_label(svy, "age") <- "Age in years"
val_labels(svy, "education") <- c("HS" = 1, "College" = 2)
question_preface(svy, "q1") <- "Rate your satisfaction with:"
note(svy, "weights") <- "Post-stratified to 2020 Census"

# Bulk operations
get_metadata(svy)                        # Extract all metadata
set_metadata(svy, metadata_list)         # Set all metadata
copy_metadata(from_svy, to_svy, vars)    # Copy metadata between objects
```

**Label Preservation:** All operations in both packages automatically preserve metadata:
- dplyr/tidyr verbs maintain labels
- Analysis functions attach labels to output
- Transformation functions update transformation history

---

## Vendored Code Strategy

### survey Package Variance Code

**Files to Vendor:**
- `svyrecvar()` - Core variance estimation for Taylor series
- `svrepvar()` - Variance estimation for replicate weights
- `twophasevar()` - Two-phase variance estimation
- Supporting functions for specific estimators

**Approach:**
1. **Copy with Attribution:**
   - Include original copyright notice in all vendored files
   - Add README section crediting Thomas Lumley and survey package
   - Maintain references to original survey package version

2. **Refactor for Modularity:**
   - Break large functions into smaller, testable components
   - Add explicit input validation
   - Improve variable naming for clarity
   - Add comprehensive inline documentation

3. **Fallback Strategy:**
   - If refactored code produces different results than original → use original code
   - Include both versions in package
   - Tests verify numerical equivalence

4. **Testing:**
   - Every vendored function has test comparing to survey:: version
   - Tolerance: differences only from rounding (typically < 1e-10)
   - Test across all design types and edge cases

**Location in Package:**
```
surveycore/
├── R/
│   ├── variance-engine-taylor.R      # Vendored Taylor variance code
│   ├── variance-engine-replicate.R   # Vendored replicate variance code
│   ├── variance-engine-twophase.R    # Vendored two-phase variance code
│   └── (all marked @keywords internal - not exported)
```

---

## Analysis Function Design

### Consistent Output Structure

All `get_*()` functions return tibbles with custom S3 classes and rich metadata:

**Class Structure:**
```r
# get_freqs() returns:
class: c("tidysurvey_freqs", "tbl_df", "tbl", "data.frame")

# get_means() returns:
class: c("tidysurvey_means", "tbl_df", "tbl", "data.frame")

# get_diffs() returns:
class: c("tidysurvey_diffs", "tbl_df", "tbl", "data.frame")
```

**Column-Level Attributes:**
Every output column has a label:
```r
attr(result$n, "label") <- "N"
attr(result$mean, "label") <- "Mean"
attr(result$pct, "label") <- "Percent"
```

**Table-Level Attributes:**
```r
attr(result, "variable_name")     # Variable analyzed
attr(result, "variable_label")    # Variable label
attr(result, "group_names")       # Grouping variables (if any)
attr(result, "group_labels")      # Labels for grouping variables
attr(result, "design_type")       # "taylor", "replicate", etc.
attr(result, "dataset")           # Original survey object (optional)
```

### Multi-Variable Support

**Applicable to:** `get_freqs()` and potentially `get_corr()`

**Pattern:**
```r
# Single variable
get_freqs(svy, x = satisfaction_overall)
# Returns: satisfaction_overall, n, pct

# Multi-variable  
get_freqs(svy, x = c(q1, q2, q3), names_to = "item", values_to = "response")
# Returns: item, response, n, pct
# With metadata: attr(., "item_labels") = list(q1 = "...", q2 = "...", q3 = "...")
```

### Domain Estimation

**Built into filter():**
```r
# Automatic domain estimation (correct SEs)
svy %>% 
  filter(age > 18) %>%
  get_means(x = income)
# SE accounts for full design, not just filtered data

# Physical subsetting (SE based on subset only)
svy %>%
  subset(region == "West") %>%
  get_means(x = income)
# SE based only on West region design
```

**Also available as explicit argument:**
```r
# Equivalent to filter() + analyze
get_means(svy, x = income, domain = age > 18)
```

---

## Development Phases

### Phase 0: Foundation (surveycore base)
**Duration:** 2-3 weeks  
**Status:** Planning

**Objectives:**
- Establish S7 class hierarchy
- Implement metadata system
- Create survey objects from data
- Basic print/summary methods
- Conversion utilities

**Deliverables:**

1. **S7 Class System:**
   - `survey_metadata` class with all properties
   - `survey_base` abstract class
   - `survey_taylor` with Taylor-specific properties
   - `survey_replicate` with replicate-specific properties
   - `survey_twophase` with two-phase structure
   - Proper validation for all classes

2. **Metadata System:**
   - `survey_metadata` S7 class
   - Helper functions: `var_label()`, `val_labels()`, `question_preface()`, `transformation()`, `note()`
   - Getters and setters for all metadata types
   - Bulk operations: `get_metadata()`, `set_metadata()`, `copy_metadata()`
   - NULL-safe design (works even without labels)

3. **Object Creation Functions:**
   ```r
   as_survey(data, ids, strata, weights, fpc, nest)
   as_survey_rep(data, repweights, weights, type, scale, rscales, rho, mse)
   as_survey_twophase(phase1_design, phase2_design, method)
   ```

4. **Basic Operations:**
   - `print.survey_base()` - informative display
   - `summary.survey_base()` - design summary with metadata
   - `str.survey_base()` - structure display
   - `dim.survey_base()`, `nrow.survey_base()`, `ncol.survey_base()`

5. **Conversion Utilities:**
   - `as_svydesign()` - convert to survey.design
   - `as_tbl_svy()` - convert to srvyr tbl_svy
   - `from_svydesign()` - import from survey.design
   - `from_tbl_svy()` - import from srvyr

6. **Testing Infrastructure:**
   - Test data generators (with labels):
     - `make_survey_data()` - realistic survey dataset
     - `make_taylor_design()` - sample Taylor design
     - `make_replicate_design()` - sample replicate design
   - S7 class validation tests
   - Metadata system tests
   - Conversion round-trip tests (surveycore → survey → surveycore)

**Success Criteria:**
- Can create survey objects of all three types
- Metadata system works correctly with getters/setters
- Objects print clearly and informatively
- Can convert to/from survey and srvyr objects
- All S7 validation works correctly
- Tests pass with 100% coverage for Phase 0 code

**Does NOT Include:**
- dplyr/tidyr verbs
- Analysis functions
- Variance estimation

---

### Phase 0.5: Tidy Integration (surveytidy package)
**Duration:** 2-3 weeks  
**Can Run in Parallel with Phase 1**  
**Status:** Planning

**Objectives:**
- Implement all dplyr verbs with design preservation
- Implement all tidyr verbs with design preservation  
- Add domain-aware filtering
- Ensure label preservation through all operations
- Test thoroughly against expected behavior

**Deliverables:**

1. **Core dplyr Verbs (No Design Implications):**
   - **Column operations:**
     - `select.survey_base()` - preserve design variables even if not selected
     - `mutate.survey_base()` - add/modify columns, update metadata
     - `rename.survey_base()` - rename columns, preserve all metadata
     - `relocate.survey_base()` - reorder columns
     - `pull.survey_base()` - extract single column
     - `glimpse.survey_base()` - quick data view
   
   - **Row operations:**
     - `arrange.survey_base()` - sort rows (preserve design)
     - `filter.survey_base()` - **DOMAIN-AWARE** (critical for SE accuracy)
     - `filter_out.survey_base()` - inverse filter (domain-aware)
   
   - **Group operations:**
     - `group_by.survey_base()` - set active groups (stored in @groups property)
     - `ungroup.survey_base()` - remove active groups

2. **Multi-Column Operations:**
   - `across()` support in mutate/summarise
   - `if_any()`, `if_all()` support in filter
   - Works with tidyselect throughout

3. **Vector Functions:**
   - Ensure compatibility: `if_else()`, `case_when()`, `desc()`, `row_number()`
   - dplyr 1.2.0+: `replace_when()`, `recode_values()`, `replace_values()`, `when_any()`, `when_all()`
   - These just work on the data.frame, but metadata is preserved

4. **Design-Aware Verbs:**
   - `slice.survey_base()`, `slice_head()`, `slice_tail()` - need to handle design updates
   - `distinct.survey_base()` - remove duplicates, update design
   - `subset.survey_base()` - **physical subsetting** (different from filter!)

5. **tidyr Verbs:**
   - `drop_na.survey_base()` - remove NA rows, preserve design
   - `separate_wider_*.survey_base()` - split columns
   - `separate_longer_*.survey_base()` - split and lengthen
   - `unite.survey_base()` - combine columns

6. **Complex Operations (Stretch Goals):**
   - `*_join.survey_base()` - merge designs (complex!)
   - `bind_rows.survey_base()` - combine surveys (update design)
   - `bind_cols.survey_base()` - add columns (preserve design)
   - `pivot_longer.survey_base()` - reshape with design preservation
   - `pivot_wider.survey_base()` - reshape with design preservation
   - `nest.survey_base()` - create list-columns of survey objects
   - `unnest.survey_base()` - expand list-columns

7. **Domain Estimation Implementation:**
   ```r
   # filter() tracks that this is a domain, not a subset
   svy %>% filter(age > 18)
   # Internally: attr(svy, "domain") <- quote(age > 18)
   # Analysis functions use this for correct variance
   
   # subset() physically subsets (different variance)
   svy %>% subset(region == "West")
   # Physically removes rows, updates design
   ```

8. **Design Variable Protection:**
   ```r
   # Design variables always preserved, even if not selected
   svy %>% select(age, income)
   # Output shows: age, income
   # But internally still has: psu, strata, weights
   # With message: "Survey design variables preserved: psu, strata, weights"
   ```

9. **Testing:**
   - Every verb tested with all design types
   - Design preservation tests
   - Label preservation tests
   - Domain vs. subset behavior tests
   - Edge cases: empty results, all NA, etc.
   - Comparison to expected dplyr behavior (where applicable)

**Success Criteria:**
- All dplyr verbs work correctly with survey objects
- Design variables never lost
- Labels preserved through all operations
- Domain estimation works correctly in filter()
- `subset()` properly distinguishes from `filter()`
- Tests pass with 100% coverage for Phase 0.5 code
- Can complete complex tidyverse workflows on survey objects

**Dependencies:**
- Phase 0 complete (need survey objects to exist)
- Does NOT require Phase 1 (can test without analysis functions)

---

### Phase 1: Core Analysis (surveycore)
**Duration:** 3-4 weeks  
**Status:** Planning

**Objectives:**
- Vendor and refactor survey variance code
- Implement all core analysis functions
- Support all design types (Taylor, replicate, twophase)
- Preserve labels throughout
- Validate against survey package

**Deliverables:**

1. **Vendor Survey Variance Code:**
   - Copy variance estimation functions from survey package:
     - `svyrecvar()` → `variance_taylor()`
     - `svrepvar()` → `variance_replicate()`
     - `twophasevar()` → `variance_twophase()`
   
   - Refactoring goals:
     - Break into smaller, modular functions
     - Add explicit input validation
     - Improve variable naming
     - Comprehensive inline documentation
     - Maintain numerical equivalence with original
   
   - Attribution:
     - Copyright notices in all vendored files
     - README acknowledgment of Thomas Lumley and survey package
     - References to original survey version
   
   - Testing:
     - Every vendored function tested against survey:: equivalent
     - Numerical tolerance: < 1e-10
     - Fallback to original code if refactored version differs

2. **Analysis Functions - Frequencies:**
   ```r
   get_freqs(svy, x, group = NULL, wt = NULL, 
             names_to = "name", values_to = "value",
             name_label = NULL, keep = NULL, 
             drop_zero = FALSE, decimals = 1, na.rm = TRUE)
   ```
   
   - Single-variable and multi-variable modes
   - Support for all design types
   - Post-aggregation filtering via `keep` argument
   - Label preservation and attachment
   - Returns: `tidysurvey_freqs` tibble

3. **Analysis Functions - Means:**
   ```r
   get_means(svy, x, group = NULL, decimals = 3, 
             na.rm = TRUE, conf_level = 0.95, domain = NULL)
   ```
   
   - Design-based means using vendored variance code
   - Confidence intervals (Wald-based)
   - Grouped analysis support
   - Domain estimation support
   - Returns: `tidysurvey_means` tibble

4. **Analysis Functions - Differences:**
   ```r
   get_diffs(svy, x, treats, group = NULL, ref_level = NULL,
             pval_adj = NULL, conf_level = 0.95,
             conf_method = c("wald", "profile"),
             show_means = TRUE, show_pct_change = FALSE,
             decimals = 3, na.rm = TRUE)
   ```
   
   - Bivariate regression approach
   - Multiple comparison adjustments (Bonferroni, Holm, BH, etc.)
   - Reference level specification
   - Both Wald and profile likelihood CIs
   - Returns: `tidysurvey_diffs` tibble

5. **Analysis Functions - Correlations:**
   ```r
   get_corr(svy, x, y = NULL, method = c("pearson", "spearman", "kendall"),
            use = "complete.obs", conf_level = 0.95)
   ```
   
   - Survey-weighted correlations
   - Multiple correlation types
   - Confidence intervals
   - Correlation matrix when y = NULL
   - Returns: `tidysurvey_corr` tibble

6. **Analysis Functions - Totals:**
   ```r
   get_totals(svy, x, group = NULL, decimals = 0,
              na.rm = TRUE, conf_level = 0.95, domain = NULL)
   ```
   
   - Population total estimation
   - Design-based variance
   - Returns: `tidysurvey_totals` tibble

7. **Analysis Functions - Quantiles:**
   ```r
   get_quantiles(svy, x, probs = c(0.25, 0.5, 0.75),
                 group = NULL, na.rm = TRUE, 
                 conf_level = 0.95, domain = NULL)
   ```
   
   - Weighted quantiles (including median)
   - Confidence intervals
   - Returns: `tidysurvey_quantiles` tibble

8. **Analysis Functions - Ratios:**
   ```r
   get_ratios(svy, numerator, denominator, group = NULL,
              decimals = 3, conf_level = 0.95, domain = NULL)
   ```
   
   - Ratio estimation (e.g., persons per household)
   - Design-based variance for ratios
   - Returns: `tidysurvey_ratios` tibble

9. **Common Features Across All Functions:**
   - Support for all design types (taylor, replicate, twophase)
   - Automatic label preservation and attachment
   - Domain estimation support (via domain argument or filter() detection)
   - Grouped analysis via `group` argument or active `group_by()`
   - Rich metadata in output (variable labels, group labels, design info)
   - Consistent output structure (tibble + custom class + attributes)

10. **Testing:**
    - Numerical validation against survey package for every function
    - All design types tested
    - Edge cases: NAs, empty groups, single values
    - Multi-variable mode (where applicable)
    - Domain estimation accuracy
    - Label preservation
    - Grouped analysis
    - Tolerance: results should match survey:: within rounding error

**Success Criteria:**
- All analysis functions produce numerically identical results to survey package
- Functions work correctly with all three design types
- Labels preserved and attached correctly
- Domain estimation works properly
- Grouped analysis works correctly
- Multi-variable mode works (freqs, corr)
- Tests pass with >90% coverage
- No dependencies on survey package (except Suggests for testing)

**Dependencies:**
- Phase 0 complete (need survey objects)
- Phase 0.5 helpful but not required (analysis functions don't need dplyr verbs)

---

### Phase 2.5: Weighting & Calibration (surveyweights package)
**Duration:** 3-4 weeks  
**Status:** Planning

**Objectives:**
- Implement calibration and raking methods
- Create replicate weight generation functions
- Add nonresponse adjustment capabilities
- Implement propensity score weighting
- Provide comprehensive diagnostics

**Deliverables:**

1. **Calibration Methods:**
   ```r
   calibrate(svy, formula, population, method = c("raking", "linear", "logit"))
   rake(svy, formulas, population_margins)
   poststratify(svy, strata, population)
   ```
   
   - General calibration to known totals
   - Raking (iterative proportional fitting)
   - Post-stratification
   - Multiple calibration methods (raking, linear, logit)
   - Updates weights in survey object
   - Preserves metadata

2. **Sample-Based Calibration:**
   ```r
   calibrate_to_sample(primary_design, control_design, formula, method)
   calibrate_to_estimate(design, estimate, vcov_estimate, formula)
   ```
   
   - Following svrep pattern
   - Accounts for variance of control totals
   - Adjusts replicate weights appropriately
   - Proper variance estimation

3. **Replicate Weight Creation:**
   ```r
   # Bootstrap methods
   create_bootstrap_weights(svy, replicates = 500, 
                           type = c("Rao-Wu-Yue-Beaumont", "standard"))
   
   # Jackknife methods
   create_jackknife_weights(svy, replicates, 
                           type = c("delete-1", "random-groups"))
   
   # Other replication methods
   create_brr_weights(svy, fay_rho = 0)
   create_fay_weights(svy, replicates = 100, rho = 0.5)
   create_gen_boot_weights(svy, replicates = 500, 
                          variance_estimator = c("SD1", "SD2"))
   create_sdr_weights(svy, replicates = 100)
   ```
   
   - Implements methods from svrep
   - Converts Taylor designs to replicate designs
   - Multiple bootstrap methods (RWYB, standard)
   - Random-groups jackknife
   - Fay's generalized replication
   - Generalized survey bootstrap
   - Successive difference replication
   - Returns survey_replicate object

4. **Nonresponse Adjustments:**
   ```r
   adjust_nonresponse(svy, response_status, method = c("weighting-class", "propensity"))
   
   redistribute_weights(svy, reduce_if, increase_if, by = NULL)
   ```
   
   - Weighting class adjustments
   - Response propensity models
   - Weight redistribution (svrep pattern)
   - Unknown eligibility handling
   - Applies to both full and replicate weights

5. **Propensity Score Weighting:**
   ```r
   # Estimate propensity scores
   pscore <- estimate_propensity(data, treatment ~ age + education + income,
                                 method = c("logistic", "probit", "rf", "gbm"))
   
   # Create weights
   create_propensity_weights(svy, propensity, 
                            estimand = c("ATE", "ATT", "ATC", "overlap", "matching"),
                            stabilize = TRUE, trim_at = c(0.01, 0.99))
   
   # Or combined
   svy_weighted <- svy %>%
     add_propensity_weights(treatment ~ age + education,
                           estimand = "ATE",
                           method = "logistic")
   ```
   
   - Multiple estimand types (ATE, ATT, ATC, overlap, matching)
   - Propensity estimation via logistic, probit, or ML methods
   - Weight stabilization
   - Weight trimming/truncation
   - Extreme weight handling
   - Integrates with survey objects

6. **Diagnostics & Balance Assessment:**
   ```r
   check_balance(svy_weighted, covariates = ~ age + education + income,
                un_weighted = svy_original)
   
   summarize_weights(svy, by = response_status)
   
   diagnose_propensity(svy, treatment ~ covariates, 
                      show_plots = TRUE)
   
   compare_weighted_estimates(list(original = svy1, adjusted = svy2),
                             formula = ~ outcome)
   ```
   
   - Standardized mean differences
   - Variance ratios
   - Love plots for balance visualization
   - Weight distribution summaries
   - Effective sample size calculations
   - Propensity score overlap assessment
   - Common support diagnostics
   - Extreme weight identification
   - Side-by-side estimate comparisons

7. **Utility Functions:**
   ```r
   effective_sample_size(svy)  # Kish's approximate effective n
   weight_variability(svy)      # CV of weights
   trim_weights(svy, lower = 0.1, upper = 0.9)
   stabilize_weights(svy, by = NULL)
   ```

8. **Object Conversions:**
   ```r
   as_replicate_design(taylor_svy, method = "bootstrap", replicates = 500)
   as_taylor_design(replicate_svy)  # if possible
   ```

9. **Testing:**
   - Calibration matches survey::calibrate() and survey::rake()
   - Replicate weights match svrep package output
   - Propensity weights produce balanced samples
   - Nonresponse adjustments work correctly
   - Weight diagnostics accurate
   - All methods work with metadata preservation

**Success Criteria:**
- Calibration numerically equivalent to survey package
- Replicate weight creation matches svrep package
- Propensity weighting achieves covariate balance
- Diagnostics identify problems correctly
- Metadata preserved through all operations
- >90% test coverage

**Dependencies:**
- Phase 0 complete (need survey objects)
- Can be developed in parallel with Phase 1-2

---

### Phase 3: Regression & Expansion (surveycore)
**Duration:** 2-3 weeks  
**Status:** Planning

**Objectives:**
- Implement survey-weighted regression
- Add regression output tidying
- Implement crosstabulations
- Complete core documentation

**Deliverables:**

1. **Regression - survey_glm():**
   ```r
   survey_glm(svy, formula, family = gaussian(), 
              start = NULL, na.action = na.omit)
   ```
   
   - Returns: S7 `survey_glm_fit` object
   - Supports all glm families
   - Uses vendored variance code for SEs
   - Proper degrees of freedom from design
   - Design-based variance-covariance matrix
   
   - S3 compatibility methods:
     - `print.survey_glm_fit()` - concise output
     - `summary.survey_glm_fit()` - detailed output (like summary.glm)
     - `coef.survey_glm_fit()` - extract coefficients
     - `vcov.survey_glm_fit()` - variance-covariance matrix
     - `predict.survey_glm_fit()` - predictions (returns numeric vector)
     - `fitted.survey_glm_fit()` - fitted values (returns numeric vector)
     - `residuals.survey_glm_fit()` - residuals (returns numeric vector)

2. **Regression - clean():**
   ```r
   clean(model, conf_level = 0.95, include_reference = TRUE)
   ```
   
   - Tidy regression output (like broom::tidy but with metadata)
   - Returns tibble with: term, estimate, std_error, statistic, p_value, conf_low, conf_high
   - Attaches variable labels as attributes
   - Includes reference levels for factors
   - Works with survey_glm_fit objects
   - Rich metadata for downstream use

3. **Crosstabulation - get_crosstab():**
   ```r
   get_crosstab(svy, row, col, group = NULL, 
                test = TRUE, decimals = 1, na.rm = TRUE)
   ```
   
   - Two-way and multi-way crosstabulations
   - Survey-adjusted chi-square test (Rao-Scott)
   - Cell counts and percentages (row, column, total)
   - Standardized residuals
   - Returns: `tidysurvey_crosstab` tibble
   - Rich output suitable for publication

4. **Additional Functionality:**
   - Hypothesis testing utilities
   - Confidence interval utilities
   - Design effect calculations (deff, deft)

5. **Documentation - Vignettes:**
   - `getting-started.Rmd` - Basic workflow, object creation, simple analysis
   - `survey-designs.Rmd` - All design types, when to use each, examples
   - `analysis-functions.Rmd` - Complete guide to all get_*() functions
   - `regression.Rmd` - survey_glm() usage, interpretation, diagnostics
   - `metadata-labels.Rmd` - Working with labels, metadata system
   - `intro-survey-analysis.Rmd` - Brief intro to survey methodology (with external links)

6. **Documentation - Function Reference:**
   - Complete roxygen2 documentation for all exported functions
   - Extensive examples for each function
   - Cross-references between related functions
   - Mathematical formulas where relevant (variance estimation, test statistics)

7. **Testing:**
   - survey_glm() output matches survey::svyglm()
   - clean() produces correct tidy output
   - get_crosstab() matches survey::svychisq()
   - All documentation examples run correctly

**Success Criteria:**
- survey_glm() numerically equivalent to survey::svyglm()
- S3 methods work correctly (predict, fitted, residuals)
- clean() produces rich, tidy output with metadata
- Crosstabs match survey package results
- All vignettes complete and render correctly
- Function documentation complete
- pkgdown site builds successfully

**Dependencies:**
- Phase 1 complete (need analysis functions for examples)
- Phase 0.5 helpful for vignette examples (dplyr workflows)
- Phase 2.5 helpful for calibration examples

---

### Phase 4: Polish & Release (all packages)
**Duration:** 2-3 weeks  
**Status:** Planning

**Objectives:**
- Complete documentation for all three packages
- Build pkgdown websites
- Performance optimization
- Comprehensive testing
- Prepare for 0.1.0 release

**Deliverables:**

1. **Documentation - surveycore:**
   - Complete pkgdown website
   - All vignettes polished
   - Function reference organized by topic
   - README with quick start examples
   - NEWS.md with release notes
   - Citation file (CITATION)
   - Contributing guidelines

2. **Documentation - surveytidy:**
   - pkgdown website
   - Vignettes:
     - `tidy-survey-workflows.Rmd` - Using dplyr/tidyr with survey objects
     - `domain-estimation.Rmd` - filter() vs subset()
   - Function reference (all verbs)
   - README with examples
   - NEWS.md

3. **Documentation - surveyverse:**
   - Meta-package website
   - README explaining ecosystem
   - Quick start guide
   - Links to other package sites
   - NEWS.md

4. **Performance Optimization:**
   - Profile analysis functions
   - Optimize hot paths (variance calculations)
   - Benchmark against survey package
   - Document performance characteristics
   - Consider Rcpp for critical sections (if needed)

5. **Testing - Comprehensive:**
   - surveycore: >90% code coverage
   - surveytidy: >90% code coverage
   - Real-world dataset examples (from survey package or public data)
   - Edge case handling documented
   - Known limitations documented
   - Cross-package integration tests

6. **Optional - Reporting Functions:**
   ```r
   export_freqs(result, file, format = c("excel", "word", "html"))
   export_means(result, file, format)
   export_crosstab(result, file, format)
   create_codebook(svy, file)
   ```
   
   - Export analysis results with labels
   - Multiple output formats
   - Professional formatting
   - Uses metadata for human-readable output

7. **Release Preparation:**
   - Version all three packages at 0.1.0
   - CRAN checks pass (`R CMD check`)
   - All examples run without errors
   - Spell check on documentation
   - URL check on documentation
   - Reverse dependency checks (none yet, but check anyway)
   - Update all version dependencies

8. **Release Materials:**
   - Blog post announcing release
   - Twitter/social media announcement
   - Comparison to survey/srvyr (migration guide)
   - Example analysis showcasing features

**Success Criteria:**
- All three packages at 0.1.0
- Complete documentation and websites
- All tests passing
- Performance acceptable (within 2x of survey package)
- Ready for CRAN submission (if desired)
- Clear migration path from survey/srvyr

**Dependencies:**
- Phase 0, 0.5, 1, 2 complete
- All major features implemented

---

### Phase 4: Polish & Release (all packages)
**Duration:** 2-3 weeks  
**Status:** Planning

**Objectives:**
- Complete documentation for all four packages
- Build pkgdown websites
- Performance optimization
- Comprehensive testing
- Prepare for 0.1.0 release

**Deliverables:**

1. **Documentation - surveycore:**
   - Complete pkgdown website
   - All vignettes polished
   - Function reference organized by topic
   - README with quick start examples
   - NEWS.md with release notes
   - Citation file (CITATION)
   - Contributing guidelines

2. **Documentation - surveytidy:**
   - pkgdown website
   - Vignettes:
     - `tidy-survey-workflows.Rmd` - Using dplyr/tidyr with survey objects
     - `domain-estimation.Rmd` - filter() vs subset()
   - Function reference (all verbs)
   - README with examples
   - NEWS.md

3. **Documentation - surveyweights:**
   - pkgdown website
   - Vignettes:
     - `calibration-and-raking.Rmd` - Weight calibration methods
     - `replicate-weights.Rmd` - Creating replicate weights
     - `nonresponse-adjustment.Rmd` - Handling nonresponse
     - `propensity-weighting.Rmd` - Propensity score methods
     - `weight-diagnostics.Rmd` - Assessing weight quality
   - Function reference
   - README with examples
   - NEWS.md

4. **Documentation - surveyverse:**
   - Meta-package website
   - README explaining ecosystem
   - Quick start guide
   - Links to other package sites
   - NEWS.md

5. **Performance Optimization:**
   - Profile analysis functions
   - Optimize hot paths (variance calculations)
   - Benchmark against survey package
   - Document performance characteristics
   - Consider Rcpp for critical sections (if needed)

6. **Testing - Comprehensive:**
   - surveycore: >90% code coverage
   - surveytidy: >90% code coverage
   - surveyweights: >90% code coverage
   - Real-world dataset examples (from survey package or public data)
   - Edge case handling documented
   - Known limitations documented
   - Cross-package integration tests

7. **Optional - Reporting Functions:**
   ```r
   export_freqs(result, file, format = c("excel", "word", "html"))
   export_means(result, file, format)
   export_crosstab(result, file, format)
   create_codebook(svy, file)
   ```
   
   - Export analysis results with labels
   - Multiple output formats
   - Professional formatting
   - Uses metadata for human-readable output

8. **Release Preparation:**
   - Version all four packages at 0.1.0
   - CRAN checks pass (`R CMD check`)
   - All examples run without errors
   - Spell check on documentation
   - URL check on documentation
   - Reverse dependency checks (none yet, but check anyway)
   - Update all version dependencies

9. **Release Materials:**
   - Blog post announcing release
   - Twitter/social media announcement
   - Comparison to survey/srvyr/svrep (migration guide)
   - Example analysis showcasing features

**Success Criteria:**
- All four packages at 0.1.0
- Complete documentation and websites
- All tests passing
- Performance acceptable (within 2x of survey package)
- Ready for CRAN submission (if desired)
- Clear migration path from survey/srvyr/svrep

**Dependencies:**
- Phase 0, 0.5, 1, 2, 2.5, 3 complete
- All major features implemented

---

### Phase 5: Extensions (future)
**Status:** Future Planning

**Potential Additions:**

1. **Psychometric Package (surveyscales):**
   - Survey-weighted EFA: `get_efa()`
   - Cronbach's alpha: `get_cronbach()`
   - Scale reliability: `get_reliability()`
   - Item statistics: `get_item_stats()`
   - CFA support: `get_cfa()`

2. **Advanced Models:**
   - Cox regression: `survey_coxph()`
   - Custom contrasts: `get_contrasts()`
   - Hypothesis tests: `survey_test()`
   - Mixed models (if feasible with survey weights)

3. **Enhanced Reporting:**
   - Demographic tables: `report_demographics()`
   - Survey quality: `report_survey_quality()`
   - Automated reports: `create_survey_report()`
   - Publication-ready tables

4. **Calibration & Weighting:**
   - `survey_calibrated` class
   - Post-stratification: `poststratify()`
   - Raking: `rake()`
   - Trim weights: `trim_weights()`

5. **Database Integration:**
   - `survey_db` class for large surveys
   - Support for database backends
   - Lazy evaluation for huge datasets

**Timeline:** Post-0.1.0 release, based on user feedback and demand

---

## Testing Strategy

### Unit Tests

**surveycore:**
- S7 class validation tests
- Metadata system tests
- Object creation tests
- Conversion utility tests
- **Numerical validation:** Every analysis function tested against survey::
  - Tolerance: < 1e-10 for point estimates
  - Tolerance: < 1e-8 for variance estimates
  - All design types tested
  - Edge cases: NA handling, empty groups, single values

**surveytidy:**
- Every dplyr verb tested
- Design preservation tests
- Label preservation tests
- Domain vs subset behavior tests
- Complex workflow tests (chained operations)

**surveyverse:**
- Loading tests
- Version compatibility tests
- Startup message tests

### Integration Tests

- End-to-end workflows across packages
- Real-world analysis examples
- Performance benchmarks vs survey package

### Test Data

**Strategy:** Create self-contained test datasets (don't rely on survey package data)

**Test Datasets:**
```r
make_survey_data(n = 1000, design = "taylor")
# Generates realistic survey data with:
# - Multiple demographic variables (age, gender, education, income)
# - Outcome variables (satisfaction, health, etc.)
# - Complete haven labels (variable labels, value labels, question prefaces)
# - Design variables (PSU, strata, weights, FPC)

make_survey_data(n = 1000, design = "replicate")
# Same as above but with replicate weights

make_survey_data(n = 1000, design = "twophase")
# Two-phase sampling design
```

### Continuous Integration

- GitHub Actions for R CMD check
- Test on: Ubuntu, macOS, Windows
- Test on: R-release, R-devel
- Code coverage reporting (covr)
- pkgdown site deployment

---

## Documentation Strategy

### Function Documentation (roxygen2)

**Required Sections:**
- `@description` - What the function does
- `@param` - Every parameter documented
- `@return` - Detailed return value structure
- `@details` - Implementation details, formulas (if relevant)
- `@examples` - Realistic examples with output
- `@seealso` - Links to related functions
- `@references` - Survey methodology references where applicable

**Style:**
- Sentence case for all headings
- Consistent terminology across functions
- Mathematical formulas in LaTeX where needed
- Examples use realistic survey data

### Vignettes

**surveycore Vignettes:**
1. **Getting Started** - 15-20 min read
   - Installing packages
   - Creating survey objects
   - Basic analysis workflow
   - Understanding output

2. **Survey Designs** - 20-25 min read
   - Taylor series designs (stratified, clustered, multi-stage)
   - Replicate weight designs (BRR, JK, bootstrap)
   - Two-phase designs
   - When to use each type
   - Converting from survey/srvyr

3. **Analysis Functions** - 30-40 min read
   - Complete guide to all get_*() functions
   - Grouped analysis
   - Multi-variable analysis
   - Domain estimation
   - Interpreting output

4. **Regression** - 20-25 min read
   - survey_glm() usage
   - Model interpretation
   - Predictions and diagnostics
   - Using clean() for tidy output

5. **Metadata & Labels** - 15-20 min read
   - Label system overview
   - Setting and retrieving labels
   - Transformation tracking
   - Using labels in reports

6. **Intro to Survey Analysis** - 10-15 min read
   - Why survey weights matter
   - Design effects
   - Variance estimation basics
   - Links to external resources

**surveytidy Vignettes:**
1. **Tidy Survey Workflows** - 25-30 min read
   - Using dplyr verbs with survey objects
   - Using tidyr verbs with survey objects
   - Complex multi-step workflows
   - Best practices

2. **Domain Estimation** - 15-20 min read
   - Understanding domains vs subsets
   - Using filter() correctly
   - When to use subset()
   - Impact on standard errors

### pkgdown Sites

**All three packages get pkgdown sites:**

**Structure:**
```
surveycore.tidysurvey.org/
├── Reference (function documentation by topic)
├── Articles (vignettes)
├── News (changelog)
└── Get Started (quick start)

surveytidy.tidysurvey.org/
├── Reference (verb documentation)
├── Articles (vignettes)
└── Get Started

surveyverse.tidysurvey.org/
├── Overview of ecosystem
├── Quick start guide
├── Links to package sites
└── News
```

**Features:**
- Search functionality
- Code syntax highlighting
- Responsive design
- Deployed via GitHub Actions

---

## Timeline Estimate

### Optimistic Timeline (Full-time equivalent)
- Phase 0: 2 weeks
- Phase 0.5: 2 weeks (parallel to Phase 1)
- Phase 1: 3 weeks
- Phase 2: 2 weeks  
- Phase 2.5: 3 weeks (can be parallel to Phase 1-2)
- Phase 3: 2 weeks
- Phase 4: 2 weeks
- **Total: ~13-16 weeks (without parallelization), ~11-13 weeks (with parallelization)**

### Realistic Timeline (Part-time, with reviews/iterations)
- Phase 0: 3-4 weeks
- Phase 0.5: 3-4 weeks
- Phase 1: 4-5 weeks
- Phase 2: 3-4 weeks
- Phase 2.5: 4-5 weeks
- Phase 3: 3-4 weeks
- Phase 4: 3-4 weeks
- **Total: ~23-30 weeks (5.5-7.5 months)**

### Key Milestones
- **End of Phase 0:** Survey objects exist and work
- **End of Phase 0.5:** Can use tidyverse verbs on survey objects
- **End of Phase 1:** Can perform core survey analyses
- **End of Phase 2:** Can do regression, crosstabs, have complete docs
- **End of Phase 2.5:** Can calibrate weights, create replicates, propensity weighting
- **End of Phase 3:** Can do regression, crosstabs, complete core docs
- **End of Phase 4:** Ready for 0.1.0 release

---

## Success Metrics

### Phase 0
- ✅ Can create all three design types
- ✅ S7 validation catches errors
- ✅ Metadata system works correctly
- ✅ Can convert to/from survey/srvyr
- ✅ 100% test coverage for implemented code

### Phase 0.5
- ✅ All dplyr verbs work correctly
- ✅ Design variables never lost
- ✅ Labels preserved through operations
- ✅ Domain estimation works in filter()
- ✅ Can complete complex tidyverse workflows

### Phase 1
- ✅ Numerical equivalence with survey package (< 1e-10 tolerance)
- ✅ All functions work with all design types
- ✅ Labels automatically preserved and attached
- ✅ Domain estimation accurate
- ✅ >90% test coverage

### Phase 2
- ✅ survey_glm() matches survey::svyglm()
- ✅ Crosstabs match survey::svychisq()
- ✅ All vignettes complete
- ✅ pkgdown sites build successfully

### Phase 2.5
- ✅ Calibration matches survey::calibrate() and survey::rake()
- ✅ Replicate weights match svrep package
- ✅ Propensity weighting achieves covariate balance
- ✅ All diagnostics work correctly
- ✅ >90% test coverage for surveyweights

### Phase 3
- ✅ Additional regression features complete
- ✅ Extended documentation complete

### Phase 4
- ✅ All four packages at 0.1.0
- ✅ CRAN checks pass
- ✅ Complete documentation
- ✅ Performance within 2x of survey package
- ✅ Ready for public release

---

## Open Questions & Decisions Needed

### Technical Decisions
1. ✅ **DECIDED:** S7 for class system
2. ✅ **DECIDED:** Metadata in separate property (not on data.frame columns)
3. ✅ **DECIDED:** Vendor survey variance code (with attribution)
4. ✅ **DECIDED:** Three separate packages (surveycore, surveytidy, surveyverse)
5. ✅ **DECIDED:** Replicate weights use type property, not subclasses

### Naming Decisions
1. ✅ **DECIDED:** surveycore, surveytidy, surveyverse
2. ✅ **DECIDED:** survey_* for class names
3. ✅ **DECIDED:** get_* for analysis functions

### Feature Decisions
1. ✅ **DECIDED:** Domain estimation via filter() detection + domain argument
2. ✅ **DECIDED:** survey_glm() returns S7 with S3 compatibility
3. ✅ **DECIDED:** Psychometrics → Phase 4, separate package
4. ✅ **DECIDED:** Reporting functions → Phase 3 (optional) or Phase 4

### Release Decisions
1. **PENDING:** Submit to CRAN or keep on GitHub?
2. **PENDING:** Target audience emphasis (methodologists vs tidyverse users)?
3. **PENDING:** License (MIT? GPL-3?)

---

## Risk Mitigation

### Technical Risks

**Risk:** Vendored variance code produces different results than survey package  
**Mitigation:** 
- Extensive numerical testing (tolerance < 1e-10)
- Fallback to original code if refactored version differs
- Both versions in package if needed

**Risk:** S7 system too new, lacks community support  
**Mitigation:**
- S7 is Posit-supported and actively developed
- Can fall back to S3 if S7 proves problematic
- Early testing of S7 in Phase 0

**Risk:** dplyr verb integration too complex  
**Mitigation:**
- Phase 0.5 isolated from core functionality
- Can release surveycore alone if surveytidy problematic
- Extensive testing against expected behavior

### Timeline Risks

**Risk:** Scope creep, phases take longer than estimated  
**Mitigation:**
- Clear phase boundaries with deliverables
- Can release after Phase 2 if needed (skip Phase 3 polish)
- Defer optional features (reporting, psychometrics)

**Risk:** Testing reveals fundamental issues requiring redesign  
**Mitigation:**
- Early validation in Phase 0
- Continuous testing against survey package
- Iterative development with feedback loops

---

## Next Steps

### Immediate (Before Starting Phase 0)
1. Create GitHub repositories for all three packages
2. Set up basic package structure (DESCRIPTION, etc.)
3. Create detailed Phase 0 implementation plan
4. Set up testing infrastructure
5. Review and finalize S7 class design

### Phase 0 Kickoff
1. Implement S7 class hierarchy
2. Build metadata system
3. Create object creation functions
4. Implement print/summary methods
5. Set up test framework

### Communication Plan
1. Document progress in GitHub issues
2. Regular check-ins on design decisions
3. Share prototypes for feedback
4. Maintain changelog in NEWS.md

---

## Appendix: Comparison to Existing Packages

### vs. survey package
**Advantages of surveycore:**
- ✅ Tidy syntax, pipe-friendly
- ✅ Automatic label preservation
- ✅ Consistent output structure
- ✅ S7 validation prevents errors
- ✅ Modern R practices

**What survey does better:**
- More design types (multiframe, panel)
- Longer track record, more testing
- More advanced features (some calibration methods)

**Migration path:** Easy conversion utilities in both directions

### vs. srvyr package
**Advantages of surveytidy:**
- ✅ More comprehensive verb support
- ✅ Built-in label preservation
- ✅ Consistent API (not summarise-wrapped)
- ✅ Domain estimation automatic
- ✅ Better metadata system

**What srvyr does better:**
- Already exists and mature
- Established user base

**Migration path:** Similar syntax, easy to switch

### vs. svrep package
**Advantages of surveyweights:**
- ✅ Integrated with full survey ecosystem
- ✅ Adds propensity score weighting
- ✅ Unified interface for all weighting methods
- ✅ Built-in diagnostics and balance assessment
- ✅ Metadata preservation throughout

**What svrep does better:**
- Already exists and mature
- Specialized focus on replicate weights
- Extensive testing and validation

**Migration path:** Very similar API, inspired by svrep patterns

### Unique Value Proposition
surveyverse is the **only** R survey package ecosystem that:
1. Uses modern S7 object system
2. Has comprehensive label/metadata preservation built-in
3. Provides full tidyverse integration
4. Is statistically rigorous (survey package code) AND user-friendly
5. Integrates weighting, calibration, and propensity methods in one place
6. Designed specifically for survey research workflows (not a generic wrapper)

---

**End of Roadmap**

*This is a living document and will be updated as the project progresses.*
