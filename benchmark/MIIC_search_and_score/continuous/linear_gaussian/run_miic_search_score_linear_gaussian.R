# ==============================================================================
# File        : run_miic_search_score_linear_gaussian.R
# Description : Runs MIIC_search&score on simulated linear Gaussian data,
#               including latent variable masking (0L, 10L, 20L scenarios).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - igraph
#   - miic
#   - digest
#   - miicsearchscore
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)
library(igraph)
library(miic)
library(digest)
library(miicsearchscore)

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5) {
    stop("Usage: Rscript run_miic_search_score_linear_gaussian.R <n_nodes> <avg_degree> <sample_sizes> <n_threads> <rep_idx>")
  }
  
  n_nodes <- as.numeric(args[1])
  avg_degree <- args[2]
  sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
  n_threads <- as.numeric(args[4])
  rep_idx <- as.numeric(args[5])
  
  run_replication(rep_idx, n_nodes, avg_degree, sample_sizes, n_threads)
  }


# ------------------------------------------------------------------------------
# Function to execute MIIC + search-and-score on one replicate
# ------------------------------------------------------------------------------
run_replication <- function(rep_idx, n_nodes, avg_degree, sample_sizes, n_threads) {
  # Load ground-truth DAG from edgelist
  graph_dir <- file.path("simulated_data/graphs/continuous", paste0("N", n_nodes), avg_degree)
  graph_path <- file.path(graph_dir, paste0("edgelist_", rep_idx, ".txt"))
  pag_10L_path <- file.path(graph_dir, paste0("pag_10L_", rep_idx, ".csv"))
  pag_20L_path <- file.path(graph_dir, paste0("pag_20L_", rep_idx, ".csv"))
  
  cat("Graph path:", graph_path, "\n")
  
  if (!file.exists(pag_10L_path) || !file.exists(pag_20L_path)) {
    warning("PAG files missing for replicate ", rep_idx, " in ", paste0("N", n_nodes), "/", avg_degree)
    next
  }
  
  g <- read_graph(graph_path, format = "edgelist")
  adj <- as_adjacency_matrix(g, sparse = FALSE)
  g <- as_graphnel(g)
  topo_order <- RBGL::tsort(g)
  node_names <- paste0("X", g@nodes)
  colnames(adj) <- rownames(adj) <- node_names
  sorted_names <- paste0("X", topo_order)
  adj_sorted <- adj[sorted_names, sorted_names]
  
  # Reconstruct topologically sorted graph
  g <- as(adj_sorted, "graphNEL")
  
  # Set reproducible edge weights
  set.seed(1000 * rep_idx)
  for (e in names(g@edgeData)) {
    sign <- if (runif(1) > 0.5) -1 else 1
    value <- runif(1, 0.1, 2)
    g@edgeData@data[[e]]$weight <- sign * value
  }
  
  # Read PAGs to mask latent variables
  pag_10L <- as.matrix(read.table(pag_10L_path, header = TRUE, sep = ","))
  pag_20L <- as.matrix(read.table(pag_20L_path, header = TRUE, sep = ","))
  
  # Loop over sample sizes
  for (n in sample_sizes) {
    set.seed(5000 * rep_idx + n)
    data_full <- data.frame(pcalg::rmvDAG(n, g, errDist = "normal"))
    
    # Prepare datasets for 0L, 10L and 20L scenarios
    datasets <- list(
      input_0L = data_full,
      input_10L = data_full[, colnames(pag_10L)],
      input_20L = data_full[, colnames(pag_20L)]
    )
    
    adj_results <- list()
    
    # Prepare output directory
    base_out <- file.path("results","continuous", "linear_gaussian", "MIIC_search_and_score", paste0("N", n_nodes), as.character(avg_degree), as.character(n))
    dir.create(base_out, recursive = TRUE, showWarnings = FALSE)
    
    # Run MIIC and MIIC_search&score for each latent setting
    for (dataset_name in names(datasets)) {
      data <- datasets[[dataset_name]]
      latent_level <- strsplit(dataset_name, "_")[[1]][2]
      
      set.seed(0)  # ensure MIIC reproducibility
      result_miic <- miic(data, latent = "orientation", propagation = TRUE, consistent = "orientation", n_threads = n_threads)
      
      # Build hash table of information gains
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
      
      # Step 2: Greedy edge reorientation using mutual information deltas
      step2_result  <- apply_edge_score_step_2(adj_step1_node_score, data, hash_table)
      adj_step2_edge_score <- step2_result$adj
      
      # Store all three outputs
      adj_results[[sprintf("miic_%s", latent_level)]] <- adj_miic
      adj_results[[sprintf("sc_node_%s", latent_level)]] <-  adj_step1_node_score 
      adj_results[[sprintf("sc_node_and_edge_%s", latent_level)]] <- adj_step2_edge_score
      
    }
    
    # Write results to file
    for (res_name in names(adj_results)) {
      adj_mat <- adj_results[[res_name]]
      base_name <- sprintf("adj_%s%s", res_name, paste0("_",rep_idx))
      output_path <- file.path(base_out, paste0(base_name, ".csv"))
      write.table(adj_mat, sep = ",", file = output_path, col.names = TRUE, row.names = TRUE)
    }
  }  # end n loop
}