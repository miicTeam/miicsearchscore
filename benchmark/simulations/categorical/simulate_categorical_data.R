# ==============================================================================
# File        : simulate_categorical_data.R
# Description : Generate synthetic categorical datasets from DAGs,
#               including 0%, 10%, and 20% latent variable scenarios.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-12
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)

sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
num_repetitions <- 50
graph_names <- c("Alarm", "Insurance", "Barley", "Mildew")

for (m_id in seq_along(graph_names)) {
  name <- graph_names[m_id]
  
  # Load CPT from RDA into isolated env to avoid name pollution
  rda_file <- paste0("data/CPT/", tolower(name), ".rda")
  tmp_env <- new.env()
  load(rda_file, envir = tmp_env)
  cpt_obj <- tmp_env[[ls(tmp_env)[1]]]
  
  # Output directory
  output_base <- file.path("simulated_data/categorical/normal", name)
  dir.create(output_base, recursive = TRUE, showWarnings = FALSE)
  
  for (rep_idx in 1:num_repetitions) {
    
    # Load PAGs for latent variable masking
    dag_path <- file.path("simulated_data/graphs/categorical", name)
    pag_10L_path <- file.path(dag_path, paste0("pag_10L_", rep_idx, ".csv"))
    pag_20L_path <- file.path(dag_path, paste0("pag_20L_", rep_idx, ".csv"))
    
    if (!file.exists(pag_10L_path) || !file.exists(pag_20L_path)) {
      warning("PAG files missing for replicate ", rep_idx, " in ", name)
      next
    }
    # Read PAGs to mask latent variables
    pag_10L <- as.matrix(read.table(pag_10L_path, header = TRUE, sep = ","))
    pag_20L <- as.matrix(read.table(pag_20L_path, header = TRUE, sep = ","))
    
    for (n in sample_sizes) {
      # Deterministic seed based on model, repetition and sample size
      set.seed(100000 * m_id + 1000 * rep_idx + n)
      
      data_full <- rbn(cpt_obj, n)

      # Output paths
      out_dir <- file.path(output_base, as.character(n))
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      
      path_0L <- file.path(out_dir, paste0("input_0L_", rep_idx, ".csv"))
      path_10L <- file.path(out_dir, paste0("input_10L_", rep_idx, ".csv"))
      path_20L <- file.path(out_dir, paste0("input_20L_", rep_idx, ".csv"))
      
      # Save full and masked datasets
      write.csv(data_full, path_0L, row.names = FALSE)
      write.csv(data_full[, colnames(pag_10L)], path_10L, row.names = FALSE)
      write.csv(data_full[, colnames(pag_20L)], path_20L, row.names = FALSE)
    }
  }
}