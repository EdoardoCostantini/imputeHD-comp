### Title:    Conergence Check Blasso
### Project:  Imputing High Dimensional Data
### Author:   Edoardo Costantini
### Created:  2020-08-25

rm(list = ls())
source("./init_general.R")

# Load data
out <- readRDS("../output/exp1_cv_bridge_20201214_1802.rds")

# Obtain conditions with cv ridge
conds_bridge <- bridge_cv(out)
conds_bridge
