# ==============================================================================
# File        : run_miic_search_score_non_linear.R
# Description : Run MIIC_search&score on simulated non-linear data, including 
#               latent variable masking (0L, 10L, 20L scenarios).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-08
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

library(bnlearn)
library(igraph)
library(miic)
library(infotheo)
library(digest)
library(quantmod)
library(data.table)
library(miicsearchscore)

source("utils/sem_generation_utils.R")

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5) {
    stop("Usage: Rscript run_miic_search_score_non_linear.R <n_nodes> <avg_degree> <sample_sizes> <n_threads> <rep_idx>")
  }
  
  n_nodes <- as.numeric(args[1])
  avg_degree <- args[2]
  sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
  n_threads <- as.numeric(args[4])
  rep_idx <- as.numeric(args[5])
  
  # ------------------------------------------------------------------------------  
  # Run replicate
  # ------------------------------------------------------------------------------  
  run_replication(rep_idx, n_nodes, avg_degree, sample_sizes, n_threads)
}


# ------------------------------------------------------------------------------  
# Function to execute MIIC + search-and-score on one replicate
# ------------------------------------------------------------------------------  
run_replication <- function(rep_idx, n_nodes, avg_degree, sample_sizes, n_threads) {
  # Paths
  graph_dir <- file.path("simulated_data/graphs/continuous", paste0("N", n_nodes), avg_degree)
  graph_path <- file.path(graph_dir, paste0("edgelist_", rep_idx, ".txt"))
  pag_10L_path <- file.path(graph_dir, paste0("pag_10L_", rep_idx, ".csv"))
  pag_20L_path <- file.path(graph_dir, paste0("pag_20L_", rep_idx, ".csv"))
  
  cat("Graph path:", graph_path, "\n")
  
  if (!file.exists(pag_10L_path) || !file.exists(pag_20L_path)) {
    warning("PAG files missing for replicate ", rep_idx, " in ", n_nodes, "/", avg_degree)
    next
  }
  
  g <- read_graph(graph_path, format = "edgelist")
  g_graphnel <- as_graphnel(g)
  node_names <- paste0("X", g_graphnel@nodes)
  V(g)$name <- node_names
  dag_bn <- as.bn(g)
  
  # Read PAGs to mask latent variables
  pag_10L <- as.matrix(read.table(pag_10L_path, header = TRUE, sep = ","))
  pag_20L <- as.matrix(read.table(pag_20L_path, header = TRUE, sep = ","))
  
  # Loop over sample sizes
  for (n in sample_sizes) {
    set.seed(1000 * rep_idx + n)
    
    data_full <- matrix(NA, nrow = n, ncol = length(node_names))
    colnames(data_full) <- node_names
    data_full <- as.data.frame(data_full)
    
    prop_discrete <- 0
    is_discrete <<- setNames(as.list(rep(FALSE, length(node_names))), node_names)
    node_params <- list()
    

    orphan_nodes <- node_names[!node_names %in% dag_bn$arcs[, 2]]
    for (node in orphan_nodes) {
      num_modes <- sample(2:4, 1)
      centers <- sample(seq(-20, 20, by = 5) + rnorm(9, 0, 0.5), num_modes)
      sd_vals <- rep(1, num_modes)
      components <- lapply(seq_len(num_modes), function(i) rnorm(n, mean = centers[i], sd = sd_vals[i]))
      data_full[[node]] <- rescale_values(generate_mixture(n, components))
    }
    
    sampled <- orphan_nodes
    while (length(sampled) < length(node_names)) {
      for (node in setdiff(node_names, sampled)) {
        parents <- dag_bn$arcs[, 1][dag_bn$arcs[, 2] == node]
        if (all(parents %in% sampled)) {
          parent_data <- data_full[, parents, drop = FALSE]
          data_full[[node]] <- generate_child_distribution(node, parents, parent_data, FALSE, unlist(is_discrete), method = "nonlinear")
          sampled <- c(sampled, node)
        }
      }
    }
    
    datasets <- list(
      input_0L = data_full,
      input_10L = data_full[, colnames(pag_10L)],
      input_20L = data_full[, colnames(pag_20L)]
    )
    
    adj_results <- list()
    
    # Prepare output directory
    base_out <- file.path("results","continuous", "non_linear", "MIIC_search_and_score", paste0("N", n_nodes), as.character(avg_degree), as.character(n))
    dir.create(base_out, recursive = TRUE, showWarnings = FALSE)
    
    # Run MIIC and MIIC_search&score for each latent setting
    for (dataset_name in names(datasets)) {
      data <- datasets[[dataset_name]]
      latent_level <- strsplit(dataset_name, "_")[[1]][2]
      
      set.seed(0)  # ensure MIIC reproducibility
      miic_result <- miic(data, latent = "orientation", propagation = TRUE, consistent = "orientation", n_threads = n_threads)
      
      summary <- miic_result$summary
      summary <- summary[summary$type == "P", ]
      hash_table <- new.env()
      adj_miic <- miic_result$adj_matrix
      
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
      adj_results[[paste0("miic_", latent_level)]] <- adj_miic
      adj_results[[paste0("sc_node_", latent_level)]] <- adj_step1_node_score
      adj_results[[paste0("sc_node_and_edge_", latent_level)]] <- adj_step2_edge_score
    }
    
    for (res_name in names(adj_results)) {
      file_name <- sprintf("adj_%s_%s.csv", res_name, rep_idx)
      write.table(adj_results[[res_name]], file = file.path(base_out, file_name), sep = ",", col.names = TRUE, row.names = TRUE)
    }
  }
}
