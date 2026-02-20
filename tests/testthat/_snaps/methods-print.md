# print.survey_taylor default output matches snapshot

    Code
      print(d)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_taylor> (Taylor series linearization)
      Sample size: 50
      
    Output
      # A tibble: 50 x 8
         psu   strata      fpc    wt    y1      y2    y3 group
         <chr> <chr>     <dbl> <dbl> <dbl>   <dbl> <int> <chr>
       1 psu_1 stratum_1   378  14.3  50.9 -0.122      1 A    
       2 psu_1 stratum_1   378  21.8  20.1  0.188      0 B    
       3 psu_1 stratum_1   378  14.4  52.8  0.119      1 B    
       4 psu_2 stratum_1   378  18.9  46.3 -0.0251     0 A    
       5 psu_2 stratum_1   378  23.0  51.9  0.108      0 B    
       6 psu_2 stratum_1   378  11.0  55.8 -0.485      0 C    
       7 psu_2 stratum_1   378  13.8  64.0 -0.504      0 A    
       8 psu_2 stratum_1   378  14.2  42.7 -1.66       0 B    
       9 psu_3 stratum_1   378  16.5  63.0 -0.382      1 C    
      10 psu_3 stratum_1   378  13.7  53.4 -0.513      1 A    
      # i 40 more rows

# print.survey_taylor full=TRUE output matches snapshot

    Code
      print(d, full = TRUE)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_taylor> (Taylor series linearization)
      Sample size: 50
      Weighted N: 625
      
      
      -- Design specification --
      
      * IDs: psu (10 PSUs)
      * Strata: strata (2 strata)
      * Weights: wt
      * Weights provided as: sampling weights
      * FPC: fpc
      * Nesting: TRUE
      
      Design variables: psu, wt, strata, and fpc
      
      
      -- Weight distribution --
      
      * Range: 6.04 – 22.97
      * Mean: 12.5
      * CV: 0.323
      
      
      -- Metadata --
      
      0 variable(s) labeled
      
    Output
      # A tibble: 50 x 8
         psu   strata      fpc    wt    y1      y2    y3 group
         <chr> <chr>     <dbl> <dbl> <dbl>   <dbl> <int> <chr>
       1 psu_1 stratum_1   378  14.3  50.9 -0.122      1 A    
       2 psu_1 stratum_1   378  21.8  20.1  0.188      0 B    
       3 psu_1 stratum_1   378  14.4  52.8  0.119      1 B    
       4 psu_2 stratum_1   378  18.9  46.3 -0.0251     0 A    
       5 psu_2 stratum_1   378  23.0  51.9  0.108      0 B    
       6 psu_2 stratum_1   378  11.0  55.8 -0.485      0 C    
       7 psu_2 stratum_1   378  13.8  64.0 -0.504      0 A    
       8 psu_2 stratum_1   378  14.2  42.7 -1.66       0 B    
       9 psu_3 stratum_1   378  16.5  63.0 -0.382      1 C    
      10 psu_3 stratum_1   378  13.7  53.4 -0.513      1 A    
      # i 40 more rows

