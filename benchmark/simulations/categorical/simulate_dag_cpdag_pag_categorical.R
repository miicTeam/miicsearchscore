# ==============================================================================
# File        : simulate_dag_cpdag_pag_categorical.R
# Description : Generate DAGs, CPDAGs, and PAGs from real Bayesian networks
#               (Alarm, Insurance, Barley, Mildew) using CPTs from bnlearn.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-12
# Version     : 1.O.0
#
# Dependencies:
#   - igraph
#   - graph_modeling.R (for adjacency matrix extraction and conversion)
#   - pag_handling.R (for PAG generation from DAG with latent variables)
#
# Notes:
#   - DAGs are extracted from CPTs using bnlearn's internal structure.
#   - CPDAGs are derived via Meek rules.
#   - PAGs simulate the presence of hidden variables (10% and 20%).
#   - Outputs are saved under /graphs/{ModelName}/ as adjacency matrices in CSV format.
#
# License     : GPL (>= 3)
# ==============================================================================

library(bnlearn)

# Load custom functions
source("utils/graph_modeling.R")
source("utils/pag_handling.R")

num_repetitions <- 50
graph_names <- c("Alarm", "Insurance", "Barley", "Mildew")

# Progress bar setup
total_runs <- length(graph_names) * num_repetitions
progress_bar <- txtProgressBar(min = 0, max = total_runs, style = 3)
run_counter <- 0

for (m_id in seq_along(graph_names)) {
  name <- graph_names[m_id]
  
  # Load CPT
  rda_file <- paste0("data/CPT/", tolower(name), ".rda")
  load(rda_file)

  # Extract structures
  adj_dag <- adjacency_from_cpt(bn)
  adj_cpdag <- adjacency_to_cpdag(adj_dag)
  node_names <- sort(colnames(adj_dag))  # Sorted for consistent sampling
  num_nodes <- length(node_names)
  
  # Output dir
  output_dir <- file.path("simulated_data/graphs/categorical", name)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Save DAG and CPDAG once
  write.table(adj_dag, sep = ",", col.names = TRUE, row.names = TRUE,
              file = file.path(output_dir, "adj_dag.csv"))
  write.table(adj_cpdag, sep = ",", col.names = TRUE, row.names = TRUE,
              file = file.path(output_dir, "adj_cpdag.csv"))
  
  # Generate PAGs with latent variables
  for (replicate in 1:num_repetitions) {
    seed_value <- 1000 + m_id * 100 + replicate
    set.seed(seed_value)
    
    num_lv_10 <- max(round(num_nodes * 0.1), 1)
    num_lv_20 <- round(num_nodes * 0.2)
    latent_10 <- sample(node_names, num_lv_10)
    latent_20 <- sample(node_names, num_lv_20)
    
    pag_10 <- generate_pag_adjacency(adj_dag, latent_10)
    pag_20 <- generate_pag_adjacency(adj_dag, latent_20)
    
    write.table(pag_10, sep = ",", col.names = TRUE, row.names = TRUE,
                file = file.path(output_dir, paste0("pag_10L_", replicate, ".csv")))
    write.table(pag_20, sep = ",", col.names = TRUE, row.names = TRUE,
                file = file.path(output_dir, paste0("pag_20L_", replicate, ".csv")))
    
    run_counter <- run_counter + 1
    setTxtProgressBar(progress_bar, run_counter)
  }
}

close(progress_bar)
