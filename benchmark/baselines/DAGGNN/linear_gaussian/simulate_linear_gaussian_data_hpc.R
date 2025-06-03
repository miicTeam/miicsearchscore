# ==============================================================================
# File        : simulate_linear_gaussian_data_hpc.R
# Description : Generate synthetic linear Gaussian datasets from DAGs,
#               including 0%, 10%, and 20% latent variable scenarios.
#               Stores the datasets in PBS scratch (path_input) for later analysis.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - igraph
#   - bnlearn
#   - pcalg
#   - RBGL
#   - graph (Bioconductor)
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)
library(igraph)
library(RBGL)
library(graph)
library(pcalg)

args <- commandArgs(trailingOnly = TRUE)
n_nodes <- args[1]
avg_degree <- args[2]
sample_sizes <- as.numeric(strsplit(args[3], ",")[[1]])
rep_idx <- as.numeric(args[4])
path_input <- args[5]

# ------------------------------------------------------------------------------
# Function to generate and store datasets for one replicate
# ------------------------------------------------------------------------------
run_replication <- function(rep_idx, n_nodes, avg_degree, sample_sizes, path_input) {
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
    
    # Simulate data from DAG
    data_full <- data.frame(pcalg::rmvDAG(n, g, errDist = "normal"))
    
    out_dir <- file.path(path_input, paste0("N", n_nodes), avg_degree, as.character(n), paste0("rep_", rep_idx))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Apply latent masking based on PAGs
    datasets <- list(
      input_0L = data_full,
      input_10L = data_full[, colnames(pag_10)],
      input_20L = data_full[, colnames(pag_20)]
    )
    
    # Save datasets to PBS scratch path
    for (dataset_name in names(datasets)) {
      data <- datasets[[dataset_name]]
      file_out <- file.path(out_dir, paste0(dataset_name, ".csv"))
      write.csv(data, file_out, row.names = FALSE)
    }
    
    cat("Saved datasets for sample size", n, "in", out_dir, "\n")
  }
}

run_replication(rep_idx, n_nodes, avg_degree, sample_sizes, path_input)