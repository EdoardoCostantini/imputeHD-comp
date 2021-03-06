### Title:    data geneartion functions
### Porject:  Imputing High Dimensional Data
### Author:   Edoardo Costantini
### Created:  2020-06-23

# data generation ---------------------------------------------------------

# Experiment 1: Multivariate Data -----------------------------------------
simData_exp1 <- function(cond, parms){
  # For internals
  # cond <- conds[1,]
  
  # 1. Generate covariance matrix -----------------------------------------
    Sigma <- diag(cond$p)
  # Block 1: highly correlated variables
    Sigma[parms$blck1, ] <- parms$blck1_r
  # Block 2: not so highly correlated variables
    Sigma[parms$blck2, ] <- parms$blck2_r
  # Block 3: uncorrelated variables
    block3_p <- cond$p - length(c(parms$blck1, parms$blck2))
    Sigma[-c(parms$blck1, parms$blck2), ] <- .01
  # Fix diagonal
    diag(Sigma) <- 1
  # Make symmetric
    Sigma[upper.tri(Sigma)] <- t(Sigma)[upper.tri(Sigma)]
  
  # 2. Gen n x p data -----------------------------------------------------
    # Sample
    Z <- rmvnorm(n     = parms$n, 
                 mean  = rep(0, cond$p), 
                 sigma = Sigma )
    # Give meaningful names
    colnames(Z) <- paste0("z", 1:ncol(Z))
  
  # 3. Scale according to your evs examination
    Z_sc <- Z * sqrt(parms$item_var) + parms$item_mean

  return( as.data.frame( Z_sc ) )
}

# Use
# Xy <- simData_exp1(conds[1, ], parms)
# cor(Xy)[1:15, 1:15]
# cov(Xy)[1:15, 1:15]

# Missingness -------------------------------------------------------------

imposeMiss <- function(dat_in, parms, cond){
  ## Description
  # Given a fully observed dataset and a param object containing the regression
  # coefficients of the model to impose missingness, it returns a version of
  # the original data with imposed missingness on all the variables indicated
  # as target int parms$z_m_id
  ## Example Inputs
  # cond <- conds[1,]
  # dat_in   <- simData_exp1(cond, parms)
  
  # Body
  # Define non-response vector
  dat_out <- dat_in
  for (i in 1:parms$zm_n) {
    nR <- simMissingness(pm    = cond$pm,
                         data  = dat_in,
                         preds = parms$rm_x[i, ],
                         type  = parms$missType,
                         beta  = parms$auxWts)
    
    # Fill in NAs
    dat_out[nR, parms$z_m_id[i]] <- NA
  }
  
  # Result
  return( dat_out )
}

# Experiment 2 - Latent Structure -----------------------------------------

