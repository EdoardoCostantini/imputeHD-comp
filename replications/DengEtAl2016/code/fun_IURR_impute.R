### Title:    imputeHD-comp impute w/ Regu Freq Regr IURR
### Author:   Edoardo Costantini
### Created:  2020-02-23
### Modified: 2020-02-23
### Notes:    function to impute data according to IURR method following 
###           reference papers Zhao Long 2016 (for univariate miss) and 
###           Deng et al 2016 (for multivariate miss). The function is a bit
###           more complex than it needs: it supports multivariate miss.

impute_IURR <- function(Xy_mis, cond, chains=5, iters=5, reg_type="lasso"){
  # # Description
  # # Packages required by function
  # library(glmnet)     # for regularized regressions
  # library(tidyverse)  # for piping
  # library(caret)      # for trainControl
  # library(PcAux)      # for iris data
  # # Other functions needed:
  # source("./init.R")
  # source("./functions.R")
  # # Input: a simulation condition, number of chians and iterations, reg type
  # # For internals:
  # cond     = conds[9, ]
  # Xy <- genData(cond, parms)
  # # Xy_mis  = iris2[,-c(1,7)] # alternative
  # reg_type = c("el", "lasso")[2]           # imputation model penality type
  # iters    = 1                             # number of iterations
  # chains   = 5                             # number of imputed datasets
  # # output: an object containing iters number of imputed datasets (imputed_datasets)
  
  ## Body
  Z <- Xy_mis
  p  <- ncol(Z) # number of variables [indexed with j]
  
  r  <- colSums(!is.na(Z)) # variable-wise count of observed values
  vmis_ind <- r != nrow(Z)
  p_imp <- sum(vmis_ind)
  
  # To store imputed values and check convergence
  imputed_values <- vector("list", p_imp)
    names(imputed_values) <- names(which(r != nrow(Z)))
  for (v in 1:p_imp) {
    imputed_values[[v]] <- matrix(rep(NA, (iters*(nrow(Z)-r[v]))), 
                                  ncol = iters)
  }
  
  # To store multiply imputed datasets
  imputed_datasets <- vector("list", iters)
    names(imputed_datasets) <- seq(1, iters)
  
  O <- !is.na(Z) # matrix index of observed values
  
  # Time performance
  start.time <- Sys.time()
  
  imp_res <- lapply(1:chains, function(x){
    Zm <- init_dt_i(Z, missing_type(Z)) # initialize data
    for (i in 1:iters) {
      print(paste0("IURR - Chain: ", x, "/", chains, "; Iter: ", i, "/", iters))
      for (j in 1:p_imp) {
        # Select data
        y_obs <- z_j_obs  <- as.vector(Zm[O[, j] == TRUE, j])
        y_mis <- zm_mj    <- as.vector(Zm[O[, j] == FALSE, j]) # useless
        X_obs <- Wm_j_obs <- as.matrix(Zm[O[, j] == TRUE, -j])
        X_mis <- Wm_mj    <- as.matrix(Zm[O[, j] == FALSE, -j])
        
        # Fit regularized regression
        # Lasso
        if(reg_type == "lasso"){
          regu.mod <- rr_est_lasso(X = Wm_j_obs, y = z_j_obs, parms = parms)
        }
        # Elastic net
        if(reg_type == "el"){
          regu.mod <- rr_est_elanet(X = Wm_j_obs, y = zstar_j, parms = parms)
        }
        
        # Impute
        zm_j <- imp_gaus_IURR(model = regu.mod,
                              X_tr = Wm_j_obs, y_tr = z_j_obs,
                              X_te = Wm_mj, y_te = zm_mj, 
                              parms = parms)
        
        # Append imputation
        imputed_values[[j]][, i] <- zm_j
        Zm[!O[, j], j] <- zm_j
      }
    }
    
    # Store results
    return(list(imp_dat = Zm,
                imp_val = imputed_values)
           )
  })
  end.time <- Sys.time()
  return(list(imp_res = imp_res,
              time = difftime(end.time, 
                              start.time, 
                              units = "mins"))
  )
}