# print.survey_replicate default output matches snapshot

    Code
      print(d)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_replicate> (BRR, 5 replicates)
      Sample size: 50
      
    Output
      # A tibble: 50 x 13
         psu   strata      fpc    wt    y1      y2    y3 group repwt_1 repwt_2 repwt_3
         <chr> <chr>     <dbl> <dbl> <dbl>   <dbl> <int> <chr>   <dbl>   <dbl>   <dbl>
       1 psu_1 stratum_1   378  14.3  50.9 -0.122      1 A        14.4    13.2   13.3 
       2 psu_1 stratum_1   378  21.8  20.1  0.188      0 B        19.0    22.6   20.3 
       3 psu_1 stratum_1   378  14.4  52.8  0.119      1 B        11.6    12.6   15.2 
       4 psu_2 stratum_1   378  18.9  46.3 -0.0251     0 A        17.5    19.0   19.0 
       5 psu_2 stratum_1   378  23.0  51.9  0.108      0 B        22.9    21.2   24.3 
       6 psu_2 stratum_1   378  11.0  55.8 -0.485      0 C        12.7    13.1    9.77
       7 psu_2 stratum_1   378  13.8  64.0 -0.504      0 A        15.3    12.5   15.1 
       8 psu_2 stratum_1   378  14.2  42.7 -1.66       0 B        14.0    15.2   14.9 
       9 psu_3 stratum_1   378  16.5  63.0 -0.382      1 C        18.0    15.3   15.9 
      10 psu_3 stratum_1   378  13.7  53.4 -0.513      1 A        11.8    13.1   15.8 
      # i 40 more rows
      # i 2 more variables: repwt_4 <dbl>, repwt_5 <dbl>

# print.survey_replicate full=TRUE output matches snapshot

    Code
      print(d, full = TRUE)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_replicate> (BRR, 5 replicates)
      Sample size: 50
      Weighted N: 625
      
      
      -- Design specification --
      
      * Weights: wt
      * Replicates: 5 BRR replicate weight column(s)
      * Scale: 0.2
      * MSE: TRUE
      * FPC: not specified
      
      
      -- Weight distribution --
      
      * Range: 6.04 – 22.97
      * Mean: 12.5
      * CV: 0.323
      
      
      -- Metadata --
      
      0 variable(s) labeled
      
    Output
      # A tibble: 50 x 13
         psu   strata      fpc    wt    y1      y2    y3 group repwt_1 repwt_2 repwt_3
         <chr> <chr>     <dbl> <dbl> <dbl>   <dbl> <int> <chr>   <dbl>   <dbl>   <dbl>
       1 psu_1 stratum_1   378  14.3  50.9 -0.122      1 A        14.4    13.2   13.3 
       2 psu_1 stratum_1   378  21.8  20.1  0.188      0 B        19.0    22.6   20.3 
       3 psu_1 stratum_1   378  14.4  52.8  0.119      1 B        11.6    12.6   15.2 
       4 psu_2 stratum_1   378  18.9  46.3 -0.0251     0 A        17.5    19.0   19.0 
       5 psu_2 stratum_1   378  23.0  51.9  0.108      0 B        22.9    21.2   24.3 
       6 psu_2 stratum_1   378  11.0  55.8 -0.485      0 C        12.7    13.1    9.77
       7 psu_2 stratum_1   378  13.8  64.0 -0.504      0 A        15.3    12.5   15.1 
       8 psu_2 stratum_1   378  14.2  42.7 -1.66       0 B        14.0    15.2   14.9 
       9 psu_3 stratum_1   378  16.5  63.0 -0.382      1 C        18.0    15.3   15.9 
      10 psu_3 stratum_1   378  13.7  53.4 -0.513      1 A        11.8    13.1   15.8 
      # i 40 more rows
      # i 2 more variables: repwt_4 <dbl>, repwt_5 <dbl>

# print.survey_twophase default output matches snapshot

    Code
      print(d)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_twophase> (method: full)
      Phase 1 sample size: 60
      Phase 2 sample size: 29
      
    Output
      # A tibble: 60 x 9
         psu   strata      fpc    wt    y1         y2    y3 group phase2_ind
         <chr> <chr>     <dbl> <dbl> <dbl>      <dbl> <int> <chr> <lgl>     
       1 psu_1 stratum_1   451  14.3  60.4 -2.02          0 B     TRUE      
       2 psu_1 stratum_1   451  21.8  59.2 -1.22          0 B     FALSE     
       3 psu_1 stratum_1   451  14.4  57.2  0.180         1 B     FALSE     
       4 psu_1 stratum_1   451  18.9  39.6  0.568         1 C     TRUE      
       5 psu_2 stratum_1   451  23.0  49.1 -0.493         1 A     FALSE     
       6 psu_2 stratum_1   451  11.0  56.2  0.0000629     0 C     TRUE      
       7 psu_2 stratum_1   451  13.8  40.5  1.12          0 A     TRUE      
       8 psu_2 stratum_1   451  14.2  44.6  1.44          0 C     FALSE     
       9 psu_2 stratum_1   451  16.5  55.8 -1.10          0 A     TRUE      
      10 psu_2 stratum_1   451  13.7  57.7 -0.117         1 B     TRUE      
      # i 50 more rows

