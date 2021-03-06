### Title:    Checking parts of experiment 2 work as expected
### Project:  Imputing High Dimensional Data
### Author:   Edoardo Costantini
### Created:  2020-05-19

# Data Generation Latent Structure ----------------------------------------

  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")

# > works for all conditions ----------------------------------------------

  all_conds_data <- lapply(1:nrow(conds), function(x){
    X <- simData_lv(parms, conds[x,])
    Xy_mis <- imposeMiss_lv(X, parms, conds[x, ])
    return(Xy_mis)
  })
  length(all_conds_data)

# > items -----------------------------------------------------------------

# On average they have mean = parms$item_mean, sd = sqrt( parms$item_var )
  
  set.seed(20200727)
  
  reps <- 5e2
  store <- matrix(0, nrow = parms$n_it*conds[1,]$lv, ncol = 2)
  
  for (i in 1:reps) {
    X <- simData_lv(parms, conds[1,])
    store <- store + data.frame(mu = colMeans(X$dat), 
                                var = apply(X$dat, 2, var))
  }
  
  colMeans(round(store/reps, 3))

  data.frame(True = c(mean = parms$item_mean, var = parms$item_var),
             MCMC = round(colMeans(store/reps), 3))
  
# On average what is the correlation btw lv, and btw items
  
  cond <- data.frame(lv = 10, pm = .1, fl = "high")
  # a) lv correlated as in phi for all fl (dah!)
  # b) fl = "none", items rho 0
  # c) fl = "low",  items rho .3 w/in scale, .18 outside
  # d) fl = "high", items rho .875 w/in scale, .525 outside
  
  set.seed(20200727)
  store <- matrix(0, nrow = parms$n_it*conds[1,]$lv, ncol = 2)
  sv_lvcov <- matrix(0, nrow = cond$lv, ncol = cond$lv)
  sv_itcov <- matrix(0, nrow = 10, ncol = 10)
  reps <- 1e3
  for (i in 1:reps) {
    simData_out <- simData_lv(parms, cond)
    sv_lvcov <- sv_lvcov + round(cov(simData_out$scores_lv),3)
    sv_itcov <- sv_itcov + round(cov(simData_out$dat[, 1:10]),3)
  }
  
  # Generate some data to extract model implied parm values
  Xy <- simData_lv(parms, cond)
  
  # Latent Variables
  MCMC_lvcov <- round(sv_lvcov/reps, 3)
  round(MCMC_lvcov - Xy$Phi, 3) # should all be close to 0
  
  # Items
  # MCMC estimate
  MCMC_itcov <- round(sv_itcov/reps, 3)

  # Molde IMPlied values
  IMP_it1_var  <- Xy$Lambda[1, 1]^2 * Xy$Phi[1,1] + Xy$Theta[1,1]
    MCMC_itcov[1, 1] - IMP_it1_var # should be zero or close
  IMP_it12_cov <- Xy$Lambda[1, 1]^2 * Xy$Phi[1,1] + Xy$Theta[1, 2]
    MCMC_itcov[1, 2] - IMP_it12_cov # should be zero or close
  IMP_it16_cov <- Xy$Lambda[1, 1]^2 * Xy$Phi[1,2] + Xy$Theta[1, 6]
  
  # Should be similar values for each parameter
  data.frame(implied = c(IMP_it1_var, IMP_it12_cov, IMP_it16_cov),
             MCMC    = MCMC_itcov[1, c(1, 2, 6)])

# Low dimensional MAR imputation works ------------------------------------
# Run the following to see how:
# 1. Imposition of missingness changes the density of the variable
# 2. Low dimensional "oracle" mice run fixes the issue
  
  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")
  cond <- conds[1, ]
  
  # Mods to make things clearer
  cond$pm <- .8 # large pm makes it stark
  parms$n <- 1e4# large n makes pattern stark
  parms$missType <- "low"
  parms$rm_x <- c(3, 4)
  parms$auxWts <- rep(1, length(parms$rm_x))

