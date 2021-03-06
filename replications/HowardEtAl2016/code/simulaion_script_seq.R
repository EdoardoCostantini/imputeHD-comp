### Title:    Replication Howard et al 2015
### Author:   Edoardo Costantini
### Created:  2020-05-18

library(parallel) # detectCores(); makeCluster()
rm(list=ls())
source("./init.R")

## Sequential run
set.seed(1234)
out1 <- list()
for(rp in 1 : parms$dt_rep){
  print(paste0("REPETITION:", rp))
  out1[[rp]] <- try(doRep(rp, conds = conds, parms = parms), silent = TRUE)
}
