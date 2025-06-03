# ==============================================================================
# File        : run_all_categorical_bootstrap.R
# Description : Runs MIIC_search&score on simulated categorical data using
#               bootstrap replicates (b ∈ 1:30), with latent variable masking.
#               Replicates are selected from selected_replicas.txt for each model.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - miic
#   - digest
#   - miicsearchscore 
#
# License     : GPL (>= 3)
# ==============================================================================

source("MIIC_search_and_score/categorical/bootstrap/run_miic_search_score_categorical_bootstrap.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("Usage: Rscript run_all_categorical_bootstrap.R <n_threads>")
}

n_threads <- as.numeric(args[1])
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
bootstrap_reps <- 1:30
models <- c("Alarm", "Insurance", "Barley", "Mildew")

# Read selected replicates from file
replica_file <- "simulated_data/categorical/bootstrap/selected_replicas.txt"
selected_replicas <- read.table(replica_file, header = TRUE, sep = "\t", stringsAsFactors = FALSE)

# Run for each model and each bootstrap replicate
for (model in models) {
  rep_idx <- selected_replicas$rep_idx[selected_replicas$model == model]
  
  if (length(rep_idx) != 1) {
    stop(paste("No unique replicate index found for model:", model))
  }
  
  for (b in bootstrap_reps) {
    message(sprintf("Running: model = %s, rep_idx = %d, bootstrap = %d", model, rep_idx, b))
    run_replication(rep_idx = rep_idx,
                    name = model,
                    sample_sizes = sample_sizes,
                    n_threads = n_threads,
                    b = b)
  }
}