simData_lv <- function(parms, cond){
  # cond <-  conds[1,]
  # parms$n <- 1e4
  n_it_tot <- parms$n_it * cond$lv
  
  # Structural parameters of the measurement model
  # Latent Variables Covariance matrix 
# (1) Block structure/Autoregressive correlation structure
  Phi <- diag(cond$lv)
  # Block 1: highly correlated variables
  Phi[parms$blck1, ] <- parms$blck1_r
  # Block 2: not so highly correlated variables
  Phi[parms$blck2, ] <- parms$blck2_r
  # Block 3: uncorrelated variables
  block3_p <- cond$lv - length(c(parms$blck1, parms$blck2))
  Phi[-c(parms$blck1, parms$blck2), ] <- .01
  # Fix diagonal
  diag(Phi) <- 1
  # Make symmetric
  Phi[upper.tri(Phi)] <- t(Phi)[upper.tri(Phi)]
  # Make it covariance instead of correlation matrix (depending of lv_var)
  Phi <- Phi * sqrt(parms$lv_var) * sqrt(parms$lv_var)
  
  # Factor loadings (random factor)
# (2) Sample from unif
  if(cond$fl == "none"){
    lambda <- rep(0, n_it_tot)
  } else {
    if(cond$fl == "high"){
      lambda <- runif(n_it_tot, .9, .97)
    } else {
      lambda <- runif(n_it_tot, .5, .6)
    }
  }
  
  # Observed Items Covariance matrix
# (3) uncorrelated observation errors
  # For decisions reagrding the paramter values look into your 
  # PhD_diary notes
  Theta <- diag(n_it_tot)
  for (i in 1:length(lambda)) {
    # Theta[i, i] <- 1 - lambda[i]^2 * 1
    Theta[i, i] <- parms$item_var - lambda[i]^2 * Phi[1,1]
  }
  
# (4) Items Factor Complexity = 1 (see Bollen1989 p234
#     aka simple measurement structure)
  Lambda <- matrix(nrow = n_it_tot, ncol = cond$lv)
  start <- 1
  for (j in 1:cond$lv) {
    end <- (start + parms$n_it) - 1
    vec <- rep(0, n_it_tot)
    vec[start:end] <- lambda[start:end]
    Lambda[, j] <- vec
    start <- end + 1
  }
  
  # Sample Scores
# (5) scores on latent variable and items errors centered around 0
  scs_lv    <- rmvnorm(parms$n, rep(0, cond$lv), Phi)
    colnames(scs_lv) <- paste0("lv", 1:ncol(scs_lv))
  scs_delta <- rmvnorm(parms$n, rep(0, n_it_tot), Theta)
    colnames(scs_delta) <- paste0("d_z", 1:ncol(scs_delta))
    
  # Compute Observed Scores
# (6) items
  x <- matrix(nrow = parms$n, ncol = n_it_tot)
  for(i in 1:parms$n){
    # x[i, ] <- t(Lambda %*% scs_lv[i, ] + scs_delta[i, ])
    x[i, ] <- t(parms$item_mean + Lambda %*% scs_lv[i, ] + scs_delta[i, ])
  }
  colnames(x) <- paste0("z", seq(1:n_it_tot))
  
  # Function output
  return( list(dat    = as.data.frame(x),
               Phi    = Phi,
               Theta  = Theta,
               Lambda = Lambda,
               scores_lv = scs_lv) )
}

# Use function
# simData_lv()

imposeMiss_lv <- function(dat_in, parms, cond){
  ## Description
  # Given a fully observed dataset and a param object containing 
  # info on the (latent) imposition mechanism, it returns a version of
  # the original data with imposed missingness on all the items 
  # indicated as target int parms$z_m_id
  ## Example Inputs
  # cond <- conds[1,]
  # dat_in   <- simData_lv(parms, cond)
  
  # Body
  # Define non-response vector
  dat_out <- dat_in$dat
  for (i in 1:parms$zm_n) {
    nR <- simMissingness(pm    = cond$pm,
                         data  = dat_in$scores_lv,
                         preds = parms$rm_x,
                         type  = parms$missType,
                         beta  = parms$auxWts)
    
    # Fill in NAs
    dat_out[nR, parms$z_m_id[i]] <- NA
  }
  
  # Result
  return( dat_out )
}

