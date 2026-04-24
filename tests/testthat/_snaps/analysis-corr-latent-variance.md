# .corr_replicate_variance_latent() emits PC-12 when 0 < n_failed <= 0.2*R

    Code
      .corr_replicate_variance_latent(d, method = "polychoric", vec_a = d@data$o1,
      vec_b = d@data$o2, active_domain = active, rho_hat_full = fit$rho)
    Condition
      Warning:
      ! 1 of 30 replicate fits failed to converge.
      i Variance is computed over the 29 successful replicate(s). See `meta(result)$n_failed_replicates_total`.
    Output
      $var_z
      [1] 0.00548952
      
      $var_z_srs
      [1] 0.005602102
      
      $n_ok
      [1] 29
      
      $n_failed
      [1] 1
      

# .corr_replicate_variance_latent() raises PC-8 when failure > 20%

    Code
      .corr_replicate_variance_latent(d, method = "polychoric", vec_a = d@data$o1,
      vec_b = d@data$o2, active_domain = active, rho_hat_full = fit$rho)
    Condition
      Error in `.corr_replicate_variance_latent()`:
      x 29 of 30 replicate fits failed to converge (96.7%).
      i Threshold for hard failure is "20"% of replicates.
      v Inspect the design's replicate weights or reduce the number of ordinal levels.

# .corr_latent_pair() raises PC-7 on survey_twophase before any MLE work

    Code
      .corr_latent_pair(d, "o1", "o2", method = "polychoric")
    Condition
      Error in `.corr_latent_pair()`:
      x `method = "polychoric"` is not supported for <surveycore::survey_twophase> designs in this release.
      v Use `method = "pearson"`, or call `get_corr()` on a <survey_taylor> or <survey_replicate> design.

# .corr_latent_pair() raises PC-1 under polychoric with a numeric column

    Code
      .corr_latent_pair(d, "o1", "num", method = "polychoric")
    Condition
      Error in `.corr_latent_pair()`:
      x `method = "polychoric"` requires ordinal variables. Non-ordinal column: num (<numeric>).
      v Coerce to <factor> or <ordered>, or use `method = "pearson"`.

# .corr_latent_pair() emits PC-13 for an unordered factor input

    Code
      withCallingHandlers(.corr_latent_pair(d, "o1", "o2", method = "polychoric"),
      surveycore_warning_polychoric_unordered_factor = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      }, warning = function(w) invokeRestart("muffleWarning"))
    Message
      ! Variable o1 is an unordered <factor>; using `levels()` order for thresholds.
      v Coerce to <ordered> to make the level order explicit.
    Output
      $r
      [1] 0.8804509
      
      $se_r
      [1] 0.3663395
      
      $se_srs
      [1] 0.02740355
      
      $n
      [1] 80
      
      $n_weighted
      [1] 930.0266
      
      $ci_low
      [1] -0.9484529
      
      $ci_high
      [1] 0.9997862
      
      $rho_z
      [1] 1.37777
      
      $se_z
      [1] 1.62958
      
      $method
      [1] "polychoric"
      
    Code
      NULL
    Output
      NULL

