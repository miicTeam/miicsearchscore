# ==============================================================================
# File        : simulate_categorical_data_hpc.R
# Description : Generate synthetic categorical datasets from DAGs,
#               including 0%, 10%, and 20% latent variable scenarios.
#               Datasets are stored on the cluster in path_input (/mnt/beegfs/tmp).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#
# Notes:
#   - CPTs are loaded from the CPT/ directory as .rda files.
#   - DAGs and PAGs used for latent masking are read from the graphs/ directory.
#   - For each sample size and replication, three datasets are generated:
#       * input_0L : no latent variables masked
#       * input_10L : 10 latent variables masked
#       * input_20L : 20 latent variables masked
#   - This script is intended to run on a SLURM-based HPC cluster without using a $SCRATCH directory.
#   - Outputs are saved in /mnt/beegfs/tmp/<user>/<model_name>/<sample_size>/.
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)

args <- commandArgs(trailingOnly = TRUE)
name <- args[1]                      # ex: "Alarm"
m_id <- as.numeric(args[2])         # model id
sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
rep_idx <- as.numeric(args[4])
path_input <- args[5]

run_replication <- function(rep_idx, name, m_id, sample_sizes, path_input) {
  
  # Load CPT from RDA into isolated env to avoid name pollution
  rda_file <- file.path("data/CPT", paste0(tolower(name), ".rda"))
  tmp_env <- new.env()
  load(rda_file, envir = tmp_env)
  cpt_obj <- tmp_env[[ls(tmp_env)[1]]]
  
  # Output base directory
  output_base <- file.path(path_input, name)
  dir.create(output_base, recursive = TRUE, showWarnings = FALSE)
  
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

    # Output directory per sample size
    out_dir <- file.path(output_base, as.character(n))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Save datasets
    write.csv(data_full, file.path(out_dir, paste0("input_0L_", rep_idx, ".csv")), row.names = FALSE)
    
    write.csv(data_full[, colnames(pag_10L)], file.path(out_dir, paste0("input_10L_", rep_idx, ".csv")), row.names = FALSE)
  
    write.csv(data_full[, colnames(pag_20L)], file.path(out_dir, paste0("input_20L_", rep_idx, ".csv")), row.names = FALSE)

  }
}

# Execute the function
run_replication(rep_idx, name, m_id, sample_sizes, path_input)