# MAR + MCAR
imposeMiss_lv_MD <- function(dat_in, parms, cond, plot = FALSE){
  ## Description
  # Adds Matrix Desing missingness to the MAR
  ## Example Inputs
  # cond <- conds[1, ]
  # cond$lv <- 50 # experimental
  # dat_in <- simData_lv(parms, cond)
  # plot = TRUE
  
  # Body
  # Define non-response vector
  dat_out <- dat_in$dat
  for (i in 1:parms$zm_n) {
    nR <- simMissingness(pm    = cond$pm,
                         data  = dat_in$scores_lv,
                         preds = parms$rm_x,
                         type  = parms$missType,
                         beta  = parms$auxWts)
    
    # Fill in NAs
    dat_out[nR, parms$z_m_id[i]] <- NA
  }
  
  # Assign observations to 1 of 6 situations
  # situations <- paste0("s", 1:6)
  # memo <- NULL
  # for (i in 1:nrow(dat_out)) {
  #   memo[[i]] <- sample(situations, 1)
  # }
  situations <- paste0("s", 1:6)
  memo <- rep(paste0("s", 1:6), length.out = parms$n)
  # sort(memo)
  # Attribute Missingness Pattern (per situation)
  missdesc <- list(s1 = c("C", "D"),
                   s2 = c("B", "D"),
                   s3 = c("B", "C"),
                   s4 = c("A", "D"),
                   s5 = c("A", "C"),
                   s6 = c("A", "B"))
  
  # Define Variable-Block match
  block_tot <- factor(x = c("Core", "A", "B", "C", "D"), 
                      levels = c("Core", "A", "B", "C", "D"))
  block_siz <- ncol(dat_out)/length(block_tot)
  block_mem.1 <- list(L1 = rep("Core", 5),
                      L2 = rep("A", 5),
                      L3 = rep("Core", 5),
                      L4 = rep("B", 5),
                      L5 = rep("A", 5),
                      L6 = rep("B", 5),
                      L7 = rep("C", 5),
                      L8 = rep("C", 5)
  )
  block_mem <- factor(unlist(block_mem.1), 
                        levels = c("Core", "A", "B", "C", "D"))
  block_tar <- block_siz - table(block_mem)
  store <- list()
  for (m in 1:length(block_tar)) {
    store[[m]] <- rep(names(block_tar[m]), block_tar[m])
  }

  memb <- factor(c(as.character(block_mem), unlist(store)),
                 levels = levels(block_tot))
  table(memb)
  # Impose Matrix Design missingness
  for (s in 1:6) {
    colIndex <- memb %in% missdesc[[s]]
    rowIndex <- memo == situations[s]
    dat_out[rowIndex, colIndex] <- NA
  }
  
  # Visual Check
  if(plot == TRUE){
    # Order columns and rows to show the EVS matrix desing plot
    dat_help <- dat_out[order(memo), order(memb)]
    # plot the matrix
    plot(as.matrix(!is.na(dat_help)), # requires "plot.matrix" pack
         border = NA,
         breaks = c(TRUE, FALSE),
         col = c("black", "white"),
         main = "Missing data pattern",
         cex.lab = 1, # text size for axis labels
         cex.axis = .5, # text size for ticks labels
         las = 2, # orientation of ticks
         y = "Observation ID",
         xlab = "Variable ID")
  }
  
  # Recast in original order
  # dat_out <- dat_out[, OG_col_order]

  # Result
  return( dat_out )
}


# Experiment 3: Interactions ----------------------------------------------

simData_int <- function(parms, cond){
  # For internals
  # cond <- conds[2,]
  
  # Generate covaraince matrix
  # For paramters decisions, look back at
  Sigma <- diag(cond$p - length(parms$blcky))
  
  # Block 1: highly correlated variables
  blck1_indx <- parms$blck1 - length(parms$blcky)
  Sigma[blck1_indx, ] <- parms$blck1_r
  
  # Block 2: not so highly correlated variables
  blck2_indx <- parms$blck2 - length(parms$blcky)
  Sigma[blck2_indx, ] <- parms$blck2_r
  
  # Block 3: uncorrelated variables
  blck3_indx <- (1:ncol(Sigma))[-c(blck1_indx, blck2_indx)]
  Sigma[blck3_indx, ] <- .01
  
  # Fix diagonal
  diag(Sigma) <- 1
  
  # Make symmetric
  Sigma[upper.tri(Sigma)] <- t(Sigma)[upper.tri(Sigma)]
  
  # Gen Predictors Variables
  # Generic predictors
  Z <- rmvnorm(n     = parms$n, 
               mean  = rep(parms$item_mean, ncol(Sigma)), 
               sigma = Sigma )
  colnames(Z) <- paste0("z", 1:ncol(Z))
  
  # Gen y variables
  if(cond$int_sub == FALSE){
    y_pred   <- Z[, parms$lm_y_x]
    y_b      <- rep(parms$b, ncol(y_pred))
    y_sgn    <- t(y_b) %*% cov(y_pred) %*% y_b
    y_sY     <- (y_sgn / cond$r2) - y_sgn
    eps      <- rnorm(parms$n, mean = 0, sd = sqrt(y_sY))
    y        <- y_pred %*% y_b + eps
  }
  if(cond$int_sub == TRUE){
    y_inte <- apply(scale(Z[, parms$lm_y_i],
                          center = parms$int_cen,
                          scale = FALSE), 
                    1, prod)
    y_pred   <- cbind(Z[, parms$lm_y_x], y_inte)
    y_b      <- rep(parms$b, ncol(y_pred))
    y_sgn    <- t(y_b) %*% cov(y_pred) %*% y_b
    y_sY     <- (y_sgn / cond$r2) - y_sgn
    eps      <- rnorm(parms$n, mean = 0, sd = sqrt(y_sY))
    y        <- y_pred %*% y_b + eps
  }

  # Combine data
  yZ <- data.frame(y = y, Z)

  return(yZ)
}

