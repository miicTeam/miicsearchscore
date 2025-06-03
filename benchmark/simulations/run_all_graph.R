# ==============================================================================
# File        : run_all_graph.R
# Description : Generates DAGs, CPDAGs and PAGs for all data types:
#               - Continuous
#               - Categorical
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - simulate_dag_cpdag_pag_continuous.R
#   - simulate_dag_cpdag_pag_categorical.R
#
# License     : GPL (>= 3)
# ==============================================================================

message("=== Generating DAGs, CPDAGs and PAGs for continuous data ===")
source("simulations/continuous/simulate_dag_cpdag_pag_continuous.R")

message("=== Generating DAGs, CPDAGs and PAGs for categorical data ===")
source("simulations/categorical/simulate_dag_cpdag_pag_categorical.R")

message("✅ All graph generation scripts completed.")