# Visualize
  i <- 1 # which variable are we looking at? they all look the same!
  # Create an empty plot
  plot(1,
       main = "Density",
       xlab = colnames(Xy)[i], ylab = "",
       ylim = c(0, .5), xlim = c(-4, 4))
  
  # Plot 1 variable from random datasets obtained with the same set up
  set.seed(20200805)
  for (rep in 1:50) {
    simData_list <- simData_lv(parms, cond)
    Xy <- simData_list$dat
    Xy_mis <- imposeMiss_lv(simData_list, parms, cond)
    lines(density(Xy[, i], na.rm = TRUE), col = "black", lty = 2, lwd = .5)
    lines(density(Xy_mis[, i], na.rm = TRUE), col = "blue", lty = 2,  lwd = .5)
  }
  
  # Plot MI of that variable on the last dataset
  MI <- mice(data = Xy_mis[, 1:20], m = 10, maxit = 10,
             method = "norm")
  MI_dt <- complete(MI, "all")
  lapply(MI_dt, function(x) lines(density(x[, i]), 
                                  lty = 2, lwd = .5,
                                  col = "yellow")
  )
  

# CFA: Model Fits Well ----------------------------------------------------
# you could make it on average but I'm already convinced
  
  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")
  
  # Gen data
  set.seed(20200805)
  # parms$n <- 1e3 # asimp
  cond <- data.frame(lv = 10, pm = .1, fl = "high")
  reps <- 1e3
  output <- data.frame(cfi = NA, tli = NA, rmsea = NA)
  for (r in 1:reps) {
    Xy <- simData_lv(parms, cond)
    items <- colnames(Xy$dat)
    CFA_model <- CFA_mod_wirte(Xy$dat, 3, parms)
    
    # Example CFA fit
    fit   <- cfa(CFA_model, data = Xy$dat, std.lv = TRUE)
    
    # Extract Fit indices
    fit.out <- summary(fit, fit.measures = TRUE, standardized = TRUE)
    
    # Store them together
    output[r, ] <- fit.out$FIT[c("cfi", "tli", "rmsea", "rmsea.pvalue")]
  }
  colMeans(output)
  # CFI (Comparative fit index): Measures whether the model fits the data 
  #   better than a more restricted baseline model. Higher is better, 
  #   with okay fit > .9.
  # TLI (Tucker-Lewis index): Similar to CFI, but it penalizes overly complex
  #   models (making it more conservative than CFI). Higher is better, 
  #   with okay fit > .9.
  # RMSEA (Root mean square error of approximation): The “error of approximation”
  #   refers to residuals. Instead of comparing to a baseline model, it measures 
  #   how closely the model reproduces data patterns. If the p-value is greater 
  #   than alpha, then it is typical to report that the model has “close fit” 
  #   according to the RMSEA.
  
  CFA_par <- parameterEstimates(fit, 
                                se = F, zstat = F, pvalue = F, ci = F)
  CFA_par[1:10, ]
  
# CFA: Factor Loadings Effects --------------------------------------------
# What do high / low factor loadings mean for items measuring the same
# construct? We suspect that high factor loadings mean that items are 
# duplicates of each other, so they are very highly correlated and 
# probably good at imputation

  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")
  
  set.seed(20200805)
  
  # Set up conditions to study
  cond_high <- data.frame(lv = 10, pm = .1, 
                          fl = "high") # key difference!
  cond_low <- data.frame(lv = 10, pm = .1, 
                         fl = "low")
  
  # Create Storing objects
  store_high <- list()
  store_low <- list()
  
  # Repetitions
  reps <- 1e3
  
  # Perform Study
  for (r in 1:reps) {
    # Gen data
    Xy_high <- simData_lv(parms, cond_high)
    Xy_low <- simData_lv(parms, cond_low)
    
    # Store element of interest
    store_low[[r]] <- rbind(cor(Xy_low$dat[1:10][, 1:5]), 
                            cor(Xy_low$dat[1:10][, 6:10]))
    store_high[[r]] <- rbind(cor(Xy_high$dat[1:10][, 1:5]), 
                             cor(Xy_high$dat[1:10][, 6:10]))
  }
  
  # Result
  round(Reduce('+', store_low)/reps, 3)
  round(Reduce('+', store_high)/reps, 3)
  # Comment: Items measuring the same construct are more highly correlated
  #          so imputations will definetly be stronger if we use them!
  
