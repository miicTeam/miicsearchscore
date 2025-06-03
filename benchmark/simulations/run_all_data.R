# ==============================================================================
# File        : run_all_data.R
# Description : Generates synthetic data for all scenarios:
#               - Continuous linear gaussian
#               - Continuous non-linear
#               - Categorical
#               - Replica selection for bootstrap
#               - Bootstrap resampling (categorical)
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - simulate_linear_gaussian_data.R
#   - simulate_nonlinear_data.R
#   - simulate_categorical_data.R
#   - select_replicas.R
#   - simulate_categorical_bootstrap_data.R
#
# License     : GPL (>= 3)
# ==============================================================================

message("=== Simulating linear Gaussian data ===")
source("simulations/continuous/simulate_linear_gaussian_data.R")

message("=== Simulating non-linear continuous data ===")
source("simulations/continuous/simulate_nonlinear_data.R")

message("=== Simulating categorical data ===")
source("simulations/categorical/simulate_categorical_data.R")

message("=== Selecting representative replicates for bootstrap ===")
source("simulations/categorical/select_replicas.R")

message("=== Simulating bootstrap categorical datasets ===")
source("simulations/categorical/simulate_categorical_bootstrap_data.R")

message("✅ All data simulation scripts completed.")
