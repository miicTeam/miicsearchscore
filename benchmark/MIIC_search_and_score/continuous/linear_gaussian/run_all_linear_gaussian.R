# ==============================================================================
# File        : run_all_linear_gaussian.R
# Description : Runs MIIC_search&score across all settings for simulated
#               linear Gaussian data (n_nodes ∈ {50,150}, avg_degree ∈ {3,5},
#               sample_sizes ∈ {100,...,20000}, rep_idx ∈ 1:30).
#
#               Each combination is executed sequentially by calling
#               run_replication() from run_miic_search_score_linear_gaussian.R.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - R (>= 4.0)
#   - bnlearn
#   - igraph
#   - miic
#   - digest
#   - miicsearchscore
#
# License     : GPL (>= 3)
# ==============================================================================

source("MIIC_search_and_score/continuous/linear_gaussian/run_miic_search_score_linear_gaussian.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("Usage: Rscript run_all_linear_gaussian.R <n_threads>")
}

n_threads <- as.numeric(args[1])
n_nodes_list <- c(50, 150)
avg_degree_list <- c(3, 5)
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
replicates <- 1:30


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