# CFA: unbiased estiamtes -------------------------------------------------

  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")
  
  # Gen data
  set.seed(20200805)
  cond <- data.frame(lv = 10, pm = .1, fl = "high")
  # items <- colnames(Xy$dat)
  
  # Create CFA model text
  Xy <- simData_lv(parms, cond)
  CFA_model <- CFA_mod_wirte(Xy$dat, 3, parms)
  
  # Storing Objects
  reps <- 500
  sv_fl <- matrix(nrow = reps, ncol = 15) # factor loadings
  sv_ev <- matrix(nrow = reps, ncol = 15) # error variances (items)
  sv_lc <- matrix(nrow = reps, ncol = 3) # latent variable covariances
  
  options(warn=2) # make warnings errors
  
  for(r in 1:reps){
    print(r)
    Xy <- simData_lv(parms, cond)
    # Define CFA model
    # Fit models
    fit   <- cfa(CFA_model, data = Xy$dat, std.lv = TRUE)
    # Compare
    CFA_par <- parameterEstimates(fit, 
                                  se = F, zstat = F, pvalue = F, ci = F)
    
    # Measured
    # factor loadings
    sv_fl[r, ] <- CFA_par[1:15, "est"] - Xy$Lambda[Xy$Lambda != 0][1:15]
    
    # items error variances
    sv_ev[r,] <- CFA_par[16:30, "est"] - diag(Xy$Theta)[1:15]
    
    # latent variables covarainces
    sv_lc[r,] <- CFA_par[34:36, "est"] - (Xy$Phi[2, 1])
  }
  
  options(warn=1) # revert warnings to warnings
  
  # Bias in percent should be close to 0)
  colMeans(sv_fl)
  colMeans(sv_ev)
  colMeans(sv_lc)
  
# CFA: Model Implied Values -----------------------------------------------
# Chech that everythin adds up
  
  # Model implied values of var(delta)
  set.seed(1234)
  parms$n <- 1e4
  Xy <- simData_lv(parms, cond)
  
  # Define CFA model
  # Fit models
  fit   <- cfa(CFA_model, data = Xy$dat, std.lv = TRUE)
  CFA_par <- parameterEstimates(fit)[1:4]
  
  # > Sample Covariance Matrix of data (S) ####
  ( S <- cov(scale(Xy$dat))[1:5, 1:5] )
  
  # Model Implied Covariance matrix of data (Sigma)
  ( Sigma <- (Xy$Lambda %*% Xy$Phi %*% t(Xy$Lambda) + Xy$Theta)[1:5, 1:5] )
  
  # Difference
  round( S - Sigma , 3)
  
  # > Error variances (ev) ####
  MCMC_ev <- CFA_par[16:30, "est"]
  IMP_ev <- sapply(Xy$dat, var)[1:15] - Xy$Lambda[Xy$Lambda != 0][1:15]^2
  
  round(
    data.frame(MCMC = MCMC_ev,
               implied = IMP_ev,
               diff = MCMC_ev - IMP_ev),
    3)
  
# Scaling issues ----------------------------------------------------------

  # Define some CFA model to test
  CFA_model <- '
      # Measurement Model
      lv1 =~ z1 + z2 + z3 + z4 + z5
      lv2 =~ z6 + z7 + z8 + z9 + z10
    '
  
  set.seed(20200727)
  X <- simData_lv(parms, conds[1,])
  
  # Scaled data
  Xs <- sapply(X$dat, function(x){
    x * sqrt(5)/sd(x) + 5
  })
  
  data.frame(mu = colMeans(X$dat),
             var = apply(X$dat, 2, var),
             mu_s = colMeans(Xs),
             var_s = apply(Xs, 2, var))
  
  # Fit models
  fit   <- cfa(CFA_model, data = X$dat, std.lv = TRUE)
  fit_v <- cfa(CFA_model, data = X$dat)
  fit_s <- cfa(CFA_model, data = Xs, std.lv = TRUE)
  fit_s <- cfa(CFA_model, data = scale(Xs), std.lv = TRUE)
  
  # Measured
  round(X$Lambda, 3)  # factor loadings
  diag(X$Theta)[1:10] # items error variances
  
  # Setting latent variables variances to 1 standardizes factor scores already
  parameterEstimates(fit, 
                     se = F, zstat = F, pvalue = F, ci = F,
                     standardized = TRUE)
  parameterEstimates(fit_v, 
                     se = F, zstat = F, pvalue = F, ci = F,
                     standardized = TRUE)
  parameterEstimates(fit_s,
                     se = F, zstat = F, pvalue = F, ci = F,
                     standardized = TRUE)
  
  # Compare
  round(X$Lambda, 3)[1,1] / round(X$Lambda, 3)[2,1]
  parameterEstimates(fit)$est[1] / parameterEstimates(fit)$est[2]
  parameterEstimates(fit_s, standardized = TRUE)$est[1] / parameterEstimates(fit_s, standardized = TRUE)$est[2]
  
