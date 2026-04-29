# pool_pvals() rejects NULL with not_list class

    Code
      pool_pvals(NULL)
    Condition
      Error in `pool_pvals()`:
      x `results` must be a list of tibbles, not <NULL>.
      i Got <NULL>.
      v Wrap a single result in `list()` (e.g., `pool_pvals(list(get_diffs(...)))`). For multiple results, supply a named or unnamed list.

# pool_pvals() rejects a bare tibble with not_list class

    Code
      pool_pvals(tibble::tibble(p_value = 0.05))
    Condition
      Error in `pool_pvals()`:
      x `results` must be a list of tibbles, not <tbl_df>.
      i Got <tbl_df/tbl/data.frame>.
      v Wrap a single result in `list()` (e.g., `pool_pvals(list(get_diffs(...)))`). For multiple results, supply a named or unnamed list.

# pool_pvals() rejects an atomic vector with not_list class

    Code
      pool_pvals(c(0.01, 0.05))
    Condition
      Error in `pool_pvals()`:
      x `results` must be a list of tibbles, not <numeric>.
      i Got <numeric>.
      v Wrap a single result in `list()` (e.g., `pool_pvals(list(get_diffs(...)))`). For multiple results, supply a named or unnamed list.

# pool_pvals() rejects empty list with empty class

    Code
      pool_pvals(list())
    Condition
      Error in `pool_pvals()`:
      x `results` must be a list of length >= 1.
      i Got an empty list.

# pool_pvals() rejects invalid method (string) with invalid_method

    Code
      pool_pvals(res, method = "fancy")
    Condition
      Error in `pool_pvals()`:
      x `method` must be a valid method for `stats::p.adjust()`.
      i Valid methods: "holm", "hochberg", "hommel", "bonferroni", "BH", "BY", "fdr", or "none".
      i Got "fancy".

# pool_pvals() rejects invalid method (length > 1) with invalid_method

    Code
      pool_pvals(res, method = c("BH", "holm"))
    Condition
      Error in `pool_pvals()`:
      x `method` must be a valid method for `stats::p.adjust()`.
      i Valid methods: "holm", "hochberg", "hommel", "bonferroni", "BH", "BY", "fdr", or "none".
      i Got "BH" and "holm".

# pool_pvals() reports element missing p_col with missing_pcol class

    Code
      pool_pvals(res)
    Condition
      Error in `pool_pvals()`:
      x All elements of `results` must contain a column named "p_value".
      i Element missing the column: "b".
      v Add the column or pass a different `p_col`.

# pool_pvals() reports id_col collision with id_col_collision class

    Code
      pool_pvals(res)
    Condition
      Error in `pool_pvals()`:
      x `id_col` "source" collides with an existing column in 1 input element.
      i Offending element: "1".
      v Rename the offending column, or supply a different `id_col`.

# pool_pvals() reports out-of-range pooled p-values with invalid_pvalues

    Code
      pool_pvals(res)
    Condition
      Error in `pool_pvals()`:
      x Pooled column "p_value" contains 1 value(s) outside `[0, 1]`.
      i Offending row (source / row-within-source): "1/2".
      v Verify that `p_col` names a p-value column, not a coefficient or test statistic.

# print.survey_pooled_pvals() snapshot for a representative input

    Code
      print(out)
    Message
      <survey_pooled_pvals: method = "BH", family_size = 3, 1 significant at alpha =
      0.05>
    Output
      # A tibble: 4 x 4
        term  p_value source p_value_adj
        <chr>   <dbl> <chr>        <dbl>
      1 x       0.001 a            0.003
      2 y       0.04  a            0.06 
      3 z       0.5   b            0.5  
      4 w      NA     c           NA    
    Message
      # 1 p-value was NA and excluded from the family

# print.survey_pooled_pvals() prints NA footer only when n_na > 0

    Code
      print(out_no_na)
    Message
      <survey_pooled_pvals: method = "BH", family_size = 3, 1 significant at alpha =
      0.05>
    Output
      # A tibble: 3 x 3
        p_value source p_value_adj
          <dbl> <chr>        <dbl>
      1    0.01 a             0.03
      2    0.04 a             0.06
      3    0.5  b             0.5 

---

    Code
      print(out_with_na)
    Message
      <survey_pooled_pvals: method = "BH", family_size = 2, 1 significant at alpha =
      0.05>
    Output
      # A tibble: 4 x 3
        p_value source p_value_adj
          <dbl> <chr>        <dbl>
      1    0.01 a             0.02
      2   NA    a            NA   
      3   NA    b            NA   
      4    0.5  b             0.5 
    Message
      # 2 p-values were NA and excluded from the family

