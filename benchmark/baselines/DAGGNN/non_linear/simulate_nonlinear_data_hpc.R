# ==============================================================================
# File        : simulate_nonlinear_data_hpc.R
# Description : Script to generate synthetic observational data using
#               non-linear structural equation models (SEMs).
#               Stores the datasets in PBS scratch (path_input) for later analysis.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - bnlearn
#   - igraph
#   - infotheo
#   - quantmod
#   - data.table
#   - sem_generation_utils.R"
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)
library(igraph)
library(infotheo)
library(quantmod)
library(data.table)
source("utils/sem_generation_utils.R")

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
    
    # Initialize orphans
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
    
    # Output paths
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
    
    cat("Saved datasets for sample size", sample_size, "in", out_dir, "\n")
  }
}

run_replication(rep_idx, n_nodes, avg_degree, sample_sizes, path_input)