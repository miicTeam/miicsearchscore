# ==============================================================================
# File        : run_miic_search_score_categorical.R
# Description : Runs MIIC_search&score on simulated categorical data,
#               including latent variable masking (0L, 10L, 20L scenarios).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - miic
#   - digest
#   - miicsearchscore
#
# License     : GPL (>= 3)
# ====================================

library(bnlearn)
library(miic)
library(digest)
library(miicsearchscore)

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5) {
    stop("Usage: Rscript run_miic_search_score_categorical.R <name> <m_id> <sample_sizes> <n_threads> <rep_idx>")
  }
  
  name <- args[1]                      # ex: "Alarm"
  m_id <- as.numeric(args[2])         # model id
  sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
  n_threads <- as.numeric(args[4])
  rep_idx <- as.numeric(args[5])
  
  # ------------------------------------------------------------------------------  
  # Run replicate
  # ------------------------------------------------------------------------------  
  run_replication(rep_idx, m_id, name, sample_sizes, n_threads)
  }

run_replication <- function(rep_idx, m_id, name, sample_sizes, n_threads) {
  
  # Load CPT from RDA into isolated env to avoid name pollution
  rda_file <- file.path("data/CPT", paste0(tolower(name), ".rda"))
  if (!file.exists(rda_file)) stop("CPT file not found: ", rda_file)
  
  tmp_env <- new.env()
  load(rda_file, envir = tmp_env)
  cpt_obj <- tmp_env[[ls(tmp_env)[1]]]
  
  # Load PAGs from full path
  dag_path <- file.path("simulated_data/graphs/categorical", name)
  pag_10L_file <- file.path(dag_path, paste0("pag_10L_", rep_idx, ".csv"))
  pag_20L_file <- file.path(dag_path, paste0("pag_20L_", rep_idx, ".csv"))
  if (!file.exists(pag_10L_file) || !file.exists(pag_20L_file)) {
    stop("PAG files missing for ", name, " rep ", rep_idx)
  }
  pag_10L <- as.matrix(read.table(pag_10L_file, header = TRUE, sep = ","))
  pag_20L <- as.matrix(read.table(pag_20L_file, header = TRUE, sep = ","))
  
  for (n in sample_sizes) {
    
    set.seed(100000 * m_id + 1000 * rep_idx + n)
    
    data_full <- rbn(cpt_obj, n)

    base_out <- file.path("results","categorical", "normal",
                          "MIIC_search_and_score", name, as.character(n))
    dir.create(base_out, recursive = TRUE, showWarnings = FALSE)
    
    datasets <- list(
      input_0L = data_full,
      input_10L = data_full[, colnames(pag_10L)],
      input_20L = data_full[, colnames(pag_20L)]
    )
    
    adj_results <- list()
    
    for (dataset_name in names(datasets)) {
      data <- datasets[[dataset_name]]
      latent_level <- strsplit(dataset_name, "_")[[1]][2]
      
      set.seed(0)
      result_miic <- miic(data, latent = "orientation", propagation = TRUE,
                          consistent = "orientation", n_threads = n_threads)
      
      summary <- result_miic$summary
      summary <- summary[summary$type == "P", ]
      hash_table <- new.env()
      adj_miic <- result_miic$adj_matrix
      
      for (i in seq_len(nrow(summary))) {
        X <- summary[i, "x"]
        Y <- summary[i, "y"]
        cond <- summary[i, "ai"]
        info_val <- summary[i, "info_shifted"]
        key <- if (!is.na(cond)) digest(c(sort(c(X, Y)), sort(cond))) else digest(sort(c(X, Y)))
        hash_table[[key]] <- info_val
      }
      
      # Step 1: Node-level conditioning set selection and edge pruning
      step1_result <- apply_node_score_step_1(adj_miic, data, hash_table)
      adj_step1_node_score <- step1_result$adj
      hash_table <- step1_result$hash_table
      
      # Step 2: Greedy edge orientation using mutual information deltas
      step2_result  <- apply_edge_score_step_2(adj_step1_node_score, data, hash_table)
      adj_step2_edge_score <- step2_result$adj
      
      # Store all three outputs
      adj_results[[sprintf("miic_%s", latent_level)]] <- adj_miic
      adj_results[[sprintf("sc_node_%s", latent_level)]] <- adj_step1_node_score
      adj_results[[sprintf("sc_node_and_edge_%s", latent_level)]] <- adj_step2_edge_score
    }
    
    for (res_name in names(adj_results)) {
      adj_mat <- adj_results[[res_name]]
      file_name <- sprintf("adj_%s_%s.csv", res_name, rep_idx)
      output_path <- file.path(base_out, file_name)
      write.table(adj_mat, sep = ",", file = output_path, col.names = TRUE, row.names = TRUE)
    }
  }
}
