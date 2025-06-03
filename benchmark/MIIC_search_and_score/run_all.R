# ==============================================================================
# File        : run_all.R
# Description : Master launcher for MIIC_search&score benchmark runs on all data types:
#               - DAG/CPDAG/PAG generation
#               - Linear Gaussian
#               - Non-linear
#               - Categorical
#               - Categorical with bootstrap
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Scripts: run_all_graphs.R, run_all_linear_gaussian.R, run_all_non_linear.R,
#              run_all_categorical.R, run_all_categorical_bootstrap.R
#
# License     : GPL (>= 3)
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("Usage: Rscript run_all.R <n_threads>")
}

n_threads <- as.numeric(args[1])

# Run graph generation script
message("Launching: DAG / CPDAG / PAG generation")
source("simulations/run_all_graph.R", local = TRUE)

# Run each type-specific launcher script
message("Launching: Linear Gaussian simulations")
source("MIIC_search_and_score/continuous/linear_gaussian/run_all_linear_gaussian.R", local = TRUE)

message("Launching: Non-linear simulations")
source("MIIC_search_and_score/continuous/non_linear/run_all_non_linear.R", local = TRUE)

message("Launching: Categorical simulations")
source("MIIC_search_and_score/categorical/normal/run_all_categorical.R", local = TRUE)

message("Launching: Categorical bootstrap simulations")
source("MIIC_search_and_score/categorical/bootstrap/run_all_categorical_bootstrap.R", local = TRUE)

message("All MIIC_search&score benchmark runs completed.")
