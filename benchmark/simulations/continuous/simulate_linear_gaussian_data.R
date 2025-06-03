# ==============================================================================
# File        : simulate_linear_gaussian_data.R
# Description : Generate synthetic linear Gaussian datasets from DAGs,
#               including 0%, 10%, and 20% latent variable scenarios.
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

# Parameters
num_repetitions <- 30
node_configs <- c("N50", "N150")
degree_configs <- c("3", "5")
sample_sizes <- c(100, 250, 500, 1000, 5000, 10000, 20000)

# Loop over graph configurations
for (n_nodes in node_configs) {
  for (avg_degree in degree_configs) {
    # Output folder
    output_base <- file.path("simulated_data/continuous/linear_gaussian", n_nodes, avg_degree)
    dir.create(output_base, recursive = TRUE, showWarnings = FALSE)
    for (rep_idx in 1:num_repetitions) {
      # Paths
      graph_dir <- file.path("simulated_data/graphs/continuous", n_nodes, avg_degree)
      graph_path <- file.path(graph_dir, paste0("edgelist_", rep_idx, ".txt"))
      pag_10L_path <- file.path(graph_dir, paste0("pag_10L_", rep_idx, ".csv"))
      pag_20L_path <- file.path(graph_dir, paste0("pag_20L_", rep_idx, ".csv"))
      
      if (!file.exists(pag_10L_path) || !file.exists(pag_20L_path)) {
        warning("PAG files missing for replicate ", rep_idx, " in ", n_nodes, "/", avg_degree)
        next
      }
      
      # Read and sort DAG
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
        
        # Output paths
        out_dir <- file.path(output_base, as.character(n))
        dir.create(out_dir, showWarnings = FALSE)
        
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
}
