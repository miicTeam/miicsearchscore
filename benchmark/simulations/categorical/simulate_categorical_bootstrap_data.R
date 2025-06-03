# ==============================================================================
# File        : simulate_categorical_bootstrap_data.R
# Description : Generate bootstrap replicates from categorical data using CPTs
#               for selected replicas (defined in selected_replicas.txt),
#               including 0%, 10%, and 20% latent variable scenarios.
#
# Author      : Nikita Lagrange
# Created on  : 2025-05-27
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - readr
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)
library(readr)

# Load selected replica IDs
replica_selection <- read_delim("simulated_data/categorical/bootstrap/selected_replicas.txt", delim = "\t", col_types = "ci")
models <- replica_selection$model
replica_ids <- replica_selection$rep_idx
names(replica_ids) <- models

# Sample sizes and number of bootstraps
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)
num_bootstraps <- 30

for (m_id in seq_along(models)) {
  name <- models[m_id]
  rep_idx <- replica_ids[name]
  
  # Load CPT from RDA into isolated env to avoid name pollution
  rda_file <- file.path("data/CPT", paste0(tolower(name), ".rda"))
  tmp_env <- new.env()
  load(rda_file, envir = tmp_env)
  cpt_obj <- tmp_env[[ls(tmp_env)[1]]]
 
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
    # Generate original deterministic dataset
    set.seed(100000 * m_id + 1000 * rep_idx + n)
    data_orig <- rbn(cpt_obj, n)
    
    # Output directory
    out_dir <- file.path("simulated_data/categorical/bootstrap", name, as.character(n))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    
    for (b in 1:num_bootstraps) {
      # Generate bootstrap replicate
      set.seed(1000000 * b + m_id + n)
      data_boot <- data_orig[sample(1:n, n, replace = TRUE), ]
      
      path_0L <- file.path(out_dir, paste0("input_0L_", rep_idx, "_", b, ".csv"))
      path_10L <- file.path(out_dir, paste0("input_10L_", rep_idx, "_", b, ".csv"))
      path_20L <- file.path(out_dir, paste0("input_20L_", rep_idx, "_", b, ".csv"))
      
      # Save full and masked datasets
      write.csv(data_boot, path_0L, row.names = FALSE)
      write.csv(data_boot[, colnames(pag_10L)], path_10L, row.names = FALSE)
      write.csv(data_boot[, colnames(pag_20L)], path_20L, row.names = FALSE)
    }
  }
}