# print.survey_twophase full=TRUE output matches snapshot

    Code
      print(d, full = TRUE)
    Message
      
      -- Survey Design ---------------------------------------------------------------
      <survey_twophase> (method: full)
      Phase 1 sample size: 60
      Phase 2 sample size: 29
      
      
      -- Phase 1 design --
      
      * IDs: psu (10 PSUs)
      * Strata: strata (2 strata)
      * Weights: wt
      
      
      -- Phase 2 design --
      
      * Subset: phase2_ind
      
      
      -- Metadata --
      
      0 variable(s) labeled
      
    Output
      # A tibble: 60 x 9
         psu   strata      fpc    wt    y1         y2    y3 group phase2_ind
         <chr> <chr>     <dbl> <dbl> <dbl>      <dbl> <int> <chr> <lgl>     
       1 psu_1 stratum_1   451  14.3  60.4 -2.02          0 B     TRUE      
       2 psu_1 stratum_1   451  21.8  59.2 -1.22          0 B     FALSE     
       3 psu_1 stratum_1   451  14.4  57.2  0.180         1 B     FALSE     
       4 psu_1 stratum_1   451  18.9  39.6  0.568         1 C     TRUE      
       5 psu_2 stratum_1   451  23.0  49.1 -0.493         1 A     FALSE     
       6 psu_2 stratum_1   451  11.0  56.2  0.0000629     0 C     TRUE      
       7 psu_2 stratum_1   451  13.8  40.5  1.12          0 A     TRUE      
       8 psu_2 stratum_1   451  14.2  44.6  1.44          0 C     FALSE     
       9 psu_2 stratum_1   451  16.5  55.8 -1.10          0 A     TRUE      
      10 psu_2 stratum_1   451  13.7  57.7 -0.117         1 B     TRUE      
      # i 50 more rows

# summary.survey_taylor output matches snapshot

    Code
      summary(d)
    Message
      
      -- Survey Design Summary -------------------------------------------------------
      Type: Taylor series linearization
      Sample size: 50
      Weighted N: 625
      
      
      -- Design --
      
      IDs: psu (10 PSUs)
      Strata: strata (2 strata)
      Weights: wt
      * Range: 6.04 – 22.97
      * Mean: 12.5
      * CV: 0.323
      FPC: fpc
      
      Metadata: 0 of 8 variable(s) labeled

# summary.survey_replicate output matches snapshot

    Code
      summary(d)
    Message
      
      -- Survey Design Summary -------------------------------------------------------
      Type: replicate weights (BRR, 5 replicates)
      Sample size: 50
      Weighted N: 625
      
      
      -- Design --
      
      Weights: wt
      * Range: 6.04 – 22.97
      * Mean: 12.5
      * CV: 0.323
      Scale: 0.2
      MSE: TRUE
      
      Metadata: 0 of 13 variable(s) labeled

# summary.survey_twophase output matches snapshot

    Code
      summary(d)
    Message
      
      -- Survey Design Summary -------------------------------------------------------
      Type: two-phase sampling (method: full)
      Phase 1 sample size: 60
      Phase 2 sample size: 29
      
      
      -- Phase 1 design --
      
      IDs: psu (10 PSUs)
      Strata: strata (2 strata)
      Weights: wt
      Weighted N: 747
      
      
      -- Phase 2 design --
      
      Subset: phase2_ind
      
      Metadata: 0 of 9 variable(s) labeled