# yZ <- simData_int(parms = parms, cond = conds[1, ])
# summary(lm(parms$frm, data = yZ))

# yZ <- simData_int(parms = parms, cond = conds[2, ])
# summary(lm(parms$frm_int, data = yZ))

imposeMiss_int <- function(dat_in, parms, cond){
  ## Description
  # Given a fully observed dataset and a param object containing 
  # info on the (latent) imposition mechanism, it returns a version of
  # the original data with imposed missingness on all the items 
  # indicated as target int parms$z_m_id
  ## Example Inputs
  # cond   <- conds[4, ]
  # dat_in <- simData_int(parms, cond)
  
  # Body
  # Define non-response vector
  dat_out <- dat_in
  
  if(cond$int_rm == FALSE){
    
    for (i in parms$z_m_id) {
      nR <- simMissingness(pm    = cond$pm,
                           data  = dat_in,
                           preds = parms$rm_x,
                           type  = parms$missType)
      
      # Fill in NAs
      dat_out[nR, i] <- NA
    }
  }
  
  if(cond$int_rm == TRUE){
    int_term <- apply(scale(dat_in[, parms$rm_x],
                            center = parms$int_cen,
                            scale = FALSE),
                      1, prod)
    Z_pred   <- cbind(dat_in, int_term)
    for (i in parms$z_m_id) {
      nR <- simMissingness(pm    = cond$pm,
                           data  = Z_pred,
                           preds = parms$rm_x_int,
                           type  = parms$missType,
                           beta  = parms$auxWts_int)
      
      # Fill in NAs
      dat_out[nR, i] <- NA
    }
  }
  
  # Result
  return( dat_out )
}


# Experiment 4 ------------------------------------------------------------

imposeMiss_evs <- function(dat_in, parms, cond){
  ## Description
  # Given a fully observed dataset and a param object containing the regression
  # coefficients of the model to impose missingness, it returns a version of
  # the original data with imposed missingness on all the variables indicated
  # as target int parms$z_m_id
  ## Example Inputs
  # cond <- conds[1,]
  # dat_in   <- data_source[sample(1:nrow(data_source),
  #                                cond$n,
  #                                replace = TRUE), ]
  
  # Body
  # Define non-response vector
  dat_out <- dat_in
  rm_x    <- dat_in[, parms$rm_x]
  
  # Recode percieved threat from immigrants 1 = low, 10 = high
  # rm_x[,1] <- match(rm_x[,1], max(rm_x[,1]):min(rm_x[,1]) )
  
  # Compute stuff
  for (i in 1:parms$zm_n) {
    nR <- simMissingness(pm    = runif(1, parms$pm[1], parms$pm[2]),
                         data  = rm_x,
                         preds = parms$rm_x,
                         type  = parms$missType,
                         beta  = parms$auxWts)
    
    # Fill in NAs
    dat_out[nR, parms$z_m_id[i]] <- NA
  }
  
  # Result
  return( dat_out )
}