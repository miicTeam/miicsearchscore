# ==============================================================================
# File        : run_miic_search_score_categorical_bootstrap.R
# Description : Runs MIIC_search&score on simulated categorical data using
#               bootstrap replicates, including latent variable masking
#               (0L, 10L, 20L scenarios).
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
# ==============================================================================

library(bnlearn)
library(miic)
library(digest)
library(miicsearchscore)

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5) {
    stop("Usage: Rscript run_miic_search_score_categorical_bootstrap.R <name> <rep_idx> <sample_sizes> <n_threads> <b>")
  }
  
  name <- args[1]
  rep_idx <- as.numeric(args[2])
  sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
  n_threads <- as.numeric(args[4])
  b <- as.numeric(args[5])
  
  # ------------------------------------------------------------------------------  
  # Run replicate
  # ------------------------------------------------------------------------------  
  run_replication(rep_idx, b, name, sample_sizes, n_threads)
}


run_replication <- function(rep_idx, b, name, sample_sizes, n_threads) {
    
  rda_file <- file.path("data/CPT", paste0(tolower(name), ".rda"))
  dag_path <- file.path("simulated_data/graphs/categorical", name)
  pag_10L <- as.matrix(read.table(file.path(dag_path, sprintf("pag_10L_%d.csv", rep_idx)), sep = ",", header = TRUE))
  pag_20L <- as.matrix(read.table(file.path(dag_path, sprintf("pag_20L_%d.csv", rep_idx)), sep = ",", header = TRUE))
  
  tmp_env <- new.env()
  load(rda_file, envir = tmp_env)
  cpt_obj <- tmp_env[[ls(tmp_env)[1]]]
  
  # Generate the original dataset using a fixed seed
  m_id <- match(name, c("Alarm", "Insurance", "Barley", "Mildew"))
  for(n in sample_sizes){
    set.seed(100000 * m_id + 1000 * rep_idx + n)
    data_orig <- rbn(cpt_obj, n)
    
    # Bootstrap sampling
    set.seed(1000000 * b + m_id + n)
    data_boot <- data_orig[sample(1:n, n, replace = TRUE), ]
    
    datasets <- list(
      input_0L = data_boot,
      input_10L = data_boot[, colnames(pag_10L)],
      input_20L = data_boot[, colnames(pag_20L)]
    )
    
    adj_results <- list()
    
    base_out <- file.path("results", "categorical", "bootstrap",
                          "MIIC_search_and_score", name, as.character(n))
    dir.create(base_out, recursive = TRUE, showWarnings = FALSE)
    
    for (dataset_name in names(datasets)) {
      data <- datasets[[dataset_name]]
      latent_level <- strsplit(dataset_name, "_")[[1]][2]
      
      # Run MIIC on bootstrapped data
      set.seed(0)
      result_miic <- miic(data, latent = "orientation", propagation = TRUE,
                          consistent = "orientation", n_threads = n_threads)
      
      summary <- result_miic$summary
      summary <- summary[summary$type == "P", ]
      hash_table <- new.env()
      adj_miic <- result_miic$adj_matrix
      
      # Store mutual information values in a hash table
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
      
      # Store the three outputs
      adj_results[[sprintf("miic_%s", latent_level)]] <- adj_miic
      adj_results[[sprintf("sc_node_%s", latent_level)]] <- adj_step1_node_score
      adj_results[[sprintf("sc_node_and_edge_%s", latent_level)]] <- adj_step2_edge_score
    }
    
    for (res_name in names(adj_results)) {
      file_out <- sprintf("adj_%s_%d_%d.csv", res_name, rep_idx, b)
      write.table(adj_results[[res_name]], file = file.path(base_out, file_out),
                  sep = ",", col.names = TRUE, row.names = TRUE)
    }
  }
}