# Effects of missingness imposition on estiamtes --------------------------
# a) Saturated model on raw data (only items with missing values)
# b) CFA model on raw data (latent variables target of miss and 
#    1 latent variable influencing)
# c) Saturated Model on Scores obtained from the variables (mean of items)
# d) LM on Scores
  
  rm(list=ls())
  source("./init_general.R")
  source("./exp2_init.R")
  
  # Twick paramters
  cond <- data.frame(lv = 10, pm = .1, fl = "high")
  model_lv <- 3 # how many lantet variables to consider in the CFA model
  
  # Modify parms for needs
  parms$n   <- 200
  parms$blck1_r <- .6
  
  # Create storing objects
  reps <- 1e3
  
  # Raw data
  # Saturated model
  mu_fl <- mu_ms <- var_fl <- var_ms <- 
    matrix(NA, nrow = reps, ncol = length(parms$z_m_id))
  cov_fl <- cov_ms <- 
    matrix(NA, nrow = reps, ncol = ncol(combn(parms$z_m_id, 2)))
  # CFA related
  fac_fl <- fac_ms <- 
    matrix(NA, nrow = reps, ncol = model_lv*parms$n_it)
  
  # Score data
  # Scores of interest
  sc_n <- 2 # up to the third
  # Saturated model
  sc_mu_fl <- sc_mu_ms <- sc_var_fl <- sc_var_ms <- 
    matrix(NA, nrow = reps, ncol = sc_n)
  sc_cov_fl <- sc_cov_ms <- 
    matrix(NA, nrow = reps, ncol = ncol(combn(1:sc_n, 2)))
  # LM related
  b_fl <- b_ms <- R2 <- 
    matrix(NA, nrow = reps, ncol = 1)
  R2 <- matrix(NA, nrow = reps, ncol = 2)
  
  CFA_er <- 0 # count CFA failures
  
  set.seed(20200805)
  # Perform analysis
  for (r in 1:reps) {
    print(r/reps*100)
    
    simData_list <- simData_lv(parms, cond)
    Xy <- simData_list$dat
    Xy_mis <- imposeMiss_lv(simData_list, parms, cond)
    CFA_model <- CFA_mod_wirte(Xy, 3, parms)
    # SAT_model <- SAT_mod_write(parms)
    O <- !is.na(Xy_mis) # matrix index of observed values

  # Saturated model (raw data)
    sem_fit <- lapply(list(GS    = Xy,
                            CC    = Xy_mis[rowSums(!O) == 0, ]), # default is listwise deletion
                       sem, 
                       model = SAT_mod_write(colnames(Xy)[parms$z_m_id]), 
                       likelihood = "wishart")
    sem_par <- sem_EST(sem_fit)

    # Means
    mu_fl[r, ] <- sem_par[1:parms$zm_n, "GS"]
    mu_ms[r, ] <- sem_par[1:parms$zm_n, "CC"]

    # Variances
    var_fl[r, ] <- sem_par[(parms$zm_n+1):(parms$zm_n*2), "GS"]
    var_ms[r, ] <- sem_par[(parms$zm_n+1):(parms$zm_n*2), "CC"]

    # Covariances
    cov_fl[r, ] <- sem_par[-(1:(parms$zm_n*2)), "GS"]
    cov_ms[r, ] <- sem_par[-(1:(parms$zm_n*2)), "CC"]

  # CFA
    CFA_gs <- sem(Xy, model = CFA_model,
                  likelihood = "wishart", std.lv = TRUE)
    fac_fl[r, ] <- parameterEstimates(CFA_gs)[1:(model_lv*parms$n_it), "est"]
    CFA_cc <- try(sem(Xy_mis, model = CFA_model,
                      likelihood = "wishart", std.lv = TRUE),
                  silent = TRUE)
      # In a try because it might not converge, for example if the number
      # of obsrvations that can be used is smaller than the number of parameters
      # that need to be estimated
    if(class(CFA_cc) == "lavaan"){
      fac_ms[r, ] <- parameterEstimates(CFA_cc)[1:(model_lv*parms$n_it),"est"]
    } else {
      CFA_er <- CFA_er + 1
    }

  ## SCORE DATA ##
    
  # Make Scores
  Xy_score <- data.frame(matrix(nrow = parms$n, ncol = cond$lv))
    colnames(Xy_score) <- paste0("sc", 1:cond$lv)
  Xy_mis_score <- data.frame(matrix(nrow = sum(rowSums(!O) == 0), ncol = cond$lv))
    colnames(Xy_mis_score) <- paste0("sc", 1:cond$lv)
    
  # Saturated model (scales)
    for (i in 1:cond$lv) {
      item_idx <- c((0:cond$lv)[i]*parms$n_it+1):((0:cond$lv)[i+1]*parms$n_it)
      
      Xy_score[,i] <- rowMeans(Xy[, item_idx])
      Xy_mis_score[,i] <- rowMeans(Xy[rowSums(!O) == 0, item_idx])
    }
    
    # Fit Model to Score data (with score being a mean value)
    sem_fit_sc <- lapply(list(GS    = Xy_score,
                            CC    = Xy_mis_score), # default is listwise deletion
                       sem, 
                       model = SAT_mod_write(colnames(Xy_score)[1:sc_n]), 
                       likelihood = "wishart")
    sem_par_sc <- sem_EST(sem_fit_sc)
    
    # Means
    sc_mu_fl[r, ] <- sem_par_sc[1:sc_n, "GS"]
    sc_mu_ms[r, ] <- sem_par_sc[1:sc_n, "CC"]
    
    # Variances
    sc_var_fl[r, ] <- sem_par_sc[(sc_n+1):(sc_n*2), "GS"]
    sc_var_ms[r, ] <- sem_par_sc[(sc_n+1):(sc_n*2), "CC"]
    
    # Covariances
    sc_cov_fl[r, ] <- sem_par_sc[-(1:(sc_n*2)), "GS"]
    sc_cov_ms[r, ] <- sem_par_sc[-(1:(sc_n*2)), "CC"]
    
  # LM
    lm_sndt <-  lapply(list(GS      = Xy_score,
                            CC      = Xy_mis_score), 
                       lm, formula = sc1 ~ -1 + sc2)
    lm_sndt <-  lapply(list(GS      = Xy,
                            CC      = Xy_mis[rowSums(!O) == 0, ]), 
                       function(x){
                         y  <- rowMeans(x[, c(1:5)])
                         x1 <- rowMeans(x[, c(6:10)])
                         lm(y ~ -1 + x1)
                       })
    lm_par <- as.data.frame(lapply(lm_sndt, coef))
    R2[r, ] <- sapply(lm_sndt, function(x) summary(x)$r.squared)
    
    b_fl[r, ] <- lm_par[, "GS"]
    b_ms[r, ] <- lm_par[, "CC"]
  }
  
  # Effect of missingness on analysis
  # MCMC Estimates
  
  # Raw data
  out_mu <- data.frame(full = round( colMeans(mu_fl), 3),
                       miss = round( colMeans(mu_ms), 3))
  out_va <- data.frame(full = round( colMeans(var_fl), 3),
                       miss = round( colMeans(var_ms), 3))
  out_cv <- data.frame(full = round( colMeans(cov_fl), 3),
                       miss = round( colMeans(cov_ms), 3))
  out_fl <- data.frame(full = round( colMeans(fac_fl), 3),
                       miss = round( colMeans(fac_ms, na.rm = TRUE), 3))
  # Score data
  out_sc_mu <- data.frame(full = round( colMeans(sc_mu_fl), 3),
                       miss = round( colMeans(sc_mu_ms), 3))
  out_sc_va <- data.frame(full = round( colMeans(sc_var_fl), 3),
                       miss = round( colMeans(sc_var_ms), 3))
  out_sc_cv <- data.frame(full = round( colMeans(sc_cov_fl), 3),
                       miss = round( colMeans(sc_cov_ms), 3))
  out_lm <- data.frame(full = round( colMeans(b_fl), 3),
                       miss = round( colMeans(b_ms, na.rm = TRUE), 3))
  
  # Bias (in terms of percentage of true value)
  
  # Raw data
  BPR_mu <- round(abs(out_mu$full - out_mu$miss)/sqrt(out_va$full), 2)
  BPR_va <- round(abs(out_va$full - out_va$miss)/out_va$full*100, 0)
  BPR_cv <- round(abs(out_cv$full - out_cv$miss)/out_cv$full*100, 0)
  
  BPR_fl <- round(abs(out_fl$full - out_fl$miss)/out_fl$full*100, 0)
  
  # Score data
  BPR_sc_mu <- round(abs(out_sc_mu$full - out_sc_mu$miss)/sqrt(out_sc_va$full), 2)
  BPR_sc_va <- round(abs(out_sc_va$full - out_sc_va$miss)/out_sc_va$full*100, 0)
  BPR_sc_cv <- round(abs(out_sc_cv$full - out_sc_cv$miss)/out_sc_cv$full*100, 0)
  
  BPR_lm <- round(abs(out_lm$full - out_lm$miss)/out_lm$full*100, 0)
  