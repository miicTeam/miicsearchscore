# ==============================================================================
# File        : simulate_dag_cpdag_pag_continuous.R
# Description : Generate synthetic DAGs and their corresponding CPDAGs and PAGs
#               for varying graph sizes and average degrees, with latent variables.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-07
# Version     : 1.0.0
#
# Dependencies:
#   - igraph
#   - bnlearn
#   - graph_modeling.R (for adjacency matrix extraction and conversion)
#   - pag_handling.R (for PAG generation from DAG with latent variables)
#
# Notes:
#   - DAGs are sampled with a biased degree distribution.
#   - CPDAGs are derived via Meek rules.
#   - PAGs simulate the presence of hidden variables (10% and 20%).
#   - Outputs include adjacency matrices and edge lists in /graphs/N{nodes}/{degree}/.
#
# License     : GPL (>= 3)
# ==============================================================================

library(igraph)
library(bnlearn)

# Load custom functions
source("utils/graph_modeling.R")
source("utils/pag_handling.R")

# Simulation parameters
num_repetitions <- 30
node_sizes <- c(50, 150)             # Number of nodes per graph
target_degrees <- c(3, 5)            # Desired average degrees
max_degree <- 5                      # Upper bound for sampled degree distribution

# Progress bar setup
total_runs <- length(node_sizes) * length(target_degrees) * num_repetitions
progress_bar <- txtProgressBar(min = 0, max = total_runs, style = 3)
run_counter <- 0

# Main simulation loop
for (num_nodes in node_sizes) {
  for (avg_degree in target_degrees) {
    for (replicate in 1:num_repetitions) {
      
      # Update progress bar
      run_counter <- run_counter + 1
      setTxtProgressBar(progress_bar, run_counter)
      
      # Unique seed to ensure reproducibility
      seed_value <- 1000 * num_nodes + 100 * avg_degree + replicate
      set.seed(seed_value)
      
      # Create biased degree distribution
      prob_degrees <- rep(0.2 / (max_degree - 1), max_degree)
      prob_degrees[avg_degree] <- 0.8
      
      degree_sequence <- sample(
        x = 1:max_degree,
        size = num_nodes,
        replace = TRUE,
        prob = prob_degrees
      )
      
      # Ensure the sequence yields a valid graph
      while (sum(degree_sequence) %% 2 != 0 ||
             (sum(degree_sequence) / 2 < num_nodes - 1)) {
        idx_adjust <- sample(1:num_nodes, 1)
        degree_sequence[idx_adjust] <- degree_sequence[idx_adjust] + 1
      }
      
      # Generate DAG
      dag <- sample_degseq(degree_sequence, method = 'vl')
      dag <- as.directed(dag, mode = "acyclic")
      stopifnot(is.dag(dag))
      
      # Assign names
      node_names <- paste0("X", 1:num_nodes)
      V(dag)$name <- node_names
      
      # Convert to adjacency matrices
      adj_dag <- adjacency_from_cpt(as.bn(dag)$nodes)
      adj_cpdag <- adjacency_to_cpdag(adj_dag)
      
      # Select latent variables
      num_lv_10 <- max(round(num_nodes * 0.1), 1)
      num_lv_20 <- round(num_nodes * 0.2)
      latent_10 <- sample(node_names, num_lv_10)
      latent_20 <- sample(node_names, num_lv_20)
      
      # Output dir
      dir.create("simulated_data/graphs/continuous", showWarnings = FALSE)
      output_dir <- file.path("simulated_data/graphs/continuous", paste0("N", num_nodes), as.character(avg_degree))
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      
      # Save files
      write.table(adj_dag, sep = ",", col.names = TRUE, row.names = TRUE,
                  file = file.path(output_dir, paste0("adj_dag_", replicate, ".csv")))
      write.table(adj_cpdag, sep = ",", col.names = TRUE, row.names = TRUE,
                  file = file.path(output_dir, paste0("adj_cpdag_", replicate, ".csv")))
      write_graph(dag, file = file.path(output_dir, paste0("edgelist_", replicate, ".txt")),
                  format = "edgelist")
      
      # Generate and save PAGs
      pag_10 <- generate_pag_adjacency(adj_dag, latent_10)
      pag_20 <- generate_pag_adjacency(adj_dag, latent_20)
      
      
      write.table(pag_10, sep = ",", col.names = TRUE, row.names = TRUE,
                  file = file.path(output_dir, paste0("pag_10L_", replicate, ".csv")))
      write.table(pag_20, sep = ",", col.names = TRUE, row.names = TRUE,
                  file = file.path(output_dir, paste0("pag_20L_", replicate,".csv")))
    }
  }
}

close(progress_bar)
