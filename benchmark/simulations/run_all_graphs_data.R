# ==============================================================================
# File        : run_all_graphs_data.R
# Description : Master launcher to generate both graph structures and simulated data:
#               - DAGs, CPDAGs, PAGs for all types
#               - Simulated data (linear, non-linear, categorical, bootstrap)
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - run_all_graph.R
#   - run_all_data.R
#
# License     : GPL (>= 3)
# ==============================================================================

message("=== Step 1: Generating all graphs ===")
source("simulations/run_all_graph.R")

message("=== Step 2: Generating all simulated data ===")
source("simulations/run_all_data.R")

message("✅ Graph and data generation completed.")
