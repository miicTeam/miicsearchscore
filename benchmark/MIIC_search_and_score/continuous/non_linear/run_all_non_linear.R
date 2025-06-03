# ==============================================================================
# File        : run_all_non_linear.R
# Description : Runs MIIC_search&score across all settings for simulated
#               non-linear data (n_nodes ∈ {50,150}, avg_degree ∈ {3,5},
#               sample_sizes ∈ {100,...,20000}, rep_idx ∈ 1:30).
#
#               Each combination is executed sequentially by calling
#               run_replication_nonlinear() from run_miic_search_score_non_linear.R.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - igraph
#   - miic
#   - infotheo
#   - digest
#   - quantmod
#   - data.table
#   - miicsearchscore
#   - benchmark/utils/sem_generation_utils.R"
#
# License     : GPL (>= 3)
# ==============================================================================

source("MIIC_search_and_score/continuous/non_linear/run_miic_search_score_non_linear.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("Usage: Rscript run_all_non_linear.R <n_threads>")
}

n_threads <- as.numeric(args[1])
n_nodes_list <- c(50, 150)
avg_degree_list <- c(3, 5)
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
replicates <- 1:30

# Run all combinations
for (n_nodes in n_nodes_list) {
  for (avg_degree in avg_degree_list) {
    for (rep_idx in replicates) {
      message(sprintf("Running: n_nodes = %d, avg_degree = %s, rep_idx = %d", 
                      n_nodes, avg_degree, rep_idx))
      run_replication(rep_idx = rep_idx,
                                n_nodes = n_nodes,
                                avg_degree = avg_degree,
                                sample_sizes = sample_sizes,
                                n_threads = n_threads)
    }
  }
}
