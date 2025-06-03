# ==============================================================================
# File        : run_all_categorical.R
# Description : Runs MIIC_search&score across all settings for simulated
#               categorical data (models ∈ {Alarm, Insurance, Barley, Mildew},
#               sample_sizes ∈ {100,...,20000},  rep_idx ∈ 1:50).
#
#               Each combination is executed sequentially by calling
#               run_replication() from run_miic_search_score_categorical.R.
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

source("MIIC_search_and_score/categorical/normal/run_miic_search_score_categorical.R")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("Usage: Rscript run_all_categorical.R <n_threads>")
}

n_threads <- as.numeric(args[1])
models <- c("Alarm", "Insurance", "Barley", "Mildew")
model_ids <- c(1, 2, 3, 4)
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
replicates <- 1:50

# Iterate over all model combinations
for (i in seq_along(models)) {
  name <- models[i]
  m_id <- model_ids[i]
  
  for (rep_idx in replicates) {
    message(sprintf("Running: model = %s, m_id = %d, rep_idx = %d",
                    name, m_id, rep_idx))
    run_replication(rep_idx = rep_idx,
                    m_id = m_id,
                    name = name,
                    sample_sizes = sample_sizes,
                    n_threads = n_threads)
  }
}
